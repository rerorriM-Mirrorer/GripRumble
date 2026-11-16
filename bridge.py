import ctypes as c
from pathlib import Path
import time
import msvcrt

if c.sizeof(c.c_void_p) != 8:
    raise SystemExit("Use 64-bit Windows Python with this x64 SDL3.dll.")
# Hold the lock until the process exits, including when started visibly.
lock = Path(__file__).with_name("bridge.lock").open("a+b")
try:
    lock.seek(0)
    msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
except OSError:
    raise SystemExit("GripRumble helper is already running.")

sdl = c.CDLL(str(Path(__file__).with_name("SDL3.dll").resolve()))

def bind(name, result, *args):
    fn = getattr(sdl, name)
    fn.restype, fn.argtypes = result, args
    return fn

init = bind("SDL_Init", c.c_bool, c.c_uint32)
hint = bind("SDL_SetHint", c.c_bool, c.c_char_p, c.c_char_p)
pads = bind("SDL_GetGamepads", c.POINTER(c.c_uint32), c.POINTER(c.c_int))
open_pad = bind("SDL_OpenGamepad", c.c_void_p, c.c_uint32)
vendor = bind("SDL_GetGamepadVendor", c.c_uint16, c.c_void_p)
product = bind("SDL_GetGamepadProduct", c.c_uint16, c.c_void_p)
rumble = bind("SDL_RumbleGamepad", c.c_bool, c.c_void_p,
              c.c_uint16, c.c_uint16, c.c_uint32)
pump = bind("SDL_PumpEvents", None)
close = bind("SDL_CloseGamepad", None, c.c_void_p)
free = bind("SDL_free", None, c.c_void_p)
quit_sdl = bind("SDL_Quit", None)
error = bind("SDL_GetError", c.c_char_p)

