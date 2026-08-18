-- The add-on surface for Work Orders
local ProcessingLogic   = require("logic/wo_ProcessingLogic")
local ClearingLogic     = require("logic/wo_ClearingLogic")
local ItemList          = require("registries/wo_ItemList")
local ContainerRegistry = require("registries/wo_ContainerRegistry")
local RegisterOptions   = require("helpers/wo_RegisterMenuOptions")
local Predicates        = require("helpers/wo_Predicates")
local ActionPlayer      = require("helpers/wo_ActionPlayer")

-- look in client/addons folder for examples

---@class WorkOrders
WorkOrders = WorkOrders or {}
---@class WorkOrders.API
WorkOrders.API = WorkOrders.API or {}

local API = WorkOrders.API

--- The shared work "runner"
--- Use this to run the player through a job instead of hand-rolling an OnTick loop(don't be like Jim)
--- it owns the per-player task queue, the game-speed keeper, square claiming, and the "player took over" bail
---   ActionPlayer.addToQueue(playerObj, func, args, opts)
---   ActionPlayer.onFinish(playerObj, func)   -- cleanup on finish OR cancel
---   ActionPlayer.clear(playerObj)            -- stop everything
--- opts.isDone(playerObj) lets a task span work that isn't a timed action (grapples,
--- animations); without it a task ends when the timed-action queue empties
API.ActionPlayer = ActionPlayer

--- convert the  string or array into a dictionary of [itemFullType] = true
---@param input string|string[]|table<string,boolean>
---@return table<string, boolean>
local function normalizeTable(input)
    local output = {}
    if type(input) == "string" then
        output[input] = true
    elseif type(input) == "table" then
        for key, value in pairs(input) do
            if type(key) == "number" and type(value) == "string" then
                output[value] = true
            elseif type(key) == "string" then
                output[key] = true
            end
        end
    end
    return output
end

local function mergeInto(target, itemData)
    for item in pairs(normalizeTable(itemData)) do
        target[item] = true
    end
end

--- make sure registry[category] exists and return it
local function categoryOf(registry, category)
    registry[category] = registry[category] or {}
    return registry[category]
end

--- registers a function to the global WorkOrders table with a "WO_" prefix
--- refuse name collisions
---@param functionName string the name of the function
---@param func function the logic funciton to execute
---@return boolean return true if good to go, false if you fucked up
local function registerGlobalLogic(functionName, func)
    local finalName = "WO_" .. functionName
    if WorkOrders[finalName] then
        print("WorkOrders API ERROR: Logic name '" .. finalName .. "' already exists. Registration aborted.")
        return false
    end
    WorkOrders[finalName] = func
    return true
end

--- working with my legacy code has been a nightmare btw
local function resolveArea(maybeSquare, maybeArea)
    if maybeArea and maybeArea.squares then return maybeArea end
    if maybeSquare and maybeSquare.squares then return maybeSquare end
    return nil
end

--- add an item or a table of items to a gathering category
---@param category string the name of where you'll keep your list of itemData
---@param itemData string|string[]|table<string,boolean> the items to gather
function API.addItemToGather(category, itemData)
    mergeInto(categoryOf(ItemList.GatherItemList, category), itemData)
end

--- add item/items to a processing category
---@param category string the name of where you'll keep your list of itemData
---@param itemData string|string[]|table<string,boolean> the items to process
function API.addItemToProcess(category, itemData)
    mergeInto(categoryOf(ItemList.ProcessList, category), itemData)
end

--- register items to be dumped on the floor during processing
---@param itemData string|string[]|table<string,boolean> the items to drop
function API.addDropItem(itemData)
    mergeInto(ItemList.DropItems, itemData)
end

--- map a tile object name to a specific item yield
---@param customName string the 'CustomName' property of the tile object
---@param yieldFullType string the full type of the item the player gets back
function API.addItemPickup(customName, yieldFullType)
    ItemList.PickupItems[customName] = yieldFullType
end

--- configure sprite ranges and stats for boulders
---@param config {min:number,max:number,tool:boolean,time:number,stones:number} the boulder config table
function API.addBoulderConfig(config)
    if type(config) == "table" then
        table.insert(ItemList.BoulderConfig, config)
    else
        print("WorkOrders API: addBoulderConfig expects a table.")
    end
end

--- tie a custom storage object to its category and sprites
---@param typeKey string the ID used in ModData for the object
---@param containerData table the table containing name, itemType, and sprites
function API.addContainer(typeKey, containerData)
    if type(containerData.itemType) == "string" then
        if ItemList.GatherItemList[containerData.itemType] then
            containerData.itemType = ItemList.GatherItemList[containerData.itemType]
        else
            print("WorkOrders API Warning: itemType category '" .. containerData.itemType .. "' not found.")
        end
    end
    ContainerRegistry.Types[typeKey] = containerData
