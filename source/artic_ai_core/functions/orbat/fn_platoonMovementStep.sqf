/*
    ARTIC - platoon movement controller (v0.3.27). Server, every commander tick (~5 s).

    A formation node with 2+ sections moving to an objective moves as ONE platoon instead of
    each section walking there on its own:

    - Platoon formation (Battle Book, Part 3 ch.2):
        OPEN  : WEDGE, ~70 m between sections (Battle Book 50-100 m)
        CLOSE : FILE,  ~22 m between sections (Battle Book 5-25 m), also used at night
      The scheme of manoeuvre places sections where they will fight from: FIX leads in the
      centre, MANOEUVRE_LEFT / MANOEUVRE_RIGHT on the left / right, reserves trail. On
      contact each section is already on its own axis.
    - Pace: platoon progress = the SLOWEST section's progress along the axis. Every section
      aims a look-ahead distance beyond that, so the platoon moves as a body; a section that
      gets ahead is set to LIMITED speed rather than halted.
    - Movement technique follows ATP 3-21.8 terminology but is tuned for Arma:
        TRAVELLING            contact not likely; continuous movement.
        TRAVELLING_OVERWATCH  contact possible / battlefield known; continuous, slower,
                              better section control.
      Pre-contact BOUNDING_OVERWATCH is intentionally deferred until the fireteam guide
      layer is stable; direct contact hands control to the tactical scheme.
    - Contact: as soon as any section is in contact, or a play is running, the controller
      releases the platoon (for 60 s) and the scheme of manoeuvre takes over.
    - Arrival: sections are given final slots around the objective (ARTIC_platoonFinalSlot)
      so they don't all converge on the same point.

    Published per group (public, only when it changes):
      ARTIC_platoonMove = [slotPos, speedMode, technique, CBA_missionTime, sectionFormation]
    Disable with ARTIC_platoonMovement = false.
*/
params [["_node",createHashMap,[createHashMap]],["_commander",createHashMap,[createHashMap]]];
if (!isServer || {(count _node) isEqualTo 0}) exitWith {};

{[_x,_commander] call ARTIC_fnc_platoonMovementStep;} forEach (_node getOrDefault ["children",[]]);

private _groups = (_node getOrDefault ["groups",[]]) select {
    !isNull _x && {(_x getVariable ["ARTIC_enabled",false])} && {({alive _x} count units _x) > 0} && {!isPlayer leader _x}
};
private _nodeId = _node getOrDefault ["id","FORMATION"];
private _release = {
    {
        if ((_x getVariable ["ARTIC_platoonMove",[]]) isNotEqualTo []) then {_x setVariable ["ARTIC_platoonMove",[],true];};
        _x setVariable ["ARTIC_repositionForAttack",false,true];
    } forEach _groups;
};

// v0.3.15: DEFEND orders get a defensive battle context (also for single sections).
if ((_node getOrDefault ["intent",""]) isEqualTo "DEFEND" && {(_node getOrDefault ["intentPos",[]]) isNotEqualTo []} && {_groups isNotEqualTo []}) then {
    [_node,_commander,_groups,_node get "intentPos"] call ARTIC_fnc_buildDefenceContext;
};

if ((count _groups) < 2 || {!(missionNamespace getVariable ["ARTIC_platoonMovement",true])}) exitWith {call _release};
private _intent = _node getOrDefault ["intent",""];
private _obj = _node getOrDefault ["intentPos",[]];
if (_obj isEqualTo [] || {!(_intent in ["SEIZE","ATTACK","CAPTURE","RAID","DEFEND","RECON","SCREEN","DELAY"])}) exitWith {call _release};

