/*
    Doctrine is WHAT a force prefers to do.
    Training is HOW WELL it can execute those preferences.

    Action weights are not hard permissions. 0.0 means a doctrine will almost
    never choose the action autonomously; explicit mission orders can still
    require it.
*/

private _actions = {
    params ["_pairs"];
    createHashMapFromArray _pairs
};

ARTIC_Doctrines = createHashMapFromArray [
    ["CONVENTIONAL", createHashMapFromArray [
        ["supportFraction", 0.35],
        ["riskTolerance", 0.55],
        ["preserveMedic", true],
        ["preserveAT", true],
        ["retainReserve", true],
        ["contactResponse", "SUPPRESS_ASSESS"],
        ["withdrawStyle", "BOUNDING"],
        ["constructionBias", 0.65],
        ["deceptionBias", 0.45],
        ["supportBias", 0.80],
        ["uasReconBias",0.72],["uasStrikeBias",0.72],
        ["actions", [[
            ["SUPPRESS",0.95],["SUPPORT_BY_FIRE",0.95],["FLANK",0.90],
            ["DOUBLE_ENVELOP",0.70],["BOUND_ADVANCE",0.90],["ASSAULT",0.78],
            ["AMBUSH",0.55],["RAID",0.45],["RECON_ATTACK",0.50],
            ["BYPASS",0.50],["FIX",0.90],["COUNTERATTACK",0.78],
            ["FIGHTING_WITHDRAWAL",0.80],["BREAK_CONTACT",0.55],
            ["PREPARE_BATTLE_POSITION",0.80],["CALL_FIRES",0.90],
            ["DECEPTION",0.50],["ENGINEERING",0.75]
        ]] call _actions]
    ]],

    ["INSURGENT", createHashMapFromArray [
        ["supportFraction", 0.30],
        ["riskTolerance", 0.50],
        ["preserveMedic", true],
        ["preserveAT", false],
        ["retainReserve", true],
        ["contactResponse", "VIOLENT_SHORT_ACTION"],
        ["withdrawStyle", "DISPERSE_DELAY"],
        ["constructionBias", 0.55],
        ["deceptionBias", 0.90],
        ["supportBias", 0.45],
        ["uasReconBias",0.62],["uasStrikeBias",0.88],
        ["actions", [[
            ["SUPPRESS",0.72],["SUPPORT_BY_FIRE",0.72],["FLANK",0.72],
            ["DOUBLE_ENVELOP",0.30],["BOUND_ADVANCE",0.40],["ASSAULT",0.55],
            ["AMBUSH",1.00],["RAID",0.95],["RECON_ATTACK",0.80],
            ["BYPASS",0.90],["FIX",0.70],["COUNTERATTACK",0.42],
            ["FIGHTING_WITHDRAWAL",0.78],["BREAK_CONTACT",1.00],
            ["PREPARE_BATTLE_POSITION",0.65],["CALL_FIRES",0.45],
            ["DECEPTION",0.95],["ENGINEERING",0.90]
        ]] call _actions]
    ]],

    ["MILITIA", createHashMapFromArray [
        ["supportFraction", 0.28],
        ["riskTolerance", 0.68],
        ["preserveMedic", false],
        ["preserveAT", false],
        ["retainReserve", false],
        ["contactResponse", "MASS_FIRE"],
        ["withdrawStyle", "BREAK_CONTACT"],
        ["constructionBias", 0.50],
        ["deceptionBias", 0.35],
        ["supportBias", 0.25],
        ["uasReconBias",0.28],["uasStrikeBias",0.52],
        ["actions", [[
            ["SUPPRESS",0.72],["SUPPORT_BY_FIRE",0.50],["FLANK",0.45],
            ["DOUBLE_ENVELOP",0.15],["BOUND_ADVANCE",0.25],["ASSAULT",0.82],
            ["AMBUSH",0.78],["RAID",0.72],["RECON_ATTACK",0.25],
            ["BYPASS",0.20],["FIX",0.45],["COUNTERATTACK",0.72],
            ["FIGHTING_WITHDRAWAL",0.30],["BREAK_CONTACT",0.72],
            ["PREPARE_BATTLE_POSITION",0.62],["CALL_FIRES",0.20],
            ["DECEPTION",0.30],["ENGINEERING",0.55]
        ]] call _actions]
    ]],

    ["RECON", createHashMapFromArray [
        ["supportFraction", 0.28],
        ["riskTolerance", 0.25],
        ["preserveMedic", true],
        ["preserveAT", true],
        ["retainReserve", false],
        ["contactResponse", "REPORT_AVOID"],
        ["withdrawStyle", "BOUNDING"],
        ["constructionBias", 0.25],
        ["deceptionBias", 0.70],
        ["supportBias", 0.92],
        ["uasReconBias",1.00],["uasStrikeBias",0.52],
        ["actions", [[
            ["SUPPRESS",0.45],["SUPPORT_BY_FIRE",0.62],["FLANK",0.45],
            ["DOUBLE_ENVELOP",0.05],["BOUND_ADVANCE",0.72],["ASSAULT",0.15],
            ["AMBUSH",0.80],["RAID",0.70],["RECON_ATTACK",1.00],
            ["BYPASS",1.00],["FIX",0.75],["COUNTERATTACK",0.12],
            ["FIGHTING_WITHDRAWAL",0.95],["BREAK_CONTACT",1.00],
            ["PREPARE_BATTLE_POSITION",0.25],["CALL_FIRES",1.00],
            ["DECEPTION",0.75],["ENGINEERING",0.32]
        ]] call _actions]
    ]],

    ["POSITIONAL", createHashMapFromArray [
        ["supportFraction", 0.42],
        ["riskTolerance", 0.38],
        ["preserveMedic", true],
        ["preserveAT", true],
        ["retainReserve", true],
        ["contactResponse", "HOLD_SHAPE_COUNTER"],
        ["withdrawStyle", "PREPARED_DELAY"],
        ["constructionBias", 1.00],
        ["deceptionBias", 0.88],
        ["supportBias", 0.90],
        ["uasReconBias",0.75],["uasStrikeBias",0.90],
        ["actions", [[
            ["SUPPRESS",0.98],["SUPPORT_BY_FIRE",0.98],["FLANK",0.45],
            ["DOUBLE_ENVELOP",0.20],["BOUND_ADVANCE",0.35],["ASSAULT",0.35],
            ["AMBUSH",0.72],["RAID",0.18],["RECON_ATTACK",0.30],
            ["BYPASS",0.20],["FIX",1.00],["COUNTERATTACK",1.00],
            ["FIGHTING_WITHDRAWAL",0.92],["BREAK_CONTACT",0.50],
            ["PREPARE_BATTLE_POSITION",1.00],["CALL_FIRES",0.95],
            ["DECEPTION",0.95],["ENGINEERING",1.00]
        ]] call _actions]
    ]],

    ["SPECIAL_FORCES", createHashMapFromArray [
        ["supportFraction", 0.30],
        ["riskTolerance", 0.32],
        ["preserveMedic", true],
        ["preserveAT", true],
        ["retainReserve", true],
        ["contactResponse", "MISSION_FIRST"],
        ["withdrawStyle", "BOUNDING"],
        ["constructionBias", 0.35],
        ["deceptionBias", 0.92],
        ["supportBias", 0.92],
        ["uasReconBias",0.95],["uasStrikeBias",0.85],
        ["actions", [[
            ["SUPPRESS",0.90],["SUPPORT_BY_FIRE",0.90],["FLANK",1.00],
            ["DOUBLE_ENVELOP",0.62],["BOUND_ADVANCE",0.95],["ASSAULT",0.82],
            ["AMBUSH",0.95],["RAID",1.00],["RECON_ATTACK",0.88],
            ["BYPASS",1.00],["FIX",0.88],["COUNTERATTACK",0.45],
            ["FIGHTING_WITHDRAWAL",0.95],["BREAK_CONTACT",0.90],
            ["PREPARE_BATTLE_POSITION",0.45],["CALL_FIRES",1.00],
            ["DECEPTION",1.00],["ENGINEERING",0.78]
        ]] call _actions]
    ]]
];

