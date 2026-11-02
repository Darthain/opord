# First Eden Test Scenario - v0.3

Use a small map area and one OPFOR company/platoon. This first test is intended to verify ORBAT, commander intent, tactical handoff and support allocation before adding more behaviour.

## 1. Load mods

Required:
- CBA_A3
- ARTIC AI packed from this source

Optional for the engineering test:
- Gruppe Adler Trenches
- Pook Camonets

Optional for FPV testing:
- FPV Drone Crocus

Do **not** use another AI movement/commander mod on the same benchmark groups. ARTIC v0.3.17 contains no runtime LAMBS/DCO/NR6/SoldierFSM integration or compatibility variables; use those mods only in separate A/B reference tests.

## 2. Place Core module

Modules > ARTIC AI > **Core / Debug Settings**

Set:
- Debug Logging = Yes
- Debug Chat = Yes
- Debug Map Markers = Yes

## 3. Build a minimal ORBAT

Place:
- 1 x Commander
- 1 x Company Formation
- 3 x Platoon Formation
- 2-3 infantry groups under each platoon (you can begin with only one platoon if desired)

Example:

```text
Commander EAST_1BN
  |
  +-- B Company
       |
       +-- B1 Platoon
       |     +-- group B1-1
       |     +-- group B1-2
       |     +-- group B1-3
       |
       +-- B2 Platoon
       +-- B3 Platoon
```

Synchronization:
- Commander -> Company Formation
- Company Formation -> each Platoon Formation
- Platoon Formation -> one unit in each subordinate group

The lowest formation can also be synchronized directly to vehicles/groups.

Recommended first profile:
- Commander Doctrine = Conventional
- Commander Training = Veteran
- Formation overrides = Inherit

## 4. Add AO and frontline reference

Place **Area of Operations** near the fight, radius 2000-4000 m, and synchronize it to the Commander.

Place **Frontline Reference** on the approximate current front. Direction is friendly-to-enemy. Synchronize it to the Commander. In v0.1 this is primarily a reference/debug object; later builds will generate a dynamic front from controlled sites.

## 5. Add Objective

Place an Objective module on a town/strongpoint.

For attack test:
- Type = Capture / Attack
- Priority = 80
- Radius = 200

Synchronize Objective -> Commander.

For defence test, switch it to Defend and start the ARTIC force near the objective.

## 6. Add Site

Place a Site module on the same town.
- Site Type = Town / Settlement or Strongpoint
- Strategic Value = 70
- Defensibility = 0.7
- Radius = 200

Synchronize Site -> Commander.

## 7. Add support asset

Place a mortar or artillery vehicle with crew.
Place **Support Asset** module next to it.
- Role = Mortar or Artillery
- Default rounds = 4

Synchronize:
- Support Asset -> artillery/mortar vehicle
- Support Asset -> Commander

The commander support manager will service group requests using `doArtilleryFire` when usable artillery ammunition is detected.

## 8. Optional manual role override

For a modded vehicle ARTIC misclassifies:
- Place **Capability / Role Override**
- Set `Roles` to comma-separated values without spaces, e.g. `ARTILLERY,TRANSPORT`
- Synchronize it to the vehicle or a unit in the group.

## What to watch for

RPT/system chat should show:

```text
[ARTIC][EAST_1BN] Registered commander...
[ARTIC][EAST_1BN] ORBAT rebuilt...
[ARTIC][EAST_1BN] Assigned ATTACK/DEFEND...
[ARTIC][O Alpha ...] SUPPRESS_AND_FLANK...
[ARTIC][O Alpha ...] FIGHTING_WITHDRAWAL...
```

In a DEFEND test, groups that reach the objective should begin `PREPARE_BATTLE_POSITION`; if GRAD Trenches is loaded, ARTIC uses GRAD envelope classes, otherwise vanilla bag-fence positions are created.

## Recommended first three tests

1. **ORBAT/attack**: verify commander intent reaches the correct subordinate groups.
2. **Defence construction**: verify groups move into the objective and create/occupy positions.
3. **Support**: manually force a group support request in debug console if necessary:

```sqf
[group cursorObject, cursorTarget, "HE"] call ARTIC_fnc_requestSupport;
```

For smoke:

```sqf
[group cursorObject, cursorTarget, "SMOKE"] call ARTIC_fnc_requestSupport;
```


## 9. UAS / Crocus test

### Recon provider

Put a UAV operator group inside the ARTIC ORBAT. Give one member a UAV terminal and a backpack that assembles into a UAV (for example a vanilla quadcopter backpack). ARTIC should detect `UAS_OPERATOR` and `RECON_UAS`.

Alternatively, synchronize **Capability / Role Override** to a unit in the group and set `Roles` to `RECON_UAS`. That uses a side-appropriate vanilla quadcopter as a virtual test asset.

### Crocus FPV provider

With FPV Drone Crocus loaded, give an AI operator one or more Crocus drone items/backpacks. ARTIC scans AP, AT and thermal variants automatically. No Crocus classname needs to be entered into ARTIC.

For a manual provider, Role Override can use `FPV_AP`, `FPV_AT` or `UAS_MIXED`. The Crocus mod must still be loaded for the actual FPV vehicle class to exist.

### Commander settings

On the Commander module:

- Automatic UAS Employment = Yes
- Recon UAS Cooldown = 60 for a fast test
- FPV Strike Cooldown = 45 for a fast test

Use a RECON, ATTACK, RAID or SCREEN objective near the player force. Expected debug flow:

```text
[ARTIC][EAST_1BN] UAS request RECON ...
[ARTIC][EAST_1BN] UAS reported N contact(s)
[ARTIC][EAST_1BN] UAS request FPV_AP/FPV_AT ...
[ARTIC][EAST_1BN] FPV_AP/FPV_AT mission completed ...
```

The autonomous strike selector only uses recent UAS-reported contacts in this alpha, so a successful recon pass should precede an automatic FPV strike.
