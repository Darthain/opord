params [["_commanderId","",[""]],["_state","",[""]]];
private _c=ARTIC_Commanders getOrDefault [_commanderId,createHashMap]; if ((count _c) isEqualTo 0) exitWith {};
private _logic=_c getOrDefault ["logic",objNull]; if (isNull _logic) exitWith {};
private _old=_logic getVariable ["ARTIC_commanderFSMState",""];
_logic setVariable ["ARTIC_commanderFSMState",_state,false];
_logic setVariable ["ARTIC_commanderFSMStateAt",time,false];
if (_state in ["MONITOR_OPERATION","ASSESS_SITUATION"]) then {_logic setVariable ["ARTIC_commanderFSMNextReview",time + (_c getOrDefault ["decisionInterval",20]),false];};
if (_old isNotEqualTo _state) then {[format ["COMMAND FSM %1 -> %2",_old,_state],_commanderId] call ARTIC_fnc_debug;};
