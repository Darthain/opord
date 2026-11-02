/*
    Platoon fixing element (v0.3.30).

    Sequence (support-by-fire occupied as part of deployment, not after release):
      1. DEPLOY    - the platoon approach already brought the section to a covered point
                     just behind its SBF (fn_buildBattleContext: FIX hold = SBF approach).
                     No live target is required to start.
      2. OCCUPY    - move onto the SBF and occupy a FIRE LINE (ARTIC_fnc_buildFireLine): one
                     firing point per shooter, scored on sight and cover, MG on the best point.
      3. OBSERVE   - confirm sight with ARTIC_fnc_battleSight against the known enemy
                     positions (the same test the planner used). Creep once if needed.
      4. HOLD FIRE - combat mode GREEN, weapons watching the enemy. State READY_HOLD_FIRE.
      5. OPEN FIRE - trigger: a sibling manoeuvre section reports it is in position and
                     waiting (ARTIC_manoeuvrePhase = WAIT_FIX), the FIX section is engaged,
                     or it has held for 90 s.
      6. SUPPRESS  - ARTIC_fixReady / suppression estimate for the manoeuvres.

    v0.3.30:
      - CONTACT mode (ARTIC_battleSbfMode = CONTACT): the section was committed in place by
        contact-aware replanning. It is already in contact where it stands: no approach move,
        fire line around its own position, no hold-fire phase.
      - Fire is SUSTAINED until a manoeuvre section reaches ASSAULT (lift fire), the
        manoeuvre sections end, or ARTIC_fixFireMaxSeconds. A target that drops is replaced
        by the next known live enemy near the objective; with none known, area fire on the
        objective. 0.3.29 ended the whole play when its first target died (5:49:12 open fire,
        5:49:13 complete), which failed the manoeuvre gate and superseded the only plan with a
        real SBF.
      - The play captures its plan/task identity and ends quietly when stale
        (ARTIC_fnc_isPlayStale); failures are reported to the platoon FSM.

    Progress is published as ARTIC_fixProgressAt so non-FSM manoeuvre gates can wait while the
    FIX section is visibly making progress instead of watching a fixed clock.
*/
params [["_group",grpNull,[grpNull]],["_target",objNull,[objNull]]];
if (isNull _group || {!local _group}) exitWith {false};
if ((_group getVariable ["ARTIC_currentPlan",""]) isNotEqualTo "") exitWith {false};

if !(_group getVariable ["ARTIC_battleFixValid",true]) exitWith {
    ["Fixing action not started: battlefield has no validated SBF position",groupId _group] call ARTIC_fnc_debug;
    false
};

private _planId = _group getVariable ["ARTIC_platoonPlanId",""];
private _taskId = _group getVariable ["ARTIC_sectionTaskId",""];
if (_planId isNotEqualTo "" && {(_group getVariable ["ARTIC_planAbortId",""]) isEqualTo _planId}) exitWith {false};
private _fsm = (missionNamespace getVariable ["ARTIC_useFSMHierarchy",true]) && {_planId isNotEqualTo ""};
private _armedAtStart = _group getVariable ["ARTIC_tacticalExecutionArmed",false];
private _identity = [_planId,_taskId,_armedAtStart];
private _stale = {[_group,_planId,_taskId,_armedAtStart] call ARTIC_fnc_isPlayStale};
private _contactMode = (_group getVariable ["ARTIC_battleSbfMode",""]) isEqualTo "CONTACT";

private _caps = [_group] call ARTIC_fnc_scanGroupCapabilities;
private _alive = _caps getOrDefault ["alive",[]];
if ((count _alive) < 2) exitWith {false};

private _reserve = [];
{_reserve pushBackUnique _x;} forEach (_caps getOrDefault ["medic",[]]);
private _fireUnits = _alive - _reserve;
if ((count _fireUnits) < 2) then {_fireUnits = +_alive; _reserve = [];};

