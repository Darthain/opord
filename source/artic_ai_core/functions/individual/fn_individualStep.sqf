/*
    ARTIC individual executor - v0.3.19.

    Priority order:
      1. Existing short local reaction
      2. Immediate danger / exposed reload response
      3. FORMATION or FIRETEAM guide owner
      4. Static/suppression parent task

    Spatial movement is guide-owned. The retired majority-centroid regroup system
    and live element-centre governor are not used.
*/
params [["_unit",objNull,[objNull]]];
// v0.3.6: downed / ACE-unconscious / mounted soldiers get no individual orders.
if (isNull _unit || {!local _unit} || {isPlayer _unit} || {!([_unit] call ARTIC_fnc_isFit)}) exitWith {};

private _task = _unit getVariable ["ARTIC_unitTask",[]];
if (_task isEqualTo []) exitWith {};
_task params ["_type","_position","_target","_until","_tolerance"];
// v0.3.9: idle tasks (FORMATION / FOLLOW / STATIC) are refreshed in place instead of
// being cleared every 20 s, which used to wipe active reactions and briefly hand the
// soldier back to vanilla combat behaviour.
if (time > _until && {_unit getVariable ["ARTIC_idleTask",false]}) then {
    _until = time + 20;
    _task set [3,_until];
    _unit setVariable ["ARTIC_unitTask",_task,false];
};
if (time > _until) exitWith {[_unit,true] call ARTIC_fnc_clearUnitTask;};

private _group = group _unit;
// v0.3.16: initialise stable fireteam membership only. Live majority-cluster anchors are
// retired from movement ownership; the section/fireteam guide hierarchy is authoritative.
[_group] call ARTIC_fnc_initFireteams;
_unit disableAI "AUTOCOMBAT";
private _last = _unit getVariable ["ARTIC_unitTaskLastIssue",-1000];
private _reissue = (time - _last) > 2.5;

// ---------------------------------------------------------------------------
// Active local reaction. v0.3.13 makes cover/reload a blocking state: no parent
// formation or tactical move can overwrite it until LOS is actually broken or the
// reaction times out.
// ---------------------------------------------------------------------------
private _reaction = _unit getVariable ["ARTIC_reactionState",[]];
if (_reaction isNotEqualTo [] && {time <= (_reaction select 3)}) exitWith {
    _unit setVariable ["ARTIC_speedApplied",-99,false];
    _reaction params ["_rType","_rPos","_rThreat","_rUntil"];
    private _rLast = _unit getVariable ["ARTIC_reactionLastIssue",-1000];
    private _rReissue = (time - _rLast) > 1.0;
    private _atCover = _rPos isEqualTo [] || {_unit distance2D _rPos < 3.5};

    if (!_atCover) then {
        if (_rType isEqualTo "RELOAD_COVER") then {_unit enableReload false;};
        if (_rReissue) then {
            _unit setUnitPosWeak "MIDDLE";
            _unit forceSpeed 5;
            _unit doMove _rPos;
            _unit setVariable ["ARTIC_reactionLastIssue",time,false];
        };
    } else {
        // Re-check threat-relative LOS at the supposed cover point. If it does not
        // actually protect the soldier, search again rather than reloading in the open.
        ([_unit,_rThreat,450] call ARTIC_fnc_assessExposure) params ["_rExposure","_rLos","_rShooters","_rPrimary"];
        private _stillExposed = _rLos isNotEqualTo [] && {_rExposure >= 0.18 || {_rShooters > 0}};
        private _repositioned = false;
        if (_stillExposed && {time < (_rUntil - 1.5)}) then {
            private _newCoverResult = [_unit,_rLos,if (_rType isEqualTo "RELOAD_COVER") then {42} else {32},_rType isEqualTo "RELOAD_COVER"] call ARTIC_fnc_findThreatRelativeCover;
            _newCoverResult params ["_newCover","_newScore","_newBlocked","_newTotal"];
            if (_newCover isNotEqualTo [] && {_unit distance2D _newCover > 3.5}) then {
                _unit setVariable ["ARTIC_reactionState",[_rType,_newCover,if ([_rPrimary] call ARTIC_fnc_isCombatEffectiveTarget) then {_rPrimary} else {_rThreat},time + 9],false];
                _unit setVariable ["ARTIC_reactionLastIssue",time,false];
                if (_rType isEqualTo "RELOAD_COVER") then {_unit enableReload false;};
                _unit setUnitPosWeak "MIDDLE";
                _unit forceSpeed 5;
                _unit doMove _newCover;
                [format ["%1 cover failed LOS check; repositioning blocked=%2/%3 exposure=%4",name _unit,_newBlocked,_newTotal,(round (_rExposure*100))/100],groupId group _unit] call ARTIC_fnc_debug;
                _repositioned = true;
            };
        };

        if (!_repositioned && {_rReissue}) then {
            doStop _unit;
            _unit forceSpeed -1;
            _unit setUnitPosWeak "DOWN";
            if ([_rThreat] call ARTIC_fnc_isCombatEffectiveTarget) then {_unit doWatch _rThreat;};
            _unit setVariable ["ARTIC_reactionLastIssue",time,false];
        };
        if (!_repositioned && {_rType isEqualTo "RELOAD_COVER"}) then {
            // Only permit the reload when the selected position has broken hostile LOS.
            // If no useful cover exists, the fallback PINNED reaction handles survival;
            // we no longer deliberately start a standing/open reload.
            if (!_stillExposed) then {
                // Let the engine perform the actual magazine change once the soldier is
                // protected. Explicit `reload _unit` produced ReloadMagazine/muzzle errors
                // on some weapon classes in the v0.3.15 benchmark.
                _unit enableReload true;
            } else {
                _unit enableReload false;
            };
        };
    };
};

