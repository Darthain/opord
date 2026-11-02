/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_takeStaticAmmo: takes up to N matching CSW ammo items from a container's cargo.
    Arguments: 0: Container, 1: Accepted ammo classes, 2: Max count
    Return: array of ammo classes taken (removed from the container)
*/
params ["_cont", "_accepts", ["_max", 4]];
private _taken = [];
if (isNull _cont || {_accepts isEqualTo []}) exitWith { _taken };
{
    if (count _taken >= _max) exitWith {};
    if (_x in _accepts && {[_cont, _x, 1] call CBA_fnc_removeMagazineCargo}) then { _taken pushBack _x; };
} forEach (magazineCargo _cont);
_taken
