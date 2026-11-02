class CfgPatches
{
    class ARTIC_AI_Core
    {
        name = "ARTIC AI Core";
        author = "ARTIC";
        requiredVersion = 2.14;
        requiredAddons[] = {"A3_Modules_F", "cba_main", "cba_modules", "cba_events", "cba_statemachine"};
        units[] = {
            "ARTIC_Module_Core",
            "ARTIC_Module_Commander",
            "ARTIC_Module_Formation",
            "ARTIC_Module_Objective",
            "ARTIC_Module_Site",
            "ARTIC_Module_AO",
            "ARTIC_Module_Frontline",
            "ARTIC_Module_Reserve",
            "ARTIC_Module_Support",
            "ARTIC_Module_RoleOverride"
        };
        weapons[] = {};
        version = "0.3.30.2-alpha";
    };
};

class CfgFactionClasses
{
    class NO_CATEGORY;
    class ARTIC_AI_Modules: NO_CATEGORY
    {
        displayName = "ARTIC AI";
    };
};

class CfgFunctions
{
    class ARTIC
    {
        tag = "ARTIC";

        class Core
        {
            file = "\artic_ai_core\functions\core";
            class preInit { preInit = 1; };
            class postInit { postInit = 1; };
            class debug {};
            class sideFromIndex {};
            class initDoctrineLibrary {};
            class getDoctrine {};
            class getTraining {};
            class getSyncedByClass {};
            class clearGroupWaypoints {};
            class isCombatEffectiveTarget {};
        };

        class Modules
        {
            file = "\artic_ai_core\functions\modules";
            class moduleCore {};
            class moduleCommander {};
            class moduleFormation {};
            class moduleObjective {};
            class moduleSite {};
            class moduleAO {};
            class moduleFrontline {};
            class moduleReserve {};
            class moduleSupport {};
            class moduleRoleOverride {};
        };

        class ORBAT
        {
            file = "\artic_ai_core\functions\orbat";
            class platoonMovementStep {};
            class platoonContactResponse {};
            class assessSectionContact {};
            class findWithdrawalLanes {};
            class battleSight {};
            class evaluateSbfFireLine {};
            class getBattleEnvelope {};
            class buildDefenceContext {};
            class rebuildORBAT {};
            class buildFormationNode {};
            class getFormationGroups {};
            class applyFormationProfile {};
            class assignFormationIntent {};
            class buildBattleContext {};
            class assessBattlefield {};
            class findBattleControlPoint {};
            class planSectionRoute {};
            class findSupportArc {};
            class generateBattleCOAs {};
            class selectAttackScheme {};
        };

        class Commander
        {
            file = "\artic_ai_core\functions\commander";
            class serverManager {};
            class commanderStep {};
            class updateCommanderIntel {};
            class refreshSiteControl {};
            class evaluateObjective {};
            class assignObjective {};
            class drawCommanderDebug {};
            class considerUAS {};
            class classifyBattlefields {};
        };

        class Capabilities
        {
            file = "\artic_ai_core\functions\capabilities";
            class scanGroupCapabilities {};
            class scanVehicleCapabilities {};
            class applyRoleOverrides {};
        };

        class Planner
        {
            file = "\artic_ai_core\functions\planner";
            class localPlanner {};
            class groupStep {};
            class reportContact {};
            class findTarget {};
            class setGroupOrder {};
            class clearGroupOrder {};
            class getProfile {};
        };

        class Tactics
        {
            file = "\artic_ai_core\functions\tactics";
            class assignElements {};
            class hasLineOfSight {};
            class coverScore {};
            class findCoverPosition {};
            class assessExposure {};
            class findThreatRelativeCover {};
            class findSupportPosition {};
            class chooseFlankPlan {};
            class assessAttackSupport {};
            class moveSectionTactical {};
            class moveFireteamTactical {};
            class suppressElement {};
            class finishPlan {};
            class executeSuppressAndFlank {};
            class executePlatoonManoeuvre {};
            class executeFixingAction {};
            class executeFightingWithdrawal {};
            class executePrepareBattlePosition {};
            class executeDefendBattlePosition {};
            class executeBlockingAction {};
            class isPlayStale {};
            class markDeployProgress {};
            class endPlayQuietly {};
            class isSectionPlayActive {};
        };

        class Formation
        {
            file = "\artic_ai_core\functions\formation";
            class getFormationTemplate {};
            class fireteamSlotWorld {};
            class assignFormationSlots {};
            class selectFormation {};
            class setSectionDestination {};
            class formationSlotWorld {};
            class sectionFormationStep {};
            class assertMovementControl {};
        };