if (_reaction isNotEqualTo [] && {time > (_reaction select 3)}) then {
    _unit setVariable ["ARTIC_reactionState",[],false];
    _unit setVariable ["ARTIC_reactionLastIssue",-1000,false];
    _unit setVariable ["ARTIC_unitTaskLastIssue",-1000,false];
    _unit enableReload true;
    _unit forceSpeed -1;
};

// ---------------------------------------------------------------------------
// Immediate danger assessment BEFORE cohesion. This prevents a formation rule
// from freezing a soldier in an exposed position while he is actively shot at.
// ---------------------------------------------------------------------------
private _threat = _unit getVariable ["ARTIC_lastDangerSource",objNull];
if !([_threat] call ARTIC_fnc_isCombatEffectiveTarget) then {_threat = objNull;};
if (isNull _threat && {[_target] call ARTIC_fnc_isCombatEffectiveTarget}) then {_threat = _target;};
if (isNull _threat) then {
    private _shared = _group getVariable ["ARTIC_sharedContacts",[]];
    private _fresh = _shared select {
        ([_x select 0] call ARTIC_fnc_isCombatEffectiveTarget) && {(time - (_x select 2)) < 45}
    };
    if (_fresh isNotEqualTo []) then {
        private _near = _fresh apply {[_unit distance2D (_x select 1),_x select 0]};
        _near sort true;
        _threat = (_near select 0) select 1;
    };
};

private _suppression = (getSuppression _unit) max 0;
private _dangerPulse = time < (_unit getVariable ["ARTIC_dangerPulseUntil",0]);
// Threat-relative exposure: count how many live threats can actually see the soldier,
// and how many have fired on him recently. This prevents low engine suppression from
// making a man stand in the open while several enemies are engaging him.
([_unit,_threat,450] call ARTIC_fnc_assessExposure) params ["_exposureScore","_losThreats","_activeShooters","_primaryThreat"];
if ([_primaryThreat] call ARTIC_fnc_isCombatEffectiveTarget) then {_threat = _primaryThreat;};
private _exposed = _losThreats isNotEqualTo [];
private _heavilyEngaged = (_activeShooters >= 2) || {(count _losThreats) >= 3} || {_exposureScore >= 0.62} || {(time - (_unit getVariable ["ARTIC_lastHitAt",-1e6])) < 8};
private _ws = weaponState _unit;
private _ammoCount = if ((count _ws) >= 5) then {_ws select 4} else {30};
private _magReloadPhase = if ((count _ws) >= 7) then {_ws select 6} else {0};
private _needsReload = (_ammoCount <= 4) || {_magReloadPhase > 0};
private _reactionCooldown = _unit getVariable ["ARTIC_reactionCooldownUntil",0];