/*
    v0.3.21 tactical release gate.  Strategic SEIZE purpose does not create dormant
    section ATTACK orders.  Only this platoon controller may arm executable section
    tasks, and only when the selected COA is deliberately released.
*/
private _armTacticalExecution = {
    if !(_intent in ["SEIZE","ATTACK","CAPTURE","RAID"]) exitWith {};
    private _cmdId = _commander getOrDefault ["id",""];
    private _execRadius = _node getOrDefault ["intentRadius",150];
    private _armedAny = false;
    {
        private _g = _x;
        if !(_g getVariable ["ARTIC_tacticalExecutionArmed",false]) then {
            private _role = _g getVariable ["ARTIC_schemeRole","MANOEUVRE_AUTO"];
            private _exec = switch (_role) do {
                case "FIX": {"FIX"};
                case "BLOCK": {"BLOCK"};
                case "RESERVE": {"RESERVE"};
                case "RESERVE_SUPPORT": {"RESERVE"};
                default {"ATTACK"};
            };
            if (_g getVariable ["ARTIC_forcedReserve",false]) then {_exec = "RESERVE";};

            // v0.3.24: a hasty attack executes against the reported contact
            private _execObj = _node getOrDefault ["hastyFocus",[]];
            if (_execObj isEqualTo []) then {_execObj = _obj;};
            [_g,_exec,_execObj,_execRadius,_cmdId,[]] call ARTIC_fnc_setGroupOrder;
            _g setVariable ["ARTIC_tacticalExecutionArmed",true,true];
            _g setVariable ["ARTIC_planFailureReason","",true];
            _g setVariable ["ARTIC_planFailureAt",-1e6,true];
            if (local _g) then {
                _g enableAttack false;
                _g setVariable ["ARTIC_autoAttackDisabledByARTIC",true,false];
            };
            _armedAny = true;
        };
    } forEach _groups;
    if (_armedAny) then {
        _node set ["executionStart",time];         // v0.3.24: plan lock / contact response
        [format ["Platoon %1: tactical execution armed from strategic %2",_nodeId,_intent],_nodeId] call ARTIC_fnc_debug;
    };
};

// Use the section guide/anchor as the section's physical reference. The actual
// section leader is a protected slot inside the formation and may legitimately
// trail the guide; he must not distort platoon progress calculations.
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

// ATTACK/CAPTURE/RAID formations prepare against a persistent battlefield. A UAS
// contact cluster can therefore alter the approach before direct contact occurs.
// v0.3.24: section contact calls -> platoon response (share, shift fire, assist, hasty attack)
[_node,_commander,_groups,_intent,_obj] call ARTIC_fnc_platoonContactResponse;

private _battleCtx = createHashMap;
if (_intent in ["SEIZE","ATTACK","CAPTURE","RAID"]) then {
    // v0.3.24: during a hasty attack the battle is centred on the reported contact
    private _hastyFocus = _node getOrDefault ["hastyFocus",[]];
    private _battleObj = if (_hastyFocus isNotEqualTo []) then {+_hastyFocus} else {_obj};
    _battleCtx = [_node,_commander,_groups,_battleObj,"APPROACH"] call ARTIC_fnc_buildBattleContext;
};
private _marchObj = +_obj;
private _repositioning = false;
if ((count _battleCtx) > 0) then {
    _repositioning = (_battleCtx getOrDefault ["repositionRequired",false]) && {!(_battleCtx getOrDefault ["repositionComplete",false])};
    if (_repositioning) then {
        _marchObj = +(_battleCtx getOrDefault ["releasePoint",_obj]);
    } else {
        private _hl = _battleCtx getOrDefault ["holdLine",[]];
        if ((count _hl) isEqualTo 2) then {_marchObj = ((_hl select 0) vectorAdd (_hl select 1)) vectorMultiply 0.5;};
    };
};
// v0.3.30 contact-aware plan: sections committed in place fight from where they are. They
// are armed as soon as the plan is active and are never given a platoon march slot, so a
// replan cannot walk an engaged section back out through the enemy in a platoon column.
private _committed = _groups select {_x getVariable ["ARTIC_committedInPlace",false]};
if (_committed isNotEqualTo []) then {
    private _pPlan = _node getOrDefault ["platoonPlan",createHashMap];
    private _pActive = (toUpper (_pPlan getOrDefault ["status",""])) in ["ACTIVE","DEPLOY","READY_CHECK","EXECUTE","CONSOLIDATE"];
    if (_pActive) then {
        private _groupsAll = _groups;
        _groups = _committed;
        call _armTacticalExecution;
        _groups = _groupsAll;
    };
    {
        if ((_x getVariable ["ARTIC_platoonMove",[]]) isNotEqualTo []) then {_x setVariable ["ARTIC_platoonMove",[],true];};
        if !(_x getVariable ["ARTIC_platoonTacticalReleased",false]) then {_x setVariable ["ARTIC_platoonTacticalReleased",true,true];};
    } forEach _committed;
};

