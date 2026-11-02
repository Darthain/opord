/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_staticAmmoClasses: [staticClass] -> ACE CSW ammo items that can load this static.
    Uses ACE's ace_csw_groups table (carry magazine -> vehicle magazines it loads) against the
    magazines the static's main turret weapons accept. Cached per class. [] without ACE CSW.
*/
params ["_static"];
if (isNil "OPORD_cswAmmoCache") then { OPORD_cswAmmoCache = createHashMap; };
private _cached = OPORD_cswAmmoCache get _static;
if (!isNil "_cached") exitWith { _cached };

private _groups = configFile >> "ace_csw_groups";
private _result = [];
if (isClass _groups) then {
    private _accepts = [];
    { _accepts append ((compatibleMagazines _x) apply { toLowerANSI _x }); } forEach getArray (configFile >> "CfgVehicles" >> _static >> "Turrets" >> "MainTurret" >> "weapons");
    {
        private _carry = configName _x;
        private _loads = (configProperties [_x, "isNumber _x", true]) apply { toLowerANSI configName _x };
        if (_loads findIf { _x in _accepts } >= 0) then { _result pushBack _carry; };
    } forEach ("true" configClasses _groups);
};
OPORD_cswAmmoCache set [_static, _result];
_result
