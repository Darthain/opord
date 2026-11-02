/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
#include "script_version.hpp"

class CfgPatches {
    class opord_main {
        name = "OPORD";
        author = "OPORD contributors";
        units[] = {};
        weapons[] = {};
        requiredVersion = 2.18;
        // Hard dependencies: CBA, ACE and the bundled soldier layer. GRAD Trenches, POOK Camonets,
        // TerrainLib and IEDD are detected at runtime.
        requiredAddons[] = {"cba_main", "cba_xeh", "cba_settings", "ace_main", "soldierFSM", "SFSM_fipo"};
        version = 0.1;
        versionStr = "0.1.0";
        versionAr[] = {MAJOR, MINOR, PATCH, BUILD};
    };
};

class CfgFunctions {
    class OPORD {
        class core {
            file = "\z\opord\addons\main\functions\core";
            class log {};
            class hasDco {};
            class isDcoHost {};
            class hcCheck {};
            class conflictCheck {};
            class getCamoPattern {};
        };
        class soldier {
            file = "\z\opord\addons\main\functions\soldier";
            class soldierHost {};
            class unitFree {};
            class lockPosture {};
            class createFipo {};
            class registerFipo {};
            class eventBridge {};
            class dcoGuard {};
        };
    };
};

class Extended_PreInit_EventHandlers {
    class opord_main { init = "call compile preprocessFileLineNumbers '\z\opord\addons\main\XEH_preInit.sqf'"; };
};
class Extended_PostInit_EventHandlers {
    class opord_main { init = "call compile preprocessFileLineNumbers '\z\opord\addons\main\XEH_postInit.sqf'"; };
};

class CfgFactionClasses {
    class OPORD_Modules { displayName = "OPORD"; priority = 2; side = 7; };
};