([_group] call ARTIC_fnc_getProfile) params ["_dName","_tName","_doctrine","_training"];
private _discipline = _training getOrDefault ["suppressionDiscipline",0.6];
private _coverTrigger = 0.16 + (0.16 * _discipline);
private _startedReaction = false;

// v0.3.6: while advancing (ASSAULT / MOVE) a soldier presses on through fire instead of
// breaking for cover on every danger pulse (Battle Book: hug the supporting fire,
// accept casualties to close with a suppressed enemy). He only takes cover when
// suppression passes a threshold set by doctrine riskTolerance and training
// suppressionDiscipline, or when he must reload while exposed. Otherwise he turns on
// the threat, fires and keeps moving.
// v0.3.14: FORMATION movement inside a play (tactical guide: HOLD / STAGE / FCL / ASSAULT
// legs) presses on like MOVE / ASSAULT. In 0.3.13 those soldiers broke for cover on every
// danger pulse, left their slots and stalled the section's guide.
private _pmOwn = _group getVariable ["ARTIC_platoonMove",[]];
private _marchAdvancing = _pmOwn isNotEqualTo [] && {(CBA_missionTime - (_pmOwn select 3)) < 30} && {!(_group getVariable ["ARTIC_platoonTacticalReleased",false])};
private _advancing = _type in ["ASSAULT","MOVE"] || {_type isEqualTo "FORMATION" && {(_group getVariable ["ARTIC_tacticalGuideActive",false]) || {_marchAdvancing}}};
private _risk = _doctrine getOrDefault ["riskTolerance",0.5];
private _pressOnLimit = (0.35 + (0.35 * _risk) + (0.2 * _discipline)) min 0.9;
if (_advancing && {!isNull _threat} && {!(_needsReload && {_exposed})} && {!_heavilyEngaged} && {_suppression < _pressOnLimit} && {_exposureScore < 0.5}) then {
    if (_dangerPulse && {time >= (_unit getVariable ["ARTIC_pressOnFireAt",0])}) then {
        _unit setVariable ["ARTIC_pressOnFireAt",time + 3,false];
        _unit doWatch _threat;
        _unit doTarget _threat;
        _unit setUnitPosWeak "MIDDLE";
    };
    _dangerPulse = false;
    _exposed = false;
};

// v0.3.6a: a soldier who must reload while a live enemy can see him always reacts,
// even with no recent fire near him and even inside the reaction cooldown. With no
// cover in reach he goes prone to reload rather than doing it standing in the open.
// v0.3.18: the section commander is part of the moving formation, not an independent
// anchor.  During a platoon-owned approach he may still react to a real hit, exposed
// reload or heavy engagement, but a distant FiredNear/danger pulse alone must not pull
// him out of the CMD slot and indirectly stop the section.
if (_marchAdvancing && {_unit isEqualTo leader _group} && {!_heavilyEngaged} && {!(_needsReload && {_exposed})} && {_suppression < (_pressOnLimit min 0.78)} && {_exposureScore < 0.58}) then {
    _dangerPulse = false;
    _exposed = false;
};

private _exposedReload = _needsReload && {_exposed};
if (_exposedReload && {(_unit getVariable ["ARTIC_reactionState",[]]) isEqualTo []}) then {
    _reactionCooldown = 0;
    _dangerPulse = true;
};

