/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_findStaticKits: finds deployable static weapons for a group.

    Sources:
      - vanilla static-weapon BACKPACKS worn by the group, or in vehicle / crate cargo
      - ACE crew-served weapon ITEMS (ACE "advanced assembly"): weapon + tripod carried in the
        launcher slot, or stored in vehicle / crate cargo; paired by ACE's assembleTo table
      - already-assembled, empty static weapons within radius (just need a crew)

    Arguments: 0: Group, 1: Centre ATL, 2: Radius m
    Return: Array of kits: [assembleTo, weaponItem, weaponSource, baseItem, baseSource, kind]
            kind: "bag" (vanilla backpacks) | "csw" (ACE items) | "static" (existing weapon)
            sources are a unit (carried) or a container (cargo)
*/
params ["_group", "_centre", ["_radius", 75]];
private _bags = []; // [class, source]
private _csw = [];  // [class, source]
private _containers = (nearestObjects [_centre, ["ReammoBox_F", "LandVehicle", "Air", "Ship"], _radius]) select { alive _x || {_x isKindOf "ReammoBox_F"} };
private _isCsw = { isClass (configFile >> "CfgWeapons" >> _this >> "ace_csw") };
{
    if (alive _x) then {
        private _b = backpack _x;
        if (_b != "") then { _bags pushBack [_b, _x]; };
        private _s = secondaryWeapon _x;
        if (_s != "" && {_s call _isCsw}) then { _csw pushBack [_s, _x]; };
    };
} forEach units _group;
{
    private _cont = _x;
    { _bags pushBack [_x, _cont]; } forEach (backpackCargo _cont);
    { if (_x call _isCsw) then { _csw pushBack [_x, _cont]; }; } forEach (weaponCargo _cont);
} forEach _containers;

private _kits = [];

// ---- Vanilla backpacks ----
private _used = [];
{
    _x params ["_cls", "_src"];
    private _info = [_cls] call OPORD_fnc_staticKitInfo;
    if (_info isEqualTo [] || {_forEachIndex in _used}) then { continue };
    _info params ["_to", "_bases"];
    private _baseIdx = -1;
    if (_bases isNotEqualTo []) then {
        _baseIdx = _bags findIf { (_x select 0) in _bases && {!(_forEachIndex in _used)} };
        if (_baseIdx < 0) then { continue };
    };
    _used pushBack _forEachIndex;
    if (_baseIdx >= 0) then {
        _used pushBack _baseIdx;
        (_bags select _baseIdx) params ["_bCls", "_bSrc"];
        _kits pushBack [_to, _cls, _src, _bCls, _bSrc, "bag"];
    } else {
        _kits pushBack [_to, _cls, _src, "", objNull, "bag"];
    };
} forEach _bags;

// ---- ACE crew-served weapon items ----
// Weapon item: ace_csw >> type "weapon", assembleTo { <deployedTripodClass> = "<staticClass>"; }
// Tripod item: ace_csw >> type "mount", deploy = "<deployedTripodClass>"
_used = [];
{
    _x params ["_cls", "_src"];
    private _wIdx = _forEachIndex;
    private _cfg = configFile >> "CfgWeapons" >> _cls >> "ace_csw";
    if (getText (_cfg >> "type") != "weapon" || {_forEachIndex in _used}) then { continue };
    private _table = (configProperties [_cfg >> "assembleTo", "isText _x", true]) apply { [configName _x, getText _x] };
    private _match = -1;
    private _static = "";
    {
        _x params ["_tCls"];
        private _tCfg = configFile >> "CfgWeapons" >> _tCls >> "ace_csw";
        if (getText (_tCfg >> "type") == "mount" && {!(_forEachIndex in _used)}) then {
            private _deploy = toLowerANSI getText (_tCfg >> "deploy");
            private _hit = _table findIf { toLowerANSI (_x select 0) == _deploy };
            if (_hit >= 0) exitWith { _match = _forEachIndex; _static = (_table select _hit) select 1; };
        };
    } forEach _csw;
    if (_match < 0 || {_static == ""} || {!(_static isKindOf "StaticWeapon")}) then { continue };
    _used pushBack _wIdx; _used pushBack _match;
    (_csw select _match) params ["_tCls", "_tSrc"];
    _kits pushBack [_static, _cls, _src, _tCls, _tSrc, "csw"];
} forEach _csw;

// ---- Existing empty statics nearby ----
{
    if (alive _x && {(crew _x) isEqualTo []} && {locked _x < 2} && {!(_x getVariable ["OPORD_claimed", false])}) then {
        _kits pushBack [typeOf _x, "", _x, "", objNull, "static"];
    };
} forEach (nearestObjects [_centre, ["StaticWeapon"], _radius]);
_kits
