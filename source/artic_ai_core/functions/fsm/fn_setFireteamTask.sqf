params [["_group",grpNull,[grpNull]],["_teamId","A",[""]],["_task",[],[[]]]];
if (isNull _group) exitWith {false};
private _team = toUpper _teamId;
if !(_team in ["A","B"]) exitWith {false};
private _check = [_task] call ARTIC_fnc_validateFireteamTask;
if !(_check select 0) exitWith {
    [format ["Rejected FT-%1 task: %2",_team,_check select 1],groupId _group] call ARTIC_fnc_debug;
    false
};
private _taskKey = format ["ARTIC_fireteamTask_%1",_team];
private _revKey = format ["ARTIC_fireteamTaskRev_%1",_team];
private _rev = (_group getVariable [_revKey,0]) + 1;
_group setVariable [_taskKey,+_task,true];
_group setVariable [_revKey,_rev,true];
_group setVariable [format ["ARTIC_fireteamReady_%1",_team],false,true];
true
