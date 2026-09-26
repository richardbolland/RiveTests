--- The economy's clock. Runs every frame. Iterates Economy.producers,
--- running the identical auto-collect cycle for each row (the free starter,
--- then every purchased bot) - same pattern as the inventory list, so
--- adding a bot later is one more list entry, not more duplicated logic.
--- Each producer owns its own cycle/pulse/popup state and its own storage
--- list; only digSpeedSeconds, itemsPerDig, elbowGreasePercent and
--- storageCapacity are shared upgrades applying to every producer alike -
--- storageCapacity lives as a mirrored field on each Producer instance
--- (so storageLabel can be computed locally) but this script is the only
--- writer of it, syncing it from Economy.storageCapacity every frame, the
--- same way every other shared upgrade works. Also owns each upgrade
--- panel's and Sell All's affordable state, the live storage totals, and
--- whether Beach Boy is affordable to buy.

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
}

local PULSE_DURATION = 0.25
local COLLECT_PULSE_MAGNITUDE = 0.15
local DIMMED_ALPHA = 0.4
local POPUP_DURATION = 1.0

-- Upgrade shape: all three take 5 uniform steps from start to cap, so a
-- shared Cost(n) = base * growth^n curve behaves the same way for each.
-- These must match the ScriptInput* values on the matching Buy* listener
-- in scene.rml exactly, or the displayed price will disagree with what
-- upgrade.luau actually charges.
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

local BEACH_BOY_COST = 458

local function levelsBought(currentValue: number, step: number, startValue: number): number
	return math.floor(math.abs(currentValue - startValue) / math.abs(step) + 0.5)
end

