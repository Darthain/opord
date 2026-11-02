/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD preInit: shared settings and events.
*/
private _cat = "OPORD";
["OPORD_debug", "CHECKBOX", ["Debug", "Map markers for planned positions and log messages in chat."],
    [_cat, "General"], false, 1, {}, false] call CBA_fnc_addSetting;
["OPORD_registerFipo", { _this call OPORD_fnc_registerFipo; }] call CBA_fnc_addEventHandler;
["OPORD_adminMessage", {
    params ["_msg"];
    if (hasInterface && {!isMultiplayer || {(call BIS_fnc_admin) > 0}}) then { systemChat ("OPORD: " + _msg); };
}] call CBA_fnc_addEventHandler;
