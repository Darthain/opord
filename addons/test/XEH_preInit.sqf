/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD test preInit: settings.
*/
["OPORD_testMenu", "CHECKBOX", ["Test menu (admins)", "ACE self-interaction 'OPORD tests' for the host or logged-in admins: spawns checkpoint test setups (D1, D2, D3, D8) in front of you and reports results. For testing only."],
    ["OPORD", "Testing"], false, 1, {}, false] call CBA_fnc_addSetting;
