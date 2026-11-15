# GripRumble packet investigation

## November 6, 2026 — Action-too-soon rejection

- **Scenario:** `/attack`, XIVCrossbar Attack, or any in-game action refused with the message `You must wait longer to perform that action.`
- **Direction:** incoming.
- **Packet:** `0x029` (action message).
- **Message ID:** 94, confirmed in Windower's action message ID list. GripRumble reads a 16-bit message at the unpack offset `0x19`, masks the upper bit with `% 32768`, and compares to 94.
- **Additional fields:** 32-bit actor at unpack offset `0x05` and target at `0x09`, following Broguypal Failsafe 1.0.4. The local player's ID must match actor or target for packet-driven cues.
- **Fallback:** Game incoming text with that exact rejection phrase. Packet and text receive a 0.3s duplicate suppression window to avoid buzzing twice for a single refusal.
- **Evidence:** Failsafe source `rerorriM-Mirrorer/Broguypal-Addons/Failsafe/Failsafe.lua`, Windower's message IDs (94). No live packet capture was obtained for this test batch. The mock test exercises representative packet bytes; it does not prove the game's live payload encoding for every action.
- **Known limitation:** The fallback text cannot be correlated to a specific packet or action. Rapid distinct rejections within 0.3s may collapse into one buzz. The precise success rate for ordinary `/attack` must be live-tested.

## November 6, 2026 — Skillchain window and Uriel Blade

- **Scenario:** Valaineral uses Uriel Blade against a selected or non-selected enemy.
- **Source:** Windower's parsed `action` callback, not direct injected packets. The source ID and each `action.targets[*].id`, category, skill ID, result message, damage amount, and skillchain add-effect are processed.
- **Heuristic:** Qualifying landed weapon/monster ability with known skillchain properties opens a target-ID-keyed estimated window. The current target must be alive and its individual window open for `chain_on`. Changing targets or expiration stops it. The nominal initial delay is 3s unless an ability-specific delay is provided. This is not proof of server availability of a follow-up.
- **Known ability IDs:** The 0.1.17 `chain_skills.lua` lists Uriel Blade in several resource namespaces, including monster abilities ID 2273. These are bundled resource data, not an observed Valaineral packet capture in this batch.
- **Live capture needed:** Log Valaineral's actual actor ID, action category, action ID, affected target IDs, result message and add-effect, and target selected before and after. Compare first hit, miss, and secondary AoE target, then test whether a follow-up actually executes in the measured window.

## November 11, 2026 — Incoming damage health tier (planned live verification)

- **Scenario:** Enemy action affects local player, party member/Trust, and/or own pet.
- **Input:** Windower parsed `action` callback (no packet injection). Determine damaged targets using recognized action result message and damage amount; classify target ID as own player, own pet returned by `get_mob_by_target('pet')`, or `get_party().p1..p5` entity ID. Existing enemy actor spawn-type guard remains.
- **Health observation:** Approximate 80 ms delayed read of `get_player().vitals.hpp`, party member `.hpp`, or pet `.hpp`; critical cutoff defaults to 25%. A missing percentage defaults to the normal (noncritical) impact. The delay is a buffer, **not proof** the health packet has already arrived. Verify with controlled combat logs and packet timing before claiming post-hit accuracy.
- **Motor output:** `hit` for normal self/pet; `criticalhit` for critical self/pet; `partyhits:` per-target letters `n` (small preexisting tap) / `c` (normal self impact). A fatal pet despawn still produces a normal pet impact. AoE produces one ordered sequence for affected party members, not two simultaneous overlapping party patterns.
- **Outstanding:** Verify real FFXI update order, lethal hit transition, party health percentages/Trusts, pet index and hit correlation, other-client contamination through shared event file. No packet ID was inferred or injected for health.