        class Combat
        {
            file = "\artic_ai_core\functions\combat";
            class fireHE {};
            class assignFirePositions {};
            class sectionReactFire {};
            class buildFireLine {};
        };

        class FSMRuntime
        {
            file = "\artic_ai_core\functions\fsm";
            class findFormationNode {};
            class startCommanderFSM {};
            class startPlatoonFSM {};
            class startSectionFSM {};
            class startFireteamFSM {};
            class commanderFSMEnterState {};
            class commanderFSMCondition {};
            class platoonFSMEnterState {};
            class platoonFSMCondition {};
            class sectionFSMEnterState {};
            class sectionFSMCondition {};
            class fireteamFSMEnterState {};
            class fireteamFSMCondition {};
            class getFireteamMembers {};
            class makeFireteamTask {};
            class validateFireteamTask {};
            class fireteamTaskGet {};
            class setFireteamTask {};
            class getPlatoonLogicList {};
            class getPlatoonPlan {};
            class createPlatoonPlan {};
            class applyPlatoonPlan {};
            class signalSectionReady {};
            class signalSectionFailure {};
            class tryIssuePlatoonHHour {};
            class supersedePlatoonPlan {};
            class platoonRuntimeEnterState {};
            class platoonRuntimeCondition {};
            class startPlatoonCBAStateMachine {};
            class registerFSMEvents {};
            class classifyPlanFailure {};
            class recordPlatoonFailure {};
            class setSectionTaskState {};
            class abortSectionTask {};
        };

        class Individual
        {
            file = "\artic_ai_core\functions\individual";
            class setUnitTask {};
            class clearUnitTask {};
            class initFireteams {};
            class individualStep {};
            class processIndividualAI {};
            class isFit {};
            class getMovementProfile {};
        };

        class Engineering
        {
            file = "\artic_ai_core\functions\engineering";
            class chooseBattlePositionLayout {};
            class createFightingPosition {};
            class createConcealment {};
            class getCamoPattern {};
            class registerObstacle {};
            class createIED {};
            class detonateIED {};
        };

        class Support
        {
            file = "\artic_ai_core\functions\support";
            class requestSupport {};
            class processSupportRequests {};
            class executeFireMission {};
            class localArtilleryFire {};
            class supportDiagnostic {};
        };

        class UAS
        {
            file = "\artic_ai_core\functions\uas";
            class scanUnitUASCapabilities {};
            class getCrocusClass {};
            class findUASProvider {};
            class requestUAS {};
            class consumeUASItem {};
            class reportUASContacts {};
            class executeReconUAS {};
            class executeFPVStrike {};
            class processUASRequests {};
        };
    };
};

class CfgVehicles
{
    class Logic;
    class Module_F: Logic
    {
        class ArgumentsBaseUnits;
        class ModuleDescription;
    };

    class ARTIC_Module_Base: Module_F
    {
        author = "ARTIC";
        category = "ARTIC_AI_Modules";
        scope = 1;
        isGlobal = 1;
        isTriggerActivated = 0;
        isDisposable = 0;
        is3DEN = 0;
    };

    class ARTIC_Module_Core: ARTIC_Module_Base
    {
        scope = 2;
        displayName = "Core / Debug Settings";
        function = "ARTIC_fnc_moduleCore";
        class Arguments: ArgumentsBaseUnits
        {
            class Debug
            {
                displayName = "Debug Logging";
                description = "Writes ARTIC decisions to RPT and, optionally, system chat.";
                typeName = "BOOL";
                defaultValue = "true";
            };
            class DebugChat
            {
                displayName = "Debug Chat";
                typeName = "BOOL";
                defaultValue = "true";
            };
            class DebugMarkers
            {
                displayName = "Debug Map Markers";
                typeName = "BOOL";
                defaultValue = "true";
            };
        };
    };

