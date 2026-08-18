local Options = {}

local MOD_ID = "WorkOrdersModOptions"

function Options.getOptions()
    return PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:getOptions(MOD_ID) or nil
end

---@param id string
function Options.getOption(id)
    local options = Options.getOptions()
    return options and options:getOption(id) or nil
end

---@param id string
---@param default any
function Options.get(id, default)
    local option = Options.getOption(id)
    if not option then return default end
    local value = option:getValue()
    if value == nil then return default end
    return value
end

---@param id string
---@param default boolean|nil
function Options.getBool(id, default)
    return Options.get(id, default) and true or false
end

---@param id string
---@param value any
function Options.set(id, value)
    local options = Options.getOptions()
    local option = options and options:getOption(id)
    if not option then return end
    option:setValue(value)
    if PZAPI.ModOptions.save then PZAPI.ModOptions:save() end
    if options.apply then options:apply() end
end

return Options
