/*
    ARTIC - section formation controller (v0.3.27). Runs on the group's owner every
    individual-AI tick (~1 s), before the soldiers' individual steps.

    - The persistent guide survives all movement-owner handovers. Tactical plays retask it;
      they never destroy/rebuild it from the soldiers.
    - Guide point = the formation's reference. It follows a real route to the section's
      destination (calculatePath "man", thinned; straight line until the path arrives)
      and SELF-PACES: it advances only while the soldiers are close to their slots, slows
      when they lag, and waits when they are well behind. The formation follows the guide,
      not its own centre (the v0.3.5-0.3.8 anchors were computed from the soldiers).
    - Formation from ARTIC_fnc_selectFormation; role slots use bounded real-metre
      templates with only a small terrain/training scale.
    - While developing contact the guide halts and faces the enemy (LINE).
*/
params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group} || {!(missionNamespace getVariable ["ARTIC_formationSystem",true])}) exitWith {};
if (isPlayer leader _group) exitWith {};
private _planActive = (_group getVariable ["ARTIC_currentPlan",""]) isNotEqualTo "";
private _tacticalGuide = _group getVariable ["ARTIC_tacticalGuideActive",false];
if (!_tacticalGuide && {!_planActive}) then {
    private _pmOwn = _group getVariable ["ARTIC_platoonMove",[]];
    if (_pmOwn isEqualTo [] || {_group getVariable ["ARTIC_platoonTacticalReleased",false]}) then {
        _group setVariable ["ARTIC_movementOwner","FORMATION",false];
    };
};
// v0.3.16: NEVER destroy the spatial reference during a plan handover. Previous builds
// cleared ARTIC_guide in the gap between currentPlan becoming active and the tactical
// guide taking ownership; the tactical layer then rebuilt from a dispersed soldier
// centroid. Preserve the guide and simply halt it until the new owner supplies a target.
if (_planActive && {!_tacticalGuide}) exitWith {
    private _g = _group getVariable ["ARTIC_guide",[]];
    if (_g isNotEqualTo []) then {
        _g set [2,time];
        _group setVariable ["ARTIC_guide",_g,false];
        _group setVariable ["ARTIC_sectionReferencePos",+(_g select 0),false];
    };
    _group setVariable ["ARTIC_guideMoving",false,false];
    _group setVariable ["ARTIC_formVel",0,false];
};
private _fit = (units _group) select {[_x] call ARTIC_fnc_isFit};
if (_fit isEqualTo []) exitWith {};

// Initial guide only: use the majority cluster rather than a raw centroid so a single
// runaway / stuck soldier cannot cause the persistent reference to spawn tens of metres
// away from the body of the section.
private _clusterSeed = _fit select 0;
private _clusterN = -1;
{
    private _cand = _x;
    private _n = {_cand distance2D _x <= 35} count _fit;
    if (_n > _clusterN) then {_clusterSeed = _cand; _clusterN = _n;};
} forEach _fit;
private _cluster = _fit select {_clusterSeed distance2D _x <= 42};
if (_cluster isEqualTo []) then {_cluster = +_fit;};
private _cx = 0; private _cy = 0;
{private _p = getPosATL _x; _cx = _cx + (_p select 0); _cy = _cy + (_p select 1);} forEach _cluster;
private _centre = [_cx / count _cluster, _cy / count _cluster, 0];
private _dest = _group getVariable ["ARTIC_sectionDestination",[]];

private _guide = _group getVariable ["ARTIC_guide",[]];
if (_guide isEqualTo []) then {
    private _dir = if (_dest isEqualTo []) then {getDir leader _group} else {_centre getDir (_dest select 0)};
    // start slightly ahead of the centre so the commander's slot sits near where he is
    _guide = [_centre getPos [6,_dir], _dir, time];
    (_guide select 0) set [2,0];
};
_guide params ["_gPos","_gDir","_gTime"];

