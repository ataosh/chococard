bit = require('bit')
local itemdata  = require 'ffxi.itemdata';
local breader = require 'bitreader';
local chat  = require 'chat';

addon.name     = 'chococard'
addon.author   = 'Ivaar, ported by secare'
addon.version  = '0.1.0'
addon.commands = {'chococard', 'cc'}

local chocobo = {
    plan        = {[0]='A','B','C','D'},
    rank        = {[0]='Poor(F)','Substandard(E)','A bit deficient(D)','Average(C)','Better than average(B)','Impressive(A)','Outstanding(S)','First-class(SS)'},
    ability     = {[0]='None','Gallop','Canter','Burrow','Bore','Auto-Regen','Treasure Finder'},
    temperament = {[0]='Very easygoing','Rather ill-tempered','Very patient chocobo','Quite sensitive','Rather enigmatic'},
    gender      = {[0]='Male','Female'},
    color       = {[0]='Yellow','Black','Blue','Red','Green'},
    size        = {[0]='Galka','Hume(M)','Hume(F)','Elvaan(M)','Elvaan(F)','Tarutaru(M)','Tarutaru(F)','Mithra'},
    weather     = {
        [0]     = {prefers='Clear days',        dislikes='None'},
        [1]     = {prefers='Hot, sunny days',   dislikes='Rainy days'},
        [2]     = {prefers='Rainy days',        dislikes='Thunderstorms'},
        [3]     = {prefers='Sandstorms',        dislikes='Windy days'},
        [4]     = {prefers='Windy days',        dislikes='Snowy days'},
        [5]     = {prefers='Snowy days',        dislikes='Hot, sunny days'},
        [6]     = {prefers='Thunderstorms',     dislikes='Sandstorms'},
        [7]     = {prefers='Auroras',           dislikes='Dark days'},
        [8]     = {prefers='Dark days',         dislikes='Auroras'},
        [9]     = {prefers='None',              dislikes='None'},
        [10]    = {prefers='Cloudy days',       dislikes='None'},
    }
}

local map_fields = function(key, ...)
    return T{...}:map(function(v) return chocobo[key][v] end)
end

local fields = {}

fields.egg = {
    DNA         = {'b3b3b3', 0x00,        fn=map_fields+{'color'}},
    ability     = {'b4',     0x01, 1},
    unknown1    = {'b1',     0x01, 5},
    plan        = {'b2',     0x01, 6},
    unknown2    = {'b15',    0x02},
    is_bred     = {'q',      0x03, 7},
}

fields.card = {
    STR         = {
        value   = {'C',      0x00+1},
        legs    = {'q',      0x00},
        rp      = {'b4',     0x00, 1,   fn=math.mult+{2}},
        rank    = {'b3',     0x00, 5},
    },
    END         = {
        value   = {'C',      0x01+1},
        tail    = {'q',      0x01},
        rp      = {'b4',     0x01, 1,   fn=math.mult+{2}},
        rank    = {'b3',     0x01, 5},
    },
    DSC         = {
        value   = {'C',      0x02+1},
        head    = {'q',      0x02},
        rp      = {'b4',     0x02, 1,   fn=math.mult+{2}},
        rank    = {'b3',     0x02, 5},
    },
    RCP         = {
        value   = {'C',      0x03+1},
        rp      = {'b5',     0x03},
        rank    = {'b3',     0x03, 5},
    },
    DNA         = {'b3b3b3', 0x04,        fn=map_fields+{'color'}},
    abilities   = {'b4b4',   0x05, 1,   fn=map_fields+{'ability'}},
    temperament = {'b3',     0x06, 1},
    weather     = {'b4',     0x06, 4},
    gender      = {'b1',     0x07},
    color       = {'b3',     0x07, 1},
    size        = {'b3',     0x07, 4},
    unknown     = {'b1',     0x07, 7},  -- body?
    name        = {'A',      0x0C},
}

local last = {
    [0x05B] = '',
    [0x033] = '',
    [0x034] = '',
    [0x05C] = '',
    [0x05D] = '',
}

local lookup = function(fn, key, ...)
    if fn then
        return fn(...)
    end
    if chocobo[key] then
        return chocobo[key][...]
    end
    return ...
end

