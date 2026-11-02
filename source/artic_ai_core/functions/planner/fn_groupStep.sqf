params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group} || {!(_group getVariable ["ARTIC_enabled",false])}) exitWith {};
if ((units _group) isEqualTo [] || {!alive leader _group}) exitWith {};

private _order = toUpper (_group getVariable ["ARTIC_executionOrderType",_group getVariable ["ARTIC_orderType",""]]);
if (_order isEqualTo "") exitWith {};
private _pos = _group getVariable ["ARTIC_executionOrderPos",_group getVariable ["ARTIC_orderPos",[]]];
private _radius = _group getVariable ["ARTIC_executionOrderRadius",_group getVariable ["ARTIC_orderRadius",150]];
private _fallback = _group getVariable ["ARTIC_executionFallback",_group getVariable ["ARTIC_orderFallback",[]]];
private _leader = leader _group;

// v0.3.30: is a tactical play running? A play is tracked by its script handle as well as
// ARTIC_currentPlan: finishPlan clears currentPlan, so in 0.3.29 an aborted play that kept
// running let groupStep start a second copy for the same section.
private _plan = _group getVariable ["ARTIC_currentPlan",""];
private _playLive = [_group] call ARTIC_fnc_isSectionPlayActive;

// v0.3.8 / v0.3.30: contact detection and the contact call run for EVERY section, including
// one running a play (0.3.24-0.3.29 skipped them during plays, so a manoeuvre section that
// bumped the enemy mid-flank never called it in). During a play the check runs every 3 s.
// Shared/UAS intelligence is not the same as direct contact. Arma's `reveal` can make a
// radio/UAS report appear in `targets`, so contact is based on actual soldier LOS or an
// immediate danger pulse rather than the target-source label alone.
private _target = objNull;
private _inContact = _group getVariable ["ARTIC_inContact",false];
if (!_playLive || {time >= (_group getVariable ["ARTIC_nextPlayContactCheck",0])}) then {
    if (_playLive) then {_group setVariable ["ARTIC_nextPlayContactCheck",time + 3,false];};
    _target = [_group] call ARTIC_fnc_findTarget;
    private _directLOS = false;
    if (!isNull _target) then {
        _directLOS = ((units _group) findIf {[_x] call ARTIC_fnc_isFit && {[getPosATL _x,_target] call ARTIC_fnc_hasLineOfSight}}) > -1;
    };
    private _directDanger = ((units _group) findIf {[_x] call ARTIC_fnc_isFit && {time < (_x getVariable ["ARTIC_dangerPulseUntil",0])}}) > -1;
    _inContact = !isNull _target && {_directLOS || {_directDanger}};
    if ((_group getVariable ["ARTIC_inContact",false]) isNotEqualTo _inContact) then {
        _group setVariable ["ARTIC_inContact",_inContact,true];
    };
    // v0.3.24: contact call to the platoon (first contact / new enemy group).
    if (_inContact) then {[_group,_target] call ARTIC_fnc_reportContact;};
};
if (_playLive) exitWith {};
if (time < (_group getVariable ["ARTIC_planCooldownUntil",0])) exitWith {};

// v0.3.29: a completed section task is terminal for that immutable plan. The section
// holds/consolidates until the Platoon FSM supersedes the plan and issues a new taskId.
private _activePlatoonPlanId = _group getVariable ["ARTIC_platoonPlanId",""];
if (_activePlatoonPlanId isNotEqualTo "" && {(_group getVariable ["ARTIC_sectionCompletePlanId",""]) isEqualTo _activePlatoonPlanId}) exitWith {
    private _tid = _group getVariable ["ARTIC_sectionTaskId",""];
    if (_tid isNotEqualTo "") then {[_group,_activePlatoonPlanId,_tid,"COMPLETE","PLAN_TASK_COMPLETE"] call ARTIC_fnc_setSectionTaskState;};
};

// v0.3.30: every tactical play is started through here so its handle is tracked.
private _startPlay = {
    params ["_fnc","_args",["_playType","TACTICAL"]];
    if ([_group] call ARTIC_fnc_isSectionPlayActive) exitWith {scriptNull};
    private _pid = _group getVariable ["ARTIC_platoonPlanId",""];
    private _tid = _group getVariable ["ARTIC_sectionTaskId",""];
    _group setVariable ["ARTIC_playPlanId",_pid,false];
    _group setVariable ["ARTIC_playTaskId",_tid,false];
    _group setVariable ["ARTIC_playType",_playType,false];
    private _h = _args spawn _fnc;
    _group setVariable ["ARTIC_playHandle",_h,false];
    _h
};

