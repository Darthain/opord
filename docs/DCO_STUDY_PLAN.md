# DCO clean-room study plan (for v0.4)

Purpose: learn behavioural patterns useful to ARTIC's individual combat brain without turning ARTIC into a dependency or copying implementation code/assets.

## Questions to study
- How does DCO decide that an individual is in immediate danger?
- How are cover candidates generated, filtered and revisited?
- What makes a soldier break movement, return fire, reposition, or continue the parent task?
- How does it prevent oscillation between cover/move states?
- How does it reason about multiple threats / threat bearing?
- How are suppression, hits, nearby fire, casualties and grenades weighted?
- How does it handle reloads / weapon readiness while exposed?
- Which decisions are individual, fireteam, or group decisions?
- Which engine AI features are disabled/enabled during each state?
- How are locality and scheduler cost controlled?

## Clean-room workflow
1. Observe behaviour and document state transitions / inputs / outputs.
2. Inspect public source only where licensing allows study.
3. Record concepts in neutral pseudocode, not copied SQF.
4. Design an ARTIC-native interface that fits parent intent -> fireteam guide -> individual reaction.
5. Implement from the ARTIC design notes, not by transcribing DCO code.
6. Test with the same v0.4 regression missions and performance gate.

## ARTIC v0.4 target interface
An individual reaction should receive:
- parent task / battlefield ID / section role / fireteam ID;
- assigned slot and fireteam guide;
- live threat set and exposure;
- suppression / recent fire / hit state;
- weapon/ammunition state;
- casualty and morale state.

It should return one bounded local action such as:
`KEEP_TASK`, `SEEK_COVER`, `RETURN_FIRE`, `RELOAD_COVER`, `SHORT_REPOSITION`, `PINNED`, `RALLY`, `CASUALTY_ACTION`.

The local action may temporarily override the slot, but must not silently abandon the parent tactical intent.
