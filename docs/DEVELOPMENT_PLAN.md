# Development plan

## Milestone A: Foundation (implemented, offline tested, awaiting in-game verification)

Repository, scripts, Forever API research, CVar importer, schema, runtime discovery, provider system, main window, navigation, search, numeric slider plus edit box, toggle and dropdown controls, reset, staged changes and safe apply, initial backup, representative Graphics/Camera/QoL settings, diagnostics, tests and docs.

**Exit criteria still open:** in-game verification of the acceptance list in `CLAUDE_STATUS.md` and screenshots of the working addon.

## Milestone B: In-game verification and hardening

- Run the in-game test plan (`TEST_RESULTS.md`, section "In-game test plan") and record evidence per aspect.
- Answer research questions 1–3 and 7 in `SETTINGS_RESEARCH.md` (secure writes, discovery completeness, CVAR_UPDATE coverage, persistence).
- Fix anything found in game; add regression tests to the mock.
- Commit real screenshots.

## Milestone C: Database expansion

- Nameplates & Unit Frames, Combat (combat text, spell queue, auto-attack), Targeting (soft targeting), Audio, Interface (action bars, chat), Accessibility, Network, Controls.
- Display mode and resolution via `C_VideoOptions` (with care), full anti-aliasing composite (`MSAAQuality`/`msaaAlphaTest`), raid graphics settings (`raidGraphics*` with `RAIDsettingsEnabled`).
- Researched hidden variables with documented ranges (camera zoom speed, nameplate distance) once verified.

## Milestone D: Profiles and presets

- Profile preview polish, per-setting selection in addition to categories.
- Candidate presets (Maximum Visuals, Balanced, Maximum Performance, Solo Leveling, Gathering, Dungeon & Raid, PvP, Cinematic) shipped only after in-game testing; untested presets stay unpublished.

## Milestone E: UX polish

- Category icons, keyboard navigation, live preview for researched safe settings, localisation, an option to show technical names in rows.

## Milestone F: Maintenance tooling

- Per-patch catalog diff report, CI running the offline tests on pull requests, a release packaging script.
