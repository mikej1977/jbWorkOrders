local ActionPlayer = require("helpers/wo_ActionPlayer")
local SelectUtils  = require("wo_SelectUtils")
local SquareUtils  = require("helpers/wo_SquareUtils")
local Options      = require("helpers/wo_Options")

local CorpseMover = {}

-- how long before we say fuck it
local PICKUP_HOLD_MS  = 170
local LAYDOWN_HOLD_MS = 170
local GRAB_GIVEUP_MS  = 300
local LOST_GIVEUP_MS  = 150
local MAX_DROPWALKS   = 5
local WEDGE_MS        = 2000
local SETTLE_MS       = 1000

CorpseMover.debug = false
local function debugLog(message) if CorpseMover.debug then print("[BOYD] " .. message) end end

local jobs = {} -- [playerNum] = job

local function safetyOn()
    return Options.getBool("Stop_Near_Zombies", true)
end

local function highlightStaging(job)
    SelectUtils.OutlineSquare(job.playerObj, job.stagingSquare)
end

local function onStagingSquare(job)
    local playerSquare, stagingSquare = job.playerObj:getSquare(), job.stagingSquare
    return playerSquare
        and playerSquare:getX() == stagingSquare:getX()
        and playerSquare:getY() == stagingSquare:getY()
        and playerSquare:getZ() == stagingSquare:getZ()
end

local function notMoving(job)
    local playerObj = job.playerObj
    local playerX, playerY, playerZ = playerObj:getX(), playerObj:getY(), playerObj:getZ()
    local now = job.clockMs
    if not job.lastX then
        job.lastX, job.lastY, job.lastZ = playerX, playerY, playerZ
        job.wedgeCheckAt = now
        return false
    end
    if now - job.wedgeCheckAt < WEDGE_MS then return false end
    local wedged = math.abs(playerX - job.lastX) + math.abs(playerY - job.lastY)
        + math.abs(playerZ - job.lastZ) < 0.3
    job.lastX, job.lastY, job.lastZ = playerX, playerY, playerZ
    job.wedgeCheckAt = now
    return wedged
end

local function finishJob(playerNum)
    local job = jobs[playerNum]
    if not job then return end
    jobs[playerNum] = nil
    if job.tick then
        Events.OnTick.Remove(job.tick)
        job.tick = nil
    end
    -- never leave a body halfass grappled or it can reanimate and fuck that
    if job.playerObj and job.playerObj:isGrappling() then
        job.playerObj:setDoGrappleLetGo()
    end
end

local function makeAuxTick(job)
    return function()
        local playerObj = job.playerObj
        if not instanceof(playerObj, "IsoPlayer") then return end

        local now = getTimestampMs()
        local dt = now - job.lastFrameMs
        job.lastFrameMs = now
        if dt < 0 then dt = 0 elseif dt > 100 then dt = 100 end
        job.clockMs = job.clockMs + dt

        if safetyOn() then
            local stats = playerObj:getStats()
            if stats:getNumVisibleZombies() > 0 or stats:getNumChasingZombies() > 0
                or stats:getNumVeryCloseZombies() > 0 then
                playerObj:Say(tostring(getText("UI_BOYD_Annoyed")))
                debugLog("aww shit, theres zambies nearby!")
                ActionPlayer.clear(playerObj)
                return
            end
        end

        -- no running with a corpse yo
        if playerObj:isGrappling() and (isAltKeyDown() or isShiftKeyDown()) then
            debugLog("aww shit, you cant run while grappling")
            ActionPlayer.clear(playerObj)
            return
        end

        --highlightStaging(job)

        if playerObj:isDraggingCorpse() and notMoving(job) then
            debugLog("this mfer is stuck! stop this shit")
            job.wedged = true
            ISTimedActionQueue.clear(playerObj)
        end
    end
end

local function letGoNow(job, state, reason)
    debugLog(reason)
    state.letGo = true
    state.laydownStart = nil
    job.playerObj:setDoGrappleLetGo()
    return false
end

local function corpseStep(job, state)
    local playerObj = job.playerObj
    local dragging  = playerObj:isDraggingCorpse()
    local grappling = playerObj:isGrappling()
    local now = job.clockMs

    if state.phase == "pickup" then
        if dragging then
            if playerObj:isPerformingGrappleGrabAnimation() then
                state.settleStart = state.settleStart or now
                if now - state.settleStart < SETTLE_MS then return false end
            end
            state.holdStart = state.holdStart or now
            if now - state.holdStart < PICKUP_HOLD_MS then return false end
            state.phase = "dropoff"
            state.idleStart, state.dropWalks = nil, 0
            job.lastX, job.wedgeCheckAt, job.wedged = nil, nil, false
            debugLog("picked up, dragging somewhere")
            return false
        end
        if grappling then state.idleStart = nil; return false end
        state.idleStart = state.idleStart or now
        if now - state.idleStart > GRAB_GIVEUP_MS then debugLog("grab failed, fuck this shit"); return true end
        return false
    end

    -- dropoff
    if state.letGo then
        -- keep asking until it's actually down, then let the animation finish
        if dragging or grappling then
            playerObj:setDoGrappleLetGo()
            state.laydownStart = nil
            return false
        end
        state.laydownStart = state.laydownStart or now
        if now - state.laydownStart >= LAYDOWN_HOLD_MS then debugLog("stay there... next!"); return true end
        return false
    end

    -- drag broke mid-carry? forget that shit and move on
    if not dragging and not grappling then
        state.idleStart = state.idleStart or now
        if now - state.idleStart > LOST_GIVEUP_MS then debugLog("where corpse go? fuck, next!"); return true end
        return false
    end
    state.idleStart = nil

    if job.wedged then
        job.wedged = false
        return letGoNow(job, state, "this mfer is stuck, drop it here")
    end
    if onStagingSquare(job) then
        return letGoNow(job, state, "at staging square, letting go!")
    end
    if state.dropWalks >= MAX_DROPWALKS then
        return letGoNow(job, state, "cant get to the square, dropping here")
    end
    state.dropWalks = state.dropWalks + 1
    local stagingSquare = job.stagingSquare
    -- 42.20 added an allowedWhileDraggingCorpses to ISTimedActionQueue.add
    local walk = ISPathFindAction:pathToLocationF(playerObj,
        stagingSquare:getX() + 0.5, stagingSquare:getY() + 0.5, stagingSquare:getZ())
    walk.allowedWhileDraggingCorpses = true -- why yes, we can spam actions while dragging
    ISTimedActionQueue.add(walk)
    return false
