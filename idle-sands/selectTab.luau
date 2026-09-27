--- Shared click handler for the three side-panel tab buttons (Beach Crew,
--- Steel Seeker, Robots). Which tab a click selects comes from RML via
--- ScriptInput* children, so one script backs all three buttons.
---
--- Selecting a class tab sets Economy.selectedClassName (the class whose
--- stats the four upgrade panels mirror, clock.luau) and turns off the
--- Robots tab; selecting the Robots tab does the reverse. A click on the
--- Steel Seeker tab is ignored outright until Economy.steelSeekerDiscovered
--- flips on - the button is also hidden until then (steelSeekerTabDisplay),
--- but a state machine still delivers input to a display:none target, so
--- the guard here is what actually stops it.

type SelectTabState = {
	context: Context?,
	className: Input<string>?,
	isRobotsTab: Input<number>?,
}

local function init(self: SelectTabState, context: Context): boolean
	self.context = context
	return true
end

local function performAction(self: SelectTabState, listenerContext: ListenerContext)
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

	local activeTabIsRobots = economy:getNumber('activeTabIsRobots')
	if not activeTabIsRobots then
		return
	end

	local isRobotsTab = self.isRobotsTab
	if isRobotsTab and isRobotsTab > 0 then
		activeTabIsRobots.value = 1
		return
	end

	local className = self.className
	if not className then
		return
	end

	if className == 'steelSeeker' then
		local steelSeekerDiscovered = economy:getNumber('steelSeekerDiscovered')
		if not steelSeekerDiscovered or steelSeekerDiscovered.value <= 0 then
			-- Not unlocked yet - ignore, even though the button is also
			-- hidden via displayValue; belt and suspenders.
			return
		end
	end

	local selectedClassName = economy:getString('selectedClassName')
	if selectedClassName then
		selectedClassName.value = className
	end
	activeTabIsRobots.value = 0
end

return function(): ListenerAction<SelectTabState>
	return {
		init = init,
		performAction = performAction,
	}
end
