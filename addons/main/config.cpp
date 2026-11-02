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
        requiredAddons[] = {"cba_main", "cba_xeh", "cba_settings"};
        version = 0.1;
        versionStr = "0.1.0";
        versionAr[] = {MAJOR, MINOR, PATCH, BUILD};
    };
};
