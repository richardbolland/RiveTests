--- Lives inside ProducerWidget (producers.rml), so one copy of this script
--- backs every producer row - the free starter and every purchased bot
--- alike. The row is always auto-collecting on its own (clock.luau owns
--- that, iterating Economy.producers), and stops collecting once its own
--- onboard storage is full. What a click does depends on that fill state:
---
--- - Storage has room: it's Elbow Grease - pitching in yourself cuts
---   elbowGreasePercent (a shared, upgradeable stat) off the FULL cycle
---   length, so every click is worth the same amount regardless of when
---   in the cycle it lands (a percentage of what's *remaining* would
---   front-load all the value into the first click or two and make
---   late-cycle clicks feel like nothing). It also means the boost
---   automatically scales down if digSpeedSeconds is upgraded to a
---   shorter cycle, with no rebalancing needed.
--- - Storage is full: the robot can't collect anything more, so a click
---   empties and sells THIS robot's own storage on the spot, instead.
---   Sell All (sell.luau) does the same thing across every robot at once.

type BoostState = {
	context: Context?,
}

local CLICK_PULSE_MAGNITUDE = 0.06
local SELL_PULSE_MAGNITUDE = 0.15

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

	-- This row's own producer instance (bound via the artboard's viewModelId).
	local producer = context:viewModel() or context:rootViewModel()
	if not producer then
		return
	end

	local economy = context:globalViewModel('Economy')
	if not economy then
		return
	end

	-- First-ever click on any robot: the player now knows clicking does
	-- something, so the auto-shown tutorial tooltip (clock.luau) can stop
	-- teaching it. One flag for the whole fleet, not per-robot. Also hide
	-- the tooltip immediately rather than leaving clock.luau's last forced
	-- "visible=1" in place: without this, the tooltip stays on screen
	-- until the player's pointer happens to leave the robot afterward,
	-- since nothing else would tell it to close on the click itself.
	local elbowGreaseTaught = economy:getNumber('elbowGreaseTaught')
	if elbowGreaseTaught and elbowGreaseTaught.value <= 0 then
		elbowGreaseTaught.value = 1
		local tooltip = context:globalViewModel('Tooltip')
		local tooltipVisible = if tooltip then tooltip:getNumber('visible') else nil
		if tooltipVisible then
			tooltipVisible.value = 0
		end
	end

	local storage = producer:getList('storage')
	local storageCapacity = producer:getNumber('storageCapacity')
	if storage and storageCapacity and storage.length >= storageCapacity.value then
		-- Full: clicking sells this robot's own storage instead of boosting.
		local currency = economy:getNumber('currency')
		local gameTime = economy:getNumber('gameTime')
		if not currency then
			return
		end

		local total = 0
		for i = 1, storage.length do
			local item = storage[i]
			local value = item:getNumber('value')
			if value then
				total += value.value
			end
		end
		currency.value += total
		local lifetimeCurrencyEarned = economy:getNumber('lifetimeCurrencyEarned')
		if lifetimeCurrencyEarned then
			lifetimeCurrencyEarned.value += total
		end
		storage:clear()

		local lastPulseTime = producer:getNumber('lastPulseTime')
		local pulseMagnitude = producer:getNumber('pulseMagnitude')
		local lastDigPopupTime = producer:getNumber('lastDigPopupTime')
		local digPopupText = producer:getString('digPopupText')
		if gameTime and lastPulseTime and pulseMagnitude then
			lastPulseTime.value = gameTime.value
			pulseMagnitude.value = SELL_PULSE_MAGNITUDE
		end
		if gameTime and lastDigPopupTime and digPopupText and total > 0 then
			lastDigPopupTime.value = gameTime.value
			digPopupText.value = 'SOLD +$' .. tostring(total)
		end
		return
	end

	-- This robot's own class stats, not the Economy mirror (which reflects
	-- whichever tab is currently selected, not necessarily this robot's
	-- class - clicking a Steel Seeker while viewing the Beach Crew tab
	-- must still use Steel Seeker's own digSpeed/elbowGrease).
	local robotClassName = producer:getString('robotClass')
	local robotClasses = economy:getList('robotClasses')
	local robotClass = nil
	if robotClassName and robotClasses then
		for i = 1, robotClasses.length do
			local candidate = robotClasses[i]
			local candidateName = candidate:getString('className')
			if candidateName and candidateName.value == robotClassName.value then
				robotClass = candidate
				break
			end
		end
	end
	local digSpeed = if robotClass then robotClass:getNumber('digSpeedSeconds') else economy:getNumber('digSpeedSeconds')
	local elbowGreasePercent = if robotClass then robotClass:getNumber('elbowGreasePercent') else economy:getNumber('elbowGreasePercent')
	local gameTime = economy:getNumber('gameTime')
	local lastDigTime = producer:getNumber('lastDigTime')
	if not digSpeed or not elbowGreasePercent or not gameTime or not lastDigTime then
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

	local lastPulseTime = producer:getNumber('lastPulseTime')
	local pulseMagnitude = producer:getNumber('pulseMagnitude')
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
