/*
    ARTIC v0.3.24 - platoon response to section contact calls (server, every platoon tick).

    For every new ARTIC_contactCall from a section in this platoon:
      1. ACKNOWLEDGE and share: the contact goes straight into every other section's
         shared tactical picture (the commander's next intel cycle confirms it).
      2. RESPOND:
         - attack under way (a play running / < 90 s since release) and the call is away
           from the objective (> 80 m: unexpected contact):
               FIX shifts fire onto it if it is established in its SBF and can see it
               (ARTIC_fireRedirect); otherwise the nearest other section that can see it
               supports by fire (ARTIC_assistCall).
         - not yet attacking (approach / hold): REACT TO CONTACT - HASTY ATTACK when the
           platoon is attacking anyway (SEIZE/ATTACK/CAPTURE/RAID), the doctrine is not
           RECON, the call is > 150 m from the objective and friendly:enemy >= 2:1:
               the calling section (already in contact) becomes FIX / base of fire, the
               other sections MANOEUVRE_LEFT / MANOEUVRE_RIGHT by where they stand relative
               to it (extras RESERVE), and the battle context re-centres on the contact.
           otherwise the platoon holds and the contact is reported to the commander.
      3. END the hasty attack when nothing live is left within 80 m of the contact for 60 s,
         or after 5 min: original roles and the objective return.
*/
params [
    ["_node",createHashMap,[createHashMap]],
    ["_commander",createHashMap,[createHashMap]],
    ["_groups",[],[[]]],
    ["_intent","",[""]],
    ["_objective",[],[[]]]
];
if (!isServer || {_groups isEqualTo []}) exitWith {};
private _nodeId = _node getOrDefault ["id","FORMATION"];
private _now = CBA_missionTime;
private _handled = _node getOrDefault ["contactCallsHandled",createHashMap];
private _pp = _node getOrDefault ["platoonPlan",createHashMap];
private _ppStatus = toUpper (_pp getOrDefault ["status",""]);
private _executing = (_ppStatus in ["ACTIVE","DEPLOY","READY_CHECK","EXECUTE","CONSOLIDATE"])
    || {((_groups findIf {(_x getVariable ["ARTIC_currentPlan",""]) isNotEqualTo ""}) > -1)}
    || {(time - (_node getOrDefault ["executionStart",-1e6])) < 90};
private _ctx = _node getOrDefault ["battleContext",createHashMap];
private _focus = _ctx getOrDefault ["focus",_objective];
private _refOf = {params ["_g"]; _g getVariable ["ARTIC_sectionReferencePos",getPosATL leader _g]};
private _sees = {params ["_from","_pos"]; (([_from,[_pos],1] call ARTIC_fnc_battleSight) select 0) > 0};

// ---- end of a hasty attack ----------------------------------------------------------------
private _hasty = _node getOrDefault ["hastyFocus",[]];
if (_hasty isNotEqualTo []) then {
    private _liveNear = ((_commander getOrDefault ["contactReports",[]]) findIf {
        (_x select 0) isEqualType objNull && {[_x select 0] call ARTIC_fnc_isCombatEffectiveTarget} && {((_x select 1) distance2D _hasty) < 80}
    }) > -1;
    if (_liveNear) then {_node set ["hastyLastLive",time];};
    if ((time - (_node getOrDefault ["hastyLastLive",time])) > 60 || {time > (_node getOrDefault ["hastyUntil",0])}) then {
        if (!_executing) then {
            {
                _x params ["_g","_role"];
                if (!isNull _g) then {_g setVariable ["ARTIC_schemeRole",_role,true]; _g setVariable ["ARTIC_tacticalExecutionArmed",false,true];};
            } forEach (_node getOrDefault ["hastyRestore",[]]);
        } else {
            // A live PlatoonPlan owns roles now. Clearing stale hasty metadata is safe;
            // restoring pre-plan roles would violate plan immutability.
            [_node,_groups] call ARTIC_fnc_applyPlatoonPlan;
        };
        _node set ["hastyFocus",[]]; _node set ["hastyRestore",[]];
        [format ["Platoon %1: hasty attack complete; resuming the objective at %2",_nodeId,mapGridPosition _objective],_nodeId] call ARTIC_fnc_debug;
    };
};

