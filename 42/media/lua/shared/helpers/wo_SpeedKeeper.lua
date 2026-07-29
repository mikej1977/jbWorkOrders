WorkOrders = WorkOrders or {}

function WorkOrders.playerAbortedAuto(playerObj)
    return playerObj:pressedMovement(false) or playerObj:pressedCancelAction()
end

local ActionSpeedKeeper = {}
ActionSpeedKeeper.__index = ActionSpeedKeeper

function ActionSpeedKeeper:new(playerObj)
    local instance = {
        playerObj = playerObj,
        desiredSpeed = getGameSpeed(),
        stopConditions = {},
        speedToMultiplier = { 1, 5, 20, 40 },
        tickHandler = nil,
    }
    setmetatable(instance, self)
    return instance
end

function ActionSpeedKeeper:AddStopCondition(condition)
    if condition then
        table.insert(self.stopConditions, condition)
    end
end

function ActionSpeedKeeper:setSpeedAndMultiplier(speed)
    setGameSpeed(speed)
    getGameTime():setMultiplier(self.speedToMultiplier[speed] or 1)
end

function ActionSpeedKeeper:resetGameSpeed()
    self:setSpeedAndMultiplier(1)
    Events.OnTick.Remove(self.tickHandler)
end

function ActionSpeedKeeper:clickedSpeedControls()
    local speedControls = UIManager:getSpeedControls()
    return speedControls:isMouseOver() and Mouse:isLeftDown()
end

function ActionSpeedKeeper:KeepSpeed()
    self:AddStopCondition(function()
        return WorkOrders.playerAbortedAuto(self.playerObj)
    end)

    local function onTick()
        Events.OnTick.Remove(self.tickHandler)

        local currentSpeed = getGameSpeed()
        if currentSpeed > 1 then
            if self:clickedSpeedControls() or isKeyPressed("Normal Speed") then
                self.desiredSpeed = 1
                self:setSpeedAndMultiplier(1)
            else
                self.desiredSpeed = currentSpeed
            end
        end

        for i = 1, #self.stopConditions do
            if self.stopConditions[i](self.playerObj) then
                self:resetGameSpeed()
                return
            end
        end

        if currentSpeed ~= self.desiredSpeed then
            self:setSpeedAndMultiplier(self.desiredSpeed)
        end

        Events.OnTick.Add(self.tickHandler)
    end

    self.tickHandler = onTick
    Events.OnTick.Add(self.tickHandler)
end

return ActionSpeedKeeper
