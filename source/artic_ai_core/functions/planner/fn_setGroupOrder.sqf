params [
    ["_group",grpNull,[grpNull]],
    ["_type","",[""]],
    ["_position",[],[[]]],
    ["_radius",150,[0]],
    ["_commanderId","",[""]],
    ["_fallback",[],[[]]]
];
if (isNull _group) exitWith {};

private _execType = toUpper _type;
// Strategic intent and executable group order are deliberately separate. The
// executable order is only consulted after platoon-guide ownership releases the group.
_group setVariable ["ARTIC_executionOrderType",_execType,true];
_group setVariable ["ARTIC_executionOrderPos",+_position,true];
_group setVariable ["ARTIC_executionOrderRadius",_radius,true];
_group setVariable ["ARTIC_executionFallback",+_fallback,true];
// Legacy aliases retained for support adapters and backwards compatibility.
_group setVariable ["ARTIC_orderType",_execType,true];
_group setVariable ["ARTIC_orderPos",+_position,true];
_group setVariable ["ARTIC_orderRadius",_radius,true];
_group setVariable ["ARTIC_orderCommander",_commanderId,true];
_group setVariable ["ARTIC_orderFallback",+_fallback,true];
_group setVariable ["ARTIC_orderIssuedAt",time,true];
_group setVariable ["ARTIC_enabled",true,true];


// ARTIC guide movement does not use group waypoints. Strip any mission/Zeus waypoint
// at ownership handover when this machine owns the group; the local watchdog repeats
// the check after locality migration.
if (local _group) then {
    [_group] call ARTIC_fnc_clearGroupWaypoints;
    // ARTIC orders own group engagement selection; vanilla auto-attack may otherwise
    // assign ATTACK commands to subordinates as soon as contacts become known.
    _group enableAttack false;
    _group setVariable ["ARTIC_autoAttackDisabledByARTIC",true,false];
};
_group setVariable ["ARTIC_cmdLastProgressAt",time,false];
_group setVariable ["ARTIC_cmdWatchPos",getPosATL leader _group,false];
