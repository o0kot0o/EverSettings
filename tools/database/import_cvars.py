#!/usr/bin/env python3
"""
EverSettings CVar catalog importer.

Builds addon/EverSettings/Database/Generated/CVarCatalog.lua from:

  1. Ketho's BlizzardInterfaceResources `forever` branch `Resources/CVars.lua`
     (the client's own ConsoleGetAllCommands()/GetCVarInfo dump for Forever).
  2. Optionally, a checkout of Gethe/wow-ui-source `forever` branch, used to
     classify each CVar by how Blizzard's Forever UI uses it:

       2 = "settings"  referenced by a file in Blizzard's settings-definition
                       addons that the Forever client actually loads
       1 = "ui"        referenced by other Blizzard UI code that Forever loads
       0 = "hidden"    not referenced by any loaded Blizzard UI file

     Which files Forever loads is worked out from each addon's TOC, resolving
     [Family] -> Mainline, [Game] -> Camelot, and evaluating
     [AllowLoadGameType ...] / [ExcludeLoadGameType ...] for game type
     "camelot" (which is also a member of "mainline").

The importer never invents types, ranges or allowed values. It only records
facts present in the sources: default string, console category, storage
flags, help text and UI exposure.

Usage:
  python tools/database/import_cvars.py \
      --cvars tools/database/sources/CVars.forever.lua \
      --ui-source <path to wow-ui-source checkout> \
      --cvars-rev <git sha> --ui-rev <git sha> --build 1.60.1.71139
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT_LUA = ROOT / "addon" / "EverSettings" / "Database" / "Generated" / "CVarCatalog.lua"
OUT_DIR = ROOT / "tools" / "database" / "out"

VAR_RE = re.compile(
    r'^\s*\["((?:[^"\\]|\\.)+)"\]\s*=\s*\{"((?:[^"\\]|\\.)*)",\s*(\d+),\s*(true|false),\s*(true|false),\s*(true|false),\s*"((?:[^"\\]|\\.)*)"\},?\s*$'
)
CMD_RE = re.compile(r'^\s*\["((?:[^"\\]|\\.)+)"\]\s*=\s*\{(\d+),\s*"((?:[^"\\]|\\.)*)"\},?\s*$')

CONSOLE_CATEGORY = {
    0: "Debug", 1: "Graphics", 2: "Console", 3: "Combat", 4: "Game", 5: "Default",
    6: "Net", 7: "Sound", 8: "Gm", 9: "Reveal", 10: "None",
}

SETTINGS_ADDONS = {
    "Blizzard_SettingsDefinitions_Frame",
    "Blizzard_SettingsDefinitions_Shared",
    "Blizzard_Settings_Shared",
    "Blizzard_Settings",
}

GAME_TYPE = "camelot"
GAME_TYPE_MEMBERSHIP = {"camelot", "mainline"}  # Forever matches both


def unescape_lua(s: str) -> str:
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def parse_cvars(path: Path):
    """Return (vars, commands, ptr_vars, ptr_commands) dicts from Ketho's CVars.lua."""
    vars_, cmds, ptr_vars, ptr_cmds = {}, {}, {}, {}
    section = None  # ("main"|"ptr", "var"|"command")
    block = "main"
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if line.startswith("local PTR"):
            block = "ptr"
            continue
        m = re.match(r"^\s*(var|command)\s*=\s*\{\s*$", line)
        if m:
            section = m.group(1)
            continue
        if section == "var":
            vm = VAR_RE.match(line)
            if vm:
                name, default, cat, acct, char, secure, help_ = vm.groups()
                entry = {
                    "default": unescape_lua(default),
                    "category": int(cat),
                    "account": acct == "true",
                    "character": char == "true",
                    "secure": secure == "true",
                    "help": unescape_lua(help_),
                }
                (vars_ if block == "main" else ptr_vars)[unescape_lua(name)] = entry
        elif section == "command":
            cm = CMD_RE.match(line)
            if cm:
                name, cat, help_ = cm.groups()
                (cmds if block == "main" else ptr_cmds)[unescape_lua(name)] = {
                    "category": int(cat), "help": unescape_lua(help_)}
    return vars_, cmds, ptr_vars, ptr_cmds


