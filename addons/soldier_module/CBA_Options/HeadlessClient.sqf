// Copyright (C) 2026 OPORD contributors
// BSD 3-Clause License. See LICENSE in this addon.

private _versionName = "OPORD | Soldier FSM | Headless Client";

[
    "SFSM_runOnHeadlessClient",
    "CHECKBOX",
    ["Run Soldier FSM on a headless client", "Soldier FSM runs on the first connected headless client if there is one, otherwise on the server. If that headless client disconnects, the server takes over."],
    _versionName,
    true,
    true,
    {},
    true
] call CBA_fnc_addSetting;
