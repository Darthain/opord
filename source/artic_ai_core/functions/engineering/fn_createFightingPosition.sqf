params [
    ["_position",[],[[]]],
    ["_direction",0,[0]],
    ["_size","SHORT",[""]],
    ["_side",east,[sideUnknown]]
];
if (_position isEqualTo []) exitWith {objNull};

private _class = "Land_BagFence_Long_F";
private _useGrad = isClass (configFile >> "CfgVehicles" >> "GRAD_envelope_short");
if (_useGrad) then {
    _class = switch (toUpper _size) do {
        case "LONG": {"GRAD_envelope_long"};
        case "BIG": {"ACE_envelope_big"};
        case "VEHICLE": {"GRAD_envelope_vehicle"};
        default {"GRAD_envelope_short"};
    };
};

private _obj = createVehicle [_class,_position,[],0,"CAN_COLLIDE"];
_obj setDir _direction;
_obj setPosATL [_position select 0,_position select 1,0];
_obj setVariable ["ARTIC_engineeringObject",true,true];
_obj setVariable ["ARTIC_ownerSide",_side,true];

if (_useGrad) then {
    _obj setVariable ["ace_trenches_progress",1,true];
    _obj setObjectTextureGlobal [0,surfaceTexture _position];
};

_obj
