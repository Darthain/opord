params [["_name", "REGULAR", [""]]];
private _key = toUpper _name;
ARTIC_TrainingProfiles getOrDefault [_key, ARTIC_TrainingProfiles get "REGULAR"]
