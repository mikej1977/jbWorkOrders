-- Shapes and callback signatures this module hands back:
--
--   selectedSquare = IsoGridSquare
--   selectedArea   = { squares = { IsoGridSquare, ... },
--                      minX, maxX, minY, maxY, z,
--                      areaWidth, areaHeight, numSquares }
--
--   SelectSingleSquare  callback(playerObj, worldObjects, square, ...)
--   SelectArea          callback(playerObj, worldObjects, area, ...)
--   SelectSquareAndArea callback(playerObj, worldObjects, square, area, ...)
--   SelectLine          callback(playerObj, worldObjects, line, ...)
--   SelectLines         callback(playerObj, worldObjects, lines, ...)

local SquareUtils = require("helpers/wo_SquareUtils")
local Options = require("helpers/wo_Options")

local SelectUtils = {}

-- keep for compat with my old worser code
SelectUtils.highlightColorData = nil

local DEFAULT_COLOR = { r = 0.2, g = 0.5, b = 0.7 }

SelectUtils.VALID_COLOR   = { r = 0.35, g = 0.9,  b = 0.4 } -- getGoodhighlightColor?
SelectUtils.INVALID_COLOR = { r = 0.9,  g = 0.35, b = 0.35 } -- getbadhighlightcolor?
SelectUtils.nextPickValidator = nil

-- reopen the menu if you canceeled out
SelectUtils.nextOnCancel = nil

local active = nil

local highlights = {}
local drawHighlights

local function endSession()
    if not active then return end
    local handlers = active.handlers
    active = nil
    highlights = {}
    WorkOrders.selecting = false
    for _, handler in ipairs(handlers) do
        Events[handler.ev].Remove(handler.fn)
    end
end

local function cancelSession()
    WorkOrders.suppressContextMenu = true
    local onCancel = active and active.onCancel
    endSession()
    if onCancel then onCancel() end
end

local function beginSession(playerObj)
    endSession()
    active = { handlers = {}, playerObj = playerObj,
        pickValidator = SelectUtils.nextPickValidator, onCancel = SelectUtils.nextOnCancel }
    SelectUtils.nextPickValidator = nil
    SelectUtils.nextOnCancel = nil
    WorkOrders.selecting = true
    highlights = {}
    local drawFunc = function() if drawHighlights then drawHighlights() end end
    Events.OnPreUIDraw.Add(drawFunc)
    table.insert(active.handlers, { ev = "OnPreUIDraw", fn = drawFunc })
    return active
end

local function addHandler(eventName, handlerFunc)
    if not active then return end
    Events[eventName].Add(handlerFunc)
    table.insert(active.handlers, { ev = eventName, fn = handlerFunc })
end

function SelectUtils.Cancel()
    endSession()
end

function SelectUtils.IsSelecting()
    return active ~= nil
end

function SelectUtils.GetMouseCoords(playerObj)
    local worldZ = playerObj:getZ()
    local worldX, worldY = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), worldZ)
    return math.floor(worldX), math.floor(worldY), worldZ
end

function SelectUtils.IsMidAir(square)
    if not square then return true end
    return square:getZ() > 0 and not square:getFloor()
end

function SelectUtils.CancelActions(playerObj)
    if instanceof(playerObj, "IsoPlayer") then
        if playerObj:isAttacking() or Mouse.isRightDown() then
            return true
        end
        return false
    end
    return true
end

function SelectUtils.GetPickedColor(playerObj)
    local pickedColor = Options.get("Select_Color")
    if pickedColor and pickedColor.r then
        local color = { r = pickedColor.r, g = pickedColor.g, b = pickedColor.b }
        SelectUtils.highlightColorData = color
        if playerObj then playerObj:getModData().highlightColorData = color end
        return color
    end

    if playerObj then
        local stored = playerObj:getModData().highlightColorData
        if stored and stored.r then return stored end
        playerObj:getModData().highlightColorData = DEFAULT_COLOR
    end
    return SelectUtils.highlightColorData or DEFAULT_COLOR
