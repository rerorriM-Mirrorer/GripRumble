"""Static pattern and event-routing checks; does not exercise SDL or USB."""
import ast
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / 'bridge.py').read_text()
ast.parse(source)
tree = ast.parse(source)
values = {}
for node in tree.body:
    if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
        if node.targets[0].id in {'HEARTBEAT_PATTERN','EXTRA_CUES','PATTERNS'}:
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
print('PASS helper static: unchanged slotpress, 60-BPM heartbeat, distinct critical self/party, avatar removed, loop cleanup')
