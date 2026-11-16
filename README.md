# GripRumble

Standalone Windower 4 rumble prototype for a USB DualSense controller, built on SDL3 through a small Windows Python helper. GripRumble does not require changes to XIVCrossbar and does not retry or inject failed actions.

**Current testing build:** 0.1.23, November 16, 2026, on `development/0.1.23-follow-tempo`. Faster follow rhythms, a quicker all-clear, and `//grip hush`. Simulated/static tests only. **Known good (`main`):** 0.1.22, confirmed working well in game by the user on November 16, 2026.

## Installation / update

Extract `GripRumble/` into the Windower `addons` directory. Preserve the folder name. Connect your physical DualSense over USB. Stop the old `bridge.py` helper before replacing it; `SDL3.dll` is shipped with the testing package. On Windows use `Start-Hidden.cmd` for the background helper or `Run-GripRumble.cmd` for a visible console, then `//lua load GripRumble` (or `//lua r GripRumble`). Leave XIVCrossbar's existing installation untouched. The GitHub source repository does not track the prebuilt DLL; source checkouts need the SDL3 3.2.28 x64 runtime beside `bridge.py`. See `docs/DEPENDENCIES.md` for the recorded SHA-256 and upstream download.

Waveforms live in `bridge.py`: restart the helper after updating, not just the Lua addon. XIVCrossbar sends its cues (slot press, trigger pull, set change, binding) straight into `GripRumble/events.txt`, and each one is switched on or off **in XIVCrossbar** and saved per character there: `//xb rumble` lists them and `//xb rumble <slot|trigger|set|bind|all> <on|off>` saves one. Since 0.1.22 GripRumble sends nothing to XIVCrossbar when it loads, so a cue you saved OFF stays OFF. Only load GripRumble on the controller-owning client. XIVCrossbar writes trigger, set and binding cues only from the client that has focus; its slot cue still comes from any client that accepted the press.

## Commands

- `//grip help` — Commands and manual previews.
- `//grip status` — Version and current toggles.
- `//grip slotpress [on|off|test]` — A this-load-only override of XIVCrossbar's slot cue (sends `lua c xivcrossbar slotrumble on|off`; bare means `on`). It is never saved; use `//xb rumble slot on|off` to save. `test` plays one knock.
- `//grip triggerpull [on|off|test]`, `//grip setswitch [on|off|test]`, `//grip binding [on|off|test]` — Bare or `test` previews the rumble. `on`/`off` asks XIVCrossbar to save that cue for this character (`//xb rumble trigger|set|bind on|off`). Nothing is sent automatically.
- `//grip hush` (or `//grip distance hush`) — Silence the current follow rumble until everyone is back in range; not saved. Hushing a far alert still lets an out-of-sight alert through.
- `//grip distance [on|off|5-50|test|check]` — Party follow rumble, saved per character, default OFF. A number turns it on at that many yalms; `0` or `off` turns it off; `on` restores the last distance (30 the first time); bare toggles. `test` previews both levels; `check` lists each party member's distance and state.
- `//grip reject [on|off|test]` — Default OFF. A failed-action double-buzzer for packet `0x029` message `94` (`You must wait longer to perform that action`), with incoming-text fallback and duplicate suppression. `test` plays a manual preview.
- `//grip tp [on|off]` — TP 1,000/2,000/3,000 threshold effects; default OFF. The separate 3,000 TP sustaining loop remains opt-in via `//grip tploop`.
- `//grip chain [steady|heartbeat|off]` — Estimated, selected-target continuation cue. Default `steady` until you save another mode; `heartbeat` repeats a *lub-dub* once per second at 60 BPM; `off` mutes it. The chosen mode now saves per character and survives `//lua r GripRumble`.
- `//grip critical [on|off|1-99|test|partytest]` — Critical health feedback, default ON at 25% HP. A critical self hit gets two strong impacts; a hit on a critical ally uses the existing normal self-hit pattern; your own pet's hits use the self-hit pattern (including a critical tier). `test` previews the critical self impact; `partytest` previews the smaller critical-party impact.
- `//grip verbose` — Per-load diagnostics; default OFF.
- `//grip wshits`, `//grip wsrev` — Optional weaponskill-hit cue and preview; impact cues default OFF.
- `//grip tploop` — Optional repeating 3,000-TP cue; default OFF.
- `//grip restart`, `//grip unload` — Lifecycle commands.
- `//grip hello|cast|land|interrupt|stop|hit|partyhit|pethit|autoattack|shutdown` — Manual cue previews (`shutdown` stops the helper).

