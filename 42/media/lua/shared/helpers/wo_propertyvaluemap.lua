-- we should make some real container icons one day
require "Definitions/ContainerButtonIcons"

local STORAGE_CONTAINERS = {
    "LogsStorage", "PlanksStorage", "TwigsStorage", "FirewoodStorage", "StonesStorage",
}

do
    local icon = getTexture("media/ui/ContainerIcons/container_icon_LogStorage.png")
    for _, containerType in ipairs(STORAGE_CONTAINERS) do
        ContainerButtonIcons[containerType] = icon
    end
end

local function addValuesToPropertyMap(propertyName, values)
    local currentValues = IsoWorld.PropertyValueMap:get(propertyName) or ArrayList.new()
    for _, value in ipairs(values) do
        if not currentValues:contains(value) then
            currentValues:add(value)
        end
    end
    IsoWorld.PropertyValueMap:put(propertyName, currentValues)
end

Events.OnInitWorld.Add(function()
    addValuesToPropertyMap("container", STORAGE_CONTAINERS)
end)
