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
			bin[char](ix, thickness)
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
	link = setmetatable({
		['c'] = function (...) cWall(...) end,
		['o'] = function (...) oWall(...) end,
		['r'] = function (...) rWall(...) end
	}, {__index = function () return __NOP end}),
	bags = {__index = function (this)
		return rawget(this, 'default') or __NOP
	end},
	sides = Discrete:new(nil, function (self) return self.val or l_getSides() end, 'number')
}

Patternizer.link['.'] = Patternizer.link.c
Patternizer.link['1'] = Patternizer.link.c

Patternizer.__index = Patternizer
Patternizer.link.__index = Patternizer.link

-- Links characters to functions so that certain actions are performed when those characters appear in a pattern.
-- Functions to be linked must have the form: function (side, thickness) end
Patternizer.link.__call = function (this, _, char, fn)
	char = type(char) == 'string' and char:match('^([%d%a%._])$') or errorf(2, 'Link', 'Argument #1 is not an alphanumeric character, period, or underscore.')
	this[char] = type(t == 'function') and fn or errorf(2, 'Link', 'Argument #2 is not a function.')
end

function Patternizer:unlink(char)
	char = type(char) == 'string' and char:match('^([%d%a%._])$') or errorf(2, 'Link', 'Argument #1 is not an alphanumeric character, period, or underscore.')
	this[char] = nil
end

function Patternizer:new(sides)
	local newInst = setmetatable({
		new = __NEW_CLASS_ERROR,
		link = setmetatable({}, self.link),
		timeline = Keyframe:new(),
		sides = self.sides:new(sides),

		pattern = {
			key = {},
			len = 0,
			ix = 0,
			d = {}
		},

	}, self)
	newInst.pattern.d.__index = newInst.pattern.d
	return newInst
end

-- Interprets and generates a pattern from a string.
-- Any extra parameters are passed to the linked functions.
function Patternizer:send(str)
	-- Cut out any uneccesary characters.
	str = (type(str) == 'string' and str or errorf(2, 'Send', 'Argument #1 is not a string.')):match('^[%s;]*(.-)[%s;]*$')

	-- Create lines table.
	local lines = {}
	for line in str:gsplit('[%s;]*[\n;][%s;]*') do
		table.insert(lines, line:gsub('%s', ''):split(','))
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
			sides = firstLine[6] or ''
			sides = sides == '' and self.sides:get() or verifyShape(tonumber(sides) or errorf(2, 'SendHeader', 'Malformed number on line 1, section 6.'))

			-- Determine absolute pivot location.
			abspivot = abspivot == '' and randSide() or math.floor(tonumber(abspivot) or errorf(2, 'SendHeader', 'Malformed number on line 1, section 1.')) % sides

			-- Determine whether the pattern is mirrored.
			mirror = firstLine[3] or ''
			mirror = (mirror == '' or mirror == '?') and getRandomDir() or (
				mirror == 't' and -1 or (
					mirror == 'f' and 1 or errorf(2, 'SendHeader', 'Value on line 1, section 3 is not "t", "f", "?", "", or nil.')
				)
			)

			-- Determine whether rows are reversed.
			reverse = firstLine[4] or ''
			reverse = (reverse == '' or reverse == 'f') and 1 or (
				reverse == 't' and -1 or (
					reverse == 'm' and mirror or (
						reverse == '?' and getRandomDir() or errorf(2, 'SendHeader', 'Value on line 1, section 4 is not "t", "f", "?", "m", "", or nil.')
					)
				)
			)

			-- Determine relative pivot location.
			relpivot = firstLine[2] or ''
			relpivot = (abspivot + (relpivot == '' and 0 or math.floor(tonumber(relpivot) or errorf(2, 'SendHeader', 'Malformed number on line 1, section 2.'))) * mirror) % sides

			-- Determine tolerance value.
			tolerance = firstLine[5] or ''
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
			return
		end

		-- Check for looping
		local leadingChar, remainder = currentLine[1]:match('^([%[%]])(.*)')
		if leadingChar == '[' then
			-- Begin a loop
			-- Find range
			local a = math.max(math.floor(tonumber(remainder) or errorf(2, 'SendLoop', 'Malformed number on line %d, section 1.', lc)), 0)
			local b = currentLine[2] or ''
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
				local section = currentLine[2] or ''
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
				local section = currentLine[4] or ''
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
				0, horizontal, self.link, sides, thickness, ix, (reverseflag == '~' and -1 or 1) * reverse, nonloop, loop,
				split == '' or split == '|' and ix or (ix + (split == '-' and floorsides or ceilsides)) % sides
			)
			self.timeline:event(seconds)

			-- * Relative pivot control
			do
				local section = currentLine[3] or ''
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

-- Begins the pattern sequence.
-- Once a pattern is completed, the next is spawned.
function Patternizer:spawn()
	local pattern = self.pattern
	pattern.ix = pattern.ix + 1

	local sides = self.sides:get()
	local defaultTable = pattern.d
	local patternTable = pattern[sides] or defaultTable
	local key = pattern.key[pattern.ix] or errorf(2, 'Begin', 'No keys provided.')

	local item = patternTable[key] or defaultTable[key]
	local outType = type(item)
	self:send(outType == 'string' and item or (outType == 'function' and item(sides, key) or ''))

	if pattern.ix >= pattern.len then
		shuffle(pattern.key)
		pattern.ix = 0
	end
end

-- Stops or resumes pattern generation. The timeline will still run.
function Patternizer:pause() self.__PAUSE = true end
function Patternizer:resume() self.__PAUSE = nil end

function Patternizer:assign(key, pattern, side)
	local pType = type(pattern)
	if pType ~= 'function' and pType ~= 'string' then errorf(2, 'Assign', 'Argument #2 is not a function or string.') end
	side = type(side) == 'number' and side or 'd'

	local group = self.pattern[side]
	if not group then
		group = setmetatable({}, self.pattern.d)
		self.pattern[side] = group
	end

	group[key] = pattern
end

function Patternizer:unassign(key, side)
	side = type(side) == 'number' and side or 'd'
	self.pattern[side][key] = nil
end

function Patternizer:assignTable(pTable, side)
	side = type(side) == 'number' and side or 'd'
	for _, v in pairs(type(pTable) == 'table' and pTable or errorf(2, 'Assign', 'Argument #2 is not a table.')) do
		local pType = type(v)
		if pType ~= 'function' and pType ~= 'string' then errorf(2, 'Assign', 'Table contains a non-string/function value.') end
	end
	self.pattern[side] = pTable
end

function Patternizer:key(...)
	local pattern = self.pattern
	pattern.key = {...}
	pattern.len = #pattern.key
	pattern.ix = 0
	shuffle(pattern.key)
end

-- Runs the patternizer.
function Patternizer:step(mFrameTime)
	if not (self.timeline:isRunning() or self.__PAUSE) then self:spawn() end
	self.timeline:step(mFrameTime)
end