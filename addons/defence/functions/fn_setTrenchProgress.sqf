/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_setTrenchProgress: [trench, progress 0..1] - raises a GRAD trench as it is dug.
*/
params ["_trench", "_progress"];
if (isNull _trench || {isNil "grad_trenches_functions_fnc_setTrenchProgress"}) exitWith {};
[_trench, (_progress max 0) min 1, 0.5] call grad_trenches_functions_fnc_setTrenchProgress;