# --------------------------------------------------------------------------
# TOC evaluation for the Forever client
# --------------------------------------------------------------------------
COND_RE = re.compile(r"\[(AllowLoadGameType|ExcludeLoadGameType|AllowLoad|ExcludeLoad|AllowLoadTextLocale|ExcludeLoadTextLocale)\s+([^\]]*)\]")


def toc_loaded_files(addon_dir: Path):
    """Return list of file paths (relative to the AddOns dir) Forever loads for this addon."""
    tocs = sorted(addon_dir.glob("*.toc"))
    if not tocs:
        return []
    # Prefer _Camelot, then _Mainline, then plain, mirroring suffix precedence.
    by_name = {t.name.lower(): t for t in tocs}
    base = addon_dir.name.lower()
    toc = by_name.get(f"{base}_camelot.toc") or by_name.get(f"{base}_mainline.toc") or by_name.get(f"{base}.toc") or tocs[0]
    files = []
    for raw in toc.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        conds = COND_RE.findall(line)
        path = COND_RE.sub("", line).strip()
        if not path:
            continue
        ok = True
        for kind, value in conds:
            items = {v.strip().lower() for v in value.split(",") if v.strip()}
            if kind == "AllowLoadGameType" and not (items & GAME_TYPE_MEMBERSHIP):
                ok = False
            if kind == "ExcludeLoadGameType" and (items & GAME_TYPE_MEMBERSHIP):
                ok = False
        if not ok:
            continue
        path = path.replace("[Family]", "Mainline").replace("[Game]", "Camelot").replace("\\", "/")
        if "[" in path:
            continue  # unknown variable, skip conservatively
        files.append((addon_dir / path))
    expanded = []
    for f in files:
        if f.suffix.lower() == ".xml" and f.exists():
            expanded.append(f)
            # XML files include scripts/other XML. Follow <Script file=""/> and <Include file=""/>.
            try:
                text = f.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for inc in re.findall(r'<(?:Script|Include)\s+file="([^"]+)"', text):
                expanded.append((f.parent / inc.replace("\\", "/")))
        else:
            expanded.append(f)
    return [p for p in expanded if p.exists()]


def scan_ui_source(ui_root: Path, cvar_names):
    addons_dir = ui_root / "Interface" / "AddOns"
    lookup = set(cvar_names)
    lower_map = {n.lower(): n for n in cvar_names}
    literal = re.compile(r'"([A-Za-z_][A-Za-z0-9_]{2,})"')
    exposure = {}
    refs = {}
    loaded_count = 0
    for addon_dir in sorted(p for p in addons_dir.iterdir() if p.is_dir()):
        files = toc_loaded_files(addon_dir)
        is_settings = addon_dir.name in SETTINGS_ADDONS
        for f in files:
            loaded_count += 1
            try:
                text = f.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for lineno, line in enumerate(text.splitlines(), 1):
                s = line.lstrip()
                if s.startswith("--"):
                    continue
                for m in literal.finditer(line):
                    tok = m.group(1)
                    name = tok if tok in lookup else lower_map.get(tok.lower())
                    if not name:
                        continue
                    level = 2 if is_settings else 1
                    if level > exposure.get(name, 0):
                        exposure[name] = level
                    lst = refs.setdefault(name, [])
                    if len(lst) < 3:
                        rel = f.relative_to(addons_dir).as_posix()
                        lst.append(f"{rel}:{lineno}")
    return exposure, refs, loaded_count


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------
def lua_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "") + '"'


