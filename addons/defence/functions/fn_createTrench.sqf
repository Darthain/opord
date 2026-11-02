/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_createTrench: creates a fighting-position earthwork IN FRONT of a soldier's spot,
    at progress 0 (to be dug). The soldier fights from open ground behind it, never inside the
    model: AI inside GRAD trench models clip, sink and get stuck.

    GRAD Trenches loaded: a GRAD trench as a spoil parapet (pair -> "long", single -> "short"),
    long side across the line of fire, surface-aligned, sunk to 0% and raised as it's dug.
    Otherwise: a sandbag fence (no digging stage).

    Arguments: 0: Spot ATL (where the soldier(s) fight), 1: Facing deg (direction of fire),
               2: Occupants (1 or 2+), 3: Side
    Return: [object, isGrad]
*/
params ["_pos", "_dir", ["_occupants", 2], ["_side", east]];
private _grad = isClass (configFile >> "CfgVehicles" >> "GRAD_envelope_long") && {!isNil "grad_trenches_functions_fnc_setTrenchProgress"};
private _p = +_pos; _p set [2, 0];

if (_grad) exitWith {
    private _cls = ["GRAD_envelope_short", "GRAD_envelope_long"] select (_occupants >= 2);
    ([_cls] call OPORD_fnc_segmentLength) params ["", "_longX", "_short"];
    private _c = _p getPos [(_short / 2) + 0.6, _dir]; _c set [2, 0];
    private _t = createVehicle [_cls, [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _t setDir (_dir + ([90, 0] select _longX) + (missionNamespace getVariable ["OPORD_trenchRotationOffset", 180]));
    _t setVectorUp (surfaceNormal _c);
    // Ground texture only if it's a colour texture (some terrains return textures that render
    // purple-white on objects); otherwise keep GRAD's own.
    private _tex = surfaceTexture _c;
    if ((toLowerANSI _tex) find "_co.paa" >= 0) then { _t setObjectTextureGlobal [0, _tex]; };
    _t setPosATL _c;
    [_t, 0] call grad_trenches_functions_fnc_setTrenchProgress;
    _t setVariable ["OPORD_engineeringObject", true, true];
    _t setVariable ["OPORD_ownerSide", _side, true];
    [_t, true]
};

private _bag = createVehicle ["Land_BagFence_Round_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
_bag setDir _dir;
_bag setPosATL (_p getPos [1.2, _dir]);
_bag setVariable ["OPORD_engineeringObject", true, true];
[_bag, false]