// ---- known enemy picture (no live target needed) ---------------------------------
private _hasTarget = [_target] call ARTIC_fnc_isCombatEffectiveTarget;
private _threatObjs = [];
// v0.3.24: judge sight against the SAME enemy positions the planner used (published as
// ARTIC_battleSightTargets), plus the live target. 0.3.23: planner 25 %, FIX 0 %.
private _threatPos = +(_group getVariable ["ARTIC_battleSightTargets",[]]);
if (_hasTarget) then {_threatObjs pushBack _target; _threatPos pushBack (getPosATL _target);};
{
    _x params ["_o","_p","_t"];
    if ((time - _t) < 240 && {_p isEqualType []} && {(count _p) >= 2}) then {
        if ((_threatPos findIf {(_x distance2D _p) < 10}) < 0) then {_threatPos pushBack _p;};
        if ([_o] call ARTIC_fnc_isCombatEffectiveTarget) then {_threatObjs pushBackUnique _o;};
    };
} forEach (_group getVariable ["ARTIC_sharedContacts",[]]);
private _battleFix = _group getVariable ["ARTIC_battleFixPos",[]];
private _focus = _group getVariable ["ARTIC_battleFocus",[]];
if (_threatPos isEqualTo [] && {_focus isNotEqualTo []}) then {_threatPos = [+_focus];};
if (_battleFix isEqualTo [] && {!_hasTarget}) exitWith {
    ["Fixing action not started: no SBF and no target",groupId _group] call ARTIC_fnc_debug;
    false
};
private _aimPos = if (_hasTarget) then {getPosATL _target} else {_threatPos param [0,_focus]};

// ---- claim ownership --------------------------------------------------------------
if (_fsm && {!([_group,_planId,_taskId,"DEPLOYING","FIX_START"] call ARTIC_fnc_setSectionTaskState)}) exitWith {false};
_group setVariable ["ARTIC_tacticalGuideActive",true,false];
_group setVariable ["ARTIC_movementPhase","COMBAT",false];
_group setVariable ["ARTIC_currentPlan","FIXING_ACTION",true];
private _sbfStarted = time;
private _m = _group getVariable ["ARTIC_metrics",createHashMap];
_m set ["sbfAttempts",(_m getOrDefault ["sbfAttempts",0]) + 1];
_group setVariable ["ARTIC_metrics",_m,false];
_group setVariable ["ARTIC_fixReady",false,true];
_group setVariable ["ARTIC_fixReadyUntil",0,true];
_group setVariable ["ARTIC_fixTarget",objNull,true];
_group setVariable ["ARTIC_fixState","OCCUPY",true];
[_group,"ARTIC_fixProgressAt"] call ARTIC_fnc_markDeployProgress;
_group setVariable ["ARTIC_planOwner",clientOwner,true];
_group enableAttack false;
_group setBehaviourStrong "COMBAT";
_group setCombatMode (["GREEN","RED"] select _contactMode);   // hold fire until the trigger (return fire allowed)

private _watch = scriptNull;
private _failFix = {
    params ["_reason",["_cool",12]];
    if (!isNull _watch) then {terminate _watch;};
    _group setVariable ["ARTIC_fixState","FAILED",true];
    _group setVariable ["ARTIC_fixReady",false,true];
    _group setVariable ["ARTIC_fixReadyUntil",0,true];
    _group setVariable ["ARTIC_planFailureReason",_reason,true];
    _group setVariable ["ARTIC_planFailureAt",time,true];
    if (_fsm) then {[_group,_reason] call ARTIC_fnc_signalSectionFailure;};
    [_group,_cool,_planId,_taskId] call ARTIC_fnc_finishPlan;
    false
};
private _quietEnd = {
    params [["_why","plan changed"]];
    if (!isNull _watch) then {terminate _watch;};
    _group setVariable ["ARTIC_fixReady",false,true];
    _group setVariable ["ARTIC_fixReadyUntil",0,true];
    if ((_group getVariable ["ARTIC_fixState",""]) isNotEqualTo "FAILED") then {_group setVariable ["ARTIC_fixState","DONE",true];};
    if (local _group) then {
        [format ["Fixing action ended quietly (%1)",_why],groupId _group] call ARTIC_fnc_debug;
        [_group,_planId,_taskId,format ["FIX %1",_why]] call ARTIC_fnc_endPlayQuietly;
    };
    false
};

