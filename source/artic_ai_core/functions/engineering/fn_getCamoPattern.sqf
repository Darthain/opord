/*
    ARTIC - camouflage pattern for this terrain (Pook net variant suffix).
    Checked against POOK Camonets: variants are numbered suffixes on every net class
    ("" = base pattern, then 2-22), e.g. 2 = NATO tan / desert brown, 5 = DPM desert,
    10 = AOR forest, 16 = snow, 22 = Lingor jungle.

    Mission override:  ARTIC_camoPattern = 5;   (0 or 1 = base pattern)
    Returns: suffix string ("" or "2".."22")
*/
private _override = missionNamespace getVariable ["ARTIC_camoPattern", -1];
private _n = if (_override >= 0) then {_override} else {
    switch (toLower worldName) do {
        case "altis";
        case "stratis";
        case "malden";
        case "vr": {2};
        case "takistan";
        case "zargabad";
        case "kunduz";
        case "mountains_acr";
        case "sefrouramal";
        case "lythium": {5};
        case "tanoa";
        case "lingor3";
        case "cam_lao_nam";
        case "rhspkl": {22};
        case "namalsk";
        case "chernarusredux_winter";
        case "enoch_winter": {16};
        default {1};
    };
};
if (_n <= 1) exitWith {""};
str (round _n)
