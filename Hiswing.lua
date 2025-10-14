-- HiSwing v2.0 
-- Circklon-style Note Sequencing
-- 
-- Patterns arise and decay: 
-- steps, velocity, and density are fluid, mutable, responsive.
-- HANJO, Tokyo, Japan.
-- 
-- K3 + E1: Toggle Pages.
-- K2: Randomize step velocities.
-- E2: Change pattern length.
-- E3: Change groove template.
-- K3 + E2: Change MIDI channel
-- K3 + E3: Pattern reduction
-- K3 + K2: Change Swing mode
-- 
-- On Note Page:
-- E1: Change root note 
-- K3 + E2: Change scale
-- E2: Navigate and select steps
-- E3: Change note value
-- 

local musicutil = require "musicutil"
local midi = require "core/midi"

local length = 16
local step = 1
local velocity_pattern = {} -- VELOCITY data from page 1 (completely separate from notes)
local groove_index = 1
local midi_device
local midi_channel = 1
local holding_k3 = false
local active_steps = {}
local reduction_amount = 0 -- 0 = 0%, 1 = 100% reduction
local default_note = 36 -- MIDI note for C2 (default when no note pattern)

-- Note sequencing variables
local note_page = false -- false = velocity page, true = note page
local note_pattern = {} -- NOTE data from page 2 (completely separate from velocity)
local selected_step = 1 -- Currently selected step on note page
local root_note = 48 -- C3 as default root note
local original_root_note = 48 -- Store original for transposition
local scale_index = 1 -- Default scale
local scales = musicutil.SCALES -- Use full musicutil scale library

-- Swing system variables
local swing_enabled = false
local swing_amount = 0 -- 0=off, 1-5=normal swing, 6-10=reverse swing
local swing_delay_times = {0, 2/96, 4/96, 6/96, 8/96, 10/96} -- TR-909 style delays (S1-S5)

-- define grooves as absolute MIDI velocities
local grooves = {
    {127,100,127,100,127,100,127,100,127,100,127,100,127,100,127,100}, -- house 1
    {127,64,100,64,127,64,100,64,127,64,100,64,127,64,100,64}, -- funky 1
    {127,127,89,89,127,127,89,89,127,127,89,89,127,127,89,89}, -- deep house
    {114,114,127,89,114,114,127,89,114,114,127,89,114,114,127,89}, -- garage
    {127,89,114,89,127,89,114,89,127,89,114,89,127,89,114,89}, -- oldschool
    {127,76,127,76,127,76,127,76,127,76,127,76,127,76,127,76}, -- electro bounce
}

-- initialize patterns
for i = 1, 16 do
    velocity_pattern[i] = math.random(80, 120) -- Initialize velocity pattern
    active_steps[i] = true
    note_pattern[i] = root_note -- Initialize note pattern
end

