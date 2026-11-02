/*
    ARTIC v0.3.18 - persistent platoon battlefield context.

    A battlefield is a stable tactical frame shared by commander, platoon, sections,
    fireteams and individuals. UAS / recon intelligence may create it before direct
    contact. v0.3.13 makes the control points and section routes terrain-aware rather
    than relying only on fixed geometric offsets.
*/
params [
    ["_node",createHashMap,[createHashMap]],
    ["_commander",createHashMap,[createHashMap]],
    ["_groups",[],[[]]],
    ["_objective",[],[[]]],
    ["_phase","APPROACH",[""]]
];
if (!isServer || {(count _node) isEqualTo 0} || {_objective isEqualTo []}) exitWith {createHashMap};
_groups = _groups select {!isNull _x && {({alive _x} count units _x) > 0}};
if (_groups isEqualTo []) exitWith {createHashMap};

private _sectionPos = {
    params ["_g"];
    private _p = _g getVariable ["ARTIC_sectionReferencePos",[]];
    if (_p isNotEqualTo [] && {(count _p) >= 2}) exitWith {+_p};
    private _guide = _g getVariable ["ARTIC_guide",[]];
    if (_guide isNotEqualTo [] && {(count _guide) >= 1}) exitWith {+(_guide select 0)};
    // Last-resort fallback is the majority cluster of fit section members, never
    // the legacy v0.3.5 sectionAnchor and never the leader alone. This keeps the
    // authoritative reference in the same guide/slot spatial model even before a
    // guide has been published on the first scheduler tick.
    private _fit = (units _g) select {[_x] call ARTIC_fnc_isFit};
    if (_fit isNotEqualTo []) then {
        private _seed = _fit select 0;
        private _bestN = -1;
        {
            private _c = _x;
            private _n = {_c distance2D _x <= 35} count _fit;
            if (_n > _bestN) then {_seed = _c; _bestN = _n;};
        } forEach _fit;
        private _cluster = _fit select {_seed distance2D _x <= 42};
        if (_cluster isEqualTo []) then {_cluster = [_seed];};
        private _sx = 0; private _sy = 0;
        {private _q = getPosATL _x; _sx = _sx + (_q select 0); _sy = _sy + (_q select 1);} forEach _cluster;
        [_sx / count _cluster,_sy / count _cluster,0]
    } else {
        getPosATL leader _g
    }
};

private _cx = 0; private _cy = 0;
{private _p = [_x] call _sectionPos; _cx = _cx + (_p select 0); _cy = _cy + (_p select 1);} forEach _groups;
private _friendlyCentre = [_cx / count _groups,_cy / count _groups,0];
private _nodeId = _node getOrDefault ["id","FORMATION"];

// Freshest classified battlefield relevant to the assigned objective.
private _battlefield = createHashMap;
private _bestD = 1e9;
{
    private _bf = ARTIC_Battlefields getOrDefault [_x,createHashMap];
    if ((count _bf) > 0 && {(time - (_bf getOrDefault ["lastUpdated",-1e6])) < 300}) then {
        private _d = (_bf getOrDefault ["centre",[0,0,0]]) distance2D _objective;
        if (_d < 750 && {_d < _bestD}) then {_bestD = _d; _battlefield = _bf;};
    };
} forEach (_commander getOrDefault ["battlefieldIds",[]]);

private _focus = if ((count _battlefield) > 0) then {+(_battlefield get "centre")} else {+_objective};
private _bfRadius = if ((count _battlefield) > 0) then {_battlefield getOrDefault ["radius",100]} else {100};
private _bfId = if ((count _battlefield) > 0) then {_battlefield get "id"} else {format ["OBJ_%1_%2",_nodeId,mapGridPosition _objective]};
private _assessment = [_commander,_groups,_battlefield] call ARTIC_fnc_assessBattlefield;

// v0.3.27: battlefield intelligence persists with the battle context. The short-lived
// shared-contact cache may expire during a long reposition, but the platoon retains the
// tracks which justified its COA. These are planning/target-acquisition tracks only; they
// do not grant vanilla movement or attack authority.
private _contactPos = [];
private _freshBattleTargets = [];
private _freshBattleTracks = [];
private _bfTracks = _battlefield getOrDefault ["contactTracks",[]];
if (_bfTracks isNotEqualTo []) then {
    {
        _x params ["_o","_p","_t"];
        if (_p isNotEqualTo []) then {
            _contactPos pushBack (+_p);
            _freshBattleTracks pushBack [_o,+_p,_t,"BATTLEFIELD"];
            if ([_o] call ARTIC_fnc_isCombatEffectiveTarget) then {_freshBattleTargets pushBackUnique _o;};
        };
    } forEach _bfTracks;
} else {
    {
        private _o = _x;
        if ([_o] call ARTIC_fnc_isCombatEffectiveTarget) then {
            private _p = getPosATL _o;
            _contactPos pushBack _p;
            _freshBattleTargets pushBackUnique _o;
            _freshBattleTracks pushBack [_o,+_p,(_battlefield getOrDefault ["lastUpdated",time]),"BATTLEFIELD_LEGACY"];
        };
    } forEach (_battlefield getOrDefault ["contacts",[]]);
};
if (_contactPos isEqualTo []) then {
    {
        _x params ["_o","_p","_t"];
        if ((_p distance2D _focus) < 250 && {(time - _t) < 300}) then {
            _contactPos pushBack (+_p);
            if ([_o] call ARTIC_fnc_isCombatEffectiveTarget) then {
                _freshBattleTargets pushBackUnique _o;
                _freshBattleTracks pushBack [_o,+_p,_t,"COMMANDER"];
            };
        };
    } forEach (_commander getOrDefault ["contactReports",[]]);
};
private _hasEnemyIntel = _contactPos isNotEqualTo [];
if (!_hasEnemyIntel) then {_contactPos = [+_focus];};

// v0.3.15: company-level sharing. Several formation nodes attacking the same battlefield
// get adjacent sectors (0, right, left, 2x right, ...) instead of overlapping corridors.
if (isNil "ARTIC_BattlefieldAllocations") then {ARTIC_BattlefieldAllocations = createHashMap;};
private _alloc = ARTIC_BattlefieldAllocations getOrDefault [_bfId,[]];
_alloc = _alloc select {(time - (_x select 1)) < 600};
private _aIdx = _alloc findIf {(_x select 0) isEqualTo _nodeId};
if (_aIdx < 0) then {_alloc pushBack [_nodeId,time]; _aIdx = (count _alloc) - 1;} else {(_alloc select _aIdx) set [1,time];};
ARTIC_BattlefieldAllocations set [_bfId,_alloc];

private _focusBase = +_focus;          // unshifted battlefield centre (sector shift applied below)
private _existing = _node getOrDefault ["battleContext",createHashMap];
private _same = (count _existing) > 0 && {(_existing getOrDefault ["battlefieldId",""]) isEqualTo _bfId} && {((_existing getOrDefault ["objective",[0,0,0]]) distance2D _objective) < 35};
private _ctx = _existing;
// v0.3.29: once a live PlatoonPlan exists, geometry and role ownership are immutable
// from DEPLOY through execution. Fresh intelligence may update the picture, but it cannot
// silently rewrite the active plan. Only REASSESS may supersede it.
private _fsmRuntime = missionNamespace getVariable ["ARTIC_useFSMHierarchy",true];
private _runtimePlan = _node getOrDefault ["platoonPlan",createHashMap];
private _runtimePlanStatus = toUpper (_runtimePlan getOrDefault ["status",""]);
private _runtimePlanLocked = _fsmRuntime && {_runtimePlanStatus in ["ACTIVE","DEPLOY","READY_CHECK","EXECUTE","CONSOLIDATE"]};
private _runtimePlanSuperseded = _fsmRuntime && {_runtimePlanStatus isEqualTo "SUPERSEDED"};
if (_runtimePlanLocked && {(count _existing) > 0}) then {
    _same = true;
    _bfId = _existing getOrDefault ["battlefieldId",_bfId];
};
if (_runtimePlanSuperseded) then {_same = false;};
// Merge fresh reports with previous battle tracks. Tracks remain usable for ten minutes.
private _battleTargets = +_freshBattleTargets;
private _battleTracks = +_freshBattleTracks;
{
    _x params ["_o","_p","_t",["_src","BATTLE"]];
    if (_p isNotEqualTo [] && {(time - _t) < 600}) then {
        private _idx = _battleTracks findIf {(_x select 0) isEqualTo _o};
        if (_idx < 0) then {_battleTracks pushBack [_o,+_p,_t,_src];};
        if ([_o] call ARTIC_fnc_isCombatEffectiveTarget) then {_battleTargets pushBackUnique _o;};
    };
} forEach (_existing getOrDefault ["battleTracks",[]]);
if (_freshBattleTracks isEqualTo [] && {_battleTracks isNotEqualTo []}) then {
    _contactPos = _battleTracks apply {+(_x select 1)};
    _hasEnemyIntel = true;
};

