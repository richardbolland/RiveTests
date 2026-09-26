--- Digging respects itemsPerDig and digSpeedSeconds, and picks items by
--- rarity weight rather than uniformly. lastDigTime/lastPulseTime live on
--- Economy (not local script state) so clock.luau can read and react to
--- them too (cooldown ring, item pop).

type CollectState = {
	context: Context?,
}

-- Common items turn up far more than rare ones. Weights are relative, not
-- percentages; higher-value items are deliberately rarer finds.
local ITEM_WEIGHTS = {
	{ name = 'BottleCap', weight = 30 },
	{ name = 'Nail', weight = 25 },
	{ name = 'TinCan', weight = 20 },
	{ name = 'Screw', weight = 12 },
	{ name = 'Key', weight = 8 },
	{ name = 'Coin', weight = 5 },
}

local TOTAL_WEIGHT = 0
for _, entry in ITEM_WEIGHTS do
	TOTAL_WEIGHT += entry.weight
end

local MAX_INVENTORY = 12

local function pickItemName(): string
	local roll = math.random() * TOTAL_WEIGHT
	local cumulative = 0
	for _, entry in ITEM_WEIGHTS do
		cumulative += entry.weight
		if roll <= cumulative then
			return entry.name
		end
	end
	return ITEM_WEIGHTS[1].name
end

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

	local digSpeed = economy:getNumber('digSpeedSeconds')
	local gameTime = economy:getNumber('gameTime')
	local lastDigTime = economy:getNumber('lastDigTime')
	if not digSpeed or not gameTime or not lastDigTime then
		return
	end

	if (gameTime.value - lastDigTime.value) < digSpeed.value then
		return
	end

	local inventory = economy:getList('inventory')
	if not inventory then
		return
	end

	local itemsPerDigProp = economy:getNumber('itemsPerDig')
	local itemsPerDig = if itemsPerDigProp then math.floor(itemsPerDigProp.value) else 1

	local added = 0
	local digTotal = 0
	for _ = 1, itemsPerDig do
		if inventory.length >= MAX_INVENTORY then
			break
		end
		local item = Data.Item.new(pickItemName())
		inventory:push(item)
		added += 1

		local value = item:getNumber('value')
		if value then
			digTotal += value.value
		end
	end

	if added > 0 then
		lastDigTime.value = gameTime.value

		local lastPulseTime = economy:getNumber('lastPulseTime')
		if lastPulseTime then
			lastPulseTime.value = gameTime.value
		end

		local lastDigPopupTime = economy:getNumber('lastDigPopupTime')
		local digPopupText = economy:getString('digPopupText')
		if lastDigPopupTime and digPopupText then
			lastDigPopupTime.value = gameTime.value
			digPopupText.value = '+$' .. tostring(digTotal)
		end
	end
end

return function(): ListenerAction<CollectState>
	return {
		init = init,
		performAction = performAction,
	}
end
