u_execDependencyScript('library_extbase', 'extbase', 'syyrion', 'utils.lua')
u_execDependencyScript('library_extbase', 'extbase', 'syyrion', 'common.lua')
u_execDependencyScript('library_slider', 'slider', 'syyrion', 'master.lua')

local __E = setmetatable({
	hd = 'Header',
	lp = 'Loop',
	po = 'Position',
	th = 'Thickness',
	rp = 'RelativePivot',
	lk = 'Link',
	cr = 'Create',
	bg = 'SetBag',
	bk = 'BagKey',

	mfn = 'Malformed number on line %d.',
	uxp = 'Unexpected "%s" on line %d.',
	xch = 'Extraneous characters found on line %d.',
	arg = 'Argument #%d is not a%s %s. ',
	mis = 'Missing flag on line %d.',
	irg = 'Invalid range on line %d.'
}, {
	__call = function (this, level, err, ...)
		local t, msg = {...}, string.format('[%sError] ', this[err])
		for i = 1, #t do
			msg = msg .. this[t[i]]
		end
		return setmetatable({
			msg = msg,
			level = level + 1
		}, {
			__call = function (this, ...)
				error(string.format(this.msg, ...), this.level)
			end
		})
	end
})

BagSelector = {
	items = {},
	keys = {},
	ix = 0,
	len = 0
}
BagSelector.__index = BagSelector

function BagSelector:new()
	local newInst = {}
	setmetatable(newInst, self)
	return newInst
end

function BagSelector:setItems(...)
	self.items = {...}
	self:reset()
end

function BagSelector:setKeys(...)
	local t = {...}
	local len = #t
	for i = 1, len do
		if type(t[i]) ~= 'number' then __E(2, 'bk', 'arg')(i, '', 'number') end
	end
	self.keys = t
	self:reset()
	self:shuffle()
end

function BagSelector:reset()
	self.ix = 0
	self.len = #self.keys
end

function BagSelector:shuffle()
	shuffle(self.keys)
end

function BagSelector:next()
	self.ix = self.ix + 1
	local out = self.items[self.keys[self.ix]]
	if self.ix == self.len then
		self:shuffle()
		self.ix = 0
	end
	return out
end

function BagSelector:wrap()
	return function ()
		return self:next()
	end
end

Patternizer = {
	link = setmetatable({
		['c'] = cWall,
		['.'] = cWall,
		['1'] = cWall,
		['o'] = oWall,
		['r'] = rWall
	}, {__index = function () return nop end}),
	bags = {__index = function (this)
		return rawget(this, 'default') or nop
	end}
}
Patternizer.__index = Patternizer
Patternizer.link.__index = Patternizer.link

Patternizer.link.__call = function (this, _, char, fn)
	char = type(char) == 'string' and char:len() == 1 and char:match('([%d%a])') or __E(2, 'lk', 'arg')(1, 'n', 'alphanumeric character')
	local t = type(fn)
	fn = (t == 'function' or t == 'nil') and fn or __E(2, 'lk', 'arg')(1, '', 'function or nil')
	this[char] = fn
end

function Patternizer:new()
	local newInst = setmetatable({
		link = setmetatable({}, self.link),
		timeline = Keyframe:new(),
		bags = setmetatable({}, self.bags)
	}, self)
	return newInst
end

