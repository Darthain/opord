/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_findAmmoSource: the container a static's crew should draw CSW ammo from.
    Prefers the container the kit came from; otherwise the nearest vehicle / crate within radius
    of the centre holding matching ammo. objNull if none (or no ACE CSW).
    Arguments: 0: Kit, 1: Centre ATL, 2: Radius m, 3: Slot position ATL
*/
params ["_kit", "_centre", "_radius", "_slotPos"];
private _accepts = [_kit select 0] call OPORD_fnc_staticAmmoClasses;
if (_accepts isEqualTo []) exitWith { objNull };
private _has = { (magazineCargo _this) findIf { _x in _accepts } >= 0 };
private _src = _kit select 2;
if (!isNull _src && {!(_src isKindOf "CAManBase")} && {!(_src isKindOf "StaticWeapon")} && {_src call _has}) exitWith { _src };
private _cands = (nearestObjects [_centre, ["ReammoBox_F", "LandVehicle", "Air", "Ship"], _radius]) select {
    (alive _x || {_x isKindOf "ReammoBox_F"}) && {!(_x isKindOf "StaticWeapon")} && {_x call _has}
};
if (_cands isEqualTo []) exitWith { objNull };
([_cands, [], { _x distance2D _slotPos }, "ASCEND"] call BIS_fnc_sortBy) select 0
