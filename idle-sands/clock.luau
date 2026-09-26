--- The economy's clock, and now the actual producer: the beach item is an
--- always-on auto-collector. Every frame this ticks gameTime, and whenever
--- the current cycle's remaining time reaches zero it collects itemsPerDig
--- items on its own and restarts the cycle - no click required. Clicking
--- (main.luau) only nudges the cycle along faster; it never collects
--- directly. Also owns the cooldown ring fraction, the item's pop/pulse
--- scale (collect vs. click-boost use different magnitudes), each upgrade
--- panel's and Sell All's affordable state, the live inventory total, and
--- the fading "+$N" collect popup.

type ClockState = {
	context: Context?,
}

-- Common items turn up far more than rare ones. Weights are relative, not
-- percentages; higher-value items are deliberately rarer finds.
local ITEM_WEIGHTS = {
	{ name = 'BottleCap', weight = 30 },
	{ name = 'Nail', weight = 25 },
	{ name = 'TinCan', weight = 20 },
	{ name = 'Screw', weight = 12 },
	{ name = 'Key', weight = 8 },
	{ name = 'Coin', weight = 5 },
}

local TOTAL_WEIGHT = 0
for _, entry in ITEM_WEIGHTS do
	TOTAL_WEIGHT += entry.weight
end

local MAX_INVENTORY = 12
local UPGRADE_COST = 110
local PULSE_DURATION = 0.25
local COLLECT_PULSE_MAGNITUDE = 0.15
local DIMMED_ALPHA = 0.4
local POPUP_DURATION = 1.0

local ITEMS_PER_DIG_MAX = 6
local DIG_SPEED_MIN = 5
local ELBOW_GREASE_MAX = 10

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

