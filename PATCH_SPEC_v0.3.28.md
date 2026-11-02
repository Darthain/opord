# ARTIC AI v0.3.28-alpha — FSM architecture foundation

This is a non-default architecture branch. It creates the Commander, Platoon, Section and Fireteam scripted FSMs plus the Fireteam task schema and start/condition helpers. `ARTIC_useFSMHierarchy` is false by default so the files can be reviewed without competing with the v0.3.27 movement/runtime loops.

The Fireteam FSM is intentionally a task/state controller, not yet the locomotion owner. A later leaf navigation FSM can use `doFSM`/`commandFSM` and low-level `moveTo` for short local gates while the tactical Fireteam FSM remains an `execFSM` controller.


## FSM Editor compatibility
The `.fsm` files in this corrected package include the decompilation/layout metadata required by Bohemia FSM Editor. The earlier generated foundation had valid-looking scripted FSM class text but omitted the `%FSM` editor metadata, which makes FSM Editor display a blank graph even though the text file is non-empty.
