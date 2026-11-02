# OPORD

Open-source AI framework for Arma 3 milsim. It makes AI fight like trained soldiers following real
doctrine, scaled by doctrine type and training level. **Status: 0.1.0-alpha, repository foundation.**
Not for live operations. Full README arrives with Phase 4 (see `docs/PLAN.md`).

**Licence:** GPL-2.0-only (`LICENSE`); the bundled soldier addons are BSD-3-Clause. Credits: `CREDITS.md`.

## Requirements
CBA_A3 and ACE3. Optional: GRAD Trenches, POOK Camonets, TerrainLib, IEDD. LAMBS Danger and VCOM AI are not
supported alongside OPORD. **Temporary:** the Workshop mod DCO UnitScanner must also be loaded (the bundled soldier layer
calls its functions; OPORD does not include it). Do not load the Workshop DCO Soldier FSM: OPORD bundles and
replaces it. This requirement goes away when OPORD's own replacement lands (`docs/PLAN.md`).

## Building
Install [HEMTT](https://github.com/BrettMayson/HEMTT), then from the repository root run `hemtt check`
and `hemtt build`. Output is in `.hemttout/build`. Never commit private signing keys.
