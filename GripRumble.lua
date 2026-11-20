_addon.name = 'GripRumble'
_addon.version = '0.1.24'
_addon.commands = {'griprumble', 'grip'}

local config = require('config')
-- Windower chat helpers install string.color(). Use chat mode 0 so every
-- message uses explicit segment colors rather than one color for the line.
require('chat')
-- Chain rhythm and the follow distance are saved per character. Other haptic
-- switches keep their established per-load defaults.
-- follow_distance 0 means the follow watch is off; follow_last remembers the
-- distance that a bare //grip distance or //grip distance on turns back on.
local FOLLOW_MIN, FOLLOW_MAX, FOLLOW_DEFAULT = 5, 50, 30
-- cast_rumble / land_rumble (0.1.24): your own casting hum and spell-landed
-- pulse, both ON by default so the known-good behavior is unchanged.
local persistent_defaults = {chain_mode = 'steady', follow_distance = 0, follow_last = FOLLOW_DEFAULT,
    cast_rumble = true, land_rumble = true}
local persistent = config.load(persistent_defaults)
local chain_mode = (persistent.chain_mode == 'off'
    or persistent.chain_mode == 'heartbeat'
    or persistent.chain_mode == 'steady') and persistent.chain_mode or 'steady'

-- Saved values arrive from XML; accept only whole numbers in range.
local function valid_distance(value)
    value = tonumber(value)
    if value and value >= FOLLOW_MIN and value <= FOLLOW_MAX and value == math.floor(value) then
        return value
    end
    return nil
end
local follow_distance = valid_distance(persistent.follow_distance) or 0
local follow_last = valid_distance(persistent.follow_last) or FOLLOW_DEFAULT
-- XML may hand back booleans or the strings 'true'/'false'.
local function saved_flag(value)
    return not (value == false or value == 'false')
end
local cast_rumble = saved_flag(persistent.cast_rumble)
local land_rumble = saved_flag(persistent.land_rumble)

local verbose = false
-- Per-load settings. XIVCrossbar now saves its own slot cue setting, so
-- GripRumble no longer forces it at load. slot_override is nil until
-- //grip slotpress on|off sends XIVCrossbar a this-load-only override.
local slot_override = nil
local reject_enabled = false
local tp_threshold_enabled = false
local critical_enabled = true
local critical_threshold = 25
local last_reject_at = -100000
local starting = false
local folder = windower.addon_path
local function chat_raw(message)
    windower.add_to_chat(0, message)
end

local function chat(message)
    chat_raw(string.color('[GripRumble]', 167) .. ' ' .. tostring(message))
end

local function chat_command(syntax, description)
    -- Each help line has the colored addon prefix, syntax, arrow, and plain
    -- description prescribed by the shared WORKFLOW.md addon conventions.
    chat_raw('  ' .. string.color('//grip', 200)
        .. string.color(' ' .. syntax, 207)
        .. ' ' .. string.color('->', 200) .. ' ' .. description)
end

local function chat_usage(syntax)
    chat('Usage: ' .. string.color('//grip', 200)
        .. string.color(' ' .. syntax, 207))
end

local casting = false
local tp_loop = false
local weaponskill_hits = false
require('pack') -- Decodes the 0x029 action rejection message without injecting packets.
local action_messages = require('resources').action_messages
local function deals_damage(result)
    if not result.param or result.param <= 0 then return false end
    if result.message == 1 or result.message == 67 then return true end
    local message = action_messages[result.message]
    local english = message and (message.en or message.english) or ''
    english = english:lower()
    return english:find('point[s]? of damage') ~= nil
        or english:find('hp drained from', 1, true) ~= nil
end

