/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_trenchFipo: places an UNASSIGNED DCO fighting position in a trench, unless another
    fighting position is already within 3 m (e.g. a soldier's primary position) or the line's cap
    is reached. Unassigned positions are DCO's stepping stones: a threatened soldier dodges to the
    nearest one, and DCO seats free soldiers (reinforcements, replacements) in them.

    Arguments: 0: Position ATL, 1: Facing deg, 2: Side, 3: Dynamic <BOOL>, 4: Line id,
               5: [coverStance, shootingStance] (DCO scale: 1 prone, 3 crouch-low, 4 crouch, 6 stand-low, 7 stand)
    Return: the position or objNull
*/
params ["_pos", "_dir", "_side", ["_dynamic", false], ["_id", ""], ["_stances", [1, 5]], ["_reserved", []]];
if ((_reserved findIf { (_x distance2D _pos) < 3 }) >= 0) exitWith { objNull };
if !(missionNamespace getVariable ["OPORD_trenchFipos", true]) exitWith { objNull };
if !(call OPORD_fnc_hasDco) exitWith { objNull };
private _key = "OPORD_tfCount_" + _id;
private _n = missionNamespace getVariable [_key, 0];
if (_n >= (missionNamespace getVariable ["OPORD_trenchFipoMax", 16])) exitWith { objNull };
if ((nearestObjects [_pos, ["SFSM_FIPO"], 3]) isNotEqualTo []) exitWith { objNull };
missionNamespace setVariable [_key, _n + 1];
private _profile = createHashMapFromArray [
    ["coverStance", _stances select 0], ["shootingStance", _stances select 1], ["sectorDistance", 300], ["sectorWidth", 0.5], ["dynamic", _dynamic]
];
[_pos, _dir, _side, objNull, _profile] call OPORD_fnc_createFipo
