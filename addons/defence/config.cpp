/*
 * OPORD
 * Copyright (C) 2026 OPORD contributors
 * SPDX-License-Identifier: GPL-2.0-only
 * Licensed under the GNU General Public License v2.0 only. See LICENSE and CREDITS.md.
 */
class CfgPatches {
    class opord_defence {
        name = "OPORD Defence";
        author = "OPORD contributors";
        units[] = {"OPORD_Module_BattlePosition", "OPORD_Module_TrenchLine"};
        weapons[] = {};
        requiredVersion = 2.18;
        requiredAddons[] = {"opord_main"};
        version = 0.1;
        versionStr = "0.1.0";
        versionAr[] = {0, 1, 0, 0};
    };
};

class CfgFunctions {
    class OPORD {
        class defence {
            file = "\z\opord\addons\defence\functions";
            class staticKitInfo {};
            class findStaticKits {};
            class refinePos {};
            class planLayout {};
            class createTrench {};
            class setTrenchProgress {};
            class conceal {};
            class assembleStatic {};
            class staticAmmoClasses {};
            class takeStaticAmmo {};
            class dropStaticAmmo {};
            class findAmmoSource {};
            class trenchMethod {};
            class terrainDigSegment {};
            class segmentLength {};
            class placeSandbags {};
            class buildTrenchLine {};
            class moduleTrenchLine {};
            class testTrenchMove {};
            class trenchFipo {};
            class moveViaTrench {};
            class groupUnderFire {};
            class orientAlong {};
            class earthworkClear {};
            class safeSnap {};
            class prepareBattlePosition {};
            class debugMarkers {};
            class moduleBattlePosition {};
            class testBattlePosition {};
        };
    };
};

class Extended_PreInit_EventHandlers {
    class opord_defence { init = "call compile preprocessFileLineNumbers '\z\opord\addons\defence\XEH_preInit.sqf'"; };
};