end

function SelectUtils.PickColor(worldObjects, playerObj)
    local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
    local buttonSize = FONT_HGT_SMALL + 6
    local borderSize = 11
    local pickerX = (getCore():getScreenWidth() / 4) - (14 * buttonSize + borderSize * 2) / 2
    local pickerY = (getCore():getScreenHeight() / 3) - (6 * buttonSize + borderSize * 2) / 2
    local colorPicker = ISColorPicker:new(pickerX, pickerY)
    colorPicker:initialise()
    colorPicker:addToUIManager()
    colorPicker:setPickedFunc(function()
        local color = colorPicker.colors[colorPicker.index]
        local data = { r = color.r, g = color.g, b = color.b }
        if playerObj then playerObj:getModData().highlightColorData = data end
        SelectUtils.highlightColorData = data
    end)
end

function SelectUtils.SortSquaresClosest(playerObj, squares)
    local square = playerObj:getSquare()
    if not square then return squares end
    return SquareUtils.orderByProximity(square:getX(), square:getY(), square:getZ(), squares)
end

SelectUtils.Style = {
    heightLevels = 0.15,
    bands        = 5,
    alphaBase    = 0.35,
    falloff      = 1.7, 
    capAlpha     = 0.15,
}

local function drawWall(renderer, screenX1, screenY1, screenX2, screenY2, height, color)
    local style = SelectUtils.Style
    local bandCount = style.bands
    for bandIndex = 0, bandCount - 1 do
        local lowerFraction = bandIndex / bandCount
        local upperFraction = (bandIndex + 1) / bandCount
        local alpha = style.alphaBase * (1 - lowerFraction) ^ style.falloff
        renderer:renderPoly(
            screenX1, screenY1 - height * lowerFraction,
            screenX2, screenY2 - height * lowerFraction,
            screenX2, screenY2 - height * upperFraction,
            screenX1, screenY1 - height * upperFraction,
            color.r, color.g, color.b, alpha)
    end
end

local function screenPt(worldX, worldY, worldZ, zoom)
    local screenX, screenY = ISCoordConversion.ToScreen(worldX, worldY, worldZ)
    return screenX / zoom, screenY / zoom
end

local function drawAreaOutline(renderer, minX, minY, maxX, maxY, areaZ, color, zoom)
    local northX, northY = screenPt(minX, minY, areaZ, zoom) -- north
    local eastX, eastY = screenPt(maxX + 1, minY, areaZ, zoom) -- east
    local southX, southY = screenPt(maxX + 1, maxY + 1, areaZ, zoom) -- south
    local westX, westY = screenPt(minX, maxY + 1, areaZ, zoom) -- west

    local _, upScreenY = screenPt(minX, minY, areaZ + 1, zoom)
    local height = (northY - upScreenY) * SelectUtils.Style.heightLevels

    if SelectUtils.Style.capAlpha > 0 then
        renderer:renderPoly(northX, northY, eastX, eastY, southX, southY, westX, westY,
            color.r, color.g, color.b, SelectUtils.Style.capAlpha)
    end

    drawWall(renderer, northX, northY, eastX, eastY, height, color) -- NE
    drawWall(renderer, eastX, eastY, southX, southY, height, color) -- SE
    drawWall(renderer, southX, southY, westX, westY, height, color) -- SW
    drawWall(renderer, westX, westY, northX, northY, height, color) -- NW
end

drawHighlights = function()
    if not active or #highlights == 0 then return end
    local renderer = getRenderer()
    if not renderer then return end

    local playerNum = 0
    local playerObj = active.playerObj
    if playerObj and playerObj.getPlayerNum then playerNum = playerObj:getPlayerNum() end
    local zoom = getCore():getZoom(playerNum)
    if not zoom or zoom <= 0 then zoom = 1 end

    for _, highlight in ipairs(highlights) do
        drawAreaOutline(renderer, highlight.minX, highlight.minY, highlight.maxX, highlight.maxY, highlight.z, highlight.color, zoom)
    end
