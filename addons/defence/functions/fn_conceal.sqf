/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_conceal: camouflages a position.
      - POOK Camonets loaded: a 2-man (SMALL) or 3-man (MEDIUM) net over the position, in the
        terrain's pattern (OPORD_fnc_getCamoPattern), east/west style by side.
      - GRAD trench + DELIBERATE: GRAD's terrain camouflage (local bushes/grass) on the trench.

    Arguments: 0: Position ATL, 1: Facing deg, 2: Side, 3: "SMALL"|"MEDIUM", 4: Trench <OBJECT>,
               5: Terrain camo on trench <BOOL>
    Return: the net object or objNull
*/
params ["_pos", "_dir", "_side", ["_size", "SMALL"], ["_trench", objNull], ["_terrainCamo", false]];

if (_terrainCamo && {!isNull _trench} && {!isNil "grad_trenches_functions_fnc_applyCamouflageAttribute"}) then {
    if (isServer) then { [_trench, 1] call grad_trenches_functions_fnc_applyCamouflageAttribute; }
    else { [_trench, 1] remoteExecCall ["grad_trenches_functions_fnc_applyCamouflageAttribute", 2]; };
};

private _style = ["east", "west"] select (_side isEqualTo west);
private _base = format [["pook_ITEMcamonet_small_%1_drop", "pook_ITEMcamonet_med_%1_drop"] select (_size == "MEDIUM"), _style];
private _cls = _base + (call OPORD_fnc_getCamoPattern);
if !(isClass (configFile >> "CfgVehicles" >> _cls)) then { _cls = _base; };
if !(isClass (configFile >> "CfgVehicles" >> _cls)) exitWith { objNull };

private _p = +_pos; _p set [2, 0];
private _net = createVehicle [_cls, [0, 0, 0], [], 0, "CAN_COLLIDE"];
_net setDir _dir;
_net setPosATL _p;
_net setVectorUp (surfaceNormal _p);
_net setVariable ["OPORD_engineeringObject", true, true];
_net
