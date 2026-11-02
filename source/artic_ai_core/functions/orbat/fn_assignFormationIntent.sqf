/*
    Recursively converts commander intent into formation/group intent.

    Converts strategic commander purpose into formation metadata and, for
    non-offensive missions, executable group orders.

    v0.3.21 keeps SEIZE purpose separate from section execution.  An offensive
    platoon receives persistent FIX / MANOEUVRE_LEFT / MANOEUVRE_RIGHT roles,
    but its direct groups remain in the safe PLATOON execution state until the
    platoon controller reaches tactical release.
*/
params [
    ["_node",createHashMap,[createHashMap]],
    ["_intent","DEFEND",[""]],
    ["_position",[],[[]]],
    ["_radius",150,[0]],
    ["_commanderId","",[""]],
    ["_fallback",[],[[]]],
    ["_schemeId","",[""]]
];
if ((count _node) isEqualTo 0) exitWith {};

_intent = toUpper _intent;
_node set ["intent",_intent];
_node set ["intentPos",_position];
_node set ["intentRadius",_radius];
// v0.3.21: strategic purpose is stored separately from executable section movement.
// Platoon COA/guide code may rotate/reposition freely without EAST_CMD installing a
// dormant ATTACK-to-objective order underneath the active guide.
_node set ["strategicIntent",_intent];
_node set ["strategicObjectivePos",+_position];
_node set ["strategicObjectiveId",_schemeId];

private _children = _node getOrDefault ["children",[]];
private _groups = _node getOrDefault ["groups",[]];
private _nodeId = _node getOrDefault ["id","FORMATION"];
private _sameScheme = (_schemeId isNotEqualTo "") && {(_node getOrDefault ["schemeId",""]) isEqualTo _schemeId};

