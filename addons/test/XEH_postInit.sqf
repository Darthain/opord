/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD test postInit.
*/
if (isServer) then {
    ["OPORD_test", { _this call OPORD_fnc_testRun; }] call CBA_fnc_addEventHandler;
    ["OPORD_battlePositionReady", { _this call OPORD_fnc_testReport; }] call CBA_fnc_addEventHandler;
};

call OPORD_fnc_testMenu;