function unpack_choc(str, format, bytepos, bitpos)
    if format == 'C' then --unsigned char
        return struct.unpack('B', str, bytepos)
    elseif format == 'A' then --get signature
        return itemdata.parse_signature(str, 0x0C)
    elseif format == 'q' then --boolean
        local reader = breader:new()
        reader:set_data(str)
        reader:set_pos(bytepos)
        if bitpos ~= nil then
            reader:read(bitpos)
        end
        return (reader:read(1) ~= 0)
    elseif string.match(format, "b%d") ~= nil then -- return bits
        local bitstrings = {} 
        local reader = breader:new()
        reader:set_data(str)
        reader:set_pos(bytepos)
        if bitpos ~= nil then
            reader:read(bitpos)
        end
        for i,v in ipairs(numbits(format)) do
            local len = tonumber(v)
            bitstrings[i] = reader:read(len)
        end
        return unpack(bitstrings)
    end
end

function numbits(format)
    local t = {}
    for str in string.gmatch(format, "([^b]+)") do
        table.insert(t, str)
    end
    return t
end

function decode_chocobo(type, str)
    local tab = {}
    for i,t in pairs(fields[type]) do
        if t[1] then
            tab[i] = lookup(t.fn, i, unpack_choc(str, unpack(t)))
        else
           tab[i] = {}
            for k,tt in pairs(t) do
                tab[i][k] = lookup(tt.fn, k, unpack_choc(str, unpack(tt)))
            end
        end
    end
    return tab
end

