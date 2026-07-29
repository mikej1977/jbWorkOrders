if not WorkOrders or not WorkOrders.API then return end

local API   = WorkOrders.API
local Logic = require("addons/Farming/Farm_Logic")
local Farm  = require("addons/Farming/Farm_Helpers")

API.addDomain("Farming", "UI_Farming_Domain", "Item_Hoe")
API.addCategory("Farming_Prepare", "UI_Farming_Cat_Prepare", "Item_Shovel")
API.addCategory("Farming_Plant",   "UI_Farming_Cat_Plant",   "Item_Seeds_Generic")
API.addCategory("Farming_Tend",    "UI_Farming_Cat_Tend",    "Item_WateringCan")
API.addCategory("Farming_Harvest", "UI_Farming_Cat_Harvest", "Item_HandScythe")

local function localPlayer() return getSpecificPlayer(0) end

API.addMenuOption({
    domain = "Farming", category = "Farming_Prepare",
    condition = function() return true end,
    translate = "UI_Farming_Till", tooltip = "UI_Farming_Till_Tooltip",
    icon = "Item_Shovel",
    action = { "SelectArea", "farmTill" },
})
API.addMenuOption({
    domain = "Farming", category = "Farming_Prepare",
    condition = function()
        local playerObj = localPlayer()
        return playerObj ~= nil and ISFarmingMenu.getShovel(playerObj) ~= nil
    end,
    translate = "UI_Farming_Remove", tooltip = "UI_Farming_Remove_Tooltip",
    reqTag = "UI_Farming_Req_Shovel",
    icon = "Item_GardeningFork",
    action = { "SelectArea", "farmRemove" },
})

API.addMenuOption({
    domain = "Farming", category = "Farming_Tend",
    condition = function(playerInv) return playerInv:containsTypeRecurse("Fertilizer") end,
    translate = "UI_Farming_Fertilize", tooltip = "UI_Farming_Fertilize_Tooltip",
    reqTag = "UI_Farming_Req_Fertilizer",
    icon = "Item_Compost",
    action = { "SelectArea", "farmFertilize" },
})
API.addMenuOption({
    domain = "Farming", category = "Farming_Tend",
    condition = function() return Farm.findWaterSource(localPlayer()) ~= nil end,
    translate = "UI_Farming_Water", tooltip = "UI_Farming_Water_Tooltip",
    reqTag = "UI_Farming_Req_Water",
    icon = "Item_WateringCan",
    action = { "SelectArea", "farmWaterArea" },
})
API.addMenuOption({
    domain = "Farming", category = "Farming_Tend",
    condition = function() return Farm.findWateringContainer(localPlayer()) ~= nil end,
    translate = "UI_Farming_WaterSource", tooltip = "UI_Farming_WaterSource_Tooltip",
    reqTag = "UI_Farming_Req_Container",
    icon = "Item_Bucket_Water",
    pickValidator = function(square, playerObj)
        return Farm.findWaterObject(square) ~= nil
            and AdjacentFreeTileFinder.Find(square, playerObj) ~= nil
    end,
    action = { "SelectSquareAndArea", "farmWaterFromSource" },
})

API.addMenuOption({
    domain = "Farming", category = "Farming_Harvest",
    condition = function() return true end,
    translate = "UI_Farming_Harvest", tooltip = "UI_Farming_Harvest_Tooltip",
    icon = "Item_HandScythe",
    action = { "SelectArea", "farmHarvest" },
})

API.addMenuProvider(Logic.seedProvider)
API.addMenuProvider(Logic.cureProvider)
