local MenuOptions = require("helpers/wo_RegisterMenuOptions")
require("registries/wo_CategoryRegistry") -- domain and category must exist before options! derp
require("logic/wo_ClearingLogic")
require("logic/wo_ProcessingLogic")
require("logic/wo_GatheringLogic")

-- condition just returns true now
MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Gathering",
    condition = function(playerInv, flags)
        return true
    end,
    translate = "UI_WorkOrders_Menu_Gather_Logs",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Gather_Logs",
    icon = "media/ui/Radial/G_Logs.png",
    action = { "SelectSquareAndArea", "gatherLogs" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Gathering",
    condition = function(playerInv, flags)
        return true
    end,
    translate = "UI_WorkOrders_Menu_Gather_Planks",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Gather_Planks",
    icon = "media/ui/Radial/G_Planks.png",
    action = { "SelectSquareAndArea", "gatherPlanks" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Gathering",
    condition = function(playerInv, flags)
        return true
    end,
    translate = "UI_WorkOrders_Menu_Gather_Firewood",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Gather_Firewood",
    icon = "media/ui/Radial/G_Firewood.png",
    action = { "SelectSquareAndArea", "gatherFirewood" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Gathering",
    condition = function(playerInv, flags)
        return true
    end,
    translate = "UI_WorkOrders_Menu_Gather_Stones",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Gather_Stones",
    icon = "media/ui/Radial/G_Stones.png",
    action = { "SelectSquareAndArea", "gatherStones" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Gathering",
    condition = function(playerInv, flags)
        return true
    end,
    translate = "UI_WorkOrders_Menu_Gather_Branches",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Gather_Branches",
    icon = "media/ui/Radial/G_Twigs.png",
    action = { "SelectSquareAndArea", "gatherTwigsAndBranches" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Clearing",
    condition = function(playerInv, flags)
        return flags.toolChopTree
    end,
    translate = "UI_WorkOrders_Menu_Clear_Trees",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Clear_Trees",
    reqTag = "UI_WorkOrders_Menu_Req_Clear_Trees",
    icon = "media/ui/Radial/C_Trees.png",
    action = { "SelectArea", "unifiedClear", "Tree" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Clearing",
    condition = function(playerInv, flags)
        return flags.toolDigStump
    end,
    translate = "UI_WorkOrders_Menu_Clear_Stumps",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Clear_Stumps",
    reqTag = "UI_WorkOrders_Menu_Req_Clear_Stumps",
    icon = "media/ui/Radial/C_Stumps.png",
    action = { "SelectArea", "unifiedClear", "Stump" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Clearing",
    condition = function(playerInv, flags)
        return flags.toolCutPlant
    end,
    translate = "UI_WorkOrders_Menu_Clear_Bushes",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Clear_Bushes",
    reqTag = "UI_WorkOrders_Menu_Req_Clear_Bushes",
    icon = "media/ui/Radial/C_Bushes.png",
    action = { "SelectArea", "unifiedClear", "Bush" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Clearing",
    condition = function(playerInv, flags)
        return true
    end,
    translate = "UI_WorkOrders_Menu_Clear_Grass",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Clear_Grass",
    reqTag = "UI_WorkOrders_Menu_Req_Clear_Grass",
    icon = "media/ui/Radial/C_Grass.png",
    action = { "SelectArea", "unifiedClear", "Grass" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Clearing",
    condition = function(playerInv, flags)
        return flags.toolBreakBoulder
    end,
    translate = "UI_WorkOrders_Menu_Clear_Boulders",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Clear_Boulders",
    reqTag = "UI_WorkOrders_Menu_Req_Clear_Boulders",
    icon = "media/ui/Radial/C_Boulders.png",
    action = { "SelectArea", "unifiedClear", "Boulder" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Processing",
    condition = function(playerInv, flags)
        return flags.recipeSawPlanks
    end,
    translate = "UI_WorkOrders_Menu_Saw_Planks",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Saw_Planks",
    reqTag = "UI_WorkOrders_Menu_Req_Saw_Planks",
    icon = "media/ui/Radial/P_SawPlanks.png",
    action = { "SelectArea", "unifiedProcess", "recipeSawPlanks", "SawLogs" },
})

MenuOptions.registerMenuOption({
    domain = "Logging",
    category = "Processing",
    condition = function(playerInv, flags)
        return flags.recipeChopFirewood and flags.toolChopTree
    end,
    translate = "UI_WorkOrders_Chop_Firewood",
    tooltip = "UI_WorkOrders_Menu_Tooltip_Chop_Firewood",
    reqTag = "UI_WorkOrders_Menu_Req_Chop_Firewood",
    icon = "media/ui/Radial/P_ChopFirewood.png",
    action = { "SelectArea", "unifiedProcess", "recipeChopFirewood", "ChopFirewood" },
})

return MenuOptions
