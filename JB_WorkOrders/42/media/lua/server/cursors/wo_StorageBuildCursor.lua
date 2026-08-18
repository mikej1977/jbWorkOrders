require "BuildingObjects/ISBuildingObject"
require "TimedActions/wo_StorageBuildAction"

WO_StorageBuildCursor = ISBuildingObject:derive("WO_StorageBuildCursor")

function WO_StorageBuildCursor:create(worldX, worldY, worldZ, north, sprite)
    local cell = getCell()
    local square = cell:getGridSquare(worldX, worldY, worldZ)
    ISTimedActionQueue.add(WO_StorageBuildAction:new(self.character, square, self.sprite, self.north, self.typeKey))
end

function WO_StorageBuildCursor:isValid(square)
    if not square then return false end
    if square:isSolid() or square:isSolidTrans() then return false end
    if not square:TreatAsSolidFloor() then return false end

    -- one pile per tile
    for objectIndex = 0, square:getSpecialObjects():size() - 1 do
        local specialObject = square:getSpecialObjects():get(objectIndex)
        if specialObject:getModData() and specialObject:getModData().WO_AutoLogStorage then return false end
    end
    return true
end

function WO_StorageBuildCursor:new(player, typeKey, sprite, northSprite)
    local cursor = {}
    setmetatable(cursor, self)
    self.__index = self
    cursor:init()
    cursor:setSprite(sprite)
    cursor:setNorthSprite(northSprite)
    cursor.typeKey = typeKey
    cursor.character = player
    cursor.player = player:getPlayerNum()
    cursor.noNeedHammer = true
    cursor.skipBuildAction = true
    return cursor
end