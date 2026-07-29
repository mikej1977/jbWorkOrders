local ActionSpeedKeeper = require("helpers/wo_SpeedKeeper")
local ClaimedSquares = require("helpers/wo_ClaimedSquares")
local SquareUtils = require("helpers/wo_SquareUtils")

local ActionPlayer = {}
local queues = {}

local overlayByPlayer = {} -- keyed {x,y,z} coords

-- so args[2] is usually the work square, but sometimes it's a world object(because I'm lazy)
-- get the square before it goes bye bye
local function resolveOverlaySquare(target)
    if not target then return nil end
    if instanceof(target, "IsoGridSquare") then return target end
    if instanceof(target, "IsoObject") then return target:getSquare() end
    return nil
end

local function overlayAdd(playerNum, target)
    local square = resolveOverlaySquare(target)
    if not square then return nil end
    local key = SquareUtils.key(square)
    overlayByPlayer[playerNum] = overlayByPlayer[playerNum] or {}
    overlayByPlayer[playerNum][key] = { x = square:getX(), y = square:getY(), z = square:getZ() }
    return key
end

local function overlayRemoveKey(playerNum, key)
    local squares = overlayByPlayer[playerNum]
    if squares and key then squares[key] = nil end
end

--- for the renderer only { [playerNum] = { [key] = {x,y,z} } }
function ActionPlayer.getPendingSquares()
    return overlayByPlayer
end

local function ensureQueue(playerNum)
    if not queues[playerNum] then
        queues[playerNum] = {
            tasks = {},
            isActive = false,
            speedKeeper = nil,
            ticker = nil,
            activeTask = nil,
            activeTicks = 0,
            onFinish = nil
        }
    end
    return queues[playerNum]
end

function ActionPlayer.onFinish(playerObj, func)
    ensureQueue(playerObj:getPlayerNum()).onFinish = func
end

function ActionPlayer.addToQueue(playerObj, func, taskArgs, options)
    local playerNum = playerObj:getPlayerNum()

    local targetSquare = taskArgs and taskArgs[2]
    if targetSquare and instanceof(targetSquare, "IsoGridSquare") then
        if not ClaimedSquares.claim(targetSquare, playerNum) then
            return false
        end
    end

    ensureQueue(playerNum)

    table.insert(queues[playerNum].tasks, {
        func = func,
        args = taskArgs,
        square = targetSquare,
        overlayKey = overlayAdd(playerNum, targetSquare),
        isDone = options and options.isDone or nil,
        timeout = options and options.timeout or 600,
    })

    if not queues[playerNum].isActive then
        ActionPlayer.start(playerObj)
    end

    return true
end

function ActionPlayer.start(playerObj)
    local playerNum = playerObj:getPlayerNum()
    local queue = queues[playerNum]

    if not queue then return end

    queue.isActive = true

    if not queue.speedKeeper then
        queue.speedKeeper = ActionSpeedKeeper:new(playerObj)
        queue.speedKeeper:KeepSpeed()
    end

    queue.ticker = function()
        if WorkOrders.playerAbortedAuto(playerObj) then
            ActionPlayer.clear(playerObj)
            return
        end

        local active = queue.activeTask
        if active then
            if ISTimedActionQueue.isPlayerDoingAction(playerObj) then
                queue.activeTicks = 0
                return
            end
            if not active.isDone(playerObj) then
                queue.activeTicks = queue.activeTicks + 1
                if queue.activeTicks < active.timeout then return end
            end
            queue.activeTask = nil
            queue.activeTicks = 0
            if active.square then ClaimedSquares.release(active.square) end
            overlayRemoveKey(playerNum, active.overlayKey)
        end

        if ISTimedActionQueue.isPlayerDoingAction(playerObj) then
            return
        end

        if queue.runningOverlayKey then
            overlayRemoveKey(playerNum, queue.runningOverlayKey)
            queue.runningOverlayKey = nil
        end

        if #queue.tasks == 0 then
            ActionPlayer.clear(playerObj)
            return
        end

        local task = table.remove(queue.tasks, 1)

        if task.square and not task.isDone then
            ClaimedSquares.release(task.square)
        end

        if task and task.func then
            task.func(unpack(task.args))
        end

        if task.isDone then
            queue.activeTask = task
            queue.activeTicks = 0
        else
            queue.runningOverlayKey = task.overlayKey
        end
    end

    Events.OnTick.Add(queue.ticker)
end

function ActionPlayer.clear(playerObj)
    local playerNum = playerObj:getPlayerNum()
    local queue = queues[playerNum]

    if queue then
        ClaimedSquares.releaseAll(playerNum)
        overlayByPlayer[playerNum] = nil
        queue.runningOverlayKey = nil

        local finish = queue.onFinish
        queue.onFinish = nil
        queue.isActive = false
        queue.tasks = {}
        queue.activeTask = nil
        queue.activeTicks = 0
        if queue.speedKeeper then
            queue.speedKeeper:resetGameSpeed()
            queue.speedKeeper = nil
        end
        if queue.ticker then
            Events.OnTick.Remove(queue.ticker)
            queue.ticker = nil
        end

        if finish then finish(playerObj) end
    end
end

return ActionPlayer
