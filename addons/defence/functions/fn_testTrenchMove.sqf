/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_testTrenchMove: pathing test. Moves a group along a trench line's route, point by
    point (respecting DCO: only free soldiers are ordered), from the first point to the last.
    [group, trenchId, reverse] call OPORD_fnc_testTrenchMove;
    trench ids: keys OPORD_trenchLines   (shown in debug chat when a line starts)
*/
params ["_group", "_id", ["_reverse", false]];
private _line = (missionNamespace getVariable ["OPORD_trenchLines", createHashMap]) get _id;
if (isNil "_line") exitWith { systemChat format ["OPORD: no trench line '%1'", _id]; };
private _pts = +(_line select 0);
if (_reverse) then { reverse _pts; };
{
    [_x, _pts] spawn {
        params ["_u", "_pts"];
        {
            private _p = _x;
            private _end = time + 90;
            waitUntil {
                sleep 1;
                if ([_u] call OPORD_fnc_unitFree && {speed _u < 0.5} && {(_u distance2D _p) > 2.5}) then { _u doMove _p; };
                !alive _u || {(_u distance2D _p) <= 2.5} || {time > _end}
            };
        } forEach _pts;
    };
} forEach (units _group);
