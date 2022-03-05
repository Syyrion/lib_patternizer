--[[
	String based pattern generation for Open Hexagon.
	https://github.com/vittorioromeo/SSVOpenHexagon

	Copyright (C) 2021 Ricky Cui

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program. If not, see <https://www.gnu.org/licenses/>.

	Email: cuiricky4@gmail.com
	GitHub: https://github.com/Syyrion
]]

u_execDependencyScript('library_extbase', 'extbase', 'syyrion', 'utils.lua')
u_execDependencyScript('library_extbase', 'extbase', 'syyrion', 'common.lua')
u_execDependencyScript('library_slider', 'slider', 'syyrion', 'master.lua')

--[[
	* Patternizer
]]

-- Creates a single ring of walls.

local function horizontal(bin, sides, thickness, ix, dir, nonloop, loop, stop)
	local function make(p)
		p:gsub('[%d%a%._]', function (char)
			(bin[char] or __NOP)(ix, thickness)
			ix = (ix + dir) % sides
			if ix == stop then error('Force exit gsub') end
			return char
		end)
	end

	if not pcall(make, nonloop) then return end

	if loop:len() == 0 then return end

	while pcall(make, loop) do end
end

Patternizer = {
	generators = {
		['c'] = function (...) cWall(...) end,
		['o'] = function (...) oWall(...) end,
		['r'] = function (...) rWall(...) end
	},
	sides = Discrete:new(nil, function (self) return self.val or l_getSides() end, 'number')
}

Patternizer.generators['.'] = Patternizer.generators['c']
Patternizer.generators['1'] = Patternizer.generators['c']
Patternizer.generators.__index = Patternizer.generators
Patternizer.__index = Patternizer

function Patternizer:new(...)
	local newInst = setmetatable({
		new = __NEW_CLASS_ERROR,
		generators = setmetatable({}, self.generators),
		timeline = Keyframe:new(),
		sides = self.sides:new(),
		pattern = {
			list = {},
			total = 0,
			previous = 0
		}
	}, self)
	newInst:add(...)
	return newInst
end

-- Links characters to functions so that certain actions are performed when those characters appear in a pattern string.
-- Functions to be linked must have the form: function (side, thickness) end
function Patternizer:link(char, fn)
	char = type(char) == 'string' and char:match('^([%d%a%._])$') or errorf(2, 'Link', 'Argument #1 is not an alphanumeric character, period, or underscore.')
	self.generators[char] = type(t == 'function') and fn or errorf(2, 'Link', 'Argument #2 is not a function.')
end

-- Unlinks a character
function Patternizer:unlink(char)
	char = type(char) == 'string' and char:match('^([%d%a%._])$') or errorf(2, 'Link', 'Argument #1 is not an alphanumeric character, period, or underscore.')
	self.generators[char] = nil
end

