params [["_commanderId","",[""]],["_condition","",[""]]];
private _c=ARTIC_Commanders getOrDefault [_commanderId,createHashMap];
if ((count _c) isEqualTo 0) exitWith {true};
private _logic=_c getOrDefault ["logic",objNull];
switch (toUpper _condition) do {
 case "COMMANDER_GONE": {isNull _logic};
 case "ORBAT_READY": {(_c getOrDefault ["orbat",[]]) isNotEqualTo []};
 case "HAS_OBJECTIVE": {(_c getOrDefault ["currentObjective",""]) isNotEqualTo ""};
 case "REVIEW_DUE": {time >= (_logic getVariable ["ARTIC_commanderFSMNextReview",0])};
 case "REASSESS_REQUESTED": {_logic getVariable ["ARTIC_commanderFSMReassess",false]};
 case "OBJECTIVE_COMPLETE": {false};
 default {false};
}
