/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_safeSnap: places a soldier on his fighting spot only if it's clear of objects
    (moves the spot back up to 3 m to find clear ground), with damage briefly disabled so a
    physics bump on arrival can't kill him.
    Arguments: 0: Unit, 1: Spot ATL, 2: Facing deg
    Return: the position used
*/
params ["_u", "_spot", "_dir"];
private _p = [_spot select 0, _spot select 1, 0];
for "_i" from 0 to 3 do {
    private _c = _spot getPos [_i, _dir + 180]; _c set [2, 0];
    private _blocked = (nearestObjects [_c, [], 1.0]) findIf { _x != _u && {!(_x isKindOf "Logic")} && {!(_x isKindOf "CAManBase")} && {(getModelInfo _x select 0) != ""} } >= 0;
    if (!_blocked) exitWith { _p = _c; };
};
_u allowDamage false;
_u setVelocity [0, 0, 0];
_u setPosATL _p;
_u setDir _dir;
[{ (_this select 0) allowDamage true; }, [_u], 3] call CBA_fnc_waitAndExecute;
_p