    class ARTIC_Module_Commander: ARTIC_Module_Base
    {
        scope = 2;
        displayName = "Commander";
        function = "ARTIC_fnc_moduleCommander";
        class Arguments: ArgumentsBaseUnits
        {
            class CommanderId
            {
                displayName = "Commander ID";
                description = "Unique ID, e.g. EAST_1BN.";
                typeName = "STRING";
                defaultValue = "EAST_CMD";
            };
            class CommanderName
            {
                displayName = "Commander Name";
                typeName = "STRING";
                defaultValue = "ARTIC Commander";
            };
            class SideIndex
            {
                displayName = "Side";
                class values
                {
                    class BLUFOR { name = "BLUFOR"; value = 0; };
                    class OPFOR { name = "OPFOR"; value = 1; default = 1; };
                    class INDEP { name = "INDEPENDENT"; value = 2; };
                    class CIV { name = "CIVILIAN"; value = 3; };
                };
            };
            class Doctrine
            {
                displayName = "Doctrine";
                class values
                {
                    class Conventional { name = "Conventional"; value = "CONVENTIONAL"; default = 1; };
                    class Insurgent { name = "Insurgent"; value = "INSURGENT"; };
                    class Militia { name = "Militia"; value = "MILITIA"; };
                    class Recon { name = "Recon"; value = "RECON"; };
                    class Positional { name = "Positional"; value = "POSITIONAL"; };
                    class SF { name = "Special Forces"; value = "SPECIAL_FORCES"; };
                };
            };
            class Training
            {
                displayName = "Training";
                class values
                {
                    class Poor { name = "Poor"; value = "POOR"; };
                    class Regular { name = "Regular"; value = "REGULAR"; default = 1; };
                    class Veteran { name = "Veteran"; value = "VETERAN"; };
                    class Elite { name = "Elite"; value = "ELITE"; };
                };
            };
            class CommandLevel
            {
                displayName = "Command Level";
                class values
                {
                    class Battalion { name = "Battalion / Task Force"; value = "BATTALION"; default = 1; };
                    class Company { name = "Company"; value = "COMPANY"; };
                    class Platoon { name = "Platoon"; value = "PLATOON"; };
                };
            };
            class DecisionInterval
            {
                displayName = "Decision Interval (sec)";
                typeName = "NUMBER";
                defaultValue = "20";
            };
            class Aggression
            {
                displayName = "Aggression (0-1)";
                typeName = "NUMBER";
                defaultValue = "0.55";
            };
            class Caution
            {
                displayName = "Caution (0-1)";
                typeName = "NUMBER";
                defaultValue = "0.55";
            };
            class Initiative
            {
                displayName = "Initiative (0-1)";
                typeName = "NUMBER";
                defaultValue = "0.60";
            };
            class Adaptability
            {
                displayName = "Adaptability (0-1)";
                typeName = "NUMBER";
                defaultValue = "0.60";
            };
            class AutoUAS
            {
                displayName = "Automatic UAS Employment";
                description = "Allows the commander to launch reconnaissance UAS and FPV strikes when suitable operators/assets exist.";
                typeName = "BOOL";
                defaultValue = "true";
            };
            class UASReconCooldown
            {
                displayName = "Recon UAS Cooldown (sec)";
                typeName = "NUMBER";
                defaultValue = "180";
            };
            class UASStrikeCooldown
            {
                displayName = "FPV Strike Cooldown (sec)";
                typeName = "NUMBER";
                defaultValue = "90";
            };
        };
        class ModuleDescription: ModuleDescription
        {
            description = "Top-level ARTIC commander. Synchronise to one or more Formation modules and optionally AO, Frontline, Objective, Site and Support Asset modules.";
        };
    };

    class ARTIC_Module_Formation: ARTIC_Module_Base
    {
        scope = 2;
        displayName = "Formation / ORBAT Node";
        function = "ARTIC_fnc_moduleFormation";
        class Arguments: ArgumentsBaseUnits
        {
            class FormationId
            {
                displayName = "Formation ID";
                typeName = "STRING";
                defaultValue = "FORMATION_1";
            };
            class FormationName
            {
                displayName = "Formation Name";
                typeName = "STRING";
                defaultValue = "Formation";
            };
            class FormationLevel
            {
                displayName = "Level";
                class values
                {
                    class Battalion { name = "Battalion"; value = "BATTALION"; };
                    class Company { name = "Company"; value = "COMPANY"; };
                    class Platoon { name = "Platoon"; value = "PLATOON"; default = 1; };
                    class Section { name = "Section / Squad"; value = "SECTION"; };
                };
            };
            class DoctrineOverride
            {
                displayName = "Doctrine Override";
                class values
                {
                    class Inherit { name = "Inherit"; value = "INHERIT"; default = 1; };
                    class Conventional { name = "Conventional"; value = "CONVENTIONAL"; };
                    class Insurgent { name = "Insurgent"; value = "INSURGENT"; };
                    class Militia { name = "Militia"; value = "MILITIA"; };
                    class Recon { name = "Recon"; value = "RECON"; };
                    class Positional { name = "Positional"; value = "POSITIONAL"; };
                    class SF { name = "Special Forces"; value = "SPECIAL_FORCES"; };
                };
            };
            class TrainingOverride
            {
                displayName = "Training Override";
                class values
                {
                    class Inherit { name = "Inherit"; value = "INHERIT"; default = 1; };
                    class Poor { name = "Poor"; value = "POOR"; };
                    class Regular { name = "Regular"; value = "REGULAR"; };
                    class Veteran { name = "Veteran"; value = "VETERAN"; };
                    class Elite { name = "Elite"; value = "ELITE"; };
                };
            };
        };
        class ModuleDescription: ModuleDescription
        {
            description = "ORBAT node. Synchronise parent Formation to child Formation modules. Synchronise the lowest formation to one unit from each subordinate group.";
        };
    };