function init()
    midi_device = midi.connect()
    if not midi_device then
        print("Error: Could not connect to MIDI device. No MIDI output.")
    else
        print("MIDI device connected. Running continuous pattern.")
        print("Available scales: " .. #scales)
        clock.run(clock_run)
    end
end

function toggle_swing()
    -- Cycle through: No swing (0), S1-S5 (1-5), No swing (0), S1R-S5R (6-10), No swing (0)
    swing_amount = (swing_amount + 1) % 11
    
    if swing_amount == 0 then
        swing_enabled = false
    else
        swing_enabled = true
    end
    redraw()
end

function get_swing_delay(step_num)
    if not swing_enabled or swing_amount == 0 then
        return 0
    end
    
    local is_even_step = (step_num % 2 == 0)
    local swing_level = swing_amount
    
    if swing_amount <= 5 then
        -- NORMAL SWING: delay even steps (S1-S5) - makes them later
        if is_even_step then
            return swing_delay_times[swing_level] -- Positive delay = later
        end
    else
        -- REVERSE SWING: advance even steps (S1R-S5R) - makes them earlier
        swing_level = swing_amount - 5 -- Convert 6-10 to 1-5
        if is_even_step then
            return -swing_delay_times[swing_level] -- Negative delay = earlier
        end
    end
    
    return 0
end

function get_swing_display()
    if not swing_enabled or swing_amount == 0 then
        return ""
    end
    
    if swing_amount <= 5 then
        return "S" .. swing_amount
    else
        return "S" .. (swing_amount - 5) .. "R"
    end
end

function get_visual_swing_offset(step_num)
    if not swing_enabled or swing_amount == 0 then
        return 0
    end
    
    local is_even_step = (step_num % 2 == 0)
    local swing_level = swing_amount
    
    if swing_amount <= 5 then
        -- NORMAL SWING: delay even steps = move visual representation RIGHT
        if is_even_step then
            return swing_level  -- Progressive right movement: 1, 2, 3, 4, 5 pixels
        end
    else
        -- REVERSE SWING: advance even steps = move visual representation LEFT
        swing_level = swing_amount - 5 -- Convert 6-10 to 1-5
        if is_even_step then
            return -swing_level  -- Progressive left movement: -1, -2, -3, -4, -5 pixels
        end
    end
    
    return 0
end

function randomize_velocity_pattern()
    -- Only randomize VELOCITY for active steps, respecting pattern reduction
    print("Randomizing VELOCITY pattern")
    for i = 1, 16 do
        if active_steps[i] then
            velocity_pattern[i] = math.random(30, 127)
        end
    end
end

function randomize_note_pattern()
    -- Only randomize NOTES for active steps, respecting pattern reduction
    -- VELOCITY pattern remains untouched!
    print("Randomizing NOTE pattern")
    for i = 1, 16 do
        if active_steps[i] then
            if scale_index == 1 then
                -- Chromatic: random note within 2 octaves (C3 to C5)
                note_pattern[i] = math.random(48, 72)
            else
                -- Scale-based: random note from the current scale within 2 octaves
                local scale_notes = musicutil.generate_scale(original_root_note, scales[scale_index].name, 2) -- 2 octaves
                if #scale_notes > 0 then
                    local random_index = math.random(1, #scale_notes)
                    note_pattern[i] = scale_notes[random_index]
                else
                    note_pattern[i] = original_root_note
                end
            end
        end
    end
end

function get_step_velocity(step)
    -- Calculate velocity for the current step using VELOCITY pattern + groove
    -- This ONLY uses velocity_pattern from page 1 and is COMPLETELY SEPARATE from notes
    local groove_velocity = grooves[groove_index][step] or 127
    local base_velocity = velocity_pattern[step] or 0
    local velocity = util.clamp(math.floor((base_velocity + groove_velocity) / 2), 1, 127)
    return velocity
end

function get_transposed_note(step_note)
    -- Calculate transposition offset from current root note
    -- This ONLY affects notes, NOT velocity
    local transposition_offset = root_note - original_root_note
    return util.clamp(step_note + transposition_offset, 0, 127)
end

function play_step(step)
    if not active_steps[step] or not midi_device then return end

    -- Apply swing timing if enabled
    local swing_delay = get_swing_delay(step)
    if swing_delay ~= 0 then
        clock.sleep(math.abs(swing_delay))
    end

    -- ALWAYS get velocity from VELOCITY pattern (page 1 data)
    local velocity = get_step_velocity(step)
    
    -- Determine which note to play
    local note_to_play
    if note_page then
        -- On note page: use transposed note from note_pattern
        note_to_play = get_transposed_note(note_pattern[step])
    else
        -- On velocity page: use default note (hi-hat)
        note_to_play = default_note
    end
    
    -- Send MIDI note with VELOCITY from page 1 and appropriate NOTE
    midi_device:note_on(note_to_play, velocity, midi_channel)
    clock.sleep(0.05) -- Short sleep to ensure note-off happens after note-on
    midi_device:note_off(note_to_play, 0, midi_channel)
end

function clock_run()
    while true do
        if length > 0 then  -- Only play if length is greater than 0
            play_step(step)
            step = step + 1
            if step > length then step = 1 end
        end
        clock.sync(1/4)
    end
end

function random_reduce()
    -- determine how many active steps based on reduction amount
    -- This affects BOTH velocity and note patterns equally
    local min_percent = 0.15
    local percent = util.linlin(0,1,1,min_percent,reduction_amount)
    local steps_to_keep = math.max(1, math.floor(length * percent))

    -- reset all steps active
    for i = 1, 16 do active_steps[i] = false end

    -- pick random steps
    local indices = {}
    for i = 1, length do table.insert(indices, i) end
    for i = 1, steps_to_keep do
        local idx = math.random(#indices)
        active_steps[indices[idx]] = true
        table.remove(indices, idx)
    end
end

function key(n,z)
    if n == 2 and z == 1 then
        if holding_k3 then
            -- K3 + K2: Change swing mode
            toggle_swing()
        else
            -- Single K2 press: Randomize patterns
            if note_page then
                randomize_note_pattern() -- Only affects NOTES
            else
                randomize_velocity_pattern() -- Only affects VELOCITY
            end
            redraw()
        end
    elseif n == 3 then
        holding_k3 = (z == 1)
    end
end

function enc(n,d)
    if n == 1 and holding_k3 then
        -- K3 + E1 toggles between pages
        note_page = not note_page
        redraw()
        return
    end
    
    if note_page then
        -- NOTE PAGE CONTROLS - ONLY AFFECT NOTES
        if n == 1 then
            -- Root note selector (transposes entire melody) - ONLY AFFECTS NOTES
            root_note = util.clamp(root_note + d, 0, 127)
            redraw()
        elseif n == 2 then
            if holding_k3 then
                -- K3 + E2: Change scale - ONLY AFFECTS NOTE RANDOMIZATION
                scale_index = util.clamp(scale_index + d, 1, #scales)
                redraw()
            else
                -- E2: Navigate through steps - ONLY AFFECTS NOTE EDITING
                selected_step = util.clamp(selected_step + d, 1, length)
                redraw()
            end
        elseif n == 3 then
            if holding_k3 then
                -- K3 + E3: Change pattern reduction (affects both pages)
                reduction_amount = util.clamp(reduction_amount + d/20, 0, 1)
                random_reduce()
                redraw()
            else
                -- Change note value for selected step - ONLY AFFECTS NOTES
                if scale_index == 1 then
                    -- Chromatic scale - free movement
                    note_pattern[selected_step] = util.clamp(note_pattern[selected_step] + d, 0, 127)
                else
                    -- Use scale degrees - only quantize when actively changing notes
                    local scale_notes = musicutil.generate_scale(original_root_note, scales[scale_index].name, 2) -- 2 octaves
                    if #scale_notes > 0 then
                        local current_note = note_pattern[selected_step]
                        local closest_index = 1
                        local min_distance = math.huge
                        
                        -- Find closest note in scale
                        for i, note in ipairs(scale_notes) do
                            local distance = math.abs(note - current_note)
                            if distance < min_distance then
                                min_distance = distance
                                closest_index = i
                            end
                        end
                        
                        -- Move to next/previous note in scale
                        local new_index = util.clamp(closest_index + d, 1, #scale_notes)
                        note_pattern[selected_step] = scale_notes[new_index]
                    end
                end
                redraw()
            end
        end
    else
        -- VELOCITY PAGE CONTROLS - ONLY AFFECT VELOCITY
        if n == 2 then
            if holding_k3 then
                midi_channel = util.clamp(midi_channel + d, 1, 16)
            else
                length = util.clamp(length + d, 0, 16)  -- Now allows 0 for STOP
            end
            redraw()
        elseif n == 3 then
            if holding_k3 then
                -- K3 + E3: Change pattern reduction (affects both pages)
                reduction_amount = util.clamp(reduction_amount + d/20, 0, 1)
                random_reduce()
            else
                groove_index = util.clamp(groove_index + d, 1, #grooves)
            end
            redraw()
        end
    end
end

function redraw()
    screen.clear()

    if note_page then
        -- NOTE PAGE DISPLAY - Shows NOTES with velocity from page 1
        screen.level(15)
        
        -- Top info text for note page
        screen.move(10,10)
        screen.text(musicutil.note_num_to_name(root_note) .. "  " .. scales[scale_index].name)
        
        -- Display active step note on top right
        local active_note_display = musicutil.note_num_to_name(get_transposed_note(note_pattern[selected_step]))
        screen.move(120, 10)
        screen.text_right(active_note_display)
        
        -- Step chart for notes - INVERTED: higher notes = longer lines
        local width = 120 / 16
        for i = 1, length do
            if active_steps[i] then
                -- Convert note to screen position (higher notes = longer lines)
                local note_height = util.linlin(24, 84, 4, 40, note_pattern[i]) -- INVERTED mapping
                local x = 4 + (i-1)*width
                
                -- Apply visual swing offset for even steps
                local swing_offset = get_visual_swing_offset(i)
                x = x + swing_offset
                
                -- Draw step
                screen.level(i == selected_step and 15 or 8) -- Highlight selected step
                screen.move(x, 64)
                screen.line(x, 64-note_height)
                screen.stroke()
            end
        end
        
    else
        -- VELOCITY PAGE DISPLAY - Shows VELOCITY pattern
        screen.level(15)
        
        -- Top info text with swing indicator
        screen.move(10,10)
        if length == 0 then
            screen.text("STOP")
        else
            local swing_display = get_swing_display()
            if swing_display ~= "" then
                screen.text("MIDI CH:"..midi_channel.." "..swing_display)
            else
                screen.text("MIDI CH:"..midi_channel)
            end
        end
        
        screen.move(80,10)
        if length == 0 then
            screen.text("LEN: 0")
        else
            screen.text("GROOVE: "..groove_index)
        end

        -- Step chart - only show if length > 0
        if length > 0 then
            local width = 120 / 16
            for i = 1, length do
                if active_steps[i] then
                    local velocity = get_step_velocity(i)
                    local height = util.linlin(1,127,0,40,velocity)
                    local x = 4 + (i-1)*width
                    
                    -- Apply visual swing offset for even steps
                    local swing_offset = get_visual_swing_offset(i)
                    x = x + swing_offset
                    
                    screen.move(x, 64)
                    screen.line(x, 64-height)
                end
            end
            screen.stroke()
        else
            -- Display STOP message when length is 0
            screen.level(8)
            screen.move(64, 40)
            screen.text_center("STOPPED")
            screen.move(64, 50)
            screen.text_center("E2 to start")
        end
    end

    screen.update()
end

function metro_redraw()
    while true do
        clock.sleep(1/15)
        redraw()
    end
end

clock.run(metro_redraw)