// Publish the phase explicitly so local guide/individual executors can use a
// reposition-specific pacing policy without inferring it from formation names.
{
    _x setVariable ["ARTIC_repositionForAttack",_repositioning,true];
    _x setVariable ["ARTIC_platoonPhase",if (_repositioning) then {"REPOSITION"} else {if ((count _battleCtx) > 0) then {"DEPLOY"} else {"TRANSIT"}},true];
} forEach _groups;

// v0.3.16 contact handover gate. A single section seeing the enemy at long range no
// longer destroys the whole platoon's approach plan. Continue section routes until the
// HOLD/release area is physically occupied, unless contact is genuinely close/immediate.
private _contact = ({_x getVariable ["ARTIC_inContact",false]} count _groups) > 0;
private _playing = ({(_x getVariable ["ARTIC_currentPlan",""]) isNotEqualTo ""} count _groups) > 0;
private _march = _node getOrDefault ["march",createHashMap];
private _nearestThreat = 1e6;
{
    _x params ["_o","_p","_t"];
    if ([_o] call ARTIC_fnc_isCombatEffectiveTarget && {(time - _t) < 120}) then {
        {_nearestThreat = _nearestThreat min (([_x] call _sectionPos) distance2D _p);} forEach _groups;
    };
} forEach (_commander getOrDefault ["contactReports",[]]);
{
    if (_x getVariable ["ARTIC_inContact",false]) then {
        private _tg = [_x] call ARTIC_fnc_findTarget;
        if ([_tg] call ARTIC_fnc_isCombatEffectiveTarget) then {
            _nearestThreat = _nearestThreat min (([_x] call _sectionPos) distance2D (getPosATL _tg));
        };
    };
} forEach _groups;
private _nearHold = true;
if ((count _battleCtx) > 0) then {
    {
        private _hp = _x getVariable ["ARTIC_battleDeploymentPos",_x getVariable ["ARTIC_battleHoldPos",[]]];
        if (_hp isEqualTo [] || {(([_x] call _sectionPos) distance2D _hp) > 70}) then {_nearHold = false;};
    } forEach _groups;
};
private _emergencyContact = _contact && {_nearestThreat < 160};
// v0.3.25: sections reacting to effective contact halt the platoon (see the publish loop).
// The halt ends in a release when the platoon has decided on a HASTY ATTACK (executed from
// where the sections are), or after 45 s of reaction without another decision.
private _reactingNow = _groups select {_x getVariable ["ARTIC_reacting",false]};
if (_reactingNow isNotEqualTo []) then {
    if ((_node getOrDefault ["reactStart",-1]) < 0) then {_node set ["reactStart",time];};
} else {
    _node set ["reactStart",-1];
};
private _hastyNow = (_node getOrDefault ["hastyFocus",[]]) isNotEqualTo [];
private _reactLong = (_node getOrDefault ["reactStart",-1]) >= 0 && {(time - (_node get "reactStart")) > 45};
private _releaseContact = _contact && {((count _battleCtx) isEqualTo 0) || {_nearHold} || {_emergencyContact} || {_hastyNow} || {_reactLong}};
if (_playing || {_releaseContact}) exitWith {
    if ((count _march) > 0 && {!(_march getOrDefault ["released",false])}) then {
        [format ["Platoon %1: tactical release (%2), nearHold=%3 nearestThreat=%4m",_nodeId,if (_playing) then {"PLAY"} else {"CONTACT"},_nearHold,round _nearestThreat],_nodeId] call ARTIC_fnc_debug;
        _march set ["released",true];
    };
    call _armTacticalExecution;
    {_x setVariable ["ARTIC_platoonTacticalReleased",true,true];} forEach _groups;
    _node set ["marchHoldUntil",time + 20];
    call _release;
};
if (_contact && {!_releaseContact}) then {
    private _lastApproachContact = _march getOrDefault ["lastApproachContact",-1000];
    if ((time - _lastApproachContact) > 20) then {
        [format ["Platoon %1: contact on approach (nearHold=%2 nearestThreat=%3m)%4",_nodeId,_nearHold,round _nearestThreat,
            if (_reactingNow isEqualTo []) then {"; distant contact, continuing routes"} else {"; halted for contact drill"}],_nodeId] call ARTIC_fnc_debug;
        _march set ["lastApproachContact",time];
    };
};
if (time < (_node getOrDefault ["marchHoldUntil",0])) exitWith {call _release};
// v0.3.30: only sections that are not committed in place march with the platoon
_groups = _groups - _committed;
if (_groups isEqualTo []) exitWith {};
{_x setVariable ["ARTIC_platoonTacticalReleased",false,true];} forEach _groups;

