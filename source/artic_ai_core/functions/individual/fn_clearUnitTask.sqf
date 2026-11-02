params [["_unit",objNull,[objNull]],["_releaseVanilla",true,[true]]];
if (isNull _unit) exitWith {};
_unit setVariable ["ARTIC_unitTask",[],false];
_unit setVariable ["ARTIC_unitTaskLastIssue",-1000,false];
_unit setVariable ["ARTIC_reactionState",[],false];
_unit setVariable ["ARTIC_reactionLastIssue",-1000,false];
_unit setVariable ["ARTIC_assaultPoint",[],false];
_unit setVariable ["ARTIC_speedApplied",-99,false];
_unit setVariable ["ARTIC_formLastTarget",[],false];
_unit setVariable ["ARTIC_formLastAim",[],false];
_unit setVariable ["ARTIC_formSettled",false,false];
_unit setVariable ["ARTIC_formStopped",false,false];
_unit setVariable ["ARTIC_formCatchUp",false,false];
if (local _unit) then {
    if (_releaseVanilla) then {_unit enableAI "AUTOCOMBAT";} else {_unit disableAI "AUTOCOMBAT";};
    _unit enableReload true;
    _unit forceSpeed -1;
    _unit setUnitPos "AUTO";
};