local function upgradeCost(level: number): number
	return math.floor(UPGRADE_BASE_COST * (UPGRADE_GROWTH ^ level) + 0.5)
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

	local digSpeed = economy:getNumber('digSpeedSeconds')
	local itemsPerDigProp = economy:getNumber('itemsPerDig')
	local itemsPerDig = if itemsPerDigProp then math.floor(itemsPerDigProp.value) else 1
	local storageCapacityProp = economy:getNumber('storageCapacity')
	local storageCapacityValue = if storageCapacityProp then storageCapacityProp.value else STORAGE_CAPACITY_START

	-- Every producer runs the same cycle: tick down, collect and restart
	-- when it reaches zero, into its OWN onboard storage. Clicking
	-- (main.luau, inside the row) either pulls a producer's own
	-- lastDigTime forward to shorten what's left, or - once that
	-- producer's storage is full - sells it on the spot; it never
	-- collects directly either way. A full producer simply stops
	-- collecting (the cycle freezes rather than resets) until its owner
	-- empties it.
	local producers = economy:getList('producers')
	if producers and digSpeed and digSpeed.value > 0 then
		for i = 1, producers.length do
			local producer = producers[i]
			local storage = producer:getList('storage')
			local storageCapacity = producer:getNumber('storageCapacity')
			if storageCapacity then
				storageCapacity.value = storageCapacityValue
			end
			local isFull = (storage ~= nil) and (storageCapacity ~= nil) and (storage.length >= storageCapacity.value)

			local lastDigTime = producer:getNumber('lastDigTime')
			local cooldownFraction = producer:getNumber('digCooldownFraction')
			if lastDigTime and cooldownFraction then
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
			local roamX = producer:getNumber('roamX')
			local roamY = producer:getNumber('roamY')
			local roamTargetX = producer:getNumber('roamTargetX')
			local roamTargetY = producer:getNumber('roamTargetY')
			if roamX and roamY and roamTargetX and roamTargetY then
				local dx = roamTargetX.value - roamX.value
				local dy = roamTargetY.value - roamY.value
				local dist = math.sqrt(dx * dx + dy * dy)
				if dist < ROAM_ARRIVE_THRESHOLD then
					roamTargetX.value = ROAM_MIN_X + math.random() * (ROAM_MAX_X - ROAM_MIN_X)
					roamTargetY.value = ROAM_MIN_Y + math.random() * (ROAM_MAX_Y - ROAM_MIN_Y)
				else
					local step = math.min(ROAM_SPEED * seconds, dist)
					roamX.value += (dx / dist) * step
					roamY.value += (dy / dist) * step
				end
			end
		end
	end

	-- Upgrade panels: affordable/maxed state, each priced on its own
	-- Cost(n) = base * growth^n curve rather than one shared flat price
	local currency = economy:getNumber('currency')
	local currencyValue = if currency then currency.value else 0

	local itemsPerDigAffordable = economy:getNumber('itemsPerDigAffordable')
	local itemsPerDigCostLabel = economy:getString('itemsPerDigCostLabel')
	if itemsPerDigProp and itemsPerDigAffordable and itemsPerDigCostLabel then
		local maxed = itemsPerDigProp.value >= ITEMS_PER_DIG_MAX
		local level = levelsBought(itemsPerDigProp.value, ITEMS_PER_DIG_STEP, ITEMS_PER_DIG_START)
		local cost = upgradeCost(level)
		itemsPerDigAffordable.value = (currencyValue >= cost and not maxed) and 1 or DIMMED_ALPHA
		itemsPerDigCostLabel.value = maxed and 'MAX' or tostring(cost)
	end

	local digSpeedAffordable = economy:getNumber('digSpeedAffordable')
	local digSpeedCostLabel = economy:getString('digSpeedCostLabel')
	if digSpeed and digSpeedAffordable and digSpeedCostLabel then
		local maxed = digSpeed.value <= DIG_SPEED_MIN
		local level = levelsBought(digSpeed.value, DIG_SPEED_STEP, DIG_SPEED_START)
		local cost = upgradeCost(level)
		digSpeedAffordable.value = (currencyValue >= cost and not maxed) and 1 or DIMMED_ALPHA
		digSpeedCostLabel.value = maxed and 'MAX' or tostring(cost)
	end

	local elbowGreasePercent = economy:getNumber('elbowGreasePercent')
	local elbowGreaseAffordable = economy:getNumber('elbowGreaseAffordable')
	local elbowGreaseCostLabel = economy:getString('elbowGreaseCostLabel')
	if elbowGreasePercent and elbowGreaseAffordable and elbowGreaseCostLabel then
		local maxed = elbowGreasePercent.value >= ELBOW_GREASE_MAX
		local level = levelsBought(elbowGreasePercent.value, ELBOW_GREASE_STEP, ELBOW_GREASE_START)
		local cost = upgradeCost(level)
		elbowGreaseAffordable.value = (currencyValue >= cost and not maxed) and 1 or DIMMED_ALPHA
		elbowGreaseCostLabel.value = maxed and 'MAX' or tostring(cost)
	end

	local storageCapacityAffordable = economy:getNumber('storageCapacityAffordable')
	local storageCapacityCostLabel = economy:getString('storageCapacityCostLabel')
	if storageCapacityProp and storageCapacityAffordable and storageCapacityCostLabel then
		local maxed = storageCapacityProp.value >= STORAGE_CAPACITY_MAX
		local level = levelsBought(storageCapacityProp.value, STORAGE_CAPACITY_STEP, STORAGE_CAPACITY_START)
		local cost = upgradeCost(level)
		storageCapacityAffordable.value = (currencyValue >= cost and not maxed) and 1 or DIMMED_ALPHA
		storageCapacityCostLabel.value = maxed and 'MAX' or tostring(cost)
	end

	-- Beach Boy purchase panel: affordable/owned state
	local beachBoyOwned = economy:getNumber('beachBoyOwned')
	local beachBoyAffordable = economy:getNumber('beachBoyAffordable')
	local beachBoyCostLabel = economy:getString('beachBoyCostLabel')
	if beachBoyOwned and beachBoyAffordable and beachBoyCostLabel then
		local owned = beachBoyOwned.value >= 1
		local afford = currencyValue >= BEACH_BOY_COST
		beachBoyAffordable.value = (afford and not owned) and 1 or DIMMED_ALPHA
		beachBoyCostLabel.value = owned and 'Owned' or tostring(BEACH_BOY_COST)
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

	return true
end

return function(): Layout<ClockState>
	return {
		init = init,
		advance = advance,
	}
end
