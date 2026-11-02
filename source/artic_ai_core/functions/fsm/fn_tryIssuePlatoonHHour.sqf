/*
    Server: update ready mask and issue exactly one H-hour for the active plan.

    v0.3.30: the PLATOON decides when readiness has failed. While any required section that is
    not yet ready keeps making deployment progress (closer to its plan deployment point, or a
    change of its FIX / BLOCK / manoeuvre phase), READY_CHECK keeps waiting. It records a TIMING
    failure (BLOCK_NOT_READY / FIX_NOT_READY / MANOEUVRE_NOT_READY) or FIX_SUPPRESSION_TIMEOUT
    only after ARTIC_readyNoProgressTimeout (45 s) without progress (and at least
    ARTIC_readyMinSeconds, 60 s, in READY_CHECK), or after ARTIC_readyCheckMaxSeconds (300 s).
    0.3.29 let each manoeuvre section give BLOCK 18 s and FIX 70 s; four of six plans died that
    way while BLOCK was still walking to a newly planned position.

    v0.3.30.2: progress also counts ARTIC_deployProgressSeq (ARTIC_fnc_markDeployProgress), so a
    FIX/BLOCK occupying its fire line is not timed out as "no progress" before it can report its
    own verdict (0.3.30.1: BLOCK_NOT_READY [TIMING] issued 6 s before BLOCK would have reported
    BLOCK_NO_LOS [TACTICAL], which then forced a same-scheme retry).
*/
params [["_logic",objNull,[objNull]]];
if (!isServer || {isNull _logic}) exitWith {false};
private _cid = _logic getVariable ["ARTIC_runtimeCommanderId",""];
private _nid = _logic getVariable ["ARTIC_runtimeFormationId",_logic getVariable ["FormationId",""]];
private _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
if ((count _node) isEqualTo 0) exitWith {false};
private _plan = _node getOrDefault ["platoonPlan",createHashMap];
if ((count _plan) isEqualTo 0) exitWith {false};
private _status = toUpper (_plan getOrDefault ["status",""]);
if !(_status in ["ACTIVE","DEPLOY","READY_CHECK"]) exitWith {_plan getOrDefault ["hHourIssued",false]};
private _planId = _plan getOrDefault ["planId",""];
if (_planId isEqualTo "") exitWith {false};
if (_plan getOrDefault ["hHourIssued",false]) exitWith {true};

private _groups = (_node getOrDefault ["groups",[]]) select {!isNull _x && {({alive _x} count units _x) > 0}};
private _required = _plan getOrDefault ["requiredReady",[]];
private _liveIds = _groups apply {groupId _x};
private _missingRequired = _required select {!(_x in _liveIds)};
if (_missingRequired isNotEqualTo []) exitWith {
    private _gid = _missingRequired select 0;
    private _tasks = _plan getOrDefault ["sectionTasks",createHashMap];
    private _roles = _plan getOrDefault ["sectionRoles",createHashMap];
    [format ["FSM READY_CHECK plan=%1 required section %2 is no longer combat effective",_planId,_gid],_nid] call ARTIC_fnc_debug;
    [_node,_gid,_tasks getOrDefault [_gid,""],_roles getOrDefault [_gid,""],"SECTION_COMBAT_INEFFECTIVE"] call ARTIC_fnc_recordPlatoonFailure;
    false
};
private _ready = [];
{
    private _g = _x;
    private _gid = groupId _g;
    if (_gid in _required) then {
        private _role = _g getVariable ["ARTIC_schemeRole",""];
        private _taskState = toUpper (_g getVariable ["ARTIC_sectionTaskState","ASSIGNED"]);
        private _terminal = _taskState in ["FAILED","ABORTED","COMPLETE"];
        private _ok = !_terminal && {
            switch (_role) do {
                case "FIX": {_g getVariable ["ARTIC_fixReady",false] && {time <= (_g getVariable ["ARTIC_fixReadyUntil",time + 1])}};
                case "BLOCK": {_g getVariable ["ARTIC_blockReady",false]};
                default {(_g getVariable ["ARTIC_sectionReadyPlanId",""]) isEqualTo _planId};
            }
        };
        if (_ok) then {_ready pushBackUnique _gid;};
    };
} forEach _groups;
_plan set ["readySet",_ready];
_plan set ["phase","READY_CHECK"];
_plan set ["status","READY_CHECK"];
_node set ["platoonPlan",_plan];
_logic setVariable ["ARTIC_platoonReadyCount",count _ready,true];
_logic setVariable ["ARTIC_platoonRequiredReadyCount",count _required,true];

