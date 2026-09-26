--- Milestone 3: digging now respects the itemsPerDig and digSpeedSeconds
--- upgrades. itemsPerDig items are added per successful dig (capped by the
--- 12-slot inventory); a dig within digSpeedSeconds of the last one is
--- ignored, reading Economy.gameTime (ticked by clock.luau) as the clock.

type CollectState = {
	context: Context?,
	lastDigTime: number?,
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
	local cooldown = if digSpeed then digSpeed.value else 0

	local gameTime = economy:getNumber('gameTime')
	local now = if gameTime then gameTime.value else 0
	local lastDigTime = self.lastDigTime
	if lastDigTime and (now - lastDigTime) < cooldown then
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
		self.lastDigTime = now
	end
end

return function(): ListenerAction<CollectState>
	return {
		init = init,
		performAction = performAction,
	}
end