// v0.3.24: a platoon assist call to a section that is not running a play (reserve, between
// plays): support by fire from where it stands for 30 s.
private _ac = _group getVariable ["ARTIC_assistCall",[]];
if (_ac isNotEqualTo [] && {(_ac select 2) > (_group getVariable ["ARTIC_assistHandledAt",0])} && {(_group getVariable ["ARTIC_currentPlan",""]) isEqualTo ""}) then {
    _group setVariable ["ARTIC_assistHandledAt",_ac select 2,false];
    if ([_ac select 0] call ARTIC_fnc_isCombatEffectiveTarget) then {
        [ARTIC_fnc_suppressElement,[_group,_ac select 0,30,[],true],"ASSIST_SUPPRESS"] call _startPlay;
        [format ["Assisting %1: engaging its contact at %2",_ac select 3,mapGridPosition (_ac select 1)],groupId _group] call ARTIC_fnc_debug;
    };
};

// v0.3.16: a section can be in contact while the PLATOON still owns the approach.
// Long-range/early contact is reported and handled by individual danger reactions, but
// does not immediately tear this section out of its assigned route.
private _pm = _group getVariable ["ARTIC_platoonMove",[]];
private _pmFresh = _pm isNotEqualTo [] && {(CBA_missionTime - (_pm select 3)) < 30};
private _platoonReleased = _group getVariable ["ARTIC_platoonTacticalReleased",false];
// v0.3.25: EFFECTIVE contact (enemy within ~450 m, or the section is actually being shot
// at) takes the section out of the platoon march so it can react: contact LINE facing the
// threat, firing positions from cover, fire control. Distant contact is still only
// reported. (0.3.16-0.3.24 kept marching sections on their routes under fire.)
private _shotAt = ((units _group) findIf {[_x] call ARTIC_fnc_isFit && {time < (_x getVariable ["ARTIC_dangerPulseUntil",0])}}) > -1;
private _effectiveContact = _inContact && {((_group getVariable ["ARTIC_sectionReferencePos",getPosATL _leader]) distance2D _target) < 450 || {_shotAt}};
if ((_group getVariable ["ARTIC_reacting",false]) isNotEqualTo _effectiveContact) then {
    _group setVariable ["ARTIC_reacting",_effectiveContact,true];
};
private _marchControlled = _pmFresh && {!_platoonReleased} && {!_effectiveContact};

// v0.3.9: contact drill. On first contact the section forms a LINE facing the enemy to
// bring every weapon to bear (the formation controller does this), for a time set by
// training (decisionDelay + 2 s, max 14 s), before the plays (suppress / fix / flank)
// start. Contact state resets after 30 s without a target.
private _formSys = missionNamespace getVariable ["ARTIC_formationSystem",true];
// ATP 3-21.8 actions on contact: REACT -> DEVELOP THE SITUATION -> CHOOSE AN
// ACTION -> EXECUTE/REPORT. This is a persistent state label shared with debug and
// future leader logic; it is not a rigid timer-driven battle drill.
if (_inContact && {!_marchControlled}) then {
    _group setVariable ["ARTIC_lastContactTime",time,false];
    if ((_group getVariable ["ARTIC_contactSince",-1]) < 0) then {
        _group setVariable ["ARTIC_contactSince",time,false];
        _group setVariable ["ARTIC_contactAction","REACT",true];
        ([_group] call ARTIC_fnc_getProfile) params ["","","","_trn"];
        private _dev = ((_trn getOrDefault ["decisionDelay",6]) + 2) min 14;
        if (_formSys) then {
            _group setVariable ["ARTIC_developUntil",time + _dev,false];
            [format ["Actions on contact: REACT -> developing situation in LINE for %1 s",round _dev],groupId _group] call ARTIC_fnc_debug;
        };
    };
    if (time < (_group getVariable ["ARTIC_developUntil",0])) then {
        _group setVariable ["ARTIC_contactAction","DEVELOP",true];
    } else {
        if ((_group getVariable ["ARTIC_contactAction",""]) in ["REACT","DEVELOP",""]) then {
            _group setVariable ["ARTIC_contactAction","CHOOSE_ACTION",true];
            ["Actions on contact: situation developed; choosing tactical action",groupId _group] call ARTIC_fnc_debug;
        };
    };
} else {
    if (_inContact && {_marchControlled}) then {
        _group setVariable ["ARTIC_lastContactTime",time,false];
        _group setVariable ["ARTIC_contactAction","APPROACH_CONTACT",true];
    } else {
        if ((time - (_group getVariable ["ARTIC_lastContactTime",-1e6])) > 30) then {
            _group setVariable ["ARTIC_contactSince",-1,false];
            _group setVariable ["ARTIC_contactAction","NONE",true];
        };
    };
};
// v0.3.25: fire control from the first moment of contact
if (_inContact && {!_marchControlled} && {_formSys} && {time < (_group getVariable ["ARTIC_developUntil",0])}) then {
    if !(_group getVariable ["ARTIC_reactFireActive",false]) then {[_group] spawn ARTIC_fnc_sectionReactFire;};
};
if (_inContact && {!_marchControlled} && {_formSys} && {time < (_group getVariable ["ARTIC_developUntil",0])}) exitWith {};