end

function SelectUtils.ClearHighlights()
    highlights = {}
end

function SelectUtils.HighlightSquare(playerObj, square, color)
    if not square or SelectUtils.IsMidAir(square) then return end
    color = color or SelectUtils.GetPickedColor(playerObj)
    local squareX, squareY, squareZ = square:getX(), square:getY(), square:getZ()
    table.insert(highlights, { minX = squareX, minY = squareY, maxX = squareX, maxY = squareY, z = squareZ, color = color })
end

function SelectUtils.HighlightMouseSquare(playerObj, color)
    local worldX, worldY, worldZ = SelectUtils.GetMouseCoords(playerObj)
    SelectUtils.HighlightSquare(playerObj, getSquare(worldX, worldY, worldZ), color)
end

function SelectUtils.HighlightArea(playerObj, startX, startY, endX, endY, areaZ, color)
    color = color or SelectUtils.GetPickedColor(playerObj)
    local minX, maxX = math.min(startX, endX), math.max(startX, endX)
    local minY, maxY = math.min(startY, endY), math.max(startY, endY)
    table.insert(highlights, { minX = minX, minY = minY, maxX = maxX, maxY = maxY, z = areaZ, color = color })
end

function SelectUtils.OutlineCoords(worldX, worldY, worldZ, color)
    addAreaHighlight(worldX, worldY, worldX + 1, worldY + 1, worldZ, color.r, color.g, color.b, 0)
end

function SelectUtils.OutlineSquare(playerObj, square, color)
    if not square then return end
    color = color or SelectUtils.GetPickedColor(playerObj)
    SelectUtils.OutlineCoords(square:getX(), square:getY(), square:getZ(), color)
end

local function buildArea(startX, startY, endX, endY, areaZ)
    local minX, maxX = math.min(startX, endX), math.max(startX, endX)
    local minY, maxY = math.min(startY, endY), math.max(startY, endY)

    local area = { squares = {} }
    for tileX = minX, maxX do
        for tileY = minY, maxY do
            local square = getSquare(tileX, tileY, areaZ)
            if square and not SelectUtils.IsMidAir(square) then
                table.insert(area.squares, square)
            end
        end
    end

    area.minX, area.maxX = minX, maxX
    area.minY, area.maxY = minY, maxY
    area.z = areaZ
    area.areaWidth = maxX - minX
    area.areaHeight = maxY - minY
    area.numSquares = #area.squares

    table.insert(area, {
        minX = minX, minY = minY, maxX = maxX, maxY = maxY, z = areaZ,
        areaWidth = area.areaWidth, areaHeight = area.areaHeight,
        numSquares = area.numSquares,
    })
    return area
end

local function bresenham(startX, startY, endX, endY, areaZ)
    local line = {}
    local deltaX, deltaY = math.abs(endX - startX), math.abs(endY - startY)
    local stepX = startX < endX and 1 or -1
    local stepY = startY < endY and 1 or -1
    local err = deltaX - deltaY
    local currentX, currentY = startX, startY
    while true do
        local square = getSquare(currentX, currentY, areaZ)
        if square then table.insert(line, square) end
        if currentX == endX and currentY == endY then break end
        local doubledError = 2 * err
        if doubledError > -deltaY then err = err - deltaY; currentX = currentX + stepX end
        if doubledError < deltaX then err = err + deltaX; currentY = currentY + stepY end
    end
    return line
end

