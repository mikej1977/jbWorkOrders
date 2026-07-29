local ItemList = require("registries/wo_ItemList")
local ActionSpeedKeeper = require("helpers/wo_SpeedKeeper")
local Predicates = require("helpers/wo_Predicates")

local WO_ProcessingLogic = {}

WO_ProcessingLogic.unifiedProcess = function(playerObj, worldObjects, selectedArea, recipe, processCategory)
    -- sometimes we get the recipe name instead of the recipe
    if type(recipe) == "string" then return end

    if not (selectedArea and selectedArea.squares and recipe and processCategory) then return end

    local processItems = ItemList.ProcessList[processCategory]
    if not processItems then
        print("WorkOrders: Process category '" .. tostring(processCategory) .. "' not found in ProcessList!")
        return
    end

    WorkOrders.processingPlayers = WorkOrders.processingPlayers or {}
    WorkOrders.processingPlayers[playerObj:getPlayerNum()] = true

    local actionSpeedKeeper = ActionSpeedKeeper:new(playerObj)
    actionSpeedKeeper:KeepSpeed()

    -- throw the outputs on the ground
    local function dropResults()
        local inventory = playerObj:getInventory()
        local itemsToDrop = {}
        for itemFullType in pairs(ItemList.DropItems) do
            local items = inventory:getItemsFromFullType(itemFullType)
            if items and not items:isEmpty() then
                for i = 0, items:size() - 1 do
                    table.insert(itemsToDrop, items:get(i))
                end
            end
        end

        if #itemsToDrop == 0 then return end
        for _, dropItem in ipairs(itemsToDrop) do
            local dropX, dropY, dropZ = ISTransferAction.GetDropItemOffset(playerObj, playerObj:getSquare(), dropItem)
            playerObj:getCurrentSquare():AddWorldInventoryItem(dropItem, dropX, dropY, dropZ):getWorldItem()
                :transmitCompleteItemToClients()
            inventory:Remove(dropItem)
        end
        ISInventoryPage.renderDirty = true
    end

    local function onTick()
        dropResults()
        if playerObj:getSquare():getLightLevel(playerObj:getPlayerNum()) < 0.4 or
            not ISTimedActionQueue.isPlayerDoingAction(playerObj) or
            playerObj:pressedMovement(false) or playerObj:pressedCancelAction() then
            WorkOrders.processingPlayers[playerObj:getPlayerNum()] = nil
            Events.OnTick.Remove(onTick)
        end
    end

    -- sawing needs a saw. if we aren't equipped, and one is sitting nearby, go and fuckin get it
    local inventory = playerObj:getInventory()
    local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
    if processCategory == "SawLogs" and containers and not inventory:containsEvalRecurse(Predicates.WoodSaw) then
        local saw
        for containerIndex = 0, containers:size() - 1 do
            local container = containers:get(containerIndex)
            if container ~= inventory then
                local items = container:getItems()
                for itemIndex = 0, items:size() - 1 do
                    local item = items:get(itemIndex)
                    if Predicates.WoodSaw(item) then saw = item; break end
                end
            end
            if saw then break end
        end
        if saw then
            ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, saw, saw:getContainer(), inventory))
        end
    end

    for _, square in ipairs(selectedArea.squares) do
        local objList = square:getObjects()
        for objectIndex = 0, objList:size() - 1 do
            local worldObject = objList:get(objectIndex)
            if instanceof(worldObject, "IsoWorldInventoryObject") and processItems[worldObject:getItem():getFullType()] then
                if luautils.walkAdj(playerObj, worldObject:getSquare(), true) then
                    ISInventoryPaneContextMenu.OnNewCraft(worldObject:getItem(), recipe, playerObj:getPlayerNum(), true)
                end
            end
        end
    end

    Events.OnTick.Add(onTick)
end

return WO_ProcessingLogic
