WorkOrders = WorkOrders or {}
WorkOrders.processingPlayers = WorkOrders.processingPlayers or {}

function WorkOrders.playerKey(playerObj)
    if isClient() or isServer() then
        return playerObj:getOnlineID()
    end
    return playerObj:getPlayerNum()
end

function WorkOrders.setProcessing(playerObj, on)
    WorkOrders.processingPlayers[WorkOrders.playerKey(playerObj)] = on or nil
    if isClient() then
        sendClientCommand(playerObj, "WorkOrders", on and "processStart" or "processEnd", {})
    end
end

if isServer() then
    Events.OnClientCommand.Add(function(module, command, playerObj, args)
        if module ~= "WorkOrders" then return end
        if command == "processStart" then
            WorkOrders.processingPlayers[WorkOrders.playerKey(playerObj)] = true
        elseif command == "processEnd" then
            WorkOrders.processingPlayers[WorkOrders.playerKey(playerObj)] = nil
        end
    end)
end
