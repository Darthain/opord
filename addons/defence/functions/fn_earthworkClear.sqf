/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_earthworkClear: [position, radius] -> true if no OPORD earthwork (trench, sandbags,
    net) is within radius. Used to stop trench pieces stacking at junctions and overlaps.
*/
params ["_pos", ["_radius", 2]];
((nearestObjects [_pos, [], _radius]) findIf { _x getVariable ["OPORD_engineeringObject", false] }) < 0
