/*
    ARTIC v0.3.30 - BLOCK element (envelopment isolation / holding element).

    Up to 0.3.29 BLOCK walked to its deployment point as a formation, reported ready the moment
    it was within 35 m, and switched to COMBAT/RED: no firing positions, no orientation on the
    enemy's escape routes and no fire control. Both envelopment schemes depend on it.

    Sequence (groupStep brings the section to ARTIC_battleDeploymentPos first):
      1. OCCUPY  - a fire line through the deployment point (ARTIC_fnc_buildFireLine), each
                   shooter's point scored on sight of the objective AND of the likely enemy
                   withdrawal lanes (ARTIC_fnc_findWithdrawalLanes; lanes that cross a friendly
                   manoeuvre corridor are excluded). Primary lane gets up to two watchers (MG
                   first), the secondary lane one. Progress -> ARTIC_blockProgressAt.
      2. READY   - ARTIC_blockReady only when >= 75 % are on their points (or occupation time is
                   up) AND at least half the shooters can see the objective or a lane.
                   Otherwise (v0.3.30.2) a bounded search for an observation line up to 60 m
                   forward, 80 m standoff from known enemy; none -> BLOCK_NO_LOS at once.
      3. HOLD    - GREEN, lane watchers watching their lane, the rest the objective.
                   Open fire on: H-hour for this plan, an enemy seen inside a withdrawal lane,
                   the section being engaged, or a platoon fire redirect.
      4. ENGAGE  - RED. Lane watchers engage enemies inside their lane; others engage visible
                   enemies, otherwise area fire on known positions. Fire is never placed on a
                   point within ARTIC_blockLiftDistance (60 m) of a friendly manoeuvre soldier;
                   when the manoeuvre is on the objective BLOCK lifts and covers the lanes only.
      5. END     - manoeuvre sections finished (10 s after the last manoeuvre play ends),
                   ARTIC_blockMaxSeconds, or the plan is replaced / aborted (quiet end).
*/
params [["_group",grpNull,[grpNull]],["_target",objNull,[objNull]]];
if (isNull _group || {!local _group}) exitWith {false};
if ((_group getVariable ["ARTIC_currentPlan",""]) isNotEqualTo "") exitWith {false};

private _planId = _group getVariable ["ARTIC_platoonPlanId",""];
private _taskId = _group getVariable ["ARTIC_sectionTaskId",""];
if (_planId isNotEqualTo "" && {(_group getVariable ["ARTIC_planAbortId",""]) isEqualTo _planId}) exitWith {false};
private _fsm = (missionNamespace getVariable ["ARTIC_useFSMHierarchy",true]) && {_planId isNotEqualTo ""};
private _stale = {[_group,_planId,_taskId,true] call ARTIC_fnc_isPlayStale};

private _caps = [_group] call ARTIC_fnc_scanGroupCapabilities;
private _alive = (_caps getOrDefault ["alive",[]]) select {alive _x && {local _x}};
if ((count _alive) < 2) exitWith {false};
private _reserve = (_caps getOrDefault ["medic",[]]) select {_x in _alive};
private _shooters = _alive - _reserve;
if ((count _shooters) < 2) then {_shooters = +_alive; _reserve = [];};
private _mgs = (_caps getOrDefault ["mg",[]]) select {_x in _shooters};
_shooters = _mgs + (_shooters - _mgs);

private _focus = _group getVariable ["ARTIC_battleFocus",[]];
if (_focus isEqualTo []) exitWith {false};
private _axis = _group getVariable ["ARTIC_battleAxis",0];
private _anchor = _group getVariable ["ARTIC_battleDeploymentPos",[]];
if (_anchor isEqualTo []) then {_anchor = _group getVariable ["ARTIC_sectionReferencePos",getPosATL leader _group];};
_anchor = +_anchor;
_anchor set [2,0];
private _sector = _group getVariable ["ARTIC_battleFireSector",[]];
private _radius = if ((count _sector) isEqualTo 2) then {(((_sector select 0) distance2D (_sector select 1)) * 0.5) max 60} else {80};

