[format ["Local planner started on owner %1",clientOwner],"PLANNER"] call ARTIC_fnc_debug;
while {true} do {
    {
        if (local _x && {_x getVariable ["ARTIC_enabled",false]} && {!isPlayer leader _x}) then {
            [_x] call ARTIC_fnc_groupStep;
        };
    } forEach allGroups;

    // The individual executor continuously enforces element/unit tasks so
    // vanilla AUTOCOMBAT cannot silently replace an active ARTIC plan.
    call ARTIC_fnc_processIndividualAI;
    sleep 1;
};
