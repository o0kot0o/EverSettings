# Architecture

## Overview

```
Definitions (data) ──► Registry ──► Providers ──► game (C_CVar, C_Minimap, ...)
        ▲                 │             ▲
 CVar catalog (generated) │             │ read back / validate
                          ▼             │
           UI (pages, rows, controls) ──► Changes (staging + apply pipeline)
                          ▲                     │
                 Callbacks (pub/sub) ◄── Sync (CVAR_UPDATE, polling) / History / Backup
```

The UI never knows how a setting is stored: it asks a provider through `ns.Providers` for availability, restrictions, the current value, the default, options or range, and it stages changes through `ns.Changes`.

## Load order (EverSettings.toc)

1. `Locales`, `Core/Init` (namespace, saved-variable defaults), `Core/Util`, `Core/Compat` (API probing), `Core/Callbacks`
2. `Database/Schema`, `Database/Categories`, `Database/Generated/CVarCatalog`, `Database/Registry`
3. `Providers/*` (provider registry plus the cvar, composite, api and diagnostic implementations)
4. `Database/Definitions/*` (data registered with `Registry:Define`)
5. Services: `Core/Values`, `Discovery`, `Backup`, `History`, `Changes`, `Sync`, `Profiles/*`, `Diagnostics`
6. `UI/*` (theme, components, pages, main window)
7. `Core/Boot` (events and slash commands)

`ADDON_LOADED` initialises saved variables, probes APIs (`Compat:Detect`) and validates definitions (`Registry:Finalize`). Definitions that fail validation are disabled, not loaded half-broken. `PLAYER_LOGIN` primes the sync cache. A timer then takes the initial snapshot (1 s) and runs discovery (3 s). All of this is read-only.

## Modules

| Module | Responsibility |
|---|---|
| `Compat` | Probes every game API, wraps `GetCVar`/`GetCVarInfo`/`SetCVar` (SetCVar returns ok, err, and a nil result is treated as possibly refused) |
| `Schema` | Enums and the definition validator (also used offline) |
| `Categories` | Category tree (14 main categories, fixed subcategories) |
| `Registry` | Definition storage, catalog cross-reference, derived scope/classification/restrictions/status, indexes by id, category and CVar, search |
| `Providers` | Provider interface, runtime ranges (`rangeFuncs`), dynamic options with per-system support checks (`optionFuncs`) |
| `Values` | Canonical values: raw conversion, validation, display transform (scale, offset, suffix), exact input parsing |
| `Changes` | Staging and the apply pipeline: validate, dependencies, restrictions, original backup, write, read back, classify, history |
| `Sync` | External change detection from `CVAR_UPDATE` and polling of visible rows; never writes |
| `History` | Persistent change log (500 entries) and session undo/redo of apply operations |
| `Backup` | Initial snapshot, original values, named backups, staged restores |
| `Discovery` | `ConsoleGetAllCommands()` enumeration and comparison with the catalog, per-build summary |
| `Profiles` / `Serializer` | Profile CRUD, compare, selective staging, checksummed text format |
| `Diagnostics` | Coverage, consistency checks against the running client, copyable report |
| `UI` | Theme, components, pages, inspector, main window |

## Provider types

| Type | Use | Milestone A examples |
|---|---|---|
| `cvar` | One console variable | Gamma, Auto Loot |
| `composite` | One control driving several variables through a named handler | Graphics Quality Preset, Mouse Look Speed, Triple Buffering, Camera Shake, Motion Sickness |
| `api` | Dedicated getter/setter functions through a named handler | Show Low-Level Quests (C_Minimap tracking) |
| `diagnostic` | Read-only information | Client build, discovery result |
| `blizzard` | Reserved for the Blizzard Settings API | none yet |

Adding a setting normally needs only a new definition. Adding a new storage mechanism means a new composite/api handler, not UI code.

## Apply pipeline

`Changes:ApplyList` sorts by `applyOrder` (the graphics preset uses -10, so individually staged quality settings applied afterwards take priority), then for each change:

1. `Values.Validate`: invalid means **failed**, nothing written.
2. `Providers:GetRestriction`: unavailable, read-only, locked, or secure/combat-restricted means **restricted**, and the change stays pending.
3. Dependency check: produces warnings only.
4. `Backup:RecordOriginal`: the first time only.
5. `Providers:Set`, then `Providers:Get` (read back).
6. Read-back equal to the request: **success**. Different from both the request and the previous value: **clamped** (adjusted by the client). Equal to the previous value: **rejected**. A write error: **failed**.
7. Success and clamped results go to the history and become one undo operation.

`Sync` is suspended during apply so EverSettings' own writes are not logged as external.

## Saved variables (`EverSettingsDB`, account-wide)

`window`, `ui` (collapsed sections, last page), `favorites`, `profiles`, `activeProfile`, `snapshots.initial`, `characterSnapshots[name-realm]`, `originals`, `backups` (max 25), `history` (max 500), `discovery.byBuild`, `debug`, `dbVersion` (migrations in `Boot.lua`).

## Decision log

| # | Decision | Reason |
|---|---|---|
| D1 | Own frames for dropdowns, dialogs and the window; no Blizzard Settings panel integration, StaticPopup or Menu | Avoid taint, especially the controller focus-manager taint documented for Forever's Menu system |
| D2 | Curated definitions authored as Lua data; the full catalog generated by Python | Definitions need functions for runtime availability; the catalog is pure data regenerated per patch |
| D3 | Staged changes only, no live preview in Milestone A | The spec allows preview only for researched, restorable settings; none are researched in game yet |
| D4 | Composite handlers reproduce Blizzard's proxy logic exactly (cascade, ratios, mappings) | One control must mean the same thing as in Blizzard's window |
| D5 | The CVar browser is read-only | Unknown variables stay read-only until researched |
| D6 | Profiles store canonical values per setting id, not raw CVar strings | Lets imports be validated against the local database, and keeps composites coherent |
| D7 | A strict offline mock built from the Forever widget/API dumps | Catches calls to methods or handlers that do not exist on Forever before testing in game |
| D8 | ~~No category icons in Milestone A~~ (superseded by D10) | Forever ships only a few suitable monochrome atlases |
| D9 | ~~Arial Narrow UI font~~ (superseded by D11) | Compact, neutral look at small sizes |
| D10 | Lucide icons rendered to tinted 32×32 TGAs (`tools/icons`), ISC license file shipped in `Media/Icons` | Issue #4 asked for consistent monochrome category icons; Forever's atlases have no coherent set. TGAs are WoW's native addon texture format |
| D11 | Bundled Inter font (SIL OFL 1.1, license shipped in `Media/Fonts`); client standard font for CJK | 0.1 screenshots showed Arial Narrow too small and thin at common UI scales; the client ships only display fonts and Arial Narrow |
| D12 | The Details panel (inspector) is hidden by default, opened by its button or a double-click, and selection never auto-opens it; saved layout migrates once (v1 to v2) unless the player chose it | Issue #4: the empty inspector cost a quarter of the list width |
| D13 | Own interface scale on the main window (dropdowns and dialogs follow it) | Readability independent of the game's UI scale |
| D14 | Slider controls are never hidden, resized, re-ranged or re-positioned while `IsDraggingThumb()` is true | The in-game drag bug (#1); regression tests model the client cancelling drags |