class CfgVehicles {
    class Logic;
    class Module_F: Logic {
        class ModuleDescription;
    };
    class OPORD_Module_TrenchLine: Module_F {
        scope = 2;
        scopeCurator = 2;
        displayName = "Trench Line / AT Ditch";
        category = "OPORD_Modules";
        function = "OPORD_fnc_moduleTrenchLine";
        functionPriority = 3;
        isGlobal = 0;
        isTriggerActivated = 0;
        isDisposable = 1;
        is3DEN = 0;
        curatorCanAttach = 0;
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\repair_ca.paa";
        class Arguments {
            class Type {
                displayName = "Type";
                typeName = "STRING";
                class values {
                    class trench { name = "Trench"; value = "TRENCH"; default = 1; };
                    class ditch { name = "Anti-tank ditch"; value = "AT_DITCH"; };
                };
            };
            class Method {
                displayName = "Method";
                description = "Auto picks by the map's terrain grid: real terrain trench on fine grids, sunken lane + trench segments on medium, trench segments on coarse.";
                typeName = "STRING";
                class values {
                    class auto { name = "Auto (by terrain grid)"; value = "AUTO"; default = 1; };
                    class terrain { name = "Terrain (TerrainLib)"; value = "TERRAIN"; };
                    class hybrid { name = "Hybrid (terrain + segments)"; value = "HYBRID"; };
                    class objects { name = "Objects (GRAD / sandbags)"; value = "OBJECTS"; };
                };
            };
            class Depth {
                displayName = "Depth (m)";
                description = "-1 = default for the method (terrain 1.6, hybrid 1.0, ditch 2.5).";
                typeName = "NUMBER";
                defaultValue = "-1";
            };
            class Length {
                displayName = "Length (m)";
                description = "Used when no route objects are synchronised: straight line in the module's facing.";
                typeName = "NUMBER";
                defaultValue = "40";
            };
            class TimePer10m {
                displayName = "Dig time per 10 m (s)";
                typeName = "NUMBER";
                defaultValue = "60";
            };
            class FipoSide {
                displayName = "Fighting positions";
                description = "Unassigned DCO fighting positions along the trench (stepping stones for dodging / seating free soldiers), facing this side of the route, plus dynamic positions at both ends.";
                typeName = "STRING";
                class values {
                    class none { name = "None"; value = ""; default = 1; };
                    class left { name = "Facing left of route"; value = "LEFT"; };
                    class right { name = "Facing right of route"; value = "RIGHT"; };
                };
            };
            class TrenchId {
                displayName = "Trench id";
                description = "Optional name (for OPORD_fnc_testTrenchMove). Blank = automatic.";
                typeName = "STRING";
                defaultValue = "";
            };
        };
        class ModuleDescription: ModuleDescription {
            description = "Digs a trench or anti-tank ditch progressively. Route: module position, then synchronised objects (Game Logics / helper arrows) chained nearest-first; or a straight line. Synchronise a unit to make his group the builders (pauses in combat).";
        };
    };
    class OPORD_Module_BattlePosition: Module_F {
        scope = 2;
        scopeCurator = 2;
        displayName = "Battle Position / SBF";
        category = "OPORD_Modules";
        function = "OPORD_fnc_moduleBattlePosition";
        functionPriority = 2;
        isGlobal = 0;
        isTriggerActivated = 0;
        isDisposable = 1;
        is3DEN = 0;
        curatorCanAttach = 1;
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\defend_ca.paa";
        class Arguments {
            class Type {
                displayName = "Type";
                description = "Defensive battle position (arc, dug in) or support-by-fire position (line on the best ground with line of sight).";
                typeName = "STRING";
                class values {
                    class def { name = "Defensive battle position"; value = "DEFENCE"; default = 1; };
                    class sbf { name = "Support by fire (SBF)"; value = "SBF"; };
                };
            };
            class Quality {
                displayName = "Preparation";
                description = "Hasty: quick shallow work. Deliberate: longer digging plus terrain camouflage. Auto: defence deliberate, SBF hasty.";
                typeName = "STRING";
                class values {
                    class auto { name = "Auto"; value = "AUTO"; default = 1; };
                    class hasty { name = "Hasty"; value = "HASTY"; };
                    class delib { name = "Deliberate"; value = "DELIBERATE"; };
                };
            };
            class Dig {
                displayName = "Dig trenches";
                description = "GRAD Trenches (sandbags without it). Auto: defence yes, SBF no.";
                typeName = "NUMBER";
                class values {
                    class auto { name = "Auto"; value = -1; default = 1; };
                    class yes { name = "Yes"; value = 1; };
                    class no { name = "No"; value = 0; };
                };
            };
            class Camo {
                displayName = "Camouflage nets";
                description = "POOK Camonets over positions and direct-fire statics.";
                typeName = "NUMBER";
                class values {
                    class yes { name = "Yes"; value = 1; default = 1; };
                    class no { name = "No"; value = 0; };
                };
            };
            class Statics {
                displayName = "Deploy static weapons";
                description = "Assemble static-weapon backpacks (worn, or stored in nearby vehicles/crates) and crew empty statics nearby.";
                typeName = "NUMBER";
                class values {
                    class yes { name = "Yes"; value = 1; default = 1; };
                    class no { name = "No"; value = 0; };
                };
            };
            class Frontage {
                displayName = "Frontage (m)";
                description = "Width of the position.";
                typeName = "NUMBER";
                defaultValue = "60";
            };
            class SectorDistance {
                displayName = "Sector depth (m)";
                description = "How far out the fire sectors reach (and the line-of-sight target for siting).";
                typeName = "NUMBER";
                defaultValue = "300";
            };
            class ConnectTrench {
                displayName = "Connect with trenches";
                description = "After occupying: a fire trench linking the positions and a communication trench to the rear, dug progressively (TerrainLib / GRAD, by map). Auto: deliberate defence only.";
                typeName = "NUMBER";
                class values {
                    class auto { name = "Auto"; value = -1; default = 1; };
                    class yes { name = "Yes"; value = 1; };
                    class no { name = "No"; value = 0; };
                };
            };
            class StaticRadius {
                displayName = "Static search radius (m)";
                description = "How far to look for vehicles/crates holding static-weapon bags and for empty statics.";
                typeName = "NUMBER";
                defaultValue = "75";
            };
        };
        class ModuleDescription: ModuleDescription {
            description = "Group prepares and occupies a battle position or support-by-fire position facing the module's direction: sites positions, deploys static weapons, digs (GRAD Trenches), camouflages (POOK Camonets), then hands each soldier a DCO fighting position. Synchronise to a unit of each group.";
            sync[] = {"AnyBrain"};
        };
    };
};