if (time >= _reactionCooldown && {!isNull _threat} && {_dangerPulse || {_heavilyEngaged} || {_exposed && {(_suppression >= _coverTrigger) || {_exposureScore >= 0.42}}}}) then {
    private _coverResult = [_unit,_losThreats,if (_needsReload) then {42} else {30},_needsReload] call ARTIC_fnc_findThreatRelativeCover;
    _coverResult params ["_cover","_coverScore","_blocked","_totalThreats"];
    if (_cover isEqualTo []) then {
        _cover = [getPosATL _unit,_threat,20,true,false] call ARTIC_fnc_findCoverPosition;
    };
    private _coverUseful = _cover isNotEqualTo [] && {_unit distance2D _cover > 2.0};

    if (_coverUseful) then {
        private _rType = if (_needsReload) then {"RELOAD_COVER"} else {"SEEK_COVER"};
        if (_rType isEqualTo "RELOAD_COVER" && {_magReloadPhase <= 0}) then {_unit enableReload false;};
        _unit setVariable ["ARTIC_reactionState",[_rType,_cover,_threat,time + 10],false];
        _unit setVariable ["ARTIC_reactionLastIssue",-1000,false];
        _unit setVariable ["ARTIC_reactionCooldownUntil",time + 7,false];
        [format ["%1 reaction=%2 exposure=%3 threats=%4 activeShooters=%5 blockedAtCover=%6/%7 suppression=%8 parent=%9",name _unit,_rType,(round (_exposureScore*100))/100,count _losThreats,_activeShooters,_blocked,_totalThreats,(round (_suppression*100))/100,_type],groupId _group] call ARTIC_fnc_debug;
        _unit forceSpeed 5;
        _unit doMove _cover;
        _startedReaction = true;
    } else {
        if (_exposedReload) then {
            // No LOS-breaking cover found: go prone/pinned and keep the reload inhibited.
            // A following tick may find new cover or the threat may lose LOS, at which
            // point the reload can safely resume.
            _unit enableReload false;
            _unit setVariable ["ARTIC_reactionState",["PINNED",getPosATL _unit,_threat,time + 4],false];
            _unit setVariable ["ARTIC_reactionLastIssue",-1000,false];
            _unit setVariable ["ARTIC_reactionCooldownUntil",time + 2,false];
            doStop _unit;
            _unit setUnitPosWeak "DOWN";
            _startedReaction = true;
        } else {
        if (_dangerPulse || {_suppression >= 0.55}) then {
            _unit setVariable ["ARTIC_reactionState",["PINNED",getPosATL _unit,_threat,time + 5],false];
            _unit setVariable ["ARTIC_reactionLastIssue",-1000,false];
            _unit setVariable ["ARTIC_reactionCooldownUntil",time + 7,false];
            doStop _unit;
            _unit setUnitPosWeak "DOWN";
            _startedReaction = true;
        };
        };
    };
};
if (_startedReaction) exitWith {_unit setVariable ["ARTIC_speedApplied",-99,false];};

// ---------------------------------------------------------------------------
// Explicit regroup override. This is created by moveElement when a formation
// fails to consolidate. It preserves the parent task and disappears once the
// section/fireteam has physically re-formed.
// ---------------------------------------------------------------------------
// v0.3.6: STATIC (idle hold for DEFEND/SUPPORT groups) keeps the danger reactions above
// but skips formation cohesion, so dispersed battle positions aren't pulled into a wedge.
if (_type isEqualTo "STATIC") exitWith {
    if (_reissue) then {
        if (_position isNotEqualTo [] && {_unit distance2D _position > (_tolerance max 4)}) then {
            _unit forceSpeed -1;
            _unit doMove _position;
        } else {
            doStop _unit;
            _unit forceSpeed -1;
            _unit setUnitPosWeak "MIDDLE";
        };
        _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
    };
};

