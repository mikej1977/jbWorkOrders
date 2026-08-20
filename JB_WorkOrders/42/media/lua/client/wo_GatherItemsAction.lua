local ActionSpeedKeeper = require("helpers/wo_SpeedKeeper")
local ItemList = require("registries/wo_ItemList")
local StorageLogic = require("logic/wo_StorageLogic")
local SquareUtils = require("helpers/wo_SquareUtils")

local ACTION_DELAY_MS  = 85
local DOTS_START_MS    = 170
local DOTS_CYCLE_MS    = 500
local DROP_STALL_LIMIT = 3 -- attempted drops where nothing transfered

WO_GatherItemsAction = {}
WO_GatherItemsAction.__index = WO_GatherItemsAction

local function grabWithDest(character, item, time, destination)
    local grabAction = ISGrabItemAction:new(character, item, time)
    if destination then
        grabAction.destContainer = destination
    end
    return grabAction
end

local function getPlayerContainers(playerObj)
    local containerList = {}
    local playerBackpacks = getPlayerInventory(playerObj:getPlayerNum()).backpacks

    for _, container in ipairs(playerBackpacks) do
        if container.inventory:getType() ~= "KeyRing" then
            table.insert(containerList, container.inventory)
        end
    end

    return #containerList > 0 and containerList or nil
end

function WO_GatherItemsAction:getAvailableContainers()
    local containers = {}
    local startSquare = self.dropSquare
    if not startSquare then return containers end

    local vehicle = startSquare:getVehicleContainer()
    if vehicle then
        local parts = { "TrunkDoorOpened", "TruckBed", "TruckBedOpen" }
        for _, partId in ipairs(parts) do
            local part = vehicle:getPartById(partId) or vehicle:getTrailerTrunkPart()
            if part and part:getItemContainer() then
                table.insert(containers, part)
            end
        end
    end

    local visited = {}
    local queue = { startSquare }

    while #queue > 0 do
        local foundStorageOnSquare = false
        local currentSquare = table.remove(queue, 1)
        local key = SquareUtils.key(currentSquare)

        if not visited[key] then
            visited[key] = true

            local objects = currentSquare:getObjects()

            for objectIndex = 0, objects:size() - 1 do
                local object = objects:get(objectIndex)
                local modData = object:getModData()

                if modData and modData.WO_AutoLogStorage == self.storageType then
                    table.insert(containers, object:getContainer())
                    foundStorageOnSquare = true
                elseif object:getContainer() and not foundStorageOnSquare then
                    if not modData.WO_AutoLogStorage then
                        table.insert(containers, object:getContainer())
                    end
                end
            end

            if foundStorageOnSquare and currentSquare == startSquare then
                local squareX, squareY, squareZ = currentSquare:getX(), currentSquare:getY(), currentSquare:getZ()
                local cell = getCell()

                local neighbors = {
                    cell:getGridSquare(squareX, squareY - 1, squareZ), -- N
                    cell:getGridSquare(squareX, squareY + 1, squareZ), -- S
                    cell:getGridSquare(squareX + 1, squareY, squareZ), -- E
                    cell:getGridSquare(squareX - 1, squareY, squareZ)  -- W
                }

                for _, neighbor in ipairs(neighbors) do
                    if neighbor and not visited[SquareUtils.key(neighbor)] then
                        table.insert(queue, neighbor)
                    end
                end
            end
        end
    end

    return containers
end

local function walkToVehiclePartArea(character, part)
    local vehicle = part:getVehicle()
    local trunkPart = part:getVehiclePart()
    local area = trunkPart:getArea()
    if not vehicle or not area then return false end
    if vehicle:canAccessContainer(trunkPart:getIndex(), character) then
        return true
    end
    local action = ISPathFindAction:pathToVehicleArea(character, vehicle, area)
    ISTimedActionQueue.add(action)
    return false
end