private _target = [_group] call ARTIC_fnc_findTarget;
([_group,_target,_gDir] call ARTIC_fnc_selectFormation) params ["_form","_face","_why"];

// v0.3.16: formations are changed at route/control points, not continuously every time
// a local classifier flips. Urgent contact / tactical overrides may still change now.
private _currentForm = _group getVariable ["ARTIC_formation",""];
private _overrideForm = toUpper (_group getVariable ["ARTIC_tacticalFormationOverride",""]);
private _contactAction = _group getVariable ["ARTIC_contactAction","NONE"];
private _urgentForm = _currentForm isEqualTo "" || {_overrideForm isNotEqualTo ""} || {_contactAction in ["REACT","DEVELOP"]};
private _changeWindow = time <= (_group getVariable ["ARTIC_formationChangeWindowUntil",0]);
private _lastFormChange = _group getVariable ["ARTIC_lastFormationChange",-1e6];
if (_currentForm isNotEqualTo "" && {_form isNotEqualTo _currentForm} && {!_urgentForm} && {!_changeWindow} && {(time - _lastFormChange) < 25}) then {
    _form = _currentForm;
    _why = "held until control point";
};

([_group] call ARTIC_fnc_getProfile) params ["","","","_training"];
private _coord = _training getOrDefault ["coordination",0.55];
private _mp = [_group] call ARTIC_fnc_getMovementProfile;
private _close = (_mp getOrDefault ["terrain","OPEN"]) isEqualTo "CLOSE";

// formation change
if ((_group getVariable ["ARTIC_formation",""]) isNotEqualTo _form) then {
    _group setVariable ["ARTIC_formation",_form,false];
    _group setVariable ["ARTIC_lastFormationChange",time,false];
    // ARTIC owns formation geometry through explicit guide slots. Do not also ask the
    // Arma group-formation engine to reorganise the same soldiers; that created a second
    // movement owner during attack approaches and was a major source of crossings/stalls.
    [format ["Formation %1 (%2)",_form,_why],groupId _group] call ARTIC_fnc_debug;
};
[_group,_form] call ARTIC_fnc_assignFormationSlots;

// v0.3.16: templates are authored in real metres. ARTIC_formSpacing is now only a
// modest scale for terrain/training, never a global multiplier derived from the closest
// pair. This prevents command/medical roles becoming a 50-90 m tail in COLUMN.
([_group] call ARTIC_fnc_getProfile) params ["","_tName2"];
private _trainScale = switch (_tName2) do {case "POOR": {0.82}; case "REGULAR": {0.9}; case "ELITE": {1.05}; default {1.0};};
private _spacing = ([1.0,0.68] select _close) * _trainScale;
_spacing = (_spacing max 0.62) min 1.08;
private _minSep = (switch (_tName2) do {case "POOR": {5}; case "REGULAR": {6}; case "ELITE": {8}; default {7};}) * ([1,0.72] select _close);
_group setVariable ["ARTIC_formSpacing",_spacing,false];
_group setVariable ["ARTIC_formMinSep",_minSep,false];

// v0.3.14: heavy left / heavy right. The MG side of the formation faces the most likely
// contact: the template is mirrored when the nearest known threat is on the right
// (templates carry the first MG on the left). 20 deg hysteresis so it doesn't flip-flop.
private _mirror = _group getVariable ["ARTIC_formMirror",false];
private _thr = [];
if ([_target] call ARTIC_fnc_isCombatEffectiveTarget) then {_thr = getPosATL _target;} else {
    private _best = 1e6;
    {
        if ([_x select 0] call ARTIC_fnc_isCombatEffectiveTarget && {(time - (_x select 2)) < 120} && {((_x select 1) distance2D _gPos) < _best}) then {
            _best = (_x select 1) distance2D _gPos; _thr = _x select 1;
        };
    } forEach (_group getVariable ["ARTIC_sharedContacts",[]]);
};
if (_thr isNotEqualTo [] && {!(_form in ["COLUMN","DIAMOND","BOX","BOX_DIAMOND"])}) then {
    private _rel = (((_gPos getDir _thr) - _gDir) + 360) % 360;
    if (!_mirror && {_rel > 20 && {_rel < 160}}) then {_mirror = true;};
    if (_mirror && {_rel > 200 && {_rel < 340}}) then {_mirror = false;};
};
_group setVariable ["ARTIC_formMirror",_mirror,false];

