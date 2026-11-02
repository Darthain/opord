/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_soldierHost: owner ID of the machine running Soldier FSM (2 = the server).
    Reads SFSM_runnerOwner, published by the server (SFSM_fnc_selectRunner). Replaces the old
    PR_HC1 / PR_HeadlessClients checks. Arguments: none. Return: NUMBER.
*/
missionNamespace getVariable ["SFSM_runnerOwner", 2]
