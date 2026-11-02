/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_testReport (server, on "OPORD_battlePositionReady"): reports a test position's result.
    Arguments: 0: Group, 1: Type, 2: State ("READY" | "PARTIAL")
*/
params ["_group", "_type", "_state"];
if (!isServer || {isNil "OPORD_testRuns"}) exitWith {};
private _run = OPORD_testRuns select { (_x select 0) == _group } param [0, []];
if (_run isEqualTo []) exitWith {};
_run params ["", "_label", "_t0", "_centre"];
private _segs = count (nearestObjects [_centre, ["GRAD_envelope_long", "GRAD_envelope_short"], 120]);
private _statics = count (_group getVariable ["OPORD_bpStatics", []]);
private _msg = format ["[OPORD TEST] %1: %2 after %3 s. Statics %4, GRAD trench pieces %5, soldiers alive %6.",
    _label, _state, round (time - _t0), _statics, _segs, { alive _x } count units _group];
[_msg, ["INFO", "WARN"] select (_state != "READY")] call OPORD_fnc_log;
["OPORD_adminMessage", [_msg]] call CBA_fnc_globalEvent;