// ---------------------------------------------------------------------------
// v0.3.9: FORMATION owner. The section formation controller (guide + role slots) owns
// this soldier's movement; only the reactions above can override it. The old cohesion
// governor below is bypassed completely, so exactly one system issues his orders.
// ---------------------------------------------------------------------------
if (_type isEqualTo "FORMATION") exitWith {
    // v0.3.11: rewritten to stop the back-and-forth "pacing" seen in the 0.3.10 test.
    private _raw = [_unit,_group,false] call ARTIC_fnc_formationSlotWorld;
    if (_raw isEqualTo []) then {
        // v0.3.20: never hand a missing ARTIC slot back to vanilla doFollow. Rebuild the
        // slot table immediately; if it is still unavailable, retain ARTIC ownership with
        // a small deterministic emergency position behind the section guide.
        [_group,_group getVariable ["ARTIC_formation","WEDGE"]] call ARTIC_fnc_assignFormationSlots;
        _raw = [_unit,_group,false] call ARTIC_fnc_formationSlotWorld;
        if (_raw isEqualTo []) then {
            private _gFallback = _group getVariable ["ARTIC_guide",[]];
            if (_gFallback isNotEqualTo []) then {
                private _members = (units _group) select {[_x] call ARTIC_fnc_isFit};
                private _idxFallback = (_members find _unit) max 0;
                _raw = (+(_gFallback select 0)) getPos [4 + 2 * _idxFallback,(_gFallback select 1) + 180];
                _raw set [2,0];
                private _lastSlotLog = _unit getVariable ["ARTIC_missingSlotLog",-1000];
                if ((time - _lastSlotLog) > 10) then {
                    [format ["UNITCTRL missing formation slot for %1; emergency guide slot retained",name _unit],groupId _group] call ARTIC_fnc_debug;
                    _unit setVariable ["ARTIC_missingSlotLog",time,false];
                };
            };
        };
    };
    if (_raw isEqualTo []) exitWith {};
    private _guide = _group getVariable ["ARTIC_guide",[]];
    private _form = _group getVariable ["ARTIC_formation","WEDGE"];
    private _vel = _group getVariable ["ARTIC_formVel",0];
    private _dir = if (_guide isNotEqualTo []) then {_guide select 1} else {getDir _unit};
    private _isCommander = (_unit isEqualTo leader _group) || {(_unit getVariable ["ARTIC_formRole",""]) isEqualTo "CMD"};
    private _repositionForAttack = _group getVariable ["ARTIC_repositionForAttack",false];

    // Aim a steady distance ahead of the slot, proportional to the formation's actual
    // speed (0.3.10 jumped between +4 m and 0 as the guide started and stopped).
    private _lead = (_vel * 4) min 8;
    // The commander rides just ahead of his CMD slot while the guide is moving. His slot
    // is intentionally close to the guide, so the old generic "ahead -> doStop" rule
    // repeatedly stopped him first and made the whole section appear leaderless.
    if (_isCommander && {_vel > 0.3}) then {_lead = (_lead max 6) min 10;};
    private _aimRaw = if (_lead > 0.5) then {_raw getPos [_lead,_dir]} else {+_raw};

    // Re-validate / re-target only when the aim has moved > 4 m; distances are measured
    // to the ACTUAL (validated) target, not the raw slot.
    private _lastAim = _unit getVariable ["ARTIC_formLastAim",[]];
    private _tgt = _unit getVariable ["ARTIC_formLastTarget",[]];
    private _newTarget = false;
    if (_tgt isEqualTo [] || {_lastAim isEqualTo []} || {(_lastAim distance2D _aimRaw) > 4}) then {
        private _v = [_unit,_group,true] call ARTIC_fnc_formationSlotWorld;
        if (_v isEqualTo []) then {_v = +_raw;};
        _tgt = if (_lead > 0.5) then {_v getPos [_lead,_dir]} else {_v};
        _unit setVariable ["ARTIC_formLastAim",_aimRaw,false];
        _unit setVariable ["ARTIC_formLastTarget",_tgt,false];
        _newTarget = true;
    };
    // v0.3.25: in a contact LINE each soldier moves to his assigned firing position from
    // cover (fn_assignFirePositions) instead of his raw slot.
    private _contactLine = _form isEqualTo "LINE" && {(time < (_group getVariable ["ARTIC_developUntil",0])) || {_group getVariable ["ARTIC_holdContactLine",false]}};
    private _fp = _unit getVariable ["ARTIC_firePos",[]];
    private _useFP = _contactLine && {_fp isNotEqualTo []} && {(time - (_fp select 3)) < 45};
    if (_useFP) then {
        private _fpPos = +(_fp select 0);
        if ((_tgt distance2D _fpPos) > 1.5) then {_newTarget = true;};
        _tgt = _fpPos;
        _unit setVariable ["ARTIC_formLastTarget",_tgt,false];
    };
    private _d = _unit distance2D _tgt;

    // Settled (halted formation): arrive within 2.5 m -> doStop once (so the engine can't
    // pull him back into its own formation) and leave him until he is > 6 m out.
    private _settled = _unit getVariable ["ARTIC_formSettled",false];
    if (_settled) then {
        if (_d > 6 || {_vel > 0.3}) then {_settled = false;};
    } else {
        if (_d < 2.5 && {_vel <= 0.3}) then {_settled = true;};
    };
    _unit setVariable ["ARTIC_formSettled",_settled,false];

    // Ahead of his target while the formation moves. v0.3.20 no longer uses doStop
    // here: doStop is sticky command state and was capable of outliving the moving slot.
    // During the long COA reposition we also tolerate extra longitudinal compression.
    private _rel = (((_tgt getDir _unit) - _dir) + 360) % 360;
    private _ahead = (!_isCommander) && {!_repositionForAttack} && {_vel > 0.3} && {_d < 10} && {_rel < 60 || {_rel > 300}};

    // speed: formation pace; run to catch up beyond 12 m until back within 6 m
    private _catch = _unit getVariable ["ARTIC_formCatchUp",false];
    if (_catch) then {if (_d < 6) then {_catch = false;};} else {
        if (_d > 12) then {_catch = true;};
    };
    _unit setVariable ["ARTIC_formCatchUp",_catch,false];
    private _spd = if (_catch) then {5} else {
        if (_vel <= 0.3) then {-1} else {if (_ahead) then {0.5} else {_vel + 0.8}}
    };
    if ((_unit getVariable ["ARTIC_speedApplied",-99]) isNotEqualTo _spd) then {
        _unit forceSpeed _spd;
        _unit setVariable ["ARTIC_speedApplied",_spd,false];
    };

    private _stopped = _unit getVariable ["ARTIC_formStopped",false];
    if (_settled) then {
        if (!_stopped) then {
            doStop _unit;
            _unit setVariable ["ARTIC_formStopped",true,false];
        };
    } else {
        // While the guide is moving, reassert the ARTIC slot regardless of unitReady.
        // expectedDestination exposes a competing vanilla destination immediately.
        private _exp = expectedDestination _unit;
        private _expPos = _exp param [0,[]];
        private _expValid = _expPos isEqualType [] && {(count _expPos) >= 2} && {((abs (_expPos select 0)) + (abs (_expPos select 1))) > 1};
        private _expDelta = if (_expValid) then {_expPos distance2D _tgt} else {1e9};
        private _refreshMove = (time - _last) > 1.5;
        private _needMove = _d > 2.5 && {
            _newTarget || {_stopped} || {_refreshMove} || {_expDelta > 10} || {(currentCommand _unit) isEqualTo ""}
        };
        if (_needMove && {!_ahead}) then {
            _unit doMove _tgt;
            _unit setVariable ["ARTIC_commandedMoveTarget",+_tgt,false];
            _unit setVariable ["ARTIC_formStopped",false,false];
            _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
        } else {
            if (_ahead) then {
                // Slow in place without replacing the movement command with STOP.
                _unit setVariable ["ARTIC_formStopped",false,false];
            };
        };
    };

    // stance / observation
    private _developing = (time < (_group getVariable ["ARTIC_developUntil",0])) || {_group getVariable ["ARTIC_holdContactLine",false]};   // v0.3.25: contact LINE also while holding
    if (_form isEqualTo "LINE" && {_developing}) then {
        // v0.3.25: stance from the firing position once there (prone behind low cover,
        // kneeling behind waist-high cover, standing at corners); crouched while moving
        _unit setUnitPosWeak (if (_useFP && {_d < 3}) then {_fp select 1} else {"MIDDLE"});
        // aiming is left to the section fire control while it runs
        if (_reissue && {!(_group getVariable ["ARTIC_reactFireActive",false])}) then {
            private _gT = [_group] call ARTIC_fnc_findTarget;
            if ([_gT] call ARTIC_fnc_isCombatEffectiveTarget) then {_unit doWatch _gT;};
            _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
        };
    } else {
        if (_settled && {_form in ["DIAMOND","BOX","BOX_DIAMOND"]} && {_guide isNotEqualTo []} && {_reissue}) then {
            // all-round: each man watches outward from the centre of the formation
            _unit doWatch (_raw getPos [60,(_guide select 0) getDir _raw]);
            _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
        };
    };

    // Tactical-guide movement keeps the section coherent without making it passive.
    // Explicitly acquire the parent target when visible while RED combat mode handles
    // actual weapon employment. AUTOCOMBAT remains disabled so the soldier cannot invent
    // a contradictory private manoeuvre.
    if ((_group getVariable ["ARTIC_tacticalGuideActive",false]) && {[_target] call ARTIC_fnc_isCombatEffectiveTarget} && {_reissue}) then {
        if ([getPosATL _unit,_target] call ARTIC_fnc_hasLineOfSight) then {
            _unit doTarget _target;
            _unit doWatch _target;
            _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
        };
    };
};

