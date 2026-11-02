params [["_group",grpNull,[grpNull]],["_condition","",[""]],["_seenOrderAt",-1e6,[0]]];
if (isNull _group) exitWith {true};
private _order=toUpper (_group getVariable ["ARTIC_executionOrderType",""]);
private _issued=_group getVariable ["ARTIC_orderIssuedAt",-1e6];
private _failure=_group getVariable ["ARTIC_planFailureReason",""];
switch (toUpper _condition) do {
 case "GROUP_GONE": {({alive _x} count units _group) isEqualTo 0};
 case "HAS_ORDER": {_order isNotEqualTo ""};
 case "ORDER_CHANGED": {_issued > _seenOrderAt};
 case "FAILURE": {_failure isNotEqualTo ""};
 case "TYPE_MOVE": {_order in ["MOVE","SEIZE","RECON","SCREEN"]};
 case "TYPE_FIX": {_order in ["FIX","SUPPORT"]};
 case "TYPE_MANOEUVRE": {_order in ["ATTACK","RAID"] && {(_group getVariable ["ARTIC_schemeRole",""]) in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT"]}};
 case "TYPE_BLOCK": {_order isEqualTo "BLOCK"};
 case "TYPE_RESERVE": {_order isEqualTo "RESERVE"};
 case "TYPE_DEFEND": {_order isEqualTo "DEFEND"};
 case "TYPE_WITHDRAW": {_order isEqualTo "DELAY"};
 case "AT_POSITION": {
    private _p=_group getVariable ["ARTIC_executionOrderPos",[]];
    _p isNotEqualTo [] && {(leader _group distance2D _p) <= 35}
 };
 default {false};
}
