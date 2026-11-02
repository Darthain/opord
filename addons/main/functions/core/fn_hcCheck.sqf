/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_hcCheck (server): warns if a headless client is connected but Soldier FSM is not using it
    (the "Run Soldier FSM on a headless client" setting is off, or it connected after Soldier FSM started).
*/
if (!isServer || {!(call OPORD_fnc_hasDco)}) exitWith {};
private _hcs = (entities "HeadlessClient_F") select { isPlayer _x };
if (_hcs isNotEqualTo [] && {(call OPORD_fnc_soldierHost) <= 2}) then {
    private _msg = "A headless client is connected but Soldier FSM is not using it: turn on 'Run Soldier FSM on a headless client' and connect the headless client before the mission starts.";
    [_msg, "WARN"] call OPORD_fnc_log;
    ["OPORD_adminMessage", [_msg]] call CBA_fnc_globalEvent;
};
