params [["_group",grpNull,[grpNull]],["_state","",[""]]];
if (isNull _group) exitWith {};
private _old=_group getVariable ["ARTIC_sectionFSMState",""];
_group setVariable ["ARTIC_sectionFSMState",_state,false];
_group setVariable ["ARTIC_sectionFSMStateAt",time,false];
if (_old isNotEqualTo _state) then {[format ["SECTION FSM %1 -> %2",_old,_state],groupId _group] call ARTIC_fnc_debug;};