function SelectUtils.SelectSingleSquare(worldObjects, playerObj, callbackFunc, ...)
    local forwardedArgs = { ... }
    beginSession(playerObj)
    local color = SelectUtils.GetPickedColor(playerObj)
    local pickValidator = active.pickValidator
    local armed = false -- ignore the mouseup

    addHandler("OnMouseDown", function()
        armed = true
    end)

    addHandler("OnMouseUp", function()
        if not armed then return end
        local square = getSquare(SelectUtils.GetMouseCoords(playerObj))
        if SelectUtils.IsMidAir(square) then return end
        endSession()
        if callbackFunc then
            return callbackFunc(playerObj, worldObjects, square, unpack(forwardedArgs))
        end
        return square
    end)

    addHandler("OnTick", function()
        if SelectUtils.CancelActions(playerObj) then return cancelSession() end
        SelectUtils.ClearHighlights()
        if pickValidator then
            local worldX, worldY, worldZ = SelectUtils.GetMouseCoords(playerObj)
            local mouseSquare = getSquare(worldX, worldY, worldZ)
            local pickColor = (mouseSquare and pickValidator(mouseSquare, playerObj))
                and SelectUtils.VALID_COLOR or SelectUtils.INVALID_COLOR
            SelectUtils.HighlightSquare(playerObj, mouseSquare, pickColor)
        else
            SelectUtils.HighlightMouseSquare(playerObj, color)
        end
    end)
end

function SelectUtils.SelectArea(worldObjects, playerObj, callbackFunc, ...)
    local forwardedArgs = { ... }
    beginSession(playerObj)
    local color = SelectUtils.GetPickedColor(playerObj)
    local dragging = false
    local startX, startY, endX, endY, areaZ

    addHandler("OnMouseDown", function()
        if dragging then return end
        startX, startY, areaZ = SelectUtils.GetMouseCoords(playerObj)
        endX, endY = startX, startY
        dragging = true
    end)

    addHandler("OnMouseUp", function()
        if not dragging then return end -- ignore the first up
        endX, endY = SelectUtils.GetMouseCoords(playerObj)
        local area = buildArea(startX, startY, endX, endY, areaZ)
        endSession()
        if callbackFunc then
            return callbackFunc(playerObj, worldObjects, area, unpack(forwardedArgs))
        end
        return area
    end)

    addHandler("OnTick", function()
        if SelectUtils.CancelActions(playerObj) then return cancelSession() end
        SelectUtils.ClearHighlights()
        endX, endY = SelectUtils.GetMouseCoords(playerObj)
        if dragging then
            SelectUtils.HighlightArea(playerObj, startX, startY, endX, endY, areaZ, color)
        else
            SelectUtils.HighlightMouseSquare(playerObj, color)
        end
    end)
end

function SelectUtils.SelectSquareAndArea(worldObjects, playerObj, callbackFunc, ...)
    local forwardedArgs = { ... }
    beginSession(playerObj)
    local color = SelectUtils.GetPickedColor(playerObj)
    local pickValidator = active.pickValidator
    local armed, dragging = false, false
    local selectedSquare
    local startX, startY, endX, endY, areaZ

    addHandler("OnMouseDown", function()
        if not selectedSquare then
            armed = true -- eat a click until shit gets real
            return
        end
        if dragging then return end
        startX, startY, areaZ = SelectUtils.GetMouseCoords(playerObj)
        endX, endY = startX, startY
        dragging = true
    end)

    addHandler("OnMouseUp", function()
        if not selectedSquare then
            if not armed then return end
            selectedSquare = getSquare(SelectUtils.GetMouseCoords(playerObj))
            return
        end
        if not dragging then return end
        endX, endY = SelectUtils.GetMouseCoords(playerObj)
        local area = buildArea(startX, startY, endX, endY, areaZ)
        endSession()
        if callbackFunc then
            return callbackFunc(playerObj, worldObjects, selectedSquare, area, unpack(forwardedArgs))
        end
        return selectedSquare, area
    end)

    addHandler("OnTick", function()
        if SelectUtils.CancelActions(playerObj) then return cancelSession() end
        SelectUtils.ClearHighlights()
        endX, endY = SelectUtils.GetMouseCoords(playerObj)
        if selectedSquare then
            SelectUtils.HighlightSquare(playerObj, selectedSquare, color)
        end
        if dragging then
            SelectUtils.HighlightArea(playerObj, startX, startY, endX, endY, areaZ, color)
        elseif pickValidator and not selectedSquare then
            local worldX, worldY, worldZ = SelectUtils.GetMouseCoords(playerObj)
            local mouseSquare = getSquare(worldX, worldY, worldZ)
            local pickColor = (mouseSquare and pickValidator(mouseSquare, playerObj))
                and SelectUtils.VALID_COLOR or SelectUtils.INVALID_COLOR
            SelectUtils.HighlightSquare(playerObj, mouseSquare, pickColor)
        else
            SelectUtils.HighlightMouseSquare(playerObj, color)
        end
    end)
