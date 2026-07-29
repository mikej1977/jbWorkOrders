require("wo_WorkOrdersWindow")

WorkOrders = WorkOrders or {}

local HUD_SIZE = 42
-- px of mosue slop before we know the player is REALLY dragging and not just clicking
local DRAG_THRESHOLD = 4

local Options = require("helpers/wo_Options")

local function getOption(name)
    return Options.get(name)
end

local function isOptionEnabled(name)
    return Options.getBool(name)
end

Events.OnKeyStartPressed.Add(function(key)
    local boundKey = getOption("Open_Window_Key")
    if not boundKey or boundKey == 0 or key ~= boundKey then return end
    local playerObj = getSpecificPlayer(0)
    if not playerObj or playerObj:isDead() then return end
    WorkOrders.ToggleWindow()
end)

local HUDButton = ISPanel:derive("WorkOrdersHUDButton")

-- puts it back where they left it, or somewhere close if the shit is gone
function HUDButton:new()
    local playerObj = getSpecificPlayer(0)
    local screenWidth, screenHeight = getCore():getScreenWidth(), getCore():getScreenHeight()
    local savedPos = playerObj and playerObj:getModData().WorkOrders_HUDPos
    local posX = savedPos and savedPos.x or (screenWidth - HUD_SIZE - 20)
    local posY = savedPos and savedPos.y or (screenHeight / 2)
    posX = math.max(0, math.min(posX, screenWidth - HUD_SIZE))
    posY = math.max(0, math.min(posY, screenHeight - HUD_SIZE))

    local button = ISPanel.new(self, posX, posY, HUD_SIZE, HUD_SIZE)
    button.backgroundColor = { r = 0.05, g = 0.05, b = 0.06, a = 0.75 }
    button.borderColor     = { r = 0.35, g = 0.35, b = 0.38, a = 1 }
    button.icon = getTexture("media/ui/Radial/Logging.png")
    button.isMoving = false
    button.wasDragged = false
    return button
end

function HUDButton:render()
    local background, border = self.backgroundColor, self.borderColor
    self:drawRect(0, 0, self.width, self.height, background.a, background.r, background.g, background.b)
    self:drawRectBorder(0, 0, self.width, self.height, border.a, border.r, border.g, border.b)
    if self.icon then
        self:drawTextureScaled(self.icon, 5, 5, HUD_SIZE - 10, HUD_SIZE - 10, 1, 1, 1, 1)
    end
    if self:isMouseOver() and not self.isMoving then
        self:drawRect(0, 0, self.width, self.height, 0.15, 1, 1, 1)
    end
end

function HUDButton:savePosition()
    local playerObj = getSpecificPlayer(0)
    if not playerObj then return end
    playerObj:getModData().WorkOrders_HUDPos = { x = self:getX(), y = self:getY() }
end

function HUDButton:onMouseDown(mouseX, mouseY)
    self.isMoving = true
    self.wasDragged = false
    self.pressedAtX = getMouseX()
    self.pressedAtY = getMouseY()
    self.grabOffsetX = getMouseX() - self:getX()
    self.grabOffsetY = getMouseY() - self:getY()
    return true
end

function HUDButton:onMouseMove(deltaX, deltaY)
    if not self.isMoving then return end

    if not self.wasDragged
        and (math.abs(getMouseX() - self.pressedAtX) > DRAG_THRESHOLD
          or math.abs(getMouseY() - self.pressedAtY) > DRAG_THRESHOLD) then
        self.wasDragged = true
    end

    if self.wasDragged then
        self:setX(getMouseX() - self.grabOffsetX)
        self:setY(getMouseY() - self.grabOffsetY)
    end
end

function HUDButton:onMouseMoveOutside(deltaX, deltaY)
    self:onMouseMove(deltaX, deltaY)
end

function HUDButton:onMouseUp(mouseX, mouseY)
    if not self.isMoving then return true end
    self.isMoving = false
    if self.wasDragged then
        self:savePosition()
    else
        WorkOrders.ToggleWindow()
    end
    return true
end

-- letting go of the button still ends the drag
function HUDButton:onMouseUpOutside(mouseX, mouseY)
    if not self.isMoving then return end
    self.isMoving = false
    if self.wasDragged then self:savePosition() end
end

local activeHUDButton = nil

function WorkOrders.RefreshHUDButton()
    local shouldExist = isOptionEnabled("Open_With_HUDButton") and getSpecificPlayer(0) ~= nil
    if shouldExist and not activeHUDButton then
        activeHUDButton = HUDButton:new()
        activeHUDButton:initialise()
        activeHUDButton:addToUIManager()
    elseif not shouldExist and activeHUDButton then
        activeHUDButton:removeFromUIManager()
        activeHUDButton = nil
    end
end

Events.OnCreatePlayer.Add(function(playerIndex)
    if playerIndex == 0 then WorkOrders.RefreshHUDButton() end
end)

Events.OnPlayerDeath.Add(function(playerObj)
    if activeHUDButton and playerObj == getSpecificPlayer(0) then
        activeHUDButton:removeFromUIManager()
        activeHUDButton = nil
    end
end)
