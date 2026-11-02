# OPORD — rules for Claude Code sessions

OPORD is an open-source (GPL-2.0-only) Arma 3 milsim AI framework. It replaces NR6 HAL and LAFS, with a
maintained fork of DCO Soldier FSM as the soldier brain. Public from the start.

## Hard rules
1. **Licensing.** OPORD code is GPL-2.0-only with the SPDX header (see `addons/main/config.cpp`). The soldier
   addons (`addons/soldier`, `addons/soldier_module`) stay BSD-3-Clause: keep existing headers exactly; new files
   there are BSD-3, "Copyright (C) 2026 OPORD contributors". Never copy or read code from sources without a
   licence: DCO UnitScanner, Tally's Vehicle FSM, PapaReap's headless-client code. Write new code from
   behaviour descriptions.
2. **Naming.** Never use "DCO", "Dragon Company" or any author's name in OPORD's name, mod title or promotion.
   Credit them in `CREDITS.md` and `SOURCE.md` only.
3. **Behaviour parity.** Do not change soldier or defence behaviour unless a task says so. Known bugs are
   listed in `docs/PLAN.md` ("After parity").
4. External source folders are read-only. Do not modify them.
5. **No publishing.** Never create a GitHub remote, push or publish without asking.
6. Small commits, one logical change each, clear messages.
7. If a task does not match what you find, stop and ask rather than guess.

## Layer model (bottom to top)
Soldier → Section → Platoon → Defence and engineering → Commander → Vehicles (core) → Support → Information network.

## Conventions
- HEMTT project (`.hemtt/project.toml`), mod prefix `opord`; build with `hemtt check` / `hemtt build`.
- Function tag `OPORD`; functions `OPORD_fnc_<name>` in `addons/<addon>/functions/fn_<name>.sqf`, with a comment
  block (what, arguments, return). Lowercase paths only (CI is case-sensitive).
- Every feature has CBA settings, an on/off switch, debug output prefixed `[OPORD]`, and checkpoint tests.
- Every OPORD `.sqf/.hpp/.cpp/.inc` starts with the GPL header; check with `python tools/check_headers.py`.
- Never order a soldier the soldier layer marks as busy.
- SQF files use LF line endings.
