local MenuModel = require("wo_MenuModel")
local KeyConflictDialog = require("wo_KeyConflictDialog")

WorkOrders = WorkOrders or {}

local Window = ISCollapsableWindow:derive("WorkOrdersWindow")

local PAD         = 12
local PANEL_C     = 16

local FRAME_INSET = 12
local TITLE_H     = 40
local TAB_H       = 36
local TAB_W       = 44
local TAB_ICON    = 28
local ICON        = 44
local CELL_W      = 108
local GAP         = 8
local SECTION_GAP = 10
local LABEL_LINES = 3 -- how many text lines a "cell" expects

local FONT        = UIFont.Small
local HFONT       = UIFont.Medium

-- we don't need your stinkin mod options
local SETTINGS = {
    { id = "Open_With_ContextMenu", kind = "tick",  label = "UI_WorkOrders_ModOptions_OpenWithContextMenu" },
    { id = "Keep_Menu_At_Top",      kind = "tick",  label = "UI_WorkOrders_ModOptions_KeepMenuOnTop" },
    { id = "Open_With_HUDButton",   kind = "tick",  label = "UI_WorkOrders_ModOptions_OpenWithHUDButton" },
    { id = "Stop_Near_Zombies",     kind = "tick",  label = "UI_WorkOrders_ModOptions_StopNearZombies" },
    { id = "Repeat_Orders",         kind = "tick",  label = "UI_WorkOrders_ModOptions_RepeatOrders" },
    { id = "Select_Color",          kind = "color", label = "UI_WorkOrders_ModOptions_SelectColor" },
    { id = "Open_Window_Key",       kind = "key",   label = "UI_WorkOrders_ModOptions_OpenKeybind" },
}

local Options = require("helpers/wo_Options")
local getOpt = Options.getOption
local setOpt = Options.set

