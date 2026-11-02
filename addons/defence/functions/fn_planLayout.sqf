/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_planLayout: lays out a battle position along the principal direction of fire.

    DEFENCE: fighting-position pairs on a shallow arc with refused (pulled-back) wings.
    SBF:     support-by-fire line, positions refined for line of sight to the target area.
    Static weapons: direct-fire weapons spread across the line slightly behind it (centre
    first, then flanks); mortars 50 m to the rear.

    Arguments:
      0: Centre ATL, 1: Facing deg, 2: Type "DEFENCE"|"SBF", 3: Frontage m,
      4: Number of fighting positions, 5: Static kits (from OPORD_fnc_findStaticKits),
      6: Sector distance m (target area for line-of-sight checks)
    Return: HashMap: "positions" [[posATL, dir]...], "statics" [[posATL, dir, isMortar]...]
*/
params ["_centre", "_dir", "_type", ["_frontage", 60], ["_n", 3], ["_kits", []], ["_sector", 300]];
private _sbf = _type == "SBF";
private _right = _dir + 90;
private _target = _centre getPos [_sector, _dir];
private _fnc_offset = {
    params ["_lat", "_back"];
    private _p = _centre getPos [abs _lat, [_right - 180, _right] select (_lat >= 0)];
    if (_back != 0) then { _p = _p getPos [_back, _dir + 180]; };
    _p set [2, 0]; _p
};

private _positions = [];
_n = _n max 1;
// Minimum spacing: a long trench's real length + 3 m (8 m without GRAD), so parapets never overlap.
private _minSp = if (isClass (configFile >> "CfgVehicles" >> "GRAD_envelope_long")) then { ((["GRAD_envelope_long"] call OPORD_fnc_segmentLength) select 0) + 3 } else { 8 };
private _spacing = if (_n > 1) then { ((_frontage / (_n - 1)) max _minSp) min (25 max _minSp) } else { 0 };
private _half = ((_n - 1) / 2) * _spacing;
for "_i" from 0 to (_n - 1) do {
    private _lat = (_i - ((_n - 1) / 2)) * _spacing;
    private _back = if (_sbf || {_half == 0}) then { 0 } else { 6 * ((_lat / _half) ^ 2) }; // refused wings
    private _p = [_lat, _back] call _fnc_offset;
    private _r = [_p, _target, [5, 8] select _sbf] call OPORD_fnc_refinePos;
    // Keep the refined spot only if it doesn't crowd an earlier position.
    if ((_positions findIf { ((_x select 0) distance2D _r) < (_minSp * 0.85) }) < 0) then { _p = _r; };
    _positions pushBack [_p, _dir];
};

private _direct = _kits select { !((_x select 0) isKindOf "StaticMortar") };
private _mortars = _kits select { (_x select 0) isKindOf "StaticMortar" };
private _statics = [];
private _slotsLat = switch (count _direct) do {
    case 0: { [] };
    case 1: { [0] };
    case 2: { [-0.35, 0.35] };
    case 3: { [-0.4, 0, 0.4] };
    default {
        private _k = count _direct;
        private _l = [];
        for "_j" from 0 to (_k - 1) do { _l pushBack (-0.45 + 0.9 * _j / (_k - 1)); };
        _l
    };
};
{
    private _p = [(_x * _frontage) + 3, [4, 0] select _sbf] call _fnc_offset; // offset off the pair slots
    _p = [_p, _target, 5] call OPORD_fnc_refinePos;
    _statics pushBack [_p, _dir, false];
} forEach _slotsLat;
{
    private _p = [(_forEachIndex - ((count _mortars - 1) / 2)) * 10, 50] call _fnc_offset;
    _statics pushBack [_p, _dir, true];
} forEach _mortars;

createHashMapFromArray [["positions", _positions], ["statics", _statics], ["direct", _direct], ["mortars", _mortars]]
