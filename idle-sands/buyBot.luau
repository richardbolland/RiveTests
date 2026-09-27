--- Shared bot-purchase script, parameterised per button via ScriptInput* so
--- one script backs every "buy a bot" panel (Beach Boy, and Steel Seeker
--- later) rather than a near-identical file per bot. Repeatable: each
--- purchase adds another copy of the same producer template and gets
--- pricier, on its own Cost(n) = base * growth^n curve (n = countStatName's
--- current value), the same shape as the upgrade panels but tracked as an
--- owned COUNT rather than a capped stat level, since there's no ceiling on
--- how many of a bot you can buy.

type BuyBotState = {
	context: Context?,
	instanceName: Input<string>?,
	countStatName: Input<string>?,
	baseCost: Input<number>?,
	growth: Input<number>?,
}

-- New purchases spawn at the template's fixed roam position; without a
-- jitter every copy of the same bot would appear stacked exactly on top of
-- each other until roaming (which only re-targets on arrival) spread them
-- out on its own.
local SPAWN_JITTER = 40

local function init(self: BuyBotState, context: Context): boolean
	self.context = context
	return true
end

local function performAction(self: BuyBotState, listenerContext: ListenerContext)
	if not listenerContext:isPointerEvent() then
		return
	end

	local context = self.context
	local instanceName = self.instanceName
	local countStatName = self.countStatName
	local baseCost = self.baseCost
	local growth = self.growth
	if not context or not instanceName or not countStatName or not baseCost or not growth then
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

	local count = economy:getNumber(countStatName)
	local currency = economy:getNumber('currency')
	local producers = economy:getList('producers')
	if not count or not currency or not producers then
		return
	end

	local cost = math.floor(baseCost * (growth ^ count.value) + 0.5)
	if currency.value < cost then
		return
	end

	currency.value -= cost
	count.value += 1
	producers:push(Data.Producer.new(instanceName))

	local newProducer = producers[producers.length]
	local roamX = newProducer:getNumber('roamX')
	local roamY = newProducer:getNumber('roamY')
	local roamTargetX = newProducer:getNumber('roamTargetX')
	local roamTargetY = newProducer:getNumber('roamTargetY')
	if roamX and roamY and roamTargetX and roamTargetY then
		local jitterX = (math.random() - 0.5) * 2 * SPAWN_JITTER
		local jitterY = (math.random() - 0.5) * 2 * SPAWN_JITTER
		roamX.value += jitterX
		roamY.value += jitterY
		roamTargetX.value += jitterX
		roamTargetY.value += jitterY
	end
end

return function(): ListenerAction<BuyBotState>
	return {
		init = init,
		performAction = performAction,
	}
end
