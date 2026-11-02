params [
    ["_group",grpNull,[grpNull]],
    ["_target",objNull,[objNull]],
    ["_flankScore",0.5,[0]],
    ["_supportLOS",true,[true]]
];
if (isNull _group || {isNull _target}) exitWith {false};
if (time < (_group getVariable ["ARTIC_supportCooldownUntil",0])) exitWith {false};

([_group] call ARTIC_fnc_getProfile) params ["_dName","_tName","_doctrine","_training"];
private _bias = _doctrine getOrDefault ["supportBias",0.5];
private _skill = _training getOrDefault ["supportIntegration",0.5];
private _groupPos = getPosATL leader _group;
private _targetPos = getPosATL _target;
private _elev = (getTerrainHeightASL _targetPos) - (getTerrainHeightASL _groupPos);

// Danger-close is commander/ARTIC-force aware rather than only checking the
// requesting section. This prevents one section calling HE onto another section.
private _cmdId = _group getVariable ["ARTIC_commanderId",""];
private _friendlyUnits = allUnits select {
    alive _x &&
    {(side (group _x)) isEqualTo (side _group)} &&
    {(group _x) getVariable ["ARTIC_enabled",false]} &&
    {_cmdId isEqualTo "" || {((group _x) getVariable ["ARTIC_commanderId",""]) isEqualTo _cmdId}}
};
private _nearestFriendly = 1e9;
{
    _nearestFriendly = _nearestFriendly min (_x distance2D _targetPos);
} forEach _friendlyUnits;

private _hardProblem = (_elev > 7) || {!_supportLOS} || {_flankScore < 0.42};
private _chance = ((_bias * 0.55) + (_skill * 0.45)) min 0.96;
private _use = _hardProblem || {random 1 < _chance};
if (!_use) exitWith {false};

private _dangerClose = _nearestFriendly < 125;
private _type = ["HE","SMOKE"] select _dangerClose;
private _reason = if (_dangerClose) then {
    "DANGER_CLOSE"
} else {
    if (_elev > 7) then {"UPHILL"} else {
        if (!_supportLOS) then {"NO_SBF_LOS"} else {
            if (_flankScore < 0.42) then {"POOR_FLANK_ROUTE"} else {"DOCTRINAL_SUPPORT"}
        }
    }
};

private _ok = [_group,_target,_type,_targetPos] call ARTIC_fnc_requestSupport;
if (_ok) then {
    _group setVariable ["ARTIC_supportCooldownUntil",time + 90,true];
    [format ["Requested %1 support (%2, elev=%3m flank=%4 nearestFriendly=%5m)",_type,_reason,round _elev,(round (_flankScore * 100)) / 100,round _nearestFriendly],groupId _group] call ARTIC_fnc_debug;
};
_ok
