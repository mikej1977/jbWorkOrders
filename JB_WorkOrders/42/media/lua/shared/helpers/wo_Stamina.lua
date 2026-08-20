local Options = require("helpers/wo_Options")

WorkOrders = WorkOrders or {}

local SIT_POKE_MS     = 1500 -- give the sit anim this long to take before we poke it again
local SIT_GIVEUP_MS   = 6000 -- cant get our ass on the ground at all? quit resting, back to work
local GETUP_GIVEUP_MS = 3000 -- forceGetUp got eaten somewhere, bail before the queue wedges

function WorkOrders.getEnduranceReduction()
    local pct
    if isClient() or isServer() then
        pct = SandboxVars.JBWorkOrders and SandboxVars.JBWorkOrders.WorkEnduranceReduction
    else
        pct = Options.get("Endurance_Reduction", 0)
    end
    pct = tonumber(pct) or 0
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
    return pct / 100
end

function WorkOrders.giveBackEndurance(playerObj, lastEndurance)
    -- in MP the server owns endurance, so the refund runs over there out of wo_StaminaSync.
    -- setting it here would just get synced away a second later
    if isClient() then return nil end
    local reduction = WorkOrders.getEnduranceReduction()
    if reduction <= 0 then return nil end
    local stats = playerObj:getStats()
    local current = stats:get(CharacterStat.ENDURANCE)
    if lastEndurance and current < lastEndurance then
        current = math.min(1, current + (lastEndurance - current) * reduction)
        stats:set(CharacterStat.ENDURANCE, current)
    end
    return current
end

function WorkOrders.getRestLevel()
    local level
    if isClient() or isServer() then
        level = SandboxVars.JBWorkOrders and SandboxVars.JBWorkOrders.RestAtEnduranceLevel
    else
        level = Options.get("Rest_Endurance_Level", 0)
    end
    level = tonumber(level) or 0
    if level < 0 then level = 0 elseif level > 4 then level = 4 end
    return level
end

---@param playerObj IsoPlayer
---@param state table|nil the queue or job table carrying the rest fields
---@return boolean
function WorkOrders.shouldStartRest(playerObj, state)
    -- a job that already proved it cant sit stays blocked, else we loop giveup -> retry forever
    if state and state.restBlocked then return false end
    local level = WorkOrders.getRestLevel()
    if level <= 0 then return false end
    local moodles = playerObj:getMoodles()
    if not moodles then return false end
    return moodles:getMoodleLevel(MoodleType.ENDURANCE) >= level
end

function WorkOrders.isEnduranceRestored(playerObj)
    return playerObj:getStats():get(CharacterStat.ENDURANCE) >= 0.95
end

function WorkOrders.getUpFromRest(playerObj)
    if playerObj:isSitOnGround() then
        playerObj:StopAllActionQueue()
        playerObj:setVariable("forceGetUp", true)
    end
end

---wipes every rest field and the halo so a half finished rest cant leak into the next job
---@param playerObj IsoPlayer
---@param state table the queue or job table carrying the rest fields
function WorkOrders.clearRest(playerObj, state)
    state.resting = nil
    state.restPhase = nil
    state.restNoSitMs = nil
    state.restPokeMs = nil
    state.restGetUpMs = nil
    state.restBlocked = nil
    playerObj:setHaloNote("", 0)
end

---@param playerObj IsoPlayer
---@param state table the queue or job table carrying the rest fields
---@param dt number ms since the last tick, already clamped by the caller
---@return boolean stillResting true means the caller bails out of this tick
function WorkOrders.updateRest(playerObj, state, dt)
    if not state.resting then return false end

    if state.restPhase == "gettingup" then
        if not playerObj:isSitOnGround() then
            WorkOrders.clearRest(playerObj, state)
            return false
        end
        state.restGetUpMs = (state.restGetUpMs or 0) + dt
        if state.restGetUpMs >= GETUP_GIVEUP_MS then
            -- one more shove, then stop holding the whole queue hostage over it
            WorkOrders.getUpFromRest(playerObj)
            WorkOrders.clearRest(playerObj, state)
            state.restBlocked = true
            return false
        end
        return true
    end

    -- endurance is back, or the player dragged the rest slider to 0 while we sat here
    if WorkOrders.isEnduranceRestored(playerObj) or WorkOrders.getRestLevel() <= 0 then
        if playerObj:isSitOnGround() then
            WorkOrders.getUpFromRest(playerObj)
            state.restPhase = "gettingup"
            state.restGetUpMs = 0
            return true
        end
        WorkOrders.clearRest(playerObj, state)
        return false
    end

    if playerObj:isSitOnGround() then
        state.restNoSitMs = 0
        state.restPokeMs = 0
    else
        -- zombie knocked us up, shitty tile, whatever. standing around regens endurance at a
        -- crawl, so poke the sit a few times and then admit defeat instead of faking a rest
        state.restNoSitMs = (state.restNoSitMs or 0) + dt
        if state.restNoSitMs >= SIT_GIVEUP_MS then
            WorkOrders.clearRest(playerObj, state)
            state.restBlocked = true
            return false
        end
        state.restPokeMs = (state.restPokeMs or 0) + dt
        if state.restPhase ~= "sitting" or state.restPokeMs >= SIT_POKE_MS then
            playerObj:setAutoWalk(false)
            playerObj:reportEvent("EventSitOnGround")
            state.restPhase = "sitting"
            state.restPokeMs = 0
        end
    end

    playerObj:setHaloNote(getText("UI_WorkOrders_Resting"), 120, 200, 120, 100)
    return true
end
