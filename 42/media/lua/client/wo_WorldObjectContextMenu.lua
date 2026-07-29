require("wo_WorkOrdersWindow")
local Options = require("helpers/wo_Options")

if ModSelector.Model and ModSelector.Model.categories and not ModSelector.Model.categories["Jim Beam's Mods"] then
    ModSelector.Model.categories["Jim Beam's Mods"] = "Item_Plush_CthulhuEye"
end

local function doWorldContextMenu(playerIndex, context, worldObjects, test)
    if test then return ISWorldObjectContextMenu.setTest() end

    local playerObj = getSpecificPlayer(playerIndex)
    if not playerObj or playerObj:getVehicle() then return end

    if not Options.getBool("Open_With_ContextMenu") then
        return
    end

    local keepOnTop = Options.getBool("Keep_Menu_At_Top")
    local menuName  = getText("UI_WorkOrders_OpenWindow")

    local option
    if keepOnTop then
        option = context:addOptionOnTop(menuName, nil, function() WorkOrders.OpenWindow() end)
    else
        option = context:insertOptionAfter(getText("ContextMenu_SitGround"), menuName, nil, function() WorkOrders.OpenWindow() end)
    end
    option.iconTexture = getTexture("media/ui/Radial/Logging.png")
end

Events.OnFillWorldObjectContextMenu.Add(doWorldContextMenu)

-- right click while doing an area selection cancels it. eat the world context menu
local originalCreateMenu = ISWorldObjectContextMenu.createMenu
ISWorldObjectContextMenu.createMenu = function(player, worldObjects, mouseX, mouseY, test)
    if WorkOrders.selecting or WorkOrders.suppressContextMenu then
        WorkOrders.suppressContextMenu = false
        return nil
    end
    return originalCreateMenu(player, worldObjects, mouseX, mouseY, test)
end
