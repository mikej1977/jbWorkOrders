local Options = require("helpers/wo_Options")

WorkOrders = WorkOrders or {}

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

function WorkOrders.shouldStartRest(playerObj)
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

function WorkOrders.updateRest(playerObj, state)
    if not state.resting then return false end

    if state.restPhase == "gettingup" then
        if not playerObj:isSitOnGround() then
            state.resting = false
            state.restPhase = nil
            return false
        end
        return true
    end

    if WorkOrders.isEnduranceRestored(playerObj) then
        if playerObj:isSitOnGround() then
            WorkOrders.getUpFromRest(playerObj)
            state.restPhase = "gettingup"
            return true
        end
        state.resting = false
        state.restPhase = nil
        return false
    end

    if state.restPhase ~= "sitting" then
        playerObj:setAutoWalk(false)
        playerObj:reportEvent("EventSitOnGround")
        state.restPhase = "sitting"
    end
    playerObj:setHaloNote(getText("UI_WorkOrders_Resting"), 120, 200, 120, 100)
    return true
end
