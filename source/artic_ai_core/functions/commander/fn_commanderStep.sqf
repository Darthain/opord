params [["_commander",createHashMap,[createHashMap]]];
if (!isServer || {(count _commander) isEqualTo 0}) exitWith {};

private _now = time;
private _last = _commander getOrDefault ["lastDecision",-1000];
private _interval = _commander getOrDefault ["decisionInterval",20];

if ((_commander getOrDefault ["orbat",[]]) isEqualTo []) then {[_commander] call ARTIC_fnc_rebuildORBAT;};
private _reports = [_commander] call ARTIC_fnc_updateCommanderIntel;
private _groundObjs = _reports apply {_x select 0};
if ((count _groundObjs) >= 2) then {[_commander,_groundObjs,"GROUND"] call ARTIC_fnc_classifyBattlefields;};
[_commander] call ARTIC_fnc_drawCommanderDebug;

// v0.3.8: platoon movement runs every tick (not only on the 20 s decision cycle).
{[_x,_commander] call ARTIC_fnc_platoonMovementStep;} forEach (_commander getOrDefault ["orbat",[]]);

if ((_now - _last) < _interval) exitWith {};
_commander set ["lastDecision",_now];

private _logic = _commander get "logic";
private _syncedObjectives = (synchronizedObjects _logic) select {_x isKindOf "ARTIC_Module_Objective"};
private _candidates = [];
{
    private _id = _x getVariable ["ObjectiveId",""];
    private _obj = ARTIC_Objectives getOrDefault [_id,createHashMap];
    if ((count _obj) > 0) then {
        private _score = [_commander,_obj] call ARTIC_fnc_evaluateObjective;
        if (_score >= 0) then {_candidates pushBack [_score,_obj];};
    };
} forEach _syncedObjectives;

if (_candidates isEqualTo []) exitWith {[_commander] call ARTIC_fnc_considerUAS;};
_candidates sort false;
private _best = (_candidates select 0) select 1;
private _bestId = _best getOrDefault ["id",""];
private _current = _commander getOrDefault ["currentObjective",""];
private _lastAssign = _commander getOrDefault ["lastObjectiveAssignment",-1000];

// v0.3.20: strategic intent is persistent. Do NOT periodically rewrite the same
// ATTACK objective into subordinate groups every 120 s: the platoon layer may be in
// the middle of a rotated COA / RELEASE move and must remain the sole movement owner.
// Re-issue only when the objective itself changes or the commander's ORBAT gains/loses
// groups (so genuinely new groups can inherit the current intent).
private _ownedGroups = allGroups select {
    (_x getVariable ["ARTIC_commanderId",""]) isEqualTo (_commander getOrDefault ["id",""])
};
private _ownedIds = _ownedGroups apply {groupId _x};
_ownedIds sort true;
private _ownedSig = _ownedIds joinString "|";
private _lastOwnedSig = _commander getOrDefault ["lastAssignedGroupSignature",""];
private _orbatChanged = _ownedSig isNotEqualTo _lastOwnedSig;

if (_bestId isNotEqualTo _current || {_orbatChanged}) then {
    [_commander,_best] call ARTIC_fnc_assignObjective;
    _commander set ["lastObjectiveAssignment",_now];
    _commander set ["lastAssignedGroupSignature",_ownedSig];
};

[_commander] call ARTIC_fnc_considerUAS;