function Patternizer:send(str, ...)
	-- Cut out any uneccesary characters
	str = str:match('^[%s;]*(.-)[%s;]*$')

	-- Create lines table
	local lines = {}
	for line in str:gsplit('[%s;]*[\n;][%s;]*') do
		table.insert(lines, line:gsub('%s', ''):split(','))
	end

	-- Line counter
	local lc = 1
	local sides, abspivot, relpivot, tolerance

	local function randSide() return u_rndInt(0, sides - 1) end

	-- Check if there's a header
	do
		local firstLine = lines[lc]
		abspivot = firstLine[1]:match('^>(.*)')
		if abspivot then
			-- Read header information and fallback if needed
			sides = firstLine[4] or ''
			sides = sides == '' and l_getSides() or verifyShape(tonumber(sides) or __E(2, 'hd', 'mfn')(lc))

			abspivot = abspivot == '' and randSide() or math.floor(tonumber(abspivot) or __E(2, 'hd', 'mfn')(lc)) % sides

			relpivot = firstLine[2] or ''
			relpivot = abspivot + (relpivot == '' and 0 or math.floor(tonumber(relpivot) or __E(2, 'hd', 'mfn')(lc)) % sides)

			tolerance = firstLine[3] or ''
			tolerance = abspivot + (tolerance == '' and 10 or math.floor(tonumber(tolerance) or __E(2, 'hd', 'mfn')(lc)) % sides)

			lc = lc + 1
		else
			-- Assign random values
			sides = l_getSides()
			abspivot = randSide()
			relpivot = abspivot
			tolerance = 10
		end
	end

	local halfSides, reloffset, loops, depth = math.floor(sides / 2), 0, {}, 0

	while true do
		-- Make reference to current line
		local currentLine = lines[lc]
		-- Exit if end of pattern is reached
		if not currentLine then break end

		-- Check for looping
		local leadingChar, remainder = currentLine[1]:match('^([%[%]])(.*)')
		if leadingChar == '[' then
			-- Begin a loop
			local a = math.max(math.floor(tonumber(remainder) or __E(2, 'lp', 'mfn')(lc)), 1)
			local b = currentLine[2] or ''
			b = math.max(math.floor(b == '' and a or tonumber(b) or __E(2, 'lp', 'mfn')(lc)), 1)
			if a > b then a, b = b, a end
			depth = depth + 1
			loops[depth] = {
				pos = lc,
				count = u_rndInt(a, b)
			}
		elseif leadingChar == ']' then
			-- Exit a loop
			local currentLoop = loops[depth] or __E(2, 'lp', 'uxp')(']', lc)
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

			-- Position
			local ix
			do
				local section = currentLine[4]
				if (section or '') == '' then
					-- Section is empty: set default
					ix = relpivot
				else
					-- Find and verify flag
					local head, flag, tail = section:match('(.*)([!%*])(.*)')
					if not flag then __E(2, 'po', 'mis')(lc) end
					if tail ~= '' then __E(2, 'po', 'xch')(lc) end
					-- Set position value
					local ofs = head == '' and 0 or math.floor(tonumber(head) or __E(2, 'po', 'mfn')(lc))
					ix = ((flag == '!' and abspivot or relpivot) + ofs) % sides
				end
			end

			-- Thickness/Delay
			local thickness, seconds
			do
				local section = currentLine[2]
				if (section or '') == '' then
					-- Section is empty: set defaults
					seconds = getIdealDelayInSeconds(sides)
					thickness = secondsToThickness(seconds)
				else
					-- Find flag
					local head, flag, tail = section:match('(.*)([!%*%?])(.*)')
					if flag == '!' then
						-- Check for extra characters
						if tail ~= '' then __E(2, 'th', 'xch')(lc) end
						-- Assign absolute thickness
						thickness = (head == '' and THICKNESS or tonumber(head) or __E(2, 'th', 'mfn')(lc)) - tolerance
						seconds = thicknessToSeconds(thickness)
					elseif flag == '*' then
						-- Check for extra characters
						if tail ~= '' then __E(2, 'th', 'xch')(lc) end
						-- Assign dynamic thickness
						seconds = getIdealDelayInSeconds(sides) * (head == '' and 1 or tonumber(head) or __E(2, 'th', 'mfn')(lc))
						thickness = secondsToThickness(seconds)
					elseif flag == '?' then
						-- Check for tail flags
						if tail == '' or tail == '-' then
							-- Assign dynamic thickness for shortest path
							seconds = getIdealDelayInSeconds(sides) * reloffset
						elseif tail == '+' then
							-- Assign dynamic thickness for longest path
							seconds = getIdealDelayInSeconds(sides) * (sides - reloffset)
						else
							-- No flags found
							__E(2, 'th', 'xch')(lc)
						end
						seconds = seconds * (head == '' and 1 or tonumber(head) or __E(2, 'th', 'mfn')(lc))
						thickness = secondsToThickness(seconds)
					else
						-- Missing flag
						__E(2, 'th', 'mis')(lc)
					end
				end
			end

			-- Add to timeline
			self.timeline:event(0, nil, self.horizontal, nil, nil, self, currentLine[1], ix, sides, thickness + tolerance, ...)
			self.timeline:event(seconds)

			-- relpivot control
			do
				local section = currentLine[3]
				if (section or '') == '' then
					-- Section is empty: set default
					reloffset = 0
				else
					-- Save the old position
					local oldpos = relpivot
					-- Find flag
					local head, flag, tail = section:match('^(.-)([!%*%?])(.*)$')
					if not flag then
						-- Flag is missing
						__E(2, 'rp', 'mis')(lc)
					elseif flag == '?' then
						-- Flag is '?'
						-- Find secondary flag
						local rflag, rtail = tail:match('^([!%*%^])(.*)')
						if rflag then
							-- Function to generate a range
							local function range()
								-- Read range numbers
								local a = math.floor(tonumber(head) or __E(3, 'rp', 'mfn')(lc))
								local b = rtail == '' and -a or math.floor(tonumber(rtail) or __E(3, 'rp', 'mfn')(lc))
								-- Reorder if necessary
								if a > b then a, b = b, a end
								return a, b
							end

							-- Check secondary flag type
							if rflag == '^' then
								if head == '' and rtail == '' then
									-- If both numbers are omitted, pick a random location that isn't the current
									relpivot = relpivot + u_rndInt(1, sides - 1) % sides
								else
									-- Offset the relative pivot while excluding 0
									local t, a, b = {}, range()
									for i = a, b do
										if i ~= 0 then table.insert(t, i) end
									end
									local len = #t
									if len == 0 then __E(2, 'rp', 'irg')(lc) end
									relpivot = relpivot + t[u_rndIntUpper(len)] % sides
								end
							else
								-- Pick random relative to absolute pivot or 
								relpivot = ((rflag == '!' and abspivot or relpivot) + u_rndInt(range())) % sides
							end
						else
							-- Secondary flag is missing
							-- Check for extra characters
							if head ~= '' and tail ~= '' then __E(2, 'rp', 'xch')(lc) end
							-- Pick a random side
							relpivot = randSide()
						end
					else
						-- Flag is '!' or '*'
						-- Check for extra characters
						if tail ~= '' then __E(2, 'rp', 'xch')(lc) end
						-- Set relpivot value
						local ofs = head == '' and 0 or math.floor(tonumber(head) or __E(2, 'rp', 'mfn')(lc))
						relpivot = ((flag == '!' and abspivot or relpivot) + ofs) % sides
					end

					-- Set relative offset to shortest distance between the old and new position
					local diff = math.abs(relpivot - oldpos)
					if diff > halfSides then
						diff = sides - diff
					end
					reloffset = diff
				end
			end
		end
		lc = lc + 1
	end
	return relpivot, reloffset