// v0.3.25: after developing, a section the platoon has not yet released HOLDS its contact
// LINE, firing from cover, while the platoon decides (hasty attack / hold / release). It
// does not start its own play or wander toward the objective.
private _holdLine = _effectiveContact && {_formSys} && {_pmFresh} && {!_platoonReleased} && {!(_group getVariable ["ARTIC_tacticalExecutionArmed",false])};
if ((_group getVariable ["ARTIC_holdContactLine",false]) isNotEqualTo _holdLine) then {
    _group setVariable ["ARTIC_holdContactLine",_holdLine,false];
    if (_holdLine) then {["Contact drill: holding contact LINE and returning fire while the platoon decides",groupId _group] call ARTIC_fnc_debug;};
};
if (_holdLine) exitWith {
    if !(_group getVariable ["ARTIC_reactFireActive",false]) then {[_group] spawn ARTIC_fnc_sectionReactFire;};
};

// v0.3.8: platoon movement. While the platoon controller is moving this section as part
// of the platoon (and it isn't in contact), follow the platoon's slot, pace and technique
// instead of walking to the objective on its own.
if (_marchControlled) exitWith {
    _group setVariable ["ARTIC_movementOwner","PLATOON_GUIDE",false];
    _pm params ["_slot","_speed","_tech","_stamp",["_form","WEDGE"]];
    if ((speedMode _group) isNotEqualTo _speed) then {_group setSpeedMode _speed;};
    // Traveling and traveling overwatch remain AWARE; direct contact / tactical plays own COMBAT.
    private _beh = "AWARE";
    if ((behaviour _leader) isNotEqualTo _beh) then {_group setBehaviour _beh;};
    if (_formSys) then {
        // v0.3.9: the section formation controller moves the section in formation; the
        // platoon's formation ("WEDGE"/"FILE") is used as a hint by ARTIC_fnc_selectFormation.
        [_group,_slot] call ARTIC_fnc_setSectionDestination;
    } else {
        if ((_group getVariable ["ARTIC_formationTemplate","WEDGE"]) isNotEqualTo _form) then {
            _group setVariable ["ARTIC_formationTemplate",_form,false];
            _group setFormation _form;
        };
        private _lastSlot = _group getVariable ["ARTIC_lastMarchSlot",[]];
        if (_lastSlot isEqualTo [] || {(_lastSlot distance2D _slot) > 10} || {unitReady _leader && {(_leader distance2D _slot) > 8}}) then {
            _group move _slot;
            _group setVariable ["ARTIC_lastMarchSlot",_slot,false];
        };
    };
};

// v0.3.8: at the objective each section uses its own final slot from the platoon
// formation, so the platoon doesn't converge on a single point.
private _finalSlot = _group getVariable ["ARTIC_platoonFinalSlot",[]];
if (_finalSlot isNotEqualTo [] && {_pos isNotEqualTo []} && {(_finalSlot distance2D _pos) < 450}) then {
    _pos = +_finalSlot;
    _radius = _radius min 60;
};
// Once a battlefield has been prepared, an attacking section with no direct target
// stages on its persistent HOLD position instead of walking into the objective centre.
if (_order in ["ATTACK","RAID"] && {isNull _target}) then {
    private _hold = _group getVariable ["ARTIC_battleHoldPos",[]];
    if (_hold isNotEqualTo []) then {_pos = +_hold; _radius = 40;};
};
private _sectionRef = _group getVariable ["ARTIC_sectionReferencePos",[]];
if (_sectionRef isEqualTo []) then {
    private _guide = _group getVariable ["ARTIC_guide",[]];
    _sectionRef = if (_guide isNotEqualTo []) then {+(_guide select 0)} else {getPosATL _leader};
};
private _distanceToOrder = if (_pos isEqualTo []) then {0} else {_sectionRef distance2D _pos};

