# JB Work Orders — Code Style Guide

How this mod is written. Match it. Derived from the mind of Jim, not
generic Lua advice.

---

## 0. Hard rules

These are not preferences. Breaking one is an automatic push denial.
See the bottom of this MD for a checklist.

### `pcall` is banned

No fucking `pcall`, no "just in case" error swallowing. There are currently **zero**
in the codebase and it stays that way.

Why:

- It hides the stack trace. "It kinda works now" is worse than a crash. A crash gets reported and fixed.

What to do instead — all three already used everywhere in this codebase:

```lua
-- 1. guard the precondition, bail early
function WO_ClearBoulderAction:complete()
    local square = self.boulderObj:getSquare()
    if not square then return true end
    ...
```

```lua
-- 2. validate at the registration boundary, print the error, return false
function API.addLogic(functionName, func)
    if type(func) ~= "function" then
        print("WorkOrders API: addLogic('" .. tostring(functionName) .. "') expects a function.")
        return false
    end
    return registerGlobalLogic(functionName, func)
end
```

```lua
-- 3. if it's a bug, let it blow up. Don't catch what you can't handle.
```

Validation belongs at load time (registration), not in the hot path. Guards belong at the
top of the function, not wrapped around it.

### Other automatic denials

- Overwriting a vanilla file instead of monkeypatching through a saved local.
- Raw player-facing strings in UI. Everything goes through `getText()`.
- An `Events.OnTick.Add` with no matching `Remove` path.
- Hand-rolling a new OnTick work loop instead of using `ActionPlayer`.
- Silently overwriting an already-registered name.

---

## 1. Layout and naming

### Files

```
media/lua/
  client/            wo_FrontDoor, wo_WorkOrdersWindow, wo_MenuModel, wo_SelectUtils, ...
  client/addons/     BOYD_*, Farm_*    -- API consumers, also the worked examples
  server/cursors/    wo_StorageBuildCursor, wo_StorageRemoveCursor
  shared/helpers/    wo_ActionPlayer, wo_SquareUtils, wo_Options, ...
  shared/logic/      wo_ClearingLogic, wo_GatheringLogic, wo_ProcessingLogic, wo_StorageLogic
  shared/registries/ wo_ItemList, wo_MenuRegistry, wo_CategoryRegistry, wo_ContainerRegistry
  shared/TimedActions/  wo_*Action     -- capitalized to match the vanilla require path
  shared/wo_API.lua                    -- the add-on surface
```

- Core files: `wo_` prefix, PascalCase name after it (`wo_SquareUtils.lua`).
  `wo_propertyvaluemap.lua` is a legacy outlier; don't copy it.
- Add-ons get their own prefix and their own folder: `BOYD_`, `Farm_`.
- `require` uses the path from the lua root, forward slashes, no extension:
  `require("helpers/wo_SquareUtils")`, `require("registries/wo_ItemList")`.
- Vanilla base classes use the vanilla quote-no-parens form:
  `require "TimedActions/ISBaseTimedAction"`.

### Identifiers

Whole words. No abbreviations, no single letters — including loop counters.

```lua
for objectIndex = 0, square:getObjects():size() - 1 do
    local worldObject = square:getObjects():get(objectIndex)
```

`objectIndex`, `itemIndex`, `containerIndex`, `lineIndex`, `dropIndex`, `bandIndex`.
Not `i`. `_` for genuinely unused, including params: `_worldObjs`.

| Kind | Case | Examples |
|---|---|---|
| local / field | lowerCamelCase | `playerObj`, `stagingSquare`, `squareObjects`, `bestIndex` |
| file constant | SCREAMING_SNAKE at top of file | `HUD_SIZE`, `DRAG_THRESHOLD`, `ACTION_DELAY_MS`, `BATCH_LIMIT` |
| module table | PascalCase | `SquareUtils`, `ClearingLogic`, `ContainerRegistry` |
| local helper fn | lowerCamelCase | `normalizeTable`, `resolveArea`, `getBoulderData`, `screenPt` |
| private window field | leading underscore | `self._layout`, `self._invSig`, `self._sliderDrag` |
| global (engine-facing) | `WO_` prefix | `WO_GatherItemsAction`, `WO_StorageBuildCursor` |

Durations carry their unit: `ACTION_DELAY_MS`, `FILL_WAIT_MS`, `GRAB_GIVEUP_MS`,
`activeElapsedMs`, `lastFrameMs`. If it's milliseconds, say `Ms`.

