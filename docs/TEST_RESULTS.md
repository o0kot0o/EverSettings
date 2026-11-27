# Test results

Three levels are tracked separately: **code implemented**, **offline tested**, **in-game verified**.

## Offline tests: 95 passed, 0 failed (2026-11-27)

Command: `.\scripts\test.ps1 -v` (Python 3.12, lupa 2.x, Lua 5.1 runtime). Addon load time offline: about 11 ms.

What the harness checks:
- **Strict widget mock.** Every widget method and script handler the addon uses must exist on that widget type in Forever's WidgetAPI dump (build 1.60.1.70938); anything else raises an error. The real `EverSettings.toc` load order is used.
- **API surface.** Every `C_*` function referenced in the source, and every listed global, exists in Forever's GlobalAPI dump.
- **Safety invariants.** No `SetCVar` during load, login or startup timers; no global leaks; profiles and browsing never write.
- **Behaviour.** Schema, values, apply pipeline (success, clamped, rejected, failed, restricted), composites, sync, history, undo/redo, discovery, profiles and import hardening, and UI flows (open/close, every page, numeric entry with Enter/Escape and invalid input, slider drag, toggle, dropdown, reset, restricted state, footer apply, virtualized browser).

The mock cannot prove in-game behaviour: layout, fonts, taint, real CVar semantics and hardware-dependent options need in-game testing.

### Passing tests

