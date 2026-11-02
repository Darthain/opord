# Tactical Foundation — v0.3

ARTIC now separates four layers during a combat action:

1. **Commander intent** — ATTACK / DEFEND / DELAY / etc.
2. **Group plan** — e.g. SUPPRESS_AND_FLANK.
3. **Element tasks** — support, manoeuvre, reserve.
4. **Individual execution** — HOLD / SUPPRESS / MOVE / ASSAULT.

The individual executor exists specifically to prevent vanilla AUTOCOMBAT from changing the meaning of an active ARTIC plan. Arma still supplies navigation/pathfinding and basic movement mechanics.

## Current support-by-fire scoring
Candidate positions consider:
- line of sight to the target
- nearby terrain/object cover
- slope
- useful weapon range
- elevation change
- movement distance from the contact position

## Current flank scoring
Both left and right are evaluated. Route score considers:
- how much of the route is masked from the target
- nearby cover
- slope quality
- route length
- whether the final staging area can see the target

## Current support integration
The attack planner can request mortar/artillery before manoeuvre. Elevated targets, failure to establish support LOS, and poor flank routes are treated as stronger reasons to request support.

This is intentionally the foundation for later composite tactics such as deliberate attack, hasty attack, double envelopment, raid, ambush and delay.
