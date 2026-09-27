--- Sell All: converts every item across every producer's own onboard
--- storage to currency, then empties each of them - the fleet-wide
--- equivalent of clicking each full robot individually (main.luau).

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

	local producers = economy:getList('producers')
	local currency = economy:getNumber('currency')
	if not producers or not currency then
		return
	end

	local total = 0
	for i = 1, producers.length do
		local storage = producers[i]:getList('storage')
		if storage then
			for j = 1, storage.length do
				local item = storage[j]
				local value = item:getNumber('value')
				if value then
					total = total + value.value
				end
			end
			storage:clear()
		end
	end

	currency.value = currency.value + total
	local lifetimeCurrencyEarned = economy:getNumber('lifetimeCurrencyEarned')
	if lifetimeCurrencyEarned then
		lifetimeCurrencyEarned.value = lifetimeCurrencyEarned.value + total
	end
end

return function(): ListenerAction<SellState>
	return {
		init = init,
		performAction = performAction,
	}
end
