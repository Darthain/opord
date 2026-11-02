/*
    ARTIC AI v0.3.30-alpha
    Platoon-coordinated manoeuvre for MANOEUVRE_LEFT / MANOEUVRE_RIGHT sections.

    v0.3.30 lifecycle fixes (0.3.29 benchmark):
      - Every gate decides inside its block and exits at SCRIPT level. In 0.3.29 the FIX gate,
        BLOCK gate and H-hour gate used exitWith inside if/then blocks, which only leaves that
        block: the script reported the failure, ran finishPlan, and then carried on to READY,
        waited for H-hour and moved, while groupStep started a second copy.
      - The play captures its plan/task identity and ends quietly as soon as it is stale
        (ARTIC_fnc_isPlayStale): new task, plan aborted by the platoon, authority withdrawn.
      - In FSM mode the PLATOON owns readiness. The section no longer gives BLOCK 18 s or FIX
        70 s; it waits for its gate / H-hour and the platoon READY_CHECK decides failure from
        lack of deployment progress.
      - Movement legs use the distance-scaled, progress-aware ARTIC_fnc_moveSectionTactical.

    v0.3.27 separates the synchronization gate from the support-by-fire gate:
      SUPPORT_MANOEUVRE  -> manoeuvre waits for an effective FIX element.
      DOUBLE_ENVELOPMENT -> both flanks + BLOCK deploy, then flanks move together.
      SINGLE_ENVELOPMENT -> one flank + BLOCK deploy; no artificial FIX requirement.

    Tactical movement may continue from the persistent battlefield focus even when no
    live target object is currently available. Weapon employment remains a later layer.
*/
params [["_group",grpNull,[grpNull]],["_target",objNull,[objNull]]];
if (isNull _group || {!local _group}) exitWith {false};
if ((_group getVariable ["ARTIC_currentPlan",""]) isNotEqualTo "") exitWith {false};

