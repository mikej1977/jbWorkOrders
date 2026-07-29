local RegisterOptions  = require("helpers/wo_RegisterMenuOptions")
local ContainerRegistry = require("registries/wo_ContainerRegistry")
local Predicates       = require("helpers/wo_Predicates")
local ClearingLogic    = require("logic/wo_ClearingLogic")
local GatheringLogic   = require("logic/wo_GatheringLogic")
local ProcessingLogic  = require("logic/wo_ProcessingLogic")
local StorageLogic     = require("logic/wo_StorageLogic")
local SelectUtils      = require("wo_SelectUtils")

local MenuModel = {}

local Options = require("helpers/wo_Options")

local function repeatOrdersEnabled()
    return Options.getBool("Repeat_Orders", false)
end

local function resolveLogic(logicName)
    if type(ClearingLogic) == "table" and ClearingLogic[logicName] then return ClearingLogic[logicName] end
    if type(GatheringLogic) == "table" and GatheringLogic[logicName] then return GatheringLogic[logicName] end
    if type(ProcessingLogic) == "table" and ProcessingLogic[logicName] then return ProcessingLogic[logicName] end
    if WorkOrders then
        if type(WorkOrders[logicName]) == "function" then return WorkOrders[logicName] end
        if type(WorkOrders["WO_" .. logicName]) == "function" then return WorkOrders["WO_" .. logicName] end
    end
    return nil
end

function MenuModel.executeAction(worldObjects, optionAction, playerObj, clickedFlags, pickValidator)
    if type(optionAction) ~= "table" then return end
    local utilityName = optionAction[1]
    local utilityFunc = SelectUtils[utilityName]
    local logicFunc   = resolveLogic(optionAction[2])
    if not (utilityFunc and logicFunc) then
        print("ERROR: WorkOrders - could not resolve action: " .. tostring(optionAction[2]))
        return
    end
    local params = {}
    for argIndex = 3, #optionAction do
        local paramValue = optionAction[argIndex]
        if type(paramValue) == "string" and clickedFlags[paramValue] ~= nil then
            table.insert(params, clickedFlags[paramValue])
        else
            table.insert(params, paramValue)
        end
    end

    -- cancel selection opens the menu back up
    local function reopenMenu()
        if WorkOrders.OpenWindow then WorkOrders.OpenWindow() end
    end

    -- "repeat mode" keep the selection shit after each drag so the player can keep
    -- selecting if they want to, right click cancels
    --
    -- SelectSquareAndArea skips this since it will never need it
    if utilityName == "SelectSquareAndArea" then
        local stagingSquare
        local function repeatAreaLoop()
            SelectUtils.nextOnCancel = reopenMenu
            SelectUtils.SelectArea(worldObjects, playerObj, function(pl, worldObjs, area, ...)
                logicFunc(pl, worldObjs, stagingSquare, area, ...)
                if repeatOrdersEnabled() then repeatAreaLoop() end
            end, unpack(params))
        end
        SelectUtils.nextPickValidator = pickValidator
        SelectUtils.nextOnCancel = reopenMenu
        SelectUtils.SelectSquareAndArea(worldObjects, playerObj, function(pl, worldObjs, square, area, ...)
            stagingSquare = square
            logicFunc(pl, worldObjs, square, area, ...)
            if repeatOrdersEnabled() then repeatAreaLoop() end
        end, unpack(params))
        return
    end

    local function armed(...)
        logicFunc(...)
        if repeatOrdersEnabled() then
            SelectUtils.nextPickValidator = pickValidator
            SelectUtils.nextOnCancel = reopenMenu
            utilityFunc(worldObjects, playerObj, armed, unpack(params))
        end
    end
    SelectUtils.nextPickValidator = pickValidator
    SelectUtils.nextOnCancel = reopenMenu
    utilityFunc(worldObjects, playerObj, armed, unpack(params))
end

local function resolveRecipe(resultFullName, item, player)
    if not instanceof(item, "InventoryItem") then return nil end
    local containers = ISInventoryPaneContextMenu.getContainers(player)
    if not containers then return nil end
    local recipes = CraftRecipeManager.getUniqueRecipeItems(item, player, containers)
    if not recipes or recipes:isEmpty() then return nil end
    for recipeIndex = 0, recipes:size() - 1 do
        local recipe = recipes:get(recipeIndex)
        local outputs = recipe:getOutputs()
        for outputIndex = 0, outputs:size() - 1 do
            local mapper = outputs:get(outputIndex):getOutputMapper()
            local resultItems = mapper and mapper:getResultItems()
            if resultItems then
                for resultIndex = 0, resultItems:size() - 1 do
                    if resultItems:get(resultIndex):getFullName() == resultFullName then
                        return recipe
                    end
                end
            end
        end
    end
    return nil
