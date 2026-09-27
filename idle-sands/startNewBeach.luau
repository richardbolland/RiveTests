--- The end screen's only button. Resets the current beach - currency,
--- items collected and the elapsed-time clock - and raises the goal for
--- the next one (clock.luau computes runGoal from runNumber). Everything
--- else carries over untouched: every bot and upgrade already bought
--- stays bought, and Steel Seeker's unlock (once earned) never re-locks.
--- Turning runComplete back off is what un-freezes clock.luau's producer
--- loop and hides the end screen overlay again.

type StartNewBeachState = {
	context: Context?,
}

local function init(self: StartNewBeachState, context: Context): boolean
	self.context = context
	return true
end

local function performAction(self: StartNewBeachState, listenerContext: ListenerContext)
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
		currency.value = 0
	end

	local runEarnings = economy:getNumber('runEarnings')
	if runEarnings then
		runEarnings.value = 0
	end

	local runItemsCollected = economy:getNumber('runItemsCollected')
	if runItemsCollected then
		runItemsCollected.value = 0
	end

	local runNumber = economy:getNumber('runNumber')
	if runNumber then
		runNumber.value += 1
	end

	local gameTime = economy:getNumber('gameTime')
	local runStartTime = economy:getNumber('runStartTime')
	if runStartTime and gameTime then
		runStartTime.value = gameTime.value
	end

	-- Last, so clock.luau's frozen-beach checks above all still read the
	-- old (complete) state for the rest of this same frame; the very next
	-- frame it recomputes runGoal/runStatusLabel/runElapsedLabel fresh and
	-- resumes the producers loop.
	local runComplete = economy:getNumber('runComplete')
	if runComplete then
		runComplete.value = 0
	end
end

return function(): ListenerAction<StartNewBeachState>
	return {
		init = init,
		performAction = performAction,
	}
end
