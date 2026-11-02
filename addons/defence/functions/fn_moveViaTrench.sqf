/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_moveViaTrench: moves a soldier to a destination along a trench line when one
    connects the two (both ends within 30 m of the same line); otherwise a plain move.
    Respects the control contract: waits while DCO is using the soldier, re-issues when free.

    Arguments: 0: Unit, 1: Destination ATL
    Return: true if a trench route is used
*/
params ["_unit", "_dest"];
private _best = [];
private _bestScore = 1e9;
{
    private _pts = _y select 0;
    private _i1 = -1; private _d1 = 1e9;
    private _i2 = -1; private _d2 = 1e9;
    {
        private _a = _x distance2D _unit;
        private _b = _x distance2D _dest;
        if (_a < _d1) then { _d1 = _a; _i1 = _forEachIndex; };
        if (_b < _d2) then { _d2 = _b; _i2 = _forEachIndex; };
    } forEach _pts;
    if (_d1 < 30 && {_d2 < 30} && {_i1 != _i2} && {(_d1 + _d2) < _bestScore}) then {
        _bestScore = _d1 + _d2;
        private _route = [];
        if (_i1 < _i2) then { for "_k" from _i1 to _i2 do { _route pushBack (_pts select _k); }; }
        else { for "_k" from _i1 to _i2 step -1 do { _route pushBack (_pts select _k); }; };
        _best = _route;
    };
} forEach (missionNamespace getVariable ["OPORD_trenchLines", createHashMap]);

_best pushBack _dest;
private _viaTrench = count _best > 1;
[_unit, _best] spawn {
    params ["_u", "_route"];
    {
        private _p = _x;
        private _end = time + 90;
        waitUntil {
            sleep 1;
            if ([_u] call OPORD_fnc_unitFree && {speed _u < 0.5} && {(_u distance2D _p) > 2.5}) then { _u doMove _p; };
            !alive _u || {(_u distance2D _p) <= 2.5} || {time > _end}
        };
    } forEach _route;
};
_viaTrench
