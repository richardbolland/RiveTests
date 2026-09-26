--- Milestone 2: clicking the beach item digs up a random item into the
--- 12-slot inventory, instead of paying currency directly. Selling happens
--- separately, via sell.luau on the Sell All button.

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

	local inventory = economy:getList('inventory')
	if not inventory then
		return
	end

	if inventory.length >= MAX_INVENTORY then
		return
	end

	local pick = ITEM_NAMES[math.random(1, #ITEM_NAMES)]
	local item = Data.Item.new(pick)
	inventory:push(item)
end

return function(): ListenerAction<CollectState>
	return {
		init = init,
		performAction = performAction,
	}
end
