/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
class CfgPatches {
    class opord_test {
        name = "OPORD Test menu";
        author = "OPORD contributors";
        units[] = {};
        weapons[] = {};
        requiredVersion = 2.18;
        requiredAddons[] = {"opord_main", "opord_defence"};
        version = 0.1;
        versionStr = "0.1.0";
        versionAr[] = {0, 1, 0, 0};
    };
};

class CfgFunctions {
    class OPORD {
        class test {
            file = "\z\opord\addons\test\functions";
            class testRun {};
            class testReport {};
            class testMenu {};
        };
    };
};

class Extended_PreInit_EventHandlers {
    class opord_test { init = "call compile preprocessFileLineNumbers '\z\opord\addons\test\XEH_preInit.sqf'"; };
};
class Extended_PostInit_EventHandlers {
    class opord_test { init = "call compile preprocessFileLineNumbers '\z\opord\addons\test\XEH_postInit.sqf'"; };
};
