# ARTIC AI v0.3.16-alpha Test Plan

Use the same Stratis radar/hill mission first. Keep the mortar removed for the movement benchmark. Run at least three identical passes before changing the mission.

## What this build is testing

1. **Guide continuity** — section GUIDE must survive approach -> early contact -> tactical release. It must not jump to the soldiers' centroid.
2. **Contact gating** — long-range contact should log `contact on approach; maintaining section routes`; full FIX/LEFT/RIGHT release should occur near HOLD/release positions or because the emergency-contact threshold was met.
3. **Protected roles** — SL / medic / 2IC remain inside the section envelope. They may have protected slots but should not form a trailing command tail.
4. **Plan fidelity** — FIX / LEFT / RIGHT follow their drawn approach routes and combat corridors. Debug now shows live SECTION GUIDE, FT-A and FT-B reference points.
5. **SBF validity** — known-enemy SBF visibility below 10% should hold the assault rather than accepting a blind fire position.
6. **Reload cover** — an exposed soldier at <=4 rounds should seek LOS-breaking cover before the magazine reaches empty whenever viable cover exists.
7. **Formation stability** — changes should happen mostly at route/control points, not WEDGE -> FILE -> WEDGE every few seconds.
8. **Metrics** — collect the periodic `METRICS ...` RPT lines and compare them with previous versions.

Then use the four fixed regression environments in `BENCHMARKS.md` before declaring a v0.3 release candidate.
