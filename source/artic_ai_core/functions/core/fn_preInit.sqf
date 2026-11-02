/*
    ARTIC AI v0.3.30.2-alpha
    Global bootstrap. Runs on every machine so local/HClient planners have the
    same doctrine/training data available.

    Mission-scoped registries are reset on every mission/preInit. This is
    deliberate: Eden preview objects are destroyed between previews, and
    preserving their object references caused stale support/UAS/commander data.
*/

ARTIC_VERSION = "0.3.30.2-alpha";

if (isNil "ARTIC_debug") then { ARTIC_debug = false; };
if (isNil "ARTIC_debugChat") then { ARTIC_debugChat = false; };
if (isNil "ARTIC_debugMarkers") then { ARTIC_debugMarkers = false; };

// Always rebuild mission-scoped state. Never carry object references from a
// previous Eden preview into the next one.
ARTIC_Commanders = createHashMap;
ARTIC_Objectives = createHashMap;
ARTIC_Sites = createHashMap;
ARTIC_AOs = createHashMap;
ARTIC_Frontlines = createHashMap;
ARTIC_SupportAssets = createHashMap;
ARTIC_RoleOverrides = createHashMap;
ARTIC_Battlefields = createHashMap;
ARTIC_ObstacleRegistry = [];
ARTIC_UASRequests = [];

call ARTIC_fnc_initDoctrineLibrary;

// Optional IEDD adapter. Registered during preInit so HC/local planners can
// request server-owned IED creation without losing early mission requests.
if (isServer) then {
    ["ARTIC_createIED", {_this call ARTIC_fnc_createIED}] call CBA_fnc_addEventHandler;
};

// v0.3.9: section formation system (guide + role slots + formation assessment).
// false = sections use Arma's engine formation (group move / doFollow) as before.
if (isNil "ARTIC_formationSystem") then {ARTIC_formationSystem = true;};

// v0.3.14: crow's foot is the forward-threat formation; false = VEE.
if (isNil "ARTIC_useCrowsFoot") then {ARTIC_useCrowsFoot = true;};

// v0.3.20 movement-authority boundary. While an ARTIC guide owns infantry movement,
// ARTIC owns the decision/FSM layer for EVERY local fit soldier. Arma retains MOVE/PATH
// for navmesh, obstacle avoidance and animation. This prevents subordinate vanilla FSM
// follow/formation behaviour from competing with ARTIC slot destinations.
if (isNil "ARTIC_controlWatchdog") then {ARTIC_controlWatchdog = true;};
if (isNil "ARTIC_takeInfantryFSMControl") then {ARTIC_takeInfantryFSMControl = true;};
// Backwards-compatible diagnostic switch from 0.3.19; no longer the primary control.
if (isNil "ARTIC_takeLeaderFSMControl") then {ARTIC_takeLeaderFSMControl = false;};

// v0.3.24/v0.3.26: plan stability and SBF quality. ARTIC_minSbfSight is retained
// for compatibility/diagnostics, but v0.3.26 no longer uses one anchor point as the
// binary assault gate. The planner evaluates aggregate visibility across a representative
// FIX fire line instead.
if (isNil "ARTIC_minSbfSight") then {ARTIC_minSbfSight = 0.4;};
if (isNil "ARTIC_preferredSbfCoverage") then {ARTIC_preferredSbfCoverage = 0.40;};
if (isNil "ARTIC_minSbfCoverage") then {ARTIC_minSbfCoverage = 0.25;};
if (isNil "ARTIC_limitedSbfCoverage") then {ARTIC_limitedSbfCoverage = 0.125;};
if (isNil "ARTIC_minSbfUsefulPoints") then {ARTIC_minSbfUsefulPoints = 2;};
if (isNil "ARTIC_contactCalls") then {ARTIC_contactCalls = true;}; // sections send contact calls to the platoon
if (isNil "ARTIC_hastyAttack") then {ARTIC_hastyAttack = true;};   // platoon reacts to contact with a hasty attack
// v0.3.27: corridor movement + tactical reassessment.
if (isNil "ARTIC_routeReplanSeconds") then {ARTIC_routeReplanSeconds = 35;};
if (isNil "ARTIC_routeCorridorWidth") then {ARTIC_routeCorridorWidth = 38;};
if (isNil "ARTIC_repositionPace") then {ARTIC_repositionPace = 2.7;};
if (isNil "ARTIC_deployPace") then {ARTIC_deployPace = 2.1;};
if (isNil "ARTIC_dynamicAttackSchemes") then {ARTIC_dynamicAttackSchemes = true;};

