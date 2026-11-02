params [["_commanderId","",[""]],["_nodeId","",[""]],["_state","",[""]]];
private _n=[_commanderId,_nodeId] call ARTIC_fnc_findFormationNode;
if ((count _n) isEqualTo 0) exitWith {};
private _logic=_n getOrDefault ["logic",objNull]; if (isNull _logic) exitWith {};
private _old=_logic getVariable ["ARTIC_platoonFSMState",""];
_logic setVariable ["ARTIC_platoonFSMState",_state,false];
_logic setVariable ["ARTIC_platoonFSMStateAt",time,false];
if (_old isNotEqualTo _state) then {[format ["PLATOON FSM %1 -> %2",_old,_state],_nodeId] call ARTIC_fnc_debug;};