function Set (list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

local chocobo_item = {
    egg  = Set{2312,2314,2317,2318,2319},
    card = Set{2313,2339,2342,2402},
}

local log_chocobo = function(tab)
    if 'None' == tab.abilities[2] then tab.abilities[2] = nil end
    print(chat.header(addon.name):append(chat.message(string.format('%s (%s) [%s] Jockey: %s DNA: [%s %s %s]', tab.name, tab.gender, tab.color, tab.size, unpack(tab.DNA)))))
    print(chat.header(addon.name):append(chat.message(string.format('STR: %3d %s %d~%d/32RP %s', tab.STR.value, tab.STR.rank, tab.STR.rp, tab.STR.rp+1, tab.STR.legs and 'Legs and talons' or ''))))
    print(chat.header(addon.name):append(chat.message(string.format('END: %3d %s %d~%d/32RP %s', tab.END.value, tab.END.rank, tab.END.rp, tab.END.rp+1, tab.END.tail and 'Tailfeather plumage' or ''))))
    print(chat.header(addon.name):append(chat.message(string.format('DSC: %3d %s %d~%d/32RP %s', tab.DSC.value, tab.DSC.rank, tab.DSC.rp, tab.DSC.rp+1, tab.DSC.head and 'Beak and crest' or ''))))
    print(chat.header(addon.name):append(chat.message(string.format('RCP: %3d %s %d/32RP', tab.RCP.value, tab.RCP.rank, tab.RCP.rp))))
    print(chat.header(addon.name):append(chat.message(string.format('Abilities: %s', table.concat(tab.abilities, ' & ')))))
    print(chat.header(addon.name):append(chat.message(string.format('Personality: %s', tab.temperament))))
    print(chat.header(addon.name):append(chat.message(string.format('Weather: Prefers %s. Dislikes %s.', tab.weather.prefers, tab.weather.dislikes))))

    if tab.unknown == 1 then
        print(chat.header(addon.name):append(chat.message('Observed unknown value')))
    end
end

local log_chocobo_card = function(str)
    local tab = decode_chocobo('card', str)
    log_chocobo(tab)
end

ashita.events.register('packet_in', 'incoming chunk', function(e)
    if e.id == 0x105 then
        if chocobo_item.card[struct.unpack('H', e.data, 15)] then
            log_chocobo_card(e.data:sub(18))
        end

    elseif e.id == 0x033 then
        last[0x033] = e.data

    elseif e.id == 0x034 then
        last[0x034] = e.data

    elseif e.id == 0x05C then
        --print(e.data)
        last[0x05C] = e.data

    elseif e.id == 0x05D then
        last[0x05D] = e.data
    end
end)

ashita.events.register('packet_out', 'outgoing chunk', function(e)
    if (e.id==0x05B) then
        last[0x05B] = e.data
    end
end)

local get_speed = function(speed_mod, gear)
    return math.min(speed_mod + gear, 8) / 8 * 20 + 80
end

local get_duration = function(time_mod, gear)
    return (math.min(time_mod + 4, 11) + gear) * 4 + 1
end


ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args();
    if (#args == 0 or args[1] ~= '/cc' and args[1] ~= '/chococard') then
        return;
    end
    if args[2] == 'log' then
        print(chat.header(addon.name):append(chat.message('--------------------------------------------------------------------------------')))
        local invMgr = AshitaCore:GetMemoryManager():GetInventory();
        for i = 1, 81 do
            local item = invMgr:GetContainerItem(0, i)
            if chocobo_item.egg[item.Id] then
                local tab = decode_chocobo('egg', item.Extra)
                local tier = item.Id > 2314 and item.Id-2314 or item.Id == 2314 and 2 or 1
                local tierdesc = {'faintly','slightly','a bit','a little','somewhat'}
                print(chat.header(addon.name):append(chat.message(string.format('Egg T%d [%s warm]', tier, tierdesc[tier]))))
                if tab.is_bred then
                    print(chat.header(addon.name):append(chat.message(string.format('Plan: %s DNA: [%s %s %s]', tab.plan, unpack(tab.DNA)))))
                    print(chat.header(addon.name):append(chat.message(string.format('Ability: %s unknowns: %d %d', tab.ability, tab.unknown1, tab.unknown2))))
                    --print(item.Extra:hex())
                end
            elseif chocobo_item.card[item.Id] then
                local extra = item.Extra
                local tab = decode_chocobo('card', extra)
                log_chocobo(tab)

                local speed_mod = math.floor(tab.STR.value / 0x20) -- str rank
                local time_mod = math.floor(tab.END.value / 0x20) -- end rank
                for x = 1, 2 do
                    if tab.abilities[x] == 'Gallop' then
                        speed_mod = speed_mod + 1
                    elseif tab.abilities[x] == 'Canter' then
                        time_mod = time_mod + 1
                    end
                end
                print(chat.header(addon.name):append(chat.message(string.format('Riding Speed: %.1f%% (Purple Race Silks: %.1f%%)', get_speed(speed_mod, 0), get_speed(speed_mod, 1)))))
                print(chat.header(addon.name):append(chat.message(string.format('Riding Time: %d Minutes (Red Race Silks: %d Minutes)', get_duration(time_mod, 0), get_duration(time_mod, 1)))))
            end
        end
    elseif args[2] == 'display' then

    elseif args[2] == 'paddock' then
        if last[0x05B] == '' or 70 ~= struct.unpack('H', last[0x05B], 0x10+1) then return end -- chocobo circuit zone id

        local option = struct.unpack('H', last[0x05B], 0x08+1)
        local menu_id = struct.unpack('H', last[0x05B], 0x12+1)

        if last[0x033] == '' and last[0x034] == '' then return end
        if string.len(last[0x033]) > 0x0C + 1 and menu_id == struct.unpack('H', last[0x033], 0x0C+1) then
            if option > 5 and option < 9 then
                -- free runs and mission races
                -- incoming packet 0x05C
                -- 0x04 chocobo data
                -- 0x0C orders
                -- 0x10 equipment
                -- 0x14 affiliation
                -- 0x1C
                local tab = decode_chocobo('card', last[0x05C]:sub(0x04+1, 0x0B+1)..string.char(0):rep(16))
                if option > 6 then
                    tab.name = last[0x05D]:sub(0x38+1, 0x47+1)
                else
                    tab.name = last[0x033]:sub(0x10+1, 0x1F+1)
                end
                log_chocobo(tab)
            end
        elseif string.len(last[0x034]) > 0x2C + 1 and menu_id == struct.unpack('H', last[0x034], 0x2C+1) and bit.band(option, 0x07) == 0 then
            -- crystal stakes paddock
            -- incoming packet 0x05C 
            -- 0x04
            -- 0x08 affiliation
            -- 0x0C orders
            -- 0x10 equipment
            -- 0x14 chocobo data
            -- 0x1C saddle
            -- 0x20
            local tab = decode_chocobo('card', last[0x05C]:sub(0x14+1, 0x1B+1)..string.char(0):rep(16))
            tab.name = last[0x05D]:sub(0x28+1, 0x37+1)
            log_chocobo(tab)
        end
    end
end)