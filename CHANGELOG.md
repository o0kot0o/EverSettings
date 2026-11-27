# Changelog

## 0.2.1-alpha (fixes from the 0.2 in-game screenshots)

- Fixed: Details showed "Current —" and rows hid the modified dot for settings whose value is Off/false (a Lua `and/or` trap).
- Fixed: Preferences descriptions overlapped the next row (not top-aligned); page descriptions could run under the Details panel.
- Wider sidebar (labels no longer truncated); Manage button sized to its label.
- Max Camera Distance: an explicitly marked extended range up to 2.6, as observed in game (Blizzard's slider stops at 2.0). The slider shows a marker at 2.0 and amber beyond it, with a tooltip and an EXTENDED badge.
- Values set outside every researched range by another addon or the console get an OUT OF RANGE badge.
- 5 new regression tests (113 total).


## 0.2.0-alpha (UI refinement, issue #4)

- Typography: bundled Inter font with a type scale, higher-contrast secondary text, and an independent interface scale (70–160%).
- Details panel (inspector): hidden by default, a labelled Details button, double-click to open, adjustable width, preference remembered. Existing installs migrate once unless the player chose to show it.
- Sidebar: monochrome category icons, right-aligned counts, separated groups, a stronger active state, optional hiding of empty categories.
- Controls: thicker slider track, round knob with a larger hit area, unit labels (%, ×, fps, °), 2px focus rings, a redesigned toggle, consistent dropdowns, hover and disabled states.
- Rows: two-line descriptions, a full-text tooltip when truncated, optional technical names, a distinct pending bar versus modified dot, a favourite star on hover, and a reset icon only when useful.
- Header and footer: logo tile and version badge, profile selector with Manage, a larger responsive search box, Apply showing the pending count, and a neutral disabled style.
- New Preferences page; responsive layout tiers; 13 new layout tests (108 total).
- Fixes: slider drag (IsDraggingThumb, no hiding of the active control); compact range errors.


## 0.1.0-alpha (Milestone A, unreleased)

Foundation release. Offline tested; not yet verified in game.

- Unified settings provider architecture (CVar, composite, dedicated API, diagnostic).
- Generated catalog of 1,785 Forever CVars and 77 commands with Blizzard UI exposure classification.
- 86 curated setting definitions with sources, ranges and per-aspect verification evidence.
- Read-only runtime discovery (ConsoleGetAllCommands) with new/missing/changed-default detection.
- Main window: header (profile, search, help, inspector, close), sidebar, settings list, collapsible inspector and footer.
- Controls: synchronized slider plus edit box, toggle, dropdown, read-only values, individual reset.
- Staged changes with validation, dependency warnings, combat and restriction checks, read-back and result reports.
- External change detection (CVAR_UPDATE and polling of visible rows).
- Initial snapshot, original values, backups before profiles, selective restore, history, undo/redo.
- Profiles with comparison, selective category staging and validated import/export.
- Technical CVar browser (read-only) and Diagnostics page.
- Offline test harness (strict WoW mock driven by the Forever widget API dump) with 92 tests.
- Deployment, test and catalog update scripts.