// v0.3.18: a failed fire-position solution is temporary.  Re-open the COA search when
// fresh intelligence arrives, enemy strength changes materially, the enemy focus moves,
// or the held plan has simply been stale for long enough.  This prevents one 0%-LOS SBF
// result from becoming a permanent HOLD_FOR_FIRE_POSITION state.
if (_same && {(count _existing) > 0} && {!_runtimePlanLocked}) then {
    private _oldAssess = _existing getOrDefault ["assessment",createHashMap];
    private _oldEnemy = _oldAssess getOrDefault ["enemyStrength",0];
    private _newEnemy = _assessment getOrDefault ["enemyStrength",0];
    private _enemyDelta = if (_oldEnemy > 0) then {abs (_newEnemy - _oldEnemy) / _oldEnemy} else {if (_newEnemy > 0) then {1} else {0}};
    private _focusShift = (_existing getOrDefault ["focus",_focus]) distance2D _focus;
    private _intelChanged = _hasEnemyIntel && {!(_existing getOrDefault ["hasEnemyIntel",false])};
    private _oldScheme = _existing getOrDefault ["schemeMode","HOLD"];
    private _invalid = (_oldScheme isEqualTo "HOLD")
        || {_oldScheme isEqualTo "SUPPORT_MANOEUVRE" && {!(_existing getOrDefault ["fixValid",false])}}
        || {((_oldAssess getOrDefault ["plan",""]) in ["HOLD_FOR_FIRE_POSITION","HOLD_FOR_TACTICAL_OPTION"])};
    private _lastReview = _existing getOrDefault ["lastPlanReview",_existing getOrDefault ["created",time]];
    private _reviewDue = (time - _lastReview) >= (if (_invalid) then {22} else {45});
    if (_intelChanged || {_focusShift > 55} || {_enemyDelta >= 0.25} || {_invalid && {_reviewDue}}) then {
        _same = false;
        [format ["Battle plan review triggered: invalid=%1 intelChanged=%2 enemyDelta=%3%% focusShift=%4m",_invalid,_intelChanged,round (_enemyDelta*100),round _focusShift],_nodeId] call ARTIC_fnc_debug;
    };
};
// v0.3.27: a tactical failure unlocks the battle plan once all local plays have
// finished. Plan stability remains, but a failed tactic is not immutable. The server resets
// sections to PLATOON ownership so the next context can choose a different scheme.
private _latestFailure = "";
private _latestFailureAt = -1e6;
private _failedScheme = "";
{
    private _fa = _x getVariable ["ARTIC_planFailureAt",-1e6];
    private _fr = _x getVariable ["ARTIC_planFailureReason",""];
    if (_fr isNotEqualTo "" && {_fa > _latestFailureAt}) then {
        _latestFailureAt = _fa;
        _latestFailure = _fr;
        _failedScheme = _x getVariable ["ARTIC_tacticalScheme",""];
    };
} forEach _groups;
private _activePlans = (_groups findIf {(_x getVariable ["ARTIC_currentPlan",""]) isNotEqualTo ""}) > -1;
private _handledFailureAt = _node getOrDefault ["lastHandledFailureAt",-1e6];
private _failureReplan = !_fsmRuntime && {!_activePlans} && {_latestFailure isNotEqualTo ""} && {_latestFailureAt > _handledFailureAt} && {(time - _latestFailureAt) < 180};
if (_failureReplan) then {
    _same = false;
    _node set ["lastHandledFailureAt",_latestFailureAt];
    _node set ["lastPlanFailureReason",_latestFailure];
    _node set ["lastFailedScheme",_failedScheme];
    _node set ["executionStart",-1e6];
    _node set ["march",createHashMap];
    {
        _x setVariable ["ARTIC_tacticalExecutionArmed",false,true];
        _x setVariable ["ARTIC_platoonTacticalReleased",false,true];
        _x setVariable ["ARTIC_executionOrderType","PLATOON",true];
        _x setVariable ["ARTIC_executionOrderPos",[],true];
        _x setVariable ["ARTIC_orderType","PLATOON",true];
        _x setVariable ["ARTIC_orderPos",[],true];
        _x setVariable ["ARTIC_platoonFinalSlot",nil,true];
        _x setVariable ["ARTIC_planFailureReason","",true];
    } forEach _groups;
    [format ["TACTICAL REASSESSMENT: failure=%1 failedScheme=%2; plan unlocked for alternate tactic",_latestFailure,_failedScheme],_nodeId] call ARTIC_fnc_debug;
};

// ---------------------------------------------------------------------------
// v0.3.24: LOCK the plan while the platoon is executing. Once released, the axis, SBF and
// corridors stay fixed until the attack finishes or aborts (every play ended and 90 s since
// release), unless the enemy has moved substantially (> 200 m). In the 0.3.23 test a new
// ground contact rebuilt the context (axis 86 -> 18) 46 s after release, while the FIX and
// manoeuvre sections were executing the old plan.
// ---------------------------------------------------------------------------
private _executing = !_failureReplan && {
    _runtimePlanLocked
    || {((_groups findIf {(_x getVariable ["ARTIC_currentPlan",""]) isNotEqualTo ""}) > -1)}
    || {(time - (_node getOrDefault ["executionStart",-1e6])) < 90}
};
private _locked = false;
if (_executing && {(count _existing) > 0} && {((_existing getOrDefault ["objective",[0,0,0]]) distance2D _objective) < 35}
    && {((_existing getOrDefault ["focus",_focus]) distance2D _focus) < 200}) then {
    if (!_same) then {
        if ((time - (_node getOrDefault ["lockLogAt",-1e6])) > 30) then {
            [format ["Battle plan LOCKED during execution (re-plan suppressed: battlefield %1 -> %2)",_existing getOrDefault ["battlefieldId","?"],_bfId],_nodeId] call ARTIC_fnc_debug;
            _node set ["lockLogAt",time];
        };
    };
    _same = true;
    _locked = true;
    _bfId = _existing getOrDefault ["battlefieldId",_bfId];
};
// v0.3.26: SBF quality is judged across a representative FIX fire line rather than
// by one anchor point. 40% remains a preferred quality signal; 25% aggregate coverage
// with multiple useful line points is a normal viable solution. A weaker LIMITED solution
// may be accepted after one failed review when the force-ratio assessment still permits
// an assault, preventing permanent HOLD_FOR_FIRE_POSITION deadlock.
private _preferredSbfCoverage = missionNamespace getVariable ["ARTIC_preferredSbfCoverage",0.40];
private _minSbfCoverage = missionNamespace getVariable ["ARTIC_minSbfCoverage",0.25];
private _limitedSbfCoverage = missionNamespace getVariable ["ARTIC_limitedSbfCoverage",0.125];
private _minSbfUsefulPoints = missionNamespace getVariable ["ARTIC_minSbfUsefulPoints",2];
private _priorSbfFailures = _existing getOrDefault ["sbfFailureCount",0];
private _sbfFailureCount = _priorSbfFailures;
private _degradedAccepted = false;

private _preselectedFix = [];
private _preselectedSight = -1;
private _preselectedLineCoverage = -1;
private _preselectedUsefulPoints = 0;
private _coaData = createHashMap;
private _baseAxisForCOA = _friendlyCentre getDir _focus;

// v0.3.30: a first TIMING failure of a scheme retries the same scheme.
// v0.3.30.2: a retry also keeps the failed plan's AXIS (the COA search evaluates only that
// axis). 0.3.30.1 re-ran the full search on a "retry", flipped the axis 177 deg and marched the
// platoon through the objective to reach the new side.
private _lastClass = _node getOrDefault ["lastPlanFailureClass",""];
private _lastScheme = _node getOrDefault ["lastFailedScheme",""];
private _retrySame = _lastClass isEqualTo "TIMING" && {((_node getOrDefault ["timingRetries",createHashMap]) getOrDefault [_lastScheme,0]) <= 1};
private _retryAxis = if (_retrySame) then {_node getOrDefault ["lastFailedAxis",-1]} else {-1};

