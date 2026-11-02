/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_debugMarkers: map markers for a planned battle position (only with OPORD debug on).
    Blue dots = fighting positions, red triangles = static slots, arrow = direction of fire.
*/
params ["_group", "_centre", "_dir", "_positions", "_slots"];
if !(missionNamespace getVariable ["OPORD_debug", false]) exitWith {};
private _id = format ["OPORD_bp_%1", groupId _group];
private _mk = {
    params ["_name", "_pos", "_type", "_color", ["_text", ""], ["_mdir", 0]];
    deleteMarker _name;
    private _m = createMarker [_name, _pos];
    _m setMarkerTypeLocal _type; _m setMarkerColorLocal _color; _m setMarkerTextLocal _text; _m setMarkerDirLocal _mdir;
    _m setMarkerSize [0.6, 0.6];
};
[_id + "_pdf", _centre, "mil_arrow", "ColorOrange", format ["%1 PDF", groupId _group], _dir] call _mk;
{ [format ["%1_p%2", _id, _forEachIndex], _x select 0, "mil_dot", "ColorBlue", str (_forEachIndex + 1)] call _mk; } forEach _positions;
{ [format ["%1_s%2", _id, _forEachIndex], _x select 0, "mil_triangle", "ColorRed", ["STATIC", "MORTAR"] select (_x select 2), _x select 1] call _mk; } forEach _slots;
