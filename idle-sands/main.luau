--- Milestone 3 (+cooldown visual): digging respects itemsPerDig and
--- digSpeedSeconds. lastDigTime now lives on Economy (not local script
--- state) so clock.luau can read it too, to drive the cooldown ring.

type CollectState = {
	context: Context?,
}

local ITEM_NAMES = { 'BottleCap', 'Nail', 'TinCan', 'Screw', 'Key', 'Coin' }
local MAX_INVENTORY = 12

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
	for _ = 1, itemsPerDig do
		if inventory.length >= MAX_INVENTORY then
			break
		end
		local pick = ITEM_NAMES[math.random(1, #ITEM_NAMES)]
		inventory:push(Data.Item.new(pick))
		added += 1
	end

	if added > 0 then
		lastDigTime.value = gameTime.value
	end
end

return function(): ListenerAction<CollectState>
	return {
		init = init,
		performAction = performAction,
	}
end
