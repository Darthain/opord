// Copyright (C) 2026 OPORD contributors
// BSD 3-Clause License. See LICENSE in this addon.

/*
*  SFSM_fnc_hcWatch
*  If the headless client running Soldier FSM disconnects, the server takes over:
*  SFSM_runnerOwner becomes 2 and the server runs the full Soldier FSM startup.
*  Arguments: none. Return: nothing. Server only.
*/
if (!isServer) exitWith {};

addMissionEventHandler ["PlayerDisconnected", {
    params ["", "", "", "", "_owner"];

    if (SFSM_runnerOwner > 2 && {_owner isEqualTo SFSM_runnerOwner}) then {
        removeMissionEventHandler ["PlayerDisconnected", _thisEventHandler];
        diag_log "***soldier FSM * headless client disconnected, server takes over***";
        missionNamespace setVariable ["SFSM_runnerOwner", 2, true];
        [] spawn SFSM_fnc_serverInit;
    };
}];