// behaviour / pace
private _paceBase = switch (_form) do {
    case "COLUMN": {[1.8,2.4] select (_why isEqualTo "safe: speed")};
    case "DIAMOND"; case "BOX"; case "BOX_DIAMOND": {1.5};
    default {1.7};
};
private _pace = _paceBase * (0.8 + 0.2 * _coord);
// v0.3.27 phase pace. Long COA repositioning should move like a deliberate transit,
// not a permanent 1.6-1.7 m/s combat creep. DEPLOY remains controlled but quicker than
// the old approach. Tactical/contact movement retains its own pace.
private _platoonPhase = _group getVariable ["ARTIC_platoonPhase",""];
private _pmPace = if (_platoonPhase isEqualTo "REPOSITION") then {
    missionNamespace getVariable ["ARTIC_repositionPace",2.7]
} else {
    if (_platoonPhase isEqualTo "DEPLOY") then {missionNamespace getVariable ["ARTIC_deployPace",2.1]} else {0}
};
if (_pmPace > 0) then {_pace = _pace max _pmPace;};
_group setVariable ["ARTIC_formPace",_pace,false];
// Formation geometry may anticipate a known threat, but UAS/shared intelligence alone
// must not put the engine into COMBAT and make vanilla AI invent its own manoeuvres.
private _actualContact = _group getVariable ["ARTIC_inContact",false];
private _pmNow = _group getVariable ["ARTIC_platoonMove",[]];
private _marchOwned = _pmNow isNotEqualTo [] && {(CBA_missionTime - (_pmNow select 3)) < 30} && {!(_group getVariable ["ARTIC_platoonTacticalReleased",false])};
private _repositionForAttack = _group getVariable ["ARTIC_repositionForAttack",false];
private _beh = if ((_actualContact || {_tacticalGuide}) && {!_marchOwned}) then {"COMBAT"} else {"AWARE"};
if ((behaviour leader _group) isNotEqualTo _beh) then {_group setBehaviour _beh;};

// ---- guide movement (v0.3.11: smoothed, hysteresis, look-ahead heading) ---------------
private _dt = ((time - _gTime) max 0) min 3;
private _developing = (time < (_group getVariable ["ARTIC_developUntil",0])) || {_group getVariable ["ARTIC_holdContactLine",false]};   // v0.3.25: contact LINE also while holding
private _moving = false;
private _vel = 0;

