// Copyright (C) 2026 OPORD contributors
// BSD 3-Clause License. See LICENSE in this addon.

/*
*  SFSM_fnc_selectRunner
*  Decides which machine runs Soldier FSM: the first connected headless client when the CBA
*  setting SFSM_runOnHeadlessClient is on and one is present, otherwise the server (owner 2).
*  Publishes the result as SFSM_runnerOwner. Runs once; later calls do nothing.
*  Arguments: none. Return: NUMBER, owner ID of the runner. Server only, scheduled.
*/
if (!isServer) exitWith {};
if (!isNil "SFSM_runnerOwner") exitWith {SFSM_runnerOwner};

private _runner = 2;

if (missionNamespace getVariable ["SFSM_runOnHeadlessClient", true]) then {
    // A headless client slot exists: give it a short grace period to connect.
    if (count (entities "HeadlessClient_F") > 0) then {
        private _until = diag_tickTime + 10;
        waitUntil {
            sleep 0.5;
            (count (call SFSM_fnc_connectedHCs) > 0) || {diag_tickTime > _until}
        };
    };

    private _hcs = call SFSM_fnc_connectedHCs;
    if (count _hcs > 0) then {_runner = _hcs select 0};
};

missionNamespace setVariable ["SFSM_runnerOwner", _runner, true];

if (_runner > 2) then {
    diag_log format ["***soldier FSM * running on headless client (owner %1)***", _runner];
    [] spawn SFSM_fnc_hcWatch;
} else {
    diag_log "***soldier FSM * running on the server***";
};

_runner
