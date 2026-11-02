params [["_name", "CONVENTIONAL", [""]]];
private _key = toUpper _name;
ARTIC_Doctrines getOrDefault [_key, ARTIC_Doctrines get "CONVENTIONAL"]
