--- The economy's clock. Runs every frame and owns everything that is
--- "computed" rather than "reacted to": gameTime, the dig cooldown ring
--- fraction, the item's pop/pulse scale (on dig and on becoming ready
--- again), each upgrade panel's affordable/maxed state, and the live
--- inventory total shown on Sell All. Grows into the full driver (bot
--- timers, auto-sell) in later milestones.

type ClockState = {
	context: Context?,
	wasOnCooldown: boolean?,
}

local UPGRADE_COST = 110
local PULSE_DURATION = 0.25
local PULSE_SCALE = 0.15
local DIMMED_ALPHA = 0.4

local ITEMS_PER_DIG_MAX = 6
local DIG_SPEED_MIN = 5
local AUTO_SELL_MIN = 5

local function init(self: ClockState, context: Context): boolean
	self.context = context
	self.wasOnCooldown = false
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

	-- Dig cooldown ring
	local digSpeed = economy:getNumber('digSpeedSeconds')
	local lastDigTime = economy:getNumber('lastDigTime')
	local cooldownFraction = economy:getNumber('digCooldownFraction')
	local isOnCooldown = false
	if gameTime and digSpeed and lastDigTime and cooldownFraction and digSpeed.value > 0 then
		local elapsed = gameTime.value - lastDigTime.value
		local remaining = digSpeed.value - elapsed
		local fraction = clamp01(remaining / digSpeed.value)
		cooldownFraction.value = fraction
		isOnCooldown = fraction > 0
	end

	-- Ready pulse: the moment cooldown finishes, stamp lastPulseTime so the
	-- item pops. (The dig itself also stamps lastPulseTime, in main.luau.)
	local lastPulseTime = economy:getNumber('lastPulseTime')
	if lastPulseTime and gameTime and self.wasOnCooldown and not isOnCooldown then
		lastPulseTime.value = gameTime.value
	end
	self.wasOnCooldown = isOnCooldown

	local itemPulseScale = economy:getNumber('itemPulseScale')
	if itemPulseScale and lastPulseTime and gameTime then
		local sincePulse = gameTime.value - lastPulseTime.value
		local pulse = 0
		if sincePulse >= 0 and sincePulse < PULSE_DURATION then
			pulse = 1 - (sincePulse / PULSE_DURATION)
		end
		itemPulseScale.value = 1 + pulse * PULSE_SCALE
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

	local autoSellSeconds = economy:getNumber('autoSellSeconds')
	local autoSellAffordable = economy:getNumber('autoSellAffordable')
	local autoSellCostLabel = economy:getString('autoSellCostLabel')
	if autoSellSeconds and autoSellAffordable and autoSellCostLabel then
		local maxed = autoSellSeconds.value <= AUTO_SELL_MIN
		autoSellAffordable.value = (canAfford and not maxed) and 1 or DIMMED_ALPHA
		autoSellCostLabel.value = maxed and 'MAX' or tostring(UPGRADE_COST)
	end

	-- Live inventory total, for the Sell All preview
	local inventory = economy:getList('inventory')
	local inventoryValue = economy:getNumber('inventoryValue')
	if inventory and inventoryValue then
		local total = 0
		for i = 1, inventory.length do
			local item = inventory[i]
			local value = item:getNumber('value')
			if value then
				total = total + value.value
			end
		end
		inventoryValue.value = total
	end

	return true
end

return function(): Layout<ClockState>
	return {
		init = init,
		advance = advance,
	}
end
