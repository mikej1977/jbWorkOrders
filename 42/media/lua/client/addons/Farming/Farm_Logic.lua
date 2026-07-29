if not WorkOrders or not WorkOrders.API then return {} end

local API = WorkOrders.API
local ActionPlayer = require("helpers/wo_ActionPlayer")
local Farm = require("addons/Farming/Farm_Helpers")

local Logic = {}

-- what did you fuck up now, Jim? 
-- WOFarmDebug = true
local function debugLog(message) if WOFarmDebug then print("[WOFarm] " .. message) end end

local function queueOverArea(playerObj, area, isValid, taskFunc)
    if not (area and area.squares) then return end
    for _, square in ipairs(area.squares) do
        if isValid(square) then
            ActionPlayer.addToQueue(playerObj, taskFunc, { playerObj, square })
        end
    end
end

API.addLogic("farmTill", function(playerObj, worldObjects, area)
    queueOverArea(playerObj, area, Farm.canTill, function(playerObj, square)
        if not Farm.canTill(square) then return end
        local shovel = ISFarmingMenu.getShovel(playerObj)   -- nil = bare hands, do it anyways
        if luautils.walkAdj(playerObj, square) then
            ISTimedActionQueue.add(ISPlowAction:new(playerObj, square, shovel))
        end
    end)
end)

API.addLogic("farmSow", function(playerObj, worldObjects, area, typeOfSeed, seedName)
    if not seedName then return end
    queueOverArea(playerObj, area, Farm.canSow, function(playerObj, square)
        if not Farm.canSow(square) then return end
        local seed = Farm.findSeed(playerObj, seedName)
        if not seed then return end
        local plant = Farm.plantAt(square)
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, seed)
        if luautils.walkAdj(playerObj, square) then
            ISTimedActionQueue.add(ISSeedActionNew:new(playerObj, seed, typeOfSeed, plant))
        end
    end)
end)

API.addLogic("farmWaterArea", function(playerObj, worldObjects, area)
    queueOverArea(playerObj, area, Farm.canWater, function(playerObj, square)
        local plant = Farm.plantAt(square)
        if not (plant and plant:isAlive() and (plant.waterLvl or 0) < 100) then return end
        local waterSource = Farm.findWaterSource(playerObj)
        if not waterSource then return end
        local uses = math.min(ISFarmingMenu.getWaterUsesInteger(waterSource),
            math.ceil((100 - plant.waterLvl) / 10), 10)
        if uses < 1 then return end
        if playerObj:getPrimaryHandItem() ~= waterSource then
            ISTimedActionQueue.add(ISEquipWeaponAction:new(playerObj, waterSource, 50, true))
        end
        if luautils.walkAdj(playerObj, square) then
            ISTimedActionQueue.add(ISWaterPlantAction:new(playerObj, waterSource, uses, square, 20 + (6 * uses)))
        end
    end)
end)

 -- how long do you stand around until you say fuck it?
local FILL_WAIT = 40

local function waterFromSourceStep(playerObj, square, sourceSquare, state)
    local plant = Farm.plantAt(square)
    if not (plant and plant:isAlive() and (plant.waterLvl or 0) < 100) then return true end
    local container = Farm.findWateringContainer(playerObj)
    if not container then debugLog("no watering container"); return true end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, container)
    local carried = ISFarmingMenu.getWaterUsesInteger(container)

    if carried >= 1 then
        state.waitingForFill = nil
        local plantNeed = math.min(math.ceil((100 - plant.waterLvl) / 10), 10)
        local uses = math.min(carried, plantNeed)
        if playerObj:getPrimaryHandItem() ~= container then
            ISTimedActionQueue.add(ISEquipWeaponAction:new(playerObj, container, 50, true))
        end
        if luautils.walkAdj(playerObj, square) then
            debugLog("watering (uses " .. uses .. ")")
            ISTimedActionQueue.add(ISWaterPlantAction:new(playerObj, container, uses, square, 20 + (6 * uses)))
        end
        return false
    end

    if state.waitingForFill then
        state.fillTicks = (state.fillTicks or 0) + 1
        if state.fillTicks < FILL_WAIT then return false end
        debugLog("nothing filled. fuck it")
        return true
    end

    local waterObject = Farm.findWaterObject(sourceSquare)
    if not (waterObject and luautils.walkAdj(playerObj, waterObject:getSquare())) then
        debugLog("cant get to the water source!")
        return true
    end
    debugLog("refilling at source")
    ISTimedActionQueue.add(ISTakeWaterAction:new(playerObj, container, waterObject, waterObject:isTaintedWater()))
    state.waitingForFill = true
    state.fillTicks = 0
    return false
