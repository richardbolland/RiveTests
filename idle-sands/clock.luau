--- The economy's clock. An invisible, zero-size layout script whose only job
--- is to accumulate real elapsed seconds into Economy.gameTime, so every
--- other script has a reliable time source that advances with --advance in
--- headless testing and with real time in the live preview and web build.
--- Grows into the full driver (bot timers, auto-sell) in later milestones.

type ClockState = {
	context: Context?,
}

local function init(self: ClockState, context: Context): boolean
	self.context = context
	return true
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

	return true
end

return function(): Layout<ClockState>
	return {
		init = init,
		advance = advance,
	}
end