    class ARTIC_Module_Objective: ARTIC_Module_Base
    {
        scope = 2;
        displayName = "Objective";
        function = "ARTIC_fnc_moduleObjective";
        class Arguments: ArgumentsBaseUnits
        {
            class ObjectiveId
            {
                displayName = "Objective ID";
                typeName = "STRING";
                defaultValue = "OBJ_1";
            };
            class ObjectiveName
            {
                displayName = "Objective Name";
                typeName = "STRING";
                defaultValue = "Objective";
            };
            class ObjectiveType
            {
                displayName = "Task Type";
                class values
                {
                    class Capture { name = "Capture / Attack"; value = "CAPTURE"; default = 1; };
                    class Defend { name = "Defend"; value = "DEFEND"; };
                    class Delay { name = "Delay"; value = "DELAY"; };
                    class Recon { name = "Recon"; value = "RECON"; };
                    class Raid { name = "Raid"; value = "RAID"; };
                    class Screen { name = "Screen"; value = "SCREEN"; };
                    class Deny { name = "Deny"; value = "DENY"; };
                };
            };
            class Priority
            {
                displayName = "Priority (1-100)";
                typeName = "NUMBER";
                defaultValue = "50";
            };
            class Radius
            {
                displayName = "Objective Radius";
                typeName = "NUMBER";
                defaultValue = "200";
            };
            class Active
            {
                displayName = "Active";
                typeName = "BOOL";
                defaultValue = "true";
            };
        };
    };

    class ARTIC_Module_Site: ARTIC_Module_Base
    {
        scope = 2;
        displayName = "Site";
        function = "ARTIC_fnc_moduleSite";
        class Arguments: ArgumentsBaseUnits
        {
            class SiteId
            {
                displayName = "Site ID";
                typeName = "STRING";
                defaultValue = "SITE_1";
            };
            class SiteName
            {
                displayName = "Site Name";
                typeName = "STRING";
                defaultValue = "Site";
            };
            class SiteType
            {
                displayName = "Site Type";
                class values
                {
                    class Town { name = "Town / Settlement"; value = "TOWN"; default = 1; };
                    class Base { name = "Base / FOB"; value = "BASE"; };
                    class Airfield { name = "Airfield"; value = "AIRFIELD"; };
                    class Bridge { name = "Bridge / Crossing"; value = "BRIDGE"; };
                    class Depot { name = "Supply Depot"; value = "DEPOT"; };
                    class Radar { name = "Radar / Sensor Site"; value = "RADAR"; };
                    class Strongpoint { name = "Strongpoint"; value = "STRONGPOINT"; };
                    class OP { name = "Observation Post"; value = "OP"; };
                };
            };
            class StrategicValue
            {
                displayName = "Strategic Value (1-100)";
                typeName = "NUMBER";
                defaultValue = "50";
            };
            class Defensibility
            {
                displayName = "Defensibility (0-1)";
                typeName = "NUMBER";
                defaultValue = "0.5";
            };
            class SupplyValue
            {
                displayName = "Supply Value (0-100)";
                typeName = "NUMBER";
                defaultValue = "0";
            };
            class Radius
            {
                displayName = "Site Radius";
                typeName = "NUMBER";
                defaultValue = "150";
            };
        };
    };

