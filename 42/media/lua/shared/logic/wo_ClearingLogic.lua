local ItemList = require("registries/wo_ItemList")
local Predicates = require("helpers/wo_Predicates")
local ActionPlayer = require("helpers/wo_ActionPlayer")
local SquareUtils = require("helpers/wo_SquareUtils")

local ClearingLogic = {}
local boulderConfig = ItemList.BoulderConfig

-- boulders are sprites boulders_0..59, key number picks tool, time and yield
local function getBoulderData(worldObject)
    local sprite = worldObject:getSprite()
    if not sprite then return nil end
    local name = sprite:getName() or ""
    if name:find("^boulders_") then
        local index = tonumber(name:match("boulders_(%d+)"))
        if index then
            for _, config in ipairs(boulderConfig) do
                if index >= config.min and index <= config.max then
                    return config
                end
            end
        end
    end
    return nil
end

ClearingLogic.ClearRegistry = {
    Tree = {
        isValid = function(square) return square:HasTree() end,
        action = function(playerObj, square)
            ActionPlayer.addToQueue(playerObj, ISWorldObjectContextMenu.doChopTree, { playerObj, square:getTree() })
        end
    },
    Grass = {
        isValid = function(square)
            for objectIndex = 0, square:getObjects():size() - 1 do
                local worldObject = square:getObjects():get(objectIndex)
                if worldObject:getProperties() and worldObject:getProperties():has(IsoFlagType.canBeRemoved) then return true end
            end
            return false
        end,
        action = function(playerObj, square)
            ActionPlayer.addToQueue(playerObj, ISWorldObjectContextMenu.doRemoveGrass, { playerObj, square })
        end
    },
    Bush = {
        isValid = function(square)
            for objectIndex = 0, square:getObjects():size() - 1 do
                local worldObject = square:getObjects():get(objectIndex)
                if worldObject:getSprite() and worldObject:getSprite():getProperties() and worldObject:getSprite():getProperties():has(IsoFlagType.canBeCut) then
                    return true
                end
            end
            return false
        end,
        action = function(playerObj, square)
            ActionPlayer.addToQueue(playerObj, ISWorldObjectContextMenu.doRemovePlant, { playerObj, square, false })
        end
    },
    Stump = {
        isValid = function(square)
            for objectIndex = 0, square:getObjects():size() - 1 do
                local worldObject = square:getObjects():get(objectIndex)
                if worldObject:isStump() then return true end
            end
            return false
        end,
        action = function(playerObj, square)
            local stumpObj = nil
            for objectIndex = 0, square:getObjects():size() - 1 do
                local worldObject = square:getObjects():get(objectIndex)
                if worldObject:isStump() then
                    stumpObj = worldObject; break
                end
            end
            if not stumpObj then return end

            ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), Predicates.DigStump, true, true)

            ActionPlayer.addToQueue(playerObj, function(playerObj, stump)
                if not stump or not stump:getSquare() then return end
                if luautils.walkAdj(playerObj, stump:getSquare()) then
                    ISTimedActionQueue.add(ISPickAxeGroundCoverItem:new(playerObj, stump))
                end
            end, { playerObj, stumpObj })
        end
    },
    Boulder = {
        isValid = function(square)
            for objectIndex = 0, square:getObjects():size() - 1 do
                if getBoulderData(square:getObjects():get(objectIndex)) then return true end
            end
            return false
        end,
        action = function(playerObj, square)
            local boulderObj, config = nil, nil
            for objectIndex = 0, square:getObjects():size() - 1 do
                local worldObject = square:getObjects():get(objectIndex)
                config = getBoulderData(worldObject)
                if config then
                    boulderObj = worldObject; break
                end
            end
            if not boulderObj or not config then return end

            if config.tool then
                ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), Predicates.Digging, true, true)
            end

            ActionPlayer.addToQueue(playerObj, function(playerObj, boulder, config)
                if not boulder or not boulder:getSquare() then return end
                if luautils.walkAdj(playerObj, boulder:getSquare()) then
                    ISTimedActionQueue.add(WO_ClearBoulderAction:new(playerObj, boulder, config.tool, config.stones))
                end
            end, { playerObj, boulderObj, config })
        end
    }
}

local function isValidForClear(square, clearType)
    local config = ClearingLogic.ClearRegistry[clearType]
    if config and config.isValid then
        return config.isValid(square)
    end
    return false
end

ClearingLogic.unifiedClear = function(playerObj, worldObjs, selectedArea, clearType)
    if not selectedArea or not selectedArea.squares then return end

    local validSquares = {}
    for _, square in ipairs(selectedArea.squares) do
        if isValidForClear(square, clearType) then
            table.insert(validSquares, square)
        end
    end

    if #validSquares == 0 then return end

    local sortedSquares = SquareUtils.orderByProximity(
        playerObj:getX(), playerObj:getY(), playerObj:getZ(), validSquares)

    local config = ClearingLogic.ClearRegistry[clearType]
    if config and config.action then
        for _, square in ipairs(sortedSquares) do
            config.action(playerObj, square)
        end
    end
end

return ClearingLogic