def write_lua(vars_, cmds, exposure, meta):
    lines = [
        "-- GENERATED FILE. Do not edit by hand.",
        "-- Produced by tools/database/import_cvars.py",
        f"-- CVar source: Ketho/BlizzardInterfaceResources@forever {meta['cvarsRevision']} (client build {meta['cvarsBuild']})",
        f"-- UI source:   Gethe/wow-ui-source@forever {meta['uiRevision']} (build {meta['uiBuild']})",
        "--",
        "-- Each CVar entry: { default, consoleCategory, flags, exposure, help }",
        "--   flags bitmask: 1 = stored server-side per account, 2 = per character, 4 = secure",
        "--   exposure: 2 = used by Blizzard's Forever settings window, 1 = used by other Blizzard UI, 0 = hidden",
        "-- Commands are console commands, not variables: { consoleCategory, help }",
        "",
        "local _, ns = ...",
        "ns.CVarCatalog = {",
        "\tmeta = {",
    ]
    for k in sorted(meta):
        v = meta[k]
        lines.append(f"\t\t{k} = {lua_str(str(v)) if not isinstance(v, (int, float)) else v},")
    lines.append("\t},")
    lines.append("\tcvars = {")
    for name in sorted(vars_, key=str.lower):
        e = vars_[name]
        flags = (1 if e["account"] else 0) | (2 if e["character"] else 0) | (4 if e["secure"] else 0)
        lines.append(
            f"\t\t[{lua_str(name)}] = {{{lua_str(e['default'])}, {e['category']}, {flags}, {exposure.get(name, 0)}, {lua_str(e['help'])}}},"
        )
    lines.append("\t},")
    lines.append("\tcommands = {")
    for name in sorted(cmds, key=str.lower):
        c = cmds[name]
        lines.append(f"\t\t[{lua_str(name)}] = {{{c['category']}, {lua_str(c['help'])}}},")
    lines.append("\t},")
    lines.append("}")
    OUT_LUA.parent.mkdir(parents=True, exist_ok=True)
    OUT_LUA.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cvars", type=Path, default=ROOT / "tools/database/sources/CVars.forever.lua")
    ap.add_argument("--ui-source", type=Path, default=None, help="Path to a wow-ui-source checkout (forever branch)")
    ap.add_argument("--cvars-rev", default="unknown")
    ap.add_argument("--cvars-build", default="unknown")
    ap.add_argument("--ui-rev", default="unknown")
    ap.add_argument("--ui-build", default="unknown")
    args = ap.parse_args(argv)

    vars_, cmds, ptr_vars, ptr_cmds = parse_cvars(args.cvars)
    if len(vars_) < 500:
        print(f"error: parsed only {len(vars_)} CVars; source format may have changed", file=sys.stderr)
        return 2

    exposure, refs, loaded = {}, {}, 0
    if args.ui_source:
        exposure, refs, loaded = scan_ui_source(args.ui_source, list(vars_))

    meta = {
        "cvarsRevision": args.cvars_rev,
        "cvarsBuild": args.cvars_build,
        "uiRevision": args.ui_rev,
        "uiBuild": args.ui_build,
        "generated": _dt.date.today().isoformat(),
        "numCVars": len(vars_),
        "numCommands": len(cmds),
    }
    write_lua(vars_, cmds, exposure, meta)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    counts = {0: 0, 1: 0, 2: 0}
    for n in vars_:
        counts[exposure.get(n, 0)] += 1
    by_cat = {}
    for n, e in vars_.items():
        by_cat[CONSOLE_CATEGORY.get(e["category"], str(e["category"]))] = by_cat.get(CONSOLE_CATEGORY.get(e["category"], str(e["category"])), 0) + 1
    report = {
        "meta": meta,
        "loadedUiFilesScanned": loaded,
        "exposure": {"settings": counts[2], "ui": counts[1], "hidden": counts[0]},
        "secure": sum(1 for e in vars_.values() if e["secure"]),
        "account": sum(1 for e in vars_.values() if e["account"]),
        "character": sum(1 for e in vars_.values() if e["character"]),
        "byConsoleCategory": dict(sorted(by_cat.items())),
        "ptrOnlyVarsExcluded": sorted(ptr_vars),
        "settingsWindowCVars": sorted((n for n in vars_ if exposure.get(n) == 2), key=str.lower),
        "references": {n: refs[n] for n in sorted(refs, key=str.lower)},
    }
    (OUT_DIR / "catalog_report.json").write_text(json.dumps(report, indent=1), encoding="utf-8", newline="\n")
    print(f"CVars: {len(vars_)}  commands: {len(cmds)}  (PTR-only excluded: {len(ptr_vars)} vars, {len(ptr_cmds)} cmds)")
    print(f"Exposure: settings={counts[2]} ui={counts[1]} hidden={counts[0]}  (UI files scanned: {loaded})")
    print(f"Wrote {OUT_LUA.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