// ---------------------------------------------------------------------------
// v0.3.17: FIRETEAM owner. Tactical split manoeuvres use one explicit fireteam
// guide per team. No live-centroid cohesion governor and no retired regroup override.
// ---------------------------------------------------------------------------
if (_type isEqualTo "FIRETEAM") exitWith {
    private _anchor = _unit getVariable ["ARTIC_fireteamMoveAnchor",[]];
    if (_anchor isEqualTo []) exitWith {};
    private _dir = _unit getVariable ["ARTIC_fireteamMoveDir",getDir _unit];
    private _line = _unit getVariable ["ARTIC_fireteamMoveLine",false];
    private _slot = [_unit,_anchor,_dir,1,_line] call ARTIC_fnc_fireteamSlotWorld;
    if (_slot isEqualTo []) exitWith {};
    private _d = _unit distance2D _slot;
    private _settled = _d < 3;
    if (_settled) then {
        if (_reissue || {!(_unit getVariable ["ARTIC_formStopped",false])}) then {
            doStop _unit;
            _unit forceSpeed -1;
            _unit setVariable ["ARTIC_formStopped",true,false];
            _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
        };
    } else {
        private _spd = if (_d > 14) then {5} else {3};
        if ((_unit getVariable ["ARTIC_speedApplied",-99]) isNotEqualTo _spd) then {
            _unit forceSpeed _spd;
            _unit setVariable ["ARTIC_speedApplied",_spd,false];
        };
        if (_reissue || {_unit getVariable ["ARTIC_formStopped",false]} || {unitReady _unit}) then {
            _unit setUnitPosWeak "MIDDLE";
            _unit doMove _slot;
            _unit setVariable ["ARTIC_commandedMoveTarget",+_slot,false];
            _unit setVariable ["ARTIC_formStopped",false,false];
            _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
        };
    };
    if ([_target] call ARTIC_fnc_isCombatEffectiveTarget && {_reissue} && {[getPosATL _unit,_target] call ARTIC_fnc_hasLineOfSight}) then {
        _unit doTarget _target;
        _unit doWatch _target;
    };
};

