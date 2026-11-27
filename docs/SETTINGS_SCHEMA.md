# Settings definition schema

Definitions are Lua tables registered in `addon/EverSettings/Database/Definitions/*.lua` with `ns.Registry:Define(def)` or `DefineGroup(common, defs)`. They are validated at login by `ns.Schema.Validate` (results in `/es diag`) and in the offline tests. A definition that fails validation is disabled.

## Fields

| Field | Required | Description |
|---|---|---|
| `id` | yes | Unique `category.name` identifier, stable across versions (used in profiles) |
| `name` | yes | Friendly display name |
| `description` | yes | One or two plain sentences. Shown truncated in the row, in full in the inspector |
| `category`, `subcategory` | yes | Primary location (see `Database/Categories.lua`) |
| `keywords` | no | Extra search terms |
| `technical` | no | Technical name shown in the inspector (derived from `cvar`/`cvars` if absent) |
| `provider` | yes | `cvar`, `composite`, `api`, `diagnostic` (`blizzard` reserved) |
| `cvar` | cvar | Console variable name (casing is normalised to the catalog's) |
| `composite` + `cvars` | composite | Handler name in `Providers/CompositeProvider.lua` and the CVars it touches (first is primary) |
| `api` | api | Handler name in `Providers/APIProvider.lua` |
| `diagnostic` | diagnostic | Handler name in `Providers/DiagnosticProvider.lua` |
| `control` | yes | `slider`, `toggle`, `dropdown`, `readonly` (`number`, `text` reserved) |
| `valueType` | yes | `number`, `integer`, `boolean`, `enum`, `string` |
| `min`, `max`, `step` | slider | Researched range and step |
| `rangeFunc` | slider (alternative) | Runtime range handler (`cameraFov`, `renderScale`) |
| `rangeSource` | slider | **Mandatory citation** of where the range comes from |
| `extendedRange` | no | `{ min, max, source }` for a documented range beyond the normal one; shown explicitly |
| `displayScale`, `displayOffset`, `suffix`, `decimals` | no | Display transform: shown = value × scale + offset (`uiScale` 0.65 shows as 65%; quality 0 shows as 1) |
| `options` | dropdown | `{ value, label, description?, warning?, notSelectable? }` list |
| `optionsFunc` | dropdown (alternative) | Dynamic options handler (`particleDensity`, `imageAA`) |
| `optionSupport` | no | `graphicsCVar` or `graphicsQuality`: disable options the client reports unsupported |
| `enumType` | no | `string` for string enums (default numeric) |
| `invert` | no | Boolean stored inverted (`deselectOnClick` shown as Sticky Targeting) |
| `onRaw`, `offRaw` | no | Raw strings for booleans (default `"1"`/`"0"`) |
| `defaultValue` | no | Canonical default when the client default does not apply (composites) |
| `scope` | derived | `account`, `character`, `machine`, `addon`, `unknown`, derived from catalog flags |
| `classification` | derived | `standard` (in Blizzard's settings window), `hidden`, `experimental` |
| `restrictions` | derived | `{ secure, combat }`; secure CVars are combat-restricted automatically |
| `dependencies` | no | `{ { id, value, reason } }`: warnings when unmet at apply time |
| `related` | no | Related setting ids (links in the inspector) |
| `apply` | no | `immediate` (default), `gxrestart`, `reload`, `restart` |
| `applyOrder` | no | Lower applies first (graphics preset is -10) |
| `isAvailable` | no | Function returning `ok, reason` for hardware or feature availability |
| `readOnlyReason` | readonly | Why it is read-only |
| `performance` | no | Performance implications |
| `sources` | yes | List of research sources with revision or build |
| `verification` | yes | Per-aspect evidence: `exists`, `values`, `write`, `persist`, `effect` with states `verified`, `source`, `community`, `experimental`, `unknown`, `unsupported` |
| `status` | no | Summary override; otherwise derived (unsupported, then verified effect, then experimental, then `values`) |

## Rules enforced by the validator

- A slider needs a numeric value type, a range (or `rangeFunc`), a positive step and `rangeSource`.
- A dropdown needs at least two options with unique values (or `optionsFunc`).
- A toggle needs `valueType = "boolean"`.
- Each provider's required fields must be present; categories and subcategories must exist.
- At least one source; known evidence aspects and states only.
- `status = "verified"` requires `verification.effect = "verified"`.
- CVars not found in the bundled catalog produce warnings.

## Example

```lua
{
	id = "graphics.gamma", category = "graphics", subcategory = "display", name = "Gamma",
	description = "Controls the gamma of the game.",
	provider = "cvar", cvar = "Gamma", control = "slider", valueType = "number",
	min = 0.3, max = 2.8, step = 0.1,
	rangeSource = "Graphics.lua CreateSliderOptions(.3, 2.8, .1); client help text 'Range: [0.3 - 2.8]'",
	sources = { "wow-ui-source@forever 1.60.1.71139 Blizzard_SettingsDefinitions_Shared/Graphics.lua (Gamma)" },
	verification = { exists = "source", values = "source", write = "source", persist = "unknown", effect = "source" },
}
```

## Generated catalog format

`Database/Generated/CVarCatalog.lua` sets `ns.CVarCatalog = { meta, cvars, commands }`.

- `cvars[name] = { default, consoleCategory, flags, exposure, help }`: flags bitmask 1 account, 2 character, 4 secure; exposure 2 settings window, 1 other Blizzard UI, 0 hidden.
- `commands[name] = { consoleCategory, help }`.
- `meta` records source revisions and builds.

## Profile text format

`!ES1;n=<name>;t=<unix time>;<id>=<tag><value>;...;#<checksum>`, with tags `b` (boolean), `n` (number) and `s` (string). Reserved characters and whitespace are percent-encoded, and an Adler-style checksum detects truncation. Imports are parsed by hand, never executed, and validated against the local definitions.
