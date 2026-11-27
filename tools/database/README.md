# Database tools

## import_cvars.py

Generates `addon/EverSettings/Database/Generated/CVarCatalog.lua` and `tools/database/out/catalog_report.json`.

```powershell
# Usually run through the wrapper, which fetches the sources and records revisions:
.\scripts\update_catalog.ps1

# Manual run:
python tools/database/import_cvars.py --cvars tools/database/sources/CVars.forever.lua `
    --ui-source <wow-ui-source checkout on the forever branch> `
    --cvars-rev <sha> --cvars-build 1.60.1.70938 --ui-rev <sha> --ui-build 1.60.1.71139
```

What it does:
1. Parses Ketho's `Resources/CVars.lua` (main `var`/`command` tables; PTR-only tables are excluded).
2. Optionally evaluates every Blizzard addon TOC as the Forever client would (`[Family]` becomes Mainline, `[Game]` becomes Camelot, game type `camelot`/`mainline`), follows XML includes, and classifies each CVar by where Blizzard's loaded Forever UI references it: settings window (2), other UI (1) or hidden (0).
3. Writes the Lua catalog with the source revisions and builds in `meta`, plus a JSON report (counts, settings-window list, up to 3 references per CVar).

It never invents types or ranges: only defaults, flags, categories, help text and exposure are recorded.

## sources/

`CVars.forever.lua` is a pinned copy of Ketho/BlizzardInterfaceResources `forever` branch `Resources/CVars.lua` at `e230342` (build 1.60.1.70938), kept so the catalog can be rebuilt reproducibly. `update_catalog.ps1` refreshes it.

## Validation

Definition validation runs in game (`/es diag`) and offline (`tests/spec/schema_spec.lua`). `python tests/run_tests.py --coverage` writes `docs/COVERAGE.md`.
