params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith { ["CONVENTIONAL","REGULAR",["CONVENTIONAL"] call ARTIC_fnc_getDoctrine,["REGULAR"] call ARTIC_fnc_getTraining] };

private _doctrineName = toUpper (_group getVariable ["ARTIC_doctrine","CONVENTIONAL"]);
private _trainingName = toUpper (_group getVariable ["ARTIC_training","REGULAR"]);
[
    _doctrineName,
    _trainingName,
    [_doctrineName] call ARTIC_fnc_getDoctrine,
    [_trainingName] call ARTIC_fnc_getTraining
]