if (!_same) then {
    private _axis = _baseAxisForCOA;
    private _lineGroups = _groups select {([_x] call ARTIC_fnc_scanGroupCapabilities) getOrDefault ["strength",0] >= 4};
    private _frontage = (((count _lineGroups) * 42) max (_bfRadius * 0.8) max 75) min 220;
    private _ratio = _assessment getOrDefault ["forceRatio",1];

    // company sector (see registry above): shift this node's battle frame sideways
    private _sectorK = [0,1,-1,2,-2,3,-3] param [_aIdx,0];
    private _shiftVec = [0,0,0];
    if (_sectorK isNotEqualTo 0) then {
        private _shifted = _focus getPos [abs (_sectorK * _frontage), _axis + ([90,-90] select (_sectorK < 0))];
        _shiftVec = [(_shifted select 0) - (_focus select 0),(_shifted select 1) - (_focus select 1),0];
        _focus = [(_shifted select 0),(_shifted select 1),0];
        _axis = _friendlyCentre getDir _focus;
        [format ["Battlefield %1 shared: %2 takes sector %3 (%4 m %5 of centre)",_bfId,_nodeId,_aIdx + 1,round (abs (_sectorK * _frontage)),["right","left"] select (_sectorK < 0)],_nodeId] call ARTIC_fnc_debug;
    };
    _baseAxisForCOA = _friendlyCentre getDir _focus;

    // v0.3.15: distances from terrain / visibility / weapons (fn_getBattleEnvelope)
    // instead of the fixed 320-380 m hold and 185-220 m fire position.
    private _env = [_focus,(_assessment getOrDefault ["mg",0]) >= 2] call ARTIC_fnc_getBattleEnvelope;
    private _fireDepth = (_env get "fireDepth") max (_bfRadius + 40);
    private _holdDepth = ((_env get "holdDepth") max (_fireDepth + 70)) + ([0,40] select (_ratio < 0.7));
    private _assaultDepth = ((_env get "assaultDepth") max ((_bfRadius * 0.35) min 85)) min (_fireDepth - 20);
    private _searchFire = _env get "searchFire";
    private _searchHold = _env get "searchHold";

    // v0.3.27: search both support-by-fire and manoeuvre quality. A useful SBF may
    // select the classic support/manoeuvre scheme; when no credible SBF exists, ARTIC can
    // still select a safe manoeuvre axis and change the scheme instead of holding forever.
    private _geometryOnlyAccepted = false;
    private _coaAccepted = false;
    if (_hasEnemyIntel) then {
        _coaData = [_focus,_friendlyCentre,_contactPos,_fireDepth,_bfRadius,_frontage,_retryAxis] call ARTIC_fnc_generateBattleCOAs;
        if ((count _coaData) > 0) then {
            private _selectedAxis = _coaData getOrDefault ["axis",_axis];
            private _supportValid = _coaData getOrDefault ["valid",false];
            private _baseAssaultAllowed = _assessment getOrDefault ["assaultAllowed",false];
            private _forceRatioCOA = _assessment getOrDefault ["forceRatio",1];

            if (_supportValid) then {
                _coaAccepted = true;
                _axis = _selectedAxis;
                _preselectedFix = +(_coaData getOrDefault ["sbf",[]]);
                _preselectedSight = _coaData getOrDefault ["anchorSight",_coaData getOrDefault ["sight",-1]];
                _preselectedLineCoverage = _coaData getOrDefault ["fireLineCoverage",-1];
                _preselectedUsefulPoints = _coaData getOrDefault ["fireLineUsefulPoints",0];
            } else {
                private _manValid = _coaData getOrDefault ["manoeuvreValid",false];
                private _manAxis = _coaData getOrDefault ["manoeuvreAxis",_baseAxisForCOA];
                private _manScore = _coaData getOrDefault ["manoeuvreScore",-1e9];
                if (_manValid && {_baseAssaultAllowed} && {(count _lineGroups) >= 2} && {_forceRatioCOA >= 0.95}) then {
                    _axis = _manAxis;
                    _selectedAxis = _manAxis;
                    _geometryOnlyAccepted = true;
                    _coaAccepted = true;
                    _preselectedFix = [];
                    _preselectedSight = -1;
                    _preselectedLineCoverage = -1;
                    _preselectedUsefulPoints = 0;
                    [format ["COA manoeuvre axis accepted without SBF: axis=%1 manoeuvreScore=%2 ratio=%3; alternate scheme required",
                        round _manAxis,round _manScore,(round (_forceRatioCOA * 100))/100],_nodeId] call ARTIC_fnc_debug;
                } else {
                    _axis = _baseAxisForCOA;
                    _preselectedFix = [];
                    _preselectedSight = -1;
                    _preselectedLineCoverage = -1;
                    _preselectedUsefulPoints = 0;
                };
            };

            private _candLog = [];
            {
                _candLog pushBack format ["%1:a%2/l%3/p%4/s%5/m%6",
                    round (_x getOrDefault ["axis",0]),
                    round (100 * (_x getOrDefault ["anchorSight",_x getOrDefault ["sight",0]])),
                    round (100 * (_x getOrDefault ["fireLineCoverage",0])),
                    _x getOrDefault ["fireLineUsefulPoints",0],
                    round (_x getOrDefault ["score",0]),
                    round (_x getOrDefault ["manoeuvreScore",0])];
            } forEach (_coaData getOrDefault ["candidates",[]]);
            {if !(_x getOrDefault ["repoSafe",true]) then {_candLog set [_forEachIndex,(_candLog select _forEachIndex) + "/REPO_UNSAFE"];};} forEach (_coaData getOrDefault ["candidates",[]]);
            private _logAnchor = _coaData getOrDefault ["anchorSight",_coaData getOrDefault ["sight",-1]];
            private _logLine = _coaData getOrDefault ["fireLineCoverage",-1];
            private _logUseful = _coaData getOrDefault ["fireLineUsefulPoints",0];
            [format ["COA search base=%1 selected=%2 accepted=%3 geometryOnly=%4 supportValid=%5 anchor=%6%% fireLine=%7%% useful=%8 candidates[%9]",
                round _baseAxisForCOA,round _axis,_coaAccepted,_geometryOnlyAccepted,_supportValid,
                round (_logAnchor*100),round (_logLine*100),_logUseful,_candLog joinString " "],_nodeId] call ARTIC_fnc_debug;
            if ((_coaData getOrDefault ["repositionUnsafeCount",0]) > 0) then {
                [format ["COA reposition safety: %1 axis candidate(s) rejected; their reposition march passes within %2 m of known enemy",
                    _coaData get "repositionUnsafeCount",missionNamespace getVariable ["ARTIC_repositionStandoff",150]],_nodeId] call ARTIC_fnc_debug;
            };
            if (_retryAxis >= 0) then {
                [format ["COA TIMING retry: evaluating only the failed plan's axis %1",round _retryAxis],_nodeId] call ARTIC_fnc_debug;
            };
        };
    };

    // v0.3.27: choose a geometry family before control points are generated. A credible
    // support COA gets the classic FIX + manoeuvre geometry. If support LOS is not credible,
    // terrain/force ratio can select an envelopment geometry immediately rather than
    // building another doomed SBF-centric plan.
    private _plan0 = _assessment getOrDefault ["plan","FIX_LEFT_RIGHT"];
    private _forceRatioForScheme = _assessment getOrDefault ["forceRatio",1];
    private _baseAssaultForScheme = _assessment getOrDefault ["assaultAllowed",false];
    private _supportLikely = _coaData getOrDefault ["valid",false];
    private _priorFailure = toUpper (_node getOrDefault ["lastPlanFailureReason",""]);
    private _shape = "HOLD";
    if (_baseAssaultForScheme && {_hasEnemyIntel}) then {
        if (_supportLikely && {!((_priorFailure find "FIX_") isEqualTo 0)}) then {
            _shape = "FIX_LEFT_RIGHT";
        } else {
            if ((count _lineGroups) >= 3 && {_forceRatioForScheme >= 1.05}) then {
                _shape = "DOUBLE_ENVELOPMENT";
            } else {
                if ((count _lineGroups) >= 2 && {_forceRatioForScheme >= 1.20}) then {
                    _shape = "SINGLE_FLANK";
                } else {
                    _shape = "HOLD";
                };
            };
        };
    };
    // Doctrine-informed attack control measures. The HOLD/attack position is where the
    // platoon assembles; the PLD is where support/assault forces are fully deployed;
    // the assault position is the last covered/concealed position; the FCL is where
    // final assault formation and fire-shift coordination occur.
    private _pldDepth = ((((_fireDepth + 65) min (_holdDepth - 35)) max (_assaultDepth + 95)) min (_holdDepth - 20)) max (_assaultDepth + 20);
    private _fclDepth = ((_assaultDepth * 0.48) max 24) min 45;
    private _reserveDepth = _holdDepth + 55;
    private _releaseDepth = _holdDepth + 95;

    private _point = {
        params ["_depth","_lat"];
        private _p = _focus getPos [_depth,_axis + 180];
        if ((abs _lat) > 0.1) then {
            _p = _p getPos [abs _lat,_axis + (if (_lat < 0) then {-90} else {90})];
        };
        _p set [2,0];
        _p
    };

    // Ideal geometry first, then deform each important control point to terrain.
    private _leftHoldIdeal = [_holdDepth,-_frontage * 0.58] call _point;
    private _rightHoldIdeal = [_holdDepth,_frontage * 0.58] call _point;
    private _fixHoldIdeal = [_holdDepth,0] call _point;
    private _releaseIdeal = [_releaseDepth,0] call _point;
    // v0.3.15: corridor stages follow the derived distances (0.3.13's "at least 210 m" /
    // "at least 115 m" put stages behind the hold line in close country)
    private _stage1Depth = _fireDepth + (_holdDepth - _fireDepth) * 0.5;
    private _stage2Depth = (_fireDepth * 0.75) max (_assaultDepth + 25);
    private _wide = [1,1.25] select (_shape isEqualTo "DOUBLE_ENVELOPMENT");
    private _left1Ideal = [_stage1Depth,-_frontage * 0.72 * _wide] call _point;
    private _right1Ideal = [_stage1Depth,_frontage * 0.72 * _wide] call _point;
    private _left2Ideal = [_stage2Depth,-_frontage * 0.83 * _wide] call _point;
    private _right2Ideal = [_stage2Depth,_frontage * 0.83 * _wide] call _point;
    private _leftAssaultIdeal = if (_shape isEqualTo "DOUBLE_ENVELOPMENT") then {[_assaultDepth * 0.3,-_frontage * 0.7] call _point} else {[_assaultDepth,-_frontage * 0.42] call _point};
    private _rightAssaultIdeal = if (_shape isEqualTo "DOUBLE_ENVELOPMENT") then {[_assaultDepth * 0.3,_frontage * 0.7] call _point} else {[_assaultDepth,_frontage * 0.42] call _point};
    private _fixIdeal = [_fireDepth,0] call _point;

    private _release = ([_releaseIdeal,_focus,"RELEASE",60,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _leftHold = ([_leftHoldIdeal,_focus,"HOLD",_searchHold,_axis,-1,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _rightHold = ([_rightHoldIdeal,_focus,"HOLD",_searchHold,_axis,1,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _fixHold = ([_fixHoldIdeal,_focus,"HOLD",_searchHold,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _left1 = ([_left1Ideal,_focus,"APPROACH",48,_axis,-1,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _right1 = ([_right1Ideal,_focus,"APPROACH",48,_axis,1,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _left2 = ([_left2Ideal,_focus,"APPROACH",42,_axis,-1,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _right2 = ([_right2Ideal,_focus,"APPROACH",42,_axis,1,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _leftAssault = ([_leftAssaultIdeal,_focus,"ASSAULT",36,_axis,-1,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _rightAssault = ([_rightAssaultIdeal,_focus,"ASSAULT",36,_axis,1,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _fixPos = ([_fixIdeal,_focus,"FIRE",_searchFire,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;

    private _reserve = ([[_reserveDepth,0] call _point,_focus,"HOLD",45,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _rally = ([[_holdDepth + 30,0] call _point,_focus,"HOLD",35,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;

    // ---- v0.3.15 shape-specific control points ------------------------------------
    // How well hidden is a corridor from the known enemy? (hidden stages + cover)
    private _corridorScore = {
        params ["_pts"];
        private _sc = 0;
        {
            _sc = _sc + (1 - (([_x,_contactPos] call ARTIC_fnc_battleSight) select 0));
            _sc = _sc + (((count (nearestTerrainObjects [_x,["TREE","SMALL TREE","BUSH","ROCK","HOUSE","WALL"],20,false,true])) min 10) / 20);
        } forEach _pts;
        _sc
    };
    private _flankSide = 0;
    if (_shape in ["SINGLE_FLANK","TWO_AXIS_RESERVE"]) then {
        private _ls = [[_leftHold,_left1,_left2]] call _corridorScore;
        private _rs = [[_rightHold,_right1,_right2]] call _corridorScore;
        _flankSide = [1,-1] select (_ls >= _rs);
    };
    if (_shape isEqualTo "TWO_AXIS_RESERVE") then {
        // reserve behind the better-covered flank, ready to exploit
        _reserve = ([[_holdDepth - 40,_flankSide * _frontage * 0.5] call _point,_focus,"HOLD",45,_axis,_flankSide,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    };

    private _keypoint = [];
    private _breakCorridor = [];
    private _breakFollow = [];
    // Legacy BREAK_IN geometry is currently not selected by the v0.3.27 scheme selector,
    // but keep the branch runtime-safe for future reintroduction.
    private _statics = [];
    if (_shape isEqualTo "BREAK_IN") then {
        // keypoint: a static weapon if known, else the densest enemy position
        _keypoint = if (_statics isNotEqualTo []) then {getPosATL (_statics select 0)} else {
            private _bestN = -1; private _kp = +_focus;
            {
                private _c = _x;
                private _n = {(_x distance2D _c) < 40} count _contactPos;
                if (_n > _bestN) then {_bestN = _n; _kp = +_c;};
            } forEach _contactPos;
            _kp
        };
        // oblique fire position (~40 deg off the axis), on whichever side sees better
        private _kTargets = [_keypoint] + _contactPos;
        private _candL = ([_keypoint getPos [_fireDepth * 0.85,_axis + 180 - 40],_keypoint,"FIRE",_searchFire,_axis,-1,_kTargets] call ARTIC_fnc_findBattleControlPoint);
        private _candR = ([_keypoint getPos [_fireDepth * 0.85,_axis + 180 + 40],_keypoint,"FIRE",_searchFire,_axis,1,_kTargets] call ARTIC_fnc_findBattleControlPoint);
        private _sbfLeft = (_candL select 1) >= (_candR select 1);
        _fixPos = [_candR select 0,_candL select 0] select _sbfLeft;
        // assault approaches at ~90 deg to the fire position's line of fire, from the
        // friendly side, so the assault never walks into its own supporting fire
        private _sbfBearing = _keypoint getDir _fixPos;
        private _a1 = (_sbfBearing + 90) % 360; private _a2 = (_sbfBearing + 270) % 360;
        private _friendlyBearing = (_axis + 180) % 360;
        private _angDiff = {params ["_a","_b"]; abs ((((_a - _b) + 540) % 360) - 180)};
        private _appr = if (([_a1,_friendlyBearing] call _angDiff) <= ([_a2,_friendlyBearing] call _angDiff)) then {_a1} else {_a2};
        private _ual = ([_keypoint getPos [50,_appr],_keypoint,"ASSAULT",30,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
        private _bs1 = ([_keypoint getPos [_stage1Depth,_appr],_keypoint,"APPROACH",48,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
        private _bs2 = ([_keypoint getPos [_stage2Depth,_appr],_keypoint,"APPROACH",42,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
        private _bHold = ([_keypoint getPos [_holdDepth,_appr],_keypoint,"HOLD",_searchHold,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
        _breakCorridor = [_bHold,_bs1,_bs2,_ual];
        // the second manoeuvre section follows ~30 m behind to exploit the break-in
        _breakFollow = _breakCorridor apply {_x getPos [30,_appr]};
    };
    private _sightTargets = [_keypoint,_contactPos] select (_keypoint isEqualTo []);
    private _fixSight = -1;
    private _fixValid = false;
    private _fixLineCoverage = 0;
    private _fixUsefulPoints = 0;
    private _fixLinePoints = 0;

    if (_hasEnemyIntel) then {
        // v0.3.17: search a broad friendly-side arc around the battlefield. Earlier
        // builds repeatedly deformed one central ideal SBF and could keep returning a
        // reverse-slope point with 0% visibility even when an oblique firing position
        // existed elsewhere.
        if (_preselectedFix isNotEqualTo []) then {
            _fixPos = +_preselectedFix;
            _fixSight = _preselectedSight;
        } else {
            private _arcFriendly = _focus getPos [(_fireDepth + 95) max (_bfRadius + 130),_axis + 180];
            private _arc = [_focus,_arcFriendly,_sightTargets,_fireDepth,_bfRadius] call ARTIC_fnc_findSupportArc;
            private _arcPos = _arc select 0;
            private _arcSight = _arc select 1;
            if (_arcPos isNotEqualTo []) then {
                _fixPos = +_arcPos;
                _fixSight = _arcSight;
            } else {
                _fixSight = ([_fixPos,_sightTargets] call ARTIC_fnc_battleSight) select 0;
            };
        };
        // v0.3.26: validate the section-sized fire line, not one anchor. If this was the
        // COA-selected point reuse its metrics; otherwise evaluate the fallback arc now.
        private _lineEval = createHashMap;
        _fixLineCoverage = _preselectedLineCoverage;
        _fixUsefulPoints = _preselectedUsefulPoints;
        _fixLinePoints = 0;
        if (_fixLineCoverage < 0) then {
            _lineEval = [_fixPos,_focus,_sightTargets,_axis,_frontage,8] call ARTIC_fnc_evaluateSbfFireLine;
            _fixLineCoverage = _lineEval getOrDefault ["coverage",0];
            _fixUsefulPoints = _lineEval getOrDefault ["usefulPoints",0];
            _fixLinePoints = _lineEval getOrDefault ["totalPoints",0];
        } else {
            _fixLinePoints = _coaData getOrDefault ["fireLineTotalPoints",5];
        };

        private _standardFix = _fixLineCoverage >= _minSbfCoverage && {_fixUsefulPoints >= _minSbfUsefulPoints};
        _fixValid = _standardFix;
        _sbfFailureCount = if (_fixValid) then {0} else {_priorSbfFailures + 1};

        if (_fixValid) then {
            [format ["Battle context %1: SBF %2 accepted STANDARD anchor=%3%% fireLine=%4%% useful=%5/%6",
                _bfId,mapGridPosition _fixPos,
                if (_fixSight < 0) then {-1} else {round (_fixSight * 100)},round (_fixLineCoverage * 100),
                _fixUsefulPoints,_fixLinePoints],_nodeId] call ARTIC_fnc_debug;
        } else {
            [format ["Battle context %1: no credible SBF (anchor=%2%% aggregate=%3%% useful=%4/%5); evaluating alternate manoeuvre scheme",
                _bfId,if (_fixSight < 0) then {-1} else {round (_fixSight * 100)},round (_fixLineCoverage * 100),
                _fixUsefulPoints,_fixLinePoints],_nodeId] call ARTIC_fnc_debug;
        };
    } else {
        _fixValid = false;
        _sbfFailureCount = _priorSbfFailures + 1;
    };

    // v0.3.27: assess the ACTUAL safe approach corridors before choosing a tactic.
    // A double envelopment requires two usable axes; a single envelopment needs one. This
    // prevents the scheme selector from assigning a section to a flank that only looks good
    // geometrically but requires a pathological detour around the enemy/terrain.
    private _routeQuality = {
        params ["_dest","_role"];
        private _avoid = (_bfRadius + 80) max 100;
        private _r = [_release,_dest,_focus,_role,_axis,_frontage,_avoid] call ARTIC_fnc_planSectionRoute;
        private _direct = (_release distance2D _dest) max 1;
        private _len = 0;
        private _prev = +_release;
        private _mask = 0;
        private _maskN = 0;
        {
            _len = _len + (_prev distance2D _x);
            _prev = +_x;
            private _seen = ([_x,_sightTargets,6] call ARTIC_fnc_battleSight) select 0;
            _mask = _mask + (1 - _seen);
            _maskN = _maskN + 1;
        } forEach _r;
        private _ratioR = _len / _direct;
        private _maskAvg = if (_maskN > 0) then {_mask / _maskN} else {0};
        private _okR = _r isNotEqualTo [] && {_ratioR <= 2.7} && {_len <= 850};
        private _scoreR = 25 * _maskAvg - 8 * ((_ratioR - 1) max 0) - 0.006 * _len;
        createHashMapFromArray [["route",_r],["direct",_direct],["length",_len],["ratio",_ratioR],["mask",_maskAvg],["valid",_okR],["score",_scoreR]]
    };
    private _leftRouteEval = [_leftHold,"MANOEUVRE_LEFT"] call _routeQuality;
    private _rightRouteEval = [_rightHold,"MANOEUVRE_RIGHT"] call _routeQuality;
    private _leftRouteOK = _leftRouteEval getOrDefault ["valid",false];
    private _rightRouteOK = _rightRouteEval getOrDefault ["valid",false];
    private _leftRouteScore = _leftRouteEval getOrDefault ["score",-1e9];
    private _rightRouteScore = _rightRouteEval getOrDefault ["score",-1e9];

    // v0.3.27: the tactic, not the SBF alone, decides whether an attack is possible.
    // SUPPORT_MANOEUVRE requires a credible FIX position. DOUBLE/SINGLE envelopment do not;
    // they synchronize manoeuvre sections at their attack positions and use BLOCK/RESERVE
    // to isolate the objective. A failed FIX plan therefore changes tactic on reassessment.
    // v0.3.30 CONTACT-AWARE REPLANNING. Sections engaged with, or within ~100 m of, a live
    // known enemy are COMMITTED: they are not marched back out to a new deployment point. The
    // best placed one (engaged before close, then nearest) becomes the FIX element where it
    // stands; the platoon then fights from contact (support and manoeuvre). In the 0.3.29 run
    // the replan routed Alpha 1-2 from the edge of the objective back round a 10-gate route
    // in a platoon column; it met the enemy at 67 m and 6 m and ended with one man.
    private _committedInfo = [];
    if ((missionNamespace getVariable ["ARTIC_contactAwareReplan",true]) && {_hasEnemyIntel}) then {
        {
            private _cs = [_x] call ARTIC_fnc_assessSectionContact;
            if ((_cs select 0) in ["ENGAGED","CLOSE"]) then {_committedInfo pushBack [_x,_cs select 0,_cs select 2,_cs select 1];};
        } forEach _groups;
    };
    private _contactAnchor = grpNull;
    private _anchorCands = _committedInfo select {((([_x select 0] call ARTIC_fnc_scanGroupCapabilities) getOrDefault ["strength",0]) >= 3)};
    if (_anchorCands isNotEqualTo []) then {
        _anchorCands = [_anchorCands,[],{([1000,0] select ((_x select 1) isEqualTo "ENGAGED")) + (_x select 2)},"ASCEND"] call BIS_fnc_sortBy;
        _contactAnchor = (_anchorCands select 0) select 0;
    };
    private _contactFix = !isNull _contactAnchor;
    if (_contactFix) then {
        _fixPos = [_contactAnchor] call _sectionPos;
        _fixPos set [2,0];
        _fixHold = +_fixPos;
        _fixValid = true;
        _fixSight = ([_fixPos,_sightTargets] call ARTIC_fnc_battleSight) select 0;
        [format ["CONTACT-AWARE PLAN: committed=[%1]; %2 fixes in place at %3 (sight %4%%)",
            (_committedInfo apply {format ["%1 %2 %3m",groupId (_x select 0),_x select 1,round (_x select 2)]}) joinString ", ",
            groupId _contactAnchor,mapGridPosition _fixPos,round (_fixSight * 100)],_nodeId] call ARTIC_fnc_debug;
    };

    private _schemeDecision = [_groups,_assessment,_fixValid,_fixLineCoverage,_fixUsefulPoints,
        _node getOrDefault ["lastPlanFailureReason",""],
        _node getOrDefault ["lastFailedScheme",""] ,
        _leftRouteOK,_rightRouteOK,_leftRouteScore,_rightRouteScore,_contactFix,_retrySame] call ARTIC_fnc_selectAttackScheme;
    private _schemeMode = _schemeDecision getOrDefault ["mode","HOLD"];
    private _schemeReason = _schemeDecision getOrDefault ["reason","UNKNOWN"];
    // v0.3.30.2: the axis-locked retry was not feasible -> spend the retry budget so the next
    // reassessment cycle runs the full COA search instead of holding on this axis.
    if (_retrySame && {_schemeMode isNotEqualTo _lastScheme}) then {
        private _rt = _node getOrDefault ["timingRetries",createHashMap];
        _rt set [_lastScheme,99];
        _node set ["timingRetries",_rt];
        [format ["COA TIMING retry of %1 not feasible on axis %2; full reassessment from the next cycle",_lastScheme,round _retryAxis],_nodeId] call ARTIC_fnc_debug;
    };
    private _selectedFlankSide = _schemeDecision getOrDefault ["flankSide",_flankSide];
    if (_selectedFlankSide isNotEqualTo 0) then {_flankSide = _selectedFlankSide;};
    if (!_hasEnemyIntel) then {
        _schemeMode = "HOLD";
        _schemeReason = "PENDING_INTEL";
        _assessment set ["assaultAllowed",false];
        _assessment set ["plan","PENDING_INTEL"];
        [format ["Battle context %1: objective-only geometry; awaiting enemy intelligence before attack approval",_bfId],_nodeId] call ARTIC_fnc_debug;
    } else {
        switch (_schemeMode) do {
            case "SUPPORT_MANOEUVRE": {
                _shape = "FIX_LEFT_RIGHT";
                _assessment set ["plan","FIX_LEFT_RIGHT"];
            };
            case "DOUBLE_ENVELOPMENT": {
                _shape = "DOUBLE_ENVELOPMENT";
                _assessment set ["assaultAllowed",true];
                _assessment set ["plan","DOUBLE_ENVELOPMENT"];
            };
            case "SINGLE_ENVELOPMENT": {
                _shape = "SINGLE_FLANK";
                _assessment set ["assaultAllowed",true];
                _assessment set ["plan","SINGLE_ENVELOPMENT"];
            };
            default {
                _shape = "HOLD";
                _assessment set ["assaultAllowed",false];
                _assessment set ["plan","HOLD_FOR_TACTICAL_OPTION"];
            };
        };
    };
    [format ["TACTICAL SCHEME selected=%1 reason=%2 fixValid=%3 line=%4%% useful=%5 ratio=%6 routes[L=%7 r%8/%9m M%10%% R=%11 r%12/%13m M%14%%]",
        _schemeMode,_schemeReason,_fixValid,round (_fixLineCoverage * 100),_fixUsefulPoints,
        (round ((_assessment getOrDefault ["forceRatio",1]) * 100))/100,
        _leftRouteOK,(round ((_leftRouteEval getOrDefault ["ratio",99]) * 100))/100,round (_leftRouteEval getOrDefault ["length",0]),round (100 * (_leftRouteEval getOrDefault ["mask",0])),
        _rightRouteOK,(round ((_rightRouteEval getOrDefault ["ratio",99]) * 100))/100,round (_rightRouteEval getOrDefault ["length",0]),round (100 * (_rightRouteEval getOrDefault ["mask",0]))],_nodeId] call ARTIC_fnc_debug;

    // Lines are based on terrain-selected anchor points, but remain broad enough to show
    // the platoon's control measures. Endpoints are perpendicular to the attack axis.
    private _lineAround = {
        params ["_centre","_half"];
        [_centre getPos [_half,_axis - 90],_centre getPos [_half,_axis + 90]]
    };
    private _holdCentre = ((_leftHold vectorAdd _rightHold) vectorMultiply 0.5);
    private _assaultCentre = ((_leftAssault vectorAdd _rightAssault) vectorMultiply 0.5);
    private _pldCentreIdeal = [_pldDepth,0] call _point;
    private _pldCentre = ([_pldCentreIdeal,_focus,"APPROACH",45,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _fclCentreIdeal = [_fclDepth,0] call _point;
    private _fclCentre = ([_fclCentreIdeal,_focus,"ASSAULT",24,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
    private _holdLine = [_holdCentre,_frontage] call _lineAround;
    private _pldLine = [_pldCentre,_frontage * 0.82] call _lineAround;
    // v0.3.22: the FIX section deploys to its SBF as part of the approach. Its HOLD /
    // attack position is a covered point just behind the SBF (away from the enemy), not
    // the platoon-centre hold line. In the 0.3.21 test the FIX hold (041039) was ~300 m from
    // its SBF (041036), so the support element started a long lateral move only at release.
    // Only once the SBF is validated against real enemy intelligence; before that the SBF
    // is a geometric placeholder and FIX keeps the normal platoon hold position.
    if (_fixValid && {!_contactFix} && {_fixPos isNotEqualTo []}) then {
        private _away = _focus getDir _fixPos;
        private _fixApproachIdeal = _fixPos getPos [35,_away];
        _fixApproachIdeal set [2,0];
        _fixHold = ([_fixApproachIdeal,_focus,"HOLD",20,_axis,0,_contactPos] call ARTIC_fnc_findBattleControlPoint) select 0;
        if ((_fixHold distance2D _fixPos) > 55) then {_fixHold = +_fixApproachIdeal;};
    };
    private _fireLine = [_fixPos,_frontage * 0.72] call _lineAround;
    private _assaultLine = [_assaultCentre,_frontage * 0.58] call _lineAround;
    private _fclLine = [_fclCentre,_frontage * 0.48] call _lineAround;
    private _loaCentre = [-25,0] call _point;
    private _loaLine = [_loaCentre,_frontage * 0.58] call _lineAround;
    private _enemyLine = [_focus,(_bfRadius max 70) min _frontage] call _lineAround;
    private _leftBoundary = [[_reserveDepth,-_frontage] call _point,[-20,-_frontage] call _point];
    private _rightBoundary = [[_reserveDepth,_frontage] call _point,[-20,_frontage] call _point];

    _ctx = createHashMapFromArray [
        ["id",format ["CTX_%1_%2_A%3",_nodeId,_bfId,round _axis]],["battlefieldId",_bfId],["objective",+_objective],
        ["focus",+_focus],["axis",_axis],["friendlyCentre",+_friendlyCentre],["radius",_bfRadius],["frontage",_frontage],
        ["releasePoint",_release],["attackPosition",_holdCentre],["holdLine",_holdLine],["probableLineOfDeployment",_pldLine],
        ["fireLine",_fireLine],["assaultLine",_assaultLine],["finalCoordinationLine",_fclLine],["limitOfAdvance",_loaLine],["enemyLine",_enemyLine],
        ["fixHold",_fixHold],["fixPos",_fixPos],["leftCorridor",[_leftHold,_left1,_left2,_leftAssault]],["rightCorridor",[_rightHold,_right1,_right2,_rightAssault]],
        ["reservePos",_reserve],["rallyPos",_rally],["leftBoundary",_leftBoundary],["rightBoundary",_rightBoundary],
        ["phase",toUpper _phase],["created",time],["updated",time],["assessment",_assessment],
        ["shape",_shape],["flankSide",_flankSide],["keypoint",_keypoint],["breakCorridor",_breakCorridor],["breakFollow",_breakFollow],
        ["envelope",_env],["fixSight",_fixSight],["fixValid",_fixValid],["hasEnemyIntel",_hasEnemyIntel],["sectorShiftVec",_shiftVec],
        ["fixFireLineCoverage",_fixLineCoverage],["fixFireLineUsefulPoints",_fixUsefulPoints],
        ["sbfMode",if (_contactFix && {_schemeMode isEqualTo "SUPPORT_MANOEUVRE"}) then {"CONTACT"} else {if (_fixValid) then {"STANDARD"} else {"NONE"}}],["sbfFailureCount",_sbfFailureCount],
        ["contactMode",_contactFix && {_schemeMode isEqualTo "SUPPORT_MANOEUVRE"}],["contactAnchor",_contactAnchor],["committedGroups",_committedInfo apply {_x select 0}],
        ["schemeMode",_schemeMode],["schemeReason",_schemeReason],["geometryOnlyAccepted",_geometryOnlyAccepted],
        ["leftRouteOK",_leftRouteOK],["rightRouteOK",_rightRouteOK],
        ["leftRouteScore",_leftRouteScore],["rightRouteScore",_rightRouteScore],["selectedFlankSide",_flankSide],
        ["battleTargets",+_battleTargets],["battleTracks",+_battleTracks],
        ["baseAxis",_baseAxisForCOA],["axisDelta",abs ((((_axis - _baseAxisForCOA) + 540) % 360) - 180)],
        ["coaScore",_coaData getOrDefault ["score",-1e9]],["coaValid",_coaAccepted],["lastPlanReview",time],
        ["repositionRequired",_coaAccepted && {(abs ((((_axis - _baseAxisForCOA) + 540) % 360) - 180)) >= 35}],["repositionComplete",false]
    ];
    _node set ["battleContext",_ctx];
    [format ["Battle context %1: shape=%2 terrain=%3 sight=%4m fire=%5m hold=%6m, SBF anchor=%7%% fireLine=%8%% mode=%9",
        _ctx get "id",_shape,_env get "terrain",round (_env get "sight"),round _fireDepth,round _holdDepth,
        if (_fixSight < 0) then {-1} else {round (_fixSight * 100)},round ((_ctx getOrDefault ["fixFireLineCoverage",0]) * 100),
        _ctx getOrDefault ["sbfMode","STANDARD"]],_nodeId] call ARTIC_fnc_debug;
    [format ["Battle context %1 terrain-planned from %2 at %3 axis=%4 RELEASE=%5 HOLD=%6 PLD=%7 SBF=%8 ASSAULT=%9 FCL=%10",_ctx get "id",if ((count _battlefield)>0) then {_battlefield getOrDefault ["source","INTEL"]} else {"OBJECTIVE"},mapGridPosition _focus,round _axis,mapGridPosition _release,mapGridPosition _holdCentre,mapGridPosition _pldCentre,mapGridPosition _fixPos,mapGridPosition _assaultCentre,mapGridPosition _fclCentre],_nodeId] call ARTIC_fnc_debug;
};

// Refresh intelligence/assessment without moving established geometry.
if (!_locked) then {_ctx set ["focus",_focusBase vectorAdd (_ctx getOrDefault ["sectorShiftVec",[0,0,0]])];};
// v0.3.24: the enemy positions the planner judged sight against; published to sections so
// the FIX section tests exactly the same set (0.3.23: planner 25 %, FIX 0 % on arrival).
_ctx set ["sightTargets",+_contactPos];
_ctx set ["phase",toUpper _phase];
_ctx set ["updated",time];
// Terrain feasibility remains authoritative between COA reviews; unlike v0.3.17 the
// review itself is periodic and can replace this context with a new axis/SBF solution.
_ctx set ["hasEnemyIntel",_hasEnemyIntel];
_ctx set ["battleTargets",+_battleTargets];
_ctx set ["battleTracks",+_battleTracks];
// v0.3.27: absence of an SBF only vetoes SUPPORT_MANOEUVRE. Envelopment schemes remain
// authorised as long as the battlefield assessment itself still permits an assault.
private _schemeRefresh = _ctx getOrDefault ["schemeMode","HOLD"];
if (!_hasEnemyIntel) then {
    _assessment set ["assaultAllowed",false];
    _assessment set ["plan","PENDING_INTEL"];
} else {
    switch (_schemeRefresh) do {
        case "SUPPORT_MANOEUVRE": {
            if !(_ctx getOrDefault ["fixValid",false]) then {
                _assessment set ["assaultAllowed",false];
                _assessment set ["plan","HOLD_FOR_TACTICAL_OPTION"];
            } else {
                _assessment set ["plan","FIX_LEFT_RIGHT"];
            };
        };
        case "DOUBLE_ENVELOPMENT": {_assessment set ["plan","DOUBLE_ENVELOPMENT"];};
        case "SINGLE_ENVELOPMENT": {_assessment set ["plan","SINGLE_ENVELOPMENT"];};
        default {
            _assessment set ["assaultAllowed",false];
            _assessment set ["plan","HOLD_FOR_TACTICAL_OPTION"];
        };
    };
};
_ctx set ["assessment",_assessment];
_node set ["battleContext",_ctx];

private _ratio = _assessment getOrDefault ["forceRatio",1];
private _plan = _assessment getOrDefault ["plan","FIX_LEFT_RIGHT"];
private _assaultAllowed = _assessment getOrDefault ["assaultAllowed",true];
private _lastSig = _node getOrDefault ["battleAssessmentSig",""];
private _sig = format ["%1/%2/%3/%4",_assessment getOrDefault ["friendlyStrength",0],_assessment getOrDefault ["enemyStrength",0],round (_ratio*100),_plan];
if (_sig isNotEqualTo _lastSig) then {
    [format ["Battle assessment: friendly %1 %2 vs enemy %3 %4 ratio=%5 plan=%6 MG=%7 GL=%8 AT=%9 support=%10 assaultAllowed=%11",
        _assessment getOrDefault ["friendlySize","?"],_assessment getOrDefault ["friendlyStrength",0],
        _assessment getOrDefault ["enemySize","?"],_assessment getOrDefault ["enemyStrength",0],
        (round (_ratio*100))/100,_plan,_assessment getOrDefault ["mg",0],_assessment getOrDefault ["grenadiers",0],
        _assessment getOrDefault ["at",0],_assessment getOrDefault ["linkedSupport",false],_assaultAllowed],_nodeId] call ARTIC_fnc_debug;
    _node set ["battleAssessmentSig",_sig];
};

// v0.3.29 role ownership. A live PlatoonPlan freezes assignments. When no live plan
// exists, v0.3.27 dynamic assignment selects the initial roles and the plan record is
// created after section corridors/deployment positions have been published below.
private _schemeNow = if (_runtimePlanLocked) then {_runtimePlan getOrDefault ["scheme",_ctx getOrDefault ["schemeMode","HOLD"]]} else {_ctx getOrDefault ["schemeMode","HOLD"]};
if (_runtimePlanLocked) then {
    [_node,_groups] call ARTIC_fnc_applyPlatoonPlan;
} else {
    private _lineNow = _groups select {([_x] call ARTIC_fnc_scanGroupCapabilities) getOrDefault ["strength",0] >= 4};
    private _firePower = {
        private _c = [_this] call ARTIC_fnc_scanGroupCapabilities;
        (_c getOrDefault ["strength",0])
            + 3 * count (_c getOrDefault ["mg",[]])
            + 1.5 * count (_c getOrDefault ["grenadier",[]])
            + count (_c getOrDefault ["at",[]])
    };
    private _rankedFire = [_lineNow,[],{_x call _firePower},"DESCEND"] call BIS_fnc_sortBy;
    {_x setVariable ["ARTIC_schemeRole","RESERVE",true]; _x setVariable ["ARTIC_tacticalScheme",_schemeNow,true];} forEach _groups;

    // v0.3.30: in a contact-aware plan the committed anchor section is the FIX element
    // regardless of its firepower rank (it is the section that is already in the fight).
    private _cAnchor = _ctx getOrDefault ["contactAnchor",grpNull];
    if (!isNull _cAnchor && {_schemeNow isEqualTo "SUPPORT_MANOEUVRE"} && {_ctx getOrDefault ["contactMode",false]}) then {
        _rankedFire = [_cAnchor] + (_rankedFire - [_cAnchor]);
    };
    if (_rankedFire isNotEqualTo [] && {_schemeNow in ["SUPPORT_MANOEUVRE","DOUBLE_ENVELOPMENT","SINGLE_ENVELOPMENT"]}) then {
        private _anchorGroup = _rankedFire select 0;
        _anchorGroup setVariable ["ARTIC_schemeRole",["BLOCK","FIX"] select (_schemeNow isEqualTo "SUPPORT_MANOEUVRE"),true];
        private _mobile = _rankedFire - [_anchorGroup];

        private _leftStart = (_ctx getOrDefault ["leftCorridor",[]]) param [0,_ctx getOrDefault ["attackPosition",_objective]];
        private _rightStart = (_ctx getOrDefault ["rightCorridor",[]]) param [0,_ctx getOrDefault ["attackPosition",_objective]];
        private _leftOK = _ctx getOrDefault ["leftRouteOK",true];
        private _rightOK = _ctx getOrDefault ["rightRouteOK",true];

        private _assignNearest = {
            params ["_pool","_dest","_roleName"];
            if (_pool isEqualTo []) exitWith {grpNull};
            private _idx = -1; private _bestD = 1e9;
            {
                private _d = ([_x] call _sectionPos) distance2D _dest;
                if (_d < _bestD) then {_bestD = _d; _idx = _forEachIndex;};
            } forEach _pool;
            if (_idx < 0) exitWith {grpNull};
            private _chosen = _pool select _idx;
            _chosen setVariable ["ARTIC_schemeRole",_roleName,true];
            _chosen
        };

        if (_schemeNow isEqualTo "SINGLE_ENVELOPMENT") then {
            private _sideK = _ctx getOrDefault ["selectedFlankSide",_ctx getOrDefault ["flankSide",0]];
            if (_sideK < 0 && {_leftOK}) then {
                [_mobile,_leftStart,"MANOEUVRE_LEFT"] call _assignNearest;
            } else {
                if (_rightOK) then {
                    [_mobile,_rightStart,"MANOEUVRE_RIGHT"] call _assignNearest;
                } else {
                    if (_leftOK) then {[_mobile,_leftStart,"MANOEUVRE_LEFT"] call _assignNearest;};
                };
            };
        } else {
            if (_leftOK && {_mobile isNotEqualTo []}) then {
                private _lg = [_mobile,_leftStart,"MANOEUVRE_LEFT"] call _assignNearest;
                if (!isNull _lg) then {_mobile = _mobile - [_lg];};
            };
            if (_rightOK && {_mobile isNotEqualTo []}) then {
                private _rg = [_mobile,_rightStart,"MANOEUVRE_RIGHT"] call _assignNearest;
                if (!isNull _rg) then {_mobile = _mobile - [_rg];};
            };
        };
    };
};
// v0.3.30: committed sections (contact-aware plan) deploy where they stand for this plan.
// Decided while no plan is locked; the PlatoonPlan then freezes their position/corridor.
if (!_runtimePlanLocked) then {
    private _committedNow = _ctx getOrDefault ["committedGroups",[]];
    {
        private _isC = _x in _committedNow;
        if (_isC && {!(_x getVariable ["ARTIC_committedInPlace",false])}) then {
            private _cp = [_x] call _sectionPos;
            _cp set [2,0];
            _x setVariable ["ARTIC_committedPos",_cp,true];
        };
        if ((_x getVariable ["ARTIC_committedInPlace",false]) isNotEqualTo _isC) then {_x setVariable ["ARTIC_committedInPlace",_isC,true];};
    } forEach _groups;
};
private _roleSig = (_groups apply {format ["%1=%2",groupId _x,_x getVariable ["ARTIC_schemeRole","RESERVE"]]}) joinString ",";
if (_roleSig isNotEqualTo (_node getOrDefault ["lastTacticalRoleSig",""])) then {
    private _rolePlan = _node getOrDefault ["platoonPlan",createHashMap];
    private _rolePlanId = if ((toUpper (_rolePlan getOrDefault ["status",""])) in ["ACTIVE","DEPLOY","READY_CHECK","EXECUTE","CONSOLIDATE"]) then {
        _rolePlan getOrDefault ["planId","PENDING"]
    } else {"PENDING"};
    [format ["TACTICAL ROLES plan=%1 scheme=%2: %3",_rolePlanId,_schemeNow,_roleSig],_nodeId] call ARTIC_fnc_debug;
    _node set ["lastTacticalRoleSig",_roleSig];
};

private _enemyLine = _ctx get "enemyLine";
private _enemyMid = ((_enemyLine select 0) vectorAdd (_enemyLine select 1)) vectorMultiply 0.5;
private _enemyLeft = _enemyLine select 0;
private _enemyRight = _enemyLine select 1;
{
    private _g = _x;
    private _role = _g getVariable ["ARTIC_schemeRole",""];
    // v0.3.15: the attack shape decides which corridor each role receives
    private _shapeNow = _ctx getOrDefault ["shape","FIX_LEFT_RIGHT"];
    private _flankSideNow = _ctx getOrDefault ["flankSide",0];
    private _isManoeuvre = _role in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT","MANOEUVRE_AUTO"];
    private _corridor = switch (true) do {
        case (_shapeNow isEqualTo "BREAK_IN" && {_role in ["MANOEUVRE_LEFT","MANOEUVRE_AUTO"]} && {(_ctx getOrDefault ["breakCorridor",[]]) isNotEqualTo []}): {+(_ctx get "breakCorridor")};
        case (_shapeNow isEqualTo "BREAK_IN" && {_role isEqualTo "MANOEUVRE_RIGHT"} && {(_ctx getOrDefault ["breakFollow",[]]) isNotEqualTo []}): {+(_ctx get "breakFollow")};
        case (_shapeNow isEqualTo "SINGLE_FLANK" && {_isManoeuvre} && {_flankSideNow isNotEqualTo 0}): {+(_ctx get (["rightCorridor","leftCorridor"] select (_flankSideNow < 0)))};
        case (_role isEqualTo "MANOEUVRE_LEFT"): {+(_ctx get "leftCorridor")};
        case (_role isEqualTo "MANOEUVRE_RIGHT"): {+(_ctx get "rightCorridor")};
        case (_role isEqualTo "FIX"): {[+(_ctx get "fixHold"),+(_ctx get "fixPos")]};
        default {[]};
    };
    private _holdPos = switch (true) do {
        case (_isManoeuvre && {_corridor isNotEqualTo []}): {_corridor select 0};
        case (_role isEqualTo "FIX"): {_ctx get "fixHold"};
        case (_role isEqualTo "BLOCK"): {private _hl = _ctx get "holdLine"; ((_hl select 0) vectorAdd (_hl select 1)) vectorMultiply 0.5};
        case (_role in ["RESERVE","RESERVE_SUPPORT"]): {_ctx get "reservePos"};
        default {private _hl = _ctx get "holdLine"; ((_hl select 0) vectorAdd (_hl select 1)) vectorMultiply 0.5};
    };
    // Deployment is the position that must be occupied before H-hour. A validated FIX
    // section deploys all the way to the SBF anchor before release; manoeuvre and BLOCK
    // elements use their HOLD/attack positions.
    private _deploymentPos = +_holdPos;
    if (_role isEqualTo "FIX" && {_schemeNow isEqualTo "SUPPORT_MANOEUVRE"} && {_ctx getOrDefault ["fixValid",false]}) then {
        _deploymentPos = +(_ctx get "fixPos");
    };
    // v0.3.30: a committed section deploys where it stands; a committed manoeuvre section
    // keeps only the part of its corridor that lies ahead of it (closer to the objective).
    private _committedHere = _g getVariable ["ARTIC_committedInPlace",false];
    if (_committedHere) then {
        private _cp = _g getVariable ["ARTIC_committedPos",[]];
        if (_cp isEqualTo []) then {_cp = [_g] call _sectionPos; _cp set [2,0];};
        _holdPos = +_cp;
        _deploymentPos = +_cp;
        if (_isManoeuvre && {(count _corridor) >= 4}) then {
            private _fc = _ctx get "focus";
            private _dHere = _cp distance2D _fc;
            private _ahead = (_corridor select [1,3]) select {(_x distance2D _fc) < (_dHere - 10)};
            private _trim = [+_cp];
            {_trim pushBack +_x;} forEach _ahead;
            if (_ahead isEqualTo []) then {_trim pushBack +(_corridor select 3);};
            while {(count _trim) < 4} do {_trim insert [1,[+_cp]];};
            _corridor = _trim;
        };
        if (_role isEqualTo "FIX") then {_corridor = [+_cp,+_cp];};
    };
    private _fireSector = switch (_role) do {
        case "MANOEUVRE_LEFT": {[_enemyLeft,_enemyMid]};
        case "MANOEUVRE_RIGHT": {[_enemyMid,_enemyRight]};
        default {[_enemyLeft,_enemyRight]};
    };
    private _fclLineRole = _ctx getOrDefault ["finalCoordinationLine",[]];
    private _fclPos = if ((count _fclLineRole) isEqualTo 2) then {
        switch (_role) do {
            case "MANOEUVRE_LEFT": {+(_fclLineRole select 0)};
            case "MANOEUVRE_RIGHT": {+(_fclLineRole select 1)};
            default {(((_fclLineRole select 0) vectorAdd (_fclLineRole select 1)) vectorMultiply 0.5)};
        }
    } else {[]};

    // Stable per-section approach path. Once a battle context exists, sections no
    // longer share one straight platoon line and then mix together at the HOLD area.
    if (_committedHere) then {
        if ((_g getVariable ["ARTIC_battleRouteKey",""]) isNotEqualTo "COMMITTED") then {
            _g setVariable ["ARTIC_battleApproachRoute",[],true];
            _g setVariable ["ARTIC_battleRouteIndex",0,true];
            _g setVariable ["ARTIC_battleRouteKey","COMMITTED",true];
            [format ["%1 committed in place at %2: no deployment march (contact-aware plan)",_role,mapGridPosition _deploymentPos],groupId _g] call ARTIC_fnc_debug;
        };
    } else {
        private _routeKey = format ["%1|%2|%3|%4|%5",_ctx get "id",_role,_shapeNow,round (_ctx get "axis"),mapGridPosition _deploymentPos];
        private _route = _g getVariable ["ARTIC_battleApproachRoute",[]];
        if ((_g getVariable ["ARTIC_battleRouteKey",""]) isNotEqualTo _routeKey || {_route isEqualTo []}) then {
            _route = [[_g] call _sectionPos,_deploymentPos,_ctx get "focus",_role,_ctx get "axis",_ctx get "frontage",(_ctx getOrDefault ["radius",100]) + 80] call ARTIC_fnc_planSectionRoute;
            _g setVariable ["ARTIC_battleApproachRoute",_route,true];
            _g setVariable ["ARTIC_battleRouteIndex",0,true];
            _g setVariable ["ARTIC_battleRouteKey",_routeKey,true];
            _g setVariable ["ARTIC_routeWatchPos",[_g] call _sectionPos,true];
            _g setVariable ["ARTIC_routeLastMovementAt",time,true];
            [format ["%1 deployment route planned: %2 -> %3 via %4 corridor gate(s)",_role,mapGridPosition ([_g] call _sectionPos),mapGridPosition _deploymentPos,count _route],groupId _g] call ARTIC_fnc_debug;
        };
    };

    _g setVariable ["ARTIC_battleContextId",_ctx get "id",true];
    _g setVariable ["ARTIC_battlefieldId",_bfId,true];
    _g setVariable ["ARTIC_battleObjective",+_objective,true];
    _g setVariable ["ARTIC_battleAxis",_ctx get "axis",true];
    _g setVariable ["ARTIC_battleFocus",+(_ctx get "focus"),true];
    _g setVariable ["ARTIC_battleReleasePoint",+(_ctx get "releasePoint"),true];
    _g setVariable ["ARTIC_battleHoldLine",+(_ctx get "holdLine"),true];
    _g setVariable ["ARTIC_battlePLD",+(_ctx get "probableLineOfDeployment"),true];
    _g setVariable ["ARTIC_battleFireLine",+(_ctx get "fireLine"),true];
    _g setVariable ["ARTIC_battleAssaultLine",+(_ctx get "assaultLine"),true];
    _g setVariable ["ARTIC_battleFCL",+(_ctx get "finalCoordinationLine"),true];
    _g setVariable ["ARTIC_battleLOA",+(_ctx get "limitOfAdvance"),true];
    _g setVariable ["ARTIC_battleHoldPos",+_holdPos,true];
    _g setVariable ["ARTIC_battleDeploymentPos",+_deploymentPos,true];
    _g setVariable ["ARTIC_battleFixPos",+(_ctx get "fixPos"),true];
    _g setVariable ["ARTIC_battleFixValid",_ctx getOrDefault ["fixValid",false],true];
    _g setVariable ["ARTIC_battleFixFireLineCoverage",_ctx getOrDefault ["fixFireLineCoverage",0],true];
    _g setVariable ["ARTIC_battleSbfMode",_ctx getOrDefault ["sbfMode","STANDARD"],true];
    _g setVariable ["ARTIC_battleCorridor",_corridor,true];
    _g setVariable ["ARTIC_battleReservePos",+(_ctx get "reservePos"),true];
    _g setVariable ["ARTIC_battleRallyPos",+(_ctx get "rallyPos"),true];
    _g setVariable ["ARTIC_battleLeftBoundary",+(_ctx get "leftBoundary"),true];
    _g setVariable ["ARTIC_battleRightBoundary",+(_ctx get "rightBoundary"),true];
    _g setVariable ["ARTIC_battleFireSector",_fireSector,true];
    _g setVariable ["ARTIC_battleFCLPos",_fclPos,true];
    _g setVariable ["ARTIC_battlePhase",_ctx get "phase",true];
    _g setVariable ["ARTIC_battlePlan",_plan,true];
    _g setVariable ["ARTIC_battleShape",_shapeNow,true];
    _g setVariable ["ARTIC_tacticalScheme",_schemeNow,true];
    _g setVariable ["ARTIC_battleSightTargets",+(_ctx getOrDefault ["sightTargets",[]]),true];
    _g setVariable ["ARTIC_battleTargets",+(_ctx getOrDefault ["battleTargets",[]]),true];
    _g setVariable ["ARTIC_battleTracks",+(_ctx getOrDefault ["battleTracks",[]]),true];
    _g setVariable ["ARTIC_battleKeypoint",+(_ctx getOrDefault ["keypoint",[]]),true];
    _g setVariable ["ARTIC_battleAssaultAllowed",_assaultAllowed,true];
    _g setVariable ["ARTIC_battleForceRatio",_ratio,true];
} forEach _groups;

// v0.3.29: create one immutable plan only after the initial section roles, corridors and
// deployment positions exist. HOLD/PENDING_INTEL contexts do not create an attack plan.
if (_fsmRuntime && {_assaultAllowed} && {_schemeNow in ["SUPPORT_MANOEUVRE","DOUBLE_ENVELOPMENT","SINGLE_ENVELOPMENT"]}) then {
    private _pNow = _node getOrDefault ["platoonPlan",createHashMap];
    private _pStatus = toUpper (_pNow getOrDefault ["status",""]);
    if !(_pStatus in ["ACTIVE","DEPLOY","READY_CHECK","EXECUTE","CONSOLIDATE"]) then {
        [_node,_ctx,_groups] call ARTIC_fnc_createPlatoonPlan;
    } else {
        [_node,_groups] call ARTIC_fnc_applyPlatoonPlan;
    };
};

_ctx
