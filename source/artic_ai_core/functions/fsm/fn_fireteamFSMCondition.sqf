params [["_group",grpNull,[grpNull]],["_teamId","A",[""]],["_condition","",[""]],["_seenRev",-1,[0]]];
if (isNull _group) exitWith {true};
private _team = toUpper _teamId;
private _task = _group getVariable [format ["ARTIC_fireteamTask_%1",_team],[]];
private _rev = _group getVariable [format ["ARTIC_fireteamTaskRev_%1",_team],0];
private _type = if (_task isEqualTo []) then {""} else {[_task,"TYPE",""] call ARTIC_fnc_fireteamTaskGet};
private _members = [_group,_team] call ARTIC_fnc_getFireteamMembers;
private _cond = toUpper _condition;
switch _cond do {
    case "GROUP_GONE": {({alive _x} count units _group) isEqualTo 0};
    case "HAS_TASK": {_task isNotEqualTo []};
    case "TASK_CHANGED": {_rev > _seenRev};
    case "NO_TASK": {_task isEqualTo []};
    case "TEAM_INEFFECTIVE": {(count _members) < 2};
    case "DEADLINE_EXPIRED": {private _d=[_task,"DEADLINE",-1] call ARTIC_fnc_fireteamTaskGet; _d > 0 && {time > _d}};
    case "ABORT": {_group getVariable [format ["ARTIC_fireteamAbort_%1",_team],false]};
    case "TYPE_MOVE": {_type in ["MOVE","FOLLOW"]};
    case "TYPE_BOUND": {_type isEqualTo "BOUND"};
    case "TYPE_DEPLOY": {_type in ["DEPLOY","OBSERVE","SUPPRESS","ENGAGE","BLOCK","HOLD"]};
    case "TYPE_ASSAULT": {_type isEqualTo "ASSAULT"};
    case "TYPE_WITHDRAW": {_type isEqualTo "WITHDRAW"};
    case "TYPE_REORGANISE": {_type isEqualTo "REORGANISE"};
    case "AT_DESTINATION": {
        private _dest=[_task,"DESTINATION",[]] call ARTIC_fnc_fireteamTaskGet;
        private _tol=[_task,"TOLERANCE",12] call ARTIC_fnc_fireteamTaskGet;
        _dest isNotEqualTo [] && {(count (_members select {(_x distance2D _dest) <= (_tol + 8)})) >= ceil ((count _members) * 0.75)}
    };
    case "SYNC_RELEASED": {
        private _sync=[_task,"SYNCKEY",""] call ARTIC_fnc_fireteamTaskGet;
        _sync isNotEqualTo "" && {_group getVariable [format ["ARTIC_sync_%1",_sync],false]}
    };
    default {false};
}
