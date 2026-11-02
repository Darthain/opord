/*
    Network-safe fireteam task schema V1.
    Index map is documented in docs/FSM_ARCHITECTURE.md.
*/
params [
    ["_type","HOLD",[""]],
    ["_destination",[],[[]]],
    ["_corridor",[],[[]]],
    ["_threatPos",[],[[]]],
    ["_target",objNull,[objNull]],
    ["_facing",-1,[0]],
    ["_sector",[],[[]]],
    ["_frontage",20,[0]],
    ["_spacing",8,[0]],
    ["_tolerance",12,[0]],
    ["_deadline",-1,[0]],
    ["_syncKey","",[""]],
    ["_rules",[],[[]]],
    ["_issuer","SECTION",[""]],
    ["_priority",50,[0]],
    ["_meta",[],[[]]]
];
private _id = format ["FT_%1_%2_%3",toUpper _type,round (time * 10),floor random 10000];
[
    "ARTIC_FT_TASK_V1",_id,toUpper _type,time,_issuer,(_priority max 0) min 100,
    +_destination,+_corridor,+_threatPos,_target,_facing,+_sector,_frontage max 0,
    _spacing max 1,_tolerance max 2,_deadline,_syncKey,+_rules,+_meta
]
