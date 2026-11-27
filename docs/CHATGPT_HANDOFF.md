# ChatGPT handoff

Where research, design or review from ChatGPT would help most. Please reply through GitHub issues: one issue per topic, with acceptance criteria. Claude reads open issues and comments before each session.

## Context in 60 seconds

- EverSettings is a WoW: Forever (interface 16001, build 1.60.1) settings manager. Milestone A is implemented and offline tested, not yet tested in game.
- Settings are data: `addon/EverSettings/Database/Definitions/*.lua`, schema in [SETTINGS_SCHEMA.md](SETTINGS_SCHEMA.md).
- Research rules: no invented ranges or values; every slider cites `rangeSource`; evidence is tracked per aspect (exists, values, write, persist, effect). See [SETTINGS_RESEARCH.md](SETTINGS_RESEARCH.md).
- Status: [CLAUDE_STATUS.md](CLAUDE_STATUS.md). Coverage: [COVERAGE.md](COVERAGE.md).

## 1. Research (highest value)

| Topic | What we need | Why |
|---|---|---|
| Secure CVars and addons on Forever | Whether `C_CVar.SetCVar` from addon code succeeds for secure CVars (`uiScale`, `autoStand`, `showTargetOfTarget`) out of combat, with evidence (Blizzard code paths, forum or wiki notes for 12.x/Forever) | Decides whether 81 secure variables can ever be editable |
| Hidden-variable ranges | Documented min/max/step with sources for `cameraZoomSpeed`, `cameraDistanceMaxZoomFactor` (Forever upper limit), `nameplateMaxDistance`, `SpellQueueWindow`, `farclip`, `maxFPS` above 200. Mark each source's client (Forever, Retail 12.x, Classic) | Unknown ranges stay read-only until researched |
| Next categories | A shortlist of 15–25 Nameplate, Combat and Targeting CVars present in Forever's catalog that are worth exposing, with labels, descriptions and value semantics from Blizzard's Forever code | Milestone C planning |
| CVAR_UPDATE coverage | Whether the event fires for `/console` changes and Blizzard settings-panel commits | External-change detection design |

## 2. UI and visual design review

- Review [UI_DESIGN.md](UI_DESIGN.md) and, once available, real screenshots in `docs/screenshots/`.
- Propose a small monochrome category icon set. Note that Forever's `uitools-icon-*` atlases are limited; propose either atlas names that exist in Forever's `AtlasInfo.lua` or a spec for custom 32×32 TGA icons.
- Row density, badge vocabulary (PENDING, EXPERIMENTAL, COMMUNITY, UNKNOWN, RESTART, HIDDEN), and how to present extended ranges.

## 3. Code review

Please review, in order of importance:
1. `Core/Changes.lua` (apply pipeline): validation, restriction checks, read-back classification, history/undo.
2. `Core/Sync.lua`: never overwriting external changes.
3. `Profiles/Serializer.lua` and `Profiles/Profiles.lua`: import hardening (no code execution, validation).
4. `Providers/CompositeProvider.lua`: faithfulness to Blizzard's proxy logic (graphics preset cascade in particular).
5. Taint risks in `UI/*` (own frames only, `UISpecialFrames` insertion, GameTooltip use).

## 4. Feature recommendations

- Which presets (Maximum Performance, Gathering, Dungeon & Raid, …) are worth building, with candidate values and the evidence needed before shipping them as recommendations.
- Whether a live preview is worth implementing for a small set of safe, instantly restorable settings (for example Gamma and Brightness).
