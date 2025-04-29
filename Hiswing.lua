-- HiSwing v1.0
-- 
-- Patterns arise and decay: 
-- steps, velocity, and density are fluid, mutable, responsive.
-- HANJO, Tokyo, Japan.
-- 
-- K2: Randomize step velocities.
-- E2: Change pattern length.
-- E3: Change groove template.
-- K3 + E2: Change MIDI channel.
-- K3 + E3: Change pattern reduction.
-- 
local musicutil = require "musicutil"
local midi = require "core/midi"

local length = 16
local step = 1
local pattern = {}
local groove_index = 1
local midi_device
local midi_channel = 1
local holding_k3 = false
local active_steps = {}
local reduction_amount = 0 -- 0 = 0%, 1 = 100% reduction
local midi_note = 36 -- MIDI note for C2

-- define grooves as absolute MIDI velocities
local grooves = {
	{127,100,127,100,127,100,127,100,127,100,127,100,127,100,127,100}, -- house 1
	{127,64,100,64,127,64,100,64,127,64,100,64,127,64,100,64}, -- funky 1
	{127,127,89,89,127,127,89,89,127,127,89,89,127,127,89,89}, -- deep house
	{114,114,127,89,114,114,127,89,114,114,127,89,114,114,127,89}, -- garage
	{127,89,114,89,127,89,114,89,127,89,114,89,127,89,114,89}, -- oldschool
	{127,76,127,76,127,76,127,76,127,76,127,76,127,76,127,76}, -- electro bounce
}

-- initialize pattern
for i = 1, 16 do
	pattern[i] = math.random(80, 120)
	active_steps[i] = true
end

function init()
	midi_device = midi.connect()
	if not midi_device then
		print("Error: Could not connect to MIDI device. No MIDI output.")
	else
		print("MIDI device connected. Running continuous C2 hi-hat pattern.")
		clock.run(clock_run)
	end
end

function randomize_pattern()
	for i = 1, 16 do
		pattern[i] = math.random(30, 127)
		active_steps[i] = true
	end
end

function play_step(step)
	if not active_steps[step] or not midi_device then return end

	local groove_velocity = grooves[groove_index][step] or 127
	local base_velocity = pattern[step] or 0
	local velocity = util.clamp(math.floor((base_velocity + groove_velocity) / 2), 1, 127)

	midi_device:note_on(midi_note, velocity, midi_channel)
	clock.sleep(0.05) -- Short sleep to ensure note-off happens after note-on
	midi_device:note_off(midi_note, 0, midi_channel)
end

function clock_run()
	while true do
		play_step(step)
		step = step + 1
		if step > length then step = 1 end
		clock.sync(1/4)
	end
end

function random_reduce()
	-- determine how many active steps based on reduction amount
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
		randomize_pattern()
	elseif n == 3 then
		holding_k3 = (z == 1)
		-- The start/stop functionality is removed
	end
end

function enc(n,d)
	if n == 1 then
		-- Mode selection removed, assuming MIDI only
	elseif n == 2 then
		if holding_k3 then
			midi_channel = util.clamp(midi_channel + d, 1, 16)
		else
			length = util.clamp(length + d, 1, 16)
		end
	elseif n == 3 then
		if holding_k3 then
			reduction_amount = util.clamp(reduction_amount + d/20, 0, 1)
			random_reduce()
		else
			groove_index = util.clamp(groove_index + d, 1, #grooves)
		end
	end
end

function redraw()
	screen.clear()

	-- Top info text
	screen.level(15)
	screen.move(10,10)
	screen.text("MIDI CH:"..midi_channel)
	screen.move(80,10)
	screen.text("GROOVE: "..groove_index)

	-- Step chart
	local width = 120 / 16
	for i = 1, length do
		if active_steps[i] then
			local groove_velocity = grooves[groove_index][i] or 127
			local base_velocity = pattern[i] or 0
			local velocity = util.clamp(math.floor((base_velocity + groove_velocity) / 2), 1, 127)
			local height = util.linlin(1,127,0,40,velocity)
			local x = 4 + (i-1)*width
			screen.move(x, 64)
			screen.line(x, 64-height)
		end
	end

	screen.stroke()
	screen.update()
end

function metro_redraw()
	while true do
		clock.sleep(1/15)
		redraw()
	end
end

clock.run(metro_redraw)
