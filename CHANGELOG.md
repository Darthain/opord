# Changelog

## 0.1.0-alpha (unreleased)
- Repository skeleton: HEMTT project, `main` addon, CI.
- Soldier layer: bundled fork of Workshop DCO Soldier FSM (`soldier`, `soldier_module`), BSD-3-Clause, at parity.
  Replaces the Workshop mod; do not load both.
- Soldier layer: PapaReap headless-client code removed (no licence) and replaced: Soldier FSM runs on the first
  connected headless client, otherwise the server. CBA setting `SFSM_runOnHeadlessClient` replaces `PR_Allow_HC`,
  `PR_Use_HC` and `PR_HC1`.
- Warning at startup if the Workshop Soldier FSM is also loaded.
- DCO UnitScanner is still required as a separate mod (temporary).
