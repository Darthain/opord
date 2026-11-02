/* Register the v0.3.29/v0.3.30 server-side FSM event bus. */
if (!isServer) exitWith {};
if (missionNamespace getVariable ["ARTIC_fsmEventsRegistered",false]) exitWith {};
missionNamespace setVariable ["ARTIC_fsmEventsRegistered",true];

["ARTIC_sectionReady", {
    params ["_cid","_nid","_gid","_planId","_taskId","_role","_phase","_stamp"];
    private _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
    if ((count _node) isEqualTo 0) exitWith {};
    private _plan = _node getOrDefault ["platoonPlan",createHashMap];
    if ((_plan getOrDefault ["planId",""]) isNotEqualTo _planId) exitWith {};
    private _expectedTask = (_plan getOrDefault ["sectionTasks",createHashMap]) getOrDefault [_gid,""];
    if (_expectedTask isNotEqualTo "" && {_expectedTask isNotEqualTo _taskId}) exitWith {
        [format ["FSM SECTION READY ignored stale task plan=%1 section=%2 reported=%3 expected=%4",_planId,_gid,_taskId,_expectedTask],_nid] call ARTIC_fnc_debug;
    };
    private _ready = +(_plan getOrDefault ["readySet",[]]);
    _ready pushBackUnique _gid;
    _plan set ["readySet",_ready];
    _node set ["platoonPlan",_plan];
    [format ["FSM SECTION READY plan=%1 section=%2 role=%3 task=%4 phase=%5",_planId,_gid,_role,_taskId,_phase],_nid] call ARTIC_fnc_debug;
}] call CBA_fnc_addEventHandler;

["ARTIC_sectionFailed", {
    params ["_cid","_nid","_gid","_planId","_taskId","_role","_reason","_stamp"];
    private _node = [_cid,_nid] call ARTIC_fnc_findFormationNode;
    if ((count _node) isEqualTo 0) exitWith {};
    private _plan = _node getOrDefault ["platoonPlan",createHashMap];
    if ((_plan getOrDefault ["planId",""]) isNotEqualTo _planId) exitWith {};
    // v0.3.30: classify, store and abort every play of this plan (ARTIC_fnc_recordPlatoonFailure)
    [_node,_gid,_taskId,_role,_reason] call ARTIC_fnc_recordPlatoonFailure;
}] call CBA_fnc_addEventHandler;