// ---- SBF position ------------------------------------------------------------------
private _supportPos = if (_battleFix isNotEqualTo []) then {+_battleFix} else {
    ([_group,_target,_fireUnits] call ARTIC_fnc_findSupportPosition) getOrDefault ["position",getPosATL leader _group]
};
private _ref = _group getVariable ["ARTIC_sectionReferencePos",getPosATL leader _group];
if (_contactMode) then {
    // committed in place: the fire line is built where the section actually is
    if ((_ref distance2D _supportPos) > 40) then {_supportPos = +_ref;};
};
private _sight = ([_supportPos,_threatPos] call ARTIC_fnc_battleSight) select 0;
private _dist = _ref distance2D _supportPos;
[format ["FIXING_ACTION %1 SBF %2 (%3m) sight=%4%% target=%5",["occupy","CONTACT fix in place at"] select _contactMode,mapGridPosition _supportPos,round _dist,round (_sight * 100),["SHARED/BATTLE","LIVE"] select _hasTarget],groupId _group] call ARTIC_fnc_debug;
if (_hasTarget) then {[_group,_target,0.5,_sight >= 0.2] call ARTIC_fnc_assessAttackSupport;};

// progress watcher: publishes ARTIC_fixProgressAt while the section closes on the SBF
_watch = [_group,_supportPos] spawn {
    params ["_g","_goal"];
    private _best = 1e9;
    while {local _g && {(_g getVariable ["ARTIC_fixState",""]) isEqualTo "OCCUPY"}} do {
        private _r = _g getVariable ["ARTIC_sectionReferencePos",getPosATL leader _g];
        private _d = _r distance2D _goal;
        if (_d < _best - 5) then {_best = _d; [_g,"ARTIC_fixProgressAt"] call ARTIC_fnc_markDeployProgress;};
        sleep 2;
    };
};

// v0.3.24: get to a covered point ~30 m behind the SBF first (normally the platoon
// approach already brought the section there), then occupy a FIRE LINE.
private _away = _aimPos getDir _supportPos;
private _approach = _supportPos getPos [30,_away]; _approach set [2,0];
private _ready = true;
if (!_contactMode && {(_ref distance2D _supportPos) > 80}) then {
    private _dA = _ref distance2D _approach;
    private _timeout = ((25 + _dA / 1.1) max 55) min 360;
    _ready = [_group,_approach,_target,_timeout,12,"FIX SBF APPROACH",_identity] call ARTIC_fnc_moveSectionTactical;
    if (!_ready) then {
        private _here = _group getVariable ["ARTIC_sectionReferencePos",getPosATL leader _group];
        if ((_here distance2D _supportPos) < 120) then {_ready = true;};
    };
};
if (call _stale) exitWith {["plan changed during SBF approach"] call _quietEnd};
if (!_ready) exitWith {["FIX_ROUTE_FAILED",15] call _failFix};
_group setVariable ["ARTIC_tacticalGuideActive",false,false];   // individual firing points from here

private _shooters = _fireUnits select {[_x] call ARTIC_fnc_isFit && {local _x}};
private _mgs = (_caps getOrDefault ["mg",[]]) select {_x in _shooters};
_shooters = _mgs + (_shooters - _mgs);
private _toEnemy = _supportPos getDir _aimPos;
private _line = [_group,_supportPos,_aimPos,_threatPos,_shooters,_target,4] call ARTIC_fnc_buildFireLine;
private _firePoints = _line getOrDefault ["points",[]];
private _minSep = _line getOrDefault ["minSep",5];
{
    if (alive _x && {local _x}) then {[_x,"HOLD",_approach,_target,400,6] call ARTIC_fnc_setUnitTask;};
} forEach _reserve;
[format ["FIX occupying fire line: %1 firing point(s) along %2 m, min %3 m apart (best point sees %4%%)",count _firePoints,round (2 * (_line getOrDefault ["half",0])),round _minSep,round (100 * (_line getOrDefault ["bestSight",0]))],groupId _group] call ARTIC_fnc_debug;
private _maxD = 0; {_maxD = _maxD max ((_x select 0) distance2D (_x select 1));} forEach _firePoints;
private _occEnd = time + (((15 + _maxD / 1.2) max 20) min 90);
private _lastOnFix = -1;
waitUntil {
    sleep 1;
    if (call _stale) exitWith {true};
    private _nOn = {((_x select 0) distance2D (_x select 1)) < 4} count _firePoints;
    // v0.3.30.2: each soldier reaching his firing point is progress the platoon can see
    if (_nOn > _lastOnFix) then {_lastOnFix = _nOn; [_group,"ARTIC_fixProgressAt"] call ARTIC_fnc_markDeployProgress;};
    time > _occEnd || {_nOn >= ceil ((count _firePoints) * 0.75)}
};
if (call _stale) exitWith {["plan changed during occupation"] call _quietEnd};

