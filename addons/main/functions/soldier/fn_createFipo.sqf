/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_createFipo: creates a DCO fighting position (SFSM_FIPO logic) for one soldier.

    Arguments:
      0: Position ATL <ARRAY>
      1: Facing (deg) <NUMBER>
      2: Side <SIDE>
      3: Assigned soldier <OBJECT> (synchronised: DCO moves him in)
      4: Profile <HASHMAP> (optional): coverStance, shootingStance, sectorDistance,
         sectorWidth, hitAndRun, flankWidth, dynamic (BOOL)
    Unassigned positions (no soldier) are used by DCO for dodges and to seat free soldiers.
    Return: the FIPO logic, or objNull without DCO.

    Every variable DCO reads is set explicitly (DCO reads some without defaults).
*/
params ["_pos", "_dir", "_side", ["_man", objNull], ["_profile", createHashMap]];
if !(call OPORD_fnc_hasDco) exitWith { objNull };

private _grp = createGroup [sideLogic, true];
private _fipo = _grp createUnit ["SFSM_FIPO", _pos, [], 0, "CAN_COLLIDE"];
_fipo setPosATL _pos;
_fipo setDir _dir;

private _set = { _fipo setVariable [_this select 0, _this select 1, true]; };
["coverstance",        _profile getOrDefault ["coverStance", 3]] call _set;      // CROUCH-LOW
["shootingstance",     _profile getOrDefault ["shootingStance", 7]] call _set;   // standing (DCO default)
["shootingstanceleft", -1] call _set;
["shootingstanceright", -1] call _set;
["allowwest",          _side isEqualTo west] call _set;
["alloweast",          _side isEqualTo east] call _set;
["allowindependent",   _side isEqualTo independent] call _set;
{ [_x, true] call _set; } forEach ["allowsql", "allowmed", "allowmar", "allowmgn", "allowats", "allowoverrun"];
["hitandrun",          _profile getOrDefault ["hitAndRun", false]] call _set;
["hitandrunmaxshots",  6] call _set;
["hitandruntimeout",   20] call _set;
["hitandruncooldown",  30] call _set;
["dynamicfipo",        _profile getOrDefault ["dynamic", false]] call _set; // active only with an enemy in its sector
["AZ_FIPO",            false] call _set;
["fubardisable",       false] call _set;
["firesectordistance", _profile getOrDefault ["sectorDistance", 300]] call _set;
["firesectorwidth",    _profile getOrDefault ["sectorWidth", 0.5]] call _set;
["leftflank",          -1] call _set;
["rightflank",         -1] call _set;
["SFSM_leftFlankWidth",  _profile getOrDefault ["flankWidth", 0.55]] call _set;
["SFSM_rightFlankWidth", _profile getOrDefault ["flankWidth", 0.55]] call _set;
["showindicators",     false] call _set;
["SFSM_suppressionKnowledge", 0] call _set;
// Also read by DCO without defaults (v0.6.1 test: "allowsuppression" undefined in fn_canFipoSuppress).
["allowsuppression",   true] call _set;
["twowayfipo",         false] call _set;
["overrundistance",    missionNamespace getVariable ["SFSM_overRunDistance", 40]] call _set;
["hrTimeoutRandom",    0] call _set;
["showmarker",         false] call _set;
["posName",            ""] call _set;
["OPORD_fipo",         true] call _set;

if (!isNull _man) then { _fipo synchronizeObjectsAdd [_man]; };

// DCO's fighting-position lists live on the DCO host (server, or the "HC" headless client).
["OPORD_registerFipo", [_fipo]] call CBA_fnc_globalEvent;
_fipo
