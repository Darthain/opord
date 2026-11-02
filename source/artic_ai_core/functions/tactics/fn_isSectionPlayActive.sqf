/*
    ARTIC v0.3.30.1 - one definition of whether a section still has a tactical script alive.

    Optional plan/task arguments restrict the answer to a particular immutable task identity.
*/
params [
    ["_group",grpNull,[grpNull]],
    ["_planId","",[""]],
    ["_taskId","",[""]]
];
if (isNull _group) exitWith {false};

private _h = _group getVariable ["ARTIC_playHandle",scriptNull];
private _handleLive = !isNull _h && {!scriptDone _h};
private _currentPlanLive = (_group getVariable ["ARTIC_currentPlan",""]) isNotEqualTo "";

if (_planId isEqualTo "" && {_taskId isEqualTo ""}) exitWith {_handleLive || {_currentPlanLive}};

private _ownerPlan = _group getVariable ["ARTIC_playPlanId",""];
private _ownerTask = _group getVariable ["ARTIC_playTaskId",""];
private _identityMatches = (_planId isEqualTo "" || {_ownerPlan isEqualTo _planId})
    && {_taskId isEqualTo "" || {_ownerTask isEqualTo _taskId}};

private _currentIdentityMatches = (_group getVariable ["ARTIC_platoonPlanId",""]) isEqualTo _planId
    && {(_group getVariable ["ARTIC_sectionTaskId",""]) isEqualTo _taskId};

(_handleLive && {_identityMatches}) || {_currentPlanLive && {_currentIdentityMatches}}
