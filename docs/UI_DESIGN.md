# UI design

## Direction

A neutral, professional settings application in the spirit of VS Code settings, Blender preferences, NVIDIA App and KDE System Settings. No faction theming, parchment, ornate borders, glows or oversized rows.

## Tokens (`UI/Themes/Theme.lua`)

| Token | Value | Use |
|---|---|---|
| window | #121315 | Window background |
| header / inspector | #18191c | Header, footer, inspector |
| sidebar | #16171a | Navigation |
| content | #1b1c1f | Settings list |
| section | #212226 | Subcategory headers, dialogs, popups |
| accent | #3aa7a3 (muted teal) | Primary button, active nav, toggle on, slider fill, modified indicator |
| text / textMuted / textDim | #e8eaed / #999ea8 / #6b707a | Primary, secondary, tertiary text |
| warning | #d9a441 | Pending changes, restrictions, experimental |
| error | #d9554f | Invalid input, failures |
| border | white at 7% | Thin 1px dividers |

Font: Arial Narrow (`Fonts\ARIALN.TTF`) at 9–18 px; the standard font for koKR, zhCN, zhTW and ruRU. Icons: Blizzard's monochrome `uitools-icon-*` atlases (close, chevrons, search, refresh, settings, resize) and `auctionhouse-icon-favorite`, tinted with theme colors. All of them were confirmed present in Forever's AtlasInfo.

## Layout

```
┌ EverSettings 0.1.0  Profile [▾ No profile] Profiles        [search…] ⚙ ⧉ ✕ ┐  header 46px (drag to move)
├──────────────┬──────────────────────────────────────────┬───────────────────┤
│ LIBRARY      │ Graphics & Visuals          24 · 2 · 1    │ Inspector         │
│  Favorites   │ Display, quality levels…                  │ name, technical   │
│  Modified    │ ▾ Display                         4       │ badges            │
│  Recent      │ ▌☆ Gamma  [====O------] [1.23] ⟳          │ description       │
│  All     86  │    Controls the gamma of the game.        │ VALUES            │
│ CATEGORIES   │  ☆ Vertical Sync                [On ●]  ⟳ │ VALID VALUES      │
│  Graphics 33 │ ▸ Textures                        3       │ BEHAVIOUR         │
│  Camera   12 │                                           │ VERIFICATION      │
│ TOOLS        │                                           │ SOURCES, RELATED  │
├──────────────┴──────────────────────────────────────────┴───────────────────┤
│ 1 pending change   status message…     Undo Redo  Discard  Reset category  [Apply] │ footer 46px
└──────────────────────────────────────────────────────────────────────────────┘
```

- Window: movable by the header, resizable with the bottom-right grip (minimum 900×540). Position, size and inspector state are saved. Escape closes it.
- Sidebar: Library (Favorites, Modified, Recently Changed, All Settings), the 14 categories (dimmed when empty) and Tools (CVar Browser, Profiles, Diagnostics).
- Rows are 52 px: favorite star, name with up to three badges (PENDING, status if not SOURCE, RESTART / RELOAD / GX RESTART, HIDDEN), a one-line description that turns into an error or restriction message when needed, the control area (300 px) and the reset button. A 3 px left bar shows amber for pending and teal for modified from default.
- Subcategories are collapsible, and the state is remembered.
- The inspector is optional. The main interface is fully usable without it.

## Controls

| Kind | Behaviour |
|---|---|
| Numeric | 168 px slider spanning exactly the researched range, plus a 64 px edit box. Dragging stages on-step values. Typing keeps the exact value. Enter confirms, Escape or clicking away cancels. Invalid input gets a red border and a message in the row, and keeps focus. The mouse wheel does not move sliders, to avoid accidental changes while scrolling. |
| Toggle | 36×18 switch with an On/Off label |
| Dropdown | Own popup list with checkmark, disabled unsupported options (tooltip gives the reason), warnings in amber, and non-selectable entries for "custom" states |
| Read-only | Current value as text, and the reason in the inspector |
| Restricted | The control is disabled and the description shows the reason (for example "Secure variable: cannot be changed during combat.") |

## Open design questions (for review)

- A monochrome category icon set (Forever has few suitable atlases; shipping custom TGA icons is an option).
- Whether to show the technical name in rows for advanced users (a toggle).
- A visual treatment for "extended range" sliders once any are researched.
- Screenshots of the working addon are needed for review (see `docs/screenshots/README.md`).
