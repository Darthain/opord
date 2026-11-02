/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_log: [message, level] - RPT log, plus chat when OPORD debug is on.
    level: "INFO" | "WARN" | "ERROR"
*/
params [["_msg", ""], ["_level", "INFO"]];
diag_log format ["[OPORD][%1] %2", _level, _msg];
if (missionNamespace getVariable ["OPORD_debug", false] && {hasInterface}) then {
    systemChat format ["OPORD: %1", _msg];
};