**Method case is split on purpose:**

- Internal plumbing -> camelCase: `ActionPlayer.addToQueue`, `Options.getBool`,
  `SquareUtils.orderByProximity`, `ClearingLogic.unifiedClear`, `API.addItemToGather`.
- Things that read like vanilla, or that a player action maps onto -> PascalCase:
  `SelectUtils.SelectArea`, `StorageLogic.PlaceStorage`, `WorkOrders.OpenWindow`,
  `WO_GatherItemsAction:PickupItems`.

When adding to an existing module, match that module. Don't mix within one file.

---

## 2. Module shape

Every non-global file is a closed table returned at the bottom:

```lua
local SquareUtils = require("helpers/wo_SquareUtils")

local ClaimedSquares = {}

-- { [squareKey] = playerNum } so two players cant fight over the same tile
local claims = {}

function ClaimedSquares.claim(square, playerNum) ... end

return ClaimedSquares
```

Globals only when the engine demands one — timed actions, building cursors, and the
`WorkOrders` namespace. Any file touching the namespace opens with:

```lua
WorkOrders = WorkOrders or {}
```

Add-on files open with a hard bail so they die quietly when the mod isn't loaded:

```lua
if not WorkOrders or not WorkOrders.API then return end
```

Requires are grouped at the top, `=` aligned when there's more than two:

```lua
local ActionPlayer = require("helpers/wo_ActionPlayer")
local SelectUtils  = require("wo_SelectUtils")
local SquareUtils  = require("helpers/wo_SquareUtils")
local Options      = require("helpers/wo_Options")
```

---

## 3. Formatting

- 4 spaces. No tabs.
- Guard clauses over nesting. Single-line returns are the default:
  `if not square then return end`
- The clamp idiom, written on one line every time:
  ```lua
  if dt < 0 then dt = 0 elseif dt > 100 then dt = 100 end
  ```
- Semicolons *only* to pack two statements onto one line:
  `stumpObj = worldObject; break`
- Multiple assignment for coordinate groups:
  `local squareX, squareY, squareZ = square:getX(), square:getY(), square:getZ()`
- `table.insert(t, v)` for normal appends; `t[#t + 1] = v` in append-heavy loops.
  Both are fine, don't churn existing code to switch.
- Align `=` in config-shaped tables (`SETTINGS`, `ContainerRegistry.Types`, UI constants).

---

## 4. PZ engine idioms

**Java collections are 0-based and need explicit size:**

```lua
local items = container:getItems()
for itemIndex = 0, items:size() - 1 do
    local item = items:get(itemIndex)
```

**Copy a Java list into a Lua table before mutating its owner** — otherwise the iteration
shifts under you:

```lua
local items = {}
local javaItems = container:getItems()
for itemIndex = 0, javaItems:size() - 1 do
    items[#items + 1] = javaItems:get(itemIndex)
end
for _, item in ipairs(items) do
    container:Remove(item)
```

**Type checks use `instanceof` with the class name string:**
`instanceof(worldObject, "IsoWorldInventoryObject")`

**ModData keys are namespaced.** `WO_AutoLogStorage`, `WorkOrders_HUDPos`,
`WorkOrders_WindowRect`. Never a bare key.

**Timed actions follow one shape** — `isValid`, `start`, `update`, `perform`, `complete`,
`getDuration`, `new` last:

```lua
function WO_GatherSpriteAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 50
end

function WO_GatherSpriteAction:new(character, spriteObj, itemType, destContainer)
    local action = {}
    setmetatable(action, self)
    self.__index = self
    action.character = character
    ...
    action.stopOnWalk = true
    action.stopOnRun = true
    action.maxTime = action:getDuration()
    return action
end
```

`perform` calls up to the base first, then fires refresh events:

```lua
function WO_RemoveStorageAction:perform()
    ISBaseTimedAction.perform(self)
    triggerEvent("OnContainerUpdate")
    ISInventoryPage.dirtyUI()
end
```

**Monkeypatch by keeping the original in a local and calling through it:**

```lua
local vanillaAddOrDrop = Actions.addOrDropItem
function Actions.addOrDropItem(character, item)
    ...
    if not (isActive and ItemList.DropItems[item:getFullType()]) then
        return vanillaAddOrDrop(character, item)
    end
```

**Event hookups go at the bottom of the file**, after everything they call is defined.

---

## 5. Ticking and long jobs