-- Interprets and generates a pattern from a string.
-- This function is way too long...
function Patternizer:send(str)
	-- Cut out any unnecessary characters.
	str = (type(str) == 'string' and str or errorf(2, 'Send', 'Argument #1 is not a string.')):gsub('[\r\t ]+', ''):match('^[\n;]*(.-)[\n;]*$')
	-- Create lines table.
	local lines = {}
	do
		local pattern = string.rep('([^,]*)', 6, ',?')
		for line in str:gsplit('[\n;]+') do
			table.insert(lines, {line:match(pattern)})
		end
	end

	-- Line counter.
	local lc = 1
	local abspivot, relpivot, mirror, reverse, tolerance, sides

	local function randSide() return u_rndInt(0, sides - 1) end

	-- Check if there's a header
	do
		local firstLine = lines[lc]
		abspivot = firstLine[1]:match('^@(.*)')
		if abspivot then
			-- Determine number of sides.
			sides = firstLine[6]
			sides = sides == '' and self.sides:get() or verifyShape(tonumber(sides) or errorf(2, 'SendHeader', 'Malformed number on line 1, section 6.'))

			-- Determine absolute pivot location.
			abspivot = abspivot == '' and randSide() or math.floor(tonumber(abspivot) or errorf(2, 'SendHeader', 'Malformed number on line 1, section 1.')) % sides

			-- Determine whether the pattern is mirrored.
			mirror = firstLine[3]
			mirror = (mirror == '' or mirror == '?') and getRandomDir() or (
				mirror == 't' and -1 or (
					mirror == 'f' and 1 or errorf(2, 'SendHeader', 'Value on line 1, section 3 is not "t", "f", "?", "", or nil.')
				)
			)

			-- Determine whether rows are reversed.
			reverse = firstLine[4]
			reverse = (reverse == '' or reverse == 'f') and 1 or (
				reverse == 't' and -1 or (
					reverse == 'm' and mirror or (
						reverse == '?' and getRandomDir() or errorf(2, 'SendHeader', 'Value on line 1, section 4 is not "t", "f", "?", "m", "", or nil.')
					)
				)
			)

			-- Determine relative pivot location.
			relpivot = firstLine[2]
			relpivot = (abspivot + (relpivot == '' and 0 or math.floor(tonumber(relpivot) or errorf(2, 'SendHeader', 'Malformed number on line 1, section 2.'))) * mirror) % sides

			-- Determine tolerance value.
			tolerance = firstLine[5]
			tolerance = tolerance == '' and 8 or tonumber(tolerance) or errorf(2, 'SendHeader', 'Malformed number on line 1, section 5.')

			-- Increment line counter
			lc = lc + 1
		else
			-- Assign random/default values
			sides = self.sides:get()
			abspivot = randSide()
			relpivot = abspivot
			mirror = getRandomDir()
			reverse = 1
			tolerance = 8
		end
	end

	local reloffset, loops, depth = 0, {}, 0
	local floorsides, ceilsides
	do
		local halfsides = sides / 2
		floorsides, ceilsides = math.floor(halfsides), math.ceil(halfsides)
	end

	while true do
		-- Make reference to current line
		local currentLine = lines[lc]

		-- Exit if end of pattern is reached
		if not currentLine then
			if depth > 0 then errorf(2, 'SendLoop', 'Unmatched "[" on line %d.', loops[depth].pos) end
			self.timeline:eval(0, self.enable, self)
			return
		end

		-- Check for looping
		local leadingChar, remainder = currentLine[1]:match('^([%[%]])(.*)')
		if leadingChar == '[' then
			-- Begin a loop
			-- Find range
			local a = math.max(math.floor(tonumber(remainder) or errorf(2, 'SendLoop', 'Malformed number on line %d, section 1.', lc)), 0)
			local b = currentLine[2]
			b = b == '' and a or math.max(math.floor(tonumber(b) or errorf(2, 'SendLoop', 'Malformed number on line %d, section 2.', lc)), a)
			local count = u_rndInt(a, b)
			if count > 0 then
				-- If count is greater than 0, add new loop object
				depth = depth + 1
				loops[depth] = {
					pos = lc,
					count = count
				}
			else
				-- If count equals 0 then skip to next "]"
				local pos = lc
				repeat
					lc = lc + 1
				until (lines[lc] or errorf(2, 'SendLoop', 'Unmatched "[" on line %d.', pos))[1]:match('^(%]).*')
			end
		elseif leadingChar == ']' then
			-- Exit a loop
			local currentLoop = loops[depth] or errorf(2, 'SendLoop', 'Unexpected "]" on line %d.', lc)
			currentLoop.count = currentLoop.count - 1
			if currentLoop.count == 0 then
				loops[depth] = nil
				depth = depth - 1
			else
				lc = currentLoop.pos
			end
		else
			--[[
				* Pattern generator
			]]

			-- * Thickness/Delay
			local thickness, seconds
			do
				local section = currentLine[2]
				if section == '' then
					-- Section is empty: set defaults
					seconds = getIdealDelayInSeconds(sides)
					thickness = secondsToThickness(seconds)
				else
					-- Find flag
					local head, flag, tail = section:match('(.-)([!%*%?])(.*)')
					if flag == '!' then
						-- Check for extra characters
						if tail == '!' then
							-- Assign rotational absolute thickness
							seconds = SECONDS_PER_PLAYER_ROTATION * (head == '' and 0.5 or tonumber(head) or errorf(2, 'SendThickness', 'Malformed number on line %d, section 2.', lc))
							thickness = secondsToThickness(seconds)
						elseif tail == '' then
							-- Assign raw absolute thickness and subtract tolerance
							thickness = (head == '' and THICKNESS or tonumber(head) or errorf(2, 'SendThickness', 'Malformed number on line %d, section 2.', lc)) - tolerance
							seconds = thicknessToSeconds(thickness)
						else
							errorf(2, 'SendThickness', 'Extraneous characters found on line %d, section 2.', lc)
						end
					elseif flag == '*' then
						-- Check for extra characters
						if tail ~= '' then errorf(2, 'SendThickness', 'Extraneous characters found on line %d, section 2.', lc) end
						-- Assign dynamic thickness
						seconds = getIdealDelayInSeconds(sides) * (head == '' and 1 or tonumber(head) or errorf(2, 'SendThickness', 'Malformed number on line %d, section 2.', lc))
						thickness = secondsToThickness(seconds)
					elseif flag == '?' then
						head = (head == '' and 0 or tonumber(head) or errorf(2, 'SendThickness', 'Malformed number on line %d, section 2.', lc))
						-- Check for tail flags
						if tail == '' or tail == '-' then
							-- Assign dynamic thickness for shortest path
							seconds = getIdealDelayInSeconds(sides) * (reloffset + head)
						elseif tail == '+' then
							-- Assign dynamic thickness for longest path
							seconds = getIdealDelayInSeconds(sides) * (sides - reloffset + head)
						else
							-- No flags found
							errorf(2, 'SendThickness', 'Extraneous characters found on line %d, section 2.', lc)
						end
						thickness = secondsToThickness(seconds)
					else
						-- Missing flag
						errorf(2, 'SendThickness', 'Missing flag on line %d, section 2.', lc)
					end
				end
			end

			-- * Position
			local ix
			do
				local section = currentLine[4]
				if section  == '' then
					-- Section is empty: set default
					ix = relpivot
				else
					-- Find and verify flag
					local head, flag, tail = section:match('(.-)([!%*])(.*)')
					if not flag then errorf(2, 'SendPosition', 'Missing flag on line %d, section 4.', lc) end
					if tail ~= '' then errorf(2, 'SendPosition', 'Extraneous characters found on line %d, section 4.', lc) end
					-- Set position value
					local ofs = head == '' and 0 or math.floor(tonumber(head) or errorf(2, 'SendPosition', 'Malformed number on line %d, section 4.', lc))
					ix = ((flag == '!' and abspivot or relpivot) + ofs) % sides
				end
			end

			-- * Block
			local reverseflag, nonloop, split, loop = currentLine[1]:match('(~?)([%d%a%._]*)([|%-%+]?)([%d%a%._]*)')

			-- * Add to timeline
			self.timeline:eval(
				0, horizontal, self.generators, sides, thickness, ix, (reverseflag == '~' and -1 or 1) * reverse, nonloop, loop,
				split == '' or split == '|' and ix or (ix + (split == '-' and floorsides or ceilsides)) % sides
			)
			self.timeline:event(seconds)

			-- * Relative pivot control
			do
				local section = currentLine[3]
				if section == '' then
					-- Section is empty: set default
					reloffset = 0
				else
					-- Save the old position
					local oldpos = relpivot
					-- Find flag
					local head, flag, tail = section:match('(.-)([!%*%?/])(.*)')
					if not flag then
						-- Flag is missing
						errorf(2, 'SendPivot', 'Missing flag on line %d, section 3.', lc)
					elseif flag == '?' then
						-- Flag is '?'
						-- Find secondary flag
						local rflag, rtail = tail:match('^([!%*])(.*)')
						if rflag then
							-- Check secondary flag type
							local a = math.floor(tonumber(head) or errorf(3, 'SendPivot', 'Malformed number on line %d, section 3.', lc))
							local b = rtail == '' and -a or math.floor(tonumber(rtail) or errorf(3, 'SendPivot', 'Malformed number on line %d, section 3.', lc))
							local s = (b - a) % sides
							-- Pick random relative to absolute pivot
							relpivot = ((rflag == '!' and abspivot or relpivot) + u_rndInt(a, a + s) * mirror) % sides
						else
							-- Secondary flag is missing
							-- Check for extra characters
							if head ~= '' and tail ~= '' then errorf(2, 'SendPivot', 'Extraneous characters found on line %d, section 3.', lc) end
							-- Pick a random side
							relpivot = randSide()
						end
					elseif flag == '/' then
						head = (head == '' and 0 or tonumber(head) or errorf(2, 'SendPivot', 'Malformed number on line %d, section 3.', lc))
						-- Check for tail flags
						if tail == '' or tail == '-' then
							-- Add floored half sides
							relpivot = (relpivot + floorsides) % sides
						elseif tail == '+' then
							-- Add ceiled half sides
							relpivot = (relpivot + ceilsides) % sides
						elseif tail == '?' then
							relpivot = (relpivot + (u_rndInt(0, 1) == 0 and floorsides or ceilsides)) % sides
						else
							-- No flags found
							errorf(2, 'SendPivot', 'Extraneous characters found on line %d, section 3.', lc)
						end

					else
						-- Flag is '!' or '*'
						-- Check for extra characters
						if tail ~= '' then errorf(2, 'SendPivot', 'Extraneous characters found on line %d, section 3.', lc) end
						-- Set relpivot value
						local ofs = head == '' and 0 or math.floor(tonumber(head) or errorf(3, 'SendPivot', 'Malformed number on line %d, section 3.', lc))
						relpivot = ((flag == '!' and abspivot or relpivot) + ofs * mirror) % sides
					end

					-- Set relative offset to shortest distance between the old and new position
					local diff = math.abs(relpivot - oldpos)
					reloffset = diff > floorsides and sides - diff or diff
				end
			end
		end
		-- Increment line counter
		lc = lc + 1
	end
