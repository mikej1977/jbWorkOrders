local ItemList = require("registries/wo_ItemList")
local Predicates = require("helpers/wo_Predicates")
local ActionPlayer = require("helpers/wo_ActionPlayer")
local SquareUtils = require("helpers/wo_SquareUtils")

local WO_ProcessingLogic = {}

-- sawing needs a saw. if we aren't equipped, and one is sitting nearby, go and fuckin get it
local function equipNearbySaw(playerObj)
    local inventory = playerObj:getInventory()
    local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
    if not containers or inventory:containsEvalRecurse(Predicates.WoodSaw) then return end
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

local function processObject(playerObj, worldObject, recipe)
    if not worldObject or not worldObject:getSquare() then return end
    local item = worldObject:getItem()
    if not item then return end
    if luautils.walkAdj(playerObj, worldObject:getSquare(), true) then
        ISInventoryPaneContextMenu.OnNewCraft(item, recipe, playerObj:getPlayerNum(), true)
    end
end

WO_ProcessingLogic.unifiedProcess = function(playerObj, worldObjects, selectedArea, recipe, processCategory)
    -- sometimes we get the recipe name instead of the recipe
    if type(recipe) == "string" then return end

    if not (selectedArea and selectedArea.squares and recipe and processCategory) then return end

    local processItems = ItemList.ProcessList[processCategory]
    if not processItems then
        print("WorkOrders: Process category '" .. tostring(processCategory) .. "' not found in ProcessList!")
        return
    end

    local squaresWithTargets = {}
    for _, square in ipairs(selectedArea.squares) do
        local objList = square:getObjects()
        for objectIndex = 0, objList:size() - 1 do
            local worldObject = objList:get(objectIndex)
            if instanceof(worldObject, "IsoWorldInventoryObject") and processItems[worldObject:getItem():getFullType()] then
                table.insert(squaresWithTargets, square)
                break
            end
        end
    end

    if #squaresWithTargets == 0 then return end

    local orderedSquares = SquareUtils.orderByProximity(
        playerObj:getX(), playerObj:getY(), playerObj:getZ(), squaresWithTargets)

    if processCategory == "SawLogs" then
        equipNearbySaw(playerObj)
    end

    WorkOrders.setProcessing(playerObj, true)
    ActionPlayer.onFinish(playerObj, function(finishedPlayer)
        WorkOrders.setProcessing(finishedPlayer, false)
    end)

    for _, square in ipairs(orderedSquares) do
        local objList = square:getObjects()
        for objectIndex = 0, objList:size() - 1 do
            local worldObject = objList:get(objectIndex)
            if instanceof(worldObject, "IsoWorldInventoryObject") and processItems[worldObject:getItem():getFullType()] then
                ActionPlayer.addToQueue(playerObj, processObject, { playerObj, worldObject, recipe })
            end
        end
    end
end

return WO_ProcessingLogic
