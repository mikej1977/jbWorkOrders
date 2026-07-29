-- here's your fuckin menu
-- domains are window tabs, categories are sections in a tab
-- options are the buttons and everything "registers" into this one very simple table on load
local RegisterOptions = {}

RegisterOptions.OptionsList = {}
RegisterOptions.Providers   = {}
RegisterOptions.Domains     = {}
RegisterOptions.Categories  = {}
RegisterOptions.DomainById   = {}
RegisterOptions.CategoryById = {}

-- register or update? registering the same id twice just refreshes it
local function upsert(list, byId, entityLabel, id, translationKey, iconPath)
    if type(id) ~= "string" or type(translationKey) ~= "string" then
        print("ERROR: RegisterOptions.register" .. entityLabel ..
            " - 'id' and 'translationKey' must both be strings.")
        return nil
    end
    local entry = byId[id]
    if entry then
        entry.translate = translationKey
        if type(iconPath) == "string" then entry.icon = iconPath end
        return entry
    end
    entry = { id = id, translate = translationKey, icon = type(iconPath) == "string" and iconPath or nil }
    byId[id] = entry
    list[#list + 1] = entry
    return entry
end

function RegisterOptions.registerDomain(id, translationKey, iconPath)
    return upsert(RegisterOptions.Domains, RegisterOptions.DomainById, "Domain", id, translationKey, iconPath)
end

function RegisterOptions.registerCategory(id, translationKey, iconPath)
    return upsert(RegisterOptions.Categories, RegisterOptions.CategoryById, "Category", id, translationKey, iconPath)
end

function RegisterOptions.registerMenuOption(option)
    if type(option) ~= "table" then
        print("ERROR: RegisterOptions.registerMenuOption - 'option' must be a table.")
        return false
    end

    local requiredFields = {
        category  = "string",
        translate = "string",
        condition = "function",
    }
    for field, expectedType in pairs(requiredFields) do
        if type(option[field]) ~= expectedType then
            print(string.format(
                "ERROR: RegisterOptions.registerMenuOption - Missing or invalid field '%s' (expected %s, got %s)",
                field, expectedType, type(option[field])))
            return false
        end
    end

    for _, optionalField in ipairs({ "tooltip", "icon", "reqTag" }) do
        if option[optionalField] ~= nil and type(option[optionalField]) ~= "string" then
            print("ERROR: RegisterOptions.registerMenuOption - '" .. optionalField .. "' must be a string.")
            return false
        end
    end

    if option.pickValidator ~= nil and type(option.pickValidator) ~= "function" then
        print("ERROR: RegisterOptions.registerMenuOption - 'pickValidator' must be a function.")
        return false
    end

    local actionType = type(option.action)
    if actionType ~= "function" and actionType ~= "table" then
        print("ERROR: RegisterOptions.registerMenuOption - 'action' must be a function or a table.")
        return false
    end
    if actionType == "table" then
        local first = type(option.action[1])
        if first ~= "function" and first ~= "string" then
            print("ERROR: RegisterOptions.registerMenuOption - action table must start with a function or a string name.")
            return false
        end
    end

    if not RegisterOptions.CategoryById[option.category] then
        print("WARNING: RegisterOptions.registerMenuOption - category '" ..
            tostring(option.category) .. "' is not registered (registerCategory). Render with fallback styling.")
    end
    if option.domain and not RegisterOptions.DomainById[option.domain] then
        print("WARNING: RegisterOptions.registerMenuOption - domain '" ..
            tostring(option.domain) .. "' is not registered (registerDomain). Render with fallback styling.")
    end

    RegisterOptions.OptionsList[#RegisterOptions.OptionsList + 1] = option
    return true
end

function RegisterOptions.registerProvider(providerFunc)
    if type(providerFunc) ~= "function" then
        print("ERROR: RegisterOptions.registerProvider - 'providerFunc' must be a function.")
        return false
    end
    RegisterOptions.Providers[#RegisterOptions.Providers + 1] = providerFunc
    return true
end

return RegisterOptions
