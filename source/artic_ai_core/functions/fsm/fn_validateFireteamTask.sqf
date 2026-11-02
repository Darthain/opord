params [["_task",[],[[]]]];
private _errors = [];
if ((count _task) < 19) then {_errors pushBack "TASK_TOO_SHORT";};
if ((_task param [0,""]) isNotEqualTo "ARTIC_FT_TASK_V1") then {_errors pushBack "BAD_SCHEMA";};
private _type = toUpper (_task param [2,""]);
private _valid = ["MOVE","FOLLOW","BOUND","DEPLOY","OBSERVE","SUPPRESS","ENGAGE","ASSAULT","BLOCK","HOLD","WITHDRAW","REORGANISE"];
if !(_type in _valid) then {_errors pushBack format ["BAD_TYPE_%1",_type];};
if (_type in ["MOVE","FOLLOW","BOUND","DEPLOY","ASSAULT","BLOCK","WITHDRAW"] && {(_task param [6,[]]) isEqualTo []}) then {_errors pushBack "DESTINATION_REQUIRED";};
[(count _errors) isEqualTo 0,_errors]
