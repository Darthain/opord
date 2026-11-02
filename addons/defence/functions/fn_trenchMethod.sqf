/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_trenchMethod: how trenches are built on this map.
      "TERRAIN": grid fine enough (<= 2.5 m) for a real dug trench via TerrainLib
      "HYBRID":  medium grid (<= 6 m): shallow sunken lane (TerrainLib) lined with trench segments
      "OBJECTS": coarse grid, or no TerrainLib: chained GRAD trench segments (sandbags without GRAD)
    Mission override: OPORD_trenchMethodOverride = "HYBRID";
    Return: [method, cellSize]
*/
private _cell = getTerrainInfo select 2;
private _override = missionNamespace getVariable ["OPORD_trenchMethodOverride", ""];
if (_override != "") exitWith { [toUpperANSI _override, _cell] };
if (isNil "TerrainLib_fnc_setTerrainHeight") exitWith { ["OBJECTS", _cell] };
private _m = "OBJECTS";
if (_cell <= 6) then { _m = "HYBRID"; };
if (_cell <= 2.5) then { _m = "TERRAIN"; };
[_m, _cell]
