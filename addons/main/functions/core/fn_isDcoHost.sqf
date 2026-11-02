/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_isDcoHost: true on the machine where Soldier FSM runs its battle loop.
    That is the first connected headless client if Soldier FSM runs there, otherwise the server
    (see SFSM_fnc_selectRunner).
*/
clientOwner isEqualTo (call OPORD_fnc_soldierHost)
