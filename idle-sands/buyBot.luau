--- Shared bot-purchase script, parameterised per button via ScriptInput* so
--- one script backs every "buy a bot" panel (Beach Boy, and Steel Seeker
--- later) rather than a near-identical file per bot.

type BuyBotState = {
	context: Context?,
	instanceName: Input<string>?,
	cost: Input<number>?,
	ownedFlagName: Input<string>?,
}

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
	local cost = self.cost
	local ownedFlagName = self.ownedFlagName
	if not context or not instanceName or not cost or not ownedFlagName then
		return
	end

	local economy = context:globalViewModel('Economy')
	if not economy then
		return
	end

	local owned = economy:getNumber(ownedFlagName)
	local currency = economy:getNumber('currency')
	local producers = economy:getList('producers')
	if not owned or not currency or not producers then
		return
	end

	if owned.value >= 1 then
		return
	end

	if currency.value < cost then
		return
	end

	currency.value -= cost
	owned.value = 1
	producers:push(Data.Producer.new(instanceName))
end

return function(): ListenerAction<BuyBotState>
	return {
		init = init,
		performAction = performAction,
	}
end
