params [["_group",grpNull,[grpNull]],["_teamId","A",[""]]];
if (isNull _group) exitWith {[]};
[_group] call ARTIC_fnc_initFireteams;
private _key = if ((toUpper _teamId) isEqualTo "B") then {"ARTIC_fireteamMembersB"} else {"ARTIC_fireteamMembersA"};
(_group getVariable [_key,[]]) select {alive _x && {[_x] call ARTIC_fnc_isFit}}