def ramp(start, end, duration):
    return [(round(start + (end - start) * i / 11), 0, duration // 12)
            for i in range(12)]

PATTERNS = {
    "m2": ("Spell interrupted", [(8000, 34000, 230)]),
    "x3": ("Enemy hit", [(65535, 65535, 200)]),
    "x8": ("Sweep", [(65535, 0, 60), (65535, 65535, 45), (0, 65535, 60)]),
    "x9": ("Decay", [(65535, 65535, 50), (33000, 12000, 60),
                     (16000, 4000, 70), (7000, 0, 90)]),
}
PATTERNS["cx"] = ("Cast sweep", ramp(1800, 5500, 600) + [(lo // 4, hi // 4, ms) for lo, hi, ms in PATTERNS["x8"][1]])

# 60 BPM: one paired lub-dub per second at the steady loop's same amplitude.
HEARTBEAT_PATTERN = [(2500, 6500, 110), (0, 0, 170),
                     (2500, 6500, 140), (0, 0, 580)]

# Party follow watch (0.1.22). The addon decides the state; these only say
# how each state feels. "far" is one soft tug every second; "lost" (same
# zone, beyond the game's ~50-yalm sight range) is a firmer double knock
# every half second (0.1.23 tempo, user-requested). far shares the chain
# heartbeat's 1-second tempo but is a single lighter tug, not a lub-dub. FOLLOW_TIMEOUT stops a follow loop the addon stopped refreshing
# (for example if FFXI closed without unloading GripRumble).
FOLLOW_FAR_PATTERN = [(3000, 9000, 80), (0, 0, 920)]
FOLLOW_LOST_PATTERN = [(12000, 18000, 90), (0, 0, 110),
                       (12000, 18000, 90), (0, 0, 210)]
FOLLOW_TIMEOUT = 30

EXTRA_CUES = {
    b'tp1000': [(3500, 14000, 45), (0, 0, 70), (5000, 20000, 55)],
    b'tp2000': [(4000, 13000, 40), (0, 0, 55), (6500, 19000, 40), (0, 0, 55), (14000, 25000, 75)],
    b'tp3000': [(8000, 26000, 40), (0, 0, 55), (13000, 38000, 40), (0, 0, 55), (28000, 50000, 75)],
    b'weaponskill': [(10000, 0, 235), (0, 0, 25), (10000, 0, 235)],
    b'skillchain': [(10000, 0, 620)],
    # Existing self impact is already full scale; critical adds a second solid thump.
    b'criticalhit': [(65535, 65535, 200), (0, 0, 55), (65535, 65535, 180)],
    b'burst': [(10000, 0, 800)],
    b'setswitch': [(0, 10000, 35)],
    # Firm initial knock, followed by a distinct softer recoil after the button travel.
    b'slotpress': [(38000, 47000, 45), (0, 0, 35), (21000, 30000, 55)],
    # Two low/rough pulses for a server-rejected action.
    b'reject': [(41000, 21000, 75), (0, 0, 60), (44000, 22000, 90)],
    b'binding': [(0, 12000, 35), (0, 0, 65), (3500, 15000, 45)],
    # XIVCrossbar L2/R2 (or enabled L1/R1 bank) raising a bar: one short, soft
    # low-motor detent. Lighter and shorter than slotpress, and on the other
    # motor from the high-motor setswitch tick so the two stay distinct.
    b'triggerpull': [(9000, 4000, 30)],
    # Everyone back inside the follow distance: one soft fading tick.
    b'follow_ok': [(0, 6000, 60), (0, 3000, 60)],
    b'autoattack': [(6500, 19000, 60)],
    b'pethit': [(65535, 65535, 200)],
}

party_tap = EXTRA_CUES[b"autoattack"]
EXTRA_CUES[b"partyhit"] = party_tap
for count in range(1, 6):
    EXTRA_CUES[f"partyhit{count}".encode()] = (party_tap + [(0, 0, 90)]) * (count - 1) + party_tap
# //grip distance test: one far tug, one lost double knock, then the all-clear.
EXTRA_CUES[b"follow_preview"] = (FOLLOW_FAR_PATTERN[:1] + [(0, 0, 600)]
                                 + FOLLOW_LOST_PATTERN[:3] + [(0, 0, 600)]
                                 + EXTRA_CUES[b"follow_ok"])
EXTRA_CUES[b"weaponskill_self"] = [
    (2800, 0, 95), (5200, 0, 80), (8800, 2000, 65),
    (14000, 5500, 50), (0, 0, 30), (58000, 49000, 75),
    (14000, 3500, 70),
]

def make_party_damage_pattern(damage_pattern):
    """Ordered party-only taps. 'c' equals a normal self hit, not the self-critical double hit."""
    if not damage_pattern or len(damage_pattern) > 5 or any(kind not in b'nc' for kind in damage_pattern):
        return None
    taps = []
    for index, kind in enumerate(damage_pattern):
        if index:
            taps.append((0, 0, 90))
        taps.extend(PATTERNS['x3'][1] if kind == ord('c') else party_tap)
    return taps

def sample_pattern(steps, elapsed, loop=False):
    if loop:
        elapsed %= sum(ms for _, _, ms in steps)
    for low, high, ms in steps:
        if elapsed < ms:
            return low, high
        elapsed -= ms
    return None

def run_bridge(pad):
    path = Path(__file__).with_name("events.txt")
    path.touch(exist_ok=True)
    offset = path.stat().st_size
    pending = b""
    active = []
    sustained = {}
    refreshed = {}
    previous = (0, 0)
    refresh = 0
    greeting = [(2500, 6500, 810)]
    hum = (0, 1100)
    one_shots = {
        **EXTRA_CUES,
        b"hello": greeting,
        b"hit": PATTERNS["x3"][1],
        b"land": [(1500, 23000, 35), (0, 0, 45),
                  (1500, 19000 + hum[1], 35), (*hum, 1000)],
        b"interrupt": PATTERNS["m2"][1],
    }
    loops = {b"cast": [(*hum, 250)], b"chain_on": greeting,
             b"chain_heartbeat_on": HEARTBEAT_PATTERN,
             b"tp_loop_on": PATTERNS["cx"][1][-3:],
             b"follow_far_on": FOLLOW_FAR_PATTERN,
             b"follow_lost_on": FOLLOW_LOST_PATTERN}
    follow_loops = (b"follow_far_on", b"follow_lost_on")
    stop_events = {b"land": b"cast", b"interrupt": b"cast", b"stop": b"cast",
                   b"chain_off": (b"chain_on", b"chain_heartbeat_on"), b"tp_loop_off": b"tp_loop_on",
                   b"follow_off": follow_loops}
    print("Ready. Load GripRumble on one Windower client. Ctrl+C stops.", flush=True)
    try:
        while True:
            pump()
            now = time.monotonic()
            # If events.txt was replaced or emptied while the helper runs,
            # start reading the new file from its beginning instead of
            # waiting forever for it to grow past the old offset.
            if path.stat().st_size < offset:
                offset = 0
                pending = b""
            with path.open("rb") as events:
                events.seek(offset)
                pending += events.read()
                offset = events.tell()
            lines = pending.split(b"\n")
            pending = lines.pop()
            for raw in lines:
                event = raw.strip()
                if event == b"shutdown":
                    return
                if event == b"probe":
                    path.with_name("ready.ack").touch()
                    continue
                if event == b"reset":
                    active.clear()
                    sustained.clear()
                if event in stop_events:
                    targets = stop_events[event]
                    for target in (targets if isinstance(targets, tuple) else (targets,)):
                        sustained.pop(target, None)
                # A rhythm switch cannot leave the previous rhythm playing.
                if event == b'chain_on':
                    sustained.pop(b'chain_heartbeat_on', None)
                elif event == b'chain_heartbeat_on':
                    sustained.pop(b'chain_on', None)
                if event in follow_loops:
                    # The addon repeats the current follow state every few
                    # seconds. A repeat only renews the timeout; it must not
                    # restart the rhythm mid-beat.
                    refreshed[event] = now
                    for other in follow_loops:
                        if other != event:
                            sustained.pop(other, None)
                    if event in sustained:
                        print(event.decode(errors="replace"), flush=True)
                        continue
                if event in loops:
                    sustained[event] = now
                if event.startswith(b'partyhits:'):
                    taps = make_party_damage_pattern(event[len(b'partyhits:'):])
                    if taps:
                        active.append((now, taps))
                elif event in one_shots:
                    active.append((now, one_shots[event]))
                print(event.decode(errors="replace"), flush=True)

            if b"cast" in sustained and now - sustained[b"cast"] >= 120:
                del sustained[b"cast"]
            for event in follow_loops:
                if event in sustained and now - refreshed.get(event, 0) >= FOLLOW_TIMEOUT:
                    del sustained[event]
            low = high = 0
            continuing = []
            for started, steps in active:
                sample = sample_pattern(steps, (now - started) * 1000)
                if sample is not None:
                    low += sample[0]
                    high += sample[1]
                    continuing.append((started, steps))
            active = continuing
            for event, started in sustained.items():
                sample = sample_pattern(loops[event], (now - started) * 1000, loop=True)
                low += sample[0]
                high += sample[1]
            mixed = min(low, 65535), min(high, 65535)
            if mixed != previous or (mixed != (0, 0) and now >= refresh):
                if not rumble(pad, *mixed, 120 if any(mixed) else 0):
                    raise SystemExit(error().decode(errors="replace") or "Rumble failed")
                previous = mixed
                refresh = now + .06
            time.sleep(.01)
    finally:
        rumble(pad, 0, 0, 0)
        print("GripRumble helper stopped.", flush=True)

hint(b"SDL_JOYSTICK_ENHANCED_REPORTS", b"auto")
if not init(0x2000):
    raise SystemExit(error().decode(errors="replace"))

count = c.c_int()
ids = pads(c.byref(count))
try:
    if not ids:
        raise SystemExit(error().decode(errors="replace") or "No gamepad detected.")
    for i in range(count.value):
        pad = open_pad(ids[i])
        if not pad:
            continue
        try:
            if (vendor(pad), product(pad)) not in {(0x054C, 0x0CE6), (0x054C, 0x0DF2)}:
                continue
            run_bridge(pad)
            break
        finally:
            close(pad)
    else:
        raise SystemExit("No physical DualSense or DualSense Edge found. Check the USB data cable.")
finally:
    free(ids)
    quit_sdl()
