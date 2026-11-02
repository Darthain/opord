# Doctrine / Tactics Matrix

ARTIC uses one shared tactical toolbox. Doctrine changes preference, organisation, risk and transitions; training changes execution quality.

Legend: P = signature/preferred, H = high, M = normal, L = rare, - = normally not autonomous.

| Tactical action | Conventional | Insurgent | Militia | Recon | Positional | Special Forces |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Establish fire superiority | P | H | H | M | P | P |
| Weapon-aware support-by-fire | P | H | M | H | P | P |
| Suppress | P | H | H | M | P | P |
| Single flank | P | H | M | M | M | P |
| Double envelopment | H | L | L | - | L | M |
| Bounding advance | P | M | L | H | M | P |
| Deliberate assault | H | M | H | L | M | H |
| Hasty assault | M | H | P | L | L | M |
| Ambush | M | P | H | H | M | P |
| Raid | M | P | H | H | L | P |
| Reconnaissance attack | M | H | L | P | L | H |
| Bypass enemy | M | H | L | P | L | P |
| Fix enemy | P | H | M | H | P | P |
| Counterattack | H | M | H | L | P | M |
| Fighting withdrawal | H | H | L | P | P | P |
| Rapid break contact | M | P | H | P | M | H |
| Prepare battle position | H | H | M | L | P | M |
| Call indirect fires | P | M | L | P | P | P |
| Deception | M | P | L | H | P | P |
| Engineering/obstacles | H | P | M | L | P | H |

## Defensive / engineering emphasis

| Defensive capability | Conventional | Insurgent | Militia | Recon | Positional | Special Forces |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Hasty fighting position | H | H | H | M | P | H |
| Pairs/team position | P | H | H | M | P | H |
| MG/AT prepared position | P | H | M | M | P | H |
| Connected trench system | H | L | M | - | P | L |
| Alternate positions | P | P | M | P | P | P |
| Hidden reserve | H | H | L | L | P | M |
| Forward disruption/security | P | P | M | P | P | P |
| Camouflage / concealment | P | P | M | P | P | P |
| Dummy/deception positions | M | H | L | M | P | H |
| Conventional minefield | H | M | L | L | P | M |
| IED / improvised explosive integration | L | P | H | M | H | M |
| Prepared withdrawal route | P | P | M | P | P | P |

## Training matrix

| Behaviour | Poor | Regular | Veteran | Elite |
|---|---|---|---|---|
| Simultaneous elements | 1 | 2 | 2-3 | 3+ |
| Specialist assignment | Weak | Basic | Strong | Dynamic |
| Suppression before movement | Inconsistent | Usually | Reliable | Adaptive |
| Bounding movement | Rare/simple | Basic | Coordinated | Terrain-adaptive |
| Fighting withdrawal | Break contact | Simple bounds | Coordinated bounds | Bounds + support sequencing |
| Reserve management | Rare | Sometimes | Normal | Deliberate |
| Fire support integration | Crude | Basic | Coordinated | Multi-effect |
| Defensive construction | Hasty | Prepared | Primary + alternate | Layered/deceptive |
| Replanning | Slow | Normal | Fast | Continuous |

## Implemented composite plans in v0.1

- SUPPRESS_AND_FLANK
- FIGHTING_WITHDRAWAL
- PREPARE_BATTLE_POSITION
- DEFEND_BATTLE_POSITION

The rest of the matrix is the roadmap for subsequent tactic state machines.

## UAS / drone employment (v0.3)

| Action | Conventional | Insurgent | Militia | Recon | Positional | Special Forces |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Recon UAS | H | M-H | L | P | H | P |
| Persistent observation | H | M | L | P | H | P |
| UAS contact reporting | P | H | M | P | P | P |
| AP FPV strike | H | P | M | M | H | H |
| AT FPV strike | H | P | M | M | P | H |
| Recon before strike | H | M | L | P | H | P |
| Hold scarce AT FPV for armour | H | M | L | H | P | H |
| BDA / re-observe after effect | M | M | L | P | M | H |

The current alpha implements recon, commander reporting, and AP/AT Crocus FPV strikes. Persistent observation, BDA-specific missions, droppers, EW and coordinated multi-drone attacks remain later work.
