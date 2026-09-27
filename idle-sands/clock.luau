--- The economy's clock. Runs every frame. Iterates Economy.producers,
--- running the identical auto-collect cycle for each row (the free starter,
--- then every purchased bot) - same pattern as the inventory list, so
--- adding a bot later is one more list entry, not more duplicated logic.
--- Each producer owns its own cycle/pulse/popup state and its own storage
--- list. digSpeedSeconds, itemsPerDig, elbowGreasePercent and
--- storageCapacity are upgraded per robot CLASS (robotClasses.rml) rather
--- than shared fleet-wide - each producer carries a robotClass name
--- (producers.rml) that picks which RobotClass instance this script reads
--- those four stats from every frame. dockSpeed (the dock-walking upgrade)
--- stays the one fleet-wide exception, since there's only one physical
--- dock every class shares.
---
--- The four upgrade panels in scene.rml are unchanged from before this
--- restructuring: they still read Economy.itemsPerDig/digSpeedSeconds/
--- elbowGreasePercent/storageCapacity (+ their *Affordable/*CostLabel
--- pairs). Those Economy fields are now a MIRROR of whichever class is
--- selected (Economy.selectedClassName) - refreshed here every frame from
--- the matching RobotClass instance - not the authoritative values
--- themselves. upgrade.luau writes to the selected RobotClass instance
--- directly when classScoped is set, never to the mirror.
---
--- Also owns: each upgrade panel's and Sell All's affordable state,
--- the live storage totals, whether Beach Boy/Steel Seeker are affordable
--- to buy, routing a full producer to the dock once dockSpeed is unlocked,
--- the tab bar's active/locked visual state, and unlocking Steel Seeker
--- once lifetime earnings cross a threshold.

type ClockState = {
	context: Context?,
}

-- Item pools, by name (Producer.itemPoolName). Common items turn up far
-- more than rare ones within a pool; weights are relative, not percentages.
type ItemWeight = { name: string, weight: number }
local ITEM_POOLS: { [string]: { ItemWeight } } = {
	all = {
		{ name = 'BottleCap', weight = 30 },
		{ name = 'Nail', weight = 25 },
		{ name = 'TinCan', weight = 20 },
		{ name = 'Screw', weight = 12 },
		{ name = 'Key', weight = 8 },
		{ name = 'Coin', weight = 5 },
	},
	beachBoy = {
		{ name = 'BottleCap', weight = 30 },
		{ name = 'Nail', weight = 25 },
		{ name = 'TinCan', weight = 20 },
	},
	steelSeeker = {
		{ name = 'Screw', weight = 40 },
		{ name = 'Key', weight = 35 },
		{ name = 'Coin', weight = 25 },
	},
}

local PULSE_DURATION = 0.25
local COLLECT_PULSE_MAGNITUDE = 0.15
local DIMMED_ALPHA = 0.4
local POPUP_DURATION = 1.0

-- Upgrade shape: all four take 5 uniform steps from start to cap, so a
-- shared Cost(n) = base * growth^n curve behaves the same way for each,
-- independently per robot class. These must match the ScriptInput* values
-- on the matching Buy* listener in scene.rml exactly, or the displayed
-- price will disagree with what upgrade.luau actually charges.
local UPGRADE_BASE_COST = 5
local UPGRADE_GROWTH = 2.8

local ITEMS_PER_DIG_START = 1
local ITEMS_PER_DIG_STEP = 1
local ITEMS_PER_DIG_MAX = 6

local DIG_SPEED_START = 60
local DIG_SPEED_STEP = -11
local DIG_SPEED_MIN = 5

local ELBOW_GREASE_START = 1
local ELBOW_GREASE_STEP = 1
local ELBOW_GREASE_MAX = 6

local STORAGE_CAPACITY_START = 3
local STORAGE_CAPACITY_STEP = 1
local STORAGE_CAPACITY_MAX = 8

-- Dock speed: 0 means docking hasn't been unlocked yet (a full producer
-- just sits frozen, same as before this feature existed - only a manual
-- click empties it). The first purchase moves it off zero, which both
-- unlocks docking and sets its initial speed; further purchases only
-- make the dock-seeking trip faster. Ambient wandering is unaffected -
-- it always uses the fixed ROAM_SPEED below, so robots never stand
-- still just because docking hasn't been bought yet. Fleet-wide (not
-- per-class): there's only one physical dock.
local MOVE_SPEED_START = 0
local MOVE_SPEED_STEP = 20
local MOVE_SPEED_MAX = 100

-- Beach Boy is repeatable rather than a one-time flag: each purchase adds
-- another producer and gets pricier, on its own (steeper, since these are
-- whole extra producers rather than a shared stat) Cost(n) = base *
-- growth^n curve, n being how many are already owned. Must match the
-- ScriptInput* values on the BuyBeachBoy listener in scene.rml exactly.
local BEACH_BOY_BASE_COST = 150
local BEACH_BOY_GROWTH = 1.6

-- Steel Seeker: same repeatable shape as Beach Boy, pricier entry and a
-- pool of exclusively mid/high-value items (no BottleCap/Nail/TinCan) to
-- justify it. Must match the ScriptInput* values on the BuySteelSeeker
-- listener in scene.rml exactly. Also stays undiscovered - hidden from
-- the tab bar and the Robots tab's purchase panel - until
-- lifetimeCurrencyEarned crosses STEEL_SEEKER_DISCOVERY_THRESHOLD: a
-- mid-game milestone meant to land a little after a player has settled
-- into Beach Crew upgrades and a first Beach Boy, not as a distant goal.
local STEEL_SEEKER_BASE_COST = 220
local STEEL_SEEKER_GROWTH = 1.6
local STEEL_SEEKER_DISCOVERY_THRESHOLD = 500

local function levelsBought(currentValue: number, step: number, startValue: number): number
	return math.floor(math.abs(currentValue - startValue) / math.abs(step) + 0.5)
end

local function upgradeCost(level: number): number
	return math.floor(UPGRADE_BASE_COST * (UPGRADE_GROWTH ^ level) + 0.5)
end

local function beachBoyCost(count: number): number
	return math.floor(BEACH_BOY_BASE_COST * (BEACH_BOY_GROWTH ^ count) + 0.5)
end

local function steelSeekerCost(count: number): number
	return math.floor(STEEL_SEEKER_BASE_COST * (STEEL_SEEKER_GROWTH ^ count) + 0.5)
end

-- Mirrors one stat from the currently-selected RobotClass instance onto
-- the (unchanged since before per-class upgrades) Economy display field
-- of the same name, and computes that stat's affordable/cost-label pair
-- the same way every upgrade panel always has. Collapses what would
-- otherwise be four near-identical ~12-line blocks (one per stat) into
-- one function and four call sites.
local function mirrorAndPriceStat(
	economy: ViewModel,
	selectedClass: ViewModel,
	statName: string,
	affordableName: string,
	costLabelName: string,
	step: number,
	startValue: number,
	cap: number,
	decreasing: boolean,
	currencyValue: number
)
	local srcProp = selectedClass:getNumber(statName)
	if not srcProp then
		return
	end

	local destProp = economy:getNumber(statName)
	if destProp then
		destProp.value = srcProp.value
	end

	local affordable = economy:getNumber(affordableName)
	local costLabel = economy:getString(costLabelName)
	if affordable and costLabel then
		local maxed = if decreasing then srcProp.value <= cap else srcProp.value >= cap
		local level = levelsBought(srcProp.value, step, startValue)
		local cost = upgradeCost(level)
		affordable.value = (currencyValue >= cost and not maxed) and 1 or DIMMED_ALPHA
		costLabel.value = maxed and 'MAX' or tostring(cost)
	end
end

-- Roaming: each producer drifts toward a random point, then picks a new
-- one on arrival. Bounds are a conservative box that fits inside the
-- beach area at the narrowest tested viewport (1024x640); revisit once
-- the responsive-layout pass can report the area's real resolved size.
local ROAM_SPEED = 40 -- points per second
local ROAM_MIN_X = 20
local ROAM_MAX_X = 520
local ROAM_MIN_Y = 20
local ROAM_MAX_Y = 320
local ROAM_ARRIVE_THRESHOLD = 4

-- The dock: a fixed point at the bottom-center of the beach area
-- (BeachArea-local coordinates, matching DockBox's static position in
-- scene.rml). Once dockSpeed is unlocked, a full producer heads straight
-- here instead of picking a new random roam target, and auto-sells the
-- moment it arrives.
local DOCK_CENTER_X = 500
local DOCK_CENTER_Y = 480
local DOCK_ARRIVE_THRESHOLD = 10

-- Wheel tracks: a mark drops every TRAIL_DROP_DISTANCE points a producer
-- travels, fades out linearly over TRAIL_FADE_DURATION seconds, and the
-- shared list is capped at TRAIL_MAX_COUNT (oldest dropped first) so it
-- can't grow without bound over a long idle session. Offsets convert a
-- producer's own roamX/roamY (its widget's top-left) into a mark centred
-- under the widget's middle, where the digging circle actually sits.
local TRAIL_DROP_DISTANCE = 18
local TRAIL_FADE_DURATION = 3
local TRAIL_MAX_COUNT = 40
local PRODUCER_WIDGET_CENTER = 55 -- half of ProducerWidget's 110x110
local TRACK_DOT_HALF = 7 -- half of TrackDot's 14x14

-- Elbow Grease tutorial: the shared Tooltip overlay auto-shows over the
-- first producer, with no hover needed, until the player has ever clicked
-- a robot (main.luau flips elbowGreaseTaught the first time that happens).
-- Root-space conversion matches showTooltip.luau's own (roamX/roamY are
-- BeachArea-local); anchorY here mirrors the ScriptInputNumber on the
-- ShowTooltip listener in producers.rml, so the tutorial and the ordinary
-- hover tooltip land in the same spot.
local BEACH_AREA_ROOT_Y = 64
local TUTORIAL_ANCHOR_Y = -60
local TUTORIAL_TEXT = 'Click to dig faster!'

local function init(self: ClockState, context: Context): boolean
	self.context = context
	return true
end

local function clamp01(value: number): number
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

local function pickItemName(poolName: string): string
	local pool = ITEM_POOLS[poolName] or ITEM_POOLS.all
	local totalWeight = 0
	for _, entry in pool do
		totalWeight += entry.weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, entry in pool do
		cumulative += entry.weight
		if roll <= cumulative then
			return entry.name
		end
	end
	return pool[1].name
end

local function advance(self: ClockState, seconds: number): boolean
	local context = self.context
	if not context then
		return true
	end

	local economy = context:globalViewModel('Economy')
	if not economy then
		return true
	end

	local gameTimeProp = economy:getNumber('gameTime')
	if gameTimeProp then
		gameTimeProp.value = gameTimeProp.value + seconds
	end
	local gameTime = if gameTimeProp then gameTimeProp.value else 0

	local robotClasses = economy:getList('robotClasses')
	local function findRobotClass(className: string): ViewModel?
		if not robotClasses then
			return nil
		end
		for i = 1, robotClasses.length do
			local rc = robotClasses[i]
			local cn = rc:getString('className')
			if cn and cn.value == className then
				return rc
			end
		end
		return nil
	end

	local dockSpeedProp = economy:getNumber('dockSpeed')
	local currency = economy:getNumber('currency')
	local currencyValue = if currency then currency.value else 0
	local lifetimeCurrencyEarned = economy:getNumber('lifetimeCurrencyEarned')

	-- Every producer runs the same cycle: tick down, collect and restart
	-- when it reaches zero, into its OWN onboard storage, using its OWN
	-- class's digSpeedSeconds/itemsPerDig/storageCapacity. Clicking
	-- (main.luau, inside the row) either pulls a producer's own
	-- lastDigTime forward to shorten what's left, or - once that
	-- producer's storage is full - sells it on the spot; it never
	-- collects directly either way. A full producer simply stops
	-- collecting (the cycle freezes rather than resets) until its owner
	-- empties it.
	local producers = economy:getList('producers')
	if producers then
		for i = 1, producers.length do
			local producer = producers[i]
			local classNameProp = producer:getString('robotClass')
			local className = if classNameProp then classNameProp.value else 'beachCrew'
			local robotClass = findRobotClass(className)

			local digSpeed = if robotClass then robotClass:getNumber('digSpeedSeconds') else nil
			local itemsPerDigProp = if robotClass then robotClass:getNumber('itemsPerDig') else nil
			local itemsPerDig = if itemsPerDigProp then math.floor(itemsPerDigProp.value) else 1
			local classStorageCapacityProp = if robotClass then robotClass:getNumber('storageCapacity') else nil
			local storageCapacityValue = if classStorageCapacityProp then classStorageCapacityProp.value else STORAGE_CAPACITY_START

			local storage = producer:getList('storage')
			local storageCapacity = producer:getNumber('storageCapacity')
			if storageCapacity then
				storageCapacity.value = storageCapacityValue
			end
			local isFull = (storage ~= nil) and (storageCapacity ~= nil) and (storage.length >= storageCapacity.value)

			local lastDigTime = producer:getNumber('lastDigTime')
			local cooldownFraction = producer:getNumber('digCooldownFraction')
			if lastDigTime and cooldownFraction and digSpeed and digSpeed.value > 0 then
				if isFull then
					cooldownFraction.value = 0
				elseif storage then
					local remaining = digSpeed.value - (gameTime - lastDigTime.value)
					if remaining <= 0 then
						local itemPoolNameProp = producer:getString('itemPoolName')
						local poolName = if itemPoolNameProp then itemPoolNameProp.value else 'all'

						local collectedTotal = 0
						for _ = 1, itemsPerDig do
							if storageCapacity and storage.length >= storageCapacity.value then
								break
							end
							local item = Data.Item.new(pickItemName(poolName))
							storage:push(item)
							local value = item:getNumber('value')
							if value then
								collectedTotal += value.value
							end
						end

						lastDigTime.value = gameTime
						remaining = digSpeed.value

						local lastPulseTime = producer:getNumber('lastPulseTime')
						local pulseMagnitude = producer:getNumber('pulseMagnitude')
						if lastPulseTime and pulseMagnitude then
							lastPulseTime.value = gameTime
							pulseMagnitude.value = COLLECT_PULSE_MAGNITUDE
						end

						local lastDigPopupTime = producer:getNumber('lastDigPopupTime')
						local digPopupText = producer:getString('digPopupText')
						if lastDigPopupTime and digPopupText and collectedTotal > 0 then
							lastDigPopupTime.value = gameTime
							digPopupText.value = '+$' .. tostring(collectedTotal)
						end
					end

					cooldownFraction.value = clamp01(remaining / digSpeed.value)
				end
			end

			local storageLabel = producer:getString('storageLabel')
			if storageLabel and storage and storageCapacity then
				if isFull then
					storageLabel.value = '!'
				else
					storageLabel.value = tostring(storage.length) .. '/' .. tostring(math.floor(storageCapacity.value))
				end
			end

			-- Pulse scale (collect vs. click-boost use different magnitudes)
			local itemPulseScale = producer:getNumber('itemPulseScale')
			local lastPulseTime = producer:getNumber('lastPulseTime')
			local pulseMagnitude = producer:getNumber('pulseMagnitude')
			if itemPulseScale and lastPulseTime and pulseMagnitude then
				local sincePulse = gameTime - lastPulseTime.value
				local pulse = 0
				if sincePulse >= 0 and sincePulse < PULSE_DURATION then
					pulse = 1 - (sincePulse / PULSE_DURATION)
				end
				itemPulseScale.value = 1 + pulse * pulseMagnitude.value
			end

			-- Collect popup ("+$36"), fading out after POPUP_DURATION seconds
			local lastDigPopupTime = producer:getNumber('lastDigPopupTime')
			local digPopupAlpha = producer:getNumber('digPopupAlpha')
			if lastDigPopupTime and digPopupAlpha then
				local sincePopup = gameTime - lastDigPopupTime.value
				digPopupAlpha.value = clamp01(1 - (sincePopup / POPUP_DURATION))
			end

			-- Roaming: drift toward roamTarget*, pick a new one on arrival,
			-- so the producer looks like it's wandering around collecting.
			-- Once full, if docking has been unlocked (dockSpeed > 0), it
			-- beelines for the dock instead of a random point, at
			-- dockSpeed rather than ROAM_SPEED, and auto-sells the moment
			-- it arrives. Ambient wandering itself never depends on
			-- dockSpeed, so robots always wander even before docking is
			-- unlocked; only a full robot's behaviour changes.
			local roamX = producer:getNumber('roamX')
			local roamY = producer:getNumber('roamY')
			local roamTargetX = producer:getNumber('roamTargetX')
			local roamTargetY = producer:getNumber('roamTargetY')
			if roamX and roamY and roamTargetX and roamTargetY then
				local dockSpeedValue = if dockSpeedProp then dockSpeedProp.value else 0
				local docking = isFull and dockSpeedValue > 0
				local speed = ROAM_SPEED
				local dockTargetX = DOCK_CENTER_X - PRODUCER_WIDGET_CENTER
				local dockTargetY = DOCK_CENTER_Y - PRODUCER_WIDGET_CENTER

				if docking then
					roamTargetX.value = dockTargetX
					roamTargetY.value = dockTargetY
					speed = dockSpeedValue
				elseif roamTargetX.value == dockTargetX and roamTargetY.value == dockTargetY then
					-- Was heading for the dock, but got emptied before
					-- arriving (a manual click-sell, or Sell All) - drop
					-- the dock as a destination right away instead of
					-- finishing that walk at ordinary roam speed.
					roamTargetX.value = ROAM_MIN_X + math.random() * (ROAM_MAX_X - ROAM_MIN_X)
					roamTargetY.value = ROAM_MIN_Y + math.random() * (ROAM_MAX_Y - ROAM_MIN_Y)
				end

				local dx = roamTargetX.value - roamX.value
				local dy = roamTargetY.value - roamY.value
				local dist = math.sqrt(dx * dx + dy * dy)

				if docking and dist < DOCK_ARRIVE_THRESHOLD then
					-- Arrived at the dock: sell this producer's own
					-- storage on the spot (the same sum+clear sweep as a
					-- manual full-click sale in main.luau), then it's
					-- free to wander again.
					local dockTotal = 0
					if storage then
						for i2 = 1, storage.length do
							local item = storage[i2]
							local value = item:getNumber('value')
							if value then
								dockTotal += value.value
							end
						end
						storage:clear()
					end
					if currency then
						currency.value += dockTotal
					end
					if lifetimeCurrencyEarned then
						lifetimeCurrencyEarned.value += dockTotal
					end

					local dockPulseTime = producer:getNumber('lastPulseTime')
					local dockPulseMagnitude = producer:getNumber('pulseMagnitude')
					if dockPulseTime and dockPulseMagnitude then
						dockPulseTime.value = gameTime
						dockPulseMagnitude.value = COLLECT_PULSE_MAGNITUDE
					end
					local dockPopupTime = producer:getNumber('lastDigPopupTime')
					local digPopupText = producer:getString('digPopupText')
					if dockPopupTime and digPopupText and dockTotal > 0 then
						dockPopupTime.value = gameTime
						digPopupText.value = 'SOLD +$' .. tostring(dockTotal)
					end

					roamTargetX.value = ROAM_MIN_X + math.random() * (ROAM_MAX_X - ROAM_MIN_X)
					roamTargetY.value = ROAM_MIN_Y + math.random() * (ROAM_MAX_Y - ROAM_MIN_Y)
				elseif (not docking) and dist < ROAM_ARRIVE_THRESHOLD then
					roamTargetX.value = ROAM_MIN_X + math.random() * (ROAM_MAX_X - ROAM_MIN_X)
					roamTargetY.value = ROAM_MIN_Y + math.random() * (ROAM_MAX_Y - ROAM_MIN_Y)
				else
					local step = math.min(speed * seconds, dist)
					roamX.value += (dx / dist) * step
					roamY.value += (dy / dist) * step
				end

				-- Wheel tracks: drop a mark once this producer has moved
				-- far enough since its last one.
				local lastTrailX = producer:getNumber('lastTrailX')
				local lastTrailY = producer:getNumber('lastTrailY')
				if lastTrailX and lastTrailY then
					local tdx = roamX.value - lastTrailX.value
					local tdy = roamY.value - lastTrailY.value
					local traveled = math.sqrt(tdx * tdx + tdy * tdy)
					if traveled >= TRAIL_DROP_DISTANCE then
						local trail = economy:getList('trail')
						if trail then
							local point = Data.TrackPoint.new('Default')
							local px = point:getNumber('x')
							local py = point:getNumber('y')
							local spawnTime = point:getNumber('spawnTime')
							if px and py and spawnTime then
								px.value = roamX.value + PRODUCER_WIDGET_CENTER - TRACK_DOT_HALF
								py.value = roamY.value + PRODUCER_WIDGET_CENTER - TRACK_DOT_HALF
								spawnTime.value = gameTime
							end
							trail:push(point)
							if trail.length > TRAIL_MAX_COUNT then
								trail:shift()
							end
						end
						lastTrailX.value = roamX.value
						lastTrailY.value = roamY.value
					end
				end
			end
		end
	end

	-- Fade every dropped wheel track linearly over TRAIL_FADE_DURATION
	-- seconds; the cap above (not this) is what keeps the list from
	-- growing forever, so a fully-faded mark just sits invisible until
	-- newer ones eventually shift it out.
	local trail = economy:getList('trail')
	if trail then
		for i = 1, trail.length do
			local point = trail[i]
			local spawnTime = point:getNumber('spawnTime')
			local alpha = point:getNumber('alpha')
			if spawnTime and alpha then
				local age = gameTime - spawnTime.value
				alpha.value = clamp01(1 - (age / TRAIL_FADE_DURATION))
			end
		end
	end

	-- Upgrade panels: mirror whichever class is selected onto the (still
	-- Economy-level, unchanged) display fields the panels already bind
	-- to, and price each stat independently on its own Cost(n) curve.
	local selectedClassName = economy:getString('selectedClassName')
	local selectedClass = if selectedClassName then findRobotClass(selectedClassName.value) else nil
	if selectedClass then
		mirrorAndPriceStat(economy, selectedClass, 'itemsPerDig', 'itemsPerDigAffordable', 'itemsPerDigCostLabel', ITEMS_PER_DIG_STEP, ITEMS_PER_DIG_START, ITEMS_PER_DIG_MAX, false, currencyValue)
		mirrorAndPriceStat(economy, selectedClass, 'digSpeedSeconds', 'digSpeedAffordable', 'digSpeedCostLabel', DIG_SPEED_STEP, DIG_SPEED_START, DIG_SPEED_MIN, true, currencyValue)
		mirrorAndPriceStat(economy, selectedClass, 'elbowGreasePercent', 'elbowGreaseAffordable', 'elbowGreaseCostLabel', ELBOW_GREASE_STEP, ELBOW_GREASE_START, ELBOW_GREASE_MAX, false, currencyValue)
		mirrorAndPriceStat(economy, selectedClass, 'storageCapacity', 'storageCapacityAffordable', 'storageCapacityCostLabel', STORAGE_CAPACITY_STEP, STORAGE_CAPACITY_START, STORAGE_CAPACITY_MAX, false, currencyValue)
	end

	-- Dock speed panel: reads "Auto-Sell" (a locked/unlock purchase) while
	-- dockSpeed is still 0, then becomes the repeatable "Robot Speed"
	-- upgrade once bought. dockActiveAlpha dims the dock box itself the
	-- same way until then. Fleet-wide, so this stays a flat Economy stat.
	local dockSpeedAffordable = economy:getNumber('dockSpeedAffordable')
	local dockSpeedCostLabel = economy:getString('dockSpeedCostLabel')
	local dockSpeedLabel = economy:getString('dockSpeedLabel')
	local dockActiveAlpha = economy:getNumber('dockActiveAlpha')
	if dockSpeedProp and dockSpeedAffordable and dockSpeedCostLabel and dockSpeedLabel then
		local maxed = dockSpeedProp.value >= MOVE_SPEED_MAX
		local level = levelsBought(dockSpeedProp.value, MOVE_SPEED_STEP, MOVE_SPEED_START)
		local cost = upgradeCost(level)
		dockSpeedAffordable.value = (currencyValue >= cost and not maxed) and 1 or DIMMED_ALPHA
		dockSpeedCostLabel.value = maxed and 'MAX' or tostring(cost)
		if dockSpeedProp.value <= 0 then
			dockSpeedLabel.value = 'Auto-Sell'
		else
			dockSpeedLabel.value = 'Robot Speed ' .. tostring(math.floor(dockSpeedProp.value))
		end
	end
	if dockActiveAlpha then
		dockActiveAlpha.value = (dockSpeedProp and dockSpeedProp.value > 0) and 1 or DIMMED_ALPHA
	end

	-- Beach Boy purchase panel: repeatable, so just affordable/not - never
	-- "owned" now that buying one doesn't stop you buying another
	local beachBoyCount = economy:getNumber('beachBoyCount')
	local beachBoyAffordable = economy:getNumber('beachBoyAffordable')
	local beachBoyCostLabel = economy:getString('beachBoyCostLabel')
	if beachBoyCount and beachBoyAffordable and beachBoyCostLabel then
		local cost = beachBoyCost(beachBoyCount.value)
		beachBoyAffordable.value = (currencyValue >= cost) and 1 or DIMMED_ALPHA
		beachBoyCostLabel.value = tostring(cost)
	end

	-- Steel Seeker purchase panel: same repeatable shape as Beach Boy
	local steelSeekerCount = economy:getNumber('steelSeekerCount')
	local steelSeekerAffordable = economy:getNumber('steelSeekerAffordable')
	local steelSeekerCostLabel = economy:getString('steelSeekerCostLabel')
	if steelSeekerCount and steelSeekerAffordable and steelSeekerCostLabel then
		local cost = steelSeekerCost(steelSeekerCount.value)
		steelSeekerAffordable.value = (currencyValue >= cost) and 1 or DIMMED_ALPHA
		steelSeekerCostLabel.value = tostring(cost)
	end

	-- Steel Seeker discovery: a one-way unlock once lifetime earnings
	-- cross the threshold (lifetimeCurrencyEarned only ever grows, so
	-- this naturally stays unlocked once true - no separate latch needed).
	local steelSeekerDiscovered = economy:getNumber('steelSeekerDiscovered')
	if steelSeekerDiscovered and lifetimeCurrencyEarned then
		steelSeekerDiscovered.value = (lifetimeCurrencyEarned.value >= STEEL_SEEKER_DISCOVERY_THRESHOLD) and 1 or 0
	end

	-- Tab bar: which tab is highlighted, which panel group is shown
	-- (displayValue flex/none - takes the group fully out of layout,
	-- unlike opacity, so hidden tabs leave no gap), and whether the
	-- Steel Seeker tab/purchase panel exist in the layout at all yet.
	local activeTabIsRobots = economy:getNumber('activeTabIsRobots')
	local onRobotsTab = (activeTabIsRobots ~= nil) and (activeTabIsRobots.value > 0)
	local onBeachCrew = (selectedClassName ~= nil) and (selectedClassName.value == 'beachCrew')

	local beachCrewTabAlpha = economy:getNumber('beachCrewTabAlpha')
	if beachCrewTabAlpha then
		beachCrewTabAlpha.value = (not onRobotsTab and onBeachCrew) and 1 or DIMMED_ALPHA
	end
	local steelSeekerTabAlpha = economy:getNumber('steelSeekerTabAlpha')
	if steelSeekerTabAlpha then
		steelSeekerTabAlpha.value = (not onRobotsTab and not onBeachCrew) and 1 or DIMMED_ALPHA
	end
	local robotsTabAlpha = economy:getNumber('robotsTabAlpha')
	if robotsTabAlpha then
		robotsTabAlpha.value = onRobotsTab and 1 or DIMMED_ALPHA
	end

	local classPanelsDisplay = economy:getNumber('classPanelsDisplay')
	if classPanelsDisplay then
		classPanelsDisplay.value = onRobotsTab and 1 or 0
	end
	local robotsPanelsDisplay = economy:getNumber('robotsPanelsDisplay')
	if robotsPanelsDisplay then
		robotsPanelsDisplay.value = onRobotsTab and 0 or 1
	end

	local discovered = (steelSeekerDiscovered ~= nil) and (steelSeekerDiscovered.value > 0)
	local steelSeekerTabDisplay = economy:getNumber('steelSeekerTabDisplay')
	if steelSeekerTabDisplay then
		steelSeekerTabDisplay.value = discovered and 0 or 1
	end
	local steelSeekerBuyPanelDisplay = economy:getNumber('steelSeekerBuyPanelDisplay')
	if steelSeekerBuyPanelDisplay then
		steelSeekerBuyPanelDisplay.value = discovered and 0 or 1
	end

	-- Live totals across every producer's own storage, for the bottom
	-- strip's fleet-wide summary, the Sell All preview, and whether
	-- selling would do anything right now
	local inventoryValue = economy:getNumber('inventoryValue')
	local storedCount = economy:getNumber('storedCount')
	local total = 0
	local count = 0
	if producers then
		for i = 1, producers.length do
			local storage = producers[i]:getList('storage')
			if storage then
				count += storage.length
				for j = 1, storage.length do
					local item = storage[j]
					local value = item:getNumber('value')
					if value then
						total = total + value.value
					end
				end
			end
		end
	end
	if inventoryValue then
		inventoryValue.value = total
	end
	if storedCount then
		storedCount.value = count
	end

	local sellAffordable = economy:getNumber('sellAffordable')
	if sellAffordable then
		sellAffordable.value = (total > 0) and 1 or DIMMED_ALPHA
	end

	-- Elbow Grease tutorial: force the shared tooltip onto the first
	-- producer every frame until the player has ever clicked one. Once
	-- taught, this stops touching Tooltip entirely and ordinary
	-- hover-driven show/hide (showTooltip.luau/hideTooltip.luau) takes
	-- back over.
	local elbowGreaseTaught = economy:getNumber('elbowGreaseTaught')
	if elbowGreaseTaught and elbowGreaseTaught.value <= 0 and producers and producers.length > 0 then
		local tutorialTarget = producers[1]
		local tRoamX = tutorialTarget:getNumber('roamX')
		local tRoamY = tutorialTarget:getNumber('roamY')
		local tooltip = context:globalViewModel('Tooltip')
		if tRoamX and tRoamY and tooltip then
			local tText = tooltip:getString('text')
			local tVisible = tooltip:getNumber('visible')
			local tX = tooltip:getNumber('x')
			local tY = tooltip:getNumber('y')
			if tText and tVisible and tX and tY then
				tText.value = TUTORIAL_TEXT
				tX.value = tRoamX.value + PRODUCER_WIDGET_CENTER
				tY.value = tRoamY.value + BEACH_AREA_ROOT_Y + PRODUCER_WIDGET_CENTER + TUTORIAL_ANCHOR_Y
				tVisible.value = 1
			end
		end
	end

	return true
end

return function(): Layout<ClockState>
	return {
		init = init,
		advance = advance,
	}
end
