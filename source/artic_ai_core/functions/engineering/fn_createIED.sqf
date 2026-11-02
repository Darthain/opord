/*
    ARTIC optional IEDD adapter.
    Creates IEDD devices on the server and registers them in ARTIC's obstacle registry.
    IEDD is not a hard dependency; this function safely returns objNull when absent.
*/
params [
    ["_pos",[],[[]]],
    ["_type","RANDOM",[""]],
    ["_opt",createHashMap,[createHashMap]],
    ["_side",east,[sideUnknown]],
    ["_owner",grpNull,[grpNull]]
];
if (_pos isEqualTo []) exitWith {objNull};
if !(isClass (configFile >> "CfgPatches" >> "iedd_ied")) exitWith {objNull};

if (!isServer) exitWith {
    ["ARTIC_createIED",_this] call CBA_fnc_serverEvent;
    objNull
};

private _types = [
    "iedd_ied_CanisterPlastic",
    "iedd_ied_CanisterFuel",
    "iedd_ied_Cardboard",
    "iedd_ied_Cinder",
    "iedd_ied_Metal",
    "iedd_ied_Barrel"
];
if ((toUpper _type) isEqualTo "RANDOM") then {_type = selectRandom _types;};
if !(isClass (configFile >> "CfgVehicles" >> _type)) exitWith {objNull};

private _fake = _opt getOrDefault ["fake",false];
private _obj = objNull;

if (_fake) then {
    // IEDD's fake objects are ordinary props matching the visible container, not
    // non-existent "*_Fake" IED classes.
    private _fakeClass = switch (_type) do {
        case "iedd_ied_CanisterPlastic": {"Land_CanisterPlastic_F"};
        case "iedd_ied_CanisterFuel": {"Land_CanisterFuel_F"};
        case "iedd_ied_Cardboard": {"Land_PaperBox_01_small_ransacked_brown_F"};
        case "iedd_ied_Cinder": {"Land_CinderBlock_01_F"};
        case "iedd_ied_Metal": {"Land_GarbageBarrel_01_F"};
        default {"Land_BarrelEmpty_F"};
    };
    _obj = createVehicle [_fakeClass,_pos,[],0,"CAN_COLLIDE"];
} else {
    _obj = createVehicle [_type,_pos,[],0,"CAN_COLLIDE"];
    _obj setVariable ["iedd_ied_variation",6,true];
    _obj setVariable ["iedd_ied_dud",(_opt getOrDefault ["dud",0.1]) max 0 min 1,true];
    _obj setVariable ["iedd_ied_size",round ((_opt getOrDefault ["size",5]) max 0 min 5),true];
    _obj setVariable ["iedd_ied_timer",[0,1] select (_opt getOrDefault ["timer",false]),true];
    _obj setVariable ["iedd_ied_timerValue",round ((_opt getOrDefault ["timerSec",30]) max 1),true];
    _obj setVariable ["iedd_ied_distance",round ((_opt getOrDefault ["distance",6]) max 0),true];
    _obj setVariable ["iedd_ied_randomTimer",0,true];
    _obj setVariable ["iedd_ied_fake",0,true];
    _obj setVariable ["iedd_ied_decals",false,true];
    if (_type isEqualTo "iedd_ied_CanisterFuel") then {
        _obj setVariable ["iedd_ied_color",selectRandom ["green","Blue","red","White"],true];
    };
};

if (isNull _obj) exitWith {objNull};
_obj setVariable ["ARTIC_engineeringObject",true,true];
_obj setVariable ["ARTIC_ownerSide",_side,true];
[_obj,["IED","IED_DECOY"] select _fake,"OBSTACLE",_side,_owner] call ARTIC_fnc_registerObstacle;
_obj