end

local function queueCorpse(job, corpse)
    local state = { phase = "pickup", dropWalks = 0, letGo = false }
    return ActionPlayer.addToQueue(job.playerObj,
        function(_playerObj, _square, targetCorpse)
            ISWorldObjectContextMenu.onGrabCorpseItem(nil, targetCorpse, job.playerNum)
        end,
        { job.playerObj, corpse:getSquare(), corpse },
        { isDone = function() return corpseStep(job, state) end, worksInDark = true, noRest = true })
end

local function collectFromSquares(squares, skipSquare)
    local corpses = {}
    for _, square in ipairs(squares) do
        local alreadyThere = skipSquare and square:getZ() == skipSquare:getZ() and square:DistTo(skipSquare) < 1
        if not alreadyThere then
            local deadBodies = square:getDeadBodys()
            for bodyIndex = 0, deadBodies:size() - 1 do
                local deadBody = deadBodies:get(bodyIndex)
                if deadBody and not deadBody:isAnimal() then
                    table.insert(corpses, deadBody)
                end
            end
        end
    end
    return corpses
end

local function getBuildingSquares(playerObj)
    local buildingSquares = {}
    if not playerObj:getBuilding() then return buildingSquares end
    local seen = {}
    local function add(square)
        if not square then return end
        local key = SquareUtils.key(square)
        if not seen[key] then seen[key] = true; table.insert(buildingSquares, square) end
    end
    local rooms = playerObj:getCurrentBuildingDef():getRooms()
    for roomIndex = 0, rooms:size() - 1 do
        local room = rooms:get(roomIndex)
        if room then
            local roomSquares = room:getIsoRoom():getSquares()
            for squareIndex = 0, roomSquares:size() - 1 do add(roomSquares:get(squareIndex)) end
        end
    end
    if playerObj:getSquare():getChunk():getMinLevel() < 0 then
        local surfaceSquares = {}
        for _, square in ipairs(buildingSquares) do table.insert(surfaceSquares, square) end
        for _, square in ipairs(surfaceSquares) do
            local below = getSquare(square:getX(), square:getY(), square:getZ() - 1)
            if below and below:getRoom() then add(below) end
        end
    end
    return buildingSquares
end

local function startJob(playerObj, stagingSquare, corpses)
    if playerObj:isGrappling() then debugLog("you already dragging something son"); return end

    local playerNum = playerObj:getPlayerNum()
    ActionPlayer.clear(playerObj)

    local job = {
        playerObj = playerObj,
        playerNum = playerNum,
        stagingSquare = stagingSquare,
        wedged = false,
        clockMs = 0,
        lastFrameMs = getTimestampMs(),
    }
    jobs[playerNum] = job

    job.tick = makeAuxTick(job)
    Events.OnTick.Add(job.tick)
    ActionPlayer.onFinish(playerObj, function() finishJob(playerNum) end)

    local queued = 0
    for corpseIndex = #corpses, 1, -1 do
        if queueCorpse(job, corpses[corpseIndex]) then queued = queued + 1 end
    end
    if queued == 0 then finishJob(playerNum) end
end

function CorpseMover.stop(playerObj)
    if playerObj then ActionPlayer.clear(playerObj) end
end

function CorpseMover.beginOutdoor(playerObj, stagingSquare, squares)
    if not (playerObj and stagingSquare and squares) then return end
    if stagingSquare:getCampfire() then
        local campfire = CCampfireSystem.instance:getLuaObjectOnSquare(stagingSquare)
        if campfire and campfire.isLit then return end
    end
    local corpses = collectFromSquares(squares, nil)
    if #corpses == 0 then return end
    startJob(playerObj, stagingSquare, corpses)
end

function CorpseMover.beginIndoor(playerObj, stagingSquare)
    if not (playerObj and stagingSquare) then return end
    if not playerObj:getBuilding() then return end
    local corpses = collectFromSquares(getBuildingSquares(playerObj), stagingSquare)
    if #corpses == 0 then return end
    startJob(playerObj, stagingSquare, corpses)
end

return CorpseMover
