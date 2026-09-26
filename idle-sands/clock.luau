--- The economy's clock. Ticks Economy.gameTime every frame, and computes
--- Economy.digCooldownFraction (1 = just dug, 0 = ready) from it, so the
--- beach item's cooldown ring has something live to bind to. Grows into the
--- full driver (bot timers, auto-sell) in later milestones.

type ClockState = {
	context: Context?,
}

local function init(self: ClockState, context: Context): boolean
	self.context = context
	return true
end

local function clamp01(value: number): number
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

local function advance(self: ClockState, seconds: number): boolean
	local context = self.context
	if not context then
		return true
	end

	local economy = context:globalViewModel('Economy')
	if not economy then
		return true
	end

	local gameTime = economy:getNumber('gameTime')
	if gameTime then
		gameTime.value = gameTime.value + seconds
	end

	local digSpeed = economy:getNumber('digSpeedSeconds')
	local lastDigTime = economy:getNumber('lastDigTime')
	local cooldownFraction = economy:getNumber('digCooldownFraction')
	if gameTime and digSpeed and lastDigTime and cooldownFraction and digSpeed.value > 0 then
		local elapsed = gameTime.value - lastDigTime.value
		local remaining = digSpeed.value - elapsed
		cooldownFraction.value = clamp01(remaining / digSpeed.value)
	end

	return true
end

return function(): Layout<ClockState>
	return {
		init = init,
		advance = advance,
	}
end
