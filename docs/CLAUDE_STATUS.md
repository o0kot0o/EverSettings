# Claude status

_Last updated: 2026-11-27, 0.2.1-alpha (fixes from the 0.2 in-game screenshots)._

## Current milestone

**Milestone A: Foundation**, plus the **0.2 UI refinement** (issue #4). Implemented and offline tested. In game: loading, discovery, slider/edit-box behaviour, validation and external-change sync are confirmed on 0.1. **0.2 seen in game** (screenshots in `docs/screenshots/after-0.2-*`): fonts, icons, the Details panel and slider drag work. 0.2.1 fixes the issues those screenshots showed and is not yet seen in game. Claude cannot run the game client; the in-game test plan is in [TEST_RESULTS.md](TEST_RESULTS.md).

## Implemented features

| Area | Code implemented | Offline tested | In-game verified |
|---|---|---|---|
| Repository, deploy (`scripts/deploy.ps1`), test and catalog scripts | yes | deploy run successfully on the dev machine (46 files copied) | n/a |
| Forever API research ([SETTINGS_RESEARCH.md](SETTINGS_RESEARCH.md)) | yes | n/a | partly via FPP's in-game notes |
| CVar importer: 1,785 CVars and 77 commands, UI exposure classification | yes | yes (generated catalog loads, specs) | no |
| Structured schema and validator | yes | yes | no |
| Runtime discovery (ConsoleGetAllCommands, read-only) | yes | yes (mock) | no |
| Provider system: cvar, composite (5 handlers), api (1), diagnostic | yes | yes | no |
| Main window: header, sidebar, pages, inspector, footer, move/resize/remember | yes | yes (strict mock) | no |
| Category navigation, Favorites, Modified, Recently Changed, All Settings | yes | yes | no |
| Search and filtering (settings and CVar browser) | yes | yes | no |
| Slider plus edit box (sync, exact entry, Enter/Escape, validation, percent/offset display) | yes | yes | no |
| Toggle and dropdown (with unsupported-option detection) | yes | yes | no |
| Individual reset and category reset (staged) | yes | yes | no |
| Staged changes, apply pipeline with read-back and result classification | yes | yes | no |
| External change detection (CVAR_UPDATE plus polling visible rows) | yes | yes (mock events) | no |
| Initial snapshot, originals, backups, selective restore, history, undo/redo | yes | yes | no |
| Profiles: CRUD, compare, selective categories, import/export | yes | yes | no |
| Technical CVar browser (read-only, virtualized) | yes | yes | no |
| Diagnostics page and `/es diag` | yes | yes | no |
| 0.2 UI refinement: Inter typography and type scale, interface scale, Details panel (hidden by default, button, double-click, resizable, remembered), sidebar icons, responsive control tiers, refined slider/toggle/dropdown/buttons, two-line descriptions with truncation tooltips, technical names, Preferences page | yes | yes (18 layout and feedback tests) | partly: 0.2 seen in game; 0.2.1 fixes pending a recheck |
| 86 curated definitions (Graphics 33, Camera 12, QoL 18, Performance 7, Questing 7, Interface 2, Accessibility 1, read-only info 6) | yes | yes (schema, defaults valid, catalog cross-check) | no |

## Recent changes

- **0.2.1:** fixed "Current —" for false values, Preferences text overlap, sidebar/Manage truncation; Max Camera Distance extended range to 2.6 (observed in game); OUT OF RANGE badge.
- **0.2 UI refinement (#4):** see [CHANGELOG.md](../CHANGELOG.md) and [UI_DESIGN.md](UI_DESIGN.md). Decisions D10–D14 are in [ARCHITECTURE.md](ARCHITECTURE.md#decision-log). The slider drag fix is preserved, and the layout code never hides, resizes or re-ranges a slider while it is dragged (regression-tested).
- Slider drag bug fixed (confirmed in game), compact range errors, live discovery findings documented.
- Initial implementation of Milestone A (all of the above).
- Bugs found and fixed by the offline tests during development: undo of `false` values (Lua `and/or` trap), redo replaying the wrong side, profile names with spaces failing the checksum, the "custom" camera-shake option being selectable, and over-constrained font-string anchors.

## Current limitations

- No in-game verification yet; every `persist` evidence entry is `unknown`.
- Screenshots: 0.1 and 0.2 screenshots are committed; 0.2.1 screenshots are still wanted.
- Display mode, resolution and full MSAA anti-aliasing are not implemented (they need careful composites).
- Categories without researched settings (Combat, Targeting, Nameplates, Controls, Audio, Network) show an empty state that points to the CVar browser.
- No live preview (by design until settings are verified as safely restorable).
- English only.
- Undo/redo stacks last for the session only (history is persistent).

## Known bugs

None known on 0.1. 0.2 changed most of the UI and has only been tested offline, so expect visual issues on the first in-game run.

## Settings database coverage

See [COVERAGE.md](COVERAGE.md) (generated). Summary: 1,785 catalog CVars; 418 in Blizzard's settings window, 256 used by other UI, 1,111 hidden; 86 definitions covering 83 CVars; 1,702 unclassified (read-only in the browser).

## In-game verification results

First result (2026-11-27, owner): **the addon loads, and `/es diag` and runtime discovery work on Forever.** Discovery found 1,800 variables and 77 commands: 16 variables not in the bundled catalog, 1 catalog variable missing from the client list, and 15 defaults that differ from the catalog. 84 of 86 definitions are available; the 2 unavailable are hardware-gated graphics options, as expected. Details in [#1](https://github.com/o0kot0o/EverSettings/issues/1). The rest of the plan in [TEST_RESULTS.md](TEST_RESULTS.md#in-game-test-plan-milestone-a-acceptance) is pending.

## Offline test results

113 passed, 0 failed (`.\scripts\test.ps1`). Details: [TEST_RESULTS.md](TEST_RESULTS.md).

## Open GitHub issues

| # | Title | Label |
|---|---|---|
| [#1](https://github.com/o0kot0o/EverSettings/issues/1) | Milestone A: in-game verification | in-game-test |
| [#2](https://github.com/o0kot0o/EverSettings/issues/2) | Research: can addons write secure CVars on Forever? | research |
| [#3](https://github.com/o0kot0o/EverSettings/issues/3) | Research: documented ranges for hidden camera, nameplate and combat variables | research |
| [#4](https://github.com/o0kot0o/EverSettings/issues/4) | Design review: visual polish and category icons | design |
| [#5](https://github.com/o0kot0o/EverSettings/issues/5) | Code review: apply pipeline, sync and import safety | review. **No review comments have been posted on GitHub yet**; writable coverage stays unchanged until they arrive. |

## Questions requiring further research

See [SETTINGS_RESEARCH.md: Open research questions](SETTINGS_RESEARCH.md#open-research-questions). The most important:

1. Can addons write secure CVars out of combat on Forever?
2. Does `CVAR_UPDATE` fire for console and Blizzard-panel changes?
3. Does `ConsoleGetAllCommands()` list every CVar?
4. Forever limits for `cameraDistanceMaxZoomFactor`, `cameraZoomSpeed`, `nameplateMaxDistance` and `SpellQueueWindow`.

## Recommended next steps

1. Owner checks 0.2 in game and provides screenshots (main window, Details open, Preferences, a narrow window).
2. Post ChatGPT's safety review on #5 so it can be addressed before writable coverage grows.
3. Owner continues the in-game test plan (#1) and reports errors (BugSack output).
4. Fix in-game issues and record verification evidence in the definitions.
5. Milestone C database expansion, starting with Nameplates and Combat (spell queue, combat text), which players ask for most.
