# UI design

_Version 0.2 (UI refinement, issue #4)._ Real screenshots are in [screenshots/](screenshots/): `before-0.1-*` show 0.1.0 in game; 0.2 screenshots are pending.

## Direction

A neutral, professional settings application in the spirit of VS Code settings, Blender preferences, NVIDIA App and KDE System Settings. No faction theming, parchment, ornate borders, glows or oversized rows.

## What changed in 0.2, and why

| Problem seen in the 0.1 screenshots | Change |
|---|---|
| Text too small and thin (Arial Narrow) at common UI scales | Bundled **Inter** (Regular/Medium/SemiBold) with a type scale; secondary text contrast raised; independent **interface scale** (70–160%) |
| Descriptions cut off after a few words | Two-line descriptions, a list that widens when Details is closed, and a full-text tooltip when text is still truncated |
| Empty inspector took a quarter of the window | Details panel hidden by default, a labelled **Details** button, double-click to open, width adjustable by dragging its edge, choice remembered |
| Text-only sidebar | 16px monochrome category icons, right-aligned counts, separated groups, a stronger active state, optional hiding of empty categories |
| Thin slider, tiny square thumb | 6px track, round knob with a 24px hit area, hover state, units beside the edit box |
| Disabled Apply looked like dimmed teal | Disabled buttons share one neutral grey style; Apply shows the pending count ("Apply (3)"); the pending count is an amber pill |
| Modified and pending looked alike | Pending: amber bar plus PENDING badge. Modified from default: teal dot |

## Tokens (`UI/Themes/Theme.lua`)

| Token | Value | Use |
|---|---|---|
| window | #121315 | Window background |
| header / inspector | #18191c | Header, footer, Details |
| sidebar | #16171a | Navigation |
| content | #1b1c1f | Settings list |
| accent | #3aa7a3 (muted teal) | Primary action, active nav, toggle on, slider fill, focus ring, modified dot |
| text / textMuted / textDim / textDisabled | #eceef1 / #b0b5be / #7d828c / #61656c | Primary, secondary, tertiary, disabled |
| warning | #e0aa4a | Pending, restrictions, experimental |
| error | #e3615c | Invalid input, failures |

### Type scale (Inter; role → size/weight)

| Role | Size | Weight | Role | Size | Weight |
|---|---|---|---|---|---|
| pageTitle | 20 | SemiBold | settingName | 13 | Medium |
| windowTitle | 15 | SemiBold | settingDesc | 12 | Regular |
| groupHeader | 15 | SemiBold | input | 13 | Medium |
| sectionHeader | 13 | SemiBold | button | 12 | SemiBold |
| pageDesc / body / nav | 13 | Regular | meta / small / technical | 11 | Regular |
| overline | 10 | SemiBold | badge | 9 | SemiBold |

The CJK locales (koKR, zhCN, zhTW) fall back to the client's standard font; Inter covers Latin, Greek and Cyrillic.

### Icons

The 33 icons come from Lucide (ISC license), are rendered to 32×32 white TGAs by `tools/icons`, and are tinted at runtime. There are four shape textures: the slider/toggle knob, the toggle pill, the modified dot, and the rounded logo tile. The checkmark and window-resize grip still use Blizzard atlases.

## Layout

```
┌ [≡] EverSettings 0.2.0   Profile [No profile ▾] [Manage]    [🔍 Search settings…] [Details] ?  ✕ ┐ 52px
├──────────────────┬───────────────────────────────────────────────────┬────────────┤
│ LIBRARY          │ Graphics & Visuals             33 · 16 modified    │ (Details,  │
│ ☆ Favorites      │ Display, quality levels and rendering features.   │  optional, │
│ ◉ Modified       │ ⌄ Display  4                                       │  resizable)│
│ ⟲ Recent         │ ▌● ☆ Gamma                   ━━━●━━━━  [ 1.23 ]  ⟲ │            │
│ ≡ All Settings 86│      Controls the gamma of the game.                │            │
│ ─────────────    │      Vertical Sync                   Off (○──)     │            │
│ CATEGORIES       │      Synchronizes your framerate to some fraction…  │            │
│ ▣ Graphics    33 │                                                     │            │
│ ⌖ Camera      12 │                                                     │            │
├──────────────────┴───────────────────────────────────────────────────┴────────────┤
│ (3 pending changes)  status…            Undo  Redo   Discard  Reset category  [Apply (3)] │ 50px
└────────────────────────────────────────────────────────────────────────────────────┘
```

- **Window:** movable by the header and resizable from the bottom-right grip (minimum 860×520). Position, size, interface scale, Details visibility and Details width are saved. Escape closes it.
- **Responsive behaviour:** the search box shrinks from 340 to 180 px and the Manage button hides below 980 px. Setting controls use a wide tier (200 px slider) when the list is at least 760 px wide, otherwise a narrow tier (140 px). Every row uses the same tier, so widths stay consistent. The Details panel is 260–520 px and always leaves the list at least 440 px when the window allows it.
- **Rows (60 px):** pending bar, modified dot, favourite star (visible on hover or when favourited), name with optional technical name and up to three badges, a description of up to two lines, the control column, and a reset icon shown only when a reset would change something. Restricted settings show a lock icon and the reason in amber. Double-click opens Details.
- **Section headers (34 px):** chevron, label and count, with a hover state; collapsed state is remembered. Grouped views (All Settings, Favorites, Modified, Search) show the category icon.

## Controls

| Kind | Behaviour |
|---|---|
| Numeric | Slider (200/140 px, 6px track, round knob, 24px hit area) + 72 px edit box + unit column (%, ×, fps, °). Dragging updates the box live and stages on release; refreshes never hide, resize or reposition a slider mid-drag (confirmed in game; regression-tested). Exact typed values are kept; Enter confirms, Escape or clicking away cancels; invalid input gets a 2px red ring and a short message ("Allowed 0.3 to 2.8"). |
| Toggle | 40×20 pill with round knob; an "On" label in accent or an "Off" label in muted text; hover and disabled states |
| Dropdown | 28 px, as wide as slider plus edit box, chevron icon; accent border and chevron while open; disabled options explain why |
| Text input focus | 2px accent ring (1px hover ring) |
| Read-only | Value as text in the control column |

## EverSettings preferences (Tools › Preferences)

Interface scale (slider + edit box, 70–160%), Show Details panel, Show technical names, Hide empty categories, Reset window layout. They apply immediately and never touch game settings.

## Open design questions

- Real 0.2 screenshots are needed to validate spacing and contrast in game.
- Whether to add keyboard shortcuts (focusing search) without capturing game input.
- How to present extended ranges once one is researched (issue #3).
