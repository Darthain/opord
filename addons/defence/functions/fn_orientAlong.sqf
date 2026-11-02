/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_orientAlong: orients a segment object so its LONG axis runs along a route stretch,
    tilted to the stretch's real slope (joins stay flush), with its front facing one side.

    Arguments: 0: Object, 1: Stretch start ATL, 2: Stretch end ATL, 3: Long axis is model X <BOOL>,
               4: Front faces the LEFT of the route direction <BOOL> (false = right)
*/
params ["_o", "_p1", "_p2", "_longX", ["_frontLeft", true]];
private _a = AGLToASL _p1; private _b = AGLToASL _p2;
private _along = vectorNormalized (_b vectorDiff _a);
if (_along isEqualTo [0, 0, 0]) exitWith {};
private _upRaw = [0, 0, 1];
// Right-handed model frame: right = forward x up; forward = up x right; up = right x forward.
private _fwd = []; private _up = [];
if (_longX) then {
    // Model X (right) along the route; forward (Y) perpendicular to it.
    // Route heading east, front left (north): right must be +east. Front right: right = -east.
    private _right = if (_frontLeft) then { _along } else { _along vectorMultiply -1 };
    _fwd = vectorNormalized (_upRaw vectorCrossProduct _right);
    _up = vectorNormalized (_right vectorCrossProduct _fwd);
} else {
    // Model Y (forward) along the route.
    _fwd = _along;
    private _right = vectorNormalized (_fwd vectorCrossProduct _upRaw);
    _up = vectorNormalized (_right vectorCrossProduct _fwd);
};
_o setVectorDirAndUp [_fwd, _up];
