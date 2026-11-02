params [["_value", 1, [0,""]]];

if (_value isEqualType "") exitWith {
    private _s = toUpper _value;
    if (_s in ["WEST","BLUFOR"]) exitWith {west};
    if (_s in ["EAST","OPFOR"]) exitWith {east};
    if (_s in ["GUER","GUERRILA","GUERRILLA","INDEPENDENT","INDEP"]) exitWith {resistance};
    if (_s in ["CIV","CIVILIAN"]) exitWith {civilian};
    east
};

switch (_value) do {
    case 0: {west};
    case 1: {east};
    case 2: {resistance};
    case 3: {civilian};
    default {east};
};