if (_developing && {_face >= 0}) then {
    // Contact LINE: facing locked at the start of the drill; only re-aimed if the enemy's
    // bearing moves by more than 25 deg (0.3.10 re-aimed every second from the
    // commander's position, so the whole line kept rotating).
    private _locked = _group getVariable ["ARTIC_developFace",-1];
    private _diff = abs ((((_face - _locked) + 540) % 360) - 180);
    if (_locked < 0 || {_diff > 25}) then {_locked = _face; _group setVariable ["ARTIC_developFace",_locked,false];};
    _gDir = _locked;
    _group setVariable ["ARTIC_guideHalted",false,false];
} else {
    _group setVariable ["ARTIC_developFace",-1,false];
    if (_dest isNotEqualTo [] && {(_gPos distance2D (_dest select 0)) > 4}) then {
        // route
        private _path = _group getVariable ["ARTIC_guidePath",[]];
        private _req = _group getVariable ["ARTIC_guidePathRequested",-1];
        if (_path isEqualTo [] && {_req < 0}) then {
            _group setVariable ["ARTIC_guidePathRequested",time,false];
            private _agent = calculatePath ["man","safe",_gPos,_dest select 0];
            if (!isNil "_agent" && {!isNull _agent}) then {
                _agent setVariable ["ARTIC_pathGroup",_group];
                _agent setVariable ["ARTIC_pathStart",+_gPos];
                _agent setVariable ["ARTIC_pathDest",+(_dest select 0)];
                _agent addEventHandler ["PathCalculated",{
                    params ["_agent","_pts"];
                    private _g = _agent getVariable ["ARTIC_pathGroup",grpNull];
                    if (isNull _g || {(_g getVariable ["ARTIC_guidePath",[]]) isNotEqualTo []}) exitWith {};
                    private _thin = []; private _last = [];
                    {
                        private _q = [_x select 0,_x select 1,0];
                        if (_last isEqualTo [] || {(_last distance2D _q) >= 8}) then {_thin pushBack _q; _last = _q;};
                    } forEach _pts;
                    _thin pushBack (_agent getVariable ["ARTIC_pathDest",_last]);
                    // v0.3.18: reject pathological engine paths that swing a section far
                    // outside its tactical lane.  The route control-point watchdog will
                    // re-plan locally if the direct corridor later proves impassable.
                    private _direct = (_agent getVariable ["ARTIC_pathStart",_last]) distance2D (_agent getVariable ["ARTIC_pathDest",_last]);
                    private _plen = 0;
                    private _pp = _agent getVariable ["ARTIC_pathStart",_last];
                    {_plen = _plen + (_pp distance2D _x); _pp = _x;} forEach _thin;
                    if (_direct > 20 && {_plen > (_direct * 2.2 + 80)}) then {
                        _thin = [+(_agent getVariable ["ARTIC_pathDest",_last])];
                        [format ["Guide path rejected as pathological: path=%1m direct=%2m; using tactical corridor",round _plen,round _direct],groupId _g] call ARTIC_fnc_debug;
                    };
                    _g setVariable ["ARTIC_guidePath",_thin,false];
                    if (missionNamespace getVariable ["ARTIC_debugMarkers",false]) then {
                        _g setVariable ["ARTIC_guidePathDebug",+_thin,true];
                    };
                }];
            };
        };
        if (_path isEqualTo [] && {_req >= 0} && {(time - _req) > 8}) then {
            _path = [+(_dest select 0)];
            _group setVariable ["ARTIC_guidePath",_path,false];
            if (missionNamespace getVariable ["ARTIC_debugMarkers",false]) then {
                _group setVariable ["ARTIC_guidePathDebug",+_path,true];
            };
        };
        private _next = if (_path isEqualTo []) then {_dest select 0} else {_path select 0};

        // v0.3.19 elastic BODY LEASH. Slot error is diagnostic, but it is no longer a
        // binary movement interlock. The guide is allowed to slow to a crawl while the
        // median body catches up; only deliberate tactical states are allowed to set
        // section velocity to zero. This removes the guide-stop -> commander-doStop ->
        // larger slot error feedback loop seen in the 0.3.18 radar benchmark.
        private _err = 0; private _n = 0; private _protectedLag = 0;
        private _dists = []; private _forwardLags = [];
        {
            private _reacting = (_x getVariable ["ARTIC_reactionState",[]]) isNotEqualTo [];
            private _s = [_x,_group,false] call ARTIC_fnc_formationSlotWorld;
            if (_s isNotEqualTo [] && {!_reacting}) then {
                private _uPos = getPosATL _x;
                private _dSlot = _x distance2D _s;
                _err = _err + _dSlot; _n = _n + 1;
                _dists pushBack _dSlot;

                // Signed distance from the soldier to his own slot along the guide axis.
                // Positive = soldier is behind his slot; negative = ahead of it.
                private _dx = (_s select 0) - (_uPos select 0);
                private _dy = (_s select 1) - (_uPos select 1);
                private _fLag = (_dx * sin _gDir) + (_dy * cos _gDir);
                _forwardLags pushBack (((_fLag max -20) min 80));

                if ((_x getVariable ["ARTIC_formRole",""]) in ["CMD","MEDIC","SECOND"]) then {
                    _protectedLag = _protectedLag max _dSlot;
                };
            };
        } forEach _fit;
        _err = if (_n > 0) then {_err / _n} else {0};
        _dists sort false;
        _forwardLags sort true;
        private _secondWorst = if ((count _dists) >= 2) then {_dists select 1} else {_dists param [0,0]};

        private _medianLag = 0;
        if (_forwardLags isNotEqualTo []) then {
            private _cLag = count _forwardLags;
            private _mid = floor (_cLag / 2);
            _medianLag = if ((_cLag mod 2) isEqualTo 0) then {
                ((_forwardLags select (_mid - 1)) + (_forwardLags select _mid)) * 0.5
            } else {
                _forwardLags select _mid
            };
        };
        private _bodyLag = _medianLag max 0;

        private _errS = (_group getVariable ["ARTIC_formErrorS",_err]) * 0.72 + _err * 0.28;
        _group setVariable ["ARTIC_formErrorS",_errS,false];
        private _errMax = 8 + 7 * (1 - _coord);
        private _hardShape = 24 + 8 * (1 - _coord);
        private _badCount = {_x > _hardShape} count _dists;

        // Median forward lag is the authoritative body leash. At the soft limit the guide
        // begins slowing; by the hard limit it crawls at ~20-30% pace but never freezes.
        private _softLag = 6 + 5 * (1 - _coord);
        private _hardLag = 18 + 10 * (1 - _coord);
        private _bodyMult = 1;
        if (_bodyLag > _softLag) then {
            private _t = (((_bodyLag - _softLag) / ((_hardLag - _softLag) max 1)) max 0) min 1;
            _bodyMult = 1 - (0.72 * _t);
        };
        if (_bodyLag > _hardLag) then {_bodyMult = 0.22;};

        // v0.3.20: during REPOSITION_FOR_ATTACK, longitudinal body lag is the ONLY
        // pacing input. Lateral/shape error is still measured for diagnostics, but it
        // must not slow a column whose bodyLag is zero. Outside repositioning, shape
        // remains a soft modifier.
        private _shapeMult = ((1.15 - 0.45 * (_errS / (_errMax max 1))) max 0.45) min 1;
        private _mult = if (_repositionForAttack) then {
            (_bodyMult max 0.35) min 1
        } else {
            ((_bodyMult min _shapeMult) max 0.20) min 1
        };

        _group setVariable ["ARTIC_guideHalted",false,false];
        _group setVariable ["ARTIC_guideHaltReason","",false];
        _group setVariable ["ARTIC_guideBodyLag",_bodyLag,false];
        _group setVariable ["ARTIC_guideSpeedMult",_mult,false];

        private _oldLeash = _group getVariable ["ARTIC_guideLeashMode","NORMAL"];
        private _leash = if (_mult < 0.32) then {"CRAWL"} else {if (_mult < 0.72) then {"SLOW"} else {"NORMAL"}};
        _group setVariable ["ARTIC_guideLeashMode",_leash,false];
        if (_leash isNotEqualTo _oldLeash) then {
            [format ["GUIDE LEASH %1 phase=%2 bodyLag=%3m avg=%4m bad=%5/%6 secondWorst=%7m protectedLag=%8m mult=%9",
                _leash,["NORMAL","REPOSITION"] select _repositionForAttack,round _bodyLag,round _errS,_badCount,_n,round _secondWorst,round _protectedLag,(round (_mult * 100))/100],groupId _group] call ARTIC_fnc_debug;
        };
        private _stepLen = _pace * _dt * _mult;
        if (_stepLen > 0) then {
            _moving = true;
            _vel = _pace * _mult;
            private _dNext = _gPos distance2D _next;
            if (_stepLen >= _dNext) then {
                _gPos = +_next; _gPos set [2,0];
                if (_path isNotEqualTo []) then {
                    _path deleteAt 0;
                    _group setVariable ["ARTIC_guidePath",_path,false];
                    if (missionNamespace getVariable ["ARTIC_debugMarkers",false]) then {
                        _group setVariable ["ARTIC_guidePathDebug",+_path,true];
                    };
                    _group setVariable ["ARTIC_formationChangeWindowUntil",time + 6,false];
                };
            } else {
                _gPos = _gPos getPos [_stepLen, _gPos getDir _next]; _gPos set [2,0];
            };
            // heading toward a point ~25 m ahead on the route, max 8 deg/s, 4 deg deadband
            private _look = +(_dest select 0);
            private _acc = 0; private _prev = _gPos;
            {
                _acc = _acc + (_prev distance2D _x);
                _prev = _x;
                if (_acc >= 25) exitWith {_look = _x;};
            } forEach _path;
            if ((_gPos distance2D _look) > 3) then {
                private _want = _gPos getDir _look;
                private _delta = ((_want - _gDir + 540) % 360) - 180;
                if ((abs _delta) > 4) then {
                    private _maxTurn = 8 * (_dt max 0.5);
                    _gDir = (_gDir + ((_delta max -_maxTurn) min _maxTurn) + 360) % 360;
                };
            };
        };
        _group setVariable ["ARTIC_formError",_err,false];
    } else {
        _group setVariable ["ARTIC_guideHalted",false,false];
    };
};

