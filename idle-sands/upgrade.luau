--- One shared upgrade-purchase script for all three upgrade panels.
--- Which stat, and by how much, comes from RML via ScriptInput* children,
--- so the same script backs items-per-dig, dig speed and auto-sell timer
--- without three near-identical files.

type UpgradeState = {
	context: Context?,
	statName: Input<string>?,
	step: Input<number>?,
	minValue: Input<number>?,
	maxValue: Input<number>?,
}

local COST = 110

local function init(self: UpgradeState, context: Context): boolean
	self.context = context
	return true
end

local function performAction(self: UpgradeState, listenerContext: ListenerContext)
	if not listenerContext:isPointerEvent() then
		return
	end

	local context = self.context
	local statName = self.statName
	local step = self.step
	local minValue = self.minValue
	local maxValue = self.maxValue
	if not context or not statName or not step or not minValue or not maxValue then
		return
	end

	local economy = context:globalViewModel('Economy')
	if not economy then
		return
	end

	local currency = economy:getNumber('currency')
	local stat = economy:getNumber(statName)
	if not currency or not stat then
		return
	end

	if currency.value < COST then
		return
	end

	local lower = math.min(minValue, maxValue)
	local upper = math.max(minValue, maxValue)
	local newValue = math.min(upper, math.max(lower, stat.value + step))

	if newValue == stat.value then
		return
	end

	currency.value = currency.value - COST
	stat.value = newValue
end

return function(): ListenerAction<UpgradeState>
	return {
		init = init,
		performAction = performAction,
	}
end
