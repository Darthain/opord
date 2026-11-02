/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD defence preInit: settings and events.
*/
private _cat = "OPORD";
["OPORD_buildTimeScale", "SLIDER", ["Digging time scale", "Multiplies digging time (deliberate 120 s, hasty 45 s per position)."],
    [_cat, "Battle positions"], [0.1, 3, 1, 2], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_staticRadius", "SLIDER", ["Static search radius (m)", "Default radius to look for static-weapon bags in vehicles/crates and empty statics."],
    [_cat, "Battle positions"], [10, 300, 75, 0], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_staticAmmoCount", "SLIDER", ["Static ammo carried per weapon", "ACE CSW ammo items a static's crew brings from vehicles / crates, and a tripod carrier drops, per weapon."],
    [_cat, "Battle positions"], [0, 10, 4, 0], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_staticDefaultAmmo", "CHECKBOX", ["Load default ammo into empty statics", "If a deployed static is still empty ~8 s after manning (e.g. ACE crew-served weapons with no CSW ammo nearby), load its default magazines."],
    [_cat, "Battle positions"], true, 1, {}, false] call CBA_fnc_addSetting;
["OPORD_sandbags", "LIST", ["Sandbags", "Sandbag fortifications: around static weapons (ring for mortars), and parapets for positions that are not dug in."],
    [_cat, "Battle positions"], [[0, 1, 2], ["Off", "Static weapons only", "Statics + undug positions"], 2], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_trenchRotationOffset", "LIST", ["Trench model rotation", "Which way trench models (GRAD) face. GRAD's parapet faces opposite to most Arma fortifications, so the default is 180. Change if soldiers end up on the wrong side of the parapet."],
    [_cat, "Trenches"], [[0, 180], ["0 (as placed)", "180 (GRAD default)"], 1], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_snapIntoPosition", "CHECKBOX", ["Step into finished positions", "When a position is finished, soldiers are placed straight into it (avoids AI pathing over the parapet), then DCO takes over."],
    [_cat, "Battle positions"], true, 1, {}, false] call CBA_fnc_addSetting;
["OPORD_digSafeRadius", "SLIDER", ["Dig safety radius (m)", "Digging pauses only if a soldier is suppressed or pinned down, or a known enemy is within this distance. Distant known enemies no longer stop work."],
    [_cat, "Battle positions"], [25, 1000, 150, 0], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_trenchTimePer10m", "SLIDER", ["Trench dig time per 10 m (s)", "Trench lines and ditches are dug progressively at this rate (pauses while builders are in combat)."],
    [_cat, "Trenches"], [5, 600, 60, 0], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_trenchDepth", "SLIDER", ["Terrain trench depth (m)", "Depth of real terrain trenches on fine-grid maps."],
    [_cat, "Trenches"], [0.6, 2.5, 1.6, 1], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_trenchFipos", "CHECKBOX", ["Fighting positions along trenches", "Unassigned DCO fighting positions along connected trenches: DCO's stepping stones for dodges, alternate positions and seating reinforcements; dynamic positions at trench ends."],
    [_cat, "Trenches"], true, 1, {}, false] call CBA_fnc_addSetting;
["OPORD_trenchFipoSpacing", "SLIDER", ["Trench fighting position spacing (m)", "Distance between stepping-stone positions. Must stay well under DCO's dodge distance (default 60 m)."],
    [_cat, "Trenches"], [4, 15, 6, 0], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_trenchFipoMax", "SLIDER", ["Max fighting positions per trench line", "Caps DCO's workload (every fighting position is checked by DCO's manager)."],
    [_cat, "Trenches"], [0, 40, 16, 0], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_terrainBudget", "SLIDER", ["Terrain budget (grid points)", "Maximum terrain grid points OPORD may change per mission (network cost for all players)."],
    [_cat, "Trenches"], [0, 100000, 20000, 0], 1, {}, false] call CBA_fnc_addSetting;
["OPORD_bpTimeout", "SLIDER", ["Preparation time limit (s)", "A position not finished by then is left PARTIAL."],
    [_cat, "Battle positions"], [120, 1800, 600, 0], 1, {}, false] call CBA_fnc_addSetting;

["OPORD_prepareBP", { _this call OPORD_fnc_prepareBattlePosition; }] call CBA_fnc_addEventHandler;
["OPORD_buildTrench", { _this call OPORD_fnc_buildTrenchLine; }] call CBA_fnc_addEventHandler;