The addon help and message styles follow shared `WORKFLOW.md` chat conventions, with `//grip help` showing color-coded command examples and `//grip status` showing the active settings.

The skillchain mode and follow distance are saved via Windower `config` (character settings under the add-on `data` directory); if nothing is saved, chain is `steady` and follow distance is OFF. All **other** GripRumble toggles remain per addon load: critical tiers start ON; reject and TP thresholds start OFF. XIVCrossbar's cue switches are saved by XIVCrossbar, not GripRumble. The new dedicated summon/dismiss cue is removed. Normal summoning spell completion is handled like other spell completions, while dismissing a pet is silent.

**Follow distance:** Four times a second GripRumble checks your party members (not alliance) who are in your zone. Someone beyond your distance but still visible gets a soft tug every second. Someone in your zone the game can no longer see gets a firmer double knock every half second; FFXI only draws and updates characters within about 50 yalms, so past that Windower has no position or only a stale one (read as 50+ yalms). The strongest state among your members wins. When everyone is back within range, the rumble stops with one soft tick. A member must come 2 yalms inside your distance to clear, a far or out-of-sight state must hold 1.5 seconds before it rumbles, the all-clear comes within about a second, and nothing rumbles during cutscenes, in the Mog House, or for 10 seconds after zoning or loading. Members in another zone are ignored. Use `//grip distance check` in game to see what GripRumble sees.

**Incoming damage:** The normal self-hit uses the already-max-strength impact; critical self/pet uses a two-hit pattern because simply increasing the motor value is impossible. Health classification is checked approximately 80 ms after the action to allow recent vital updates. This ordering and the 25% cutoff still require live testing, especially across sudden lethal damage, AoE attacks and Trust party members. Critical thresholds should be adjusted with `//grip critical 20` (for example), without editing files.

**Multi-client note:** The current single helper owns the USB controller, but neither `events.txt` nor the earlier direct XIVCrossbar hook tags events with their Windower client or character. This is a known limitation, not fixed in 0.1.19. A future client-scoped event protocol and reload-proof handshake should be implemented as a **narrow companion change** rather than overwriting the latest XIVCrossbar package.

## Skillchain detection and outstanding validation

Skillchain continuation rumble remains *action-packet-derived, estimated timing*, not a guaranteed server notification that a chain is possible. The tracker records only a known skillchain-property action that visibly landed or produced a chain additional effect against a living enemy, then emits `chain_on` only when its tracked window is open **for the current selected target**. A switch to another target without a window should stop the cue. Uriel Blade is not a special timer trigger: its action packets use the same damage/property checks as other qualifying weaponskills. The current window formula typically allows up to ~10 seconds including the initial wait, but real-world eligibility can depend on server timing or other conditions not exposed by the packet. Test Valaineral's Uriel Blade on the selected target and on another target with `//grip verbose` before treating the heuristic as authoritative.

## Cumulative change notes

- **0.1.23 (2026-11-16, local testing):** Follow tug every 1 s (was 2 s) and out-of-sight double knock every 0.5 s (was 1.5 s). All-clear after 0.5 s back in range, checked every 0.25 s (was 1.5 s / 0.5 s). Added `//grip hush` / `//grip distance hush`. Other waveforms unchanged.
- **0.1.22 (2026-11-16, local testing):** Added `triggerpull` (one 30 ms soft low-motor detent) for XIVCrossbar's L2/R2 and shoulder-bank cue. Added `//grip triggerpull|setswitch|binding [on|off|test]`; `on`/`off` forward to XIVCrossbar's saved `//xb rumble` settings. Removed the load-time `slotrumble on` so XIVCrossbar's saved slot setting is respected; `//grip slotpress on|off` remains a this-load override. Added saved `//grip distance` party follow rumble with far and out-of-sight levels, all-clear tick, `test` and `check`. Helper: follow loops time out after 30 s without a refresh from the addon, and the helper re-reads `events.txt` from the start if the file is emptied while it runs. Slotpress, setswitch, binding and all other waveforms unchanged.

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
