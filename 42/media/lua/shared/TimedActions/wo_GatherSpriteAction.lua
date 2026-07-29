WO_GatherSpriteAction = ISBaseTimedAction:derive("WO_GatherSpriteAction")

function WO_GatherSpriteAction:isValid()
    return self.spriteObj:getSquare() ~= nil
end

function WO_GatherSpriteAction:start()
    self.character:faceThisObject(self.spriteObj)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self:setOverrideHandModels(nil, nil)
end

function WO_GatherSpriteAction:perform()
    ISBaseTimedAction.perform(self)
    triggerEvent("OnContainerUpdate")
end

function WO_GatherSpriteAction:complete()
    local square = self.spriteObj:getSquare()
    if not square then return true end

    local item = instanceItem(self.itemType)
    if not item then
        print("[WO] GatherSpriteAction: instanceItem returned nil for: " .. tostring(self.itemType))
        return true
    end

    square:transmitRemoveItemFromSquare(self.spriteObj)
    square:RemoveTileObject(self.spriteObj)

    local targetContainer = self.destContainer or self.character:getInventory()
    targetContainer:AddItem(item)
    sendAddItemToContainer(targetContainer, item)

    local containerObj = targetContainer:getParent()
    if containerObj and containerObj:getModData().WO_AutoLogStorage then
        WorkOrders.Storage.UpdateSprite(containerObj)
    end

    return true
end

function WO_GatherSpriteAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 50
end

function WO_GatherSpriteAction:new(character, spriteObj, itemType, destContainer)
    local action = {}
    setmetatable(action, self)
    self.__index = self
    action.character = character
    action.spriteObj = spriteObj
    action.itemType = itemType
    action.destContainer = destContainer
    action.stopOnWalk = true
    action.stopOnRun = true
    action.maxTime = action:getDuration()
    return action
end
