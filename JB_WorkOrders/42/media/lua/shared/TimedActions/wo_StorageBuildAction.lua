require "TimedActions/ISBaseTimedAction"
require "logic/wo_StorageLogic"

WO_StorageBuildAction = ISBaseTimedAction:derive("WO_StorageBuildAction")

function WO_StorageBuildAction:isValid()
    if not self.square then return false end
    return true
end

function WO_StorageBuildAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
end

function WO_StorageBuildAction:start()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

function WO_StorageBuildAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 50
end

function WO_StorageBuildAction:perform()
    ISBaseTimedAction.perform(self)
    ISInventoryPage.dirtyUI()
end

function WO_StorageBuildAction:complete()
    WorkOrders.Storage.PlaceStorage(
        self.character,
        nil,
        self.square,
        self.typeKey,
        self.isNorthSprite,
        self.buildObjName
    )
    return true
end

function WO_StorageBuildAction:new(character, square, buildObjName, isNorthSprite, typeKey)
    local action = {}
    setmetatable(action, self)
    self.__index = self
    action.character = character
    action.square = square
    action.buildObjName = buildObjName
    action.isNorthSprite = isNorthSprite
    action.typeKey = typeKey
    action.stopOnWalk = true
    action.stopOnRun = true
    action.maxTime = action:getDuration()
    return action
end
