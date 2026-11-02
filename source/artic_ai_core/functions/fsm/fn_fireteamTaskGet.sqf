params [["_task",[],[[]]],["_field","",[""]],["_default",nil]];
private _idx = createHashMapFromArray [
 ["SCHEMA",0],["ID",1],["TYPE",2],["ISSUEDAT",3],["ISSUER",4],["PRIORITY",5],
 ["DESTINATION",6],["CORRIDOR",7],["THREATPOS",8],["TARGET",9],["FACING",10],
 ["SECTOR",11],["FRONTAGE",12],["SPACING",13],["TOLERANCE",14],["DEADLINE",15],
 ["SYNCKEY",16],["RULES",17],["META",18]
];
private _i = _idx getOrDefault [toUpper _field,-1];
if (_i < 0 || {_i >= count _task}) exitWith {_default};
_task select _i
