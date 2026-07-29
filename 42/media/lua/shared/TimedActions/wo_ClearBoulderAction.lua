WO_ClearBoulderAction = ISBaseTimedAction:derive("WO_ClearBoulderAction")

function WO_ClearBoulderAction:isValid()
    return self.boulderObj:getSquare() ~= nil
end

function WO_ClearBoulderAction:start()
    if self.needsTool then
        self:setActionAnim("HammerOre")
    else
        self:setActionAnim("Dig")
    end
    self.character:faceLocation(self.boulderObj:getX(), self.boulderObj:getY())
end

function WO_ClearBoulderAction:update()
    self.character:faceLocation(self.boulderObj:getX(), self.boulderObj:getY())
end

function WO_ClearBoulderAction:perform()
    ISBaseTimedAction.perform(self)
    triggerEvent("OnContainerUpdate")
end

function WO_ClearBoulderAction:complete()
    local square = self.boulderObj:getSquare()
    if not square then return true end

    square:transmitRemoveItemFromSquare(self.boulderObj)
    square:RemoveTileObject(self.boulderObj)

    -- throw shit around the square so it doesnt all fall in one place
    for stoneIndex = 1, self.stoneCount do
        local stone = instanceItem("Base.Stone2")
        square:AddWorldInventoryItem(stone, ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), square:getZ())
    end
    return true
end

function WO_ClearBoulderAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 150
end

function WO_ClearBoulderAction:new(character, boulderObj, needsTool, stoneCount)
    local action = {}
    setmetatable(action, self)
    self.__index = self
    action.character = character
    action.boulderObj = boulderObj
    action.needsTool = needsTool
    action.stoneCount = stoneCount
    action.stopOnWalk = true
    action.stopOnRun = true
    action.maxTime = action:getDuration()
    return action
end
