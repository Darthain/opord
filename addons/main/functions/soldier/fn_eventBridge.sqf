/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_eventBridge: subscribes to DCO's (unprefixed, local) events and re-raises them as
    prefixed OPORD events: "OPORD_dco_<name>". Also keeps simple per-group counters that the
    group layer reads (e.g. how many soldiers are pinned down right now).
    DCO raises these on the machine running the AI (server or the headless client).
*/
if !(call OPORD_fnc_hasDco) exitWith {};
{
    private _name = _x;
    [_name, compile format ['["OPORD_dco_%1", _this] call CBA_fnc_localEvent;', _name]] call CBA_fnc_addEventHandler;
} forEach [
    "pinned_down", "overrun", "overrun_flee", "overrun_attack", "take_cover_init", "take_cover_end",
    "suppressing_now", "mg_suppression", "healing_done", "revive_done", "wounded_no_medkit",
    "fipo_getIn", "fipo_getOut", "FIPO_knockedOut", "new_battle", "battle_updated", "battle_ended",
    "SFSM_surrender", "capture", "vehicle_hijack", "turret_mounted", "morale_event"
];

// Pinned-down counter per group (decays after 30 s): the group layer reads OPORD_fnc_groupPinned.
["OPORD_dco_pinned_down", {
    params ["_man"];
    private _g = group _man;
    private _list = (_g getVariable ["OPORD_pinnedTimes", []]) select { time - _x < 30 };
    _list pushBack time;
    _g setVariable ["OPORD_pinnedTimes", _list];
}] call CBA_fnc_addEventHandler;