end


function Patternizer:disable() self.spawn = __NOP end
function Patternizer:enable() self.spawn = nil end

-- Begins the pattern sequence.
-- This function is disabled while a pattern exists on the timeline
function Patternizer:spawn()
	local sides = self.sides:get()
	local patterns, plistlen, exclude = self.pattern.list, self.pattern.total, self.pattern.previous
	local pool, ix = {}, 0
	for i = 1, plistlen do
		local allow, patternStr = patterns[i](sides)
		if allow and i ~= exclude then
			ix = ix + 1
			pool[ix] = i
			pool[-ix] = patternStr
		end
	end
	if ix > 0 then
		local choice = u_rndInt(1, ix)
		self.pattern.previous = pool[choice]
		local status, message = pcall(self.send, self, pool[-choice])
		assert(status, ('[SpawnError] Unable to spawn pattern #%d. Message: %s'):format(pool[choice], message))
		self:disable()
	end
end

-- Stops or resumes pattern generation. The timeline will still run.
function Patternizer:pause() self.pspawn = __NOP end
function Patternizer:resume() self.pspawn = nil end

-- Same as spawn but can be disabled by pause and resume functions
function Patternizer:pspawn()
	self:spawn()
end

-- Adds patterns
function Patternizer:add(...)
	local t, start = {...}, self.pattern.total
	local len = #t
	for i = 1, len do
		local fn = t[i]
		self.pattern.list[start + i] = type(fn) == 'function' and fn or errorf(2, 'AddPattern', 'Argument #%d is not a function.', i)
	end
	self.pattern.total = start + len
end

-- Removes all patterns
function Patternizer:clear()
	for i = 1, self.pattern.total do
		self.pattern.list[i] = nil
	end
	self.pattern.total = 0
end

-- Runs the patternizer timeline without spawning patterns
function Patternizer:step(mFrameTime)
	self.timeline:step(mFrameTime)
end

-- Runs the patternizer while also spawning patterns
function Patternizer:run(mFrameTime)
	self:pspawn()
	self:step(mFrameTime)
end