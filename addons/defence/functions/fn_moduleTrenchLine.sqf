/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_moduleTrenchLine: Eden / Zeus module.
    Route: the module's position, then any synchronised objects (e.g. Game Logics or helper
    arrows), chained nearest-first. With no synced objects: a straight line of "Length" metres
    in the module's facing direction.
    Builders: synchronise a unit; his group works it (and pauses while in combat).
*/
params ["_logic", ["_units", []], ["_activated", true]];
if (!isServer || {!_activated}) exitWith {};
private _synced = synchronizedObjects _logic;
private _men = _synced select { _x isKindOf "CAManBase" };
private _pts = _synced select { !(_x isKindOf "CAManBase") && {!(_x isKindOf "Module_F")} } apply { getPosATL _x };
private _route = [getPosATL _logic];
while { _pts isNotEqualTo [] } do {
    private _last = _route select -1;
    private _next = ([_pts, [], { _x distance2D _last }, "ASCEND"] call BIS_fnc_sortBy) select 0;
    _route pushBack _next;
    _pts = _pts - [_next];
};
if (count _route < 2) then { _route pushBack ((getPosATL _logic) getPos [_logic getVariable ["Length", 40], getDir _logic]); };

private _opt = createHashMap;
_opt set ["type", _logic getVariable ["Type", "TRENCH"]];
_opt set ["method", _logic getVariable ["Method", "AUTO"]];
private _depth = _logic getVariable ["Depth", -1];
if (_depth > 0) then { _opt set ["depth", _depth]; };
_opt set ["timePer10m", _logic getVariable ["TimePer10m", 60]];
private _fp = _logic getVariable ["FipoSide", ""];
if (_fp != "") then { _opt set ["fipoSide", _fp]; _opt set ["dynamicStart", true]; _opt set ["dynamicEnd", true]; };
private _side = east;
if (_men isNotEqualTo []) then { _opt set ["group", group (_men select 0)]; _side = side group (_men select 0); };
_opt set ["id", _logic getVariable ["TrenchId", ""]];
if ((_opt get "id") == "") then { _opt deleteAt "id"; };

[{ time > 15 }, { _this call OPORD_fnc_buildTrenchLine; }, [_route, _side, _opt]] call CBA_fnc_waitUntilAndExecute;
