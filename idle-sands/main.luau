--- The item is always auto-collecting on its own (clock.luau owns that).
--- Clicking it never collects directly - it's Elbow Grease: pitching in
--- yourself cuts Economy.elbowGreasePercent (an upgradeable stat, stored as
--- whole percentage points) off the FULL cycle length, so every click is
--- worth the same amount regardless of when in the cycle it lands (a
--- percentage of what's *remaining* would front-load all the value into
--- the first click or two and make late-cycle clicks feel like nothing).
--- It also means the boost automatically scales down if digSpeedSeconds
--- is upgraded to a shorter cycle, with no rebalancing needed.

type BoostState = {
	context: Context?,
}

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
	local elbowGreasePercent = economy:getNumber('elbowGreasePercent')
	if not digSpeed or not gameTime or not lastDigTime or not elbowGreasePercent then
		return
	end

	local remaining = digSpeed.value - (gameTime.value - lastDigTime.value)
	if remaining <= 0 then
		-- About to auto-collect this frame anyway; nothing to speed up.
		return
	end

	-- Cutting X% of the full cycle off what's left is the same as moving
	-- lastDigTime backward (simulating more time having passed since the
	-- last collect) by that same amount, since
	-- remaining = digSpeed - (gameTime - lastDigTime). Clamp so a click
	-- near the very end of a cycle can't push remaining negative.
	local cut = math.min(remaining, digSpeed.value * (elbowGreasePercent.value / 100))
	lastDigTime.value -= cut

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
