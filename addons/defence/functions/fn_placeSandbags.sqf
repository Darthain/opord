/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_placeSandbags: places sandbag fortifications.
      "ROUND": curved fence in front of a static weapon / position
      "RING":  three round fences around a mortar
      "SHORT": short parapet in front of an undug position
      "LONG":  long wall segment (trench lining)
    Arguments: 0: Position ATL, 1: Facing deg, 2: Kind
    Return: array of created objects
*/
params ["_pos", "_dir", ["_kind", "ROUND"]];
private _made = [];
private _mk = {
    params ["_cls", "_p", "_d"];
    if !(isClass (configFile >> "CfgVehicles" >> _cls)) exitWith {};
    private _q = +_p; _q set [2, 0];
    private _o = createVehicle [_cls, [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _o setDir _d;
    _o setPosATL _q;
    _o setVectorUp (surfaceNormal _q);
    _o setVariable ["OPORD_engineeringObject", true, true];
    _made pushBack _o;
};
switch (toUpperANSI _kind) do {
    case "RING": {
        { ["Land_BagFence_Round_F", _pos getPos [2.2, _dir + _x], _dir + _x + 180] call _mk; } forEach [0, 120, 240];
    };
    case "SHORT": { ["Land_BagFence_Short_F", _pos getPos [1.2, _dir], _dir] call _mk; };
    case "LONG": { ["Land_BagFence_Long_F", _pos, _dir] call _mk; };
    default { ["Land_BagFence_Round_F", _pos getPos [1.6, _dir], _dir + 180] call _mk; };
};
_made
