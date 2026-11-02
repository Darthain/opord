params [
    ["_requester",grpNull,[grpNull]],
    ["_mission","RECON",[""]],
    ["_position",[],[[]]],
    ["_target",objNull,[objNull]],
    ["_commanderId","",[""]]
];
if (_position isEqualTo [] && {!isNull _target}) then {_position = getPosATL _target;};
if (_position isEqualTo []) exitWith {false};
if (_commanderId isEqualTo "" && {!isNull _requester}) then {_commanderId = _requester getVariable ["ARTIC_commanderId",""];};
if (_commanderId isEqualTo "") exitWith {false};

private _payload = [toUpper _mission,_position,_target,_requester,_commanderId,time];
if (isServer) then {
    ARTIC_UASRequests pushBack _payload;
} else {
    ["ARTIC_UAS_REQUEST",_payload] call CBA_fnc_serverEvent;
};
[format ["UAS request %1 at %2",toUpper _mission,mapGridPosition _position],_commanderId] call ARTIC_fnc_debug;
true
