# ARTIC AI Architecture v0.1

## Command hierarchy

```text
Commander / HQ
    |
    +-- Formation (Battalion/Company/Platoon)
            |
            +-- child Formation(s)
            |       |
            |       +-- groups
            |
            +-- directly attached groups

Commander intent
    -> Formation distribution
        -> Group order
            -> Local tactical plan (server/HC owner)
                -> Element / individual commands
```

Higher layers define **intent**. Lower layers may choose execution details but must not contradict the higher intent.

## Shared behavioural model

Every ARTIC-controlled group carries:

- Doctrine: what tactical methods the force prefers.
- Training: how competently it can execute those methods.
- Morale: reserved for the next iteration; willingness/cohesion.
- Commander/formation identity.
- Current command intent.
- Current tactical plan.
- Capability scan (MG, grenadier, AT, medic, engineer, radio, vehicles and roles).

## Commander layer

The server owns:

- Commanders
- ORBAT
- Sites
- Objectives
- AO / frontline reference
- Support allocations
- Site control state

The tactical planner runs on the machine that locally owns the group. This is intentionally Headless Client compatible.

## Why no RHQ-style master class list

ARTIC scans the actual group/vehicle configuration and equipment. A unit may hold several capabilities simultaneously. Mission makers can use the Role Override module for unusual assets that the scanner cannot classify correctly.

## Battlefield preparation

`PREPARE_BATTLE_POSITION` is designed as the base for future engineering doctrine. v0.1 sites weapon/fighting positions and can create GRAD trenches/camouflage when those mods are loaded. Later revisions will add mine/IED/obstacle belts, safe lanes, dummy positions and depth.


## UAS layer (v0.3)

UAS is a commander support capability rather than an independent tactical brain. The server commander creates RECON/FPV requests; providers are selected from the commander's ORBAT or explicitly synchronized Support Assets. Recon results enter the same commander intelligence picture used by ground formations. Autonomous FPV strikes are only selected from recent UAS-reported contacts, preserving a basic sensor-to-shooter chain.

The Crocus integration is runtime-only: ARTIC detects its classes/items when present but does not require or redistribute the Crocus PBO.

## v0.3.16 movement ownership rule
Moving infantry should have one authoritative spatial chain:

`PLATOON PLAN -> SECTION GUIDE -> DESIRED FIRETEAM GUIDES -> SOLDIER FORMATION SLOT`

Immediate danger reactions can temporarily override an individual slot. When the reaction ends the soldier returns to that same hierarchy.

Legacy `ARTIC_sectionAnchor` / `ARTIC_fireteamAnchor*` and `moveElement` remain registered only for older standalone tactics/compatibility during the transition. They are not the primary movement reference for the platoon battlefield benchmark. New tactics should be written against section/fireteam guides and generic element capabilities.
