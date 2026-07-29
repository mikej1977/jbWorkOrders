local ItemList = require("registries/wo_ItemList")

local GatheringLogic = {}

GatheringLogic.gatherLogs = function(playerObj, worldObjects, stagingSquare, selectedArea)
    if not selectedArea or not selectedArea.squares then return end
    WO_GatherItemsAction:new(playerObj, stagingSquare, selectedArea, ItemList.GatherItemList.Logs, "Logs")
end

GatheringLogic.gatherTwigsAndBranches = function(playerObj, worldObjects, stagingSquare, selectedArea)
    if not selectedArea then return end
    WO_GatherItemsAction:new(playerObj, stagingSquare, selectedArea, ItemList.GatherItemList.Twigs, "Twigs")
end

GatheringLogic.gatherPlanks = function(playerObj, worldObjects, stagingSquare, selectedArea)
    if not stagingSquare or not selectedArea then return end
    WO_GatherItemsAction:new(playerObj, stagingSquare, selectedArea, ItemList.GatherItemList.Planks, "Planks")
end

GatheringLogic.gatherFirewood = function(playerObj, worldObjects, stagingSquare, selectedArea)
    if not stagingSquare or not selectedArea then return end
    WO_GatherItemsAction:new(playerObj, stagingSquare, selectedArea, ItemList.GatherItemList.Firewood, "Firewood")
end

GatheringLogic.gatherStones = function(playerObj, worldObjects, stagingSquare, selectedArea)
    if not stagingSquare or not selectedArea then return end
    WO_GatherItemsAction:new(playerObj, stagingSquare, selectedArea, ItemList.GatherItemList.Stones, "Stones")
end

return GatheringLogic
