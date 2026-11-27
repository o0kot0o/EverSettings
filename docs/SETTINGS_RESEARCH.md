# Settings research (WoW: Forever)

What EverSettings knows about Forever's settings system, where each fact came from, and how sure it is.

## Sources and revisions

| Source | Revision | Build | Used for |
|---|---|---|---|
| [Ketho/BlizzardInterfaceResources `forever`](https://github.com/Ketho/BlizzardInterfaceResources/tree/forever) `Resources/CVars.lua` | `e230342a476eb4ef484ba7b34adc0da6ecc6acc1` (2026-11-14) | 1.60.1.70938 | CVar names, defaults, console category, account/character/secure flags, help text; console commands |
| same repo, `GlobalAPI.lua`, `WidgetAPI.lua`, `AtlasInfo.lua`, `GlobalStrings/enUS.lua` | same | 1.60.1.70938 | API existence checks, strict widget mock, atlas availability, Blizzard's labels and tooltips |
| [Gethe/wow-ui-source `forever`](https://github.com/Gethe/wow-ui-source/tree/forever) | `d9c22e32cb240afb82bb2ecefbb78ef935333f59` (2026-11-25) | 1.60.1.71139 | Blizzard's actual Forever settings definitions, ranges, option lists, composite settings, API documentation |
| [ForeverPlusPlus `docs/forever-api.md`](https://github.com/xIGBClutchIx/ForeverPlusPlus/blob/main/docs/forever-api.md) | `6b98426` (2026-11-27) | 70009–70938 | In-game findings on Forever (TOC, SavedVariables, secrets, CVar notes) |
| [reckhou/WoWBlzCode](https://github.com/reckhou/WoWBlzCode), [warcraft.wiki.gg/wiki/CVar](https://warcraft.wiki.gg/wiki/CVar) | not used for data yet | n/a | Listed for cross-checking. Neither is Forever-specific, so nothing from them is used without Forever confirmation (see open questions) |

The live client on the development machine is in `C:\Program Files (x86)\World of Warcraft\_forever_` (product `wowf`). The dump build (70938) and UI source build (71139) differ by one patch; `/es diag` reports differences between the bundled catalog and the running client.

## Forever client facts relevant to settings

| Fact | Evidence |
|---|---|
| Interface 16001; `GetBuildInfo()` returns `"1.60.1", build, date, 16001`; detect Forever with `16000 <= interface < 17000` | FPP (in-game), Ketho README |
| TOC `[Family]` resolves to `Mainline`, `[Game]` to `Camelot`; game types `camelot` and `mainline` both load on Forever | Ketho README, FPP (in-game probe) |
| `ConsoleGetAllCommands()` is the global (not `C_Console`); entries have `command`, `help`, `category`, `commandType`, `scriptContents`, `scriptParameters`; `Enum.ConsoleCommandType.Cvar = 0`, `Command = 1`, `Macro = 2`, `Script = 3` | `Blizzard_APIDocumentationGenerated/ConsoleDocumentation.lua`; FPP (C_Console missing, in-game) |
| `Enum.ConsoleCategory`: Debug 0, Graphics 1, Console 2, Combat 3, Game 4, Default 5, Net 6, Sound 7, Gm 8, Reveal 9, None 10 | ConsoleDocumentation.lua |
| `C_CVar.GetCVarInfo(name)` returns `value, defaultValue, isStoredServerAccount, isStoredServerCharacter, isLockedFromUser, isSecure, isReadOnly` | CVarDocumentation.lua |
| `C_CVar.SetCVar(name, value) -> success` has preconditions `RequiresValidAndPublicCVar`, `RequiresNonReadOnlyCVar`, `RequiresNonSecureCVar`, all with FailureMode **ReturnNothing**: a refused write returns nothing instead of raising an error. EverSettings therefore reads back every write. | CVarDocumentation.lua |
| `CVAR_UPDATE` payload is documented as `(eventName, value)`, but Blizzard's own Forever handlers treat it as `(cvarName, value)` | ConsoleDocumentation.lua; `Blizzard_AccessibilityTemplates/Mainline/AccessibilityTemplates.lua`, `Blizzard_CharacterCreate/Camelot/Blizzard_CharacterCreate.lua` |
| Global `GetCVar`/`SetCVar`/`GetCVarBool`/`GetCVarDefault` are Lua wrappers in `Blizzard_SharedXMLBase/CvarUtil.lua` | UI source |
| No CVar carries a type. A 0/1 default does not make a boolean (`cameraSmoothStyle` takes 0, 1, 2, 4) | FPP; Controls.lua |
| SavedVariables persist (since 2026-09-24) | FPP (in-game) |
| Opening Blizzard menus from addon code can taint the controller UI; EverSettings uses its own frames | FPP (Gethe source analysis) |

## Catalog classification (automated)

`tools/database/import_cvars.py` evaluates every Blizzard addon TOC the way the Forever client does (`[Family]`/`[Game]` substitution, `AllowLoadGameType`/`ExcludeLoadGameType` for `camelot`/`mainline`, XML includes), then scans the loaded files for each CVar name as a string literal:

| Exposure | Count | Meaning |
|---|---|---|
| settings (2) | 418 | Referenced by a file in Blizzard's settings-definition addons that Forever loads |
| ui (1) | 256 | Referenced by other Blizzard UI code Forever loads |
| hidden (0) | 1,111 | Not referenced by any loaded Blizzard UI file |

Totals: 1,785 CVars, 77 commands (10 PTR-only variables and 10 PTR-only commands excluded), 81 secure, account-stored and character-stored counts in `tools/database/out/catalog_report.json`.

The scan is heuristic. A literal match can be a false positive: a few generic names such as `Outline` or `SSAO` also appear as non-CVar strings. It can also miss a CVar whose name is built at runtime. Curated definitions always cite the specific Blizzard code, not just the classification.

## How Blizzard's Forever settings are built (findings)

### Settings controlled by dedicated APIs or callbacks
- **Graphics quality preset** (`graphicsQuality`): changing it runs `OnGCChanged`, which sets every advanced quality CVar to `GetGraphicsCVarValueForQualityLevel(cvar, level, raid)`, raises particle density to at least 1, and only includes children whose feature is supported (`C_VideoOptions.IsPBRWaterSupported`, `IsOutlineModeSupported`, `IsSpellVisualDensitySystemSupported`, `IsSecondaryLightingSupported`). The cascade lives in Blizzard's Lua, not the engine, so setting the CVar alone does **not** cascade. EverSettings reproduces it as the composite `graphicsPreset`. (Graphics.lua, GraphicsOverrides.lua)
- **Trivial quest tracking**: `C_Minimap.SetTracking(MinimapUtil.GetFilterIndexForFilterID(Enum.MinimapTrackingFilter.TrivialQuests), value)` (Camelot/InterfaceOverrides.lua). Implemented as API provider `trivialQuestTracking`.
- **Display mode, monitor and resolution**: `C_VideoOptions.SetGameWindowSize` with `gxMonitor`/`gxMaximize` and `DISPLAY_SIZE_CHANGED`. Not implemented yet (needs care: wrong values can leave the client unusable).
- **Camera FOV range**: `GetCameraFOVDefaults()` returns default, player min and player max. **Render scale range**: `GetMinRenderScale()`/`GetMaxRenderScale()`. Both used as runtime ranges.
- **Option support**: `IsGraphicsCVarValueSupported(cvar, value)` and `IsGraphicsSettingValueSupported(cvar, value, raid)` return an error index (non-zero means unsupported). Used to disable unsupported dropdown options.

### Settings controlling multiple CVars (composites)
| Blizzard proxy | CVars | Rule | Source |
|---|---|---|---|
| Mouse Look Speed | `cameraYawMoveSpeed`, `cameraPitchMoveSpeed` | pitch = yaw / 2, range 90–270 step 10, default 180 | Controls.lua |
| Auto Follow Speed | `cameraYawSmoothSpeed`, `cameraPitchSmoothSpeed` | pitch = yaw / 4, same range | Controls.lua |
| Triple Buffering | `gxMaxFrameLatency` | 3 = on, 2 = off; GxRestart | Graphics.lua |
| Camera Shake | `ShakeStrengthCamera`, `ShakeStrengthUI` | both 0 / 0.25 / 1 | Accessibility.lua |
| Motion Sickness | `CameraKeepCharacterCentered`, `CameraReduceUnexpectedMovement` | on = 0 and 1 | Accessibility.lua |
| Anti-aliasing | `MSAAQuality`, `ffxAntiAliasingMode`, `msaaAlphaTest` | mode/MSAA/CMAA interplay (`SplitMSAA`) | Graphics.lua (only the image-based part is implemented) |
| Sticky Targeting | `deselectOnClick` | inverted boolean (`NegateBoolean`) | Controls.lua |

### Ranges and enumerations
All ranges and option lists in the definition files come from `Settings.CreateSliderOptions(min, max, step)` and option containers in Blizzard's Forever code, or from the CVar's own help text when it states a range (for example `Gamma` "Range: [0.3 - 2.8]"). Examples: FPS limits 8–200 step 1, UI scale 0.65–1.15 step 0.01, Max Camera Distance 1.0–2.0 step 0.1 (Camelot override; Retail's range differs), quality sliders 0–9 shown as 1–10.

### Protected, secure and read-only settings
- 81 CVars are flagged secure in the dump (for example `uiScale`, `useUiScale`, `autoStand`, `autoUnshift`, `ActionButtonUseKeyDown`, `showTargetOfTarget`). `SetCVar` documents `RequiresNonSecureCVar`. EverSettings treats secure variables as unwritable during combat and reads back after every write. Whether addons can write secure CVars **outside** combat on Forever is unverified (see open questions).
- `isReadOnly` and `isLockedFromUser` from `GetCVarInfo` are checked at runtime before every write.

### Storage scope
From the dump flags: account-stored (server), character-stored (server), otherwise local machine (`Config.wtf`). Example: `showQuestLevel` and `autoSelfCast` are character-scoped; `autoLootDefault` is account-scoped; graphics CVars are machine-scoped.

### Reload and restart requirements
Blizzard commit flags: `GxRestart` (triple buffering, graphics API and similar) and `ClientRestart` (`physicsLevel`). Community reports say `outlineModeShowLootEffectWhenDisabled` needs a full restart to turn off. Marked as `apply = "gxrestart"` or `"restart"`.

### Dependencies
`maxFPS` needs `useMaxFPS`, `maxFPSBk` needs `useMaxFPSBk`, `targetFPS` needs `useTargetFPS`, and `uiScale` needs `useUiScale`. Image-based AA only applies when the AA mode is Image-Based or Advanced. Resample quality and sharpness only matter when render scale is not 100%. The `raidGraphics*` settings need `RAIDsettingsEnabled`.

### Deprecated, internal and possibly non-functional variables
- 45 in the Debug category and 183 in Default include developer, telemetry and test variables (`telemetry*`, `AIBrain`, `addon*RestrictionsForced`, `test_*`). They are never made editable without research.
- `nameplateSimplifiedScale` resets to 0.3 at every login (FPP user report): writable, but not persisted.
- 12.0 renames: `nameplateShowFriends` became `nameplateShowFriendlyPlayers`, `ShowClassColorInNameplate` became `nameplateShowClassColor`; `nameplateMotion`, `nameplateGlobalScale` and `nameplateOtherTopInset` are gone (FPP).
- Forever-only variables: `ShowAllSpellRanks`, `showQuestLevel`, `showSwingTimer`, `showTaxiNodeLearnedIcon`, `classicStyleWorldText`, `canUseQuestItemWithLeftClick`, `displayFreeBagSlots`, `showLootSpam` (FPP).

## Verification model

Evidence is tracked separately per aspect: **exists**, **values** (accepted values), **write** (permission), **persist** (persistence) and **effect** (observed effect). Each aspect can be `verified` (observed in game on Forever), `source` (Blizzard's Forever code or client dump), `community`, `experimental`, `unknown` or `unsupported`. Current totals are in [COVERAGE.md](COVERAGE.md). No aspect is in-game verified yet.

## Runtime discovery on the live client (2026-11-27, build 1.60.1.71139)

First in-game run, read from EverSettings' SavedVariables. `ConsoleGetAllCommands()` returned 1,800 variables and 77 commands.

- **16 variables not in the bundled dump (70938):**
  - 8 `CACHE-*` counters (`CACHE-WGOB-GameObjects{Hotfix,Record}Count`, `CACHE-WQST-QuestObjective…`, `CACHE-WQST-QuestV2…`). These are internal client-cache statistics, not settings.
  - 8 nameplate variables: `nameplateCastBarDisplay`, `nameplateEnemyNpcAuraDisplay`, `nameplateEnemyPlayerAuraDisplay`, `nameplateFriendlyPlayerAuraDisplay`, `nameplateInfoDisplay`, `nameplateSimplifiedTypes`, `nameplateStackingTypes`, `nameplateThreatDisplay`. FPP documents `nameplateThreatDisplay` as a bitfield of `Enum.NamePlateThreatDisplay`, and `nameplateSimplifiedTypes` as account-scoped. Lesson: **the static dump does not contain every variable**, so runtime discovery is required, and the catalog should be merged with discovery results. Relevant for Milestone C (nameplates).
- **1 catalog variable not listed by the client:** `showInGameNavigation`. Blizzard's own `Interface.lua` guards it with `if C_CVar.GetCVar("showInGameNavigation")`, so it can be absent.
- **15 changed defaults, none from a patch:**
  - 14 are graphics quality CVars (`graphicsQuality`, view distance, environment detail, ground clutter, shadows, compute effects, outline mode, and their `raid*` twins), each one level higher than in the dump. The client derives these defaults from hardware detection, so they differ per machine. EverSettings already takes "factory default" from the running client (`GetCVarDefault`), not from the catalog.
  - `serverAlert`: a region-specific URL (us vs eu).
- An external change was recorded right after install: `showQuestLevel` was turned on outside EverSettings (another addon, such as Questie, or the player). Sync detected and logged it without overwriting.

## Open research questions

1. Can addon code write **secure** CVars (`uiScale`, `autoStand`) outside combat on Forever, or does `RequiresNonSecureCVar` block tainted callers entirely? (Test: Apply in EverSettings out of combat, then read back.)
2. Does `ConsoleGetAllCommands()` list every CVar on Forever? (FPP open question; `/es diag` reports catalog entries missing from the client list.)
3. Does `CVAR_UPDATE` fire for console (`/console`) changes and for Blizzard's settings panel on Forever?
4. Upper limit of `cameraDistanceMaxZoomFactor` on Forever (Retail 2.6, Classic Era 4.0, not verified). Needed before offering an extended range.
5. Ranges for frequently requested hidden variables: `cameraZoomSpeed`, `farclip`, `nameplateMaxDistance` (a character had 60 saved), `SpellQueueWindow`.
6. Do `maxFPS`/`targetFPS` accept values above Blizzard's slider maximum of 200?
7. Persistence of each scope after relog and restart (all `persist` evidence is currently unknown).
8. Defaults and exact triggers of `autoDismount`, `autoStand` and `autoUnshift` on Forever (FPP open question).
