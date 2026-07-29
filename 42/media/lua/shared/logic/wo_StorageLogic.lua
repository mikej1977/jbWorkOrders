local ItemList = require("registries/wo_ItemList")
local ContainerRegistry = require("registries/wo_ContainerRegistry")

WorkOrders = WorkOrders or {}
WorkOrders.Storage = WorkOrders.Storage or {}

local StorageLogic = WorkOrders.Storage

-- fake that drag cusrsor shit
local function watchCursorDrag(playerObj, cursor)
    WorkOrders.selecting = true
    local playerNum = playerObj:getPlayerNum()
    local watcher
    watcher = function()
        if getCell():getDrag(playerNum) == cursor then return end
        Events.OnTick.Remove(watcher)
        WorkOrders.selecting = false
        if not getCell():getDrag(playerNum) and WorkOrders.OpenWindow then
            WorkOrders.OpenWindow()
        end
    end
    Events.OnTick.Add(watcher)
end

StorageLogic.Create = function(playerObj, typeKey)
    local data = ContainerRegistry.Types[typeKey]
    if not data then return end

    local sprite = data.sprites.cursor
    local northSprite = data.sprites.cursorNorth or sprite

    if WO_StorageBuildCursor then
        local buildObj = WO_StorageBuildCursor:new(playerObj, typeKey, sprite, northSprite)
        getCell():setDrag(buildObj, playerObj:getPlayerNum())
        watchCursorDrag(playerObj, buildObj)
    end
end

StorageLogic.Remove = function(playerObj)
    if WO_StorageRemoveCursor then
        local cursor = WO_StorageRemoveCursor:new(playerObj)
        getCell():setDrag(cursor, playerObj:getPlayerNum())
        watchCursorDrag(playerObj, cursor)
    end
end

StorageLogic.PlaceStorage = function(playerObj, _worldObjs, square, typeKey, north, spriteName)
    if not square then return end

    -- clear the tile so the container pile isnt sitting in a bunch of shit
    local toRemove = {}
    for objectIndex = 0, square:getObjects():size() - 1 do
        local object = square:getObjects():get(objectIndex)
        if object:getProperties() and object:getProperties():has(IsoFlagType.canBeRemoved) then
            table.insert(toRemove, object)
        end
    end

    for _, object in ipairs(toRemove) do
        if isClient() then
            sledgeDestroy(object)
        else
            square:transmitRemoveItemFromSquare(object)
            square:RemoveTileObject(object)
        end
    end

    local cell = square:getCell()

    local data = ContainerRegistry.Types[typeKey]
    local finalSprite = (data and data.sprites.empty) or "blends_natural_01_64"

    local storageObj = IsoThumpable.new(cell, square, finalSprite, north, {})
    storageObj:setIsThumpable(false)
    storageObj:setCanPassThrough(true)
    storageObj:setMaxHealth(500)
    storageObj:setHealth(500)

    local container = storageObj:getContainer()
    if not container then
        local containerName = typeKey .. "Storage"
        container = ItemContainer.new(containerName, square, storageObj)
        storageObj:setContainer(container)
    end
    container:setCapacity(100)
    container:setAcceptItemFunction("WorkOrders.Storage.Accept")

    local modData = storageObj:getModData()
    modData.WO_AutoLogStorage = typeKey

    square:AddSpecialObject(storageObj)

    if isClient() then
        storageObj:transmitCompleteItemToServer()
    elseif isServer() then
        storageObj:transmitCompleteItemToClients()
    end

    square:RecalcAllWithNeighbours(true)
    storageObj:transmitModData()
    container:setExplored(true)
    triggerEvent("OnContainerUpdate")
end

StorageLogic.Accept = function(container, item)
    local object = container:getParent()
    if not object then return true end

    local typeKey = object:getModData().WO_AutoLogStorage
    if not typeKey then
        return true
    end

    local storageConfig = ContainerRegistry.Types[typeKey]
    if not storageConfig then return true end

    local itemFullType = item:getFullType()
    local allowedTypes = storageConfig.itemType

    if type(allowedTypes) == "table" then
        if allowedTypes[itemFullType] then return true end
    elseif type(allowedTypes) == "string" then
        if allowedTypes == itemFullType then return true end
    end

    return false
end

---@param object IsoThumpable
StorageLogic.UpdateSprite = function(object)
    if not object or not object:getModData().WO_AutoLogStorage then return end

    local typeKey = object:getModData().WO_AutoLogStorage
    local data = ContainerRegistry.Types[typeKey]
    if not data then return end

    local container = object:getContainer()
    if not container then return end

    local weight = container:getContentsWeight()
    local capacity = container:getCapacity()
    local percent = weight / capacity
    local isNorth = object:getNorth()

    local spriteName = data.sprites.empty or "blends_natural_01_64"
    local levelKey = nil

    if percent > 0.75 then
        levelKey = "level4"
    elseif percent > 0.50 then
        levelKey = "level3"
    elseif percent > 0.25 then
        levelKey = "level2"
    elseif percent > 0 then
        levelKey = "level1"
    end

    if levelKey then
        if isNorth and data.sprites[levelKey .. "north"] then
            spriteName = data.sprites[levelKey .. "north"]
        else
            spriteName = data.sprites[levelKey]
        end
    end

    if object:getSpriteName() ~= spriteName then
        object:setSpriteFromName(spriteName)
        object:transmitModData()

        if isClient() then
            object:transmitUpdatedSpriteToServer()
        end

        if isServer() then
            object:sendObjectChange(IsoObjectChange.SPRITE)
            object:transmitUpdatedSpriteToClients()
        end
    end
end

StorageLogic.CheckSquare = function(square)
    if not square then return end
    for objectIndex = 0, square:getSpecialObjects():size() - 1 do
        local specialObject = square:getSpecialObjects():get(objectIndex)
        if specialObject:getModData().WO_AutoLogStorage then
            StorageLogic.UpdateSprite(specialObject)
        end
    end
end

StorageLogic.OnRefreshContainers = function(inventoryPage, state)
    if state ~= "end" then return end
    if inventoryPage.onCharacter then return end

    local containers = inventoryPage.backpacks
    if not containers then return end

    for _, backpack in ipairs(containers) do
        local container = backpack.inventory
        if container and container:getParent() then
            local object = container:getParent()
            local modData = object:getModData()
            if modData and modData.WO_AutoLogStorage then
                container:setAcceptItemFunction("WorkOrders.Storage.Accept")
                StorageLogic.UpdateSprite(object)
            end
        end
    end
end

Events.OnRefreshInventoryWindowContainers.Add(StorageLogic.OnRefreshContainers)

Events.OnContainerUpdate.Add(function(container)
    if not container or
        instanceof(container, "IsoDeadBody") or
        instanceof(container, "IsoZombie") or
        instanceof(container, "IsoGridSquare") then
        return
    end
    if not container:getSquare() then return end
    local square = container:getSquare()
    if not square then return end
    StorageLogic.CheckSquare(square)
end)

Events.LoadGridsquare.Add(function(square)
    if not square then return end
    StorageLogic.CheckSquare(square)
end)

Events.OnObjectAdded.Add(function(object)
    if not isServer() or not object then return end
    local modData = object:getModData()

    if modData and modData.WO_AutoLogStorage then
        StorageLogic.UpdateSprite(object)
        ISInventoryPage.dirtyUI()
    end
end)

return StorageLogic