    class ARTIC_Module_AO: ARTIC_Module_Base
    {
        scope = 2;
        displayName = "Area of Operations";
        function = "ARTIC_fnc_moduleAO";
        class Arguments: ArgumentsBaseUnits
        {
            class AOId
            {
                displayName = "AO ID";
                typeName = "STRING";
                defaultValue = "AO_1";
            };
            class AOName
            {
                displayName = "AO Name";
                typeName = "STRING";
                defaultValue = "Area of Operations";
            };
            class Radius
            {
                displayName = "Radius";
                typeName = "NUMBER";
                defaultValue = "3000";
            };
        };
    };

    class ARTIC_Module_Frontline: ARTIC_Module_Base
    {
        scope = 2;
        displayName = "Frontline Reference";
        function = "ARTIC_fnc_moduleFrontline";
        class Arguments: ArgumentsBaseUnits
        {
            class FrontId
            {
                displayName = "Front ID";
                typeName = "STRING";
                defaultValue = "FRONT_1";
            };
            class Direction
            {
                displayName = "Friendly-to-Enemy Direction";
                typeName = "NUMBER";
                defaultValue = "0";
            };
            class Width
            {
                displayName = "Front Width";
                typeName = "NUMBER";
                defaultValue = "2000";
            };
        };
    };

    class ARTIC_Module_Reserve: ARTIC_Module_Base
    {
        scope = 2;
        displayName = "Reserve Assignment";
        function = "ARTIC_fnc_moduleReserve";
        class Arguments: ArgumentsBaseUnits
        {
            class ReserveLevel
            {
                displayName = "Reserve Level";
                class values
                {
                    class Commander { name = "Commander Reserve"; value = "COMMANDER"; default = 1; };
                    class Formation { name = "Formation Reserve"; value = "FORMATION"; };
                };
            };
        };
    };

    class ARTIC_Module_Support: ARTIC_Module_Base
    {
        scope = 2;
        displayName = "Support Asset";
        function = "ARTIC_fnc_moduleSupport";
        class Arguments: ArgumentsBaseUnits
        {
            class SupportId
            {
                displayName = "Support ID";
                typeName = "STRING";
                defaultValue = "SUPPORT_1";
            };
            class SupportRole
            {
                displayName = "Role";
                class values
                {
                    class Artillery { name = "Artillery"; value = "ARTILLERY"; };
                    class Mortar { name = "Mortar"; value = "MORTAR"; default = 1; };
                    class CAS { name = "CAS"; value = "CAS"; };
                    class Transport { name = "Transport"; value = "TRANSPORT"; };
                    class Medical { name = "Medical"; value = "MEDICAL"; };
                    class Repair { name = "Repair"; value = "REPAIR"; };
                    class Ammo { name = "Ammunition"; value = "AMMO"; };
                    class Fuel { name = "Fuel"; value = "FUEL"; };
                    class Engineer { name = "Engineer"; value = "ENGINEER"; };
                    class UAS { name = "Recon UAS"; value = "RECON_UAS"; };
                    class FPVAP { name = "FPV Anti-Personnel"; value = "FPV_AP"; };
                    class FPVAT { name = "FPV Anti-Tank"; value = "FPV_AT"; };
                    class UASMixed { name = "UAS Mixed / Drone Section"; value = "UAS_MIXED"; };
                    class QRF { name = "QRF"; value = "QRF"; };
                };
            };
            class Priority
            {
                displayName = "Priority (1-100)";
                typeName = "NUMBER";
                defaultValue = "50";
            };
            class AmmoClass
            {
                displayName = "Artillery Ammo Override";
                description = "Optional magazine classname. Leave empty to auto-detect artillery ammunition.";
                typeName = "STRING";
                defaultValue = "";
            };
            class Rounds
            {
                displayName = "Default Fire Mission Rounds";
                typeName = "NUMBER";
                defaultValue = "4";
            };
        };
    };

    class ARTIC_Module_RoleOverride: ARTIC_Module_Base
    {
        scope = 2;
        displayName = "Capability / Role Override";
        function = "ARTIC_fnc_moduleRoleOverride";
        class Arguments: ArgumentsBaseUnits
        {
            class Roles
            {
                displayName = "Roles";
                description = "Comma-separated roles, e.g. ARTILLERY,TRANSPORT or RECON,QRF.";
                typeName = "STRING";
                defaultValue = "";
            };
        };
    };
};

class CfgRemoteExec
{
    class Functions
    {
        class ARTIC_fnc_consumeUASItem
        {
            allowedTargets = 0;
            jip = 0;
        };
        class ARTIC_fnc_localArtilleryFire
        {
            allowedTargets = 0;
            jip = 0;
        };
    };
};