{
    private _g = _x;
    private _call = _g getVariable ["ARTIC_contactCall",[]];
    if (_call isNotEqualTo []) then {
        _call params ["_t","_pos","_brg","_dist","_desc","_cnt","_obj","_gid"];
        if ((_handled getOrDefault [_gid,-1]) < _t && {(_now - _t) < 30}) then {
            _handled set [_gid,_t];

            // 1. share immediately
            {
                if (_x isNotEqualTo _g) then {
                    private _sc = +(_x getVariable ["ARTIC_sharedContacts",[]]);
                    if ((_sc findIf {(_x select 0) isEqualTo _obj}) < 0) then {
                        _sc pushBack [_obj,+_pos,time,_gid,_g getVariable ["ARTIC_formationId",""],0.9,"GROUND"];
                        _x setVariable ["ARTIC_sharedContacts",_sc,true];
                    };
                };
            } forEach _groups;

            // 2. respond
            private _response = "shared with the platoon";
            // v0.3.30 contact-aware replanning: a manoeuvre section engaged at close range while
            // it is still deploying / waiting for H-hour invalidates the plan. The platoon aborts
            // it (class CONTACT) and the replacement plan fixes that section where it stands.
            // A section already executing its manoeuvre (Stage 1 onward) fights through.
            private _roleC = _g getVariable ["ARTIC_schemeRole",""];
            private _ppId = _pp getOrDefault ["planId",""];
            // executing = H-hour received for this plan (the phase only reads STAGE1 once Stage 1 is reached)
            private _manExec = (_ppId isNotEqualTo "" && {(_g getVariable ["ARTIC_hHourPlanId",""]) isEqualTo _ppId})
                || {(_g getVariable ["ARTIC_manoeuvrePhase",""]) in ["STAGE1","STAGE2","ASSAULT_READY","ASSAULT","COMPLETE"]};
            private _contactReplan = _executing
                && {missionNamespace getVariable ["ARTIC_contactAwareReplan",true]}
                && {missionNamespace getVariable ["ARTIC_useFSMHierarchy",true]}
                && {_ppId isNotEqualTo ""}
                && {_ppStatus in ["ACTIVE","DEPLOY","READY_CHECK"]}
                && {!(_pp getOrDefault ["hHourIssued",false])}
                // v0.3.30.2: FIX / BLOCK still marching to their position (no play yet) count too;
                // 0.3.30.1 waved BLOCK's 76 m contact through as "on the objective; plan continues".
                && {_roleC in ["MANOEUVRE_LEFT","MANOEUVRE_RIGHT","MANOEUVRE_AUTO"]
                    || {_roleC in ["FIX","BLOCK"] && {(_g getVariable ["ARTIC_currentPlan",""]) isEqualTo ""}}}
                && {!(_g getVariable ["ARTIC_committedInPlace",false])}
                && {!_manExec}
                && {_dist < (missionNamespace getVariable ["ARTIC_contactReplanDistance",150])}
                && {(time - (_pp getOrDefault ["createdAt",time])) > 12}
                && {!(_pp getOrDefault ["contactReplanIssued",false])};
            if (_contactReplan) then {
                _pp set ["contactReplanIssued",true];
                _node set ["platoonPlan",_pp];
                [_node,_gid,_g getVariable ["ARTIC_sectionTaskId",""],_roleC,"CONTACT_ON_DEPLOYMENT"] call ARTIC_fnc_recordPlatoonFailure;
                _response = format ["CONTACT REPLAN: %1 (%2) engaged at %3 m before H-hour; plan %4 aborted, replanning with %1 fixing in place",_gid,_roleC,round _dist,_ppId];
            } else {
            if (_executing) then {
                if ((_pos distance2D _focus) > 80) then {
                    // v0.3.30: FIX or a READY/engaged BLOCK element can shift fire onto the call
                    private _fixIdx = _groups findIf {
                        _x isNotEqualTo _g && {
                            ((_x getVariable ["ARTIC_schemeRole",""]) isEqualTo "FIX" && {(_x getVariable ["ARTIC_fixState",""]) in ["READY_HOLD_FIRE","SUPPRESS"]})
                            || {(_x getVariable ["ARTIC_schemeRole",""]) isEqualTo "BLOCK" && {(_x getVariable ["ARTIC_blockState",""]) in ["READY_HOLD_FIRE","ENGAGE"]}}
                        } && {[[_x] call _refOf,_pos] call _sees}
                    };
                    private _fix = if (_fixIdx > -1) then {_groups select _fixIdx} else {grpNull};
                    if (!isNull _fix) then {
                        _fix setVariable ["ARTIC_fireRedirect",[_obj,+_pos,_now,_gid],true];
                        _response = format ["%1 (%2) shifting fire onto it",groupId _fix,_fix getVariable ["ARTIC_schemeRole",""]];
                    } else {
                        // v0.3.30: only a section that is not running a play can act on an assist
                        // call (groupStep reads it between plays); others were never told before.
                        private _others = [(_groups - [_g]) select {(_x getVariable ["ARTIC_currentPlan",""]) isEqualTo ""},[],{([_x] call _refOf) distance2D _pos},"ASCEND"] call BIS_fnc_sortBy;
                        private _hIdx = _others findIf {[[_x] call _refOf,_pos] call _sees};
                        if (_hIdx > -1) then {
                            (_others select _hIdx) setVariable ["ARTIC_assistCall",[_obj,+_pos,_now,_gid],true];
                            _response = format ["%1 supporting by fire",groupId (_others select _hIdx)];
                        } else {
                            _response = "no other section can see it; plan continues";
                        };
                    };
                } else {
                    _response = "on the objective; plan continues";
                };
            } else {
                private _fit = 0;
                {_fit = _fit + ({[_x] call ARTIC_fnc_isFit} count units _x);} forEach _groups;
                private _ratio = _fit / (_cnt max 1);
                private _doctrine = toUpper (_g getVariable ["ARTIC_doctrine","CONVENTIONAL"]);
                private _canHasty = (missionNamespace getVariable ["ARTIC_hastyAttack",true])
                    && {_intent in ["SEIZE","ATTACK","CAPTURE","RAID"]}
                    && {_doctrine isNotEqualTo "RECON"}
                    && {(count _groups) >= 2}
                    && {_ratio >= 2}
                    && {(_pos distance2D _objective) > 150}
                    && {(_node getOrDefault ["hastyFocus",[]]) isEqualTo []};
                if (_canHasty) then {
                    // roles: caller fixes; others left / right of it as seen facing the enemy
                    private _restore = _groups apply {[_x,_x getVariable ["ARTIC_schemeRole",""]]};
                    private _repRef = [_g] call _refOf;
                    private _toEnemy = _repRef getDir _pos;
                    _g setVariable ["ARTIC_schemeRole","FIX",true];
                    private _left = grpNull; private _right = grpNull;
                    {
                        if (_x isNotEqualTo _g) then {
                            private _rel = ((((_repRef getDir ([_x] call _refOf)) - _toEnemy) + 540) % 360) - 180;
                            private _role = switch (true) do {
                                case (_rel < 0 && {isNull _left}): {_left = _x; "MANOEUVRE_LEFT"};
                                case (_rel >= 0 && {isNull _right}): {_right = _x; "MANOEUVRE_RIGHT"};
                                case (isNull _left): {_left = _x; "MANOEUVRE_LEFT"};
                                case (isNull _right): {_right = _x; "MANOEUVRE_RIGHT"};
                                default {"RESERVE"};
                            };
                            _x setVariable ["ARTIC_schemeRole",_role,true];
                        };
                        _x setVariable ["ARTIC_tacticalExecutionArmed",false,true];
                    } forEach _groups;
                    _node set ["hastyFocus",+_pos];
                    _node set ["hastyUntil",time + 300];
                    _node set ["hastyLastLive",time];
                    _node set ["hastyRestore",_restore];
                    _response = format ["HASTY ATTACK: %1 fixes%2%3",groupId _g,
                        if (isNull _left) then {""} else {format [", %1 left",groupId _left]},
                        if (isNull _right) then {""} else {format [", %1 right",groupId _right]}];
                } else {
                    _response = format ["holding; reported to commander (ratio %1:1)",(round (_ratio * 10)) / 10];
                };
            };
            };
            [format ["Platoon %1: contact call from %2 (%3, bearing %4, %5 m) acknowledged -> %6",_nodeId,_gid,_desc,_brg,_dist,_response],_nodeId] call ARTIC_fnc_debug;
        };
    };
} forEach _groups;
_node set ["contactCallsHandled",_handled];