`ActionPlayer` owns the per-player task queue, game-speed keeper, square claiming, rest
handling, dark check, and the "player took over" bail. **Use it.** Don't write a new
OnTick work loop.

```lua
ActionPlayer.addToQueue(playerObj, taskFunc, { playerObj, square }, { dedupeSquare = true })
ActionPlayer.onFinish(playerObj, function(finishedPlayer) ... end)  -- runs on finish OR cancel
ActionPlayer.clear(playerObj)
```

`opts.isDone(playerObj)` lets a task span work that isn't a timed action (grapples,
animations). Without it, a task ends when the timed-action queue empties.

When a raw ticker genuinely is needed (`wo_GatherItemsAction`, `BOYD_CorpseMover`,
`SpeedKeeper`), the self-rescheduling pattern is:

```lua
local function OnTick()
    Events.OnTick.Remove(self.OnTick)      -- first line, always

    ... bail conditions: dark, player input, dead player ...

    local now = getTimestampMs()
    local dt = now - (self.lastFrameMs or now)
    self.lastFrameMs = now
    if dt < 0 then dt = 0 elseif dt > 100 then dt = 100 end

    ... work ...

    Events.OnTick.Add(self.OnTick)          -- re-add at every exit that continues
end
self.OnTick = OnTick
Events.OnTick.Add(self.OnTick)
```

Rules that fall out of it:

- Remove first, re-add at each continuing exit. Every early `return` must have decided
  whether it re-arms.
- Clamp `dt` to 100 ms so an alt-tab doesn't fast-forward the job.
- Check the abort every tick: `playerObj:pressedMovement(false) or playerObj:pressedCancelAction()`.
- Store the handler on the job/queue table so cleanup can find it.
- Fast-forward: **x1 (F4) only.** F5+ stopping is a vanilla limitation, not a bug to fix.

---

## 6. Registration and the add-on API

Everything registers into flat tables at load time: `OptionsList`, `Providers`, `Domains`,
`Categories`, `ClearRegistry`, `ContainerRegistry.Types`, `ItemList.*`.

**Order matters and is stated in the file.** Categories exist before options reference them:

```lua
require("registries/wo_CategoryRegistry") -- domain and category must exist before options! derp
```

**Refuse collisions loudly, return false, never overwrite:**

```lua
if WorkOrders[finalName] then
    print("WorkOrders API ERROR: Logic name '" .. finalName .. "' already exists. Registration aborted.")
    return false
end
```

**Dead API stays as a stub that yells** so old add-ons fail visibly instead of silently:

```lua
function API.addScanner(category, id)
    print("WorkOrders API: addScanner(...) is no more -- do availability checks inside "
        .. "your menu option's condition(playerInv, flags).")
end
```

**Menu options are declarative tables**, validated at registration:

```lua
API.addMenuOption({
    domain    = "Farming",
    category  = "Farming_Tend",
    condition = function(playerInv, flags) return playerInv:containsTypeRecurse("Fertilizer") end,
    translate = "UI_Farming_Fertilize",
    tooltip   = "UI_Farming_Fertilize_Tooltip",
    reqTag    = "UI_Farming_Req_Fertilizer",
    icon      = "Item_Fertilizer",
    action    = { "SelectArea", "farmFertilize" },
})
```

`action` is `{ selectUtilName, logicName, ...params }`. Both names are **strings resolved
late** through `resolveLogic`; a param string matching a flag key gets substituted with
that flag's value. Availability lives in `condition(playerInv, flags)` — cheap and pure,
it runs on every window rebuild.

Public API functions carry EmmyLua annotations. Internals don't need them.

```lua
--- add an item or a table of items to a gathering category
---@param category string the name of where you'll keep your list of itemData
---@param itemData string|string[]|table<string,boolean> the items to gather
function API.addItemToGather(category, itemData)
```

---

## 7. Logging

| Prefix | Used for |
|---|---|
| `WorkOrders API: ` / `WorkOrders API ERROR: ` | API misuse by an add-on |
| `ERROR: RegisterOptions.<fn> - ` | registration validation failure |
| `WARNING: RegisterOptions.<fn> - ` | recoverable, renders with fallback styling |
| `[WO] ` / `[BOYD] ` / `[WOFarm] ` | runtime / debug |

Debug logging is a file-local flag plus a no-op wrapper, with the toggle left commented
in place:

```lua
-- what did you fuck up now, Jim?
-- WOFarmDebug = true
local function debugLog(message) if WOFarmDebug then print("[WOFarm] " .. message) end end
```

---

## 8. Multiplayer

- Branch on `isClient()` / `isServer()`. Never assume SP.
- **Sandbox wins in MP, mod options in SP.** Same shape everywhere:
  ```lua
  if isClient() or isServer() then
      pct = SandboxVars.JBWorkOrders and SandboxVars.JBWorkOrders.WorkEnduranceReduction
  else
      pct = Options.get("Endurance_Reduction", 0)
  end
  ```
  MP-locked sliders render disabled rather than disappearing.
- Player identity: `WorkOrders.playerKey()` — `getOnlineID()` in MP, `getPlayerNum()` in SP.
- Transmit after mutating world state: `transmitModData`, `transmitRemoveItemFromSquare`,
  `transmitUpdatedSpriteToServer` (client) / `transmitUpdatedSpriteToClients` +
  `sendObjectChange` (server), `sendAddItemToContainer`, `sendRemoveItemFromContainer`.
- Destroying objects: `sledgeDestroy` on client, `transmitRemoveItemFromSquare` +
  `RemoveTileObject` on server.
- Client commands go through one module name with a small verb, both ends in the same file:
  `sendClientCommand(playerObj, "WorkOrders", "processStart", {})`.

---

## 9. UI

- Layout constants at the top of the file. No magic numbers in draw code.
  `PAD`, `TITLE_H`, `TAB_W`, `CELL_W`, `ICON`, `GAP`, `LABEL_LINES`.
- **`prerender` computes, `render` draws.** Layout lands in `self._layout`; hit-testing in
  `onMouseUp` re-derives from that same layout. Never compute geometry twice by hand.
- Rebuild is signature-driven, not every frame:
  ```lua
  local signature = invSignature(player())
  if signature ~= self._invSig or dark ~= (self.flags and self.flags.tooDark) then
      self._invSig = signature
      self:refresh()
  end
  ```
- All text via `getText("UI_WorkOrders_...")`. Keys live in
  `common/media/lua/shared/Translate/EN/*.json`.
- Window rect and HUD button position persist to player ModData and are clamped back onto
  the screen on open.
- Textures that can return nil for a frame get a lazy retry, not an assumption:
  ```lua
  -- so getSharedTexture can and will return nil for a frame or two so that's fun
  if not ninePatch and NinePatchTexture then
      ninePatch = NinePatchTexture.getSharedTexture("media/ui/WO_Panel9patch.png")
  end
  ```

---

## 10. Comments

The voice is lowercase, conversational, and absolutely as profane as Jim. **Keep it.** Do not sanitize it,
do not rewrite it into corporate neutral, do not "clean up" a comment while editing the
code under it.

Comments explain *why*, or flag a trap. They never restate the code:

```lua
-- trees also have the IsoFlagType.canBeCut so skip those!
-- throw shit around the square so it doesnt all fall in one place
-- we gonna copy to a lua table first
-- never leave a body halfass grappled or it can reanimate and fuck that
```

Known-jank markers are load-bearing documentation. Leave them:

```lua
-- this is pure shitass jank that I gave up on
-- so args[2] is usually the work square, but sometimes it's a world object(because I'm lazy)
```

Module-top contract blocks are the one place for structured comments — see the callback
shapes at the top of `wo_SelectUtils.lua` and the runner docs in `wo_API.lua`.

Typos in existing comments are not bugs. Don't fix them as drive-by changes.

---

## 11. Checklist before pushing

- [ ] No `pcall` / `xpcall`.
- [ ] Every `Events.*.Add` has a path that `Remove`s it.
- [ ] New long-running work goes through `ActionPlayer`, not a new ticker.
- [ ] Player abort (`pressedMovement` / `pressedCancelAction`) is honored.
- [ ] `dt` clamped; timestamps in `Ms`-suffixed names.
- [ ] Java lists iterated `0 .. size() - 1`; copied to Lua before mutating the owner.
- [ ] New settings read sandbox in MP, mod options in SP.
- [ ] World mutations transmit for MP.
- [ ] All new strings via `getText`, keys added to `Translate/EN/`.
- [ ] Registration validates input, prints on failure, returns false, never overwrites.
- [ ] New public API has EmmyLua annotations.
- [ ] Loop indices named `<thing>Index`, no `i`.
- [ ] Comments left in the author's voice.
