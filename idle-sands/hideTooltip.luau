--- Universal tooltip: hides the shared Tooltip overlay, on a "pointer
--- exits this element" listener. Takes no inputs - pair it with
--- showTooltip.luau's matching enter listener on any hoverable element.

type HideTooltipState = {
	context: Context?,
}

local function init(self: HideTooltipState, context: Context): boolean
	self.context = context
	return true
end

local function performAction(self: HideTooltipState, listenerContext: ListenerContext)
	local context = self.context
	if not context then
		return
	end

	local tooltip = context:globalViewModel('Tooltip')
	if not tooltip then
		return
	end

	local visible = tooltip:getNumber('visible')
	if visible then
		visible.value = 0
	end
end

return function(): ListenerAction<HideTooltipState>
	return {
		init = init,
		performAction = performAction,
	}
end
