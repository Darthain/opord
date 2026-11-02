params [["_commanderId","",[""]],["_nodeId","",[""]]];
if (!isServer) exitWith {0};
private _n = [_commanderId,_nodeId] call ARTIC_fnc_findFormationNode;
if ((count _n) isEqualTo 0) exitWith {0};
private _logic = _n getOrDefault ["logic",objNull];
if (isNull _logic) exitWith {0};
private _old = _logic getVariable ["ARTIC_platoonFSM",0];
if (_old > 0 && {!completedFSM _old}) exitWith {_old};
private _h = [_commanderId,_nodeId] execFSM "\\artic_ai_core\\fsm\\ARTIC_Platoon.fsm";
_logic setVariable ["ARTIC_platoonFSM",_h,false];
_h
