/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_moduleBattlePosition: Eden / Zeus module.
    Eden: place where the position should be, rotate it to face the threat (principal direction
    of fire), synchronise it to a unit of each group that should occupy it.
    Zeus: place it on a unit (its group), facing the threat.
    Waits ~15 s after mission start so DCO has settled group ownership (server / headless client).
*/
params ["_logic", ["_units", []], ["_activated", true]];
if (!isServer || {!_activated}) exitWith {};

private _type = _logic getVariable ["Type", "DEFENCE"];
private _quality = _logic getVariable ["Quality", "AUTO"];
private _dig = _logic getVariable ["Dig", -1];
private _opt = createHashMap;
if (_quality != "AUTO") then { _opt set ["quality", _quality]; };
if (_dig >= 0) then { _opt set ["dig", _dig == 1]; };
_opt set ["camo", (_logic getVariable ["Camo", 1]) == 1];
_opt set ["statics", (_logic getVariable ["Statics", 1]) == 1];
_opt set ["frontage", _logic getVariable ["Frontage", [60, 80] select (_type == "SBF")]];
_opt set ["sectorDistance", _logic getVariable ["SectorDistance", [300, 600] select (_type == "SBF")]];
_opt set ["radius", _logic getVariable ["StaticRadius", 75]];
private _conn = _logic getVariable ["ConnectTrench", -1];
if (_conn >= 0) then { _opt set ["trench", _conn == 1]; };

private _centre = getPosATL _logic;
private _dir = getDir _logic;
private _objs = _units + synchronizedObjects _logic + [_logic getVariable ["bis_fnc_curatorAttachObject_object", objNull]];
private _groups = [];
{ if (!isNull _x && {_x isKindOf "CAManBase"}) then { _groups pushBackUnique (group _x); }; } forEach _objs;
if (_groups isEqualTo []) exitWith { ["Battle Position module: synchronise it to a unit of the group(s) to use.", "WARN"] call OPORD_fnc_log; };

// Start once ownership has settled: with Soldier FSM on a headless client, wait until the group has
// moved to it (max 60 s), so the build runs on the machine that owns the soldiers.
[{
    params ["_groups"];
    if (time <= 15) exitWith { false };
    private _hostOwner = call OPORD_fnc_soldierHost;
    if (_hostOwner <= 2 || {time > 75}) exitWith { true };
    (_groups findIf { groupOwner _x != _hostOwner }) < 0
}, {
    params ["_groups", "_centre", "_dir", "_type", "_opt"];
    {
        private _c = if (count _groups > 1) then { _centre getPos [(_forEachIndex - ((count _groups - 1) / 2)) * 90, _dir + 90] } else { _centre };
        ["OPORD_prepareBP", [_x, _c, _dir, _type, _opt], leader _x] call CBA_fnc_targetEvent;
    } forEach _groups;
}, [_groups, _centre, _dir, _type, _opt]] call CBA_fnc_waitUntilAndExecute;

if (!is3DEN && {!isNull (_logic getVariable ["bis_fnc_curatorAttachObject_object", objNull])}) then { deleteVehicle _logic; };
