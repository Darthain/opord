/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_unitFree: [unit] -> BOOL
    The control contract: OPORD only gives a soldier an individual order when DCO is not
    using him (sprinting, in cover, reviving, in a fighting position, hunting, fleeing...).
    Without DCO, any alive, conscious unit is free.
*/
params ["_unit"];
if (!alive _unit || {_unit getVariable ["ACE_isUnconscious", false]}) exitWith { false };
if !(call OPORD_fnc_hasDco) exitWith { true };
if (isNil "SFSM_fnc_availableAiSoldier") exitWith { true };
[_unit] call SFSM_fnc_availableAiSoldier
