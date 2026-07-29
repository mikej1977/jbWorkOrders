if not WorkOrders or not WorkOrders.API then return end

local API   = WorkOrders.API
local Mover = require("addons/BringOutYourDead/BOYD_CorpseMover")

API.addDomain("BOYD", "UI_BOYD_Domain", "Moodle_Icon_Zombie")

API.addCategory("BOYD_Haul", "UI_BOYD_Category_Haul", "Container_Bodybag")

API.addLogic("BOYD_MoveOutdoor", function(playerObj, worldObjects, stagingSquare, area)
    Mover.beginOutdoor(playerObj, stagingSquare, area and area.squares)
end)

API.addLogic("BOYD_GatherIndoor", function(playerObj, worldObjects, square)
    Mover.beginIndoor(playerObj, square)
end)

API.addMenuOption({
    domain    = "BOYD",
    category  = "BOYD_Haul",
    condition = function() return true end,
    translate = "UI_BOYD_Menu_Outdoor",
    tooltip   = "UI_BOYD_Menu_Tooltip_Outdoor",
    icon      = "Container_DeadPerson_FemaleZombie",
    action    = { "SelectSquareAndArea", "BOYD_MoveOutdoor" },
})

API.addMenuOption({
    domain    = "BOYD",
    category  = "BOYD_Haul",
    condition = function()
        local playerObj = getSpecificPlayer(0)
        return playerObj and playerObj:getBuilding() ~= nil
    end,
    translate = "UI_BOYD_Menu_Indoor",
    tooltip   = "UI_BOYD_Menu_Tooltip_Indoor",
    reqTag    = "UI_BOYD_Req_Indoor",
    icon      = "Container_DeadPerson_MaleZombie",
    action    = { "SelectSingleSquare", "BOYD_GatherIndoor" },
})