// Platoon centre
private _cx = 0; private _cy = 0;
{private _p = [_x] call _sectionPos; _cx = _cx + (_p select 0); _cy = _cy + (_p select 1);} forEach _groups;
private _centre = [_cx / count _groups, _cy / count _groups, 0];

// New objective: new march
if ((count _march) isEqualTo 0 || {((_march getOrDefault ["objective",[0,0,0]]) distance2D _marchObj) > 30} || {_march getOrDefault ["arrived",false] && {(_centre distance2D _marchObj) > 250}}) then {
    _march = createHashMapFromArray [
        ["objective",+_marchObj],["start",+_centre],["axis",_centre getDir _marchObj],
        ["mover",grpNull],["moverTarget",0],["moverSince",0],["arrived",false],["released",false]
    ];
    _node set ["march",_march];
    {_x setVariable ["ARTIC_platoonFinalSlot",nil,true];} forEach _groups;
    [format ["Platoon %1: moving as a platoon to %2 (%3 sections)",_nodeId,mapGridPosition _marchObj,count _groups],_nodeId] call ARTIC_fnc_debug;
};
if (_march getOrDefault ["arrived",false]) exitWith {call _release};
_march set ["released",false];

private _start = _march get "start";
private _axis = _march get "axis";
private _total = _start distance2D _marchObj;

// v0.3.13: intelligence about a future battlefield does NOT make the platoon bound
// toward it. Bounding is reserved for actual combat / deliberate tactical plays.
// Before direct contact the platoon uses continuous travel or a slower tactical
// approach while section routes split toward their assigned HOLD positions.
private _threat = 1e6;
{
    _x params ["_o","_p","_t"];
    if ([_o] call ARTIC_fnc_isCombatEffectiveTarget && {(time - _t) < 120}) then {_threat = _threat min (_centre distance2D _p);};
} forEach (_commander getOrDefault ["contactReports",[]]);
private _hasBattle = (count _battleCtx) > 0;
private _releasePoint = if (_hasBattle) then {_battleCtx getOrDefault ["releasePoint",_marchObj]} else {_marchObj};
// ATP 3-21.8 distinguishes traveling (contact not likely), traveling overwatch
// (contact possible), and bounding overwatch (contact expected). ARTIC deliberately
// keeps the pre-contact approach continuous: intelligence about a battlefield changes
// the platoon to TRAVELLING_OVERWATCH, while bounding is reserved for the actual
// contact/tactical-play layer so sections do not fragment hundreds of metres early.
private _technique = if (_hasBattle || {_threat < 900}) then {"TRAVELLING_OVERWATCH"} else {"TRAVELLING"};

