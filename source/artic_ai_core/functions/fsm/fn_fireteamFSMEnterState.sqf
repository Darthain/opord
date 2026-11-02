params [["_group",grpNull,[grpNull]],["_teamId","A",[""]],["_state","",[""]]];
if (isNull _group) exitWith {};
private _team = toUpper _teamId;
private _key = format ["ARTIC_fireteamState_%1",_team];
private _old = _group getVariable [_key,""];
_group setVariable [_key,_state,false];
_group setVariable [format ["ARTIC_fireteamStateAt_%1",_team],time,false];
private _ready = _state in ["READY","BOUND_SET"];
_group setVariable [format ["ARTIC_fireteamReady_%1",_team],_ready,true];
if (_state isEqualTo "FAILED") then {
    if ((_group getVariable [format ["ARTIC_fireteamFailure_%1",_team],""]) isEqualTo "") then {
        _group setVariable [format ["ARTIC_fireteamFailure_%1",_team],"FSM_FAILED",true];
    };
};
if (_old isNotEqualTo _state) then {[format ["FT-%1 FSM %2 -> %3",_team,_old,_state],groupId _group] call ARTIC_fnc_debug;};
