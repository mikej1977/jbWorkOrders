local WOKeyConflictDialog = {}

function WOKeyConflictDialog.findConflict(key)
    if not key or key == 0 or type(keyBinding) ~= "table" then return nil end
    for _, binding in ipairs(keyBinding) do
        local name = binding.value
        -- starts with "[" is not for reals
        if name and name:sub(1, 1) ~= "[" and ((binding.key and binding.key == key) or (binding.alt and binding.alt == key)) then
            local label = getText("UI_optionscreen_binding_" .. name)
            if label == "UI_optionscreen_binding_" .. name then label = name end
            return label -- translated binding key
        end
    end
    return nil
end

function WOKeyConflictDialog.show(key, actionName, onKeep, onClear)
    local textManager = getTextManager()
    local mediumFont, smallFont = UIFont.Medium, UIFont.Small
    local mediumFontHeight, smallFontHeight = textManager:getFontHeight(mediumFont), textManager:getFontHeight(smallFont)

    local message = getText("UI_WorkOrders_KeyConflict", getKeyName(key) or "?", actionName or "?")
    local padding, gap = 14, 8
    local buttonHeight = smallFontHeight + 8
    local buttonWidth = math.max(150, textManager:MeasureStringX(smallFont, getText("UI_optionscreen_KeybindClear")) + 30)
    local panelWidth = math.max(buttonWidth + 2 * padding, textManager:MeasureStringX(mediumFont, message) + 2 * padding)
    local panelHeight = padding + mediumFontHeight + padding + 3 * buttonHeight + 2 * gap + padding

    local panelX = (getCore():getScreenWidth() - panelWidth) / 2
    local panelY = (getCore():getScreenHeight() - panelHeight) / 2

    local panel = ISPanel:new(panelX, panelY, panelWidth, panelHeight)
    panel:initialise(); panel:instantiate()
    panel.background = true
    panel.backgroundColor = { r = 0.05, g = 0.06, b = 0.05, a = 0.96 }
    panel.borderColor = { r = 0.55, g = 0.45, b = 0.2, a = 1 }
    panel.moveWithMouse = false
    panel:setAlwaysOnTop(true)
    panel:addToUIManager()

    local label = ISLabel:new(panelWidth / 2, padding, mediumFontHeight, message, 0.96, 0.88, 0.55, 1, mediumFont, true)
    label.center = true
    label:initialise()
    panel:addChild(label)

    local function close() panel:removeFromUIManager() end
    local buttonY = padding + mediumFontHeight + padding
    local function addButton(title, callback)
        local button = ISButton:new((panelWidth - buttonWidth) / 2, buttonY, buttonWidth, buttonHeight, title, panel, function()
            close()
            if callback then callback() end
        end)
        button:initialise(); button:instantiate()
        button.borderColor = { r = 1, g = 1, b = 1, a = 0.2 }
        panel:addChild(button)
        buttonY = buttonY + buttonHeight + gap
    end

    addButton(getText("UI_optionscreen_KeybindKeep"), onKeep)
    addButton(getText("UI_optionscreen_KeybindClear"), onClear)
    addButton(getText("UI_Cancel"), nil)

    return panel
end

WorkOrders = WorkOrders or {}
WorkOrders.KeyConflictDialog = WOKeyConflictDialog
return WOKeyConflictDialog
