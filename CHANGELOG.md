# Changelog

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