// ---------------------------------------------------------------------------
// Parent task execution.
// ---------------------------------------------------------------------------
switch (_type) do {
    case "HOLD": {
        if (_reissue) then {
            doStop _unit;
            _unit forceSpeed -1;
            _unit setUnitPosWeak "MIDDLE";
            if ([_target] call ARTIC_fnc_isCombatEffectiveTarget) then {_unit doWatch _target;};
            _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
        };
    };
    case "SUPPRESS": {
        if (_reissue) then {
            doStop _unit;
            _unit forceSpeed -1;
            _unit setUnitPosWeak "MIDDLE";
            if ([_target] call ARTIC_fnc_isCombatEffectiveTarget) then {
                _unit doTarget _target;
                _unit doSuppressiveFire _target;
            };
            _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
        };
    };
    case "MOVE": {
        if (_position isEqualTo []) exitWith {};
        if ((_unit distance2D _position) <= _tolerance) then {
            doStop _unit;
            _unit forceSpeed -1;
        } else {
            if (_reissue) then {
                _unit setUnitPosWeak "MIDDLE";
                _unit forceSpeed _effSpeed;
                _unit doMove _position;
                _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
            };
        };
    };
    case "ASSAULT": {
        if (_reissue) then {
            _unit forceSpeed _effSpeed;
            _unit setUnitPos "AUTO";
            if ([_target] call ARTIC_fnc_isCombatEffectiveTarget) then {
                _unit doTarget _target;
                private _assaultPoint = _unit getVariable ["ARTIC_assaultPoint",[]];
                if (_assaultPoint isEqualTo []) then {
                    _assaultPoint = if (_position isNotEqualTo []) then {+_position} else {
                        private _p = getPosATL _target;
                        _p getPos [12 + random 8,random 360]
                    };
                    _unit setVariable ["ARTIC_assaultPoint",_assaultPoint,false];
                };
                _unit doMove _assaultPoint;
            } else {
                doStop _unit;
            };
            _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
        };
    };
    case "FOLLOW": {
        private _ldr = leader _group;
        if (!isNull _ldr && {_ldr isNotEqualTo _unit} && {_reissue}) then {
            _unit forceSpeed _effSpeed;
            _unit doFollow _ldr;
            _unit setVariable ["ARTIC_unitTaskLastIssue",time,false];
        };
    };
};
