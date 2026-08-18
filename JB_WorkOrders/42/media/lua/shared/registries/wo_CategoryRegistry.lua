local MenuOptions = require("helpers/wo_RegisterMenuOptions")
require("logic/wo_ClearingLogic")
require("logic/wo_ProcessingLogic")
require("logic/wo_GatheringLogic")

MenuOptions.registerDomain("Logging", "UI_WorkOrders_Category_Logging", "media/ui/Radial/Logging.png")
MenuOptions.registerCategory("Gathering", "UI_WorkOrders_Category_Gathering", "media/ui/Radial/Gathering.png")
MenuOptions.registerCategory("Clearing", "UI_WorkOrders_Category_Clearing", "media/ui/Radial/Clearing.png")
MenuOptions.registerCategory("Processing", "UI_WorkOrders_Category_Processing", "media/ui/Radial/Processing.png")
MenuOptions.registerCategory("Storage", "UI_WorkOrders_StorageMenuTitle", "media/ui/Radial/Storage.png")

return MenuOptions