// Direct groups at the lowest tactical formation receive a coordinated scheme.
if (_intent in ["SEIZE","ATTACK","CAPTURE","RAID"] && {(count _groups) >= 2}) then {
    private _lineGroups = [];
    private _smallSupport = [];
    private _fixCandidate = grpNull;
    private _bestFirepower = -1e9;
    {
        private _g = _x;
        private _caps = [_g] call ARTIC_fnc_scanGroupCapabilities;
        private _strength = _caps getOrDefault ["strength",0];
        if (_strength >= 4) then {
            _lineGroups pushBack _g;
            private _firepower =
                ((count (_caps getOrDefault ["mg",[]])) * 100) +
                ((count (_caps getOrDefault ["grenadier",[]])) * 35) +
                (_strength * 2);
            if (_firepower > _bestFirepower) then {
                _bestFirepower = _firepower;
                _fixCandidate = _g;
            };
        } else {
            _smallSupport pushBack _g;
        };
    } forEach _groups;

    if (!_sameScheme) then {
        // Clear stale scheme values first.
        {
            _x setVariable ["ARTIC_schemeRole","",true];
            _x setVariable ["ARTIC_attackAxis",0,true];
            _x setVariable ["ARTIC_axisLocked",false,true];
            _x setVariable ["ARTIC_schemeId",_schemeId,true];
            _x setVariable ["ARTIC_manoeuvrePhase","",true];
            _x setVariable ["ARTIC_fixReady",false,true];
            _x setVariable ["ARTIC_fixReadyUntil",0,true];
        } forEach _groups;

        if ((count _lineGroups) >= 2) then {
            private _fix = if (!isNull _fixCandidate) then {_fixCandidate} else {_lineGroups select 0};
            _fix setVariable ["ARTIC_schemeRole","FIX",true];
            _fix setVariable ["ARTIC_attackAxis",0,true];
            _fix setVariable ["ARTIC_axisLocked",true,true];

            private _man = _lineGroups - [_fix];
            if ((count _man) isEqualTo 1) then {
                (_man select 0) setVariable ["ARTIC_schemeRole","MANOEUVRE_AUTO",true];
                (_man select 0) setVariable ["ARTIC_attackAxis",0,true];
                (_man select 0) setVariable ["ARTIC_axisLocked",false,true];
            } else {
                (_man select 0) setVariable ["ARTIC_schemeRole","MANOEUVRE_LEFT",true];
                (_man select 0) setVariable ["ARTIC_attackAxis",-1,true];
                (_man select 0) setVariable ["ARTIC_axisLocked",true,true];

                (_man select 1) setVariable ["ARTIC_schemeRole","MANOEUVRE_RIGHT",true];
                (_man select 1) setVariable ["ARTIC_attackAxis",1,true];
                (_man select 1) setVariable ["ARTIC_axisLocked",true,true];

                if ((count _man) > 2) then {
                    {
                        _x setVariable ["ARTIC_schemeRole","RESERVE",true];
                        _x setVariable ["ARTIC_attackAxis",0,true];
                        _x setVariable ["ARTIC_axisLocked",true,true];
                    } forEach (_man select [2]);
                };
            };
        } else {
            if ((count _lineGroups) isEqualTo 1) then {
                (_lineGroups select 0) setVariable ["ARTIC_schemeRole","MANOEUVRE_AUTO",true];
                (_lineGroups select 0) setVariable ["ARTIC_attackAxis",0,true];
            };
        };

        {
            _x setVariable ["ARTIC_schemeRole","RESERVE_SUPPORT",true];
            _x setVariable ["ARTIC_attackAxis",0,true];
            _x setVariable ["ARTIC_axisLocked",true,true];
            _x setVariable ["ARTIC_schemeId",_schemeId,true];
        } forEach _smallSupport;

        _node set ["schemeId",_schemeId];

        private _summary = _groups apply {
            format ["%1=%2",groupId _x,_x getVariable ["ARTIC_schemeRole","UNASSIGNED"]]
        };
        [format ["Scheme of manoeuvre %1: %2",_schemeId,_summary joinString ", "],_nodeId] call ARTIC_fnc_debug;
    };

    // v0.3.21: publish strategic purpose and scheme roles, but DO NOT install
    // executable FIX/ATTACK orders yet.  Those orders are armed by the platoon
    // controller only when the selected COA reaches tactical release.  This removes
    // the dormant "ATTACK the Eden objective" fallback that could wake up if guide
    // freshness/locality briefly changed during a reposition.
    {
        private _g = _x;
        _g setVariable ["ARTIC_strategicIntent",_intent,true];
        _g setVariable ["ARTIC_strategicObjectivePos",+_position,true];
        _g setVariable ["ARTIC_strategicObjectiveId",_schemeId,true];
        _g setVariable ["ARTIC_orderCommander",_commanderId,true];
        _g setVariable ["ARTIC_orderIssuedAt",time,true];
        _g setVariable ["ARTIC_enabled",true,true];

        // Safe pre-release execution state.  No objective position is present in the
        // executable slot, so a planner/guide handover cannot fall through to OBJ_1.
        _g setVariable ["ARTIC_executionOrderType","PLATOON",true];
        _g setVariable ["ARTIC_executionOrderPos",[],true];
        _g setVariable ["ARTIC_executionOrderRadius",_radius,true];
        _g setVariable ["ARTIC_executionFallback",+_fallback,true];
        _g setVariable ["ARTIC_orderType","PLATOON",true];
        _g setVariable ["ARTIC_orderPos",[],true];
        _g setVariable ["ARTIC_orderRadius",_radius,true];
        _g setVariable ["ARTIC_orderFallback",+_fallback,true];
        _g setVariable ["ARTIC_tacticalExecutionArmed",false,true];

        if (local _g) then {
            [_g] call ARTIC_fnc_clearGroupWaypoints;
            _g enableAttack false;
            _g setVariable ["ARTIC_autoAttackDisabledByARTIC",true,false];
        };
    } forEach _groups;
} else {
    // Non-attack missions retain the previous deterministic behaviour.
    {
        private _g = _x;
        private _gIntent = if (_g getVariable ["ARTIC_forcedReserve",false]) then {"RESERVE"} else {
            // A lone section has no platoon COA layer to arm it later, so retain a
            // direct executable attack while preserving SEIZE as its strategic purpose.
            if (_intent in ["SEIZE","CAPTURE"]) then {"ATTACK"} else {_intent}
        };
        _g setVariable ["ARTIC_schemeRole",_gIntent,true];
        _g setVariable ["ARTIC_attackAxis",0,true];
        _g setVariable ["ARTIC_axisLocked",false,true];
        _g setVariable ["ARTIC_strategicIntent",_intent,true];
        _g setVariable ["ARTIC_strategicObjectivePos",+_position,true];
        _g setVariable ["ARTIC_strategicObjectiveId",_schemeId,true];
        [_g,_gIntent,_position,_radius,_commanderId,_fallback] call ARTIC_fnc_setGroupOrder;
    } forEach _groups;
};

if (_children isEqualTo []) exitWith {};

private _count = count _children;
{
    private _childIntent = _intent;

    switch (_intent) do {
        case "SEIZE";
        case "CAPTURE";
        case "ATTACK": {
            if (_count >= 3 && {_forEachIndex isEqualTo (_count - 1)}) then {
                _childIntent = "RESERVE";
            } else {
                if (_count >= 2 && {_forEachIndex isEqualTo 1}) then {_childIntent = "SUPPORT";};
            };
        };
        case "DEFEND": {
            if (_count >= 3 && {_forEachIndex isEqualTo (_count - 1)}) then {_childIntent = "RESERVE";};
        };
        case "DELAY": {
            if (_count >= 3 && {_forEachIndex isEqualTo (_count - 1)}) then {_childIntent = "RESERVE";};
        };
        case "RECON": {
            _childIntent = if (_forEachIndex isEqualTo 0) then {"RECON"} else {"RESERVE"};
        };
        case "RAID": {
            _childIntent = if (_forEachIndex isEqualTo 0) then {"ATTACK"} else {"SUPPORT"};
        };
        case "SCREEN": {
            _childIntent = if (_forEachIndex < (_count - 1)) then {"RECON"} else {"RESERVE"};
        };
    };

    [_x,_childIntent,_position,_radius,_commanderId,_fallback,_schemeId] call ARTIC_fnc_assignFormationIntent;
} forEach _children;