// v0.3.22: once the platoon has armed this section at tactical release, it may execute on
// the platoon's shared intelligence. A section that has not yet seen the enemy itself uses
// the freshest live shared contact, so FIX / manoeuvre plays start at release instead of
// waiting for a new UAS report or a local sighting (0.3.21: ~2 min 48 s idle after release).
// Applied after the contact drill, so it never triggers a LINE / develop-fire reaction.
if (isNull _target && {_group getVariable ["ARTIC_tacticalExecutionArmed",false]} && {_order in ["FIX","ATTACK","RAID","SUPPORT","BLOCK"]}) then {
    private _bestT = -1;
    {
        _x params ["_o","_p","_t"];
        if ([_o] call ARTIC_fnc_isCombatEffectiveTarget && {(time - _t) < 300} && {_t > _bestT}) then {_bestT = _t; _target = _o;};
    } forEach (_group getVariable ["ARTIC_sharedContacts",[]]);
    if (!isNull _target) then {_group setVariable ["ARTIC_targetSource","SHARED:ARMED",false];};
};

switch (_order) do {
    case "RESERVE": {
        if (_pos isNotEqualTo [] && {_distanceToOrder > (_radius max 75)}) then {
            [_group,_pos] call ARTIC_fnc_setSectionDestination;
        } else {
            _group setBehaviourStrong "AWARE";
            _group setCombatMode "YELLOW";
        };
    };

    case "BLOCK": {
        // v0.3.30 envelopment isolation element. Deploy to the BLOCK position (progress is
        // published so the platoon READY_CHECK can see the section closing), then run the
        // BLOCK play: fire line facing the objective and its withdrawal lanes. BLOCK is only
        // READY once that fire line is occupied (0.3.27-0.3.29: ready on arrival, no positions).
        private _deploy = _group getVariable ["ARTIC_battleDeploymentPos",_pos];
        private _dDeploy = if (_deploy isEqualTo []) then {0} else {_sectionRef distance2D _deploy};
        if (_dDeploy > 35) then {
            [_group,_deploy] call ARTIC_fnc_setSectionDestination;
            if ((_group getVariable ["ARTIC_blockState",""]) isNotEqualTo "DEPLOY") then {_group setVariable ["ARTIC_blockState","DEPLOY",true];};
            if (_group getVariable ["ARTIC_blockReady",false]) then {_group setVariable ["ARTIC_blockReady",false,true];};
            private _best = _group getVariable ["ARTIC_blockDeployBest",1e9];
            if (_dDeploy < (_best - 5)) then {
                _group setVariable ["ARTIC_blockDeployBest",_dDeploy,false];
                [_group,"ARTIC_blockProgressAt"] call ARTIC_fnc_markDeployProgress;
            };
        } else {
            _group setVariable ["ARTIC_blockDeployBest",1e9,false];
            private _taskNow = _group getVariable ["ARTIC_sectionTaskId",""];
            private _mayRun = (_group getVariable ["ARTIC_tacticalExecutionArmed",false])
                && {time > (_group getVariable ["ARTIC_blockRestUntil",0])}
                && {_taskNow isEqualTo "" || {(_group getVariable ["ARTIC_blockDoneTaskId",""]) isNotEqualTo _taskNow}};
            if (_mayRun) then {
                _group setVariable ["ARTIC_contactAction","EXECUTE",true];
                [ARTIC_fnc_executeBlockingAction,[_group,_target],"BLOCK"] call _startPlay;
            } else {
                _group setBehaviourStrong (["AWARE","COMBAT"] select _inContact);
                _group setCombatMode (["YELLOW","RED"] select _inContact);
            };
        };
    };

    case "SUPPORT": {
        if (!isNull _target) then {
            _group setVariable ["ARTIC_contactAction","EXECUTE",true];
            [ARTIC_fnc_executeFixingAction,[_group,_target],"FIX"] call _startPlay;
        } else {
            if (_pos isNotEqualTo []) then {[_group,_pos] call ARTIC_fnc_setSectionDestination;};
        };
    };


    case "FIX": {
        // v0.3.22: the FIX section occupies its SBF as part of deployment; it needs a
        // validated SBF, not a live target (fire is held until the trigger).
        private _bfFix = _group getVariable ["ARTIC_battleFixPos",[]];
        // v0.3.30: a FIX task that has lifted / completed is not restarted under the same task
        private _fixTask = _group getVariable ["ARTIC_sectionTaskId",""];
        private _fixDone = time < (_group getVariable ["ARTIC_fixRestUntil",0])
            || {_fixTask isNotEqualTo "" && {(_group getVariable ["ARTIC_fixDoneTaskId",""]) isEqualTo _fixTask}};
        if (!_fixDone && {!isNull _target || {_bfFix isNotEqualTo [] && {_group getVariable ["ARTIC_battleFixValid",true]} && {_group getVariable ["ARTIC_tacticalExecutionArmed",false]}}}) then {
            _group setVariable ["ARTIC_contactAction","EXECUTE",true];
            [ARTIC_fnc_executeFixingAction,[_group,_target],"FIX"] call _startPlay;
        } else {
            if (_pos isNotEqualTo [] && {_distanceToOrder > (_radius max 100)}) then {[_group,_pos] call ARTIC_fnc_setSectionDestination;};
        };
    };

    case "ATTACK": {
        private _roleNow = _group getVariable ["ARTIC_schemeRole",""];
        private _battleFocus = _group getVariable ["ARTIC_battleFocus",[]];
        if (_roleNow in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT"] && {_group getVariable ["ARTIC_tacticalExecutionArmed",false]} && {!isNull _target || {_battleFocus isNotEqualTo []}}) then {
            _group setVariable ["ARTIC_contactAction","EXECUTE",true];
            [ARTIC_fnc_executePlatoonManoeuvre,[_group,_target],"MANOEUVRE"] call _startPlay;
        } else {
            if (!isNull _target) then {
                _group setVariable ["ARTIC_contactAction","EXECUTE",true];
                [ARTIC_fnc_executeSuppressAndFlank,[_group,_target]] call _startPlay;
            } else {
                if (_pos isNotEqualTo []) then {[_group,_pos] call ARTIC_fnc_setSectionDestination;};
            };
        };
    };

    case "RAID": {
        if (!isNull _target) then {
            _group setVariable ["ARTIC_contactAction","EXECUTE",true];
            [ARTIC_fnc_executeSuppressAndFlank,[_group,_target]] call _startPlay;
        } else {
            if (_pos isNotEqualTo []) then {[_group,_pos] call ARTIC_fnc_setSectionDestination;};
        };
    };

    case "DEFEND": {
        if (_pos isEqualTo []) exitWith {};
        // v0.3.15: occupy this section's battle position from the defence context
        private _bp = _group getVariable ["ARTIC_defenceBP",[]];
        if (_bp isNotEqualTo [] && {(_bp distance2D _pos) < 400}) then {
            _pos = +_bp;
            _distanceToOrder = _sectionRef distance2D _pos;
        };
        if (_distanceToOrder > (_radius max 80)) then {
            [_group,_pos] call ARTIC_fnc_setSectionDestination;
        } else {
            if !(_group getVariable ["ARTIC_battlePositionPrepared",false]) then {
                [ARTIC_fnc_executePrepareBattlePosition,[_group,_pos,objNull]] call _startPlay;
            } else {
                [ARTIC_fnc_executeDefendBattlePosition,[_group,_pos]] call _startPlay;
            };
        };
    };

    case "DELAY": {
        if (!isNull _target) then {
            [ARTIC_fnc_executeFightingWithdrawal,[_group,_target,_fallback]] call _startPlay;
        } else {
            if (_pos isNotEqualTo [] && {_distanceToOrder > _radius}) then {[_group,_pos] call ARTIC_fnc_setSectionDestination;};
        };
    };

    case "RECON": {
        if (!isNull _target) then {
            // Recon doctrine prioritises reporting and preserving the patrol.
            if ((_group getVariable ["ARTIC_doctrine","RECON"]) isEqualTo "RECON") then {
                private _away = (getPosATL _target) getDir (getPosATL _leader);
                private _dest = (getPosATL _leader) getPos [120,_away];
                [ARTIC_fnc_executeFightingWithdrawal,[_group,_target,_dest]] call _startPlay;
            };
        } else {
            if (_pos isNotEqualTo []) then {[_group,_pos] call ARTIC_fnc_setSectionDestination;};
        };
    };

    case "SCREEN": {
        if (!isNull _target) then {
            [_group,_target] call ARTIC_fnc_requestSupport;
        };
        if (_pos isNotEqualTo [] && {_distanceToOrder > _radius}) then {[_group,_pos] call ARTIC_fnc_setSectionDestination;};
    };
};