function WO_GatherItemsAction:new(character, dropSquare, pickupSquares, itemsTable, storageType)
    local filteredSquares = {}

    if pickupSquares and pickupSquares.squares then
        for _, square in ipairs(pickupSquares.squares) do
            if square ~= dropSquare then
                table.insert(filteredSquares, square)
            end
        end
    end

    -- get from the end of the list
    local path = SquareUtils.orderByProximity(character:getX(), character:getY(), character:getZ(), filteredSquares)
    local orderedSquares = {}
    for index = #path, 1, -1 do
        orderedSquares[#orderedSquares + 1] = path[index]
    end

    local action = {
        character = character,
        destContainer = nil,
        dropSquare = dropSquare,
        pickupSquares = orderedSquares,
        lastSquare = false,
        lastItems = false,
        itemTypes = itemsTable,
        storageType = storageType,
        OnTick = nil,
        currentSquare = nil,
        currentItems = {},
        droppingItems = false,
        stopRequested = false,
        actionDelayMs = 0
    }
    setmetatable(action, self)
    action:Start()
    return action
end

function WO_GatherItemsAction:IsDoingSomething()
    return ISTimedActionQueue.isPlayerDoingAction(self.character)
        or self:IsCancel()
        or self.character:isPlayerMoving()
        or self.character:shouldBeTurning()
end

function WO_GatherItemsAction:IsCancel()
    if not instanceof(self.character, "IsoPlayer") then return true end
    return self.character:pressedCancelAction() or self.character:isAttacking()
end

function WO_GatherItemsAction:GetNextSquare()
    local count = #self.pickupSquares
    if count > 0 then
        self.currentSquare = self.pickupSquares[count]
        self.lastSquare = count == 1
        self.squareScanned = false
        return self.currentSquare
    end

    self.currentSquare = nil
end

function WO_GatherItemsAction:GetItemsOnSquare()
    if not self.currentSquare then
        self.currentSquare = nil
        return
    end
    self.squareScanned = true

    local squareObjects = self.currentSquare:getObjects()
    if squareObjects:size() == 0 then return end

    for objectIndex = 0, squareObjects:size() - 1 do
        local item = squareObjects:get(objectIndex)
        if instanceof(item, "IsoWorldInventoryObject") and self.itemTypes[item:getItem():getFullType()] then
            table.insert(self.currentItems, item)
        elseif self.itemTypes[item:getProperty("CustomName")] then
            table.insert(self.currentItems, item)
        end
    end

    if self.lastSquare and #self.currentItems < 20 then
        self.lastItems = true
    end
end

function WO_GatherItemsAction:PickupItems()
    if not self.currentItems or #self.currentItems == 0 then
        if self.currentSquare then
            table.remove(self.pickupSquares)
        end
        self.currentSquare = nil
        return
    end

    local lastIndex = #self.currentItems
    local item = self.currentItems[lastIndex]
    local customName = item:getProperty("CustomName")
    local isTile = customName and self.itemTypes[customName] and not instanceof(item, "IsoWorldInventoryObject")

    local yieldType = nil
    local weight = 0

    if isTile then
        yieldType = ItemList.PickupItems[customName]
        if not yieldType then table.remove(self.currentItems, lastIndex); return end
        if not yieldType:find("%.") then yieldType = "Base." .. yieldType end
        local scriptItem = ScriptManager.instance:getItem(yieldType)
        weight = scriptItem and scriptItem:getActualWeight() or 1.0
    else
        yieldType = item:getItem():getFullType()
        weight = item:getItem():getActualWeight()
    end

    if not self.destContainer or not self.destContainer:hasRoomFor(self.character, weight) then
        self:SetDestContainerByWeight(yieldType, weight)
    end

    if not self.destContainer then
        local hasFreeSpace = false
        local playerContainers = getPlayerContainers(self.character)

        if playerContainers then
            for _, container in ipairs(playerContainers) do
                for itemType in pairs(self.itemTypes) do
                    local matchingItems = container:getItemsFromFullType(itemType)
                    if matchingItems and not matchingItems:isEmpty() then
                        hasFreeSpace = true
                        break
                    end
                end
                if hasFreeSpace then break end
            end
        end

        if hasFreeSpace then
            self:DropOffItems()
        else
            self:End()
        end
        return
    end

    local walk = ISWalkToTimedAction:new(self.character, self.currentSquare)

    local completionData = {
        char = self.character,
        itemObj = item,
        itemFullType = yieldType,
        dest = self.destContainer,
        tileFlag = isTile
    }

    walk:setOnComplete(function(data)
        if not data.itemObj or not data.itemObj:getSquare() then
            return -- lol someone beat you to it!
        end

        if data.tileFlag then
            ISTimedActionQueue.add(WO_GatherSpriteAction:new(data.char, data.itemObj, data.itemFullType, data.dest))
        else
            ISTimedActionQueue.add(grabWithDest(data.char, data.itemObj, 50, data.dest))
        end
    end, completionData)

    ISTimedActionQueue.add(walk)

    table.remove(self.currentItems, lastIndex)
    return
end

function WO_GatherItemsAction:SetDestContainerByWeight(itemFullType, weight)
    if self.destContainer and self.destContainer:hasRoomFor(self.character, weight) then
        return
    end

    local containers = getPlayerContainers(self.character)
    if not containers then return end

    for _, container in ipairs(containers) do
        local containerInventory = container
        if containerInventory:hasRoomFor(self.character, weight) and containerInventory:getType() ~= "KeyRing" then
            self.destContainer = containerInventory
            return
        end
    end

    self.destContainer = nil
end

function WO_GatherItemsAction:DropOffItems()
    self.droppingItems = true

    local destinations = self:getAvailableContainers()

    local playerContainers = getPlayerContainers(self.character)
    if not playerContainers then
        self.droppingItems = false
        self:End()
        return
    end

    local carried = 0
    for _, playerContainer in ipairs(playerContainers) do
        for itemType in pairs(self.itemTypes) do
            local carriedItems = playerContainer:getItemsFromFullType(itemType)
            if carriedItems then carried = carried + carriedItems:size() end
        end
    end

    if carried > 0 and self.lastCarried and carried >= self.lastCarried then
        self.dropStalls = (self.dropStalls or 0) + 1
        if self.dropStalls >= DROP_STALL_LIMIT then
            self.dropOffFull = true
            self.droppingItems = false
            return
        end
    else
        self.dropStalls = 0
    end
    self.lastCarried = carried

    local actionsQueued = 0
    local BATCH_LIMIT = 20
    local scheduledSquare = self.character:getSquare()
    local unreachable = {} -- cant path to these this batch, quit checking every item

    local projectedWeights = {}
    for _, destination in ipairs(destinations) do
        local actualContainer = instanceof(destination, "VehiclePart") and destination:getItemContainer() or destination
        projectedWeights[actualContainer] = actualContainer:getCapacityWeight()
    end

    for _, playerContainer in ipairs(playerContainers) do
        for itemType in pairs(self.itemTypes) do
            local dropItems = playerContainer:getItemsFromFullType(itemType)

            if dropItems and not dropItems:isEmpty() then
                for dropIndex = 0, dropItems:size() - 1 do
                    if actionsQueued >= BATCH_LIMIT then return end

                    local dropItem = dropItems:get(dropIndex)
                    local droppedToContainer = false
                    local itemWeight = dropItem:getActualWeight()

                    for _, container in ipairs(destinations) do
                        local targetVehiclePart = nil
                        local actualContainer = container

                        if instanceof(container, "VehiclePart") then
                            actualContainer = container:getItemContainer()
                            targetVehiclePart = actualContainer
                        end

                        if not unreachable[actualContainer]
                            and actualContainer:getCapacity() >= (projectedWeights[actualContainer] + itemWeight) then
                            local containerObj = actualContainer:getParent()
                            local destSquare = containerObj and containerObj:getSquare() or self.dropSquare
                            local canGetThere = true

                            if scheduledSquare ~= destSquare then
                                if targetVehiclePart then
                                    -- false here is "pathfind queued, come back next tick bruh"
                                    -- failure is not an option
                                    if not walkToVehiclePartArea(self.character, targetVehiclePart) then return end
                                else
                                    -- crate boxed in by its own neighbors? blacklist it and try the next one.
                                    -- bailing here fucks the whole job: walkAdj wipes the queue before it
                                    -- fails, so we'd come back every tick, clear, fail, and queue shit
                                    canGetThere = luautils.walkAdj(self.character, destSquare, true)
                                    if not canGetThere then unreachable[actualContainer] = true end
                                end
                                if canGetThere then scheduledSquare = destSquare end
                            end

                            if canGetThere then
                                projectedWeights[actualContainer] = projectedWeights[actualContainer] + itemWeight

                                ISTimedActionQueue.add(ISInventoryTransferAction:new(self.character, dropItem,
                                    dropItem:getContainer(), actualContainer, 50))

                                if containerObj and containerObj:getModData() and containerObj:getModData().WO_AutoLogStorage then
                                    local updateAction = ISBaseTimedAction:new(self.character)
                                    updateAction.Type = "UpdateStorageSprite"
                                    updateAction.maxTime = 1
                                    updateAction.isValid = function(self) return true end

                                    updateAction.perform = function(self)
                                        StorageLogic.UpdateSprite(containerObj)
                                        ISBaseTimedAction.perform(self)
                                    end
                                    ISTimedActionQueue.add(updateAction)
                                end

                                droppedToContainer = true
                                actionsQueued = actionsQueued + 1
                                break
                            end
                        end
                    end

                    if not droppedToContainer then
                        if scheduledSquare ~= self.dropSquare then
                            -- can't path to the selected square: check the floor
                            -- transfer anyway would dump shit wherever the player is standing
                            if not luautils.walkAdj(self.character, self.dropSquare, true) then
                                self.dropOffBlocked = true
                                self.droppingItems = false
                                return
                            end
                            scheduledSquare = self.dropSquare
                        end

                        ISTimedActionQueue.add(ISInventoryTransferAction:new(
                            self.character, dropItem, dropItem:getContainer(),
                            ISInventoryPage.floorContainer[self.character:getPlayerNum() + 1], 50
                        ))
                        actionsQueued = actionsQueued + 1
                    end
                end
            end
        end
    end

    if actionsQueued == 0 then
        self.droppingItems = false
        self.lastCarried = nil
        self.dropStalls = nil
        ISInventoryPage.renderDirty = true
    end
end

function WO_GatherItemsAction:Start()
    self.stopRequested = false
    WorkOrders.setWorking(self.character, true)
    local actionSpeedKeeper = ActionSpeedKeeper:new(self.character)
    actionSpeedKeeper:AddStopCondition(function()
        return self.stopRequested
    end)
    actionSpeedKeeper:KeepSpeed()
    self:Update()
end

function WO_GatherItemsAction:End()
    self.stopRequested = true
    WorkOrders.setWorking(self.character, false)
    if self.resting then WorkOrders.getUpFromRest(self.character) end
    WorkOrders.clearRest(self.character, self) -- also wipes the halo note
    if self.OnTick then
        ISTimedActionQueue.clear(self.character)
        Events.OnTick.Remove(self.OnTick)
    end
    if self.dropOffBlocked then
        self.character:setHaloNote(getText("UI_WorkOrders_CantReachDropOff"), 255, 100, 80, 300)
    elseif self.dropOffFull then
        self.character:setHaloNote(getText("UI_WorkOrders_DropOffFull"), 255, 100, 80, 300)
    end
end

-- the whole job runs off this tick
function WO_GatherItemsAction:Update()
    self.dotsMs = 0
    self.lastFrameMs = nil

    local function OnTick()
        Events.OnTick.Remove(self.OnTick)

        if not self.character or not self.character:getSquare() then return end
        if self.dropOffBlocked or self.dropOffFull then
            self:End()
            return
        end
        if WorkOrders.isTooDark(self.character) then
            self:End()
            self.character:setHaloNote(getText("UI_WorkOrders_TooDark"), 255, 80, 80, 300)
            return
        end

        if self.character:pressedMovement(false) or self.character:pressedCancelAction() then
            self:End()
            return
        end

        local now = getTimestampMs()
        local dt = now - (self.lastFrameMs or now)
        self.lastFrameMs = now
        if dt < 0 then dt = 0 elseif dt > 100 then dt = 100 end

        self.lastEndurance = WorkOrders.giveBackEndurance(self.character, self.lastEndurance)

        if self:IsDoingSomething() then
            self.actionDelayMs = ACTION_DELAY_MS

            self.dotsMs = 0

            self.character:setHaloNote("", 0)
            Events.OnTick.Add(self.OnTick)
            return
        end

        if self.resting then
            if WorkOrders.updateRest(self.character, self, dt) then
                Events.OnTick.Add(self.OnTick)
                return
            end
        elseif WorkOrders.shouldStartRest(self.character, self) then
            self.resting = true
            self.restPhase = nil
            Events.OnTick.Add(self.OnTick)
            return
        end

        self.dotsMs = self.dotsMs + dt

        -- do a little "." ".." "..." text so the player knows we;re still thinking, not stuck
        if self.dotsMs > DOTS_START_MS then
            local cycle = self.dotsMs % DOTS_CYCLE_MS
            local dots = "."
            if cycle >= DOTS_CYCLE_MS * 2 / 3 then
                dots = "..."
            elseif cycle >= DOTS_CYCLE_MS / 3 then
                dots = ".."
            end
            self.character:setHaloNote(dots, 255, 255, 255, 11)
        end

        if self.actionDelayMs > 0 then
            self.actionDelayMs = self.actionDelayMs - dt
            Events.OnTick.Add(self.OnTick)
            return
        end

        if self.droppingItems then
            self:DropOffItems()
            if self.droppingItems then
                Events.OnTick.Add(self.OnTick)
            else
                self.OnTick()
            end
            return
        end

        if not self.currentSquare then
            self:GetNextSquare()
        end

        if (self.lastSquare and self.lastItems) and not self.currentSquare then
            self:DropOffItems()
            if self.droppingItems then
                Events.OnTick.Add(self.OnTick)
                return
            end
            self:End()
            return
        end

        if (not self.currentItems or #self.currentItems == 0) and self.currentSquare and not self.squareScanned then
            self:GetItemsOnSquare()
        end

        self:PickupItems()
        Events.OnTick.Add(self.OnTick)
    end

    self.OnTick = OnTick
    Events.OnTick.Add(self.OnTick)
end