ARTIC_TrainingProfiles = createHashMapFromArray [
    ["POOR", createHashMapFromArray [
        ["coordination",0.30],["decisionDelay",10],["maxElements",1],
        ["suppressionDiscipline",0.35],["specialistAssignment",0.25],
        ["boundDistance",35],["flankDistance",80],["supportIntegration",0.20],
        ["constructionSkill",0.40],["deceptionSkill",0.20],["replanSpeed",0.25],
        ["moraleResilience",0.55],["uasSkill",0.30]
    ]],
    ["REGULAR", createHashMapFromArray [
        ["coordination",0.58],["decisionDelay",6],["maxElements",2],
        ["suppressionDiscipline",0.60],["specialistAssignment",0.58],
        ["boundDistance",45],["flankDistance",110],["supportIntegration",0.52],
        ["constructionSkill",0.65],["deceptionSkill",0.48],["replanSpeed",0.52],
        ["moraleResilience",0.70],["uasSkill",0.58]
    ]],
    ["VETERAN", createHashMapFromArray [
        ["coordination",0.82],["decisionDelay",3.5],["maxElements",3],
        ["suppressionDiscipline",0.82],["specialistAssignment",0.86],
        ["boundDistance",55],["flankDistance",135],["supportIntegration",0.82],
        ["constructionSkill",0.82],["deceptionSkill",0.75],["replanSpeed",0.82],
        ["moraleResilience",0.84],["uasSkill",0.82]
    ]],
    ["ELITE", createHashMapFromArray [
        ["coordination",0.95],["decisionDelay",2],["maxElements",4],
        ["suppressionDiscipline",0.95],["specialistAssignment",0.97],
        ["boundDistance",60],["flankDistance",155],["supportIntegration",0.96],
        ["constructionSkill",0.92],["deceptionSkill",0.92],["replanSpeed",0.96],
        ["moraleResilience",0.93],["uasSkill",0.96]
    ]]
];
