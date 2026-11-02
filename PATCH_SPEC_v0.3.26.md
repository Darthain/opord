# ARTIC AI v0.3.26-alpha patch specification

## Scope
Attack authorisation only. No deliberate weapon-employment changes.

## Root cause from 0.3.25 benchmark
- UAS found 15 contacts and the force ratio was favourable (~2.64).
- `fn_generateBattleCOAs` repeatedly produced 0-25% single-anchor sight.
- `ARTIC_minSbfSight = 0.4` made every COA invalid.
- `fn_buildBattleContext` forced `HOLD_FOR_FIRE_POSITION`, so `fn_platoonMovementStep`
  correctly refused tactical release.

## Implementation
1. New `ARTIC_fnc_evaluateSbfFireLine` samples five representative FIX-line points.
2. Union enemy visibility across the line becomes the primary SBF feasibility metric.
3. STANDARD SBF: >=25% aggregate coverage and >=2 useful points.
4. Preferred SBF: >=40% aggregate coverage; receives a COA score bonus.
5. LIMITED SBF: >=12.5% aggregate coverage and >=1 useful point.
6. LIMITED is accepted only after one failed plan review, when the normal battlefield
   assessment still allows assault and force ratio >=1.15.
7. Context/debug state records fire-line coverage, useful points, mode and failure count.
8. Existing force-ratio, anti-armour and support vetoes remain authoritative.

## Deliberately deferred
- Explicit rifle `doFire` behaviour.
- MG suppression reliability changes.
- AT fire-command changes.
- Fire-control cadence/target allocation changes.

Those should be tested after this build proves that the planner actually releases the attack.