end

API.addLogic("farmWaterFromSource", function(playerObj, worldObjects, sourceSquare, area)
    local sourceWater = Farm.findWaterObject(sourceSquare)
    if not sourceWater then
        debugLog("no water object on chosen square. fuck it")
        return
    end
    debugLog("source is ok, fluid=" .. tostring(sourceWater:getFluidAmount()))
    if not (area and area.squares) then return end
    for _, square in ipairs(area.squares) do
        if Farm.canWater(square) then
            local state = {}
            ActionPlayer.addToQueue(playerObj, function() end, { playerObj, square },
                { isDone = function(pl) return waterFromSourceStep(pl, square, sourceSquare, state) end })
        end
    end
end)

API.addLogic("farmFertilize", function(playerObj, worldObjects, area)
    queueOverArea(playerObj, area, Farm.canFertilize, function(playerObj, square)
        local plant = Farm.plantAt(square)
        if not (plant and plant:isAlive()) then return end
        if not playerObj:getInventory():containsTypeRecurse("Fertilizer") then return end
        if luautils.walkAdj(playerObj, square) then
            local handItem = ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), "Fertilizer", true)
            ISTimedActionQueue.add(ISFertilizeAction:new(playerObj, handItem, plant, 100))
        end
    end)
end)

API.addLogic("farmHarvest", function(playerObj, worldObjects, area)
    queueOverArea(playerObj, area, Farm.canHarvest, function(playerObj, square)
        local plant = Farm.plantAt(square)
        if not (plant and plant:canHarvest()) then return end
        if luautils.walkAdj(playerObj, square) then
            ISTimedActionQueue.add(ISHarvestPlantAction:new(playerObj, plant, 100))
        end
    end)
end)

API.addLogic("farmRemove", function(playerObj, worldObjects, area)
    queueOverArea(playerObj, area, Farm.canRemove, function(playerObj, square)
        local plant = Farm.plantAt(square)
        if not plant then return end
        local shovel = ISFarmingMenu.getShovel(playerObj)
        if not shovel then return end
        if luautils.walkAdj(playerObj, square) then
            local handItem = ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), shovel, true)
            ISTimedActionQueue.add(ISShovelAction:new(playerObj, handItem, plant, 40))
        end
    end)
end)

API.addLogic("farmTreat", function(playerObj, worldObjects, area, cureName)
    if not cureName then return end
    queueOverArea(playerObj, area, function(square) return Farm.canTreat(square, cureName) end,
        function(playerObj, square)
            if not Farm.canTreat(square, cureName) then return end
            local cureItem = Farm.findCure(playerObj, cureName)
            if not cureItem then return end
            local plant = Farm.plantAt(square)
            local uses = 1
            if luautils.walkAdj(playerObj, square) then
                ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), cureItem, true)
                ISTimedActionQueue.add(ISCurePlantAction:new(playerObj, cureItem, uses, plant, 10 * (uses * 10), cureName))
            end
        end)
end)

function Logic.seedProvider(playerObj)
    local options = {}
    for _, seed in ipairs(Farm.carriedSeeds(playerObj)) do
        options[#options + 1] = {
            domain   = "Farming",
            category = "Farming_Plant",
            label    = getText("UI_Farming_Sow_Prefix") .. " " .. seed.displayName .. " (" .. seed.count .. ")",
            tooltip  = "UI_Farming_Sow_Tooltip",
            icon     = seed.iconPath,
            action   = { "SelectArea", "farmSow", seed.typeOfSeed, seed.seedName },
        }
    end
    return options
end

function Logic.cureProvider(playerObj)
    local options = {}
    for _, cure in ipairs(Farm.carriedCures(playerObj)) do
        options[#options + 1] = {
            domain   = "Farming",
            category = "Farming_Tend",
            label    = getText("UI_Farming_Treat_Prefix") .. " " .. getText("UI_Farming_Disease_" .. cure.cure),
            tooltip  = "UI_Farming_Treat_Tooltip",
            icon     = cure.iconPath,
            action   = { "SelectArea", "farmTreat", cure.cure },
        }
    end
    return options
end

return Logic
