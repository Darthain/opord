params [["_group",grpNull,[grpNull]],["_teamId","A",[""]]];
if (isNull _group || {!local _group}) exitWith {0};
private _team = toUpper _teamId;
if !(_team in ["A","B"]) exitWith {0};
private _key = format ["ARTIC_fireteamFSM_%1",_team];
private _old = _group getVariable [_key,0];
if (_old > 0 && {!completedFSM _old}) exitWith {_old};
private _h = [_group,_team] execFSM "\\artic_ai_core\\fsm\\ARTIC_Fireteam.fsm";
_group setVariable [_key,_h,false];
_h
