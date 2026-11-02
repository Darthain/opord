params [["_group",grpNull,[grpNull]],["_center",[],[[]]]];
if (isNull _group || {!local _group}) exitWith {false};
if ((_group getVariable ["ARTIC_currentPlan",""]) isNotEqualTo "") exitWith {false};

_group setVariable ["ARTIC_currentPlan","DEFEND_BATTLE_POSITION",true];
_group setVariable ["ARTIC_planOwner",clientOwner,true];
_group setBehaviourStrong "COMBAT";
_group setCombatMode "RED";

private _objects = (_group getVariable ["ARTIC_battlePositionObjects",[]]) select {!isNull _x};
private _men = (units _group) select {alive _x && {isNull objectParent _x}};

if (_objects isNotEqualTo []) then {
    {
        private _obj = _objects select (_forEachIndex mod count _objects);
        private _p = getPosATL _obj;
        if (local _x) then {
            _x disableAI "AUTOCOMBAT";
            _x doMove (_p getPos [2 + random 3,random 360]);
            _x setUnitPosWeak "MIDDLE";
        };
    } forEach _men;
};

sleep 8;
private _target = [_group] call ARTIC_fnc_findTarget;
if (!isNull _target) then {
    [_group,_target,18] spawn ARTIC_fnc_suppressElement;
};

// DEFEND is a persistent intent; release the active-plan lock so the group can
// reassess targets without abandoning its prepared position.
[_group] call ARTIC_fnc_finishPlan;
true
