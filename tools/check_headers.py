#!/usr/bin/env python3
"""Every OPORD source file carries the GPL-2.0-only licence header.
The bundled soldier addons are BSD-3-Clause and are skipped (see SKIP_ADDONS).
Usage: python tools/check_headers.py   (exit code 1 lists files missing it)"""
import pathlib, sys
MARK = "SPDX-License-Identifier: GPL-2.0-only"
SKIP_ADDONS = {"soldier", "soldier_module"}
root = pathlib.Path(__file__).resolve().parent.parent / "addons"
missing = [p for p in root.rglob("*")
           if p.suffix in (".sqf", ".hpp", ".cpp", ".inc")
           and p.relative_to(root).parts[0] not in SKIP_ADDONS
           and MARK not in p.read_text(encoding="utf-8", errors="ignore")[:600]]
for p in missing: print("MISSING HEADER:", p.relative_to(root.parent))
print(f"{len(missing)} file(s) missing the header")
sys.exit(1 if missing else 0)
