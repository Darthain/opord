params [["_commanderId","",[""]],["_nodeId","",[""]],["_condition","",[""]]];
private _n=[_commanderId,_nodeId] call ARTIC_fnc_findFormationNode;
if ((count _n) isEqualTo 0) exitWith {true};
private _groups=(_n getOrDefault ["groups",[]]) select {!isNull _x && {{alive _x} count units _x > 0}};
private _intent=_n getOrDefault ["intent",""];
private _failures=_groups select {(_x getVariable ["ARTIC_planFailureReason",""]) isNotEqualTo ""};
switch (toUpper _condition) do {
 case "NODE_GONE": {(count _n) isEqualTo 0};
 case "HAS_INTENT": {_intent isNotEqualTo "" && {(_n getOrDefault ["intentPos",[]]) isNotEqualTo []}};
 case "TACTICAL_FAILURE": {_failures isNotEqualTo []};
 case "EXECUTION_ARMED": {_groups isNotEqualTo [] && (({_x getVariable ["ARTIC_tacticalExecutionArmed",false]} count _groups) isEqualTo (count _groups))};
 case "ALL_DEPLOYED": {
    _groups isNotEqualTo [] && (({private _p=_x getVariable ["ARTIC_battleDeploymentPos",[]]; _p isEqualTo [] || {(leader _x distance2D _p) <= 45}} count _groups) isEqualTo (count _groups))
 };
 case "OBJECTIVE_COMPLETE": {false};
 default {false};
}
