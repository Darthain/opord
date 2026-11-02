# ARTIC UAS System - v0.3 alpha

## Capability scan

ARTIC scans each unit for:

- UAV terminal in assigned items.
- Backpack with `assembleInfo >> assembleTo` resolving to a vehicle with `isUav = 1`.
- Crocus magazine items:
  - `Item_Crocus_AP`
  - `Item_Crocus_AT`
  - `Item_Crocus_AP_TI`
  - `Item_Crocus_AT_TI`
- Crocus AP/AT/TI UAV backpacks.

Group roles generated from the scan:

- `UAS_OPERATOR`
- `RECON_UAS`
- `FPV_AP`
- `FPV_AT`

Manual Role Override can still add any of these, or `UAS_MIXED`, to unusual modded drone teams.

## Recon mission

The Commander can autonomously request recon around its current Objective. ARTIC selects an available UAS provider in the same ORBAT, launches the assembled UAV class when one is detected (or a side-appropriate vanilla quadcopter for an explicitly tagged virtual RECON_UAS provider), flies it to the search area, performs a timed orbit/search, and reports line-of-sight enemy contacts.

Reported contacts are stored as recent UAS contacts in the Commander intelligence picture and are revealed to radio-capable ARTIC groups in that ORBAT.

## FPV strike mission

When recent UAS contacts exist, the Commander may request an AP or AT FPV strike according to target type and doctrine/training weighting. ARTIC selects a Crocus-equipped provider, consumes the selected Crocus item/backpack, creates the side-correct Crocus drone class, and flies a staging/final attack profile to the target.

Crocus itself remains responsible for the warhead effect on drone destruction/impact. ARTIC does not copy Crocus assets.

## Doctrine weights

Initial relative tendencies:

- Conventional: balanced recon and strike.
- Insurgent: strong FPV strike preference, moderate recon.
- Militia: limited recon and moderate strike.
- Recon: maximum ISR preference, conservative strike use.
- Positional: strong recon and strong strike around prepared areas.
- Special Forces: very strong recon and high strike preference.

Training changes UAS search radius, mission duration, approach quality and likelihood of employing the capability.

## Current alpha limitations

- Recon recovery is abstracted after the UAV returns near its operator.
- No battery/signal/repeater model yet.
- No grenade/mortar dropper mission yet.
- No swarm/multi-drone simultaneous attack yet.
- No EW/jamming/counter-UAS layer yet.
- UAS execution currently remains server-authoritative; HC transfer is planned after the first stable in-engine test.
