require "BuildingObjects/ISBuildingObject"
require "TimedActions/wo_RemoveStorageAction"

WO_StorageRemoveCursor = ISBuildingObject:derive("WO_StorageRemoveCursor")

-- boom
function WO_StorageRemoveCursor:create(worldX, worldY, worldZ, north, sprite)
    local cell = getCell()
    local square = cell:getGridSquare(worldX, worldY, worldZ)

    for objectIndex = 0, square:getSpecialObjects():size() - 1 do
        local specialObject = square:getSpecialObjects():get(objectIndex)
        if specialObject:getModData() and specialObject:getModData().WO_AutoLogStorage then
            self.storageObj = specialObject
        end
    end
    if self.storageObj then
        ISTimedActionQueue.add(WO_RemoveStorageAction:new(self.character, self.storageObj, 50))
    end
end

function WO_StorageRemoveCursor:isValid(square)
    if not square then return false end

    for objectIndex = 0, square:getSpecialObjects():size() - 1 do
        local specialObject = square:getSpecialObjects():get(objectIndex)
        if specialObject:getModData() and specialObject:getModData().WO_AutoLogStorage then
            return true
        end
    end
    return false
end

function WO_StorageRemoveCursor:render(worldX, worldY, worldZ, square)
    local highlightColor = getCore():getGoodHighlitedColor()
    if not self:isValid(square) then
        highlightColor = getCore():getBadHighlitedColor()
    end
    self:getFloorCursorSprite():RenderGhostTileColor(worldX, worldY, worldZ, highlightColor:getR(), highlightColor:getG(), highlightColor:getB(), 0.8)
end

function WO_StorageRemoveCursor:new(player)
    local cursor = {}
    setmetatable(cursor, self)
    self.__index = self
    cursor:init()
    cursor.character = player
    cursor.player = player:getPlayerNum()
    cursor.noNeedHammer = true
    cursor.skipBuildAction = true
    return cursor
end
