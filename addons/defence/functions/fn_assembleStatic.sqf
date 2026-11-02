/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_assembleStatic: assembles a static weapon from a kit at a slot and mans it.
    Removes the backpacks (vanilla) or launcher-slot items (ACE CSW) from the soldiers carrying
    them, or from container cargo.

    Arguments: 0: Kit [assembleTo, weaponBag, weaponSource, baseBag, baseSource, kind],
               1: Slot position ATL, 2: Facing deg, 3: Gunner <OBJECT>,
               4: CSW ammo the crew brought <ARRAY> (optional), 5: Existing ammo cache (optional)
    Return: the static weapon
*/
params ["_kit", "_pos", "_dir", "_gunner", ["_ammo", []], ["_cache", objNull]];
_kit params ["_to", "_wBag", "_wSrc", "_bBag", "_bSrc", "_kind"];

private _static = objNull;
if (_kind == "static") then {
    _static = _wSrc; // already assembled
} else {
    private _fnc_takeBag = {
        params ["_cls", "_src"];
        if (isNull _src || {_cls == ""}) exitWith {};
        if (_kind == "csw") then {
            // ACE crew-served weapon items live in the launcher slot or in weapon cargo.
            if (_src isKindOf "CAManBase") then {
                if (secondaryWeapon _src == _cls) then { _src removeWeaponGlobal _cls; };
            } else {
                [_src, _cls, 1] call CBA_fnc_removeWeaponCargo;
            };
        } else {
            if (_src isKindOf "CAManBase") then {
                if (backpack _src == _cls) then { removeBackpackGlobal _src; };
            } else {
                [_src, _cls, 1] call CBA_fnc_removeBackpackCargo;
            };
        };
    };
    [_wBag, _wSrc] call _fnc_takeBag;
    [_bBag, _bSrc] call _fnc_takeBag;
    private _p = +_pos; _p set [2, 0];
    _static = createVehicle [_to, [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _static setDir _dir;
    _static setPosATL _p;
    _static setVectorUp (surfaceNormal _p);
};
_static setVariable ["OPORD_claimed", true, true];
_static setVariable ["OPORD_ownerGroup", group _gunner, true];
// Ammo the crew brought goes into a cache beside the weapon BEFORE the gunner gets in, so ACE's
// AI reload (on get-in, within 10 m) finds it.
_cache = [getPosATL _static, _ammo, _cache] call OPORD_fnc_dropStaticAmmo;
if (!isNull _cache) then { _static setVariable ["OPORD_ammoCache", _cache, true]; };
if (alive _gunner) then {
    _gunner assignAsGunner _static;
    _gunner moveInGunner _static;
};

// Ammo: with ACE CSW ammo handling for AI, the gunner reloads from CSW ammo on him or within
// 10 m. If the weapon is still empty after that, optionally load its default magazines so a
// deployed static is never useless (setting "Load default ammo into empty statics").
[{
    params ["_static"];
    if (!alive _static || {someAmmo _static} || {!(missionNamespace getVariable ["OPORD_staticDefaultAmmo", true])}) exitWith {};
    private _mags = getArray (configOf _static >> "Turrets" >> "MainTurret" >> "magazines");
    { _static addMagazineTurret [_x, [0]]; } forEach (_mags select [0, 2]);
}, [_static], 8] call CBA_fnc_waitAndExecute;
_static
