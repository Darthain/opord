/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_dcoGuard: workaround for a DCO Soldier FSM bug (move.fsm). DCO is no longer
    maintained upstream, so this is applied to EVERY local AI soldier, not just OPORD's.

    When a DCO scripted move stalls, DCO re-issues it with commandFSM, which can run its move
    state machine for a soldier that never had "FSM_startPos" set -> "Undefined variable
    _startPos" errors. Every 10 s this gives each local AI soldier without one his current
    position. Soldiers mid-move already have DCO's value and are never overwritten.
    Players are never touched.
*/
{
    if (local _x && {!isPlayer _x} && {alive _x} && {isNil { _x getVariable "FSM_startPos" }}) then {
        _x setVariable ["FSM_startPos", getPosATLVisual _x];
        if (isNil { _x getVariable "FSM_startTime" }) then { _x setVariable ["FSM_startTime", time]; };
    };
} forEach allUnits;
