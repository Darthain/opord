/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_registerFipo: [fipo] - runs on the DCO host only. Adds the fighting position to
    DCO's lists and initialises it (which moves the synchronised soldier in).
*/
params ["_fipo"];
if (isNull _fipo || {!(call OPORD_fnc_isDcoHost)}) exitWith {};
if (isNil "SFSM_fipositions") then { SFSM_fipositions = []; };
if (isNil "SFSM_allFipos") then { SFSM_allFipos = []; };
SFSM_fipositions pushBackUnique _fipo;
SFSM_allFipos pushBackUnique _fipo;
if (!isNil "SFSM_fnc_initFipo") then { [_fipo] call SFSM_fnc_initFipo; };
