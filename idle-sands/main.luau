--- Milestone 1: clicking the beach item pays out currency.
--- Grows into the full economy driver (bot timers, auto-sell) in later
--- milestones; for now it only reacts to the one click listener.

type CollectState = {
	context: Context?,
}

local function init(self: CollectState, context: Context): boolean
	self.context = context
	return true
end

local function performAction(self: CollectState, listenerContext: ListenerContext)
	if not listenerContext:isPointerEvent() then
		return
	end

	local context = self.context
	if not context then
		return
	end

	local economy = context:globalViewModel('Economy')
	if not economy then
		return
	end

	local currency = economy:getNumber('currency')
	if currency then
		currency.value = currency.value + 1
	end
end

return function(): ListenerAction<CollectState>
	return {
		init = init,
		performAction = performAction,
	}
end
