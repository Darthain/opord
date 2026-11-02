// Copyright: Erlend Kristensen(c) 2023, learnbymistake@gmail.com
// BSD 3-Clause License     
// Author:         Leo Hartgen (Tally-1)
// Author links:   
//              https://github.com/Tally-1, 
//              https://thehartgen.web.app/projects/, 
//              https://www.fiverr.com/hartgen_dev/script-anything-you-can-think-of-in-arma-3

// OPORD: replaces the removed headless-client block (BSD-3-Clause, OPORD contributors).
// Soldier FSM runs on the first connected headless client if there is one, otherwise on
// the server. When a headless client runs it, the server only calls SFSM_fnc_initSettings.
// If that headless client disconnects, SFSM_fnc_hcWatch makes the server run this function again.

// Tally: Will be updated in the post-config 
SFSM_aceLoaded = false;

if (isServer) then {
    [] call SFSM_fnc_selectRunner;
    [] spawn SFSM_fnc_coexistCheck;
} else {
    private _until = diag_tickTime + 60;
    waitUntil {sleep 1; !isNil "SFSM_runnerOwner" || {diag_tickTime > _until}};
};

private _runner = missionNamespace getVariable ["SFSM_runnerOwner", 2];

if (isServer && {_runner > 2}) exitWith {
    diag_log "***soldier FSM * server exited, headless client used***";
    [] call SFSM_fnc_initSettings;
};

if (!isServer && {_runner != clientOwner}) exitWith {
    diag_log "***soldier FSM * this headless client is not the selected runner***";
};

if (!isServer) then {diag_log "***soldier FSM * Headless Client Loaded***"};

// Forcing unscheduled call
// See leopard20s comment at the bottom of this page:
// https://community.bistudio.com/wiki/call
isNil{
    [] call SFSM_fnc_initSettings;
    [] call SFSM_fnc_postConfig;

    {[_x] call SFSM_fnc_InitMan}         forEach allUnits;
    {[_x] call SFSM_fnc_InitGroup}       forEach allGroups;
    {[_x] call SFSM_fnc_initVehicle}     forEach vehicles;
    {_x   call SFSM_fnc_curatorEH}       forEach allCurators;
    []    call SFSM_fnc_initFIPOsAndAZs;
    []    call SFSM_fnc_unitKilled; 
    []    call SFSM_fnc_unitCreated;
    []    call SFSM_fnc_projectileCreated;
    []    call SFSM_fnc_buildingDestroyedEH;
    []    call SFSM_fnc_speechEventsMan;
    []    call FIPO_fnc_fipoStances;
    []    call SFSM_fnc_animationMaps;
    []    call SFSM_fnc_stancePosMap;
    []    call SFSM_fnc_initAttackAnims;
    []    call SFSM_fnc_antiRubberBand;
    []    call SFSM_fnc_ACE_MedicalCBA;
    []    call SFSM_fnc_storeMoveDataAllMen;

    {[_x] call SFSM_fnc_initVirtualZone} forEach (entities "SFSM_VZ");

    // May move these lines to a separate function if more non-medical
    // ACE / CBA eventhandlers are added.
    [
        "ace_captiveStatusChanged", 
        {_this call SFSM_fnc_ACE_onCaptiveChange;}
    
    ] call CBA_fnc_addEventHandler;
    
    [
        "fipo_getIn", 
        {isNil{_this call SFSM_fnc_onFipoGetIn}}
    
    ] call CBA_fnc_addEventHandler;

    [
        "new_battle", 
        {isNil{_this call SFSM_fnc_activateBattleVzs}}
    
    ] call CBA_fnc_addEventHandler;
    
};

sleep 0.1;

[] spawn SFSM_fnc_updateVirtualZones;
[] spawn SFSM_fnc_TaskManager;
[] spawn SFSM_fnc_fipoManager;
[] spawn SFSM_fnc_AZmanager;
// [] spawn SFSM_fnc_moraleUpdater;

/* --------comment by Tally----------
unitKilled and unitCreated are mission eventhandlers.
MissionEventHandlers only execute locally hence
whatever code is ran by them should be remoted to the HC if present.

This can be done dynamically by getting the owner of the unit and 
using remoteExec on the netId, if the netId is the server then the
function will execute as normal, if not then the function will be executed by
the HC.
*/

// this fnc is run locally, hence a global declaration is needed for those clients
// that does not have SFSM loaded
missionNamespace setVariable ["Tcore_fnc_setTextTexture",Tcore_fnc_setTextTexture, true];

diag_log "***soldier FSM * server loaded***";

// ["new_battle", {}] call CBA_fnc_addEventHandler;
[] call SFSM_fnc_logSettings;

//Making sure all VR indicators are deleted 
{if(_x getVariable ['fipo_ind', false])then{deleteVehicle _x}} forEach (entities "CAManBase");