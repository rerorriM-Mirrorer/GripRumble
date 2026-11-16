"""Static pattern and event-routing checks; does not exercise SDL or USB."""
import ast
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / 'bridge.py').read_text()
ast.parse(source)
tree = ast.parse(source)
values = {}
for node in tree.body:
    if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
        if node.targets[0].id in {'HEARTBEAT_PATTERN','EXTRA_CUES','PATTERNS',
                                  'FOLLOW_FAR_PATTERN','FOLLOW_LOST_PATTERN','FOLLOW_TIMEOUT'}:
            try:
                values[node.targets[0].id] = ast.literal_eval(node.value)
            except (ValueError, TypeError):
                pass
heartbeat = values['HEARTBEAT_PATTERN']
assert sum(duration for _,_,duration in heartbeat) == 1000, 'heartbeat needs 1 second cycle'
assert heartbeat[0][:2] == heartbeat[2][:2] == (2500,6500), 'steady motor strength'
assert heartbeat[1][:2] == heartbeat[3][:2] == (0,0), 'clear lub-dub gaps'
assert values['EXTRA_CUES'][b'slotpress'] == [(38000,47000,45),(0,0,35),(21000,30000,55)], 'slotpress unchanged'
assert values['EXTRA_CUES'][b'criticalhit'][-1][2] == 180
# Execute only the pure builder, never import the SDL/Windows driver on Linux.
pattern_func = next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='make_party_damage_pattern')
fn_tree = ast.fix_missing_locations(ast.Module(body=[pattern_func], type_ignores=[]))
namespace = {'PATTERNS': {'x3': ('Self',[(65535,65535,200)])},'party_tap':[(6500,19000,60)]}
exec(compile(fn_tree, '<party-pattern>', 'exec'), namespace)
make = namespace['make_party_damage_pattern']
assert make(b'n') == [(6500,19000,60)]
assert make(b'c') == [(65535,65535,200)]
assert make(b'nc') == [(6500,19000,60),(0,0,90),(65535,65535,200)]
assert make(b'cn') == [(65535,65535,200),(0,0,90),(6500,19000,60)]
assert make(b'') is None and make(b'n'*6) is None and make(b'!') is None

assert 'b"avatar":' not in source, 'old avatar cue should be absent'
assert 'b"chain_heartbeat_on": HEARTBEAT_PATTERN' in source
assert 'b"chain_off": (b"chain_on", b"chain_heartbeat_on")' in source

# 0.1.22 triggerpull: lighter and shorter than slotpress, other motor from setswitch.
cues = values['EXTRA_CUES']
trigger, slot = cues[b'triggerpull'], cues[b'slotpress']
assert max(max(lo, hi) for lo, hi, _ in trigger) < min(max(lo, hi) for lo, hi, ms in slot if lo or hi)
assert sum(ms for *_, ms in trigger) < sum(ms for *_, ms in slot)
assert cues[b'setswitch'] == [(0, 10000, 35)] and cues[b'binding'] == [(0,12000,35),(0,0,65),(3500,15000,45)], 'set/binding unchanged'
assert trigger[0][0] > trigger[0][1] and cues[b'setswitch'][0][0] == 0, 'trigger low motor vs setswitch high motor'
far, lost = values['FOLLOW_FAR_PATTERN'], values['FOLLOW_LOST_PATTERN']
assert sum(ms for *_, ms in far) == 1000 and sum(ms for *_, ms in lost) == 500, '0.1.23 tempo'
assert max(hi for _, hi, _ in lost) > max(hi for _, hi, _ in far), 'lost stronger than far'

# Simulate run_bridge with a fake clock, file and motor; no SDL is loaded.
import tempfile
run_node = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'run_bridge')
helpers = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in {'sample_pattern'}]
class Clock:
    t = 1000.0
    def monotonic(self): return self.t
    def sleep(self, seconds): self.t += seconds
clock = Clock()
outputs = []
folder = Path(tempfile.mkdtemp())
events_path = folder / 'events.txt'
script = []  # (time, line or callable)
def pump():
    while script and script[0][0] <= clock.t:
        _, action = script.pop(0)
        if callable(action):
            action()
        else:
            with events_path.open('ab') as f: f.write(action + b'\n')
def rumble(pad, low, high, ms):
    outputs.append((round(clock.t - 1000, 2), low, high))
    return True
ns = {'__file__': str(folder / 'bridge.py'), 'Path': Path, 'time': clock, 'pump': pump, 'rumble': rumble,
      'error': lambda: b'', 'print': lambda *a, **k: None}
for name in ('EXTRA_CUES','PATTERNS','HEARTBEAT_PATTERN','FOLLOW_FAR_PATTERN','FOLLOW_LOST_PATTERN','FOLLOW_TIMEOUT'):
    ns[name] = values[name]
ns['PATTERNS'] = {k: tuple(v) for k, v in values['PATTERNS'].items()}
ns['PATTERNS']['cx'] = ('Cast sweep', [(0, 0, 100)] * 3)
exec(compile(ast.fix_missing_locations(ast.Module(body=helpers + [run_node], type_ignores=[])), '<run>', 'exec'), ns)
events_path.write_bytes(b'old\n' * 3)
def at(t, item): script.append((1000 + t, item))
at(0.1, b'follow_far_on')
at(1.2, b'follow_far_on')       # refresh mid-gap must not restart the tug
at(5.0, b'follow_lost_on')
at(5.6, b'follow_off')
at(6.0, b'follow_far_on')
at(37.0, lambda: events_path.write_bytes(b''))   # file emptied while running
at(37.5, b'triggerpull')
at(38.0, b'shutdown')
ns['run_bridge'](None)
def motor_at(t):
    current = (0, 0)
    for when, lo, hi in outputs:
        if when <= t: current = (lo, hi)
    return current
assert motor_at(0.15) == (3000, 9000), 'far tug starts'
assert motor_at(1.25) == (0, 0), 'refresh did not restart the tug'
assert motor_at(2.15) == (3000, 9000), 'far rhythm continues on its own beat'
assert motor_at(5.05) == (12000, 18000), 'lost replaces far'
assert motor_at(5.65) == (0, 0), 'follow_off stops lost'
assert motor_at(6.05) == (3000, 9000)
assert motor_at(36.2) == (0, 0), 'unrefreshed follow loop stops after FOLLOW_TIMEOUT'
assert motor_at(37.52) == (9000, 4000), 'reads a truncated events file from the start'
print('PASS helper static: unchanged slotpress/setswitch/binding, triggerpull lighter, follow loops, refresh, timeout, truncation, 60-BPM heartbeat, critical self/party, avatar removed, loop cleanup')