end

--[[
	Functions to be linked must have the form
	function (side, thickness) end
]]

-- Creates a single ring of walls

function Patternizer:horizontal(str, ix, sides, th, ...)
	sides, ix = type(sides) == 'number' and math.floor(sides) or l_getSides(), type(ix) == 'number' and math.floor(ix) or 0
	local limit = ix + sides
	str = type(str) == 'string' and str or __E(2, 'cr', 'arg')(1, '', 'string')
	local nonLoop, loop = str:match('(.*)|(.*)')
	if not nonLoop then nonLoop, loop = str, '' end

	local function make(p, ...)
		local t = {...}
		p:gsub('[%d%a%._]', function (s)
			self.link[s](ix % sides, th, unpack(t))
			ix = ix + 1
			if ix == limit then error() end
			return s
		end)
	end

	if not pcall(make, nonLoop, ...) then return end

	if loop:len() == 0 then return end

	while pcall(make, loop, ...) do end
end

function Patternizer:setDefaultBag(bag)
	local t = type(bag)
	bag = (t == 'function' or t == 'nil') and bag or __E(2, 'bg', 'arg')(1, '', 'function or nil')
	self.bags.default = bag
end

function Patternizer:setBag(bag, ...)
	local t = type(bag)
	bag = (t == 'function' or t == 'nil') and bag or __E(2, 'bg', 'arg')(1, '', 'function or nil')
	for ix, wl in pairs({...}) do
		self.bags[type(wl) == 'number' and wl or __E(2, 'bg', 'arg')(ix + 1, '', 'number')] = bag
	end
end

function Patternizer:run(mFrameTime, ...)
	if not self.timeline:isRunning() then
		local str = self.bags[l_getSides()]()
		if type(str) == 'string' then
			self:send(str, ...)
		end
	end
	self.timeline:step(mFrameTime)
end