if (_required isEqualTo []) exitWith {
    if !(_plan getOrDefault ["readyTimeoutIssued",false]) then {
        _plan set ["readyTimeoutIssued",true];
        _node set ["platoonPlan",_plan];
        [format ["FSM READY_CHECK invalid plan=%1: no required tactical elements",_planId],_nid] call ARTIC_fnc_debug;
        [_node,"","","","PLAN_NO_REQUIRED_ELEMENTS"] call ARTIC_fnc_recordPlatoonFailure;
    };
    false
};
private _allReady = (count _ready) isEqualTo (count _required);
if (!_allReady) exitWith {
    // ---- v0.3.30 progress-based readiness timeout ---------------------------------------
    if (_plan getOrDefault ["readyTimeoutIssued",false]) exitWith {false};
    if ((_plan getOrDefault ["readyCheckStart",-1]) < 0) then {
        _plan set ["readyCheckStart",time];
        _plan set ["readyProgressAt",time];
    };
    private _best = _plan getOrDefault ["readyBest",createHashMap];
    private _sigs = _plan getOrDefault ["readySig",createHashMap];
    private _deploy = _plan getOrDefault ["sectionDeployment",createHashMap];
    private _progressed = false;
    private _notReady = [];
    {
        private _g = _x;
        private _gid = groupId _g;
        if (_gid in _required && {!(_gid in _ready)}) then {
            _notReady pushBack _g;
            // v0.3.30.2: ARTIC_deployProgressSeq makes occupation progress visible (soldiers reaching
            // firing points, a BLOCK/FIX line moving to observation) while phase and distance are flat.
            private _sig = format ["%1|%2|%3|%4",_g getVariable ["ARTIC_fixState",""],_g getVariable ["ARTIC_blockState",""],_g getVariable ["ARTIC_manoeuvrePhase",""],_g getVariable ["ARTIC_deployProgressSeq",0]];
            if ((_sigs getOrDefault [_gid,""]) isNotEqualTo _sig) then {_sigs set [_gid,_sig]; _progressed = true;};
            private _dp = _deploy getOrDefault [_gid,[]];
            if (_dp isNotEqualTo []) then {
                private _ref = _g getVariable ["ARTIC_sectionReferencePos",getPosATL leader _g];
                private _d = _ref distance2D _dp;
                if (_d < ((_best getOrDefault [_gid,1e9]) - 5)) then {_best set [_gid,_d]; _progressed = true;};
            };
        };
    } forEach _groups;
    _plan set ["readyBest",_best];
    _plan set ["readySig",_sigs];
    if (_progressed) then {_plan set ["readyProgressAt",time];};
    private _age = time - (_plan get "readyCheckStart");
    private _idle = time - (_plan get "readyProgressAt");
    private _timedOut = (_age > (missionNamespace getVariable ["ARTIC_readyMinSeconds",60]) && {_idle > (missionNamespace getVariable ["ARTIC_readyNoProgressTimeout",45])})
        || {_age > (missionNamespace getVariable ["ARTIC_readyCheckMaxSeconds",300])};
    _node set ["platoonPlan",_plan];
    if (!_timedOut || {_notReady isEqualTo []}) exitWith {false};

    // the element holding the platoon up: BLOCK / FIX first, then manoeuvre sections
    private _rank = {switch (_this getVariable ["ARTIC_schemeRole",""]) do {case "BLOCK": {0}; case "FIX": {1}; default {2};}};
    private _culprit = ([_notReady,[],{_x call _rank},"ASCEND"] call BIS_fnc_sortBy) select 0;
    private _cRole = _culprit getVariable ["ARTIC_schemeRole",""];
    private _fixG = _groups select {(_x getVariable ["ARTIC_schemeRole",""]) isEqualTo "FIX"};
    private _fixFiring = _fixG isNotEqualTo [] && {((_fixG select 0) getVariable ["ARTIC_fixState",""]) isEqualTo "SUPPRESS"};
    private _reason = switch (true) do {
        case (_cRole isEqualTo "BLOCK"): {"BLOCK_NOT_READY"};
        case (_cRole isEqualTo "FIX"): {"FIX_NOT_READY"};
        case ((_culprit getVariable ["ARTIC_manoeuvrePhase",""]) isEqualTo "WAIT_FIX" && {_fixFiring}): {"FIX_SUPPRESSION_TIMEOUT"};
        default {"MANOEUVRE_NOT_READY"};
    };
    _plan set ["readyTimeoutIssued",true];
    _node set ["platoonPlan",_plan];
    [format ["FSM READY_CHECK timeout plan=%1 ready=%2/%3 waited=%4s noProgress=%5s holding=%6 (%7) -> %8",
        _planId,count _ready,count _required,round _age,round _idle,groupId _culprit,_cRole,_reason],_nid] call ARTIC_fnc_debug;
    [_node,groupId _culprit,_culprit getVariable ["ARTIC_sectionTaskId",""],_cRole,_reason] call ARTIC_fnc_recordPlatoonFailure;
    false
};
_plan set ["hHourIssued",true];
_plan set ["hHourAt",time];
_plan set ["phase","EXECUTE"];
_plan set ["status","EXECUTE"];
_node set ["platoonPlan",_plan];
// v0.3.30: a plan that reached H-hour resets the timing-retry budget
_node set ["timingRetries",createHashMap];
_logic setVariable ["ARTIC_hHourPlanId",_planId,true];
{
    _x setVariable ["ARTIC_hHourPlanId",_planId,true];
} forEach _groups;
["ARTIC_hHour",[_cid,_nid,_planId,+_ready,time]] call CBA_fnc_localEvent;
[format ["FSM H-HOUR plan=%1 READY %2/%3; platoon execution released",_planId,count _ready,count _required],_nid] call ARTIC_fnc_debug;
true