-- break text into "<= maxLines" that fit maxWidth
local function wrapLabel(text, maxWidth, font, maxLines)
    local textManager = getTextManager()
    local function fit(text)
        if textManager:MeasureStringX(font, text) <= maxWidth then return text end
        while #text > 1 and textManager:MeasureStringX(font, text .. "...") > maxWidth do text = text:sub(1, #text - 1) end
        return text .. "..."
    end
    local words = {}
    for word in string.gmatch(text or "", "%S+") do words[#words + 1] = word end
    local lines, currentLine = {}, ""
    for _, word in ipairs(words) do
        local trial = (currentLine == "") and word or (currentLine .. " " .. word)
        if textManager:MeasureStringX(font, trial) <= maxWidth then
            currentLine = trial
        else
            if currentLine ~= "" then lines[#lines + 1] = currentLine end
            currentLine = word
            if #lines >= maxLines then currentLine = ""; break end
        end
    end
    if currentLine ~= "" and #lines < maxLines then lines[#lines + 1] = currentLine end
    for lineIndex = 1, #lines do lines[lineIndex] = fit(lines[lineIndex]) end
    return lines
end

-- so getSharedTexture can and will return nil for a frame or two so that's fun
local ninePatch
local function drawPanel(self)
    if not ninePatch and NinePatchTexture then
        ninePatch = NinePatchTexture.getSharedTexture("media/ui/WO_Panel9patch.png")
    end
    if ninePatch then
        ninePatch:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height)
    end
end

local titleTex
local function loadTitle()
    if titleTex == nil then titleTex = getTexture("media/ui/WO_Title.png") end
    return titleTex
end

local function player() return getSpecificPlayer(0) end

local function invSignature(playerObj)
    local inventory = playerObj and playerObj:getInventory()
    local count = inventory and inventory:getItems():size() or -1
    local inBuilding = playerObj and playerObj:getBuilding() ~= nil
    return count * 2 + (inBuilding and 1 or 0)
end

-- where window was when it was closed
local savedUIState = nil

function Window:new(posX, posY, width, height)
    local window = ISCollapsableWindow.new(self, posX, posY, width, height)
    window.title = getText("UI_WorkOrders_Window_Title")
    window.resizable = true
    window.drawFrame = false -- let 9-patch do the thing
    window.background = false
    window.clearStentil = false -- litnetSraelC
    window.pin = true -- stay
    window.minimumWidth = 2 * PAD + 2 * CELL_W + GAP
    window.minimumHeight = 160
    window.domains       = {}
    window.activeDomainId = nil
    window.flags    = {}
    window.scrollY  = 0
    window.contentH = 0
    window.hovered  = nil
    return window
end

function Window:titleBarHeight()
    return TITLE_H
end

function Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    -- we brought our own shit to the party!
    if self.pinButton then self.pinButton:setVisible(false) end
    if self.collapseButton then self.collapseButton:setVisible(false) end
    if self.infoButton then self.infoButton:setVisible(false) end
    local buttonSize = 32
    if self.closeButton then
        self.closeButton:setWidth(buttonSize)
        self.closeButton:setHeight(buttonSize)
        self.closeButton:setX(FRAME_INSET)
        self.closeButton:setY((TITLE_H - buttonSize) / 2)
        self.closeButton:setImage(getTexture("media/ui/WO_Close.png"))
        self.closeButton.backgroundColorMouseOver = { r = 1, g = 1, b = 1, a = 0.25 }
    end

    -- gear/back button
    self.settingsButton = ISButton:new(self.width - buttonSize - FRAME_INSET, (TITLE_H - buttonSize) / 2, buttonSize, buttonSize, "", self,
        function(window) window:toggleSettings() end)
    self.settingsButton.anchorRight = true
    self.settingsButton.anchorLeft = false
    self.settingsButton:initialise()
    self.settingsButton.borderColor.a = 0
    self.settingsButton.backgroundColor.a = 0
    self.settingsButton.backgroundColorMouseOver = { r = 1, g = 1, b = 1, a = 0.25 }
    self.settingsButton:setImage(getTexture("media/ui/WO_Gear.png"))
    self.settingsButton:setTooltip(getText("UI_WorkOrders_Settings"))
    self:addChild(self.settingsButton)
end

function Window:toggleSettings()
    self.settingsOpen = not self.settingsOpen
    self:cancelKeyCapture()
    if self.settingsButton then
        if self.settingsOpen then
            self.settingsButton:setImage(getTexture("media/ui/WO_Back.png"))
            self.settingsButton:setTooltip(getText("UI_WorkOrders_Back"))
        else
            self.settingsButton:setImage(getTexture("media/ui/WO_Gear.png"))
            self.settingsButton:setTooltip(getText("UI_WorkOrders_Settings"))
        end
    end
    if self.settingsOpen then
        self.scrollY = 0
    else
        self:refresh()
    end
end

function Window:refresh()
    local playerObj = player()
    if not playerObj then return end
    self.flags   = MenuModel.computeWindowFlags(playerObj)
    self.domains = MenuModel.buildOrders(playerObj, self.flags)
    self._invSig = invSignature(playerObj)  -- baseline inv to check against
    self:ensureActiveDomain()
end

function Window:ensureActiveDomain()
    local domains = self.domains or {}
    for _, domain in ipairs(domains) do
        if domain.id == self.activeDomainId then return end
    end
    self.activeDomainId = domains[1] and domains[1].id or nil
end

function Window:activeDomain()
    for _, domain in ipairs(self.domains or {}) do
        if domain.id == self.activeDomainId then return domain end
    end
    return self.domains and self.domains[1] or nil
end

function Window:tabBarHeight()
    return (self.domains and #self.domains > 1) and TAB_H or 0
end

function Window:columnsFor(availableWidth)
    return math.max(1, math.floor((availableWidth + GAP) / (CELL_W + GAP)))
end

-- beep boop
function Window:computeLayout()
    local availableWidth = self.width - 2 * PAD
    local columns = self:columnsFor(availableWidth)
    local layout = { headers = {}, cells = {}, cols = columns }
    local currentY = 0
    local domain = self:activeDomain()
    for _, group in ipairs(domain and domain.cats or {}) do
        if #group.items > 0 then
            table.insert(layout.headers, { y = currentY, group = group })
            currentY = currentY + self.headerH
            local rows = math.ceil(#group.items / columns)
            for itemIndex, item in ipairs(group.items) do
                local column = (itemIndex - 1) % columns
                local row = math.floor((itemIndex - 1) / columns)
                table.insert(layout.cells, {
                    x = PAD + column * (CELL_W + GAP),
                    y = currentY + row * (self.cellH + GAP),
                    item = item,
                })
            end
            currentY = currentY + rows * (self.cellH + GAP) + SECTION_GAP
        end
    end
    layout.contentH = currentY
    self._layout = layout
    self.contentH = currentY
    return layout
end

function Window:contentTop() return self:titleBarHeight() + self:tabBarHeight() end
function Window:contentBottom() return self.height - PANEL_C end
function Window:contentViewH() return self:contentBottom() - self:contentTop() end

function Window:clampScroll()
    local maxScroll = math.max(0, self.contentH - self:contentViewH())
    if self.scrollY < 0 then self.scrollY = 0 end
    if self.scrollY > maxScroll then self.scrollY = maxScroll end
end

function Window:prerender()
    ISCollapsableWindow.prerender(self)
    -- a changed item count means rebuild this shit
    if not self.settingsOpen then
        local signature = invSignature(player())
        if signature ~= self._invSig then
            self._invSig = signature
            self:refresh()
        end
    end
    drawPanel(self)
    self.lineH  = getTextManager():getFontHeight(FONT)
    self.hfontH = getTextManager():getFontHeight(HFONT)
    self.cellH  = ICON + 4 + LABEL_LINES * self.lineH
    self.headerH = self.hfontH + 20 -- text + underline + a little room for sheep balls
    self:computeLayout()
    self:clampScroll()
end

function Window:cancelKeyCapture()
    if self._keyHandler then
        Events.OnKeyPressed.Remove(self._keyHandler)
        self._keyHandler = nil
    end
    self.capturingKey = nil
end

-- get the next keypress for the damn keybind
function Window:captureKey(id)
    self:cancelKeyCapture()
    self.capturingKey = id
    self._keyHandler = function(key)
        self:cancelKeyCapture()
        if key == Keyboard.KEY_ESCAPE then return end
        local conflict = KeyConflictDialog.findConflict(key)
        if conflict then
            KeyConflictDialog.show(key, conflict,
                function() setOpt(id, key) end, -- keep both
                function() setOpt(id, 0) end)   -- no key
        else
            setOpt(id, key)
        end
    end
    Events.OnKeyPressed.Add(self._keyHandler)
end

function Window:openColorPicker(option)
    local initialColor = option:getValue() or { r = 0.2, g = 0.5, b = 0.7 }
    local colorPicker = ISColorPicker:new(self:getAbsoluteX() + PAD, self:getAbsoluteY() + self:titleBarHeight() + 40)
    colorPicker:initialise()
    colorPicker:addToUIManager()
    colorPicker:setInitialColor(ColorInfo.new(initialColor.r, initialColor.g, initialColor.b, 1))
    colorPicker:setPickedFunc(function(_target, color)
        setOpt("Select_Color", { r = color.r, g = color.g, b = color.b, a = 1 })
    end)
end

function Window:onSettingClicked(setting)
    local option = getOpt(setting.id)
    if not option then return end
    if setting.kind == "tick" then
        setOpt(setting.id, not option:getValue())
    elseif setting.kind == "color" then
        self:openColorPicker(option)
    elseif setting.kind == "key" then
        self:captureKey(setting.id)
    end
end

function Window:renderSettings()
    local titleHeight = self:titleBarHeight()
    local textManager = getTextManager()
    self._settingsRows = {}

    local currentY = titleHeight + 8
    self:drawText(getText("UI_WorkOrders_Settings"), PAD, currentY, 0.95, 0.82, 0.35, 1, HFONT)
    self:drawRect(PAD, currentY + self.hfontH + 4, self.width - 2 * PAD, 1, 0.4, 0.5, 0.5, 0.5)
    currentY = currentY + self.hfontH + 12

    local rowHeight = math.max(26, self.lineH + 12)
    local mouseX, mouseY = self:getMouseX(), self:getMouseY()
    local boxSize = 18

    for _, setting in ipairs(SETTINGS) do
        local option = getOpt(setting.id)
        local hover = self:isMouseOver() and mouseX >= PAD and mouseX <= self.width - PAD and mouseY >= currentY and mouseY <= currentY + rowHeight
        if hover then self:drawRect(PAD, currentY, self.width - 2 * PAD, rowHeight, 0.14, 1, 1, 1) end

        self:drawText(getText(setting.label), PAD + 6, currentY + (rowHeight - self.lineH) / 2, 0.9, 0.9, 0.9, 1, FONT)

        local controlX = self.width - PAD - 6 - boxSize
        local controlY = currentY + (rowHeight - boxSize) / 2
        if setting.kind == "tick" then
            self:drawRect(controlX, controlY, boxSize, boxSize, 1, 0.10, 0.16, 0.12)
            self:drawRectBorder(controlX, controlY, boxSize, boxSize, 1, 0.5, 0.6, 0.5)
            if option and option:getValue() then
                self:drawRect(controlX + 4, controlY + 4, boxSize - 8, boxSize - 8, 1, 0.93, 0.84, 0.52)
            end
        elseif setting.kind == "color" then
            local color = (option and option:getValue()) or { r = 1, g = 1, b = 1 }
            local swatchWidth = boxSize + 8
            self:drawRect(self.width - PAD - 6 - swatchWidth, controlY, swatchWidth, boxSize, 1, color.r, color.g, color.b)
            self:drawRectBorder(self.width - PAD - 6 - swatchWidth, controlY, swatchWidth, boxSize, 1, 0.6, 0.6, 0.6)
        elseif setting.kind == "key" then
            local keyText
            if self.capturingKey == setting.id then
                keyText = getText("UI_WorkOrders_Settings_PressKey")
            else
                local code = option and option:getValue()
                keyText = (code and code ~= 0 and getKeyName(code)) or "..."
            end
            local textWidth = textManager:MeasureStringX(FONT, keyText)
            self:drawText(keyText, self.width - PAD - 6 - textWidth, currentY + (rowHeight - self.lineH) / 2, 0.92, 0.86, 0.5, 1, FONT)
        end

        table.insert(self._settingsRows, { y = currentY, h = rowHeight, s = setting })
        currentY = currentY + rowHeight + 3
    end
end

function Window:drawResizeGrip()
    for dotRow = 1, 3 do
        for dotCol = 1, dotRow do
            self:drawRect(self.width - FRAME_INSET - (dotCol - 1) * 4, self.height - FRAME_INSET - (3 - dotRow) * 4, 2, 2, 0.6, 0.45, 0.7, 0.5)
        end
    end
end

function Window:render()
    local titleHeight = self:titleBarHeight()
    local titleTexture = loadTitle()
    if titleTexture then
        local drawHeight = titleHeight - 8
        local drawWidth = titleTexture:getWidth() * (drawHeight / titleTexture:getHeight())
        local maxWidth = self.width - 2 * PANEL_C - 24
        if maxWidth > 0 and drawWidth > maxWidth then drawHeight = drawHeight * (maxWidth / drawWidth); drawWidth = maxWidth end
        self:drawTextureScaled(titleTexture, (self.width - drawWidth) / 2, (titleHeight - drawHeight) / 2, drawWidth, drawHeight, 1, 1, 1, 1)
    else
        self:drawTextCentre(self.title, self.width / 2, math.max(1, (titleHeight - self.hfontH) / 2),
            0.96, 0.88, 0.5, 1, HFONT)
    end
    self:drawRect(PANEL_C, titleHeight, self.width - 2 * PANEL_C, 1, 0.5, 0.35, 0.58, 0.42)

    -- the settings page hijacks all your shit
    if self.settingsOpen then
        self._tabs = nil
        self.hovered = nil
        self.hoveredTab = nil
        self:renderSettings()
        self:drawResizeGrip()
        return
    end

    -- setup any domain tabs
    self._tabs = nil
    self.hoveredTab = nil
    if self.domains and #self.domains > 1 then
        self._tabs = {}
        local tabY = titleHeight
        local mouseX, mouseY = self:getMouseX(), self:getMouseY()
        for tabIndex, domain in ipairs(self.domains) do
            local tabX = PAD + (tabIndex - 1) * (TAB_W + 4)
            local active = (domain.id == self.activeDomainId)
            local hover = self:isMouseOver() and mouseX >= tabX and mouseX <= tabX + TAB_W and mouseY >= tabY and mouseY <= tabY + TAB_H
            self:drawRect(tabX, tabY + 4, TAB_W, TAB_H - 5, active and 0.30 or (hover and 0.16 or 0.06), 0.45, 0.62, 0.45)
            if domain.icon then
                local iconSize = TAB_ICON
                self:drawTextureScaled(domain.icon, tabX + (TAB_W - iconSize) / 2, tabY + 4 + (TAB_H - 5 - iconSize) / 2, iconSize, iconSize, active and 1 or 0.75, 1, 1, 1)
            end
            if active then
                self:drawRect(tabX, tabY + TAB_H - 2, TAB_W, 2, 1, 0.86, 0.70, 0.35)
            end
            if hover then self.hoveredTab = domain end
            self._tabs[#self._tabs + 1] = { x = tabX, y = tabY, w = TAB_W, h = TAB_H, id = domain.id }
        end
    end

    local top = self:contentTop()
    local viewHeight = self:contentViewH()
    local textManager = getTextManager()

    self:setStencilRect(0, top, self.width, viewHeight)

    local baseY = top - self.scrollY
    self.hovered = nil
    local mouseX, mouseY = self:getMouseX(), self:getMouseY()
    local mouseInView = self:isMouseOver() and mouseY >= top and mouseY <= self:contentBottom()

    for _, header in ipairs(self._layout.headers) do
        local headerY = baseY + header.y
        local headerIconSize = self.hfontH
        if header.group.icon then
            self:drawTextureScaled(header.group.icon, PAD, headerY + 2 + (self.hfontH - headerIconSize) / 2, headerIconSize, headerIconSize, 1, 1, 1, 1)
        end
        self:drawText(header.group.label, PAD + headerIconSize + 6, headerY + 2, 0.95, 0.82, 0.35, 1, HFONT)
        self:drawRect(PAD, headerY + self.hfontH + 4, self.width - 2 * PAD, 1, 0.4, 0.5, 0.5, 0.5)
    end

    for _, cell in ipairs(self._layout.cells) do
        local item = cell.item
        local cellX, cellY = cell.x, baseY + cell.y
        local iconX = cellX + (CELL_W - ICON) / 2
        local enabled = item.enabled
        local iconAlpha = enabled and 1.0 or 0.30

        local isHover = mouseInView and mouseX >= cellX and mouseX <= cellX + CELL_W and mouseY >= cellY and mouseY <= cellY + self.cellH
        if isHover then
            self.hovered = item
            if enabled then
                self:drawRect(cellX, cellY, CELL_W, self.cellH, 0.18, 1, 1, 1)
            end
        end

        if item.icon then
            local iconShade = enabled and 1 or 0.7
            self:drawTextureScaled(item.icon, iconX, cellY, ICON, ICON, iconAlpha, iconShade, iconShade, iconShade)
        end

        local textShade = enabled and 0.92 or 0.55
        local textAlpha = enabled and 1 or 0.6
        local lines = wrapLabel(item.label, CELL_W - 6, FONT, LABEL_LINES)
        local textY = cellY + ICON + 2
        for lineIndex = 1, #lines do
            self:drawTextCentre(lines[lineIndex], cellX + CELL_W / 2, textY + (lineIndex - 1) * self.lineH, textShade, textShade, textShade, textAlpha, FONT)
        end
    end

    self:clearStencilRect()

    local maxScroll = math.max(0, self.contentH - viewHeight)
    if maxScroll > 0 then
        local trackHeight = viewHeight
        local thumbHeight = math.max(20, trackHeight * (viewHeight / self.contentH))
        local thumbY = top + (trackHeight - thumbHeight) * (self.scrollY / maxScroll)
        self:drawRect(self.width - 10, thumbY, 3, thumbHeight, 0.5, 0.8, 0.8, 0.8)
    end

    self:drawResizeGrip()

    if self.hovered then
        self:renderTooltip(self.hovered, mouseX, mouseY)
    elseif self.hoveredTab then
        local label = self.hoveredTab.label or ""
        local labelWidth, fontHeight = textManager:MeasureStringX(FONT, label), textManager:getFontHeight(FONT)
        local boxX = math.min(mouseX + 12, self.width - labelWidth - 14)
        local boxY = mouseY + 14
        self:drawRect(boxX, boxY, labelWidth + 10, fontHeight + 6, 0.92, 0.05, 0.05, 0.06)
        self:drawRectBorder(boxX, boxY, labelWidth + 10, fontHeight + 6, 0.8, 0.4, 0.4, 0.45)
        self:drawText(label, boxX + 5, boxY + 3, 0.95, 0.85, 0.55, 1, FONT)
    end
end

function Window:renderTooltip(item, mouseX, mouseY)
    local lines = {}
    if item.reqTagKey and not item.enabled then
        table.insert(lines, getText("UI_WorkOrders_Menu_Tooltip_Requires") .. ": " .. getText(item.reqTagKey))
    elseif item.tooltipKey then
        table.insert(lines, getText(item.tooltipKey))
    end
    if #lines == 0 then return end
    local textManager = getTextManager()
    local textWidth = 0
    for _, line in ipairs(lines) do textWidth = math.max(textWidth, textManager:MeasureStringX(FONT, line)) end
    local tooltipHeight = #lines * (textManager:getFontHeight(FONT)) + 8
    local boxX = math.min(mouseX + 14, self.width - textWidth - 12)
    local boxY = mouseY + 14
    self:drawRect(boxX, boxY, textWidth + 12, tooltipHeight, 0.92, 0.05, 0.05, 0.06)
    self:drawRectBorder(boxX, boxY, textWidth + 12, tooltipHeight, 0.8, 0.4, 0.4, 0.45)
    local lineY = boxY + 4
    for _, line in ipairs(lines) do
        self:drawText(line, boxX + 6, lineY, 0.95, 0.85, 0.55, 1, FONT)
        lineY = lineY + textManager:getFontHeight(FONT)
    end
end

function Window:onMouseWheel(delta)
    self.scrollY = self.scrollY + delta * 40
    self:clampScroll()
    return true
end

-- the drag is over - let go, your too old. nobody listens to techno!
function Window:onMouseMove(deltaX, deltaY)
    if self.moving and not isMouseButtonDown(0) then
        self.moving = false
        return
    end
    ISCollapsableWindow.onMouseMove(self, deltaX, deltaY)
end

function Window:onMouseMoveOutside(deltaX, deltaY)
    if self.moving and not isMouseButtonDown(0) then
        self.moving = false
        return
    end
    ISCollapsableWindow.onMouseMoveOutside(self, deltaX, deltaY)
end

-- only the title bar drags othwise clicking an "order" might yeet the whole thing
function Window:onMouseDown(mouseX, mouseY)
    if not self:getIsVisible() then return end
    if mouseY < self:titleBarHeight() then
        return ISCollapsableWindow.onMouseDown(self, mouseX, mouseY)
    end
    self.moving = false
    self:bringToTop()
    return true
end

function Window:onMouseUp(mouseX, mouseY)
    local titleHeight = self:titleBarHeight()

    if self.settingsOpen then
        if mouseY < titleHeight then return ISCollapsableWindow.onMouseUp(self, mouseX, mouseY) end
        ISCollapsableWindow.onMouseUp(self, mouseX, mouseY)
        for _, row in ipairs(self._settingsRows or {}) do
            if mouseX >= PAD and mouseX <= self.width - PAD and mouseY >= row.y and mouseY <= row.y + row.h then
                getSoundManager():playUISound("UIActivateButton")
                self:onSettingClicked(row.s)
                return true
            end
        end
        return true
    end

    if self._tabs and mouseY >= titleHeight and mouseY < self:contentTop() then
        for _, tab in ipairs(self._tabs) do
            if mouseX >= tab.x and mouseX <= tab.x + tab.w and mouseY >= tab.y and mouseY <= tab.y + tab.h then
                if tab.id ~= self.activeDomainId then
                    getSoundManager():playUISound("UIActivateTab")
                    self.activeDomainId = tab.id
                    self.scrollY = 0
                end
                return true
            end
        end
        return true
    end
    if mouseY < titleHeight then
        return ISCollapsableWindow.onMouseUp(self, mouseX, mouseY)
    end
    ISCollapsableWindow.onMouseUp(self, mouseX, mouseY)

    if not self._layout then return true end
    local baseY = self:contentTop() - self.scrollY
    for _, cell in ipairs(self._layout.cells) do
        local cellX, cellY = cell.x, baseY + cell.y
        if mouseX >= cellX and mouseX <= cellX + CELL_W and mouseY >= cellY and mouseY <= cellY + self.cellH then
            if cell.item.enabled then
                getSoundManager():playUISound("UIActivateButton")
                WorkOrders.CloseWindow()
                cell.item.run(player(), self.flags)
            end
            return true
        end
    end
    return true
end

function Window:saveRect()
    local playerObj = player()
    if not playerObj then return end
    playerObj:getModData().WorkOrders_WindowRect = {
        x = self:getX(), y = self:getY(), w = self:getWidth(), h = self:getHeight(),
    }
end

function Window:close()
    self:cancelKeyCapture()
    self:saveRect()
    savedUIState = { activeDomainId = self.activeDomainId, scrollY = self.scrollY }
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    Window.instance = nil
end

-- open/close/toggle shit
function WorkOrders.OpenWindow()
    if Window.instance then
        Window.instance:refresh()
        Window.instance.scrollY = 0 -- reopen at the top
        Window.instance:setVisible(true)
        Window.instance:bringToTop()
        return Window.instance
    end
    local playerObj = player()
    if not playerObj then return end

    local screenWidth, screenHeight = getCore():getScreenWidth(), getCore():getScreenHeight()
    local rect = playerObj:getModData().WorkOrders_WindowRect
    local width = rect and rect.w or (2 * PAD + 3 * CELL_W + 2 * GAP)
    local height = rect and rect.h or 420
    local posX = rect and rect.x or (screenWidth / 2 - width / 2)
    local posY = rect and rect.y or (screenHeight / 2 - height / 2)

    -- keep window on the damn screen
    width = math.min(width, screenWidth)
    height = math.min(height, screenHeight)
    posX = math.max(0, math.min(posX, screenWidth - width))
    posY = math.max(0, math.min(posY, screenHeight - height))

    local window = Window:new(posX, posY, width, height)
    window:initialise()
    window:addToUIManager()
    window:refresh()
    -- open back where the player left off
    if savedUIState then
        if savedUIState.activeDomainId then
            window.activeDomainId = savedUIState.activeDomainId
            window:ensureActiveDomain()
        end
        window.scrollY = savedUIState.scrollY or 0
    end
    Window.instance = window
    return window
end

function WorkOrders.CloseWindow()
    if Window.instance then Window.instance:close() end
end

function WorkOrders.ToggleWindow()
    if Window.instance then
        WorkOrders.CloseWindow()
    else
        WorkOrders.OpenWindow()
    end
end

return Window
