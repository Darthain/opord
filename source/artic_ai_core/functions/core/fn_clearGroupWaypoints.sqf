params [["_group", grpNull, [grpNull]]];
if (isNull _group) exitWith {};

while { count waypoints _group > 0 } do {
    deleteWaypoint ((waypoints _group) select 0);
};
