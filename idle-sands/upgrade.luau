--- One shared upgrade-purchase script for all upgrade panels. Which stat,
--- by how much, and at what price comes from RML via ScriptInput*
--- children, so the same script backs items-per-dig, dig speed, Elbow
--- Grease, storage capacity and dock speed without near-identical files.
---
--- Cost follows the standard incremental-game curve, Cost(n) = base *
--- growth^n where n is how many levels of THIS upgrade have already been
--- bought - cheap first purchase, exponentially pricier from there. n is
--- derived from the stat's current value rather than stored separately,
--- since every upgrade here takes uniform steps from a known start:
--- n = |current - startValue| / |step|, where startValue is minValue for
--- an increasing stat (step > 0) or maxValue for a decreasing one.
---
--- classScoped (optional, truthy = 1) marks a stat that belongs to
--- whichever robot class is currently selected (Economy.selectedClassName)
--- rather than to Economy directly - itemsPerDig, digSpeedSeconds,
--- elbowGreasePercent and storageCapacity all vary per class now
--- (robotClasses.rml), while dockSpeed stays fleet-wide and omits this
--- input. A classScoped purchase reads/writes the matching RobotClass
--- instance's own field: writing to Economy's copy would just be
--- overwritten by clock.luau's next-frame mirror refresh, since that
--- mirror only ever flows outward (selected class -> Economy display),
--- never back.

type UpgradeState = {
	context: Context?,
	statName: Input<string>?,
	step: Input<number>?,
	minValue: Input<number>?,
	maxValue: Input<number>?,
	baseCost: Input<number>?,
	growth: Input<number>?,
	classScoped: Input<number>?,
}

local function findRobotClass(economy: ViewModel, className: string): ViewModel?
	local robotClasses = economy:getList('robotClasses')
	if not robotClasses then
		return nil
	end
	for i = 1, robotClasses.length do
		local candidate = robotClasses[i]
		local candidateName = candidate:getString('className')
		if candidateName and candidateName.value == className then
			return candidate
		end
	end
	return nil
end

local function init(self: UpgradeState, context: Context): boolean
	self.context = context
	return true
end

local function levelsBought(currentValue: number, step: number, minValue: number, maxValue: number): number
	local startValue = if step > 0 then minValue else maxValue
	return math.floor(math.abs(currentValue - startValue) / math.abs(step) + 0.5)
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
	local baseCost = self.baseCost
	local growth = self.growth
	if not context or not statName or not step or not minValue or not maxValue or not baseCost or not growth then
		return
	end

	local economy = context:globalViewModel('Economy')
	if not economy then
		return
	end

	local runComplete = economy:getNumber('runComplete')
	if runComplete and runComplete.value > 0 then
		return
	end

	local target = economy
	local classScoped = self.classScoped
	if classScoped and classScoped > 0 then
		local selectedClassName = economy:getString('selectedClassName')
		if not selectedClassName then
			return
		end
		local robotClass = findRobotClass(economy, selectedClassName.value)
		if not robotClass then
			return
		end
		target = robotClass
	end

	local currency = economy:getNumber('currency')
	local stat = target:getNumber(statName)
	if not currency or not stat then
		return
	end

	local lower = math.min(minValue, maxValue)
	local upper = math.max(minValue, maxValue)
	local newValue = math.min(upper, math.max(lower, stat.value + step))

	if newValue == stat.value then
		-- Already at the cap for this stat.
		return
	end

	local level = levelsBought(stat.value, step, minValue, maxValue)
	local cost = math.floor(baseCost * (growth ^ level) + 0.5)

	if currency.value < cost then
		return
	end

	currency.value = currency.value - cost
	stat.value = newValue
end

return function(): ListenerAction<UpgradeState>
	return {
		init = init,
		performAction = performAction,
	}
end