// ---- observe: same sight test as the planner --------------------------------------
private _unitSees = {params ["_u"]; (([getPosATL _u,_threatPos,4] call ARTIC_fnc_battleSight) select 0) > 0};
private _losUnits = _fireUnits select {alive _x && {local _x} && {[_x] call _unitSees}};
private _need = ceil ((count (_fireUnits select {alive _x && {local _x}})) * 0.50);
if ((count _losUnits) < (_need max 1)) then {
    // shift the whole fire line forward once (up to 25 m) toward the enemy
    private _shift = ((_supportPos distance2D _aimPos) * 0.2) min 25;
    [format ["Fixing element: %1/%2 shooters see the enemy; moving the fire line %3m forward",count _losUnits,_need,round _shift],groupId _group] call ARTIC_fnc_debug;
    {
        _x params ["_u","_pt"];
        private _np = _pt getPos [_shift,_toEnemy]; _np set [2,0];
        _x set [1,_np];
        [_u,"HOLD",_np,_target,400,3] call ARTIC_fnc_setUnitTask;
    } forEach _firePoints;
    private _cEnd = time + 30;
    waitUntil {sleep 1; (call _stale) || {time > _cEnd} || {({((_x select 0) distance2D (_x select 1)) < 4} count _firePoints) >= ceil ((count _firePoints) * 0.75)}};
    _losUnits = _fireUnits select {alive _x && {local _x} && {[_x] call _unitSees}};
};
if (call _stale) exitWith {["plan changed while observing"] call _quietEnd};
_group setVariable ["ARTIC_fixState","OBSERVE",true];
[_group,"ARTIC_fixProgressAt"] call ARTIC_fnc_markDeployProgress;
terminate _watch;
if ((count _losUnits) < (_need max 1)) exitWith {
    ["Fixing element failed to establish useful sight; requesting platoon tactic change",groupId _group] call ARTIC_fnc_debug;
    sleep 4;
    ["FIX_NO_LOS",12] call _failFix
};

// ---- hold fire until the trigger --------------------------------------------------
_group setVariable ["ARTIC_fixState","READY_HOLD_FIRE",true];
[_group,"ARTIC_fixProgressAt"] call ARTIC_fnc_markDeployProgress;
if (_fsm && {!([_group,_planId,_taskId,"READY","FIX_READY"] call ARTIC_fnc_setSectionTaskState)}) exitWith {["task state rejected at READY"] call _quietEnd};
{if (alive _x && {local _x}) then {_x doWatch _aimPos;};} forEach _fireUnits;

