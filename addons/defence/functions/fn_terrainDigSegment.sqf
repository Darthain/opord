/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_terrainDigSegment (SERVER): lowers the terrain along a segment to a target depth
    below the ORIGINAL ground, scaled by progress (0..1). Target-based, so overlapping segments
    and repeated passes never dig deeper than intended. Uses TerrainLib (network-optimised,
    restorable, objects follow the ground).

    Arguments: 0: Start pos, 1: End pos, 2: Width m, 3: Depth m, 4: Progress 0..1
    Respects the mission terrain budget (OPORD_terrainBudget grid points).
*/
if (!isServer) exitWith { _this remoteExecCall ["OPORD_fnc_terrainDigSegment", 2]; };
if (isNil "TerrainLib_fnc_setTerrainHeight") exitWith {};
params ["_p1", "_p2", ["_width", 1.5], ["_depth", 1.6], ["_progress", 1]];
private _cell = getTerrainInfo select 2;
private _len = (_p1 distance2D _p2) max 0.1;
private _mid = [((_p1 select 0) + (_p2 select 0)) / 2, ((_p1 select 1) + (_p2 select 1)) / 2, 0];
private _dir = _p1 getDir _p2;
// Half-width at least ~half a cell so the centre line of grid points is always captured.
private _area = [_mid, [((_width / 2) max (_cell * 0.55)), (_len / 2) + (_cell * 0.25), _dir, true]];
private _pts = [_area] call TerrainLib_fnc_getAreaTerrainGrid;

private _used = missionNamespace getVariable ["OPORD_terrainUsed", 0];
private _budget = missionNamespace getVariable ["OPORD_terrainBudget", 20000];
private _out = [];
{
    private _orig = ([_x] call TerrainLib_fnc_unmodifiedTerrainHeight) select 2;
    private _target = _orig - (_depth * ((_progress max 0) min 1));
    if ((_x select 2) > _target + 0.02) then { _out pushBack [_x select 0, _x select 1, _target]; };
} forEach _pts;
if (_out isEqualTo []) exitWith {};
if (_used + count _out > _budget) exitWith { ["Terrain budget reached: further terrain digging skipped.", "WARN"] call OPORD_fnc_log; };
missionNamespace setVariable ["OPORD_terrainUsed", _used + count _out];
[_out, true, true] call TerrainLib_fnc_setTerrainHeight;
// Re-ground DCO fighting positions near the dug stretch (TerrainLib moves objects, not logics).
{
    private _p = getPosATL _x;
    _x setPosATL [_p select 0, _p select 1, 0];
} forEach (nearestObjects [_mid, ["SFSM_FIPO"], (_len / 2) + (_cell * 2)]);