- [x] api_spec.lua :: Forever API surface :: every listed global API the addon calls exists in the Forever dump
- [x] api_spec.lua :: Forever API surface :: every C_ namespace function referenced in the source exists in the Forever dump
- [x] boot_spec.lua :: boot :: loads every TOC file and initialises saved variables
- [x] boot_spec.lua :: boot :: detects the Forever client
- [x] boot_spec.lua :: boot :: does not modify any game setting on install or login
- [x] boot_spec.lua :: boot :: prints nothing alarming during boot
- [x] boot_spec.lua :: boot :: captures the initial snapshot
- [x] boot_spec.lua :: boot :: registers both slash commands
- [x] boot_spec.lua :: boot :: handles unknown slash commands gracefully
- [x] boot_spec.lua :: boot :: loads quickly
- [x] changes_spec.lua :: staging :: stages without touching the game
- [x] changes_spec.lua :: staging :: drops a pending change that equals the current value
- [x] changes_spec.lua :: staging :: refuses to stage read-only settings
- [x] changes_spec.lua :: staging :: stages category defaults only where values differ
- [x] changes_spec.lua :: apply pipeline :: writes, reads back and reports success
- [x] changes_spec.lua :: apply pipeline :: records the original value only the first time
- [x] changes_spec.lua :: apply pipeline :: detects values clamped by the client
- [x] changes_spec.lua :: apply pipeline :: detects silently rejected writes
- [x] changes_spec.lua :: apply pipeline :: keeps secure settings pending during combat and never writes them
- [x] changes_spec.lua :: apply pipeline :: treats read-only client variables as restricted
- [x] changes_spec.lua :: apply pipeline :: rejects invalid staged values without writing
- [x] changes_spec.lua :: apply pipeline :: warns about unmet dependencies
- [x] changes_spec.lua :: apply pipeline :: reports restart requirements
- [x] changes_spec.lua :: composite settings :: mouse look speed sets pitch to half of yaw
- [x] changes_spec.lua :: composite settings :: triple buffering maps to gxMaxFrameLatency 3/2
- [x] changes_spec.lua :: composite settings :: camera shake sets both strengths
- [x] changes_spec.lua :: composite settings :: graphics preset cascades to supported children, respecting minimums
- [x] changes_spec.lua :: composite settings :: applies the preset before individually staged quality settings
- [x] changes_spec.lua :: composite settings :: API provider toggles minimap trivial quest tracking
- [x] changes_spec.lua :: undo and redo :: undoes and redoes an apply
- [x] discovery_spec.lua :: runtime discovery :: separates variables from console commands
- [x] discovery_spec.lua :: runtime discovery :: detects new, missing and changed variables without writing
- [x] discovery_spec.lua :: runtime discovery :: counts unclassified variables
- [x] discovery_spec.lua :: runtime discovery :: diagnostics report builds and finds no consistency issues
- [x] profiles_spec.lua :: profile management :: saves, renames, duplicates and deletes
- [x] profiles_spec.lua :: profile management :: compares against the game and stages only selected categories
- [x] profiles_spec.lua :: profile management :: restores a backup selectively through the staging pipeline
- [x] profiles_spec.lua :: export and import :: round-trips a profile
- [x] profiles_spec.lua :: export and import :: detects tampering and truncation
- [x] profiles_spec.lua :: export and import :: rejects unknown settings, invalid values and never executes content
- [x] schema_spec.lua :: definitions :: all pass schema validation
- [x] schema_spec.lua :: definitions :: cover Graphics, Camera and Quality of Life
- [x] schema_spec.lua :: definitions :: reference CVars that exist in the catalog with their canonical casing
- [x] schema_spec.lua :: definitions :: every slider has a researched range and cites it
- [x] schema_spec.lua :: definitions :: defaults of curated settings lie inside their documented values
- [x] schema_spec.lua :: definitions :: derive scope, classification and secure restrictions from the catalog
- [x] schema_spec.lua :: definitions :: never mark unverified settings as in-game verified
- [x] schema_spec.lua :: definitions :: have unique ids and valid categories
- [x] schema_spec.lua :: schema validator :: accepts a minimal valid definition
- [x] schema_spec.lua :: schema validator :: rejects a slider without a range
- [x] schema_spec.lua :: schema validator :: rejects a slider without a cited range source
- [x] schema_spec.lua :: schema validator :: rejects a dropdown with a single option
- [x] schema_spec.lua :: schema validator :: rejects unknown providers, categories and verification states
- [x] schema_spec.lua :: schema validator :: rejects 'verified' status without verified effect evidence
- [x] schema_spec.lua :: schema validator :: requires research sources
- [x] sync_spec.lua :: external changes :: are detected through CVAR_UPDATE and recorded, without writing back
- [x] sync_spec.lua :: external changes :: drop a pending change the outside world already made
- [x] sync_spec.lua :: external changes :: leave a different pending change in place
- [x] sync_spec.lua :: external changes :: are found by polling when no event fires
- [x] sync_spec.lua :: external changes :: are not reported for EverSettings' own applies
- [x] ui_spec.lua :: main window :: opens with /es and closes again
- [x] ui_spec.lua :: main window :: navigates every sidebar entry without errors
- [x] ui_spec.lua :: main window :: shows an empty-state notice for categories without researched settings
- [x] ui_spec.lua :: main window :: searches across names, technical names and keywords
- [x] ui_spec.lua :: main window :: remembers position and size
- [x] ui_spec.lua :: main window :: toggles the inspector and shows setting details
- [x] ui_spec.lua :: numeric slider + edit box :: stages an exact typed value on Enter
- [x] ui_spec.lua :: numeric slider + edit box :: flags invalid input and does not stage it
- [x] ui_spec.lua :: numeric slider + edit box :: dragging the slider stages on-step values
- [x] ui_spec.lua :: numeric slider + edit box :: percent settings show and accept percentages
- [x] ui_spec.lua :: toggle, dropdown and reset :: toggle stages the opposite value
- [x] ui_spec.lua :: toggle, dropdown and reset :: dropdown shows labels and stages the selected value
- [x] ui_spec.lua :: toggle, dropdown and reset :: reset stages the factory default
- [x] ui_spec.lua :: toggle, dropdown and reset :: restricted settings are disabled with an explanation
- [x] ui_spec.lua :: toggle, dropdown and reset :: footer apply runs the pipeline
- [x] ui_spec.lua :: other pages :: CVar browser filters a large list quickly
- [x] ui_spec.lua :: other pages :: profiles page saves and stages a profile
- [x] ui_spec.lua :: other pages :: diagnostics page renders the report
- [x] values_spec.lua :: input parsing :: accepts plain, decimal and exponent numbers
- [x] values_spec.lua :: input parsing :: rejects garbage
- [x] values_spec.lua :: numeric values :: keeps exactly typed values instead of rounding to the slider step
- [x] values_spec.lua :: numeric values :: rejects values outside the researched range
- [x] values_spec.lua :: numeric values :: rejects fractions for integer settings
- [x] values_spec.lua :: numeric values :: converts percentage display values
- [x] values_spec.lua :: numeric values :: shows quality levels 1-10 for stored values 0-9
- [x] values_spec.lua :: numeric values :: uses runtime ranges from the client
- [x] values_spec.lua :: boolean and enum values :: reads and writes booleans, honouring inverted storage
- [x] values_spec.lua :: boolean and enum values :: validates enums against documented options only
- [x] values_spec.lua :: boolean and enum values :: supports string enums
- [x] values_spec.lua :: boolean and enum values :: disables options the system reports as unsupported
- [x] values_spec.lua :: boolean and enum values :: labels camera shake values set elsewhere as custom and refuses to select it
- [x] zz_globals_spec.lua :: globals :: the addon only creates its documented globals

