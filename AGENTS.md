# Agent entry point

Read the current root `WORKFLOW.md` and `TESTING.md` before code changes. Preserve cumulative testing history and the user-confirmed known-good slotpress/casting behavior.

GripRumble is an independent Windower Lua addon with a singleton SDL3/Python DualSense helper. XIVCrossbar is an optional companion: its current experimental slotpress hook writes to a shared events file. Do not assume multi-client routing or reload survival without tests.

Use a development branch for untested work; keep main for verified source. Build installable ZIPs with WORKFLOW.md and TESTING.md inside GripRumble/, and distinguish mock/static verification from live FFXI testing.
