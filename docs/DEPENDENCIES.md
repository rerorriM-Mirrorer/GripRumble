# Runtime dependencies

GripRumble's Python helper loads SDL3 through `ctypes`. The 0.1.21 testing ZIP includes the prebuilt Windows x64 runtime DLL beside `bridge.py`.

- **Runtime:** SDL3 3.2.28, Windows x64
- **Bundled DLL SHA-256:** `55f17c87b32e07ef46365d604131c063014e4e47ce58da9ec061720ddfb90d82`
- **Official upstream package:** [SDL3-3.2.28-win32-x64.zip](https://www.libsdl.org/release/SDL3-3.2.28-win32-x64.zip)

The Git source branch intentionally does not track this prebuilt binary. For a source checkout, obtain the matching official SDL3 x64 package, extract `SDL3.dll`, and place it beside `bridge.py`. Verify the DLL hash above before using it. The supplied 0.1.21 testing ZIP already contains the bundled DLL.