// Terrain / spacing from the lead group's profile
private _mp = [_groups select 0] call ARTIC_fnc_getMovementProfile;
private _close = (_mp getOrDefault ["terrain","OPEN"]) isEqualTo "CLOSE";
private _desiredForm = ["WEDGE","FILE"] select _close;
private _form = _march getOrDefault ["approachForm",_desiredForm];
if !(_form in ["WEDGE","FILE"]) then {_form = _desiredForm;};
private _pendingForm = _march getOrDefault ["approachFormPending",""];
private _pendingSince = _march getOrDefault ["approachFormPendingSince",time];
if (_desiredForm isEqualTo _form) then {
    _pendingForm = "";
    _pendingSince = time;
} else {
    if (_pendingForm isNotEqualTo _desiredForm) then {
        _pendingForm = _desiredForm;
        _pendingSince = time;
    } else {
        if ((time - _pendingSince) >= 45) then {
            _form = _desiredForm;
            _pendingForm = "";
            _pendingSince = time;
            [format ["Platoon %1: approach formation transition authorised -> %2 after sustained terrain change",_nodeId,_form],_nodeId] call ARTIC_fnc_debug;
        };
    };
};
// v0.3.19: a major COA shift is a reposition march, not a combat deployment.
// Move each section in FILE/COLUMN until the new release side is occupied, then allow
// the battle geometry to reopen FIX / LEFT / RIGHT lanes. This prevents a 60-90 degree
// COA rotation from swinging every WEDGE slot tens of metres at once.
if (_repositioning) then {
    _form = "FILE";
    _pendingForm = "";
    _pendingSince = time;
};
_march set ["approachForm",_form];
_march set ["approachFormPending",_pendingForm];
_march set ["approachFormPendingSince",_pendingSince];
// Keep section spacing consistent with the platoon formation that is actually being
// executed; a momentary close-country classifier must not collapse a WEDGE to FILE spacing.
private _S = if (_repositioning) then {35} else {if (_form isEqualTo "FILE") then {22} else {70}};

