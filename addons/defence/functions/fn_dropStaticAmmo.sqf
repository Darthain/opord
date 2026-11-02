/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_dropStaticAmmo: puts CSW ammo into a ground cache beside a static-weapon slot
    (within ACE's 10 m reload reach), creating the cache if needed.
    Arguments: 0: Slot position ATL, 1: Ammo classes, 2: Existing cache <OBJECT> (optional)
    Return: the cache (weapon holder) or objNull if nothing to drop
*/
params ["_pos", "_mags", ["_cache", objNull]];
if (_mags isEqualTo []) exitWith { _cache };
if (isNull _cache) then {
    private _p = +_pos; _p set [2, 0];
    _cache = createVehicle ["GroundWeaponHolder", _p getPos [1.5, random 360], [], 0, "CAN_COLLIDE"];
    _cache setVariable ["OPORD_staticCache", true, true];
};
{ _cache addMagazineCargoGlobal [_x, 1]; } forEach _mags;
_cache