private _formation = _group getVariable ["ARTIC_formationId",""];
private _siblings = allGroups select {
    _x isNotEqualTo _group && {side _x isEqualTo side _group}
    && {(_x getVariable ["ARTIC_formationId",""]) isEqualTo _formation}
    && {(_x getVariable ["ARTIC_schemeRole",""]) in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT","MANOEUVRE_AUTO"]}
};
private _trigger = "";
if (_contactMode) then {
    _trigger = "IN_CONTACT";
} else {
    [format ["FIX in SBF, holding fire: %1 shooter(s) see the enemy; waiting for manoeuvre sections",count _losUnits],groupId _group] call ARTIC_fnc_debug;
    private _holdEnd = time + 90;
    waitUntil {
        sleep 1;
        if (call _stale) exitWith {true};
        _trigger = switch (true) do {
            case (_siblings isEqualTo []): {"NO_MANOEUVRE"};
            case ((_siblings findIf {(_x getVariable ["ARTIC_manoeuvrePhase",""]) isEqualTo "WAIT_FIX"}) > -1): {"MANOEUVRE_READY"};
            case (({(getSuppression _x) > 0.25} count (_fireUnits select {alive _x})) >= 2): {"ENGAGED"};
            case (time > _holdEnd): {"TIMEOUT"};
            default {""};
        };
        _trigger isNotEqualTo ""
    };
};
if (call _stale) exitWith {["plan changed while holding fire"] call _quietEnd};

// ---- open fire ------------------------------------------------------------------------
_group setCombatMode "RED";
private _nextTarget = {
    private _cands = [];
    {if ([_x] call ARTIC_fnc_isCombatEffectiveTarget) then {_cands pushBackUnique _x;};} forEach _threatObjs;
    {
        _x params ["_o","_p","_t"];
        if ((time - _t) < 180 && {[_o] call ARTIC_fnc_isCombatEffectiveTarget} && {_p isEqualType []} && {(_p distance2D _aimPos) < 200}) then {_cands pushBackUnique _o;};
    } forEach (_group getVariable ["ARTIC_sharedContacts",[]]);
    ([_cands,[],{_x distance2D _supportPos},"ASCEND"] call BIS_fnc_sortBy) param [0,objNull]
};
private _fireTarget = if (_hasTarget) then {_target} else {call _nextTarget};
[format ["FIX opening fire (trigger=%1) on %2",_trigger,if (isNull _fireTarget) then {"area " + mapGridPosition _aimPos} else {typeOf _fireTarget}],groupId _group] call ARTIC_fnc_debug;

private _mS = _group getVariable ["ARTIC_metrics",createHashMap];
_mS set ["sbfSuccess",(_mS getOrDefault ["sbfSuccess",0]) + 1];
_mS set ["sbfSeconds",(_mS getOrDefault ["sbfSeconds",0]) + (time - _sbfStarted)];
_group setVariable ["ARTIC_metrics",_mS,false];
_group setVariable ["ARTIC_fixState","SUPPRESS",true];
if (_fsm && {!([_group,_planId,_taskId,"EXECUTING",format ["FIX_FIRE:%1",_trigger]] call ARTIC_fnc_setSectionTaskState)}) exitWith {["task state rejected at fire"] call _quietEnd};
_group setVariable ["ARTIC_fixReady",true,true];
_group setVariable ["ARTIC_fixReadyUntil",time + 75,true];
_group setVariable ["ARTIC_fixTarget",_fireTarget,true];

// fire helper: suppress a live contact, or area-fire a position (builds the estimate)
private _startFire = {
    params ["_tObj","_tPos"];
    if (!isNull _tObj && {[_tObj] call ARTIC_fnc_isCombatEffectiveTarget}) then {
        [_group,_tObj,80,_fireUnits] spawn ARTIC_fnc_suppressElement
    } else {
        [_group,_fireUnits,_tPos] spawn {
            params ["_g","_us","_p"];
            private _end = time + 80;
            private _caps = [_g] call ARTIC_fnc_scanGroupCapabilities;
            private _mg = _caps getOrDefault ["mg",[]];
            private _gren = _caps getOrDefault ["grenadier",[]];
            _g setVariable ["ARTIC_suppressionEstimate",0,true];
            while {local _g && {time < _end}} do {
                private _gain = 0;
                {
                    if (alive _x && {local _x}) then {
                        _x doSuppressiveFire (AGLToASL (_p vectorAdd [0,0,1]));
                        if ((([getPosATL _x,[_p],1] call ARTIC_fnc_battleSight) select 0) > 0) then {
                            _gain = _gain + 0.045 + ([0,0.09] select (_x in _mg)) + ([0,0.035] select (_x in _gren));
                        };
                    };
                } forEach _us;
                _g setVariable ["ARTIC_suppressionEstimate",((_g getVariable ["ARTIC_suppressionEstimate",0]) + _gain) min 1,true];
                sleep 2.5;
            };
        }
    }
};
private _sup = [_fireTarget,_aimPos] call _startFire;
private _fireStart = time;
private _fireMax = time + (missionNamespace getVariable ["ARTIC_fixFireMaxSeconds",300]);
private _lastRedirect = (_group getVariable ["ARTIC_fireRedirect",[0,0,0]]) param [2,0];
private _seenMan = false;
private _manEndedAt = -1;
private _endWhy = "";
waitUntil {
    sleep 1;
    if (call _stale) exitWith {_endWhy = "STALE"; true};
    // v0.3.24: shift fire onto a contact called by another section of the platoon
    private _rd = _group getVariable ["ARTIC_fireRedirect",[]];
    if (_rd isNotEqualTo [] && {(_rd select 2) > _lastRedirect}) then {
        _lastRedirect = _rd select 2;
        terminate _sup;
        _fireTarget = _rd select 0;
        _threatObjs pushBackUnique _fireTarget;
        _sup = [_rd select 0,_rd select 1] call _startFire;
        _group setVariable ["ARTIC_fixTarget",_rd select 0,true];
        [format ["FIX shifting fire onto contact called by %1 at %2",_rd select 3,mapGridPosition (_rd select 1)],groupId _group] call ARTIC_fnc_debug;
    };
    // v0.3.30: a target that drops is replaced; the objective stays under fire
    if (!isNull _fireTarget && {!([_fireTarget] call ARTIC_fnc_isCombatEffectiveTarget)}) then {
        terminate _sup;
        private _nt = call _nextTarget;
        if (!isNull _nt) then {
            _fireTarget = _nt;
            _sup = [_nt,getPosATL _nt] call _startFire;
            _group setVariable ["ARTIC_fixTarget",_nt,true];
            [format ["FIX target down; switching fire to %1 at %2",typeOf _nt,mapGridPosition _nt],groupId _group] call ARTIC_fnc_debug;
        } else {
            _fireTarget = objNull;
            _sup = [objNull,_aimPos] call _startFire;
            _group setVariable ["ARTIC_fixTarget",objNull,true];
            [format ["FIX target down; no other live contact known, area fire on %1",mapGridPosition _aimPos],groupId _group] call ARTIC_fnc_debug;
        };
    };
    if (scriptDone _sup) then {_sup = [_fireTarget,_aimPos] call _startFire;};
    _group setVariable ["ARTIC_fixReadyUntil",time + 30,true];

    // manoeuvre progress: lift fire when a manoeuvre section assaults; end when they are done
    private _manActive = (_siblings findIf {(_x getVariable ["ARTIC_currentPlan",""]) isEqualTo "PLATOON_MANOEUVRE"}) > -1;
    if (_manActive) then {_seenMan = true; _manEndedAt = -1;} else {if (_manEndedAt < 0) then {_manEndedAt = time;};};
    private _assault = (_siblings findIf {(_x getVariable ["ARTIC_manoeuvrePhase",""]) in ["ASSAULT","COMPLETE"]}) > -1;
    _endWhy = switch (true) do {
        case (_assault && {_seenMan}): {"LIFT_ASSAULT"};
        case (_siblings isEqualTo [] && {(time - _fireStart) > 70}): {"NO_MANOEUVRE"};
        case (_manEndedAt >= 0 && {(time - _manEndedAt) > ([45,15] select _seenMan)}): {"MANOEUVRE_ENDED"};
        case (time > _fireMax): {"TIMEOUT"};
        default {""};
    };
    _endWhy isNotEqualTo ""
};
terminate _sup;
if (_endWhy isEqualTo "STALE") exitWith {["plan changed while firing"] call _quietEnd};
_group setVariable ["ARTIC_fixReady",false,true];
_group setVariable ["ARTIC_fixReadyUntil",0,true];
_group setVariable ["ARTIC_fixState","DONE",true];
_group setVariable ["ARTIC_planFailureReason","",true];
_group setVariable ["ARTIC_planFailureAt",-1e6,true];
// v0.3.30: the fixing task is finished for this plan; groupStep must not restart it
// (a restart during the assault would put fire back onto the objective).
_group setVariable ["ARTIC_fixDoneTaskId",_taskId,true];
_group setVariable ["ARTIC_fixRestUntil",time + 120,false];

if (local _group) then {
    if (_endWhy isEqualTo "LIFT_ASSAULT") then {
        [format ["FIX lifting fire after %1 s: manoeuvre section assaulting the objective",round (time - _fireStart)],groupId _group] call ARTIC_fnc_debug;
    } else {
        [format ["Fixing action complete (%1) after %2 s of fire",_endWhy,round (time - _fireStart)],groupId _group] call ARTIC_fnc_debug;
    };
    [_group,8,_planId,_taskId] call ARTIC_fnc_finishPlan;
};
true
