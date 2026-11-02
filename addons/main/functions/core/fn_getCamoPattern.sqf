/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
/*
    OPORD_fnc_getCamoPattern: POOK net variant suffix for this terrain (from OPORD v0.3).
    Variants: "" base, then 2-22 (2 NATO tan, 5 DPM desert, 10 AOR forest, 16 snow, 22 jungle).
    Mission override: OPORD_camoPattern = 5;   (0 or 1 = base pattern)
*/
private _override = missionNamespace getVariable ["OPORD_camoPattern", -1];
private _n = if (_override >= 0) then {_override} else {
    switch (toLowerANSI worldName) do {
        case "altis"; case "stratis"; case "malden"; case "vr": {2};
        case "takistan"; case "zargabad"; case "kunduz"; case "mountains_acr"; case "sefrouramal"; case "lythium": {5};
        case "tanoa"; case "lingor3"; case "cam_lao_nam"; case "rhspkl": {22};
        case "namalsk"; case "chernarusredux_winter"; case "enoch_winter": {16};
        default {1};
    };
};
if (_n <= 1) exitWith {""};
str (round _n)
