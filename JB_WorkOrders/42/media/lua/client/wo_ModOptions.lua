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

    local enduranceSlider = options:addSlider("Endurance_Reduction",
        getText("UI_WorkOrders_ModOptions_EnduranceReduction"), 0, 100, 5, 0,
        getText("UI_WorkOrders_ModOptions_EnduranceReduction_tooltip"))

    local restSlider = options:addSlider("Rest_Endurance_Level",
        getText("UI_WorkOrders_ModOptions_RestLevel"), 0, 4, 1, 0,
        getText("UI_WorkOrders_ModOptions_RestLevel_tooltip"))

    options:addColorPicker("Select_Color", "UI_WorkOrders_ModOptions_SelectColor",
        defaultSelectColor.r, defaultSelectColor.g, defaultSelectColor.b, defaultSelectColor.a)

    options:addDescription("")
    options:addDescription("")

    -- in MP the server's sandbox value rules, so show it read-only instead of a live setting
    Events.OnGameStart.Add(function()
        if isClient() or isServer() then
            if enduranceSlider then
                local sandboxValue = SandboxVars.JBWorkOrders and SandboxVars.JBWorkOrders.WorkEnduranceReduction or 0
                enduranceSlider:setValue(sandboxValue)
                enduranceSlider:setEnabled(false)
            end
            if restSlider then
                local sandboxRest = SandboxVars.JBWorkOrders and SandboxVars.JBWorkOrders.RestAtEnduranceLevel or 0
                restSlider:setValue(sandboxRest)
                restSlider:setEnabled(false)
            end
        end
    end)

    options.apply = function(self)
        if WorkOrders and WorkOrders.RefreshHUDButton then
            WorkOrders.RefreshHUDButton()
        end
    end
end

return WorkOrdersOptions()