end

function SelectUtils.SelectLine(worldObjects, playerObj, callbackFunc, ...)
    local forwardedArgs = { ... }
    beginSession(playerObj)
    local color = SelectUtils.GetPickedColor(playerObj)
    local dragging = false
    local startX, startY, endX, endY, areaZ

    addHandler("OnMouseDown", function()
        if dragging then return end
        startX, startY, areaZ = SelectUtils.GetMouseCoords(playerObj)
        endX, endY = startX, startY
        dragging = true
    end)

    addHandler("OnMouseUp", function()
        if not dragging then return end
        endX, endY = SelectUtils.GetMouseCoords(playerObj)
        local line = bresenham(startX, startY, endX, endY, areaZ)
        endSession()
        if callbackFunc then
            return callbackFunc(playerObj, worldObjects, line, unpack(forwardedArgs))
        end
        return line
    end)

    addHandler("OnTick", function()
        if SelectUtils.CancelActions(playerObj) then return cancelSession() end
        SelectUtils.ClearHighlights()
        if not dragging then
            SelectUtils.HighlightMouseSquare(playerObj, color)
            return
        end
        endX, endY = SelectUtils.GetMouseCoords(playerObj)
        for _, square in ipairs(bresenham(startX, startY, endX, endY, areaZ)) do
            SelectUtils.HighlightSquare(playerObj, square, color)
        end
    end)
end

function SelectUtils.SelectLines(worldObjects, playerObj, callbackFunc, ...)
    local forwardedArgs = { ... }
    beginSession(playerObj)
    local color = SelectUtils.GetPickedColor(playerObj)
    local dragging = false
    local startX, startY, endX, endY, areaZ

    addHandler("OnMouseDown", function()
        if dragging then return end
        startX, startY, areaZ = SelectUtils.GetMouseCoords(playerObj)
        endX, endY = startX, startY
        dragging = true
    end)

    addHandler("OnMouseUp", function()
        if not dragging then return end
        endX, endY = SelectUtils.GetMouseCoords(playerObj)
        local minX, maxX = math.min(startX, endX), math.max(startX, endX)
        local minY, maxY = math.min(startY, endY), math.max(startY, endY)
        local lines = { lineX = {}, lineY = {} }
        for tileX = minX, maxX do
            table.insert(lines.lineX, getSquare(tileX, startY, areaZ))
        end
        for tileY = minY, maxY do
            table.insert(lines.lineY, getSquare(endX, tileY, areaZ))
        end
        endSession()
        if callbackFunc then
            return callbackFunc(playerObj, worldObjects, lines, unpack(forwardedArgs))
        end
        return lines
    end)

    addHandler("OnTick", function()
        if SelectUtils.CancelActions(playerObj) then return cancelSession() end
        SelectUtils.ClearHighlights()
        endX, endY = SelectUtils.GetMouseCoords(playerObj)
        if not dragging then
            SelectUtils.HighlightMouseSquare(playerObj, color)
            return
        end
        SelectUtils.HighlightArea(playerObj, startX, startY, endX, startY, areaZ, color)
        SelectUtils.HighlightArea(playerObj, endX, startY, endX, endY, areaZ, color)
    end)
end

WorkOrders = WorkOrders or {}
WorkOrders.SelectUtils = SelectUtils

return SelectUtils
