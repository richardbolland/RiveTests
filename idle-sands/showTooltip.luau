--- Universal tooltip: shows the shared Tooltip overlay (scene.rml) near
--- whatever hoverable element wired this up, via a "pointer enters this
--- element" listener. One script backs every tooltip in the game - a
--- static side panel and a roaming producer alike - so adding a new one
--- is two listeners (this + hideTooltip.luau) and two ScriptInput values,
--- never new script logic.
---
--- anchorX/anchorY are added on top of a base position that depends on
--- what this listener's host artboard is bound to:
--- - no view model, or one without roamX/roamY (a static panel on the
---   root IdleSands artboard): base is (0, 0), so anchorX/anchorY are
---   plain root-artboard coordinates.
--- - a view model WITH roamX/roamY (a ProducerWidget row): base is that
---   producer's own current position, converted from its roamX/roamY
---   (BeachArea-local) into root-artboard coordinates, so the tooltip
---   follows a moving target without every caller needing to know that.

type ShowTooltipState = {
	context: Context?,
	text: Input<string>?,
	anchorX: Input<number>?,
	anchorY: Input<number>?,
}

-- ProducerWidget is 110x110 (producers.rml); BeachArea sits directly below
-- the 64pt TopBar at the root artboard's left edge (scene.rml), so a
-- producer's root-space centre is its own roamX/roamY (BeachArea-local,
-- top-left of the widget) plus these two fixed offsets. Revisit both if
-- either layout changes.
local PRODUCER_WIDGET_CENTER = 55
local BEACH_AREA_ROOT_Y = 64

local function init(self: ShowTooltipState, context: Context): boolean
	self.context = context
	return true
end

local function performAction(self: ShowTooltipState, listenerContext: ListenerContext)
	local context = self.context
	local text = self.text
	local anchorX = self.anchorX
	local anchorY = self.anchorY
	if not context or not text then
		return
	end

	local tooltip = context:globalViewModel('Tooltip')
	if not tooltip then
		return
	end

	local textProp = tooltip:getString('text')
	local visible = tooltip:getNumber('visible')
	local xProp = tooltip:getNumber('x')
	local yProp = tooltip:getNumber('y')
	if not textProp or not visible or not xProp or not yProp then
		return
	end

	local baseX, baseY = 0, 0
	local vm = context:viewModel()
	if vm then
		local roamX = vm:getNumber('roamX')
		local roamY = vm:getNumber('roamY')
		if roamX and roamY then
			baseX = roamX.value + PRODUCER_WIDGET_CENTER
			baseY = roamY.value + BEACH_AREA_ROOT_Y + PRODUCER_WIDGET_CENTER
		end
	end

	textProp.value = text
	xProp.value = baseX + (if anchorX then anchorX else 0)
	yProp.value = baseY + (if anchorY then anchorY else 0)
	visible.value = 1
end

return function(): ListenerAction<ShowTooltipState>
	return {
		init = init,
		performAction = performAction,
	}
end
