-- farming isvalids are tied to ISFarmingMenu.cursor so we can't reuse them "per square"
-- so reimpl the checks on the primitives instead
local Farm = {}

function Farm.plantAt(square)
    if not square then return nil end
    return CFarmingSystem.instance:getLuaObjectOnSquare(square)
end

function Farm.isGoodSeed(item)
    if not item then return false end
    if not instanceof(item, "Food") then return true end
    if item:isRotten() or item:isCooked() or item:isBurnt() then return false end
    if item:hasTag(ItemTag.IS_CUTTING) and not item:isFresh() then return false end
    local baseHunger = math.abs(item:getBaseHunger())
    local hungerChange = math.abs(item:getHungerChange())
    if item:isFresh() and hungerChange < baseHunger then return false end
    if not item:isFresh() and hungerChange < (baseHunger * 0.75) then return false end
    return true
end

function Farm.seedCount(playerObj, seedName)
    return playerObj:getInventory():getCountTypeEvalRecurse(seedName, Farm.isGoodSeed)
end

function Farm.findSeed(playerObj, seedName)
    return playerObj:getInventory():getFirstTypeEvalRecurse(seedName, Farm.isGoodSeed)
end

-- You got the disease, I got the cure
Farm.CURES = {
    Mildew = { itemType = "GardeningSprayMilk",       level = "mildewLvl" },
    Flies  = { itemType = "GardeningSprayCigarettes", level = "fliesLvl" },
    Slugs  = { itemType = "SlugRepellent",            level = "slugsLvl" },
    Aphids = { itemType = "GardeningSprayAphids",     level = "aphidLvl" },
}

local function hasUsesLeft(item)
    local uses = item.getCurrentUses and item:getCurrentUses()
    return uses ~= nil and uses >= 1
end

function Farm.findCure(playerObj, cureName)
    local cure = Farm.CURES[cureName]
    if not cure then return nil end
    return playerObj:getInventory():getFirstTypeEvalRecurse(cure.itemType, hasUsesLeft)
end

function Farm.findWaterSource(playerObj)
    local heldItem = playerObj:getPrimaryHandItem()
    if heldItem and ISFarmingMenu.getWaterUsesInteger(heldItem) > 0 then return heldItem end
    local items = playerObj:getInventory():getItems()
    for itemIndex = 0, items:size() - 1 do
        local item = items:get(itemIndex)
        if ISFarmingMenu.getWaterUsesInteger(item) > 0 then return item end
    end
    return nil
end

-- gotta botta-a-watta with watta?
function Farm.findWateringContainer(playerObj)
    local withWater = Farm.findWaterSource(playerObj)
    if withWater then return withWater end
    local items = playerObj:getInventory():getItems()
    for itemIndex = 0, items:size() - 1 do
        local item = items:get(itemIndex)
        if item:canStoreWater() then return item end
    end
    return nil
end

function Farm.findWaterObject(square)
    if not square then return nil end
    local objects = square:getObjects()
    for objectIndex = 0, objects:size() - 1 do
        local object = objects:get(objectIndex)
        if object:hasFluid() and object:getFluidAmount() > 0 then return object end
    end
    local floor = square:getFloor()
    if floor and floor:hasFluid() and floor:getFluidAmount() > 0 then return floor end
    return nil
end

function Farm.canTill(square)
    return ISFarmingMenu.canDigHereSquare(square)
end

function Farm.canSow(square)
    local plant = Farm.plantAt(square)
    return plant ~= nil and plant.state == "plow"
end

function Farm.canWater(square)
    local plant = Farm.plantAt(square)
    return plant ~= nil and plant:isAlive() and (plant.waterLvl or 0) < 100
end

function Farm.canFertilize(square)
    local plant = Farm.plantAt(square)
    return plant ~= nil and plant:isAlive()
end

function Farm.canHarvest(square)
    local plant = Farm.plantAt(square)
    return plant ~= nil and plant:canHarvest()
end

function Farm.canRemove(square)
    return Farm.plantAt(square) ~= nil
end

function Farm.canTreat(square, cureName)
    local plant = Farm.plantAt(square)
    if not (plant and plant:isAlive()) then return false end
    local cure = Farm.CURES[cureName]
    return cure ~= nil and (plant[cure.level] or 0) > 0
end

-- gimme your loose seeds
function Farm.carriedSeeds(playerObj)
    local seeds = {}
    if not (farming_vegetableconf and farming_vegetableconf.props) then return seeds end
    for typeOfSeed, props in pairs(farming_vegetableconf.props) do
        local seedTypes = props.seedTypes or { props.seedName }
        for _, seedName in ipairs(seedTypes) do
            local count = Farm.seedCount(playerObj, seedName)   -- loose seeds only
            if count > 0 then
                local scriptItem = ScriptManager.instance:getItem(seedName)
                seeds[#seeds + 1] = {
                    typeOfSeed  = typeOfSeed,
                    seedName    = seedName,
                    count       = count,
                    displayName = scriptItem and scriptItem:getDisplayName() or seedName,
                    iconPath    = scriptItem and ("media/textures/Item_" .. scriptItem:getIcon()) or nil,
                }
            end
        end
    end
    return seeds
end

-- gimme your cures
function Farm.carriedCures(playerObj)
    local cures = {}
    for cureName in pairs(Farm.CURES) do
        local item = Farm.findCure(playerObj, cureName)
        if item then
            cures[#cures + 1] = {
                cure        = cureName,
                displayName = item:getDisplayName(),
                iconPath    = "media/textures/Item_" .. item:getIcon(),
            }
        end
    end
    return cures
end

return Farm
