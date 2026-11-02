/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_staticKitInfo: [backpackClass] -> [assembleTo, baseClasses] or []
    A static-weapon backpack (vanilla assembly) has assembleInfo >> assembleTo naming a
    StaticWeapon; baseClasses lists the tripods it can be assembled on (empty = none needed).
    UAV backpacks are excluded (they assemble to drones, not static weapons).
*/
params ["_bag"];
private _ai = configFile >> "CfgVehicles" >> _bag >> "assembleInfo";
private _to = getText (_ai >> "assembleTo");
if (_to == "" || {!(_to isKindOf "StaticWeapon")}) exitWith { [] };
private _base = if (isArray (_ai >> "base")) then { getArray (_ai >> "base") } else { [getText (_ai >> "base")] };
[_to, _base select { _x != "" }]