// v0.3.29: a manoeuvre element that has reported READY waits for the platoon-owned
// synchronization gate rather than self-releasing. Keep this generous enough for the
// opposite flank / block element to finish deployment without creating a false failure.
// v0.3.30: the PLATOON READY_CHECK owns readiness failure (below); the section-side wait is
// only a safety cap and must outlast ARTIC_readyCheckMaxSeconds.
if (isNil "ARTIC_hHourReadyTimeout") then {ARTIC_hHourReadyTimeout = 390;};

// v0.3.30 READY_CHECK: fail readiness only when deployment stops progressing.
if (isNil "ARTIC_readyMinSeconds") then {ARTIC_readyMinSeconds = 60;};
if (isNil "ARTIC_readyNoProgressTimeout") then {ARTIC_readyNoProgressTimeout = 45;};
if (isNil "ARTIC_readyCheckMaxSeconds") then {ARTIC_readyCheckMaxSeconds = 300;};
// v0.3.30 movement legs: distance-scaled deadline + progress watchdog
if (isNil "ARTIC_moveTimeoutPace") then {ARTIC_moveTimeoutPace = 1.1;};          // m/s budgeted per leg
if (isNil "ARTIC_moveNoProgressSeconds") then {ARTIC_moveNoProgressSeconds = 40;};
// v0.3.30 fire control
if (isNil "ARTIC_fixFireMaxSeconds") then {ARTIC_fixFireMaxSeconds = 300;};      // sustained FIX fire cap
if (isNil "ARTIC_blockMaxSeconds") then {ARTIC_blockMaxSeconds = 480;};
if (isNil "ARTIC_blockLiftDistance") then {ARTIC_blockLiftDistance = 60;};      // no BLOCK fire within this of friendly manoeuvre
// v0.3.30 contact-aware replanning
if (isNil "ARTIC_contactAwareReplan") then {ARTIC_contactAwareReplan = true;};
if (isNil "ARTIC_contactReplanDistance") then {ARTIC_contactReplanDistance = 150;}; // manoeuvre engaged closer than this before H-hour -> replan
if (isNil "ARTIC_engagedDistance") then {ARTIC_engagedDistance = 200;};
if (isNil "ARTIC_closeContactDistance") then {ARTIC_closeContactDistance = 100;};
// v0.3.30.2 reposition safety / BLOCK observation
if (isNil "ARTIC_repositionStandoff") then {ARTIC_repositionStandoff = 150;};  // reposition march may not pass closer than this to known enemy
if (isNil "ARTIC_blockObsSearch") then {ARTIC_blockObsSearch = 60;};          // BLOCK searches this far forward for an observation line
if (isNil "ARTIC_blockMinStandoff") then {ARTIC_blockMinStandoff = 80;};      // ...but never closer than this to known enemy

// v0.3.29 live FSM migration. The platoon CBA state machine now owns plan identity,
// role immutability, READY/H-hour and failure-driven plan supersession. Section/fireteam
// movement remains on the proven v0.3.27 executor for this migration phase.
if (isNil "ARTIC_useFSMHierarchy") then {ARTIC_useFSMHierarchy = true;};
if (isNil "ARTIC_useFireteamFSM") then {ARTIC_useFireteamFSM = false;};
ARTIC_PlatoonCBAStateMachine = locationNull;
ARTIC_fsmEventsRegistered = false;
