--- The item is always auto-collecting on its own (clock.luau owns that).
--- Clicking it never collects directly - it just cuts a percentage off
--- whatever time is left on the current cycle, so enough rapid clicks
--- speed a producer up noticeably without ever fully replacing the wait.

type BoostState = {
	context: Context?,
}

local CLICK_CUT_FRACTION = 0.2
local CLICK_PULSE_MAGNITUDE = 0.06

local function init(self: BoostState, context: Context): boolean
	self.context = context
	return true
end

local function performAction(self: BoostState, listenerContext: ListenerContext)
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

	local digSpeed = economy:getNumber('digSpeedSeconds')
	local gameTime = economy:getNumber('gameTime')
	local lastDigTime = economy:getNumber('lastDigTime')
	if not digSpeed or not gameTime or not lastDigTime then
		return
	end

	local remaining = digSpeed.value - (gameTime.value - lastDigTime.value)
	if remaining <= 0 then
		-- About to auto-collect this frame anyway; nothing to speed up.
		return
	end

	-- Cutting X% off what's left is the same as moving lastDigTime backward
	-- (simulating more time having passed since the last collect), since
	-- remaining = digSpeed - (gameTime - lastDigTime).
	lastDigTime.value -= remaining * CLICK_CUT_FRACTION

	local lastPulseTime = economy:getNumber('lastPulseTime')
	local pulseMagnitude = economy:getNumber('pulseMagnitude')
	if lastPulseTime and pulseMagnitude then
		lastPulseTime.value = gameTime.value
		pulseMagnitude.value = CLICK_PULSE_MAGNITUDE
	end
end

return function(): ListenerAction<BoostState>
	return {
		init = init,
		performAction = performAction,
	}
end
