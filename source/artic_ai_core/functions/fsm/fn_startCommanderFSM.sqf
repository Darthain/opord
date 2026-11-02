params [["_commanderId","",[""]]];
if (!isServer || {_commanderId isEqualTo ""}) exitWith {0};
private _c = ARTIC_Commanders getOrDefault [_commanderId,createHashMap];
if ((count _c) isEqualTo 0) exitWith {0};
private _logic = _c getOrDefault ["logic",objNull];
if (isNull _logic) exitWith {0};
private _old = _logic getVariable ["ARTIC_commanderFSM",0];
if (_old > 0 && {!completedFSM _old}) exitWith {_old};
private _h = [_commanderId] execFSM "\\artic_ai_core\\fsm\\ARTIC_Commander.fsm";
_logic setVariable ["ARTIC_commanderFSM",_h,false];
_h
