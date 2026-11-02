params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {};
_group setVariable ["ARTIC_executionOrderType","",true];
_group setVariable ["ARTIC_executionOrderPos",[],true];
_group setVariable ["ARTIC_executionOrderRadius",150,true];
_group setVariable ["ARTIC_executionFallback",[],true];
_group setVariable ["ARTIC_orderType","",true];
_group setVariable ["ARTIC_orderPos",[],true];
_group setVariable ["ARTIC_orderRadius",150,true];
_group setVariable ["ARTIC_orderFallback",[],true];
_group setVariable ["ARTIC_repositionForAttack",false,true];

// Restore vanilla FSM only when ARTIC actually releases this group entirely.
if (local _group) then {
    {
        if (local _x && {_x getVariable ["ARTIC_fsmDisabledByARTIC",false]}) then {
            _x enableAI "FSM";
            _x setVariable ["ARTIC_fsmDisabledByARTIC",false,false];
        };
    } forEach units _group;
    if (_group getVariable ["ARTIC_autoAttackDisabledByARTIC",false]) then {
        _group enableAttack true;
        _group setVariable ["ARTIC_autoAttackDisabledByARTIC",false,false];
    };
};