// Order sections by scheme role
private _rank = {
    switch (_this getVariable ["ARTIC_schemeRole",""]) do {
        case "FIX": {0}; case "BLOCK": {0}; case "MANOEUVRE_LEFT": {1}; case "MANOEUVRE_RIGHT": {2};
        case "MANOEUVRE_AUTO": {3}; case "RESERVE": {4}; case "RESERVE_SUPPORT": {5}; default {3};
    }
};
private _ordered = [_groups,[],{_x call _rank},"ASCEND"] call BIS_fnc_sortBy;
private _hasSides = (_ordered findIf {(_x getVariable ["ARTIC_schemeRole",""]) in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT"]}) > -1;
private _formationClose = _form isEqualTo "FILE";
private _depthMul = if (_technique isEqualTo "TRAVELLING") then {1} else {1.08};

// [lateral, forward] offset per section, relative to the platoon guide point
private _offsets = [];
{
    private _role = _x getVariable ["ARTIC_schemeRole",""];
    private _i = _forEachIndex;
    private _off = if (_formationClose) then {
        [0, -(_i * _S)]
    } else {
        if (_hasSides) then {
            switch (_role) do {
                case "FIX": {[0,0]};
                case "MANOEUVRE_LEFT": {[-_S, -0.6 * _S * _depthMul]};
                case "MANOEUVRE_RIGHT": {[_S, -0.6 * _S * _depthMul]};
                default {[0, -(1.1 + 0.4 * (_i - 3)) * _S * _depthMul]};
            }
        } else {
            switch (_i) do {
                case 0: {[0,0]};
                case 1: {[-_S, -0.6 * _S * _depthMul]};
                case 2: {[_S, -0.6 * _S * _depthMul]};
                default {[0, -(1.1 + 0.4 * (_i - 3)) * _S * _depthMul]};
            }
        }
    };
    _offsets pushBack _off;
} forEach _ordered;

// Progress along the axis, corrected for each section's formation depth
private _progressOf = {
    params ["_g","_off"];
    private _p = [_g] call _sectionPos;
    private _d = _start distance2D _p;
    private _ang = (_start getDir _p) - _axis;
    (_d * cos _ang) - (_off select 1)
};
private _progress = [];
{_progress pushBack ([_x,_offsets select _forEachIndex] call _progressOf);} forEach _ordered;
private _P = 1e9; private _Pmax = -1e9;
{_P = _P min _x; _Pmax = _Pmax max _x;} forEach _progress;

private _slotAt = {
    params ["_prog","_off"];
    private _base = _start getPos [(_prog + (_off select 1)) max 0, _axis];
    if ((abs (_off select 0)) > 0.1) then {
        _base = _base getPos [abs (_off select 0), _axis + ([90,-90] select ((_off select 0) < 0))];
    };
    _base
};

// Arrival: if a battlefield has been prepared, sections occupy role-specific HOLD
// positions rather than converging around the objective itself. The FIX section will
// subsequently advance from HOLD to the fire line; manoeuvre sections enter their
// persistent left/right corridors from here.
private _finalSlots = [];
{
    private _bp = _x getVariable ["ARTIC_battleDeploymentPos",_x getVariable ["ARTIC_battleHoldPos",[]]];
    if (_repositioning) then {
        // Re-form the platoon on the new release side before opening FIX/LEFT/RIGHT lanes.
        private _role = _x getVariable ["ARTIC_schemeRole",""];
        private _lat = switch (_role) do {case "MANOEUVRE_LEFT": {-45}; case "MANOEUVRE_RIGHT": {45}; default {0};};
        private _rp = +_marchObj;
        if ((abs _lat) > 0.1) then {_rp = _rp getPos [abs _lat,(_battleCtx get "axis") + (if (_lat < 0) then {-90} else {90})];};
        _finalSlots pushBack _rp;
    } else {
        if ((count _battleCtx) > 0 && {_bp isNotEqualTo []}) then {_finalSlots pushBack (+_bp)} else {_finalSlots pushBack ([_total,_offsets select _forEachIndex] call _slotAt);};
    };
} forEach _ordered;
private _allNear = true;
{private _rp = [_x] call _sectionPos; if ((_rp distance2D (_finalSlots select _forEachIndex)) > 45) then {_allNear = false;};} forEach _ordered;
private _battleAssaultAllowed = if ((count _battleCtx) > 0) then {((_battleCtx getOrDefault ["assessment",createHashMap]) getOrDefault ["assaultAllowed",false])} else {true};
if (_allNear && {_repositioning}) exitWith {
    _battleCtx set ["repositionComplete",true];
    _battleCtx set ["lastPlanReview",time];
    _node set ["battleContext",_battleCtx];
    {
        _x setVariable ["ARTIC_battleApproachRoute",[],true];
        _x setVariable ["ARTIC_battleRouteKey","",true];
        _x setVariable ["ARTIC_battleRouteIndex",0,true];
        _x setVariable ["ARTIC_routeWatchPos",[_x] call _sectionPos,true];
        _x setVariable ["ARTIC_routeLastMovementAt",time,true];
    } forEach _ordered;
    _node set ["march",createHashMap];
    [format ["Platoon %1: REPOSITION_FOR_ATTACK complete at %2; establishing attack lanes on axis %3",_nodeId,mapGridPosition _marchObj,round (_battleCtx getOrDefault ["axis",0])],_nodeId] call ARTIC_fnc_debug;
};
if (_allNear && {_intent in ["SEIZE","ATTACK","CAPTURE","RAID"]} && {!_battleAssaultAllowed}) then {
    // Occupy/hold the attack position under platoon-guide ownership while the commander
    // waits for intelligence, a viable SBF, or additional support. Do NOT release groups
    // into FIX/LEFT/RIGHT scripts that cannot satisfy the plan.
    {_x setVariable ["ARTIC_platoonFinalSlot",_finalSlots select _forEachIndex,true];} forEach _ordered;
    private _lastHoldLog = _march getOrDefault ["lastInvalidPlanHold",-1000];
    if ((time - _lastHoldLog) > 20) then {
        [format ["Platoon %1: HOLD occupied but assault not authorised (plan=%2); maintaining guide control",_nodeId,((_battleCtx getOrDefault ["assessment",createHashMap]) getOrDefault ["plan","?"])],_nodeId] call ARTIC_fnc_debug;
        _march set ["lastInvalidPlanHold",time];
    };
};
if (_allNear && {_battleAssaultAllowed}) exitWith {
    {_x setVariable ["ARTIC_platoonFinalSlot",_finalSlots select _forEachIndex,true];} forEach _ordered;
    _march set ["arrived",true];
    call _armTacticalExecution;
    {_x setVariable ["ARTIC_platoonTacticalReleased",true,true];} forEach _ordered;
    [format ["Platoon %1: battle HOLD line occupied at %2 in %3; tactical release authorised",_nodeId,mapGridPosition _marchObj,_form],_nodeId] call ARTIC_fnc_debug;
    call _release;
};

// Targets per section. Once the battlefield is prepared, each section owns its own
// terrain-scored approach route. Before that, normal platoon geometry is retained.
private _look = if (_technique isEqualTo "TRAVELLING") then {[60,35] select _formationClose} else {[42,28] select _formationClose};
private _targets = [];
private _routeRemaining = [];
if (_repositioning) then {
    {_targets pushBack (+(_finalSlots select _forEachIndex));} forEach _ordered;
} else {
if (_hasBattle) then {
    {
        private _g = _x;
        private _route = _g getVariable ["ARTIC_battleApproachRoute",[]];
        private _idx = _g getVariable ["ARTIC_battleRouteIndex",0];
        private _rp = [_g] call _sectionPos;
        private _corridorWidth = missionNamespace getVariable ["ARTIC_routeCorridorWidth",38];

        // v0.3.27 corridor gates: a control point is a gate through a safe tactical
        // corridor, not an exact coordinate that the section must touch. Advance when
        // inside the gate radius OR when the section has crossed the gate plane toward
        // the following point. This removes the return-turn/jinking behaviour caused by
        // missing a CP by a few metres.
        private _advance = true;
        while {_advance && {_idx < count _route}} do {
            _advance = false;
            private _cp = _route select _idx;
            if ((_rp distance2D _cp) <= _corridorWidth) then {
                _idx = _idx + 1;
                _advance = true;
            } else {
                if (_idx < ((count _route) - 1)) then {
                    private _nx = _route select (_idx + 1);
                    private _vx = (_nx select 0) - (_cp select 0);
                    private _vy = (_nx select 1) - (_cp select 1);
                    private _wx = (_rp select 0) - (_cp select 0);
                    private _wy = (_rp select 1) - (_cp select 1);
                    private _passed = (_vx * _wx + _vy * _wy) > 0;
                    if (_passed && {(_rp distance2D _nx) < ((_cp distance2D _nx) + _corridorWidth)}) then {
                        _idx = _idx + 1;
                        _advance = true;
                    };
                };
            };
        };

        // Re-plan only when the SECTION PHYSICALLY stops moving, not merely because its
        // distance to one ideal CP failed to shrink. Arma may legitimately route around
        // rocks/vegetation while still making good progress inside the corridor.
        private _watchPos = _g getVariable ["ARTIC_routeWatchPos",_rp];
        private _lastMove = _g getVariable ["ARTIC_routeLastMovementAt",time];
        if ((_rp distance2D _watchPos) >= 8) then {
            _watchPos = +_rp;
            _lastMove = time;
            _g setVariable ["ARTIC_routeWatchPos",_watchPos,true];
            _g setVariable ["ARTIC_routeLastMovementAt",_lastMove,true];
        };
        private _cpDist = if (_idx < count _route) then {_rp distance2D (_route select _idx)} else {_rp distance2D (_finalSlots select _forEachIndex)};
        private _replanAfter = missionNamespace getVariable ["ARTIC_routeReplanSeconds",35];
        if ((time - _lastMove) > _replanAfter && {_cpDist > (_corridorWidth + 12)}) then {
            private _roleR = _g getVariable ["ARTIC_schemeRole","SECTION"];
            _route = [_rp,_finalSlots select _forEachIndex,_battleCtx get "focus",_roleR,_battleCtx get "axis",_battleCtx get "frontage",(_battleCtx getOrDefault ["radius",100]) + 80] call ARTIC_fnc_planSectionRoute;
            _idx = 0;
            _g setVariable ["ARTIC_battleApproachRoute",_route,true];
            _g setVariable ["ARTIC_battleRouteIndex",0,true];
            _g setVariable ["ARTIC_routeWatchPos",+_rp,true];
            _g setVariable ["ARTIC_routeLastMovementAt",time,true];
            [format ["%1 CORRIDOR REPLAN physicalNoProgress=%2s cpDist=%3m newGates=%4",
                _roleR,round (time - _lastMove),round _cpDist,count _route],groupId _g] call ARTIC_fnc_debug;
        };
        _g setVariable ["ARTIC_battleRouteIndex",_idx,true];
        private _slot = if (_idx < count _route) then {+(_route select _idx)} else {+(_finalSlots select _forEachIndex)};
        _targets pushBack _slot;
        _routeRemaining pushBack (_rp distance2D (_finalSlots select _forEachIndex));
    } forEach _ordered;
} else {
    private _T = (_P + _look) min _total;
    {_targets pushBack ([_T,_offsets select _forEachIndex] call _slotAt);} forEach _ordered;
};
};

// Publish (only when something changed, or every 20 s to keep it fresh)
private _now = CBA_missionTime;
private _reacting = _groups select {_x getVariable ["ARTIC_reacting",false]};
private _reactPause = _reacting isNotEqualTo [];
if (_reactPause && {(time - (_node getOrDefault ["reactPauseLog",-1e6])) > 20}) then {
    [format ["Platoon %1: %2 reacting to contact; platoon halts in place while it develops the situation",_nodeId,(_reacting apply {groupId _x}) joinString ", "],_nodeId] call ARTIC_fnc_debug;
    _node set ["reactPauseLog",time];
};
{
    private _g = _x;
    private _slot = _targets select _forEachIndex;
    // v0.3.25: a section is reacting to effective contact -> the platoon HALTS: every
    // section holds where it is (the reacting one fights its contact LINE) until the
    // platoon's contact response decides (hasty attack / release / hold).
    if (_reactPause) then {_slot = [_g] call _sectionPos;};
    private _ahead = false;
    if (_hasBattle && {_routeRemaining isNotEqualTo []}) then {
        private _maxRemain = 0; {_maxRemain = _maxRemain max _x;} forEach _routeRemaining;
        _ahead = (_routeRemaining select _forEachIndex) < (_maxRemain - ([45,25] select _formationClose));
    } else {
        _ahead = (_progress select _forEachIndex) > (_P + ([25,12] select _formationClose));
    };
    private _speed = if (_ahead || {_technique isEqualTo "TRAVELLING_OVERWATCH"}) then {"LIMITED"} else {"NORMAL"};
    private _old = _g getVariable ["ARTIC_platoonMove",[]];
    private _changed = _old isEqualTo []
        || {((_old select 0) distance2D _slot) > 12}
        || {(_old select 1) isNotEqualTo _speed}
        || {(_old select 2) isNotEqualTo _technique}
        || {(_now - (_old select 3)) > 20};
    if (_changed) then {
        _g setVariable ["ARTIC_platoonMove",[_slot,_speed,_technique,_now,_form],true];
    };
    _g setVariable ["ARTIC_platoonTacticalReleased",false,true];
} forEach _ordered;

private _lastLog = _march getOrDefault ["lastLog",-1000];
if ((time - _lastLog) > 20 || {(_march getOrDefault ["lastTech",""]) isNotEqualTo _technique}) then {
    private _detail = if (_repositioning) then {format ["REPOSITION_FOR_ATTACK -> RELEASE %1",mapGridPosition _marchObj]} else {if (_hasBattle) then {format ["section deployment corridors -> %1",mapGridPosition _marchObj]} else {format ["progress %1/%2m",round _P,round _total]}};
    [format ["Platoon %1: %2 %3, %4, spacing %5m",_nodeId,_technique,_form,_detail,round _S],_nodeId] call ARTIC_fnc_debug;
    _march set ["lastLog",time];
    _march set ["lastTech",_technique];
};