local function pickItemName(): string
	local roll = math.random() * TOTAL_WEIGHT
	local cumulative = 0
	for _, entry in ITEM_WEIGHTS do
		cumulative += entry.weight
		if roll <= cumulative then
			return entry.name
		end
	end
	return ITEM_WEIGHTS[1].name
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

	local gameTime = economy:getNumber('gameTime')
	if gameTime then
		gameTime.value = gameTime.value + seconds
	end

	-- The producer cycle: ticks down on its own, collects and restarts
	-- when it reaches zero. Clicking (main.luau) only pulls lastDigTime
	-- forward to shorten what's left; it never collects.
	local digSpeed = economy:getNumber('digSpeedSeconds')
	local lastDigTime = economy:getNumber('lastDigTime')
	local cooldownFraction = economy:getNumber('digCooldownFraction')
	if gameTime and digSpeed and lastDigTime and cooldownFraction and digSpeed.value > 0 then
		local remaining = digSpeed.value - (gameTime.value - lastDigTime.value)
		if remaining <= 0 then
			local inventory = economy:getList('inventory')
			local itemsPerDigProp = economy:getNumber('itemsPerDig')
			local itemsPerDig = if itemsPerDigProp then math.floor(itemsPerDigProp.value) else 1

			local collectedTotal = 0
			if inventory then
				for _ = 1, itemsPerDig do
					if inventory.length >= MAX_INVENTORY then
						break
					end
					local item = Data.Item.new(pickItemName())
					inventory:push(item)
					local value = item:getNumber('value')
					if value then
						collectedTotal += value.value
					end
				end
			end

			lastDigTime.value = gameTime.value
			remaining = digSpeed.value

			local lastPulseTime = economy:getNumber('lastPulseTime')
			local pulseMagnitude = economy:getNumber('pulseMagnitude')
			if lastPulseTime and pulseMagnitude then
				lastPulseTime.value = gameTime.value
				pulseMagnitude.value = COLLECT_PULSE_MAGNITUDE
			end

			local lastDigPopupTime = economy:getNumber('lastDigPopupTime')
			local digPopupText = economy:getString('digPopupText')
			if lastDigPopupTime and digPopupText and collectedTotal > 0 then
				lastDigPopupTime.value = gameTime.value
				digPopupText.value = '+$' .. tostring(collectedTotal)
			end
		end

		cooldownFraction.value = clamp01(remaining / digSpeed.value)
	end

	local itemPulseScale = economy:getNumber('itemPulseScale')
	local lastPulseTime = economy:getNumber('lastPulseTime')
	local pulseMagnitude = economy:getNumber('pulseMagnitude')
	if itemPulseScale and lastPulseTime and pulseMagnitude and gameTime then
		local sincePulse = gameTime.value - lastPulseTime.value
		local pulse = 0
		if sincePulse >= 0 and sincePulse < PULSE_DURATION then
			pulse = 1 - (sincePulse / PULSE_DURATION)
		end
		itemPulseScale.value = 1 + pulse * pulseMagnitude.value
	end

	-- Upgrade panels: affordable/maxed state
	local currency = economy:getNumber('currency')
	local canAfford = currency ~= nil and currency.value >= UPGRADE_COST

	local itemsPerDig = economy:getNumber('itemsPerDig')
	local itemsPerDigAffordable = economy:getNumber('itemsPerDigAffordable')
	local itemsPerDigCostLabel = economy:getString('itemsPerDigCostLabel')
	if itemsPerDig and itemsPerDigAffordable and itemsPerDigCostLabel then
		local maxed = itemsPerDig.value >= ITEMS_PER_DIG_MAX
		itemsPerDigAffordable.value = (canAfford and not maxed) and 1 or DIMMED_ALPHA
		itemsPerDigCostLabel.value = maxed and 'MAX' or tostring(UPGRADE_COST)
	end

	local digSpeedSeconds = economy:getNumber('digSpeedSeconds')
	local digSpeedAffordable = economy:getNumber('digSpeedAffordable')
	local digSpeedCostLabel = economy:getString('digSpeedCostLabel')
	if digSpeedSeconds and digSpeedAffordable and digSpeedCostLabel then
		local maxed = digSpeedSeconds.value <= DIG_SPEED_MIN
		digSpeedAffordable.value = (canAfford and not maxed) and 1 or DIMMED_ALPHA
		digSpeedCostLabel.value = maxed and 'MAX' or tostring(UPGRADE_COST)
	end

	local elbowGreasePercent = economy:getNumber('elbowGreasePercent')
	local elbowGreaseAffordable = economy:getNumber('elbowGreaseAffordable')
	local elbowGreaseCostLabel = economy:getString('elbowGreaseCostLabel')
	if elbowGreasePercent and elbowGreaseAffordable and elbowGreaseCostLabel then
		local maxed = elbowGreasePercent.value >= ELBOW_GREASE_MAX
		elbowGreaseAffordable.value = (canAfford and not maxed) and 1 or DIMMED_ALPHA
		elbowGreaseCostLabel.value = maxed and 'MAX' or tostring(UPGRADE_COST)
	end

	-- Live inventory total, for the Sell All preview, and whether selling
	-- would do anything right now
	local inventory = economy:getList('inventory')
	local inventoryValue = economy:getNumber('inventoryValue')
	local total = 0
	if inventory and inventoryValue then
		for i = 1, inventory.length do
			local item = inventory[i]
			local value = item:getNumber('value')
			if value then
				total = total + value.value
			end
		end
		inventoryValue.value = total
	end

	local sellAffordable = economy:getNumber('sellAffordable')
	if sellAffordable then
		sellAffordable.value = (total > 0) and 1 or DIMMED_ALPHA
	end

	-- Collect popup ("+$36"), fading out after POPUP_DURATION seconds
	local lastDigPopupTime = economy:getNumber('lastDigPopupTime')
	local digPopupAlpha = economy:getNumber('digPopupAlpha')
	if lastDigPopupTime and digPopupAlpha and gameTime then
		local sincePopup = gameTime.value - lastDigPopupTime.value
		digPopupAlpha.value = clamp01(1 - (sincePopup / POPUP_DURATION))
	end

	return true
end

return function(): Layout<ClockState>
	return {
		init = init,
		advance = advance,
	}
end
