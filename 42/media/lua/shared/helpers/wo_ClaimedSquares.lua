local SquareUtils = require("helpers/wo_SquareUtils")

local ClaimedSquares = {}

-- { [squareKey] = playerNum } so two players cant fight over the same tile (this is pure shitass jank that doesn't work)
local claims = {}

function ClaimedSquares.claim(square, playerNum)
    local key = SquareUtils.key(square)
    local existing = claims[key]
    if existing ~= nil and existing ~= playerNum then
        return false
    end
    claims[key] = playerNum
    return true
end

function ClaimedSquares.release(square)
    claims[SquareUtils.key(square)] = nil
end

function ClaimedSquares.releaseAll(playerNum)
    for key, owner in pairs(claims) do
        if owner == playerNum then
            claims[key] = nil
        end
    end
end

return ClaimedSquares