private _role = _group getVariable ["ARTIC_schemeRole","MANOEUVRE_AUTO"];
if !(_role in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT"]) exitWith {false};

private _schemeMode = _group getVariable ["ARTIC_tacticalScheme","SUPPORT_MANOEUVRE"];
private _requiresFix = _schemeMode isEqualTo "SUPPORT_MANOEUVRE";
private _requiresBlock = _schemeMode in ["DOUBLE_ENVELOPMENT","SINGLE_ENVELOPMENT"];
private _battleFocus = _group getVariable ["ARTIC_battleFocus",[]];
private _hasLiveTarget = [_target] call ARTIC_fnc_isCombatEffectiveTarget;
if (!_hasLiveTarget && {_battleFocus isEqualTo []}) exitWith {false};
private _targetPos = if (_hasLiveTarget) then {getPosATL _target} else {+_battleFocus};

private _markFailure = {
    params ["_reason"];
    _group setVariable ["ARTIC_planFailureReason",_reason,true];
    _group setVariable ["ARTIC_planFailureAt",time,true];
    if (missionNamespace getVariable ["ARTIC_useFSMHierarchy",true]) then {[_group,_reason] call ARTIC_fnc_signalSectionFailure;};
};
private _abort = {
    params ["_reason",["_cooldown",12]];
    [_reason] call _markFailure;
    _group setVariable ["ARTIC_manoeuvrePhase","ABORT",true];
    [_group,_cooldown,_platoonPlanId,_sectionTaskId] call ARTIC_fnc_finishPlan;
    false
};

private _caps = [_group] call ARTIC_fnc_scanGroupCapabilities;
private _movers = (_caps getOrDefault ["alive",[]]) select {alive _x && {local _x}};
if ((count _movers) < 3) exitWith {false};

([_group] call ARTIC_fnc_getProfile) params ["_dName","_tName","_doctrine","_training"];
private _coordination = _training getOrDefault ["coordination",0.55];
private _discipline = _training getOrDefault ["suppressionDiscipline",0.6];
private _threshold = 0.22 + (_discipline * 0.42);
private _formation = _group getVariable ["ARTIC_formationId",""];
private _schemeId = _group getVariable ["ARTIC_schemeId",""];
private _platoonPlanId = _group getVariable ["ARTIC_platoonPlanId",""];
private _sectionTaskId = _group getVariable ["ARTIC_sectionTaskId",""];
private _fsmOwned = (missionNamespace getVariable ["ARTIC_useFSMHierarchy",true]) && {_platoonPlanId isNotEqualTo ""};
if (_platoonPlanId isNotEqualTo "" && {(_group getVariable ["ARTIC_planAbortId",""]) isEqualTo _platoonPlanId}) exitWith {false};

// v0.3.30 play identity: this play belongs to exactly one plan/task.
private _identity = [_platoonPlanId,_sectionTaskId,true];
private _stale = {[_group,_platoonPlanId,_sectionTaskId,true] call ARTIC_fnc_isPlayStale};
private _endStale = {
    // The platoon replaced or aborted this task. End quietly: no failure report.
    _group setVariable ["ARTIC_manoeuvrePhase","ABORT",true];
    if (local _group) then {
        [format ["%1 play ended: plan %2 task %3 is no longer current",_role,_platoonPlanId,_sectionTaskId],groupId _group] call ARTIC_fnc_debug;
        [_group,_platoonPlanId,_sectionTaskId,format ["%1 stale",_role]] call ARTIC_fnc_endPlayQuietly;
    };
    false
};

if (_fsmOwned && {!([_group,_platoonPlanId,_sectionTaskId,"DEPLOYING","MANOEUVRE_START"] call ARTIC_fnc_setSectionTaskState)}) exitWith {false};
_group setVariable ["ARTIC_tacticalGuideActive",true,false];
_group setVariable ["ARTIC_movementPhase","COMBAT",false];
_group setVariable ["ARTIC_currentPlan","PLATOON_MANOEUVRE",true];
private _mAttack = _group getVariable ["ARTIC_metrics",createHashMap];
_mAttack set ["attacksAttempted",(_mAttack getOrDefault ["attacksAttempted",0]) + 1];
_group setVariable ["ARTIC_metrics",_mAttack,false];
_group setVariable ["ARTIC_planOwner",clientOwner,true];
_group setVariable ["ARTIC_manoeuvrePhase","PREPARE",true];
_group enableAttack false;
_group setBehaviourStrong "COMBAT";
_group setCombatMode "RED";

private _siblings = allGroups select {
    _x isNotEqualTo _group
    && {side _x isEqualTo side _group}
    && {(_x getVariable ["ARTIC_formationId",""]) isEqualTo _formation}
    && {(_schemeId isEqualTo "") || {(_x getVariable ["ARTIC_schemeId",""]) isEqualTo _schemeId}}
};
private _fixGroups = _siblings select {(_x getVariable ["ARTIC_schemeRole",""]) isEqualTo "FIX"};
private _blockGroups = _siblings select {(_x getVariable ["ARTIC_schemeRole",""]) isEqualTo "BLOCK"};
private _otherMan = _siblings select {(_x getVariable ["ARTIC_schemeRole",""]) in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT"]};
private _fix = if (_fixGroups isNotEqualTo []) then {_fixGroups select 0} else {grpNull};
private _block = if (_blockGroups isNotEqualTo []) then {_blockGroups select 0} else {grpNull};
private _partner = if (_otherMan isNotEqualTo []) then {_otherMan select 0} else {grpNull};

if (_requiresFix && {isNull _fix}) exitWith {
    [format ["%1 has no platoon FIX sibling for SUPPORT_MANOEUVRE; requesting tactical reassessment",_role],groupId _group] call ARTIC_fnc_debug;
    ["FIX_MISSING",15] call _abort
};
if (_requiresBlock && {isNull _block}) exitWith {
    [format ["%1 has no BLOCK sibling for %2; requesting tactical reassessment",_role,_schemeMode],groupId _group] call ARTIC_fnc_debug;
    ["BLOCK_MISSING",15] call _abort
};

private _flankDistance = _training getOrDefault ["flankDistance",110];
private _flankPlan = if (_hasLiveTarget) then {
    [_group,_target,_flankDistance] call ARTIC_fnc_chooseFlankPlan
} else {
    createHashMapFromArray [
        ["score",0.5],
        ["stage1",getPosATL leader _group],
        ["stage2",getPosATL leader _group],
        ["side",if (_role isEqualTo "MANOEUVRE_LEFT") then {-1} else {1}]
    ]
};
private _flankScore = _flankPlan getOrDefault ["score",0];
private _stage1 = _flankPlan getOrDefault ["stage1",getPosATL leader _group];
private _stage2 = _flankPlan getOrDefault ["stage2",getPosATL leader _group];
private _assaultStageBattle = [];
private _side = _flankPlan getOrDefault ["side",0];

// Persistent battle corridors are authoritative once the platoon has built a COA.
private _battleCorridor = _group getVariable ["ARTIC_battleCorridor",[]];
private _battleFCLPos = _group getVariable ["ARTIC_battleFCLPos",[]];
if ((count _battleCorridor) >= 4) then {
    _stage1 = +(_battleCorridor select 1);
    _stage2 = +(_battleCorridor select 2);
    _assaultStageBattle = +(_battleCorridor select 3);
    _side = if (_role isEqualTo "MANOEUVRE_LEFT") then {-1} else {1};
    // The battlefield planner already safety-checked this corridor. Do not reject it
    // because a local live-target flank scorer was unavailable or pessimistic.
    _flankScore = _flankScore max 0.45;
};

[format ["PLATOON_MANOEUVRE %1 scheme=%2 movers=%3 flank=%4 score=%5 fix=%6 block=%7 partner=%8 battle=%9",
    _role,_schemeMode,count _movers,
    if (_side < 0) then {"LEFT"} else {"RIGHT"},
    (round (_flankScore*100))/100,
    if (isNull _fix) then {"N/A"} else {groupId _fix},
    if (isNull _block) then {"N/A"} else {groupId _block},
    if (isNull _partner) then {"NONE"} else {groupId _partner},
    _group getVariable ["ARTIC_battleContextId","?"]],groupId _group] call ARTIC_fnc_debug;

// ---------------------------------------------------------------------------
// Scheme-specific preconditions. v0.3.30: decide inside, exit at script level.
// ---------------------------------------------------------------------------
private _gateFail = "";
if (_requiresFix) then {
    _group setVariable ["ARTIC_manoeuvrePhase","WAIT_FIX",true];
    private _waitStart = time;
    private _fixReady = false;
    private _maxWait = if (_fsmOwned) then {
        // The platoon READY_CHECK owns the timeout (progress-based); this is only a safety cap.
        (missionNamespace getVariable ["ARTIC_readyCheckMaxSeconds",300]) + 90
    } else {
        missionNamespace getVariable ["ARTIC_fixGateTimeout",70]
    };
    private _progressTimeout = missionNamespace getVariable ["ARTIC_fixProgressTimeout",35];
    waitUntil {
        sleep 0.5;
        if (call _stale) exitWith {true};
        private _st = _fix getVariable ["ARTIC_fixState",""];
        _fixReady = (_fix getVariable ["ARTIC_fixReady",false])
            && {time <= (_fix getVariable ["ARTIC_fixReadyUntil",0])}
            && {(_fix getVariable ["ARTIC_suppressionEstimate",0]) >= _threshold};
        _fixReady
            || {_st isEqualTo "FAILED"}
            || {(time - _waitStart) > _maxWait}
            || {!_fsmOwned && {(time - (_fix getVariable ["ARTIC_fixProgressAt",_waitStart])) > _progressTimeout} && {(time - _waitStart) > 25}}
    };
    switch (true) do {
        case (call _stale): {_gateFail = "STALE";};
        case (_fixReady): {};
        // FIX reports its own failure to the platoon; do not add a second reason in FSM mode.
        case (_fsmOwned && {(_fix getVariable ["ARTIC_fixState",""]) isEqualTo "FAILED"}): {_gateFail = "STALE";};
        default {
            [format ["%1 support gate failed: FIX did not establish effect threshold %2; requesting alternate tactic",
                _role,(round (_threshold*100))/100],groupId _group] call ARTIC_fnc_debug;
            _gateFail = "FIX_SUPPRESSION_TIMEOUT";
        };
    };
};
// Envelopment: in FSM mode the platoon H-hour already requires BLOCK READY, so the section
// does not run its own BLOCK clock. Without the FSM the v0.3.27 gate is kept, but it waits
// while the BLOCK element is visibly progressing (ARTIC_blockProgressAt).
if (_gateFail isEqualTo "" && {_requiresBlock} && {!_fsmOwned}) then {
    private _blockStart = time;
    private _blockDeadline = time + 18;
    waitUntil {
        sleep 0.5;
        if (call _stale) exitWith {true};
        if ((time - (_block getVariable ["ARTIC_blockProgressAt",-1e6])) < 20
            && {(_block getVariable ["ARTIC_blockState",""]) in ["DEPLOY","OCCUPY"]}) then {
            _blockDeadline = (_blockDeadline max (time + 6)) min (_blockStart + 150);
        };
        (_block getVariable ["ARTIC_blockReady",false]) || {time > _blockDeadline} || {(_block getVariable ["ARTIC_blockState",""]) isEqualTo "FAILED"}
    };
    if (call _stale) then {
        _gateFail = "STALE";
    } else {
        if !(_block getVariable ["ARTIC_blockReady",false]) then {
            [format ["%1 %2 gate failed: BLOCK element not ready",_role,_schemeMode],groupId _group] call ARTIC_fnc_debug;
            _gateFail = "BLOCK_NOT_READY";
        };
    };
};
if (_gateFail isEqualTo "STALE") exitWith {call _endStale};
if (_gateFail isNotEqualTo "") exitWith {[_gateFail,12] call _abort};
if (_requiresFix) then {_group setVariable ["ARTIC_manoeuvrePhase","FIX_RESOLVED",true];};

if !(_group getVariable ["ARTIC_battleAssaultAllowed",true]) exitWith {
    [format ["%1 holding: battle assessment no longer authorises assault (ratio=%2 plan=%3)",
        _role,(round ((_group getVariable ["ARTIC_battleForceRatio",0])*100))/100,
        _group getVariable ["ARTIC_battlePlan","?"]],groupId _group] call ARTIC_fnc_debug;
    ["PLAN_NOT_AUTHORIZED",18] call _abort
};

if (_flankScore < 0.25 && {_battleCorridor isEqualTo []}) exitWith {
    [format ["%1 aborting: local flank score %2 is too exposed and no planned corridor exists",
        _role,(round (_flankScore*100))/100],groupId _group] call ARTIC_fnc_debug;
    ["MANOEUVRE_ROUTE_EXPOSED",12] call _abort
};

// Partner synchronization. A SINGLE_ENVELOPMENT legitimately has no partner and passes.
// v0.3.30: returns false at once when this play is stale; callers check _stale first.
private _waitPartner = {
    params ["_phase","_seconds"];
    if (isNull _partner) exitWith {true};
    private _deadline = time + _seconds;
    waitUntil {
        sleep 0.5;
        (call _stale) || {time > _deadline} || {
            private _p = _partner getVariable ["ARTIC_manoeuvrePhase",""];
            _p isEqualTo "ABORT" || {_p in [_phase,"STAGE1","STAGE2","ASSAULT_READY","ASSAULT","COMPLETE"]}
        }
    };
    if (call _stale) exitWith {false};
    private _p = _partner getVariable ["ARTIC_manoeuvrePhase",""];
    !(_p isEqualTo "ABORT") && {_p in [_phase,"STAGE1","STAGE2","ASSAULT_READY","ASSAULT","COMPLETE"]}
};

_group setVariable ["ARTIC_manoeuvrePhase","READY",true];
[format ["%1 READY scheme=%2 block=%3 fix=%4 plan=%5 task=%6; awaiting PLATOON H-hour",
    _role,_schemeMode,
    if (isNull _block) then {"N/A"} else {_block getVariable ["ARTIC_blockReady",false]},
    if (isNull _fix) then {"N/A"} else {_fix getVariable ["ARTIC_fixReady",false]},
    _platoonPlanId,_sectionTaskId],groupId _group] call ARTIC_fnc_debug;

private _syncFail = "";
if (_fsmOwned) then {
    [_group,"READY"] call ARTIC_fnc_signalSectionReady;
    // The platoon READY_CHECK decides when readiness has failed; this is only a safety cap.
    private _hDeadline = time + (missionNamespace getVariable ["ARTIC_hHourReadyTimeout",390]);
    waitUntil {
        sleep 0.25;
        (call _stale)
        || {(_group getVariable ["ARTIC_hHourPlanId",""]) isEqualTo _platoonPlanId}
        || {time > _hDeadline}
    };
    if (call _stale) then {
        _syncFail = "STALE";
    } else {
        if ((_group getVariable ["ARTIC_hHourPlanId",""]) isNotEqualTo _platoonPlanId) then {
            [format ["%1 held: platoon H-hour was not issued for plan=%2",_role,_platoonPlanId],groupId _group] call ARTIC_fnc_debug;
            _syncFail = "MANOEUVRE_SYNC_FAILED";
        };
    };
} else {
    if !(["READY",22] call _waitPartner) then {
        if (call _stale) then {_syncFail = "STALE";} else {
            [format ["%1 held: partner failed READY gate",_role],groupId _group] call ARTIC_fnc_debug;
            _syncFail = "MANOEUVRE_SYNC_FAILED";
        };
    };
};
if (_syncFail isEqualTo "STALE") exitWith {call _endStale};
if (_syncFail isNotEqualTo "") exitWith {[_syncFail,10] call _abort};

private _hHourDuplicate = false;
private _hHourStateOK = true;
if (_fsmOwned) then {
    _hHourDuplicate = (_group getVariable ["ARTIC_hHourConsumedPlanId",""]) isEqualTo _platoonPlanId
        && {(_group getVariable ["ARTIC_hHourConsumedTaskId",""]) isEqualTo _sectionTaskId};
    if (!_hHourDuplicate) then {
        _hHourStateOK = [_group,_platoonPlanId,_sectionTaskId,"EXECUTING","H_HOUR"] call ARTIC_fnc_setSectionTaskState;
        if (_hHourStateOK) then {
            _group setVariable ["ARTIC_hHourConsumedPlanId",_platoonPlanId,true];
            _group setVariable ["ARTIC_hHourConsumedTaskId",_sectionTaskId,true];
        };
    };
};
if (_hHourDuplicate) exitWith {
    [format ["H-HOUR DUPLICATE IGNORED plan=%1 task=%2 role=%3",_platoonPlanId,_sectionTaskId,_role],groupId _group] call ARTIC_fnc_debug;
    false
};
if (!_hHourStateOK) exitWith {
    if (call _stale) then {call _endStale} else {false}
};

[format ["%1 H-HOUR RECEIVED plan=%2 task=%3; moving Stage 1",_role,_platoonPlanId,_sectionTaskId],groupId _group] call ARTIC_fnc_debug;
private _ok = [_group,_stage1,_target,75,16,format ["%1 STAGE1",_role],_identity] call ARTIC_fnc_moveSectionTactical;
if (call _stale) exitWith {call _endStale};
if (!_ok) exitWith {
    [format ["%1 failed Stage 1; requesting tactical reassessment",_role],groupId _group] call ARTIC_fnc_debug;
    ["MANOEUVRE_ROUTE_FAILED",10] call _abort
};
_group setVariable ["ARTIC_manoeuvrePhase","STAGE1",true];
private _pOK = ["STAGE1",55] call _waitPartner;
if (call _stale) exitWith {call _endStale};
if (!_pOK) exitWith {
    [format ["%1 holding at Stage 1: partner failed phase gate",_role],groupId _group] call ARTIC_fnc_debug;
    ["MANOEUVRE_SYNC_FAILED",10] call _abort
};

[format ["%1 STAGE1 synchronized; moving Stage 2",_role],groupId _group] call ARTIC_fnc_debug;
_ok = [_group,_stage2,_target,80,14,format ["%1 STAGE2",_role],_identity] call ARTIC_fnc_moveSectionTactical;
if (call _stale) exitWith {call _endStale};
if (!_ok) exitWith {
    [format ["%1 failed Stage 2; requesting tactical reassessment",_role],groupId _group] call ARTIC_fnc_debug;
    ["MANOEUVRE_ROUTE_FAILED",10] call _abort
};
_group setVariable ["ARTIC_manoeuvrePhase","STAGE2",true];
_pOK = ["STAGE2",60] call _waitPartner;
if (call _stale) exitWith {call _endStale};
if (!_pOK) exitWith {
    [format ["%1 holding at Stage 2: partner failed phase gate",_role],groupId _group] call ARTIC_fnc_debug;
    ["MANOEUVRE_SYNC_FAILED",10] call _abort
};

private _assaultBearing = _targetPos getDir _stage2;
private _assaultStage = if (_assaultStageBattle isNotEqualTo []) then {+_assaultStageBattle} else {_targetPos getPos [55,_assaultBearing]};
_assaultStage = [_assaultStage,_target,15,true] call ARTIC_fnc_findCoverPosition;
_ok = [_group,_assaultStage,_target,65,12,format ["%1 ASSAULT_LINE",_role],_identity] call ARTIC_fnc_moveSectionTactical;
if (call _stale) exitWith {call _endStale};
if (!_ok) exitWith {
    [format ["%1 failed assault-line occupation; requesting tactical reassessment",_role],groupId _group] call ARTIC_fnc_debug;
    ["MANOEUVRE_ROUTE_FAILED",10] call _abort
};

_group setVariable ["ARTIC_manoeuvrePhase","ASSAULT_READY",true];
_pOK = ["ASSAULT_READY",50] call _waitPartner;
if (call _stale) exitWith {call _endStale};
if (!_pOK) exitWith {
    [format ["%1 holding on assault line: partner not ready",_role],groupId _group] call ARTIC_fnc_debug;
    ["MANOEUVRE_SYNC_FAILED",10] call _abort
};

[format ["%1 ASSAULT_READY synchronized; closing to final coordination line",_role],groupId _group] call ARTIC_fnc_debug;
private _fclOK = true;
if (_battleFCLPos isNotEqualTo []) then {
    _group setVariable ["ARTIC_tacticalFormationOverride","LINE",false];
    _fclOK = [_group,_battleFCLPos,_target,45,11,format ["%1 FCL",_role],_identity] call ARTIC_fnc_moveSectionTactical;
};
if (call _stale) exitWith {call _endStale};
if (!_fclOK) exitWith {
    [format ["%1 failed final coordination line occupation",_role],groupId _group] call ARTIC_fnc_debug;
    ["MANOEUVRE_ROUTE_FAILED",10] call _abort
};

[format ["%1 final coordination complete; assaulting with synchronized scheme=%2",_role,_schemeMode],groupId _group] call ARTIC_fnc_debug;
_group setVariable ["ARTIC_manoeuvrePhase","ASSAULT",true];
private _assaultAnchor = _targetPos getPos [18,_assaultBearing];
private _assaultFacing = _assaultAnchor getDir _targetPos;
_group setVariable ["ARTIC_formationFacingDir",_assaultFacing,true];
private _assaultOK = [_group,_assaultAnchor,_target,45,12,format ["%1 ASSAULT",_role],_identity] call ARTIC_fnc_moveSectionTactical;
if (call _stale) exitWith {call _endStale};
if (!_assaultOK) exitWith {
    [format ["%1 assault guide failed to consolidate",_role],groupId _group] call ARTIC_fnc_debug;
    ["MANOEUVRE_ROUTE_FAILED",10] call _abort
};

private _assaultEnd = time + 16;
{
    if ([_x] call ARTIC_fnc_isFit && {local _x}) then {
        [_x,"FORMATION",[],_target,20,8] call ARTIC_fnc_setUnitTask;
    };
} forEach _movers;
waitUntil {sleep 0.5; (call _stale) || {time > _assaultEnd}};
if (call _stale) exitWith {call _endStale};

_group setVariable ["ARTIC_manoeuvrePhase","COMPLETE",true];
_group setVariable ["ARTIC_planFailureReason","",true];
_group setVariable ["ARTIC_planFailureAt",-1e6,true];
[format ["%1 assault phase complete; consolidating",_role],groupId _group] call ARTIC_fnc_debug;
[_group,8,_platoonPlanId,_sectionTaskId] call ARTIC_fnc_finishPlan;
true
