local ItemList = require("registries/wo_ItemList")
local vanillaAddOrDrop = Actions.addOrDropItem

-- drop shit on the ground instead of inventory
function Actions.addOrDropItem(character, item)
    local pn = character:getPlayerNum()
    local isActive = pn and WorkOrders.processingPlayers and WorkOrders.processingPlayers[pn]
    if not (isActive and ItemList.DropItems[item:getFullType()]) then
        return vanillaAddOrDrop(character, item)
    end

    local square = character:getSquare()
    local dropX, dropY, dropZ = ISTransferAction.GetDropItemOffset(character, square, item)
    character:getCurrentSquare():AddWorldInventoryItem(item, dropX, dropY, dropZ)

    triggerEvent("OnContainerUpdate")
end
