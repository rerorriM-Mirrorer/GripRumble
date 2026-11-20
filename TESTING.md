## Current Development Status — 2026-11-20 (America/Chicago), 0.1.24 Test2: pet hits as party hits

- **Repository / branch:** `rerorriM-Mirrorer/GripRumble` / `development/0.1.24-cast-land-switches`, on top of `bcfcc60` (0.1.24 Test1, cast/land switches).
- **Installed base:** 0.1.23 Follow Tempo test (A, 2026-11-20); Test1 may or may not be installed, the Test2 ZIP covers both.
- **Request:** Make rumbles for hits/damage to the player's pet match hits on other party members instead of hits to self.
- **Change (Lua only):** Your pet's ID now goes into the same `partyhits:` list as party members, in target order, so it plays the party tap (`n`) or the critical-party tap (`c`, below the critical threshold) instead of `hit` / `criticalhit`. A pet that vanished after a fatal hit reads as a normal tap (Inferred: no HP to read). `report_damage` lost its pet argument. `bridge.py` and every waveform unchanged; the `pethit` preview cue still exists and is unchanged.
- **Checks (Verified, host only):** `luatex --luaonly tests/mock_grip.lua .` PASS (self+pet+critical ally = `hit` + `partyhits:nc`; critical self+critical pet+normal ally = `criticalhit` + `partyhits:cn`; pet alone = `partyhits:n`); `python3 -I tests/check_helper.py` PASS; `git diff --check` PASS. No Windower, helper, DualSense or FFXI run.
- **Live:** none for 0.1.24. 0.1.23 follow tempo and hush still Pending.
- **Next live tests:** Test1 list below, plus: with a pet out, let it take hits: it should feel like a party member's tap, not your own big impact. With the pet under 25% HP: the critical-party tap. Self hits unchanged. A hit on you, your pet and a party member together: one self impact, then two taps.

---

## Current Development Status — 2026-11-20 (America/Chicago), 0.1.24 cast/land switches

