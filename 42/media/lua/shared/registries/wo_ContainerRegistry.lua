local ItemList = require("registries/wo_ItemList")

local ContainerRegistry = {}

ContainerRegistry.Types = {
    Logs = {
        translate = "UI_WorkOrders_LogStorage",
        itemType = ItemList.GatherItemList.Logs,
        icon = "media/ui/Radial/G_Logs.png",
        sprites = {
            empty = "jb_workorders_20",
            cursor = "jb_workorders_4",
            cursorNorth = "jb_workorders_0",

            level1 = "jb_workorders_4",
            level2 = "jb_workorders_5",
            level3 = "jb_workorders_6",
            level4 = "jb_workorders_7",

            level1north = "jb_workorders_0",
            level2north = "jb_workorders_1",
            level3north = "jb_workorders_2",
            level4north = "jb_workorders_3"
        }
    },

    Planks = {
        translate = "UI_WorkOrders_PlanksStorage",
        itemType = ItemList.GatherItemList.Planks,
        icon = "media/ui/Radial/G_Planks.png",
        sprites = {
            empty = "jb_workorders_20",
            cursor = "jb_workorders_12",
            cursorNorth = "jb_workorders_8",

            level1 = "jb_workorders_12",
            level2 = "jb_workorders_13",
            level3 = "jb_workorders_14",
            level4 = "jb_workorders_15",

            level1north = "jb_workorders_8",
            level2north = "jb_workorders_9",
            level3north = "jb_workorders_10",
            level4north = "jb_workorders_11"
        }
    },

    Twigs = {
        translate = "UI_WorkOrders_ScrapWoodStorage",
        itemType = ItemList.GatherItemList.Twigs,
        icon = "media/ui/Radial/S_ScrapWood.png",
        sprites = {
            empty = "jb_workorders_20",
            cursor = "jb_workorders_16",
            cursorNorth = "jb_workorders_16",

            level1 = "jb_workorders_16",
            level2 = "jb_workorders_17",
            level3 = "jb_workorders_18",
            level4 = "jb_workorders_19",

            level1north = "jb_workorders_16",
            level2north = "jb_workorders_17",
            level3north = "jb_workorders_18",
            level4north = "jb_workorders_19",
        },
    },

    Firewood = {
        translate = "UI_WorkOrders_FirewoodStorage",
        itemType = ItemList.GatherItemList.Firewood,
        icon = "media/ui/Radial/S_Firewood.png",
        sprites = {
            empty = "jb_workorders_20",
            cursor = "jb_workorders_28",
            cursorNorth = "jb_workorders_24",

            level1 = "jb_workorders_28",
            level2 = "jb_workorders_29",
            level3 = "jb_workorders_30",
            level4 = "jb_workorders_31",

            level1north = "jb_workorders_24",
            level2north = "jb_workorders_25",
            level3north = "jb_workorders_26",
            level4north = "jb_workorders_27",
        },
    },

    Stones = {
        translate = "UI_WorkOrders_StoneStorage",
        itemType = ItemList.GatherItemList.Stones,
        icon = "media/ui/Radial/S_Stones.png",
        sprites = {
            empty = "jb_workorders_20",
            cursor = "jb_workorders_22",
            cursorNorth = "jb_workorders_22",

            level1 = "jb_workorders_21",
            level2 = "jb_workorders_21",
            level3 = "jb_workorders_22",
            level4 = "jb_workorders_23",

            level1north = "jb_workorders_21",
            level2north = "jb_workorders_21",
            level3north = "jb_workorders_22",
            level4north = "jb_workorders_23",
        }
    }
}

return ContainerRegistry