// ---- known enemy picture -----------------------------------------------------------
private _threatPos = +(_group getVariable ["ARTIC_battleSightTargets",[]]);
private _threatObjs = [];
if ([_target] call ARTIC_fnc_isCombatEffectiveTarget) then {_threatObjs pushBack _target; _threatPos pushBack (getPosATL _target);};
{
    _x params ["_o","_p","_t"];
    if ((time - _t) < 240 && {_p isEqualType []} && {(count _p) >= 2}) then {
        if ((_threatPos findIf {(_x distance2D _p) < 10}) < 0) then {_threatPos pushBack _p;};
        if ([_o] call ARTIC_fnc_isCombatEffectiveTarget) then {_threatObjs pushBackUnique _o;};
    };
} forEach (_group getVariable ["ARTIC_sharedContacts",[]]);
if (_threatPos isEqualTo []) then {_threatPos = [+_focus];};

// ---- manoeuvre siblings and withdrawal lanes ---------------------------------------
private _formation = _group getVariable ["ARTIC_formationId",""];
private _siblings = allGroups select {
    _x isNotEqualTo _group && {side _x isEqualTo side _group}
    && {(_x getVariable ["ARTIC_formationId",""]) isEqualTo _formation}
    && {(_x getVariable ["ARTIC_schemeRole",""]) in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT","MANOEUVRE_AUTO"]}
};
private _keepOut = [];
{
    {_keepOut pushBack _x;} forEach (_x getVariable ["ARTIC_battleCorridor",[]]);
    private _fcl = _x getVariable ["ARTIC_battleFCLPos",[]];
    if (_fcl isNotEqualTo []) then {_keepOut pushBack _fcl;};
} forEach _siblings;
private _lanes = [_focus,_axis,_radius,_anchor,_keepOut,2] call ARTIC_fnc_findWithdrawalLanes;
private _lanePts = [];
{_lanePts pushBack (_x select 2); _lanePts pushBack (_x select 1);} forEach _lanes;

// ---- claim ---------------------------------------------------------------------------
if (_fsm && {!([_group,_planId,_taskId,"DEPLOYING","BLOCK_START"] call ARTIC_fnc_setSectionTaskState)}) exitWith {false};
_group setVariable ["ARTIC_currentPlan","BLOCKING_ACTION",true];
_group setVariable ["ARTIC_planOwner",clientOwner,true];
_group setVariable ["ARTIC_tacticalGuideActive",false,false];
_group setVariable ["ARTIC_movementPhase","COMBAT",false];
_group setVariable ["ARTIC_blockReady",false,true];
_group setVariable ["ARTIC_blockState","OCCUPY",true];
[_group,"ARTIC_blockProgressAt"] call ARTIC_fnc_markDeployProgress;
_group enableAttack false;
_group setBehaviourStrong "COMBAT";
_group setCombatMode "GREEN";
private _m = _group getVariable ["ARTIC_metrics",createHashMap];
_m set ["blockAttempts",(_m getOrDefault ["blockAttempts",0]) + 1];
_group setVariable ["ARTIC_metrics",_m,false];

private _clearLanes = {{_x setVariable ["ARTIC_blockLane",nil,false];} forEach (units _group);};
private _fail = {
    params ["_reason",["_cool",12]];
    _group setVariable ["ARTIC_blockState","FAILED",true];
    _group setVariable ["ARTIC_blockReady",false,true];
    _group setVariable ["ARTIC_planFailureReason",_reason,true];
    _group setVariable ["ARTIC_planFailureAt",time,true];
    if (_fsm) then {[_group,_reason] call ARTIC_fnc_signalSectionFailure;};
    call _clearLanes;
    [_group,_cool,_planId,_taskId] call ARTIC_fnc_finishPlan;
    false
};
private _quietEnd = {
    params [["_why","plan changed"]];
    _group setVariable ["ARTIC_blockReady",false,true];
    if ((_group getVariable ["ARTIC_blockState",""]) isNotEqualTo "FAILED") then {_group setVariable ["ARTIC_blockState","DONE",true];};
    call _clearLanes;
    if (local _group) then {
        [format ["BLOCK ended (%1)",_why],groupId _group] call ARTIC_fnc_debug;
        [_group,_planId,_taskId,format ["BLOCK %1",_why]] call ARTIC_fnc_endPlayQuietly;
    };
    false
};

private _laneTxt = if (_lanes isEqualTo []) then {"none observable clear of friendly corridors; covering the objective frontage"} else {
    (_lanes apply {format ["%1 (sight %2%%%3)",_x select 0,round (100 * (_x select 4)),["",", road"] select (_x select 5)]}) joinString ", "
};
[format ["BLOCK occupying at %1: withdrawal lanes %2",mapGridPosition _anchor,_laneTxt],groupId _group] call ARTIC_fnc_debug;

// ---- 1. occupy the fire line -------------------------------------------------------
private _line = [_group,_anchor,_focus,_threatPos + _lanePts,_shooters,_target,8] call ARTIC_fnc_buildFireLine;
private _firePoints = _line getOrDefault ["points",[]];
if (_firePoints isEqualTo []) exitWith {["BLOCK_NO_POSITION",12] call _fail};
private _reservePos = _anchor getPos [12,_focus getDir _anchor];
{if (alive _x && {local _x}) then {[_x,"HOLD",_reservePos,_target,400,6] call ARTIC_fnc_setUnitTask;};} forEach _reserve;

// lane watchers: primary lane up to two (MG first), secondary lane one
private _assigned = [];
{
    private _lane = _x;
    private _want = [2,1] select (_forEachIndex > 0);
    private _pool = _firePoints select {!((_x select 0) in _assigned)};
    _pool = [_pool,[],{
        ((([_x select 1,[_lane select 2,_lane select 1],2] call ARTIC_fnc_battleSight) select 0) * -10)
            + ([0,-3] select ((_x select 0) in _mgs))
    },"ASCEND"] call BIS_fnc_sortBy;
    {
        if (_forEachIndex < _want) then {
            (_x select 0) setVariable ["ARTIC_blockLane",[_lane select 0,_lane select 2,_lane select 1],false];
            _assigned pushBack (_x select 0);
        };
    } forEach _pool;
} forEach _lanes;

private _maxD = 0;
{_maxD = _maxD max ((_x select 0) distance2D (_x select 1));} forEach _firePoints;
private _occEnd = time + (((15 + _maxD / 1.2) max 20) min 90);
private _onPoint = {({alive (_x select 0) && {((_x select 0) distance2D (_x select 1)) < 4}} count _firePoints)};
private _lastOn = -1;
waitUntil {
    sleep 1;
    if (call _stale) exitWith {true};
    private _n = call _onPoint;
    if (_n > _lastOn) then {_lastOn = _n; [_group,"ARTIC_blockProgressAt"] call ARTIC_fnc_markDeployProgress;};
    time > _occEnd || {_n >= ceil ((count _firePoints) * 0.75)}
};
if (call _stale) exitWith {["plan changed during occupation"] call _quietEnd};

// ---- 2. observe ----------------------------------------------------------------------
// v0.3.30.2: if the line cannot see, search for an observation line up to
// ARTIC_blockObsSearch (60 m) forward of it (and 25 m either side), never closer than
// ARTIC_blockMinStandoff (80 m) to a known enemy position. Fail fast with BLOCK_NO_LOS when no
// such point sees anything, instead of a blind 20 m creep (0.3.30.1: 0/4 shooters saw from the
// planned BLOCK point; the creep could not fix a position 235 m back in urban terrain).
private _seePts = _threatPos + _lanePts;
private _sees = {params ["_u"]; (([getPosATL _u,_seePts,6] call ARTIC_fnc_battleSight) select 0) > 0};
private _losUnits = _shooters select {alive _x && {local _x} && {[_x] call _sees}};
private _need = ceil ((count (_shooters select {alive _x})) * 0.5);
if ((count _losUnits) < (_need max 1)) then {
    private _standoff = missionNamespace getVariable ["ARTIC_blockMinStandoff",80];
    private _reach = missionNamespace getVariable ["ARTIC_blockObsSearch",60];
    private _toObj = _anchor getDir _focus;
    private _bestP = [];
    private _bestS = 0;
    for "_fwd" from 20 to _reach step 20 do {
        {
            private _p = _anchor getPos [_fwd,_toObj];
            if ((abs _x) > 0.1) then {_p = _p getPos [abs _x,_toObj + ([90,-90] select (_x < 0))];};
            _p set [2,0];
            private _dMin = 1e9;
            {_dMin = _dMin min (_p distance2D _x);} forEach _threatPos;
            if (!(surfaceIsWater _p) && {_dMin >= _standoff}) then {
                private _sv = ([_p,_seePts,6] call ARTIC_fnc_battleSight) select 0;
                if (_sv > (_bestS + 0.05)) then {_bestS = _sv; _bestP = _p;};
            };
        } forEach [0,-25,25];
    };
    if (_bestP isEqualTo []) then {
        [format ["BLOCK: %1/%2 shooters see the objective or a lane, and no point within %3 m forward (standoff %4 m) sees it",count _losUnits,_need,_reach,_standoff],groupId _group] call ARTIC_fnc_debug;
    } else {
        [format ["BLOCK: %1/%2 shooters see the objective or a lane; moving the fire line %3 m to an observation point at %4 (sight %5%%)",
            count _losUnits,_need,round (_anchor distance2D _bestP),mapGridPosition _bestP,round (_bestS * 100)],groupId _group] call ARTIC_fnc_debug;
        _anchor = +_bestP;
        private _line2 = [_group,_anchor,_focus,_seePts,_shooters select {alive _x && {local _x}},_target,8] call ARTIC_fnc_buildFireLine;
        if ((_line2 getOrDefault ["points",[]]) isNotEqualTo []) then {_firePoints = _line2 get "points";};
        [_group,"ARTIC_blockProgressAt"] call ARTIC_fnc_markDeployProgress;
        private _maxD2 = 0;
        {_maxD2 = _maxD2 max ((_x select 0) distance2D (_x select 1));} forEach _firePoints;
        private _cEnd = time + (((15 + _maxD2 / 1.2) max 20) min 75);
        private _lastOn2 = -1;
        waitUntil {
            sleep 1;
            if (call _stale) exitWith {true};
            private _n2 = call _onPoint;
            if (_n2 > _lastOn2) then {_lastOn2 = _n2; [_group,"ARTIC_blockProgressAt"] call ARTIC_fnc_markDeployProgress;};
            time > _cEnd || {_n2 >= ceil ((count _firePoints) * 0.75)}
        };
        _losUnits = _shooters select {alive _x && {local _x} && {[_x] call _sees}};
    };
};
if (call _stale) exitWith {["plan changed while observing"] call _quietEnd};
if ((count _losUnits) < (_need max 1)) exitWith {
    [format ["BLOCK failed to observe the objective or a withdrawal lane (%1/%2 shooters see)",count _losUnits,_need],groupId _group] call ARTIC_fnc_debug;
    ["BLOCK_NO_LOS",12] call _fail
};

// ---- 3. ready, hold fire -------------------------------------------------------------
_group setVariable ["ARTIC_blockState","READY_HOLD_FIRE",true];
_group setVariable ["ARTIC_blockReady",true,true];
[_group,"ARTIC_blockProgressAt"] call ARTIC_fnc_markDeployProgress;
if (_fsm && {!([_group,_planId,_taskId,"READY","BLOCK_READY"] call ARTIC_fnc_setSectionTaskState)}) exitWith {["task state rejected at READY"] call _quietEnd};
{
    private _u = _x select 0;
    if (alive _u && {local _u}) then {
        private _ln = _u getVariable ["ARTIC_blockLane",[]];
        _u doWatch (if (_ln isEqualTo []) then {_focus} else {_ln select 1});
    };
} forEach _firePoints;
[format ["BLOCK READY: %1 shooter(s) on the fire line (%2 see), %3 watching withdrawal lanes; holding fire until H-hour",count _firePoints,count _losUnits,count _assigned],groupId _group] call ARTIC_fnc_debug;

private _readyAt = time;
private _maxEnd = time + (missionNamespace getVariable ["ARTIC_blockMaxSeconds",480]);
private _seenActive = false;
private _lastRedirect = (_group getVariable ["ARTIC_fireRedirect",[0,0,0]]) param [2,0];
private _siblingsActive = {(_siblings findIf {(_x getVariable ["ARTIC_currentPlan",""]) isEqualTo "PLATOON_MANOEUVRE"}) > -1};
private _knownEnemies = {
    private _k = +_threatObjs;
    {
        _x params ["_o","_p","_t"];
        if ((time - _t) < 120 && {[_o] call ARTIC_fnc_isCombatEffectiveTarget}) then {_k pushBackUnique _o;};
    } forEach (_group getVariable ["ARTIC_sharedContacts",[]]);
    {
        if ((_x distance2D _focus) < (_radius + 150)) then {_k pushBackUnique _x;};
    } forEach (((leader _group) targets [true,800]) select {alive _x});
    _k select {[_x] call ARTIC_fnc_isCombatEffectiveTarget}
};
private _laneEnemy = {
    params ["_cands"];
    private _hit = [];
    {
        if (_hit isEqualTo []) then {
            private _ep = getPosATL _x;
            private _li = _lanes findIf {(_ep distance2D (_x select 2)) < 40 || {(_ep distance2D (_x select 1)) < 40}};
            if (_li > -1) then {_hit = [_x,(_lanes select _li) select 0];};
        };
    } forEach _cands;
    _hit
};

private _trigger = "";
waitUntil {
    sleep 1;
    if (call _stale) exitWith {true};
    if (call _siblingsActive) then {_seenActive = true;};
    private _phases = _siblings apply {_x getVariable ["ARTIC_manoeuvrePhase",""]};
    private _hHour = (_planId isNotEqualTo "" && {(_group getVariable ["ARTIC_hHourPlanId",""]) isEqualTo _planId})
        || {(_phases findIf {_x in ["STAGE1","STAGE2","ASSAULT_READY","ASSAULT"]}) > -1};
    private _lane = [call _knownEnemies] call _laneEnemy;
    private _rd = _group getVariable ["ARTIC_fireRedirect",[]];
    _trigger = switch (true) do {
        case (_hHour): {"H_HOUR"};
        case (_lane isNotEqualTo []): {format ["WITHDRAWAL_%1",_lane select 1]};
        case (({(getSuppression _x) > 0.25} count (_shooters select {alive _x})) >= 2): {"ENGAGED"};
        case (_rd isNotEqualTo [] && {(_rd select 2) > _lastRedirect}): {"REDIRECT"};
        case (_seenActive && {!(call _siblingsActive)}): {"MANOEUVRE_ENDED"};
        case (!_seenActive && {(time - _readyAt) > 240}): {"NO_MANOEUVRE"};
        case (time > _maxEnd): {"TIMEOUT"};
        default {""};
    };
    _trigger isNotEqualTo ""
};
if (call _stale) exitWith {["plan changed while holding"] call _quietEnd};
if (_trigger in ["MANOEUVRE_ENDED","NO_MANOEUVRE","TIMEOUT"]) exitWith {[format ["%1 before H-hour",_trigger]] call _quietEnd};

// ---- 4. engage -----------------------------------------------------------------------
_group setVariable ["ARTIC_blockState","ENGAGE",true];
if (_fsm && {!([_group,_planId,_taskId,"EXECUTING",format ["BLOCK_FIRE:%1",_trigger]] call ARTIC_fnc_setSectionTaskState)}) exitWith {["task state rejected at fire"] call _quietEnd};
_group setCombatMode "RED";
[format ["BLOCK opening fire (trigger=%1)",_trigger],groupId _group] call ARTIC_fnc_debug;
private _lift = missionNamespace getVariable ["ARTIC_blockLiftDistance",60];
private _lifted = false;
private _laneLog = createHashMap;
private _engageEnd = _maxEnd max (time + 60);
private _manEndedAt = -1;
private _endWhy = "";
while {_endWhy isEqualTo ""} do {
    if (call _stale) then {_endWhy = "STALE";} else {
        if (call _siblingsActive) then {_seenActive = true; _manEndedAt = -1;} else {
            if (_manEndedAt < 0) then {_manEndedAt = time;};
        };
        if (_seenActive && {_manEndedAt >= 0} && {(time - _manEndedAt) > 10}) then {_endWhy = "MANOEUVRE_DONE";};
        if (!_seenActive && {(time - _readyAt) > 240}) then {_endWhy = "NO_MANOEUVRE";};
        if (time > _engageEnd) then {_endWhy = "TIMEOUT";};
    };
    if (_endWhy isEqualTo "") then {
        private _friendly = [];
        {_friendly append ((units _x) select {alive _x});} forEach _siblings;
        private _nearFriend = {params ["_p"]; (_friendly findIf {(_x distance2D _p) < _lift}) > -1};
        private _objLifted = [_focus] call _nearFriend;
        if (_objLifted isNotEqualTo _lifted) then {
            _lifted = _objLifted;
            if (_lifted) then {
                [format ["BLOCK lifting fire off the objective: friendly manoeuvre within %1 m; covering withdrawal lanes only",_lift],groupId _group] call ARTIC_fnc_debug;
            } else {
                ["BLOCK resuming fire on the objective",groupId _group] call ARTIC_fnc_debug;
            };
        };
        private _rd = _group getVariable ["ARTIC_fireRedirect",[]];
        if (_rd isNotEqualTo [] && {(_rd select 2) > _lastRedirect}) then {
            _lastRedirect = _rd select 2;
            _threatObjs pushBackUnique (_rd select 0);
            [format ["BLOCK shifting fire onto contact called by %1 at %2",_rd select 3,mapGridPosition (_rd select 1)],groupId _group] call ARTIC_fnc_debug;
        };
        private _enemies = call _knownEnemies;
        {
            private _u = _x select 0;
            if (alive _u && {local _u} && {[_u] call ARTIC_fnc_isFit} && {(_u getVariable ["ARTIC_reactionState",[]]) isEqualTo []}) then {
                private _ln = _u getVariable ["ARTIC_blockLane",[]];
                private _vis = _enemies select {!([getPosATL _x] call _nearFriend) && {[getPosATL _u,_x] call ARTIC_fnc_hasLineOfSight}};
                if (_ln isNotEqualTo []) then {
                    private _inLane = _vis select {((getPosATL _x) distance2D (_ln select 1)) < 45 || {((getPosATL _x) distance2D (_ln select 2)) < 45}};
                    if (_inLane isNotEqualTo []) then {
                        private _e = ([_inLane,[],{_x distance2D _u},"ASCEND"] call BIS_fnc_sortBy) select 0;
                        _u reveal [_e,4];
                        _u doTarget _e;
                        _u doFire _e;
                        if ((time - (_laneLog getOrDefault [_ln select 0,-1e6])) > 30) then {
                            _laneLog set [_ln select 0,time];
                            [format ["BLOCK engaging enemy withdrawing via %1 lane",_ln select 0],groupId _group] call ARTIC_fnc_debug;
                        };
                    } else {
                        _u doWatch (_ln select 1);
                    };
                } else {
                    if (_vis isNotEqualTo []) then {
                        private _e = ([_vis,[],{_x distance2D _u},"ASCEND"] call BIS_fnc_sortBy) select 0;
                        _u reveal [_e,4];
                        _u doTarget _e;
                    } else {
                        if (!_lifted && {random 1 < 0.4}) then {
                            private _ap = selectRandom _threatPos;
                            if !([_ap] call _nearFriend) then {_u doSuppressiveFire (AGLToASL (_ap vectorAdd [0,0,1]));};
                        };
                    };
                };
            };
        } forEach _firePoints;
        sleep 3;
    };
};

// ---- 5. end --------------------------------------------------------------------------
if (_endWhy isEqualTo "STALE") exitWith {["plan changed while engaged"] call _quietEnd};
private _siblingComplete = (_siblings findIf {(_x getVariable ["ARTIC_manoeuvrePhase",""]) isEqualTo "COMPLETE"}) > -1;
if (_siblingComplete) then {
    _group setVariable ["ARTIC_blockDoneTaskId",_taskId,true];
    _group setVariable ["ARTIC_blockRestUntil",time + 600,false];
} else {
    _group setVariable ["ARTIC_blockRestUntil",time + 20,false];
};
_group setVariable ["ARTIC_planFailureReason","",true];
_group setVariable ["ARTIC_planFailureAt",-1e6,true];
if (_fsm) then {[_group,_planId,_taskId,"COMPLETE",format ["BLOCK_COMPLETE:%1",_endWhy]] call ARTIC_fnc_setSectionTaskState;};
[format ["complete: %1 after %2 s of fire%3",_endWhy,round (time - _readyAt),["",", manoeuvre on the objective"] select _siblingComplete]] call _quietEnd;
true
