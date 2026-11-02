/*
    ARTIC - place concealment (v0.2.1, checked against POOK Camonets and GRAD Trenches).

    POOK: the placeable 2-man / 3-man nets are the dropped-item objects
    pook_ITEMcamonet_small_<east|west>_drop<N> and pook_ITEMcamonet_med_..._drop<N>.
    (pook_camonet_small_east appears in Pook's units[] list but has no class, so the
    v0.2.0 adapter never placed anything.) "east"/"west" are Pook's net styles, not
    sides: EAST style is used for OPFOR/independent, WEST style for BLUFOR.
    These are item holders, so players can pick them up like any dropped net.

    Sizes:
      "SMALL"    2-man net             (pairs position, OP)
      "MEDIUM"   3-man net             (team position)
      "SPOTTER"  spotter/OP net        (observation post, sniper pair)
      "VEH_MED" / "VEH_TANK" / "VEH_TRUCK"   vehicle nets
      "TERRAIN"  GRAD Trenches terrain camouflage on an existing trench (_trench)

    Arguments: 0 pos ATL, 1 dir, 2 side, 3 size, 4 trench object (for "TERRAIN")
    Returns: created object, the trench for "TERRAIN", or objNull
*/
params [
    ["_position", [], [[]]],
    ["_direction", 0, [0]],
    ["_side", east, [sideUnknown]],
    ["_size", "SMALL", [""]],
    ["_trench", objNull, [objNull]]
];
private _kind = toUpper _size;

if (_kind isEqualTo "TERRAIN") exitWith {
    if (isNull _trench || {isNil "grad_trenches_functions_fnc_applyCamouflageAttribute"}) exitWith {objNull};
    // GRAD attaches this terrain's own bush/grass objects to the trench (server only).
    private _objs = getArray (configFile >> "CfgWorldsTextures" >> worldName >> "camouflageObjects");
    if (_objs isEqualTo []) exitWith {objNull};
    if (isServer) then {
        [_trench, 1] call grad_trenches_functions_fnc_applyCamouflageAttribute;
    } else {
        [_trench, 1] remoteExecCall ["grad_trenches_functions_fnc_applyCamouflageAttribute", 2];
    };
    _trench
};

if (_position isEqualTo []) exitWith {objNull};

private _style = ["east", "west"] select (_side isEqualTo west);
private _pattern = call ARTIC_fnc_getCamoPattern;
private _base = switch (_kind) do {
    case "MEDIUM": {format ["pook_ITEMcamonet_med_%1_drop", _style]};
    case "SPOTTER": {format ["pook_camonet_spotternet_%1", _style]};
    case "VEH_MED": {format ["pook_camonet_vehmed_%1", _style]};
    case "VEH_TANK": {format ["pook_camonet_vehtank_%1", _style]};
    case "VEH_TRUCK": {format ["pook_camonet_vehtruck_%1", _style]};
    default {format ["pook_ITEMcamonet_small_%1_drop", _style]};
};

// Prefer the terrain pattern, fall back to the base pattern.
private _class = _base + _pattern;
if !(isClass (configFile >> "CfgVehicles" >> _class)) then {_class = _base;};
if !(isClass (configFile >> "CfgVehicles" >> _class)) exitWith {objNull};

private _obj = createVehicle [_class, [0, 0, 0], [], 0, "CAN_COLLIDE"];
_obj setDir _direction;
_obj setPosATL [_position select 0, _position select 1, 0];
_obj setVectorUp surfaceNormal _position;
_obj setVariable ["ARTIC_engineeringObject", true, true];
_obj setVariable ["ARTIC_ownerSide", _side, true];
_obj
