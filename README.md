# GripRumble

Standalone Windower 4 rumble prototype for a USB DualSense controller, built on SDL3 through a small Windows Python helper. GripRumble does not require changes to XIVCrossbar and does not retry or inject failed actions.

**Current testing build:** 0.1.21, November 12, 2026. The source snapshot is published on [`development/0.1.21-chat-style`](https://github.com/rerorriM-Mirrorer/GripRumble/tree/development/0.1.21-chat-style); `main` remains a bootstrap placeholder pending live FFXI acceptance. `//grip chain off|steady|heartbeat` saves its mode using Windower `config` and reloads it on startup; the mode is the only persistent preference in this patch. The other haptic defaults and waveforms are unchanged. The chat-convention changes are locally simulated/static-tested only, not verified in FFXI.

## Installation / update

Extract `GripRumble/` into the Windower `addons` directory. Preserve the folder name. Connect your physical DualSense over USB. Stop the old `bridge.py` helper before replacing it; `SDL3.dll` is shipped with the testing package. On Windows use `Start-Hidden.cmd` for the background helper or `Run-GripRumble.cmd` for a visible console, then `//lua load GripRumble` (or `//lua r GripRumble`). Leave XIVCrossbar's existing installation untouched. The GitHub source repository does not track the prebuilt DLL; source checkouts need the SDL3 3.2.28 x64 runtime beside `bridge.py`. See `docs/DEPENDENCIES.md` for the recorded SHA-256 and upstream download.

The newer slot-press waveform lives in `bridge.py`; restart the helper after updating, not just Lua. For slot-press feedback, the current test-only XIVCrossbar build with its `slotrumble` hook must be installed and loaded in the same Windower client. GripRumble attempts to enable that hook automatically on load. After reloading XIVCrossbar, run `//grip slotpress on` to re-sync its reset-on-reload flag. Only load GripRumble on the intended controller-owning FFXI client. Each loaded instance and each independently enabled XIVCrossbar slot hook can write to the **shared** `events.txt`, including from other clients, because this prototype has no per-client event routing. Use `//xb slotrumble off` in other clients until a client-scoped bridge is available. Re-loading XIVCrossbar after GripRumble can temporarily disable the slot hook even though the helper itself is still running.

## Commands

- `//grip help` — Commands and manual previews.
- `//grip status` — Version and current toggles.
- `//grip slotpress [on|off|test]` — Default ON. Bare command behaves like `on`; enabling or disabling also sends `lua c xivcrossbar slotrumble on|off` if the XIVCrossbar files are installed. `test` plays one knock manually without changing either switch.
- `//grip reject [on|off|test]` — Default OFF. A failed-action double-buzzer for packet `0x029` message `94` (`You must wait longer to perform that action`), with incoming-text fallback and duplicate suppression. `test` plays a manual preview.
- `//grip tp [on|off]` — TP 1,000/2,000/3,000 threshold effects; default OFF. The separate 3,000 TP sustaining loop remains opt-in via `//grip tploop`.
- `//grip chain [steady|heartbeat|off]` — Estimated, selected-target continuation cue. Default `steady` until you save another mode; `heartbeat` repeats a *lub-dub* once per second at 60 BPM; `off` mutes it. The chosen mode now saves per character and survives `//lua r GripRumble`.
- `//grip critical [on|off|1-99|test|partytest]` — Critical health feedback, default ON at 25% HP. A critical self hit gets two strong impacts; a hit on a critical ally uses the existing normal self-hit pattern; your own pet's hits use the self-hit pattern (including a critical tier). `test` previews the critical self impact; `partytest` previews the smaller critical-party impact.
- `//grip verbose` — Per-load diagnostics; default OFF.
- `//grip wshits`, `//grip wsrev` — Optional weaponskill-hit cue and preview; impact cues default OFF.
- `//grip tploop` — Optional repeating 3,000-TP cue; default OFF.
- `//grip restart`, `//grip unload` — Lifecycle commands.
- `//grip hello|cast|land|interrupt|stop|hit|partyhit|pethit|autoattack|shutdown|setswitch|binding` — Manual cue previews (`shutdown` stops the helper).

The addon help and message styles follow shared `WORKFLOW.md` chat conventions, with `//grip help` showing color-coded command examples and `//grip status` showing the active settings.

The skillchain mode is saved via Windower `config` (character settings under the add-on `data` directory); if none is saved, it defaults to `steady`. All **other** toggles remain per addon load: slotpress and critical tiers start ON; reject and TP thresholds start OFF. The new dedicated summon/dismiss cue is removed. Normal summoning spell completion is handled like other spell completions, while dismissing a pet is silent.

**Incoming damage:** The normal self-hit uses the already-max-strength impact; critical self/pet uses a two-hit pattern because simply increasing the motor value is impossible. Health classification is checked approximately 80 ms after the action to allow recent vital updates. This ordering and the 25% cutoff still require live testing, especially across sudden lethal damage, AoE attacks and Trust party members. Critical thresholds should be adjusted with `//grip critical 20` (for example), without editing files.

**Multi-client note:** The current single helper owns the USB controller, but neither `events.txt` nor the earlier direct XIVCrossbar hook tags events with their Windower client or character. This is a known limitation, not fixed in 0.1.19. A future client-scoped event protocol and reload-proof handshake should be implemented as a **narrow companion change** rather than overwriting the latest XIVCrossbar package.

## Skillchain detection and outstanding validation

Skillchain continuation rumble remains *action-packet-derived, estimated timing*, not a guaranteed server notification that a chain is possible. The tracker records only a known skillchain-property action that visibly landed or produced a chain additional effect against a living enemy, then emits `chain_on` only when its tracked window is open **for the current selected target**. A switch to another target without a window should stop the cue. Uriel Blade is not a special timer trigger: its action packets use the same damage/property checks as other qualifying weaponskills. The current window formula typically allows up to ~10 seconds including the initial wait, but real-world eligibility can depend on server timing or other conditions not exposed by the packet. Test Valaineral's Uriel Blade on the selected target and on another target with `//grip verbose` before treating the heuristic as authoritative.

## Cumulative change notes

- **0.1.21 (2026-11-12, local testing):** Updated all GripRumble addon chat output to shared WORKFLOW conventions: mode-0 chat with individually colored heading (167), separators (140), `//grip` prefix and arrows (200), and command syntax (207). Feedback/status remains neutral white after its styled `[GripRumble]` heading. Added explicit commands, usage feedback, and unknown-command response. No haptic events, waveforms, bridge behavior, persistence, or defaults changed. In-game visual verification pending.

- **0.1.20 (2026-11-12, local testing):** Persist the chain mode with Windower `config.load`/`config.save` for the current character. `//grip chain off`, `steady`, and `heartbeat` are remembered across Lua reloads. Other toggles and all helper waveforms are unchanged. Added simulated reload regression. No live FFXI validation yet.

- **0.1.19 (2026-11-11, local testing):** Keep user-approved slotpress, casting, successful/interrupt, damage and party-hit waveforms. Default OFF for action rejection and TP threshold pulses; keep TP loop opt-in. Added 60-BPM optional skillchain heartbeat with mid-window switching; removed avatar summon/dismiss cue. Added own-pet incoming damage as normal self impact, plus 25% critical self/pet double impact and critical-party self-strength impact. Health evaluation waits ~80 ms for vitals refresh. New `tp`, `chain`, `critical` commands, expanded mock regression and bridge static checks. No multi-client shared-event isolation or automatic XB post-reload handshake yet; no live 0.1.19 test.
- **0.1.18 (2026-11-06, local testing):** Slot feedback defaults ON and automatically requests XIVCrossbar's test toggle at load; bare `slotpress` explicitly enables/re-syncs and reports status. Strong two-part recoil waveform replaces the quiet 30 ms tap. Added default-ON failed-action double-buzzer, action-message-94 packet/text observation, duplicate guard, `reject on/off/test`, `slotpress on/off/test`, `status`, `help`, and `restart`. Retained existing chain tracking, overlap mixer, and all previous cues. Current skillchain tracking is still estimated and awaits live Uriel Blade validation.
- **0.1.17:** Added optional test-only XIVCrossbar accepted-slot press cue (30 ms).
- **0.1.16:** Overlapping motor cues; rev + hammer weaponskill preview. Verbose and WS-impact cues default OFF.
- **0.1.15:** Staggered party-hit pulses.
- **0.1.14:** Per-action incoming party hits and optional weaponskill impacts.
- **0.1.13:** Target-specific window diagnostics independent of party roster.
- **0.1.12:** Spell landing click-and-tail.
- **0.1.11:** Trust weaponskill properties, including Valaineral's Uriel Blade.
- **0.1.10–0.1.0:** Earlier prototype feature history and test details preserved in `TESTING.md`.