_group setVariable ["ARTIC_guide",[_gPos,_gDir,time],false];
// Authoritative physical reference for platoon planning. The leader is a protected
// member inside this formation, not the section position itself.
_group setVariable ["ARTIC_sectionReferencePos",+_gPos,false];
_group setVariable ["ARTIC_guideMoving",_moving,false];
_group setVariable ["ARTIC_formVel",_vel,false];

// Persistent desired fireteam guides are derived from FORMATION SLOTS, never from the
// soldiers' live centroid. They remain stable even when a member reacts to danger.
private _ftMean = {
    params ["_members"];
    private _pts = [];
    {
        if ([_x] call ARTIC_fnc_isFit) then {
            private _sp = [_x,_group,false] call ARTIC_fnc_formationSlotWorld;
            if (_sp isNotEqualTo []) then {_pts pushBack _sp;};
        };
    } forEach _members;
    if (_pts isEqualTo []) exitWith {+_gPos};
    private _sx = 0; private _sy = 0;
    {_sx = _sx + (_x select 0); _sy = _sy + (_x select 1);} forEach _pts;
    [_sx / count _pts,_sy / count _pts,0]
};
private _fta = _group getVariable ["ARTIC_fireteamMembersA",[]];
private _ftb = _group getVariable ["ARTIC_fireteamMembersB",[]];
_group setVariable ["ARTIC_fireteamGuideA",[_fta] call _ftMean,false];
_group setVariable ["ARTIC_fireteamGuideB",[_ftb] call _ftMean,false];

// Lightweight benchmark telemetry. RPT summaries are emitted by processIndividualAI.
private _m = _group getVariable ["ARTIC_metrics",createHashMap];
private _slotSum = 0; private _slotN = 0; private _slotMax = 0;
{
    private _sp = [_x,_group,false] call ARTIC_fnc_formationSlotWorld;
    if (_sp isNotEqualTo [] && {[_x] call ARTIC_fnc_isFit}) then {
        private _d = _x distance2D _sp;
        _slotSum = _slotSum + _d; _slotN = _slotN + 1; _slotMax = _slotMax max _d;
    };
} forEach _fit;
if (_slotN > 0) then {
    _m set ["slotErrorSum",(_m getOrDefault ["slotErrorSum",0]) + (_slotSum / _slotN)];
    _m set ["slotSamples",(_m getOrDefault ["slotSamples",0]) + 1];
    _m set ["slotErrorMax",(_m getOrDefault ["slotErrorMax",0]) max _slotMax];
};
_group setVariable ["ARTIC_metrics",_m,false];
