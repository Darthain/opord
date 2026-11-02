/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD postInit.
*/
call OPORD_fnc_eventBridge;
if (call OPORD_fnc_hasDco) then { [{ call OPORD_fnc_dcoGuard }, 10] call CBA_fnc_addPerFrameHandler; };
if (isServer) then {
    [{ call OPORD_fnc_hcCheck; }, [], 20] call CBA_fnc_waitAndExecute;
    [{ call OPORD_fnc_conflictCheck; }, [], 20] call CBA_fnc_waitAndExecute;
};
