params [
    ["_logic", objNull, [objNull]],
    ["_className", "", [""]]
];

if (isNull _logic || {_className isEqualTo ""}) exitWith { [] };

(synchronizedObjects _logic) select { _x isKindOf _className }
