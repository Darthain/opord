/*
    ARTIC v0.3.16 - section formation templates in REAL METRES.

    Previous builds stored small unitless coordinates and then globally scaled the
    entire template until the closest pair met a requested separation. That could turn
    COLUMN into a 60-90 m snake and placed CMD / MEDIC / 2IC far behind the section.

    v0.3.16 keeps every normal section inside a bounded combat envelope. The formation
    controller applies only a small terrain/training scale (ARTIC_formSpacing, normally
    0.65-1.05). "Protected" means a role is not deliberately used as point man; it does
    NOT mean the role is allowed to trail the section.

    Each slot: [role, lateral_metres, forward_metres]
      +forward = direction of travel; +lateral = right.
*/
params [["_name","WEDGE",[""]]];

switch (toUpper _name) do {
    case "COLUMN": {[
        ["SCOUT",0,8], ["RIFLE",0,4], ["CMD",0,1], ["MG",0,-3],
        ["GREN",0,-7], ["MEDIC",0,-9], ["AT",0,-12], ["SECOND",0,-14],
        ["RIFLE",0,-17], ["RIFLE",0,-20]
    ]};
    case "VEE": {[
        ["SCOUT",-9,6], ["GREN",9,6], ["MG",-6,2], ["RIFLE",6,2],
        ["CMD",0,1], ["RIFLE",-4,-3], ["AT",4,-3], ["MEDIC",-3,-6],
        ["SECOND",3,-6], ["RIFLE",0,-10]
    ]};
    case "CROWS_FOOT": {[
        ["MG",-9,7], ["RIFLE",-4,5], ["MG",9,7], ["RIFLE",4,5],
        ["CMD",0,1], ["MEDIC",-3,-4], ["SECOND",3,-4], ["GREN",0,-7],
        ["AT",-7,-3], ["RIFLE",7,-3]
    ]};
    case "LINE": {[
        ["MG",-18,0], ["RIFLE",-12,0], ["GREN",-6,0], ["SCOUT",0,0],
        ["AT",6,0], ["RIFLE",12,0], ["RIFLE",18,0], ["CMD",0,-4],
        ["MEDIC",-5,-7], ["SECOND",5,-7]
    ]};
    case "DIAMOND": {[
        ["SCOUT",0,9], ["MG",-9,0], ["GREN",9,0], ["SECOND",0,-9],
        ["CMD",0,1], ["MEDIC",-3,-3], ["AT",-5,5], ["RIFLE",5,5],
        ["RIFLE",5,-5], ["RIFLE",-5,-5]
    ]};
    case "BOX": {[
        ["SCOUT",-8,8], ["MG",8,8], ["RIFLE",-8,-8], ["SECOND",8,-8],
        ["CMD",0,1], ["MEDIC",0,-4], ["GREN",-9,0], ["AT",9,0],
        ["RIFLE",0,-9], ["RIFLE",0,9]
    ]};
    case "BOX_DIAMOND": {[
        ["SCOUT",-8,7], ["MG",-14,0], ["RIFLE",-4,0], ["RIFLE",-8,-7],
        ["GREN",8,7], ["RIFLE",4,0], ["AT",14,0], ["SECOND",8,-7],
        ["CMD",0,1], ["MEDIC",0,-5]
    ]};
    case "ECHELON_LEFT": {[
        ["SCOUT",2,7], ["MG",-3,4], ["GREN",-7,1], ["RIFLE",5,4],
        ["CMD",0,0], ["MEDIC",-2,-4], ["AT",-11,-2], ["SECOND",3,-5],
        ["RIFLE",-15,-6], ["RIFLE",-19,-10]
    ]};
    case "ECHELON_RIGHT": {[
        ["SCOUT",-2,7], ["MG",3,4], ["GREN",7,1], ["RIFLE",-5,4],
        ["CMD",0,0], ["MEDIC",2,-4], ["AT",11,-2], ["SECOND",-3,-5],
        ["RIFLE",15,-6], ["RIFLE",19,-10]
    ]};
    default {[
        // WEDGE: command group stays in the forward-middle of the body.
        ["SCOUT",0,9], ["MG",-7,3], ["GREN",7,3], ["CMD",0,1],
        ["RIFLE",-11,-3], ["AT",11,-3], ["MEDIC",-4,-6], ["SECOND",4,-6],
        ["RIFLE",-14,-10], ["RIFLE",14,-10]
    ]};
};