end

function MenuModel.computeWindowFlags(playerObj)
    local flags = {}
    local inventory = playerObj:getInventory()
    flags.toolChopTree = inventory:containsEvalRecurse(Predicates.ChopTree)
    flags.toolWoodSaw = inventory:containsEvalRecurse(Predicates.WoodSaw)
    flags.toolCutPlant = inventory:containsEvalRecurse(Predicates.CutPlant)
    flags.toolDigStump = inventory:containsEvalRecurse(Predicates.DigStump)
    flags.toolBreakBoulder = inventory:containsEvalRecurse(Predicates.Digging)

    local log = instanceItem("Base.Log")
    flags.recipeSawPlanks    = resolveRecipe("Base.Plank", log, playerObj) or false
    flags.recipeChopFirewood = resolveRecipe("Base.Firewood", log, playerObj) or false
    return flags
end

function MenuModel.buildOrders(playerObj, flags)
    flags = flags or {}
    local playerInv = playerObj:getInventory()

    local evalFlags = setmetatable({}, { __index = function(_, key)
        local value = flags[key]
        if value ~= nil then return value end
        return true
    end })

    local function makeHeader(id, entry)
        local iconPath = (entry and entry.icon) or "media/ui/Radial/Logging.png"
        return {
            id = id,
            label = getText(entry and entry.translate or id),
            icon = iconPath and getTexture(iconPath) or nil,
        }
    end

    local domains, domainOrder = {}, {}
    local function category(domId, catId)
        local domainEntry = domains[domId]
        if not domainEntry then
            domainEntry = makeHeader(domId, RegisterOptions.DomainById[domId]); domainEntry.cats = {}; domainEntry.catIndex = {}
            domains[domId] = domainEntry; table.insert(domainOrder, domainEntry)
        end
        local categoryEntry = domainEntry.catIndex[catId]
        if not categoryEntry then
            categoryEntry = makeHeader(catId, RegisterOptions.CategoryById[catId]); categoryEntry.items = {}
            domainEntry.catIndex[catId] = categoryEntry; table.insert(domainEntry.cats, categoryEntry)
        end
        return categoryEntry
    end

    -- turn an "option" table into a menu item!
    local function emit(option)
        local categoryEntry = category(option.domain or "Logging", option.category or "General")
        local runFn
        if type(option.run) == "function" then
            runFn = option.run
        elseif option.action then
            local action = option.action
            local pickValidator = option.pickValidator -- green/red pick feedback
            runFn = function(playerObj, clickedFlags) MenuModel.executeAction(nil, action, playerObj, clickedFlags, pickValidator) end
        else
            runFn = function() end
        end
        local condition = option.condition
        table.insert(categoryEntry.items, {
            label = option.label or (option.translate and getText(option.translate)) or "",
            icon = option.icon and getTexture(option.icon) or nil,
            tooltipKey = option.tooltip,
            reqTagKey = option.reqTag,
            enabled = (condition == nil) or (condition(playerInv, evalFlags) and true or false),
            run = runFn,
        })
    end

    for _, option in ipairs(RegisterOptions.OptionsList) do
        emit(option)
    end

    for _, provider in ipairs(RegisterOptions.Providers) do
        local produced = provider(playerObj, evalFlags)
        if type(produced) == "table" then
            for _, option in ipairs(produced) do
                emit(option)
            end
        end
    end

    for typeKey, data in pairs(ContainerRegistry.Types) do
        local categoryEntry = category(data.domain or "Logging", "Storage")
        table.insert(categoryEntry.items, {
            label = getText(data.translate or typeKey),
            icon = data.icon and getTexture(data.icon) or nil,
            enabled = true,
            run = function(playerObj) StorageLogic.Create(playerObj, typeKey) end,
        })
    end
    do
        local categoryEntry = category("Logging", "Storage")
        table.insert(categoryEntry.items, {
            label = getText("UI_WorkOrders_Menu_RemoveStorage"),
            icon = getTexture("media/ui/Radial/S_Remove.png"),
            enabled = true,
            run = function(playerObj) StorageLogic.Remove(playerObj) end,
        })
    end

    local function sorter(registryList)
        local rank = {}
        for rankIndex, entry in ipairs(registryList) do rank[entry.id] = rankIndex end
        return function(first, second)
            local firstRank, secondRank = rank[first.id] or math.huge, rank[second.id] or math.huge
            if firstRank ~= secondRank then return firstRank < secondRank end
            return first.label < second.label
        end
    end
    table.sort(domainOrder, sorter(RegisterOptions.Domains))
    for _, domainEntry in ipairs(domainOrder) do table.sort(domainEntry.cats, sorter(RegisterOptions.Categories)) end
    return domainOrder
end

return MenuModel
