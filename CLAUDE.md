# CLAUDE.md

Instructions for Claude sessions working on EverSettings.

## Before each session

1. Check GitHub for new issues, comments and review instructions: `gh issue list --state open` and `gh issue view <n> --comments`.
2. Read `docs/CLAUDE_STATUS.md` (current state) and the issue's acceptance criteria.
3. Do not overwrite or disregard existing design decisions without recording why in `docs/ARCHITECTURE.md` (Decision log) or the relevant doc.

## Hard rules

- Target **WoW: Forever** only (interface 16001, build 1.60.1, codename Camelot). Never assume Retail or Classic behave the same: check `Gethe/wow-ui-source@forever` and the client dumps.
- Never invent ranges, allowed values or behaviour. Every slider needs `rangeSource`; every definition needs `sources` and per-aspect `verification`. Unknown numeric ranges get a read-only control.
- Never mark anything `verified` unless it was observed in game on Forever. A successful SetCVar is not proof of an effect.
- The addon must never write a setting without an explicit Apply by the player: nothing at load, login or discovery.
- Never write secure CVars in combat, bypass protected APIs, run console commands from profiles, or `loadstring` imported text.
- Unknown and unclassified CVars stay read-only.
- Avoid tainting Blizzard UI: use EverSettings' own frames (no StaticPopup, no Blizzard Menu, no Settings panel hooks).

## Workflow

- Run tests: `.\scripts\test.ps1` (or `.venv\Scripts\python -I tests\run_tests.py`). All tests must pass before committing.
- Deploy for in-game testing: `.\scripts\deploy.ps1` (or `-Mode link`).
- After changing definitions: `python tests/run_tests.py --coverage` to refresh `docs/COVERAGE.md`.
- After a game patch: `.\scripts\update_catalog.ps1`, then review `tools/database/out/catalog_report.json` and the in-game Diagnostics page.
- Keep `docs/CLAUDE_STATUS.md` current, keeping code implemented, offline tested and in-game verified clearly separate.
- Reference issues in commits (`Refs #12`, `Fixes #12`) and record in the status file how each requirement was addressed.
- Screenshots in `docs/screenshots/` must be of the real addon in game, never mockups.

## Code conventions

- Lua 5.1; every file starts with `local addonName, ns = ...` (or `local _, ns = ...`). No new globals beyond those listed in `tests/spec/zz_globals_spec.lua`.
- Settings are data in `Database/Definitions/*.lua`; the UI must not special-case individual settings.
- New provider behaviour goes in `Providers/` behind the provider interface documented in `Providers/Providers.lua`.
- Colors, fonts and metrics live in `UI/Themes/Theme.lua` only.