end

--- create custom logic gate for items
---@param id string the name you'll call to use the check
---@param predicateFunc function a function returning a bool when checked against an item
function API.addPredicate(id, predicateFunc)
    if type(predicateFunc) == "function" then Predicates[id] = predicateFunc end
end

--- keep this stub so old add-ons fail with a yell
function API.addScanner(category, id)
    print("WorkOrders API: addScanner('" .. tostring(category) .. "', '" .. tostring(id) ..
        "') is no more -- do availability checks inside your menu option's condition(playerInv, flags).")
end

--- register a top level domain tab
---@param id string the id used as `domain` for your options
---@param translationKey string the tab name
---@param iconPath string|nil the tab icon
function API.addDomain(id, translationKey, iconPath)
    RegisterOptions.registerDomain(id, translationKey, iconPath)
end

--- register a category
---@param id string the id used as `category` on your options
---@param translationKey string the section name
---@param iconPath string|nil the section icon
function API.addCategory(id, translationKey, iconPath)
    RegisterOptions.registerCategory(id, translationKey, iconPath)
end

--- define a menu button and its behavior. defaults to Logging
--- can have optional "pickValidator = function(square) -> bool"
---@param optionTable {domain:string,category:string,condition:function,translate:string,tooltip:string,icon:string,reqTag:string,action: string[],pickValidator:function}
function API.addMenuOption(optionTable)
    RegisterOptions.registerMenuOption(optionTable)
end

--- register a menu provider for buttons that depend on a live state
--- called as "provider(playerObj, flags)" every time the window rebuilds
--- return an array of option tables (or nil for no bueno)
---@param providerFunc fun(playerObj:IsoPlayer, flags:table):table[]
function API.addMenuProvider(providerFunc)
    if type(providerFunc) ~= "function" then
        print("WorkOrders API: addMenuProvider expects a function.")
        return false
    end
    return RegisterOptions.registerProvider(providerFunc)
end

--- register a custom logic function, referenced by name in a menu option's 'action'
--- your function will get (playerObj, worldObjects, ...selectionResults),
--- where the results depend on the SelectUtils function named first in 'action'
---   "SelectSingleSquare"  = (playerObj, worldObjects, square)
---   "SelectArea"          = (playerObj, worldObjects, area)
---   "SelectSquareAndArea" = (playerObj, worldObjects, square, area)
--- use this when your shit is neither gather, process or clear
---@param functionName string name referenced as action[2]
---@param func function the logic to run
---@return boolean true if registered, false on name collision or bad input
function API.addLogic(functionName, func)
    if type(func) ~= "function" then
        print("WorkOrders API: addLogic('" .. tostring(functionName) .. "') expects a function.")
        return false
    end
    return registerGlobalLogic(functionName, func)
end

--- Add logic for the item/s to gather
---@param functionName string the string name for your function
---@param itemData string|string[]|table<string,boolean> the items to gather
---@param storageType string|nil the ModData ID of a custom storage object
function API.addGatherLogic(functionName, itemData, storageType)
    local itemsTable = normalizeTable(itemData)
    registerGlobalLogic(functionName, function(playerObj, worldObjects, selectedSquare, selectedArea)
        -- gathering always needs a staging square + an area
        if not selectedSquare or not selectedArea then return end
        WO_GatherItemsAction:new(playerObj, selectedSquare, selectedArea, itemsTable, storageType)
    end)
end

--- add logic for items to process
---@param functionName string the string name for your function
---@param recipe string the crafting recipe to run for the process
---@param processCategory string the list category of items used as recipe inputs
function API.addProcessLogic(functionName, recipe, processCategory)
    registerGlobalLogic(functionName, function(playerObj, worldObjects, maybeSquare, maybeArea)
        local area = resolveArea(maybeSquare, maybeArea)
        if not area then return end
        ProcessingLogic.unifiedProcess(playerObj, worldObjects, area, recipe, processCategory)
    end)
end

--- add new clearing options
---@param typeName string the unique ID for the clear type
---@param isValidFunc function checks if an object on a square is valid to clear
---@param actionFunc function the action to queue up for the player
function API.registerClearingSystem(typeName, isValidFunc, actionFunc)
    ClearingLogic.ClearRegistry[typeName] = {
        isValid = isValidFunc,
        action = actionFunc
    }

    registerGlobalLogic(typeName, function(playerObj, worldObjects, maybeSquare, maybeArea)
        local area = resolveArea(maybeSquare, maybeArea)
        if not area then return end
        ClearingLogic.unifiedClear(playerObj, worldObjects, area, typeName)
    end)
end
