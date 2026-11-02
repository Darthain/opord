/*
    ARTIC v0.3.27 - set/update a persistent section guide destination.
    A materially new destination opens a short formation-change window so changes happen
    at control points rather than every local terrain-classifier tick.
*/
params [["_group",grpNull,[grpNull]],["_destination",[],[[]]]];
if (isNull _group || {_destination isEqualTo []}) exitWith {false};
private _old = _group getVariable ["ARTIC_sectionDestination",[]];
private _changed = _old isEqualTo [] || {((_old select 0) distance2D _destination) > 28};
_group setVariable ["ARTIC_sectionDestination",[+_destination,time],false];
if (missionNamespace getVariable ["ARTIC_debugMarkers",false]) then {
    _group setVariable ["ARTIC_debugSectionDestination",+_destination,true];
};
if (_changed) then {
    _group setVariable ["ARTIC_guidePath",[],false];
    _group setVariable ["ARTIC_guidePathRequested",-1,false];
    if (missionNamespace getVariable ["ARTIC_debugMarkers",false]) then {
        _group setVariable ["ARTIC_guidePathDebug",[],true];
    };
    _group setVariable ["ARTIC_formationChangeWindowUntil",time + 7,false];
    _group setVariable ["ARTIC_formErrorS",0,false];
    _group setVariable ["ARTIC_guideHalted",false,false];
    _group setVariable ["ARTIC_guideHaltReason","",false];
    _group setVariable ["ARTIC_guideLeashMode","NORMAL",false];

    // A COA/route retask invalidates every cached per-soldier stop/aim state. Merely
    // changing the guide destination used to leave the commander in a sticky doStop
    // state until several other conditions happened to change. The next individual
    // tick now issues a fresh doMove from the new guide geometry.
    {
        if (local _x && {!isPlayer _x}) then {
            _x setVariable ["ARTIC_formLastTarget",[],false];
            _x setVariable ["ARTIC_formLastAim",[],false];
            _x setVariable ["ARTIC_formSettled",false,false];
            _x setVariable ["ARTIC_formStopped",false,false];
            _x setVariable ["ARTIC_formCatchUp",false,false];
            _x setVariable ["ARTIC_unitTaskLastIssue",-1000,false];
            _x setVariable ["ARTIC_speedApplied",-99,false];
            _x setVariable ["ARTIC_commandedMoveTarget",[],false];
            _x setVariable ["ARTIC_ctrlLastReassert",-1000,false];
            _x setVariable ["ARTIC_ctrlWatchPos",getPosATL _x,false];
            _x setVariable ["ARTIC_ctrlLastProgressAt",time,false];
        };
    } forEach units _group;
};
true
