params [
    ["_side",east,[sideUnknown]],
    ["_payload","AP",[""]],
    ["_thermal",false,[true]]
];

private _prefix = switch (_side) do {
    case west: {"B_"};
    case east: {"O_"};
    case resistance: {"I_"};
    default {""};
};
if (_prefix isEqualTo "") exitWith {""};

private _kind = toUpper _payload;
if !(_kind in ["AP","AT"]) exitWith {""};
private _suffix = format ["Crocus_%1%2",_kind,if (_thermal) then {"_TI"} else {""}];
private _class = _prefix + _suffix;
if !(isClass (configFile >> "CfgVehicles" >> _class)) exitWith {""};
_class
