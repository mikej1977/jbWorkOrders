WorkOrders = WorkOrders or {}

-- MP packet wants Capability.CanModifyBodyStats and the default user role has jack shit
--
--   cuz I flow
--   client-> setWorking(playerObj, true)
--   server-> sweep tops them back up every SWEEP_MS out of WorkOrders.giveBackEndurance
--   client-> setWorking(playerObj, false)

local SWEEP_MS = 300 -- server runs like 10 ticks/sec? 

-- what did you fuck up now, Jim?
WOStaminaDebug = false
local function debugLog(message) if WOStaminaDebug then print("[WO] " .. message) end end

---@param playerObj IsoPlayer
---@param on boolean
function WorkOrders.setWorking(playerObj, on)
    if not isClient() then return end -- SP and the co-op don't need to do all this shit
    debugLog("client sending " .. (on and "workStart" or "workEnd"))
    sendClientCommand(playerObj, "WorkOrders", on and "workStart" or "workEnd", {})
end

if isServer() then
    local workingPlayers = {} -- [playerKey] = true while a work order is running
    local lastEndurance = {}
    local nextSweepMs = 0
    local tickerOn = false
    local sweepTicker

    local function stopSweep()
        if not tickerOn then return end
        Events.OnTick.Remove(sweepTicker)
        tickerOn = false
        debugLog("sweep off, nobody working")
    end

    local function startSweep()
        if tickerOn then return end
        Events.OnTick.Add(sweepTicker)
        tickerOn = true
        debugLog("sweep on")
    end

    local function onlineByKey()
        local online = {}
        local players = getOnlinePlayers()
        if not players then return online end
        for playerIndex = 0, players:size() - 1 do
            local playerObj = players:get(playerIndex)
            online[WorkOrders.playerKey(playerObj)] = playerObj
        end
        return online
    end

    sweepTicker = function()
        local now = getTimestampMs()
        if now < nextSweepMs then return end
        nextSweepMs = now + SWEEP_MS

        local online = onlineByKey()
        local anyWorking = false

        for playerKey in pairs(workingPlayers) do
            local playerObj = online[playerKey]
            if playerObj then
                local previous = lastEndurance[playerKey]
                local drained = playerObj:getStats():get(CharacterStat.ENDURANCE)
                local current = WorkOrders.giveBackEndurance(playerObj, previous)
                lastEndurance[playerKey] = current
                debugLog(string.format("refund %s: last=%s drained=%.4f now=%.4f back=%+.4f",
                    tostring(playerKey),
                    previous and string.format("%.4f", previous) or "nil",
                    drained, current or drained, (current or drained) - drained))
                anyWorking = true
            else
                -- quit mid job? quit tracking those assholes
                workingPlayers[playerKey] = nil
                lastEndurance[playerKey] = nil
            end
        end

        -- nobody left to give endurance so gtfo
        if not anyWorking then stopSweep() end
    end

    Events.OnClientCommand.Add(function(module, command, playerObj, _args)
        if module ~= "WorkOrders" then return end
        local playerKey = WorkOrders.playerKey(playerObj)
        if command == "workStart" then
            local reduction = WorkOrders.getEnduranceReduction()
            debugLog(string.format("workStart from %s, WorkEnduranceReduction gives reduction %.2f",
                tostring(playerKey), reduction))
            -- server gives nothing back, dont bother tracking it
            if reduction <= 0 then
                debugLog("reduction is 0, not tracking anybody. check the servers sandbox vars")
                return
            end
            workingPlayers[playerKey] = true
            lastEndurance[playerKey] = nil
            startSweep()
        elseif command == "workEnd" then
            debugLog("workEnd from " .. tostring(playerKey))
            workingPlayers[playerKey] = nil
            lastEndurance[playerKey] = nil
        end
    end)
end
