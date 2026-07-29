WorkOrders = WorkOrders or {}
local function WorkOrdersOptions()
    local options = PZAPI.ModOptions:create("WorkOrdersModOptions", "")

    local defaultSelectColor = { r = 0.2, g = 0.5, b = 0.7, a = 1 }

    options:addDescription("UI_WorkOrders_ModOptions_Desc1")
    options:addDescription("UI_WorkOrders_ModOptions_Image")
    options:addDescription("UI_WorkOrders_ModOptions_Desc2")
    options:addDescription("UI_WorkOrders_ModOptions_Desc3")
    options:addDescription("")
    options:addTickBox("Open_With_ContextMenu", "UI_WorkOrders_ModOptions_OpenWithContextMenu", true)
    options:addTickBox("Keep_Menu_At_Top", "UI_WorkOrders_ModOptions_KeepMenuOnTop", false)
    options:addKeyBind("Open_Window_Key", getText("UI_WorkOrders_ModOptions_OpenKeybind"), 0)
    options:addTickBox("Open_With_HUDButton", "UI_WorkOrders_ModOptions_OpenWithHUDButton", false)
    options:addTickBox("Stop_Near_Zombies", "UI_WorkOrders_ModOptions_StopNearZombies", true)
    options:addTickBox("Repeat_Orders", "UI_WorkOrders_ModOptions_RepeatOrders", false)

    options:addColorPicker("Select_Color", "UI_WorkOrders_ModOptions_SelectColor",
        defaultSelectColor.r, defaultSelectColor.g, defaultSelectColor.b, defaultSelectColor.a)

    options:addDescription("")
    options:addDescription("")

    options.apply = function(self)
        if WorkOrders and WorkOrders.RefreshHUDButton then
            WorkOrders.RefreshHUDButton()
        end
    end
end

return WorkOrdersOptions()