-- XIVCrossbar writes its cues straight into events.txt, so on/off lives in
-- XIVCrossbar: GripRumble can only ask it to change. Changed in 0.1.22:
-- nothing is sent at load any more. XIVCrossbar keeps its own saved
-- per-character cue settings (//xb rumble), and the old load-time
-- 'slotrumble on' re-enabled the slot cue even when it was saved OFF.
-- Commands are sent only when you type a //grip command, from this client.
local function xivcrossbar_installed()
    return windower.file_exists(folder .. '../xivcrossbar/xivcrossbar.lua')
end

local function send_xivcrossbar(command)
    if not xivcrossbar_installed() then return false end
    windower.send_command('lua c xivcrossbar ' .. command)
    return true
end

local function emit(cue)
    local file = io.open(windower.addon_path .. 'events.txt', 'a')
    if not file then
        chat('Cannot write events.txt.')
        return
    end
    file:write(cue, '\n')
    file:close()
    if verbose and cue ~= 'probe' then
        chat('Cue: ' .. cue)
        local log = io.open(folder .. 'diagnostics.log', 'a')
        if log then
            log:write(os.date('%H:%M:%S'), ' cue ', cue, '\n')
            log:close()
        end
    end
end

-- Both incoming packet 0x029 and the printed game message may report the
-- same refusal. One physical buzzer per rejection, not two.
local function on_rejected_action()
    if not reject_enabled then return end
    local now = os.clock()
    if now - last_reject_at < 0.3 then return end
    last_reject_at = now
    emit('reject')
end

-- Failsafe uses the same 0x029 fields. Message 94 means exactly
-- 'You must wait longer to perform that action.' /attack is covered too,
-- even though Failsafe itself does not retry that command.
windower.register_event('incoming chunk', function(id, original)
    if id ~= 0x029 or type(original) ~= 'string' or #original < 27 then return end
    local player = windower.ffxi.get_player()
    if not player then return end
    local actor = original:unpack('I', 0x05)
    local target = original:unpack('I', 0x09)
    local message = original:unpack('H', 0x19) % 32768
    if message == 94 and (actor == player.id or target == player.id) then
        on_rejected_action()
    end
end)

windower.register_event('incoming text', function(original, modified)
    local line = 'You must wait longer to perform that action'
    if (type(original) == 'string' and original:find(line, 1, true))
        or (type(modified) == 'string' and modified:find(line, 1, true)) then
        on_rejected_action()
    end
end)

local chain_skills = require('chain_skills')
local windows = {}
local chain_active = false
local function chain_start_cue()
    return chain_mode == 'heartbeat' and 'chain_heartbeat_on' or 'chain_on'
end

-- Party members normally have both a percentage and a live mob entry. Keep
-- their IDs, not party slots, when carrying hits across an action callback.
local function party_member(id)
    local party = windower.ffxi.get_party()
    for index = 1, 5 do
        local member = party and party['p' .. index]
        if member and member.mob and member.mob.id == id then return member end
    end
    return nil
end
local function party_contains(id)
    return party_member(id) ~= nil
end

local function hit_is_critical(id, player)
    if not critical_enabled then return false end
    local hpp
    if id == player.id then
        hpp = player.vitals and player.vitals.hpp
        if hpp == nil then
            local self_mob = windower.ffxi.get_mob_by_id(player.id)
            hpp = self_mob and self_mob.hpp
        end
    else
        local party = party_member(id)
        if party then
            hpp = party.hpp or (party.mob and party.mob.hpp)
        else
            local pet = windower.ffxi.get_mob_by_target('pet')
            if pet and pet.id == id then hpp = pet.hpp end
        end
    end
    return type(hpp) == 'number' and hpp >= 0 and hpp <= critical_threshold
end

-- A short post-hit observation allows the client to apply a health update
-- received alongside an action packet before choosing the critical pattern.
-- Exact ordering still requires live Windower validation.
-- Since 0.1.24 your own pet is one of party_ids, so its hits use the
-- party taps (critical tier included) instead of the self-hit impact.
local function report_damage(player, self_hit, party_ids)
    if self_hit then emit(hit_is_critical(player.id, player) and 'criticalhit' or 'hit') end
    if #party_ids > 0 then
        local pattern = {}
        for _, id in ipairs(party_ids) do
            pattern[#pattern + 1] = hit_is_critical(id, player) and 'c' or 'n'
        end
        emit('partyhits:' .. table.concat(pattern))
    end
end

local function track_weaponskill(action, player)
    local own = action.actor_id == player.id
    local category, id = action.category, action.param
    local ability
    if category == 3 then
        ability = chain_skills.weapon_skills[id] or chain_skills.monster_abilities[id]
    elseif category == 11 or category == 13 then
        ability = chain_skills.monster_abilities[id] or chain_skills.weapon_skills[id]
    elseif category == 4 then
        -- Spells can confirm a chain via their result, but their ordinary
        -- properties depend on buffs the standalone tracker does not track.
        ability = nil
    end
    local selected = verbose and windower.ffxi.get_mob_by_target('t')
    local landed = false
    local now = os.clock()
    for _, target in ipairs(action.targets) do
        local enemy = windower.ffxi.get_mob_by_id(target.id)
        if enemy and enemy.spawn_type == 16 then
            for _, result in ipairs(target.actions) do
                local message = result.has_add_effect and result.add_effect_message or 0
                local chained = (message >= 288 and message <= 301)
                    or (message >= 385 and message <= 397) or (message >= 767 and message <= 770)
                local damage = deals_damage(result) or ((result.message == 185 or result.message == 187
                    or result.message == 317 or result.message == 802) and result.param > 0)
                if selected and selected.id == target.id and (category ~= 4 or chained) then
                    local trace = ('Chain input actor=%s category=%s action=%s message=%s extra=%s known=%s')
                        :format(action.actor_id, category, id, result.message, message, tostring(ability ~= nil))
                    local log = io.open(folder .. 'diagnostics.log', 'a')
                    if log then
                        log:write(os.date('%H:%M:%S'), ' ', trace, '\n')
                        log:close()
                    end
                end
                if chained or damage then
                    landed = true
                    if chained or (ability and ability.skillchain and #ability.skillchain > 0) then
                        local previous = windows[target.id]
                        local step = chained and ((previous and previous.expires > now and previous.step or 1) + 1) or 1
                        local opens = now + (ability and ability.delay or 3)
                        if step > 5 or message >= 767 then
                            windows[target.id] = nil
                        else
                            windows[target.id] = {opens = opens, expires = opens + 8 - step, step = step}
                        end
                    end
                    break
                end
            end
        end
    end
    if weaponskill_hits and landed and category ~= 4 and (own or party_contains(action.actor_id)) then
        emit(own and 'weaponskill_self' or 'weaponskill')
    end
end

-- Party follow watch -------------------------------------------------------
-- FFXI only draws and updates characters within about 50 yalms. A party
-- member in your zone but beyond that has no live position: Windower either
-- has no mob entry for them or keeps their last, stale position, which
-- reads 50 or more yalms away. Both count as 'lost'. A member closer than
-- that but farther than your chosen distance is 'far'.
local FOLLOW_LOST_YALMS = 49.5
local FOLLOW_HYSTERESIS = 2     -- must come this much closer to clear 'far'
local FOLLOW_SETTLE = 1.5       -- seconds a far/lost state must hold before it rumbles
local FOLLOW_CLEAR_SETTLE = 0.5 -- seconds 'everyone back' must hold (0.1.23: clears within 1 s)
local FOLLOW_REFRESH = 10       -- re-send an active state so the helper keeps it
local FOLLOW_ZONE_GRACE = 10    -- seconds after zoning while everyone loads in
local FOLLOW_POLL = 0.25
local follow_state = 'ok'       -- what is currently rumbling: ok, far or lost
local follow_candidate, follow_candidate_since = 'ok', 0
local follow_flagged = {}       -- member name -> true while beyond the distance
local follow_next_poll, follow_next_refresh = 0, 0
local follow_quiet_until = 0
-- //grip hush silences the current level until everyone is back in range.
-- It holds the rank that was rumbling: hushing 'far' still lets 'lost'
-- through, hushing 'lost' silences both. 0 means nothing is hushed.
local FOLLOW_RANK = {ok = 0, far = 1, lost = 2}
local follow_hushed = 0
local function follow_audible(state)
    return FOLLOW_RANK[state] > follow_hushed
end

-- Read one member's situation: 'ok', 'far', 'lost', or nil when the member
-- is not in your zone (zoned elsewhere, offline) and so is not watched.
local function member_follow_state(member, zone, threshold, was_flagged)
    if not member or member.zone ~= zone then return nil end
    local mob = member.mob
    if not mob or type(mob.distance) ~= 'number' then return 'lost', nil end
    local yalms = math.sqrt(mob.distance) -- Windower reports distance squared.
    if yalms >= FOLLOW_LOST_YALMS then return 'lost', yalms end
    local limit = was_flagged and threshold - FOLLOW_HYSTERESIS or threshold
    if yalms > limit then return 'far', yalms end
    return 'ok', yalms
end

local function follow_cue(state)
    return state == 'lost' and 'follow_lost_on' or 'follow_far_on'
end

-- Stop any follow rumble. quietly skips the all-clear tick (used for off,
-- zoning, cutscenes and unload, where nobody actually caught up).
-- The all-clear tick still plays after a hush: it tells you they caught up.
local function follow_stop(quietly)
    if follow_state ~= 'ok' then
        emit('follow_off')
        if not quietly then emit('follow_ok') end
    end
    follow_state = 'ok'
    follow_candidate = 'ok'
    follow_flagged = {}
    follow_hushed = 0
end

local function follow_poll(now)
    if follow_distance == 0 then return end
    if now < follow_next_poll then return end
    follow_next_poll = now + FOLLOW_POLL
    local player = windower.ffxi.get_player()
    local info = windower.ffxi.get_info()
    -- Status 4 is an event or cutscene; members are often hidden then.
    if not player or not info or info.mog_house or player.status == 4 or now < follow_quiet_until then
        follow_stop(true)
        return
    end
    local party = windower.ffxi.get_party()
    local worst = 'ok'
    local flagged = {}
    for index = 1, 5 do
        local member = party and party['p' .. index]
        local name = member and member.name or ('p' .. index)
        local state = member_follow_state(member, info.zone, follow_distance, follow_flagged[name])
        if state == 'lost' or state == 'far' then
            flagged[name] = true
            if state == 'lost' or worst == 'ok' then worst = state end
        end
    end
    follow_flagged = flagged
    if worst ~= follow_candidate then
        follow_candidate, follow_candidate_since = worst, now
    end
    local settle = follow_candidate == 'ok' and FOLLOW_CLEAR_SETTLE or FOLLOW_SETTLE
    if follow_candidate ~= follow_state and now - follow_candidate_since >= settle then
        if follow_candidate == 'ok' then
            follow_stop(false)
        else
            follow_state = follow_candidate
            if follow_audible(follow_state) then
                emit(follow_cue(follow_state))
                follow_next_refresh = now + FOLLOW_REFRESH
            end
            if verbose then chat('Follow: ' .. follow_state .. '.') end
        end
    elseif follow_state ~= 'ok' and follow_audible(follow_state) and now >= follow_next_refresh then
        emit(follow_cue(follow_state))
        follow_next_refresh = now + FOLLOW_REFRESH
    end
end

local function reset()
    windows = {}
    chain_active = false
    casting = false
    -- The helper's 'reset' clears every loop, follow included.
    follow_state, follow_candidate, follow_flagged = 'ok', 'ok', {}
    follow_hushed = 0
    follow_quiet_until = os.clock() + FOLLOW_ZONE_GRACE
    emit('reset')
end

local function start_helper()
    local launcher = folder:gsub('/', '\\') .. 'Start-Hidden.cmd'
    local ok, result = pcall(os.execute, 'start "" /min cmd.exe /d /c call "' .. launcher .. '"')
    if not ok or (result ~= true and result ~= 0) then
        chat('Could not launch helper. Run Start-Hidden.cmd or check bridge.log.')
    end
end

local function await_helper(attempt)
    if not starting then return end
    local ack = io.open(folder .. 'ready.ack', 'r')
    if ack then
        ack:close()
        os.remove(folder .. 'ready.ack')
        starting = false
        emit('hello')
    elseif attempt < 20 then
        if attempt == 2 then start_helper() end
        emit('probe')
        coroutine.schedule(function() await_helper(attempt + 1) end, 0.5)
    else
        starting = false
        chat('Helper did not respond. Check bridge.log.')
    end
end

windower.register_event('load', function()
    os.remove(folder .. 'ready.ack')
    starting = true
    await_helper(0)
    -- Give party members a moment to appear before the follow watch judges.
    follow_quiet_until = os.clock() + FOLLOW_ZONE_GRACE
end)
windower.register_event('unload', function()
    starting = false
    follow_stop(true)
    emit('shutdown')
end)
windower.register_event('zone change', reset)
windower.register_event('logout', reset)

windower.register_event('tp change', function(new, old)
    if tp_loop and (old >= 3000) ~= (new >= 3000) then
        emit(new >= 3000 and 'tp_loop_on' or 'tp_loop_off')
    end
    if not tp_threshold_enabled then return end
    for threshold = 3000, 1000, -1000 do
        if old < threshold and new >= threshold then
            emit('tp' .. threshold)
            return
        end
    end
end)

windower.register_event('action', function(action)
    local player = windower.ffxi.get_player()
    if not player then return end
    if action.category == 3 or action.category == 11 or action.category == 13 or action.category == 4 then
        track_weaponskill(action, player)
    end
    if action.actor_id == player.id then
        if action.category == 8 then
            if action.param == 28787 then
                casting = false
                emit('interrupt')
            elseif action.param == 24931 then
                casting = true
                -- casting stays tracked when the hum is off, so a later
                -- 'stop' still clears any hum a preview may have started.
                if cast_rumble then emit('cast') end
            end
        elseif action.category == 4 then
            casting = false
            local landed = false
            for _, target in ipairs(action.targets) do
                for _, result in ipairs(target.actions) do
                    local message = result.message
                    if message == 252 or message == 265 or message == 268
                        or message == 274 or message == 275 then
                        emit('stop')
                        emit('burst')
                        return
                    end
                    local resource = action_messages[message]
                    local english = resource and (resource.en or resource.english) or ''
                    english = english:lower()
                    if english ~= '' and not english:find('no effect', 1, true)
                        and not english:find('resist', 1, true)
                        and not english:find('misses', 1, true)
                        and not english:find('fails', 1, true)
                        and not english:find('absorbs', 1, true) then
                        landed = true
                    end
                end
            end
            -- With the landed pulse off, the silent 'stop' still ends the hum.
            emit((landed and land_rumble) and 'land' or 'stop')
        end
    else
        local actor = windower.ffxi.get_mob_by_id(action.actor_id)
        if not actor or actor.spawn_type ~= 16 then return end
        local self_hit = false
        local party_ids = {}
        local pet = windower.ffxi.get_mob_by_target('pet')
        local pet_target_id = pet and pet.id
        for _, target in ipairs(action.targets) do
            local is_self = target.id == player.id
            local is_pet = pet_target_id and target.id == pet_target_id
            local is_party = not is_self and not is_pet and party_contains(target.id)
            if is_self or is_pet or is_party then
                for _, result in ipairs(target.actions) do
                    if deals_damage(result) then
                        if is_self then
                            self_hit = true
                            if verbose then
                                chat(('Incoming damage category %d, message %d.'):format(action.category, result.message))
                            end
                        else
                            -- Party members and, since 0.1.24, your pet.
                            party_ids[#party_ids + 1] = target.id
                        end
                        break
                    end
                end
            end
        end
        if self_hit or #party_ids > 0 then
            -- Capture IDs, not the mutable 'action' table.
            coroutine.schedule(function()
                local current = windower.ffxi.get_player()
                if current and current.id == player.id then
                    report_damage(current, self_hit, party_ids)
                end
            end, 0.08)
        end
    end
end)

windower.register_event('status change', function(status)
    if casting and (status == 2 or status == 3) then
        casting = false
        emit('stop')
    end
end)

windower.register_event('prerender', function()
    local now = os.clock()
    follow_poll(now)
    for id, window in pairs(windows) do
        if now >= window.expires then windows[id] = nil end
    end
    local target = windower.ffxi.get_mob_by_target('t')
    local window = target and target.hpp > 0 and windows[target.id]
    local open = window ~= nil and window ~= false and now >= window.opens
    if open ~= chain_active then
        chain_active = open
        if open then
            if chain_mode ~= 'off' then emit(chain_start_cue()) end
        else
            emit('chain_off')
        end
    end
end)

local function follow_description()
    if follow_distance == 0 then return 'OFF' end
    local hushed = follow_state ~= 'ok' and not follow_audible(follow_state)
    return ('%d yalms (%s%s)'):format(follow_distance, follow_state, hushed and ', hushed' or '')
end

local function show_status()
    local slot = slot_override == nil and 'XB saved'
        or ((slot_override and 'ON' or 'OFF') .. ' this load')
    chat(('v%s | Slot: %s | Reject: %s | TP thresholds: %s | Chain: %s')
        :format(_addon.version, slot,
            reject_enabled and 'ON' or 'OFF', tp_threshold_enabled and 'ON' or 'OFF', chain_mode))
    chat(('Cast: %s | Land: %s | Critical: %s at %d%% HP | WS hits: %s | TP loop: %s | Verbose: %s')
        :format(cast_rumble and 'ON' or 'OFF', land_rumble and 'ON' or 'OFF',
            critical_enabled and 'ON' or 'OFF', critical_threshold,
            weaponskill_hits and 'ON' or 'OFF', tp_loop and 'ON' or 'OFF',
            verbose and 'ON' or 'OFF'))
    chat('Follow distance: ' .. follow_description() .. '. XIVCrossbar cues: '
        .. string.color('//xb rumble', 200) .. ' shows which are on.')
end

local function show_help()
    chat_raw(string.color('--------------------------------------------------', 140))
    chat_raw(string.color('GripRumble', 167) .. ' - Commands')
    chat_command('help', 'Show this list of commands.')
    chat_command('status', 'Show current settings and version.')
    chat_command('slotpress [on|off|test]', 'XB slot cue for this load only; test plays the knock.')
    chat_command('triggerpull [on|off]', 'Save XB trigger cue on/off; bare previews it.')
    chat_command('setswitch [on|off]', 'Save XB set-change cue on/off; bare previews it.')
    chat_command('binding [on|off]', 'Save XB binding cue on/off; bare previews it.')
    chat_command('distance [on|off|5-50|test|check]', 'Party follow rumble (saved; bare toggles).')
    chat_command('hush', 'Silence follow rumble until everyone is back in range.')
    chat_command('cast [on|off|test]', 'Casting hum (saved; default ON); bare previews it.')
    chat_command('land [on|off|test]', 'Spell-landed pulse (saved; default ON); bare previews it.')
    chat_command('reject [on|off|test]', 'Failed-action buzzer (default OFF).')
    chat_command('tp [on|off]', 'TP threshold cues (default OFF).')
    chat_command('chain [steady|heartbeat|off]', 'Save skillchain feedback per character; 60 BPM heartbeat.')
    chat_command('critical [on|off|1-99|test|partytest]', 'Critical HP damage feedback (default ON, 25%).')
    chat_command('verbose', 'Toggle diagnostic messages.')
    chat_command('wshits', 'Toggle weaponskill hit feedback (default OFF).')
    chat_command('tploop', 'Toggle sustained 3000 TP cue (default OFF).')
    chat_command('wsrev', 'Preview the weaponskill impact.')
    chat_command('restart', 'Reload the GripRumble Lua addon.')
    chat_command('unload', 'Unload the GripRumble Lua addon.')
    chat_command('<cue>', 'Preview hello, interrupt, stop, hit, partyhit,')
    chat_raw('      pethit, autoattack, or shutdown.')
    chat_raw(string.color('--------------------------------------------------', 140))
end

-- XIVCrossbar cue names in its //xb rumble command, keyed by GripRumble cue.
local xb_cues = {
    triggerpull = {xb = 'trigger', label = 'Trigger pull'},
    setswitch = {xb = 'set', label = 'Set change'},
    binding = {xb = 'bind', label = 'Binding'},
}

-- //grip triggerpull|setswitch|binding [on|off|test]. Bare or test previews
-- (setswitch and binding were bare previews before 0.1.22). on/off asks
-- XIVCrossbar to save that cue for this character; nothing is sent at load,
-- so several clients never write XIVCrossbar's settings at once.
local function handle_xb_cue(cue, option)
    local entry = xb_cues[cue]
    if not option or option == 'test' then
        emit(cue)
        chat(entry.label .. ' preview sent.')
    elseif option == 'on' or option == 'off' then
        if send_xivcrossbar('rumble ' .. entry.xb .. ' ' .. option) then
            chat(entry.label .. ' cue ' .. option:upper() .. ' requested from XIVCrossbar (saved there).')
        else
            chat('XIVCrossbar was not found beside GripRumble; nothing changed.')
        end
    else
        chat_usage(cue .. ' [on|off|test]')
    end
end

-- //grip cast|land [on|off|test]. Bare or test previews, as before 0.1.24.
local spell_switches = {
    cast = {key = 'cast_rumble', label = 'Casting hum'},
    land = {key = 'land_rumble', label = 'Spell-landed pulse'},
}

local function handle_spell_switch(cue, option)
    local entry = spell_switches[cue]
    if not option or option == 'test' then
        emit(cue)
        if cue == 'cast' then
            -- The hum is a loop; end the preview after a moment.
            coroutine.schedule(function() if not casting then emit('stop') end end, 1.5)
        end
        chat(entry.label .. ' preview sent.')
    elseif option == 'on' or option == 'off' then
        local enabled = option == 'on'
        if entry.key == 'cast_rumble' then
            cast_rumble = enabled
            if not enabled and casting then emit('stop') end
        else
            land_rumble = enabled
        end
        persistent[entry.key] = enabled
        local saved, err = pcall(config.save, persistent)
        chat(entry.label .. ' rumble ' .. option:upper() .. '.'
            .. (saved and ' Saved for this character.'
                or ' WARNING: could not save setting: ' .. tostring(err)))
    else
        chat_usage(cue .. ' [on|off|test]')
    end
end

local function save_follow()
    persistent.follow_distance = follow_distance
    persistent.follow_last = follow_last
    local saved, err = pcall(config.save, persistent)
    return saved and ' Saved for this character.' or ' WARNING: could not save setting: ' .. tostring(err)
end

local function set_follow(distance)
    if distance == 0 then
        follow_stop(true)
    else
        follow_last = distance
    end
    follow_distance = distance
    follow_next_poll = 0
    local note = save_follow()
    if distance == 0 then
        chat('Follow distance rumble OFF.' .. note)
    else
        chat(('Follow distance rumble ON: soft past %d yalms, stronger when out of sight.'):format(distance) .. note)
    end
end

-- //grip distance check: one line per party member, for tuning and for
-- confirming in game how far Windower can still see someone.
local function follow_check()
    local info = windower.ffxi.get_info()
    local party = windower.ffxi.get_party()
    local any = false
    for index = 1, 5 do
        local member = party and party['p' .. index]
        if member then
            any = true
            local state, yalms = member_follow_state(member, info and info.zone, follow_distance > 0 and follow_distance or follow_last, false)
            local detail
            if state == nil then
                detail = 'other zone (not watched)'
            elseif yalms then
                detail = ('%.1f yalms - %s'):format(yalms, state)
            else
                detail = 'same zone, no position - lost'
            end
            chat(('%s: %s'):format(member.name or ('p' .. index), detail))
        end
    end
    if not any then chat('No party members to watch.') end
end

-- //grip hush (also //grip distance hush): a quick, unsaved snooze for the
-- current alert. The watch keeps running and re-arms once everyone is back.
local function follow_hush()
    if follow_distance == 0 then
        chat('Follow distance rumble is OFF.')
    elseif follow_state == 'ok' or not follow_audible(follow_state) then
        chat('No follow rumble to hush.')
    else
        follow_hushed = FOLLOW_RANK[follow_state]
        emit('follow_off')
        chat(follow_state == 'far'
            and 'Follow hushed until everyone is back; out of sight still rumbles.'
            or 'Follow hushed until everyone is back in range.')
    end
end

local function handle_distance(option)
    local yalms = tonumber(option)
    if not option then
        set_follow(follow_distance == 0 and follow_last or 0)
    elseif option == 'on' then
        set_follow(follow_last)
    elseif option == 'off' or yalms == 0 then
        set_follow(0)
    elseif option == 'test' then
        emit('follow_preview')
        chat('Follow preview sent: far tug, out-of-sight knock, then all clear.')
    elseif option == 'check' then
        follow_check()
    elseif option == 'hush' then
        follow_hush()
    elseif valid_distance(yalms) then
        set_follow(yalms)
    else
        chat_usage('distance [on|off|5-50|test|check]')
    end
end

windower.register_event('addon command', function(cue, option)
    cue = cue and cue:lower() or 'help'
    option = option and option:lower()
    if cue == 'slotpress' then
        if option == 'test' then
            emit('slotpress')
            chat('Slot-press knock preview sent.')
        elseif not option or option == 'on' or option == 'off' then
            -- XIVCrossbar's slotrumble is a this-load-only override; it is
            -- never saved, and //xb rumble slot on|off clears it.
            slot_override = option ~= 'off'
            local xb_found = send_xivcrossbar('slotrumble ' .. (slot_override and 'on' or 'off'))
            chat('Slot-press rumble ' .. (slot_override and 'ON' or 'OFF') .. ' for this load.'
                .. (xb_found and ' Use //xb rumble slot on|off to save it.'
                    or ' XIVCrossbar was not found beside GripRumble.'))
        else
            chat_usage('slotpress [on|off|test]')
        end
    elseif xb_cues[cue] then
        handle_xb_cue(cue, option)
    elseif spell_switches[cue] then
        handle_spell_switch(cue, option)
    elseif cue == 'distance' then
        handle_distance(option)
    elseif cue == 'hush' then
        follow_hush()
    elseif cue == 'reject' then
        if option == 'test' then
            emit('reject')
            chat('Rejection buzzer preview sent.')
        elseif not option or option == 'on' or option == 'off' then
            reject_enabled = option ~= 'off'
            chat('Failed-action rumble ' .. (reject_enabled and 'ON' or 'OFF') .. '.')
        else
            chat_usage('reject [on|off|test]')
        end
    elseif cue == 'tp' then
        if not option or option == 'on' or option == 'off' then
            tp_threshold_enabled = option ~= 'off'
            chat('TP threshold rumbles ' .. (tp_threshold_enabled and 'ON' or 'OFF') .. '.')
        else
            chat_usage('tp [on|off]')
        end
    elseif cue == 'chain' then
        if not option then
            chat('Skillchain window: ' .. chain_mode .. ' (heartbeat = 60 BPM).')
        elseif option == 'steady' or option == 'heartbeat' or option == 'off' then
            if chain_mode ~= option then
                if chain_active then emit('chain_off') end
                chain_mode = option
                if chain_active and chain_mode ~= 'off' then emit(chain_start_cue()) end
            end
            persistent.chain_mode = chain_mode
            local saved, err = pcall(config.save, persistent)
            chat('Skillchain window rumble: ' .. chain_mode .. '.'
                .. (saved and ' Saved for this character.'
                    or ' WARNING: could not save setting: ' .. tostring(err)))
        else
            chat_usage('chain [steady|heartbeat|off]')
        end
    elseif cue == 'critical' then
        local percent = tonumber(option)
        if option == 'test' then
            emit('criticalhit')
            chat('Critical self-impact preview sent.')
        elseif option == 'partytest' then
            emit('partyhits:c')
            chat('Critical-party impact preview sent (normal self-hit strength).')
        elseif option == 'on' or option == 'off' then
            critical_enabled = option == 'on'
            chat('Critical damage rumbles ' .. (critical_enabled and 'ON' or 'OFF') .. '.')
        elseif percent and percent >= 1 and percent <= 99 and percent == math.floor(percent) then
            critical_threshold = percent
            critical_enabled = true
            chat(('Critical damage rumbles ON at %d%% HP.'):format(critical_threshold))
        elseif not option then
            chat(('Critical damage: %s at %d%% HP.'):format(critical_enabled and 'ON' or 'OFF', critical_threshold))
        else
            chat_usage('critical [on|off|1-99|test|partytest]')
        end
    elseif cue == 'status' then
        show_status()
    elseif cue == 'help' then
        show_help()
    elseif cue == 'restart' then
        chat('Restarting GripRumble.')
        windower.send_command('lua r GripRumble')
    elseif cue == 'wsrev' then
        emit('weaponskill_self')
    elseif cue == 'wshits' then
        weaponskill_hits = not weaponskill_hits
        chat(weaponskill_hits and 'Weaponskill impact cues enabled.' or 'Weaponskill impact cues disabled.')
    elseif cue == 'tploop' then
        tp_loop = not tp_loop
        local player = windower.ffxi.get_player()
        local tp = player and player.vitals and player.vitals.tp or 0
        emit(tp_loop and tp >= 3000 and 'tp_loop_on' or 'tp_loop_off')
        chat(tp_loop and '3,000 TP loop enabled for this load.' or '3,000 TP loop disabled.')
    elseif cue == 'unload' then
        chat('Unloading GripRumble.')
        windower.send_command('lua unload GripRumble')
    elseif cue == 'verbose' then
        verbose = not verbose
        chat(verbose and 'Diagnostics enabled.' or 'Diagnostics disabled.')
    elseif cue == 'hello' or cue == 'stop'
        or cue == 'interrupt' or cue == 'partyhit' or cue == 'hit' or cue == 'pethit' or cue == 'autoattack' or cue == 'shutdown' then
        emit(cue)
    else
        chat('Unknown command: ' .. cue .. '.')
        show_help()
    end
end)