## In-game verification: started (2026-11-27)

The addon has been deployed to the development machine's Forever install (`_forever_\Interface\AddOns\EverSettings`, 46 files) but has **not** been loaded in game by Claude, which cannot run the game client. Please run this plan and record results here (and per setting in the definitions' `verification` tables).

### In-game test plan (Milestone A acceptance)

| # | Check | How | Result |
|---|---|---|---|
| 1 | Loads without Lua errors | Enable the addon, log in, check for errors (BugSack or `/console scriptErrors 1`) | loads, `/es diag` runs (2026-11-27); error check pending |
| 2 | `/es` and `/eversettings` open and close the window | Type both | pending |
| 3 | No settings changed on install | Before first login with the addon, note a few values (`/dump GetCVar("Gamma")` etc.). After login, `/es diag` shows 0 history entries and the values are unchanged | pending |
| 4 | Current and default values are correct | Compare a few rows with Blizzard's Options window (Gamma, View Distance, Auto Loot, Max Camera Distance) | pending |
| 5 | Slider and edit box stay in sync | Drag the Gamma slider, type `1.23` + Enter, type `9` (red, rejected), press Escape | click works and Apply changes Gamma (2026-11-27); Escape restores the value; invalid input flagged (screenshot). Drag fix v2 (IsDraggingThumb, no hide on refresh) needs recheck |
| 6 | Validate and apply | Stage 2–3 changes, Apply, confirm the footer report and that Blizzard's Options shows the new values | pending |
| 7 | External changes detected | With EverSettings open, change Auto Loot in Blizzard's Options or run `/console autoLootDefault 1`; the row updates | **pass** (Blizzard Options, 2026-11-27) |
| 8 | Restore originals | Profiles > Safety > Original values > Stage originals > Apply | pending |
| 9 | Secure in combat | Enter combat, try to change UI Scale or Auto Stand: disabled with a combat reason; leaving combat re-enables it | pending |
| 10 | Unsupported APIs handled | `/es diag` lists capabilities; options unsupported by your GPU are disabled | pending |
| 11 | Responsive with a large list | CVar Browser: scroll and filter 1,785 variables smoothly | pending |
| 12 | Layout | Window resize, text not overlapping, badges positioned, inspector scrolls | pending |
| 13 | Secure write outside combat | Apply UI Scale out of combat and read back (research question 1) | pending |

Please attach screenshots of the main window, the inspector, the CVar browser and the profiles page to `docs/screenshots/`.
