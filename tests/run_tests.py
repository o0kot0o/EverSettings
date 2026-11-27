#!/usr/bin/env python3
"""
Offline test runner for EverSettings.

Loads tests/wowmock.lua (a strict WoW API mock built from the Forever client's widget API
dump), loads every file listed in addon/EverSettings/EverSettings.toc in order exactly as
the client would (each chunk receives addonName, ns), fires ADDON_LOADED and PLAYER_LOGIN,
then runs every tests/spec/*_spec.lua file.

Requires: pip install lupa   (provides a Lua 5.1 runtime, matching WoW's Lua version)
Usage:    python tests/run_tests.py [-v] [filter]
"""
from __future__ import annotations

import re
import sys
import time
from pathlib import Path

try:
    import lupa.lua51 as lupa
except ImportError:  # pragma: no cover
    print("lupa is required: pip install lupa", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon" / "EverSettings"
TESTS = ROOT / "tests"


def toc_files():
    files = []
    for line in (ADDON / "EverSettings.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        files.append(line.replace("\\", "/"))
    return files


def posix(p: Path) -> str:
    return p.as_posix()


def main(argv):
    verbose = "-v" in argv
    filters = [a for a in argv if not a.startswith("-")]
    rt = lupa.LuaRuntime(unpack_returned_tuples=True)
    rt.execute(f"MOCK_DATA_DIR = [[{posix(TESTS / 'data')}]]")
    rt.execute(f"dofile([[{posix(TESTS / 'wowmock.lua')}]])")
    loader = rt.eval(
        "function(path, name, ns) local f, err = loadfile(path); if not f then error(err, 0) end; return f(name, ns) end"
    )

    # Seed mock CVars from the bundled catalog before the addon loads.
    seed_ns = rt.table()
    loader(posix(ADDON / "Database/Generated/CVarCatalog.lua"), "EverSettings", seed_ns)
    rt.globals().MOCK.SeedCVars(seed_ns.CVarCatalog)

    rt.execute("PRE_GLOBALS = {}; for k in pairs(_G) do PRE_GLOBALS[k] = true end")
    ns = rt.table()
    t0 = time.perf_counter()
    for rel in toc_files():
        loader(posix(ADDON / rel), "EverSettings", ns)
    load_ms = (time.perf_counter() - t0) * 1000
    rt.globals().ES_NS = ns
    rt.globals().ES_FILES = rt.table(*[posix(ADDON / rel) for rel in toc_files()])
    rt.globals().ES_LOAD_MS = load_ms

    # Boot like the client does.
    rt.execute("MOCK.FireEvent('ADDON_LOADED', 'EverSettings'); MOCK.FireEvent('PLAYER_LOGIN'); MOCK.RunTimers()")
    # Record what happened during boot before any test resets state.
    rt.execute("BOOT_WRITES = #MOCK.setLog; BOOT_PRINTED = {}; for i, p in ipairs(MOCK.printed) do BOOT_PRINTED[i] = p end")

    if "--coverage" in argv:
        md = rt.execute(f"return dofile([[{posix(TESTS / 'coverage.lua')}]])")
        out = ROOT / "docs" / "COVERAGE.md"
        out.write_text(md, encoding="utf-8", newline="\n")
        print(f"Wrote {out.relative_to(ROOT)}")

    rt.execute(f"dofile([[{posix(TESTS / 'spec_helper.lua')}]])")
    specs = sorted((TESTS / "spec").glob("*_spec.lua"))
    for spec in specs:
        if filters and not any(f in spec.name for f in filters):
            continue
        rt.globals().SPEC_FILE = spec.name
        loader(posix(spec), "EverSettings", ns)

    results = rt.globals().SPEC_RESULTS
    passed = failed = 0
    failures = []
    for i in range(1, len(results) + 1):
        r = results[i]
        if r.ok:
            passed += 1
            if verbose:
                print(f"  ok    {r.file} :: {r.name}")
        else:
            failed += 1
            failures.append((r.file, r.name, r.err))
            print(f"  FAIL  {r.file} :: {r.name}\n        {r.err}")
    print(f"\n{passed} passed, {failed} failed  (addon load {load_ms:.1f} ms)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
