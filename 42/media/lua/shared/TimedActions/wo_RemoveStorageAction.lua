require "TimedActions/ISBaseTimedAction"

WO_RemoveStorageAction = ISBaseTimedAction:derive("WO_RemoveStorageAction")

function WO_RemoveStorageAction:isValid()
    if not self.storageObj then return false end
    if not self.storageObj:getSquare() then return false end
    return true
end

function WO_RemoveStorageAction:update()
    self.character:faceLocation(self.storageObj:getSquare():getX(), self.storageObj:getSquare():getY())
end

function WO_RemoveStorageAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

function WO_RemoveStorageAction:perform()
    ISBaseTimedAction.perform(self)
    triggerEvent("OnContainerUpdate")
    ISInventoryPage.dirtyUI()
end

function WO_RemoveStorageAction:complete()
    local square = self.storageObj:getSquare()
    if not square then return true end

    -- dump shit on the floor before we delete the container
    local container = self.storageObj:getContainer()
    if container and not container:isEmpty() then
        -- we gonna copy to a lua table first
        local items = {}
        local javaItems = container:getItems()
        for itemIndex = 0, javaItems:size() - 1 do
            items[#items + 1] = javaItems:get(itemIndex)
        end
        for _, item in ipairs(items) do
            container:Remove(item)
            sendRemoveItemFromContainer(container, item)
            square:AddWorldInventoryItem(item, ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), square:getZ())
        end
    end

    square:transmitRemoveItemFromSquare(self.storageObj)
    square:RemoveTileObject(self.storageObj)
    return true
end

function WO_RemoveStorageAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 50
end

function WO_RemoveStorageAction:new(character, storageObj)
    local action = {}
    setmetatable(action, self)
    self.__index = self
    action.character = character
    action.storageObj = storageObj
    action.stopOnWalk = true
    action.stopOnRun = true
    action.maxTime = action:getDuration()
    return action
end
