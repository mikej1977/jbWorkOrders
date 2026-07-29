local SquareUtils = {}

--- x,y,z "string key" to use as a table index
---@param square IsoGridSquare
---@return string
function SquareUtils.key(square)
    return square:getX() .. "," .. square:getY() .. "," .. square:getZ()
end

local function distSq(ax, ay, az, bx, by, bz)
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return dx * dx + dy * dy + dz * dz
end

---@param fromX number
---@param fromY number
---@param fromZ number
---@param squares IsoGridSquare[]
---@return IsoGridSquare[]
function SquareUtils.orderByProximity(fromX, fromY, fromZ, squares)
    local remaining = {}
    for index, square in ipairs(squares) do remaining[index] = square end

    local ordered = {}
    local currentX, currentY, currentZ = fromX, fromY, fromZ
    while #remaining > 0 do
        local bestIndex, bestDist = 1, math.huge
        for index, square in ipairs(remaining) do
            local dist = distSq(currentX, currentY, currentZ, square:getX(), square:getY(), square:getZ())
            if dist < bestDist then bestDist, bestIndex = dist, index end
        end
        local picked = remaining[bestIndex]
        ordered[#ordered + 1] = picked
        currentX, currentY, currentZ = picked:getX(), picked:getY(), picked:getZ()
        table.remove(remaining, bestIndex)
    end
    return ordered
end

return SquareUtils
