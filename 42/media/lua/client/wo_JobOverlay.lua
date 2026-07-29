local ActionPlayer = require("helpers/wo_ActionPlayer")
local SelectUtils  = require("wo_SelectUtils")

Events.OnTick.Add(function()
    local pendingByPlayer = ActionPlayer.getPendingSquares()
    if not pendingByPlayer then return end
    for playerNum, squares in pairs(pendingByPlayer) do
        local playerObj = getSpecificPlayer(playerNum)
        if playerObj then
            local color = SelectUtils.GetPickedColor(playerObj)
            for _, coord in pairs(squares) do
                SelectUtils.OutlineCoords(coord.x, coord.y, coord.z, color)
            end
        end
    end
end)
