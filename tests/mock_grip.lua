-- LOCAL SIMULATION ONLY. LuaTeX Lua 5.4 with Windower API stubs.
-- No Windower, FFXI, dual client, USB or Windows runtime validation.
local root = assert(arg[1], 'addon directory required')
package.path = root .. '/?.lua;' .. package.path
local saved_chain_mode, save_count = nil, 0
package.preload['config'] = function()
    return {
        load = function(defaults)
            return {chain_mode = saved_chain_mode or defaults.chain_mode}
        end,
        save = function(values)
            saved_chain_mode = values.chain_mode
            save_count = save_count + 1
        end,
    }
end
package.preload['chat'] = function()
    -- Use visible markers to assert styles without depending on FFXI control bytes.
    string.color = function(value, color)
        return '<color:' .. tostring(color) .. '>' .. value .. '</color>'
    end
    return {}
end
package.preload['resources'] = function() return {action_messages = {[309]={en='Casts spell on target'}}} end
local native_unpack = string.unpack
package.preload['pack'] = function()
    string.unpack = function(data, kind, offset)
        local sig = kind == 'I' and '<I4' or '<I2'
        return native_unpack(sig, data, offset + 1)
    end
    return true
end
local times = 100
os.clock = function() return times end
local registered, sent, chats, scheduled, chat_modes = {}, {}, {}, {}, {}
local me = {id=7, vitals={tp=2000,hpp=70}}
local selected = 99
local pet_id = 9
local mobs = {
    [7] = {id=7,hpp=70},
    [9] = {id=9,hpp=80},
    [99] = {id=99,spawn_type=16,hpp=100,name='Enemy A'},
    [100] = {id=100,spawn_type=16,hpp=100,name='Enemy B'},
    [500] = {id=500,spawn_type=16,hpp=100,name='Enemy C'},
}
local party_member = {mob={id=8,hpp=80},hpp=80}
windower = {
    addon_path = root .. '/',
    file_exists = function() return true end,
    register_event = function(name, fn) registered[name]=fn end,
    send_command = function(s) sent[#sent+1]=s end,
    add_to_chat = function(mode,line) chats[#chats+1]=line; chat_modes[#chat_modes+1]=mode end,
    ffxi = {
        get_player = function() return me end,
        get_party = function() return {p1=party_member} end,
        get_mob_by_id = function(id) return mobs[id] end,
        get_mob_by_target = function(slot)
            if slot=='t' then return mobs[selected] end
            if slot=='pet' then return mobs[pet_id] end
            return nil
        end,
    }
}
coroutine.schedule = function(fn, delay) scheduled[#scheduled+1]={fn=fn,delay=delay} end
_addon = {}
assert(loadfile(root .. '/GripRumble.lua'))()
local function eq(actual, expected, label)
    assert(actual == expected, ('%s expected %s got %s'):format(label, tostring(expected), tostring(actual)))
end
local function cues()
    local f=io.open(root .. '/events.txt','r')
    if not f then return '' end
    local s=f:read('*a'); f:close()
    return s
end
local function count(s, word)
    local n=0
    for line in s:gmatch('[^\n]+') do if line == word then n=n+1 end end
    return n
end
local function drain_delayed_damage()
    local i=1
    while i <= #scheduled do
        if scheduled[i].delay == 0.08 then
            local task=table.remove(scheduled,i)
            task.fn()
        else i=i+1 end
    end
end
os.remove(root .. '/events.txt')
registered['load']()
local auto_xb_sync = false
for _, task in ipairs(scheduled) do
    if task.delay == 1.0 then task.fn(); auto_xb_sync = true end
end
assert(auto_xb_sync, 'load schedules XB sync')
eq(sent[#sent], 'lua c xivcrossbar slotrumble on', 'automatic XB enable')
registered['addon command']('help')
local help = table.concat(chats, '\n')
assert(help:find('<color:140>--------------------------------------------------</color>',1,true), 'divider uses 140')
assert(help:find('<color:167>GripRumble</color>',1,true), 'help header uses 167')
assert(help:find('<color:200>//grip</color><color:207> chain [steady|heartbeat|off]</color>',1,true), 'command/syntax use 200/207')
assert(help:find('<color:200>-></color> Save skillchain',1,true), 'arrow uses 200, description neutral')
for _, mode in ipairs(chat_modes) do eq(mode, 0, 'chat mode 0 for explicit fragment colors') end
local before_unknown = #chats
registered['addon command']('not_a_command')
assert(chats[before_unknown+1]:find('Unknown command: not_a_command.',1,true), 'bad command reports error before help')
registered['addon command']('slotpress','unexpected')
assert(chats[#chats]:find('<color:200>//grip</color><color:207> slotpress [on|off|test]</color>',1,true), 'usage styling')
registered['addon command']('status')
assert(chats[#chats-2]:find('Reject: OFF',1,true), 'rejection defaults off')
assert(chats[#chats-2]:find('TP thresholds: OFF',1,true), 'TP thresholds default off')
assert(chats[#chats-1]:find('Critical: ON at 25%% HP'), 'critical enabled')
registered['addon command']('slotpress','off')
eq(sent[#sent], 'lua c xivcrossbar slotrumble off','XB off')
registered['addon command']('slotpress')
eq(sent[#sent], 'lua c xivcrossbar slotrumble on','bare reenables XB')
registered['addon command']('slotpress','test')
eq(count(cues(),'slotpress'),1,'preview once')
registered['incoming text']('You must wait longer to perform that action.')
eq(count(cues(),'reject'),0,'reject defaults off')
registered['addon command']('reject','on')
local packet=string.rep('\0',5)..string.pack('<I4I4',7,99)..string.rep('\0',12)..string.pack('<I2',94)..string.rep('\0',5)
registered['incoming chunk'](0x029,packet)
registered['incoming text']('You must wait longer to perform that action.')
eq(count(cues(),'reject'),1,'packet+text deduplicated')
registered['addon command']('reject','off')
times=101
registered['incoming text']('You must wait longer to perform that action.')
eq(count(cues(),'reject'),1,'reject off again')
registered['tp change'](2100,500)
eq(count(cues(),'tp2000'),0,'thresholds default off')
registered['addon command']('tp','on')
registered['tp change'](2100,500)
eq(count(cues(),'tp2000'),1,'thresholds on')
registered['addon command']('tp','off')
registered['tp change'](2100,500)
eq(count(cues(),'tp2000'),1,'thresholds off')
-- Existing casting/landing/interruption are the cherished known-good patterns.
registered['action']({actor_id=7,category=8,param=24931,targets={}})
eq(count(cues(),'cast'),1,'local casting preserved')
registered['action']({actor_id=7,category=4,param=1,targets={{id=7,actions={{message=309,param=0}}}}})
eq(count(cues(),'land'),1,'successful spell preserved')
registered['action']({actor_id=7,category=8,param=24931,targets={}})
registered['action']({actor_id=7,category=8,param=28787,targets={}})
eq(count(cues(),'interrupt'),1,'casting interruption preserved')
registered['action']({actor_id=8,category=8,param=24931,targets={}})
eq(count(cues(),'cast'),2,'another party member casting does not make a local cast cue')
-- Valaineral landed Uriel Blade estimate starts after initial delay.
times=200
registered['action']({actor_id=8,category=13,param=2273,targets={{id=99,actions={{message=1,param=200}}}}})
registered['prerender']()
eq(count(cues(),'chain_on'),0,'no cue before window')
times=204
registered['prerender']()
eq(count(cues(),'chain_on'),1,'tracked window')
registered['addon command']('chain','heartbeat')
eq(count(cues(),'chain_heartbeat_on'),1,'heartbeat on while open')
eq(count(cues(),'chain_off'),1,'stops old steady loop')
registered['addon command']('chain','off')
eq(count(cues(),'chain_off'),2,'stops heartbeat')
eq(saved_chain_mode, 'off', 'chain off is persisted')
registered['addon command']('chain','steady')
eq(count(cues(),'chain_on'),2,'steady resumes')
eq(saved_chain_mode, 'steady', 'chain steady persisted')
selected=100
registered['prerender']()
eq(count(cues(),'chain_off'),4,'changing target stops loop')
registered['action']({actor_id=8,category=13,param=2273,targets={{id=100,actions={{message=1,param=0}}}}})
times=207
registered['prerender']()
eq(count(cues(),'chain_on'),2,'missed Uriel not tracked')
-- New avatar no longer triggers arrival/departure cue.
local before = cues()
pet_id=nil
registered['prerender']()
pet_id=9
registered['prerender']()
eq(cues(),before,'no summon/dismiss cue')
-- Damage: own normal, pet normal, party critical; no duplicate pet as party member.
party_member.hpp=20
registered['action']({actor_id=500,category=1,param=1,targets={
    {id=7,actions={{message=1,param=100}}},
    {id=9,actions={{message=1,param=100}}},
    {id=8,actions={{message=1,param=100}}},
}})
drain_delayed_damage()
eq(count(cues(),'hit'),2,'own and pet match')
eq(count(cues(),'partyhits:c'),1,'critical ally gets self-strength hit')
-- Crit severity is evaluated after the short health-update delay.
registered['action']({actor_id=500,category=1,param=1,targets={
    {id=7,actions={{message=1,param=100}}},
    {id=9,actions={{message=1,param=100}}},
    {id=8,actions={{message=1,param=100}}},
}})
me.vitals.hpp=20
mobs[9].hpp=20
party_member.hpp=75
drain_delayed_damage()
eq(count(cues(),'criticalhit'),2,'critical self and pet')
eq(count(cues(),'partyhits:n'),1,'normal ally')
registered['addon command']('critical','off')
registered['action']({actor_id=500,category=1,param=1,targets={{id=7,actions={{message=1,param=100}}}}})
drain_delayed_damage()
eq(count(cues(),'hit'),3,'critical off uses normal self hit')
registered['addon command']('critical','25')
assert(chats[#chats]:find('25%% HP'), 'set threshold command')
registered['addon command']('critical','test')
eq(count(cues(),'criticalhit'),3,'critical manual self preview')
registered['addon command']('critical','partytest')
eq(count(cues(),'partyhits:c'),2,'critical party preview')
-- Simulate a full Lua reload after changing the mode. Only the saved chain
-- mode survives; other per-load defaults are deliberately unchanged.
registered['addon command']('chain','off')
eq(saved_chain_mode, 'off', 'saved off before reload')
assert(loadfile(root .. '/GripRumble.lua'))()
registered['addon command']('status')
assert(chats[#chats-2]:find('Chain: off',1,true), 'off survives reload')
assert(chats[#chats-2]:find('Reject: OFF',1,true), 'other defaults survive reload')
-- Under a new active Uriel Blade window, OFF still silences the cue.
local old_chain_on = count(cues(),'chain_on')
local old_heartbeat_on = count(cues(),'chain_heartbeat_on')
selected=99
times=300
registered['action']({actor_id=8,category=13,param=2273,targets={{id=99,actions={{message=1,param=210}}}}})
times=304
registered['prerender']()
eq(count(cues(),'chain_on'),old_chain_on,'off after reload silences steady')
eq(count(cues(),'chain_heartbeat_on'),old_heartbeat_on,'off after reload silences heartbeat')
registered['addon command']('chain','heartbeat')
eq(saved_chain_mode,'heartbeat','saved heartbeat after reload')
assert(loadfile(root .. '/GripRumble.lua'))()
registered['addon command']('status')
assert(chats[#chats-2]:find('Chain: heartbeat',1,true), 'heartbeat survives reload')
registered['addon command']('chain','steady')
eq(saved_chain_mode,'steady','saved steady after reload')
assert(save_count >= 5, 'every explicit chain change is saved')
print('PASS simulated GripRumble: reload persistence, XB sync/defaults, reject, TP toggle, skillchain rhythm, avatar removal, pet damage, critical self/party')
os.remove(root .. '/events.txt')