- **Repository / branch:** `rerorriM-Mirrorer/GripRumble` / `development/0.1.24-cast-land-switches`, based on `development/0.1.23-follow-tempo` `1129f74` (0.1.23 code `4555757` plus today's docs sync).
- **Installed base:** A reports the 0.1.23 Follow Tempo test is installed (A, 2026-11-20).
- **Request:** A setting or command to disable the rumble during casting and when a spell lands; add them if missing. Verified: none existed; `cast` and `land` were always emitted for your own spells.
- **Change (0.1.24, Lua only):** `//grip cast [on|off|test]` and `//grip land [on|off|test]`, saved per character via `config` (`cast_rumble`, `land_rumble`, default ON so behavior is unchanged until switched). Cast off: no `cast` cue, casting is still tracked. Land off: the silent `stop` is sent instead of `land`, so any hum still ends. Turning cast off mid-cast sends `stop`. Interrupt, `burst` (magic burst), damage and all other cues untouched. `//grip status` line 2 starts `Cast: ON | Land: ON`. Bare `//grip cast` preview now auto-stops after 1.5 s (was: hummed until the helper's 120 s cap). `cast`/`land` removed from the generic `<cue>` help line since they have their own entries. `bridge.py` and every waveform unchanged.
- **Checks (Verified, host only):** `luatex --luaonly tests/mock_grip.lua .` PASS (LuaTeX Lua 5.4 mock, not Windower Lua 5.1; new cases: cast off, land off, stop still sent, interrupt unaffected, previews, usage, reload persistence from XML strings, back on); `python3 -I tests/check_helper.py` PASS; `python3 -m py_compile bridge.py launch_hidden.py` PASS; `git diff --check` PASS. No Lua 5.1 `luac` on this host. No Windower, helper, DualSense or FFXI run.
- **Live:** none for 0.1.24. 0.1.23 follow tempo and hush still Pending.
- **Next live tests:**
  1. Install over `addons/GripRumble/` (helper restart not needed: `bridge.py` unchanged), `//lua r GripRumble`, `//grip status`: line 2 starts `Cast: ON | Land: ON`.
  2. `//grip cast off`, cast a spell: no hum while casting; the landed pulse still plays.
  3. `//grip land off`, cast again: no hum and no landed pulse; nothing left humming afterward.
  4. Interrupt a spell (move while casting): interrupt buzz still plays. A magic burst still gives the burst rumble.
  5. `//lua r GripRumble`, `//grip status`: both still OFF. `//grip cast on`, `//grip land on`: normal casting feel is back.
  6. `//grip cast` and `//grip land` (bare) preview each once; the cast hum stops by itself.

---

## Current Development Status — 2026-11-20 (America/Chicago)

- Docs sync to canon 2026-11-20.1 (`agents_shared_version` and `workflow_version`); project-specific lines moved to the AGENTS REPO block: project rules (2 bullets), prototype note, XIVCrossbar companion note; no runtime change, no FFXI test.

---

# GripRumble TESTING.md

## Current Development Status - November 16, 2026, later (America/Chicago)

- **Repository / branch:** `rerorriM-Mirrorer/GripRumble`. `main` now holds 0.1.22 (`b598d9d`), promoted as known good on the user's live report. Working branch `development/0.1.23-follow-tempo` builds on it.
- **Runtime / companion:** unchanged from 0.1.22 (Windower 4, Python 3 / SDL3 3.2.28 x64 helper, XIVCrossbar `feat/rumble-events-20261115`).
- **Source baseline:** `b598d9d` (0.1.22).
- **Current change (0.1.23):** `follow_far_on` loop `[(3000,9000,80),(0,0,920)]` (1 s); `follow_lost_on` loop `[(12000,18000,90),(0,0,110),(12000,18000,90),(0,0,210)]` (0.5 s); follow poll 0.25 s; all-clear settle 0.5 s (far/lost settle stays 1.5 s); new `//grip hush` and `//grip distance hush`.
- **Recent user-confirmed live behavior:** 0.1.22 "working well" in game, including the follow distance feature; user asked for the faster tempo and quicker all-clear now in 0.1.23.
- **Verification:** `luatex --luaonly tests/mock_grip.lua .` PASS (adds hush and 1 s all-clear checks); `python -I tests/check_helper.py` PASS (1 s / 0.5 s cycles); `python -m py_compile bridge.py launch_hidden.py` PASS; `git diff --check` PASS. Not run in Windows, Windower or FFXI.
- **Next live tests:** restart the helper (waveforms changed). `//grip distance test` for the new tempo. Walk away: tug every second past the distance, quick double knock out of sight. Walk back: rumble stops and ticks within about a second. While rumbling, `//grip hush`: silent at once, `//grip status` shows `hushed`; after everyone is back and someone leaves again, it rumbles again. Hush a far alert, then let them drop out of sight: the knock should come through.

---

## November 16, 2026 - Follow tempo and hush, test batch 0.1.23

- **Live report on 0.1.22:** Working well. Requests: far tug about every second, lost double knock every half second, back in range within 1 s, and a quick way to stop distance rumbles until the next trigger. Push 0.1.22 to `main` as known good.
- **Publication:** `main` fast-forwarded to `b598d9d` (0.1.22, unchanged code) and `development/0.1.22-crossbar-follow` pushed. 0.1.23 pushed on its own development branch; not on `main`.
- **Interpretation of "until next trigger":** hush lasts until everyone is back within the distance (the all-clear), so the next time someone falls behind is a new trigger. A worse state than the one hushed (far to out of sight) also counts as a new trigger. Hush is not saved and clears on zoning, cutscenes and turning the watch off.
- **Files:** `GripRumble.lua`, `bridge.py`, `tests/mock_grip.lua`, `tests/check_helper.py`, `README.md`, `TESTING.md`.
- **Install:** full ZIP. Stop the helper, extract over `addons/GripRumble/`, start the helper, `//lua r GripRumble`.

---

## Earlier status (0.1.22 batch, kept for history)

- **Repository / branch:** `rerorriM-Mirrorer/GripRumble`, local working branch `development/0.1.22-crossbar-follow`, based on the published `development/0.1.21-chat-style` head `1b7ab06`. **Not pushed:** push access was not granted in this session. The testing ZIP matches the local branch head given in the handoff.
- **Runtime / companion:** Windower 4 Lua addon plus Windows Python 3 / SDL3 3.2.28 x64 helper. Companion: XIVCrossbar local branch `feat/rumble-events-20261115` (commit `a766b6e`), which sends `slotpress`, `triggerpull`, `setswitch` and `binding` into `events.txt`, each saved per character in XIVCrossbar and OFF by default there.
- **Source baseline:** User's installed snapshot `GripRumble-2026-11-16.zip`; its code (`GripRumble.lua`, `bridge.py`, `chain_skills.lua`, tests, launchers) is byte-identical to `1b7ab06`. Its bundled `SDL3.dll` SHA-256 `55f17c87...0d82` matches `docs/DEPENDENCIES.md`.
- **Current change (0.1.22):** `triggerpull` waveform; `//grip triggerpull|setswitch|binding [on|off|test]`; no XIVCrossbar command at load (slot override now only on `//grip slotpress on|off`); saved `//grip distance [on|off|5-50|test|check]` follow watch with far/lost loops and all-clear tick; helper follow-loop timeout and truncated-file recovery. `slotpress`, `setswitch`, `binding` and every other existing waveform unchanged.
- **Recent user-confirmed live behavior:** User reports all current GripRumble rumbles working well, including slotpress. XIVCrossbar `//xb rumble all on` worked and slot rumble stayed on after reloading XIVCrossbar alone (reported in the XIVCrossbar handoff). Nothing in 0.1.22 has been tested in game.
- **Verification:** `luatex --luaonly tests/mock_grip.lua .` PASS (LuaTeX Lua 5.4 simulation, not Windower Lua 5.1); `python -I tests/check_helper.py` PASS (now also runs `run_bridge` against a fake clock, file and motor: follow refresh keeps rhythm, 30 s timeout, truncated file, triggerpull lighter than slotpress); `python -m py_compile bridge.py launch_hidden.py` PASS; `git diff --check` PASS. No Windows helper, USB DualSense, Windower or FFXI run.
- **Next live tests:** see the November 16 entry below.

---

## November 16, 2026 - XIVCrossbar cues and follow distance, test batch 0.1.22

- **Request:** Rumble patterns for XIVCrossbar's new cues (handoff `griprumble-handoff-2026-11-15.md`), GripRumble-side settings for them, and a continuing rumble when a party member in the same zone is beyond a chosen distance or out of sight, with `//grip distance <yalms>`, `0`/`off` off, bare toggle, and possibly a lighter level past the distance and a stronger one out of sight. All files for a fresh install.
- **Handoff decisions taken:** (1) The load-time `slotrumble on` sync is removed; it overrode a slot cue saved OFF in XIVCrossbar. (2) New cues are never auto-synced; `//grip <cue> on|off` forwards one `//xb rumble` command only when typed, from that client, so clients never write XIVCrossbar's shared settings together at load. (3) Per-cue switches live in XIVCrossbar; GripRumble only forwards. (4) Per-trigger detail (`triggerpull:l2`) left for a later XIVCrossbar change.
- **Waveforms (all suggestions, untested by feel):** `triggerpull` `[(9000,4000,30)]` - low motor, below slotpress's 38000/47000 and shorter than its 135 ms, on the opposite motor from `setswitch`'s high-motor tick. `follow_far_on` loop `[(3000,9000,80),(0,0,1920)]` (2 s). `follow_lost_on` loop `[(12000,18000,90),(0,0,110),(12000,18000,90),(0,0,1210)]` (1.5 s). `follow_ok` `[(0,6000,60),(0,3000,60)]`. `follow_preview` joins them for `//grip distance test`.
- **Follow rules:** party p1-p5 in your zone only; lost = no Windower mob/position or at least 49.5 yalms (FFXI's 50-yalm draw/update cap leaves stale positions beyond it); far = beyond the distance; clear 2 yalms inside it; 1.5 s settle; strongest member state wins; re-sent every 10 s while active (helper stops a loop after 30 s without one); quiet in cutscenes (status 4), Mog House and for 10 s after load, zoning or logout.
- **Files:** `GripRumble.lua`, `bridge.py`, `tests/mock_grip.lua`, `tests/check_helper.py`, `README.md`, `TESTING.md`. `chain_skills.lua`, launchers, `SDL3.dll`, WORKFLOW, AGENTS, PACKETS, DEPENDENCIES unchanged.
- **Install:** Full install ZIP. Stop the helper (`//grip shutdown` or close it), extract over `addons/GripRumble/`, start the helper, `//lua r GripRumble`. The ZIP ships no `data/settings.xml`, `events.txt` or logs, so saved chain settings and history are kept.
- **Live test requests:**
  1. `//grip status`: third line shows `Follow distance: OFF`. Slot shows `XB saved`.
  2. `//xb rumble` to see XIVCrossbar's saved cues, then `//grip triggerpull on`; pull L2/R2 and change shoulder banks. Does the detent feel distinct from slotpress, and is it light enough when followed by a slot knock? `//grip setswitch` and `//grip binding` previews next to it.
  3. `//lua r GripRumble` with XIVCrossbar slot cue saved OFF: slot presses should stay silent (previously GripRumble turned them on).
  4. `//grip distance test`, then `//grip distance 30`. Walk away from a follower: soft tug past 30; double knock once they drop out of sight; one soft tick when they catch up. Use `//grip distance check` at each stage and note the reported yalms, especially the last number seen before `no position`.
  5. Zone with followers; no rumble for about 10 s, then only if someone is left behind in the zone. Cutscene: no rumble. `//grip distance off` stops it at once.
  6. Reload GripRumble: distance setting is kept. Regression: slotpress, cast/land/interrupt, damage cues unchanged.
- **Open questions:** Whether Windower drops a distant member's `mob` entry or keeps a stale one, and the exact last-seen distance in crowded zones (the server may stop updating some characters earlier). `check` output answers both.

---

## Current Development Status - November 14, 2026 (America/Chicago)

- **Repository / branch:** `rerorriM-Mirrorer/GripRumble` / `development/0.1.21-chat-style`. The repository was empty before this publication. `main` contains only the bootstrap README; the unverified 0.1.21 source remains on the development branch.
- **Runtime / companion:** Windower 4 Lua addon plus a Windows Python 3 / SDL3 DualSense helper. XIVCrossbar remains an optional companion for accepted slot presses; no XIVCrossbar files were changed in this batch.
- **Source baseline:** `GripRumble-0.1.21-Chat-Conventions-Test.zip`, SHA-256 `6ea6b39dcaac7e19b9c3e6d124831139f0f76fb2a4de1917fa34c63c676bb7e8`. The GitHub source snapshot was imported from this exact package. `chain_skills.lua` matches the existing `rerorriM-Mirrorer/xivcrossbar` `libs/skillchain/skills.lua` blob `78476bc45a49fc23a22744600db2471e8e10c895` byte-for-byte.
- **Current change:** Publish the 0.1.21 source, tests, packet notes, README, and current canonical WORKFLOW. The 0.1.21 code changes chat output to shared color conventions and retains chain-mode persistence. No haptic behavior or helper waveform changed from 0.1.20.
- **Recent user-confirmed live behavior:** User reports the 0.1.18 slotpress waveform feels substantially better. No live confirmation yet for 0.1.20 chain persistence or 0.1.21 chat colors.
- **Verification:** `luatex --luaonly tests/mock_grip.lua .` PASS (LuaTeX Lua 5.4 mock simulation, not Windower Lua 5.1); `python tests/check_helper.py` PASS; `python -m py_compile bridge.py launch_hidden.py` PASS; ZIP integrity PASS (15 entries, 2,703,703 uncompressed bytes). No actual Windows helper, SDL3 runtime, USB DualSense, Windower, or FFXI chat test was run.
- **Binary dependency:** `SDL3.dll` is intentionally not tracked in the Git source branch. The testing ZIP includes the runtime. The bundled DLL identifies as SDL 3.2.28 x64 and has SHA-256 `55f17c87b32e07ef46365d604131c063014e4e47ce58da9ec061720ddfb90d82`; see `docs/DEPENDENCIES.md` for the upstream SDL package.
- **Publication note:** The previous November 12 status recorded local branch/hash information from the prior handoff. The local `.git` metadata was not present in this workspace, and the remote repository was confirmed empty. This publication is therefore a new GitHub source snapshot imported from the 0.1.21 ZIP, not a verified push of the previously reported local commit. Historical records below are retained as records of what was reported at the time.
- **Next live tests:** Install the 0.1.21 ZIP; verify `//grip help`, `//grip status`, invalid-command help, and ASCII punctuation in actual FFXI chat; set `//grip chain off`, reload, and confirm it stays off; confirm slotpress, casting, success and interruption remain unchanged. Restart the Python helper only if the helper files are replaced.

---

## November 14, 2026 - Initial GitHub source publication of 0.1.21

- **Repository setup:** Confirmed `rerorriM-Mirrorer/GripRumble` was empty and that the linked GitHub account had push permission. Added a bootstrap README on `main`, then created `development/0.1.21-chat-style` for the unverified source checkpoint. `main` was not promoted to a test release.
- **Published source:** GripRumble Lua, Python helper source, skillchain data, launchers, LICENSE, README, AGENTS, WORKFLOW, cumulative TESTING, packet notes, and local mock/static tests. `SDL3.dll` is excluded from Git because the available GitHub file-writing path accepts text blobs; the exact runtime remains in the supplied 0.1.21 testing ZIP and its version/hash are documented in `docs/DEPENDENCIES.md`.
- **Workflow:** Refreshed root `WORKFLOW.md` from the current NPCMirror canonical file and preserved the GripRumble-specific prototype note. Root README/WORKFLOW/TESTING follow the shared repository convention; the installable ZIP continues to keep its copies inside `GripRumble/`.
- **Checks:** LuaTeX mock simulation PASS; Python helper static tests PASS; Python `py_compile` PASS; source ZIP integrity PASS. This is static/simulated verification only, not live Windower or FFXI acceptance.
- **Remote status:** The actual development branch head is recorded in the delivery handoff and GitHub history. The commit hash is intentionally not written into this file because it would change the commit itself.

---

## November 12, 2026 - Chat convention test batch 0.1.21

- Request: conform all GripRumble chatlog messages to the current canonical WORKFLOW.md conventions, not just one chain save message.
- Modified: `GripRumble.lua`, tests/mock_grip.lua, README.md, TESTING.md, and kept bundled WORKFLOW.md aligned with canonical guidance. `bridge.py`, SDL3.dll, all other haptic files untouched.
- Checks: LuaTeX API mock, helper static check, Python bytecode compilation, source diff inspection. All PASS locally. Physical controller and in-game chat colors pending.
- Publish: local development commit and full ZIP testing package only; GitHub repository `main` still empty. Neither live gameplay nor controller testing claimed.

---

## Current Development Status — November 12, 2026 (America/Chicago)

- **Repository / branch:** `rerorriM-Mirrorer/GripRumble` is still empty on remote `main` (checked this batch). Local development branch: `development/0.1.20-chain-persistence`. Do **not** interpret this package as pushed to GitHub.
- **Baseline:** Archived `GripRumble-0.1.19-Haptic-Tuning-Test.zip` SHA256 `fef1cb378206dfd9820d1228b400dbcd35e9028e5027af4ba8dd967b101c8aac`; the Lua addon, mock test, README, TESTING and a canonical WORKFLOW chat-punctuation convention change in this batch.
- **Current change:** Windower `config` persists `chain_mode` per-character, defaulting to `steady` if no saved setting exists. Commands `//grip chain off`, `//grip chain steady`, and `//grip chain heartbeat` save the selected mode. No other haptic toggle becomes persistent. Existing slotpress, casting, damage, skillchain cue waveforms and helper remain unchanged.
- **Observed user report:** User repeatedly set `//grip chain off`, but it reset after an addon reload. Source confirmed `chain_mode = 'steady'` and no save/load in 0.1.19. User earlier confirmed 0.1.18 slotpress feels significantly better. No live 0.1.20 test has been performed.
- **Local checks:** LuaTeX Lua 5.4 Windower event simulation for chain off/steady/heartbeat across repeated source reloads, other default toggles, and legacy cue regressions; Python helper static tests and Python bytecode checks; integrity and files inspected. Windower Lua 5.1 and Windows helper/physical DualSense are **not** tested.
- **Next in-game:** Install 0.1.20, run `//grip chain off`, confirm chat says saved, `//lua r GripRumble`, run `//grip status`, expect `Chain: off`. Confirm no skillchain window rumble but casting/slotpress remain. Test heartbeat persistence if desired. If saving warns or fails, capture the specific error and inspect `GripRumble/data` permissions.

---

## November 12, 2026 — Chain mode persistence test batch 0.1.20

- **Request:** Keep `//grip chain off` from reverting on addon reload.
- **Implementation:** Use normal Windower `config.load` to read a saved chain mode at addon load. `config.save` writes the explicit selection in the chain command handler; do not write a settings file in the ZIP. Preserve all other per-load defaults.
- **Files:** `GripRumble.lua`, `tests/mock_grip.lua`, `README.md`, `TESTING.md`, `WORKFLOW.md` (shared chat-punctuation guidance); all other packaged source files remain identical to the previous ZIP.
- **Tests:** `luatex --luaonly tests/mock_grip.lua .` - PASS simulation, including multiple in-process Lua reloads; `python tests/check_helper.py` - PASS helper static checks; `python -m py_compile bridge.py launch_hidden.py` - PASS; Lua syntax loadfile - PASS. This is not in-game confirmation.
- **Delivery:** Full install ZIP with WORKFLOW.md and TESTING.md inside the GripRumble folder. No requirement to restart Python helper for this Lua-only code change.

---

## Current Development Status — November 11, 2026 (America/Chicago)

- **Repository / branch:** Dedicated `rerorriM-Mirrorer/GripRumble` repo has `main` configured but contained no commits/files when checked. This checkpoint is from the archived 0.1.18 ZIP (local main baseline `7b87ab8a9239ba9960bd09634d8eb8f3292b3f8c`), prepared locally as `development/0.1.19-haptic-tuning` without replacing any known-good remote `main` release.
- **Source baseline:** `GripRumble-0.1.18-Default-Haptics-Test.zip` SHA256 `fa1be3d6ad8acd3294928fe6e06d447ea540550ac59bc6f81c114336fe091477`. The matching XIVCrossbar slot-tap ZIP was inspected read-only; no XIVCrossbar source is modified in this batch.
- **Current build:** 0.1.19. Slotpress unchanged, with its existing auto-sync at Grip load and manual `//grip slotpress on` after XB reload. Reject and TP thresholds default OFF. Cast/hit/spell/burst waveforms unchanged. Skillchain rhythm optional steady/heartbeat (60 BPM)/off. No custom avatar summoned/dismissed cue. Own pet damage has normal self-hit feedback. New critical health distinction defaults ON at 25% HP: self/pet stronger double impact, critically injured ally gets standard self-hit strength.
- **Live feedback:** User confirmed that the 0.1.18 slotpress *feels so much better* and that casting/land/interrupt, self-hit and party-hit effects are liked. No new live 0.1.19 test or actual haptic strength validation has occurred.
- **Verification:** Lua parsing via LuaTeX (Lua 5.4, not Windower Lua 5.1); simulated Windower callbacks for default switches, slot hook command, rejection, TP thresholds, skillchain mode changes and targeting, no avatar transition cue, pet damage, critical self/party and opt-out; Python bytecode compilation plus helper pattern/static checks. Real Windows, physical controller, multibox and packet order are **untested**.
- **Known limitations:** Shared `GripRumble/events.txt` has no writer/client identity. XIVCrossbar's in-memory `slotrumble` resets OFF after XB reload; GR re-syncs only on its own load or `//grip slotpress on`. GR loaded on two clients or enabled XB hook on a different client can mix events. Client-specific routing and reload handshake require a deliberate follow-up companion integration. Critical threshold uses current hpp after ~80 ms, so action/HP update ordering and fatal hits need in-game confirmation.
- **Next:** Install 0.1.19 on the single intended client, restart the Python helper, confirm slotpress and cast preservation, test `//grip chain heartbeat` with Uriel Blade, preview `//grip critical test` and `//grip critical partytest` separately, test pet vs party AoE and 25% HP severity, and inspect the linked XB dropouts separately before changing its source.

---

## November 11, 2026 — Test batch 0.1.19

**Material and development context:** Continued independently from the 0.1.18 delivered ZIP rather than guessing source. Compared the XIVCrossbar test package's `emit_slotpress` and `slot_rumble_enabled` behavior. Rechecked the current canonical NPCMirror `AGENTS.md`, `WORKFLOW.md`, and `TESTING.md` from GitHub because GripRumble's new dedicated GitHub repository is empty. Followed the ZIP-layout rule: docs remain inside `GripRumble/`.

**Changes requested:** Retain the good slotpress and cast/landing/interruption cues; reject buzzer and TP thresholds OFF by default; keep unchanged damage/party cues; optional 60 BPM heartbeat for selected target's continuation window; no summon/dismiss special event; own pet damage like self damage; stronger own damage in critical health, and critical party damage like normal self damage; investigate cross-client and XB-reload dropoffs.

**Checks:**
1. `luatex --luaonly tests/mock_grip.lua <addon-folder>` — simulated event routing, exact switch defaults, XT slot auto-sync and manual re-sync, rejection suppression, TP toggle, target-specific and missed Uriel Blade timing, chain mode changes, no summon/dismiss cue, self/pet/party hits, critical classifications, and opt-outs. PASS locally.
2. `python tests/check_helper.py` — static helper pattern tests: slotpress unchanged, heartbeat cycle exactly 1000 ms, critical self stronger than self, critical-party equal to normal self, no avatar one-shot, cleanup of both chain loops. PASS locally.
3. `python -m py_compile bridge.py launch_hidden.py`, Lua parsing with local LuaTeX — PASS. Neither validates Windows DLL ABI or Windower 4 Lua 5.1.
4. ZIP layout and integrity — check at package creation.

**Live test requests:** Compare old/new slotpress and casting; test `//grip reject test` with reject OFF; `//grip tp on` threshold followed by OFF; `//grip chain heartbeat`, `steady`, `off` while an eligible continuation window is open; pet damage with Carbuncle/BST/PUP; self drops below 25%, ally below 25%, simultaneous AoE with multiple party members; fast lethal damage; reload XIVCrossbar and verify the known re-sync command; check other clients for GripRumble load / `//xb slotrumble` state when unexpected cues occur. Packet and vital timing remain observational pending live captures.

**Publication:** Local testing package only until a GitHub baseline can be initialized and a working branch pushed. Do not mark this as a remote publication or an in-game pass.

---

## Current Development Status — November 6, 2026 (America/Chicago)

- **Source / branch:** Local Git repository `griprepo` on `development/0.1.18-default-haptics`, based on archived GripRumble 0.1.17 Slot Tap ZIP (local baseline commit `035f141`); no connected GripRumble GitHub repository, remote branch, or published push. Do not confuse the local commit with a remote GitHub release.
- **Current build:** 0.1.18, still independent of XIVCrossbar. Companion requirement for slot presses: XIVCrossbar public-beta test build with `//xb slotrumble on|off` hook. XIVCrossbar files are not modified in this batch.
- **New behavior:** Default-on `slotpress` + auto XB hook request on addon load; `//grip slotpress [on|off|test]`, with bare `slotpress` explicitly enabling and reporting state. Default-on `reject` with `//grip reject [on|off|test]`, 0x029 message-94 and incoming-text detection, duplicate suppression; stronger two-part slot knock.
- **Preserved:** All old overlapping motor effects, cast/success/interrupt/TP/party impact behavior, previous per-load toggles, and the target-specific skillchain timer heuristic. A Uriel Blade landed hit can open an **estimated** skillchain timer, never a guaranteed server-confirmed opportunity.
- **Verification:** Python 3 `py_compile` for helper scripts; Lua syntax parsing using local LuaTeX 5.4 (NOT Windower's Lua 5.1); local mock Windower test of command routing, defaults, duplicate rejection, and target-specific chain selection (see `tests/mock_grip.lua`). No actual Windows, USB, Windower, or FFXI test for 0.1.18.
- **Outstanding live checks:** Feel new two-stage knock; confirm Grip auto-enables the XIVCrossbar test hook when both addons are loaded; confirm `slotpress off` silences XB cues while preserving manual tests; verify `/attack` early rejection on `0x029`/message 94 and no double buzz from text + packet; confirm Valaineral Uriel Blade only starts the continuation rumble if a landed property-bearing action produced a tracked window on current target. If XIVCrossbar is reloaded after GripRumble, re-run `//grip slotpress on` to re-sync.
- **Package install:** Replace the existing `GripRumble/` folder with the package and restart its Python helper to load changed `bridge.py`. Preserve `events.txt` or `bridge.log` as needed before replacing. No changes to `xivcrossbar/`.
- **Next:** Live test and adjust strength/timing, investigate any false chain opens with action packet diagnostics, decide on persistent settings and proper shared ownership only after current standalone version is trusted.

---

## November 6, 2026 — 0.1.18 local testing batch

- **Base:** 0.1.17 Slot Tap ZIP, not a GitHub commit.
- **Modified:** `GripRumble.lua` and `bridge.py` plus source documentation. Kept `chain_skills.lua`, `SDL3.dll`, and launchers unchanged. No code changes in XIVCrossbar itself.
- **Semantics:** `//grip slotpress` now explicitly switches ON instead of being the old manual single-tap preview; use `//grip slotpress test` for the preview. The hook is ON by default on Grip load; uses Windower `lua c xivcrossbar slotrumble on` to request XB's test switch. The reject detector similarly defaults ON and is not tied to Failsafe's retry queue.
- **Checks:** LuaTeX syntax parse, Python `py_compile`, local `tests/mock_grip.lua` simulation; no in-game claim. Notes and outstanding tests retain original historical entries below verbatim.

---

# GripRumble 0.1.17 — Slot press test

- Run the helper, then use `//grip slotpress` for one 30 ms tap.
- On the XIVCrossbar test build, enable `//xb slotrumble on`. Accepted slot
  presses append the same cue to the running helper's event stream. An accepted
  press reports local dispatch, while existing spell and combat cues report
  what happened in-game.
- Shut down and restart the helper after updating `bridge.py`. Reload GripRumble
  for the manual command. Physical feedback is pending live testing.

---

# GripRumble 0.1.0

1. Extract the GripRumble folder directly under Windower's addons folder.
2. Plug the DualSense in via USB. Double-click Run-GripRumble.cmd and wait
   for Ready. Leave the existing XIVCrossbar wrapper running.
3. In one Windower client, enter //lua load GripRumble. Feel the greeting.
4. Try //grip cast, wait past six seconds, then //grip land or //grip stop.
   The cast should rise for 3 seconds, switch to cx, then repeat x8 at 6 seconds.
5. Cast a spell in game. Confirm m2 on completion and silence on interruption.
6. Take an enemy melee hit. Confirm x3. Summon and Release an avatar.
   Each avatar transition should play three repetitions of x9.
7. Use //lua unload GripRumble, then Ctrl+C in the helper to end the test.

Manual replay commands: //grip hello, //grip hit, //grip avatar.
Enemy detection currently covers landed enemy melee attacks. Spell completion
uses the player's completion packet. There is a two-minute cast failsafe.
Python syntax and archive integrity checked. Windows, Windower, and controller
behavior need in-game verification.

## 0.1.1 hidden helper

Stop the old helper with Ctrl+C before updating. Double-click Start-Hidden.cmd.
Its launcher can flash briefly. The helper runs without a console and appends
startup output and errors to bridge.log. Wait for a new Ready line, then load
GripRumble (or reload it if already loaded) for the greeting. The helper starts
at the end of events.txt, so a greeting sent before startup is skipped.
Use //grip hello to replay and //grip shutdown to stop the helper.

## 0.1.2 lifecycle and live autoattacks

Stop the 0.1.1 helper before replacing the folder contents. Load GripRumble
on one client. It probes for the helper, launches it hidden if needed, then
plays the greeting when the helper responds. Unload should stop the helper.
Check bridge.log for Ready, hello, and the stopped message.
Use //grip verbose to toggle chat and diagnostics.log, then land a melee
autoattack. Compare the live cue with //grip autoattack. Cast Cure and compare
the softer cast with the stronger 230 ms landing cue.

## 0.1.3 Windower Lua compatibility

0.1.2 failed at require('ffi') on the reported Windower runtime.
0.1.3 uses the Windows start command through standard Lua and retains
the hidden Python helper and ready probe. The launcher can briefly appear
minimized. Reload on the affected client and check for the greeting.
If launch fails, start Start-Hidden.cmd manually and reload the addon.

## 0.1.4 launcher exit and shutdown check

The minimized launcher explicitly uses cmd /c and exits without pausing.
Startup errors go to launcher.log or bridge.log. A brief flash can still occur.
Use //grip unload (or //lua unload GripRumble) and verify a new stopped line
in bridge.log. //grip shutdown stops only the helper.

## 0.1.5 combat feel

Cast a long spell. Expect a quiet, steady hum through the cast and the
existing landing cue. Interrupt a cast and check that the hum stops.
Land a melee round and compare the cue with the damage animation.
The live cue is delayed one second from the action event; the manual
//grip autoattack preview is immediate.
Use //grip tploop to opt in for the current addon load. At 3,000 TP the
previous charged sweep repeats behind other cues. Spend TP to stop it.

## 0.1.6 incoming damage and casting

Try melee, ranged, Bomb Toss, and hostile damage spells. In verbose mode
a matched incoming hit prints its action category and message ID. Misses,
healing and status-only actions should be silent. Outgoing autoattack cues
are manual-only via //grip autoattack. Casting uses a much lighter high
channel hum with overlapping refreshes. TP loop remains opt-in.

## 0.1.7 spell results and party hits

Verbose cue tracing starts enabled. Toggle with //grip verbose.
Normal spell completion ends the hum silently. Interruption plays the
former 230 ms landing pulse. Preview with //grip cast then //grip land
or //grip interrupt. //grip stop remains a silent manual stop.
Enemy damage to a nearby party member with a known entity plays one
small tap per action. When the same action hits you, the self cue wins.
Preview with //grip partyhit.

## 0.1.8 weaponskills and continuation windows

Target a living enemy. A party member's damaging weaponskill should play
one weaponskill cue; your own should play two. The charged sweep replaces
the standalone closing cue and repeats during the estimated continuation
window on the selected target. Switch targets, kill the enemy, or wait for
expiry to stop it. Test a follow-up weaponskill to refresh the window.
Timing follows the XIVCrossbar delay and step formula, with its weapon
skill properties table. This standalone estimate tracks party weaponskills.

## 0.1.9 greeting, spell click, and continuation hum

Startup and //grip hello use only the final 810 ms pulse. The same
strength is sustained during the estimated continuation window on the
selected enemy after your or a party member's qualifying weaponskill.
Compare //grip land (35 ms bright click) with //grip interrupt.

## 0.1.10 spell landing

Preview with //grip land. Expect two bright clicks and a short fading hum.
Try //grip cast followed by //grip interrupt. The cast hum should be
replaced immediately by the interruption pulse and should not resume.

## 0.1.11 Trust weaponskills

Category 11 actions from party actors now use the monster ability table.
Target an enemy and let Valaineral open with Uriel Blade. Check for
weaponskill and chain_on, then chain_off at expiry. Repeat with a player
weaponskill to compare. Hostile actors cannot open a tracked window.

## 0.1.12 spell landing tail

The second click flows into a one-second tail at casting-hum strength.
Compare a successful Cure, a fully resisted or no-effect spell, and
an interruption. Only the normal successful landing uses the tail.

## 0.1.13 target window tracking

Window detection runs independently of the party roster and weaponskill tap.
With verbose enabled, diagnostics.log records relevant action IDs and result
messages on the selected enemy. Try Valaineral's Uriel Blade and compare the
Chain input record with chain_on and chain_off. Check that looking away stops
the hum and returning to the target before expiry resumes it.

## 0.1.14 party damage and weaponskill impacts

Try an enemy melee hit, ranged hit, spell, and area attack against a party
member. A single enemy action produces at most one party tap, using the
autoattack pattern. If you also take damage, expect the self-hit cue then
the party tap. Damage must be reported in a recognized action result.

Your landed weaponskill plays three copies of the impact. Use //grip wshits
to mute both self and party weaponskill impacts for the current addon load.
The continuation hum still tracks windows while impacts are muted.

## 0.1.15 staggered party hits

Weaponskill impacts default off. //grip wshits enables them for this load.
An enemy action gives one 60 ms tap per damaged ally, spaced by 90 ms.
When you also take damage, your hit cue queues first. Verbose partyhitN
shows the ally count. //grip partyhit still previews a single tap.

## 0.1.16 overlapping cues

Verbose and weaponskill impacts default off. //grip wsrev previews a
rising rev and hammer strike. //grip wshits enables combat impacts.
Your rev is triggered by the landed result. Party weaponskills retain
the single impact. Try //grip cast then //grip partyhit to feel the mix.
Interruptions stop the casting layer and play their own cue. Each motor
channel sums active patterns and caps at the controller's maximum.
