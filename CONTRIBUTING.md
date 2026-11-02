# Contributing to OPORD

## Licence of contributions
OPORD's own code is **GPL-2.0-only** ("inbound = outbound"). Code inside the bundled soldier addons
(`addons/soldier`, `addons/soldier_module`) is **BSD-3-Clause**. By opening a pull request you confirm
you have the right to submit the code.

## Code from other projects
- **Allowed with notices kept:** GPLv2 and permissive licences such as BSD/MIT. Keep the original
  copyright line in the file header and add the source to `CREDITS.md`.
- **Never copy:** GPLv3 or AGPL code, APL-ND code, or code with no licence (this includes DCO UnitScanner,
  Tally's Vehicle FSM and PapaReap's headless-client code). Calling other mods' functions at runtime is fine.
- **Clean-room rule:** describe a behaviour in a short design note (plain words, real doctrine) before writing it.

## File headers
Every `.sqf`, `.hpp`, `.cpp` and `.inc` file outside the soldier addons starts with the OPORD header.
Check with `python tools/check_headers.py`.

## Code style
- Functions: `OPORD_fnc_<name>` in `addons/<addon>/functions/fn_<name>.sqf`, with a comment block saying what it
  does, its arguments and its return value.
- Every feature has CBA settings, an on/off switch, debug output prefixed `[OPORD]`, and checkpoint tests.

## Building
See `README.md`.
