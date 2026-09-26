--- Sell All: converts every item in the inventory to currency, then empties it.

type SellState = {
	context: Context?,
}

local function init(self: SellState, context: Context): boolean
	self.context = context
	return true
end

local function performAction(self: SellState, listenerContext: ListenerContext)
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
	local currency = economy:getNumber('currency')
	if not inventory or not currency then
		return
	end

	local total = 0
	for i = 1, inventory.length do
		local item = inventory[i]
		local value = item:getNumber('value')
		if value then
			total = total + value.value
		end
	end

	currency.value = currency.value + total
	inventory:clear()
end

return function(): ListenerAction<SellState>
	return {
		init = init,
		performAction = performAction,
	}
end
