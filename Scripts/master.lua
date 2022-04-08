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

Patternizer = {
	link = {
		['c'] = function (...) cWall(...) end,
		['o'] = function (...) oWall(...) end,
		['r'] = function (...) rWall(...) end
	},
	sides = Discrete:new(nil, function (self) return self.val or l_getSides() end, Filter.SIDE_COUNT),
	tolerance = Discrete:new(4, nil, Filter.NON_NEGATIVE)
}

Patternizer.link['.'] = Patternizer.link['c']
Patternizer.link['1'] = Patternizer.link['c']
Patternizer.link.__index = Patternizer.link
Patternizer.__index = Patternizer

function Patternizer:new(...)
	local newInst = setmetatable({
		new = __NIL,
		link = setmetatable({}, self.link),
		timeline = Keyframe:new(),
		sides = self.sides:new(),
		tolerance = self.tolerance:new(),
		pattern = {
			list = {},
			total = 0
		}
	}, self)
	newInst:add(...)
	return newInst
end

-- Links characters to functions so that certain actions are performed when those characters appear in a pattern string.
-- Functions to be linked must have the form: function (side, thickness) end
-- Doubles as the table for links
function Patternizer.link.__call(_, self, char, fn)
	char = type(char) == 'string' and char:match('^([%w%._])$') or errorf(2, 'Link', 'Argument #1 is not an alphanumeric character, period, or underscore.')
	self.link[char] = type(t == 'function') and fn or errorf(2, 'Link', 'Argument #2 is not a function.')
end

-- Unlinks a character
function Patternizer:unlink(...)
	local t = {...}
	local len = #t
	for i = 1, len do
		local char = t[i]
		char = type(char) == 'string' and char:match('^([%w%._])$') or errorf(2, 'Link', 'Argument #%d is not an alphanumeric character, period, or underscore.', i)
		self.link[char] = nil
	end
end



--[[
	* Stack class
]]

local Stack = {}
Stack.__index = Stack

function Stack:new()
	return setmetatable({sp = 1}, self)
end

function Stack:push(n)
	self[self.sp] = n
	self.sp = self.sp + 1
end

function Stack:pop(depth, header, message, ...)
	self.sp = self.sp - 1
	return self[self.sp > 0 and self.sp or errorf((depth or 0) + 1, header or 'Stack', message or 'Stack underflow.', ...)]
end



--[[
	* Wall generator
	Creates a single row of walls
]]
local function horizontal(link, pos, sides, th, dir, data)
	local step, ix = sides / data.length, 0
	dir = dir * data.dir
	local function make(str, stop)
		str:gsub('[%w%._]', function (char)
			(link[char] or __NIL)((ix + pos) % sides, th)
			ix = ix + dir
			if ix == stop then error() end
			return char
		end)
	end

	for i = 1, data.length do
		local stop = data[i].d(i * step) * dir
		if pcall(make, data[i].nl, stop) then
			local l = data[i].l
			if l then
				while pcall(make, l, stop) do end
			else
				ix = stop
			end
		end
	end
end



--[[
	* Instructions
]]

-- Instuctions available only after the #restrict instruction
local BASIC_INSTRUCTIONS = {
	-- Math
	['+'] = function (_, stack) stack:push(stack:pop() + stack:pop()) end,
	['-'] = function (_, stack) local b = stack:pop(); stack:push(stack:pop() - b) end,
	['*'] = function (_, stack) stack:push(stack:pop() * stack:pop()) end,
	['/'] = function (_, stack) local b = stack:pop(); stack:push(stack:pop() / b) end,
	['%'] = function (_, stack) local b = stack:pop(); stack:push(stack:pop() % b) end,
	['floor'] = function (_, stack) stack:push(math.floor(stack:pop())) end,
	['ceil'] = function (_, stack) stack:push(math.ceil(stack:pop())) end,
	['abs'] = function (_, stack) stack:push(math.abs(stack:pop(pc))) end,

	-- Logic
	['=='] = function (_, stack) stack:push((stack:pop() == stack:pop()) and 1 or 0) end,
	['!='] = function (_, stack) stack:push((stack:pop() ~= stack:pop()) and 1 or 0) end,
	['<'] = function (_, stack) local b = stack:pop(); stack:push((stack:pop() < b) and 1 or 0) end,
	['<='] = function (_, stack) local b = stack:pop(); stack:push((stack:pop() <= b) and 1 or 0) end,
	['>'] = function (_, stack) local b = stack:pop(); stack:push((stack:pop() > b) and 1 or 0) end,
	['>='] = function (_, stack) local b = stack:pop(); stack:push((stack:pop() >= b) and 1 or 0) end,
	['or'] = function (_, stack) local b = stack:pop(); stack:push((stack:pop() ~= 0 or b ~= 0) and 1 or 0) end,
	['and'] = function (_, stack) local b = stack:pop(); stack:push((stack:pop() ~= 0 and b ~= 0) and 1 or 0) end,
	['not'] = function (_, stack) stack:push(stack:pop() == 0 and 1 or 0) end,

	-- Constants
	['$sides'] = function (_, stack, env) stack:push(env.sides) end
}
BASIC_INSTRUCTIONS.__index = BASIC_INSTRUCTIONS

-- The full set of instructions
local INSTRUCTIONS = {
	-- Random function
	['rnd'] = function (_, stack) local b = stack:pop(); stack:push(u_rndInt(stack:pop(), b)) end,

	-- Stack operations
	['dup'] = function (_, stack) local n = stack:pop(); stack:push(n); stack:push(n) end,
	['drop'] = function (_, stack) stack:pop() end,
	['swap'] = function (_, stack) local a = stack:pop(); local b = stack:pop(); stack:push(a); stack:push(b) end,
	['over'] = function (_, stack) local a = stack:pop(); local b = stack:pop(); stack:push(b); stack:push(a); stack:push(b) end,
	['roll'] = function (_, stack)
		local times = stack:pop()
		local depth = stack:pop()
		if depth == 0 then return end
		depth = depth % stack.sp
		times = times % depth
		local buffer = {}
		for i = depth - 1, 0, -1 do buffer[i] = stack:pop() end
		for i = 0, depth - 1 do stack:push(buffer[(i + times) % depth]) end
	end,

	-- Control flow
	['while'] = function (_, stack, env, jump) env.pc = stack:pop() == 0 and jump or env.pc + 1 end,
	['for'] = function (_, stack, env, jump)
		local i = stack:pop()
		if i == 0 then
			env.pc = jump
		else
			stack:push(i - 1)
			env.pc = env.pc + 1
		end
	end,
	-- ['if'] = ['abs']
	['else'] = function (_, _, env, jump) env.pc = jump end,
	-- ['end'] = ['else'],
	['return'] = __TRUE,
	['#restrict'] = __TRUE,

	-- Constants
	['$hsides'] = function (_, stack, env) stack:push(env.hsides) end,
	['$th'] = function (_, stack) stack:push(THICKNESS) end,
	['$idealth'] = function (_, stack, env) stack:push(env.idealth) end,
	['$idealdl'] = function (_, stack, env) stack:push(env.idealdl) end,
	['$sperpr'] = function (_, stack) stack:push(SECONDS_PER_PLAYER_ROTATION) end,

	-- Variables
	['$abs'] = function (_, stack, env) stack:push(env.abs) end,
	['=abs'] = function (_, stack, env) env.abs = stack:pop() end,
	['$rel'] = function (_, stack, env) stack:push(env.rel) end,
	['=rel'] = function (_, stack, env) env.rel = stack:pop() end,
	['$rof'] = function (_, stack, env) stack:push(env.rof) end,
	['=rof'] = function (_, stack, env) env.rof = stack:pop() end,
	['$mirror'] = function (_, stack, env) stack:push(env.mirror) end,
	['=mirror'] = function (_, stack, env) env.mirror = stack:pop() == 0 and 1 or 0 end,
	['$tolerance'] = function (_, stack, env) stack:push(env.tolerance) end,
	['=tolerance'] = function (_, stack, env) env.tolerance = stack:pop() end,

	-- Position functions
	['rmv'] = function (_, stack, env)
		local ofs = stack:pop() * env.mirror
		local aofs = math.abs(ofs)
		env.rof = aofs > env.hsides and (env.sides - aofs) or aofs
		env.rel = (env.rel + ofs) % env.sides
	end,
	-- ['a'] = ['$abs']
	['r'] = function (_, stack, env) stack:push((env.abs + env.rel) % env.sides) end,

	-- Thickness functions
	['i'] = function (_, stack, env) stack:push(stack:pop() * env.idealth) end,
	['spath'] = function (_, stack, env) stack:push(env.rof * env.idealth) end,
	['lpath'] = function (_, stack, env) stack:push((env.sides - env.rof) * env.idealth) end,
	['th2s'] = function (_, stack) stack:push(thicknessToSeconds(stack:pop())) end,
	['s2th'] = function (_, stack) stack:push(secondsToThickness(stack:pop())) end,
	['notol'] = function (_, stack, env) stack:push(stack:pop() - env.tolerance) end,

	-- Timeline functions
	['h:'] = function (self, stack, env, data)
		local th = stack:pop()
		local pos = stack:pop()
		self.timeline:eval(0, horizontal, self.link, pos, env.sides, th + env.tolerance, env.mirror, data)
		env.pc = env.pc + 1
	end,
	['sleep'] = function (self, stack) self.timeline:event(stack:pop()) end,
	['thsleep'] = function (self, stack) self.timeline:event(thicknessToSeconds(stack:pop())) end,
	['rsleep'] = function (self, stack) self.timeline:event(SECONDS_PER_PLAYER_ROTATION * stack:pop()) end,
	['p:'] = function (self, stack, env, data)
		local th = stack:pop()
		local pos = stack:pop()
		self.timeline:eval(0, horizontal, self.link, pos, env.sides, th + env.tolerance, env.mirror, data)
		self.timeline:event(thicknessToSeconds(th))
		env.pc = env.pc + 1
	end,
	['call:'] = function (self, stack, env, char)
		local args = {}
		for i = stack:pop(), 1, -1 do
			args[i] = stack:pop()
		end
		self.timeline:eval(0, self.link[char], unpack(args))
		env.pc = env.pc + 1
	end
}
INSTRUCTIONS['if'] = INSTRUCTIONS['while']
INSTRUCTIONS['end'] = INSTRUCTIONS['else']
INSTRUCTIONS['a'] = INSTRUCTIONS['$abs']

setmetatable(INSTRUCTIONS, BASIC_INSTRUCTIONS)



--[[
	* Compilers
]]

local function decode(dir, pattern)
	local data, init, plen = {}, 1, pattern:len()
	repeat
		local _, last, nonloop, loop, div = pattern:find('([%w%._]*)|?([%w%._]*)([%+%-]?)', init)
		table.insert(data, {
			nl = nonloop,
			l = loop:len() > 0 and loop or nil,
			d = div == '+' and math.ceil or math.floor
		})
		init = last + 1
	until last == plen
	data.length = #data
	data.dir = dir == '~' and -1 or 1
	return data
end

function Patternizer:strWall(str, pos, th)
	local dir, pattern = str:match('^(~?)([%w%._|%+%-]-)$')
	if not dir then errorf(3, 'WallString', 'Invalid pattern.', ix, ins) end
	horizontal(
		self.link,
		Filter.INTEGER(pos) and pos or errorf(2, 'WallString', 'Argument #2 is not an integer.'),
		self.sides:get(),
		Filter.NUMBER(th) and th or errorf(2, 'WallString', 'Argument #3 is not a number.'),
		1,
		decode(dir, pattern)
	)
end

-- Compiles a string into a table.
function Patternizer.compile(str)
	str = (Filter.STRING(str) and str or errorf(2, 'Compilation', 'Argument #1 is not a string.')):gsub('//.*\n', '\n'):match('^%s*(.-)%s*$')
	local ix, newProgram, stack = 1, {}, Stack:new()

	local tokenizer

	local restrictTokenizer = function (ins)
		newProgram[ix] = BASIC_INSTRUCTIONS[ins] and ins or tonumber(ins) or errorf(3, 'Compilation', 'Unrecognized "%s" at instruction %d.', ins, ix)
	end

	local bodyTokenizer = function(ins)
		if ins == '#restrict' then
			newProgram[ix] = ins
			newProgram.restrict = ix + 1
			tokenizer = restrictTokenizer
		elseif ins == 'while' or ins == 'for' or ins == 'if' then
			stack:push({type = ins, loc = ix})
			newProgram[ix] = {ins = ins}
		elseif ins == 'else' then
			local top = stack:pop(3, 'Compilation', 'Unmatched "%s" at instruction %d', ins, ix)
			if top.type ~= 'if' then errorf(3, 'Compilation', 'Unmatched "%s" at instruction %d', ins, ix) end
			newProgram[ix] = {ins = ins}
			newProgram[top.loc].data = ix + 1
			stack:push({type = ins, loc = ix})
		elseif ins == 'end' then
			local top = stack:pop(3, 'Compilation', 'Unmatched "%s" at instruction %d', ins, ix)
			newProgram[ix] = {ins = ins, data = (top.type == 'while' or top.type == 'for') and top.loc or ix + 1}
			newProgram[top.loc].data = ix + 1
		else
			local chars
			ins, chars = ins:match('^([^:]+:?)(.-)$')
			if ins == 'h:' or ins == 'p:' then
				local dir, pattern = chars:match('^(~?)([%w%._|%+%-]-)$')
				if not dir then errorf(3, 'Compilation', 'Invalid pattern at instruction %d, "%s".', ix, ins) end
				newProgram[ix] = {ins = ins, data = decode(dir, pattern)}
			elseif ins == 'call:' then
				newProgram[ix] = {ins = ins, data = chars:match('^[%w%._]$') or errorf(3, 'Compilation', 'At instruction %d, "%s" can only accept one function character.', ix, ins)}
			else
				newProgram[ix] = INSTRUCTIONS[ins] and ins or tonumber(ins) or errorf(3, 'Compilation', 'Unrecognized "%s" at instruction %d.', ins, ix)
			end
		end
	end

	tokenizer = bodyTokenizer

	for ins in str:gsplit('[%s]+') do
		tokenizer(ins)
		ix = ix + 1
	end

	if stack.sp > 1 then
		local top = stack:pop()
		errorf(2, "Compilation", 'Unmatched "%s" at instruction %d.', top.type, top.loc)
	end

	return newProgram
end



--[[
	* Interpreters
]]

local INSTRUCTION_LIMIT = 1048575

local function interpret(self, program, instructionSet, env, stack, errlvl)
	for _ = 1, INSTRUCTION_LIMIT do
		local ins = program[env.pc]
		local instype = type(ins);
		if instype == 'number' then
			stack:push(ins)
			env.pc = env.pc + 1
		elseif instype == "string" then
			if instructionSet[ins](self, stack, env) then
				return unpack(stack, 1, stack.sp - 1)
			end
			env.pc = env.pc + 1
		elseif instype == 'table' then
			instructionSet[ins.ins](self, stack, env, ins.data)
		else
			return unpack(stack, 1, stack.sp - 1)
		end
	end
	errorf(errlvl + 1, 'Runtime', 'Instruction limit of %d reached.', INSTRUCTION_LIMIT)
end

-- Interprets a compiled program.
function Patternizer:interpret(program, ...)
	if not Filter.TABLE(program) then errorf(2, 'Interpret', 'Argument #1 is not a table.') end
	local env, stack = nil, Stack:new()
	local sides = self.sides:get()
	env = {
		pc = 1,
		sides = sides,
		hsides = sides / 2,
		idealth = getIdealThickness(sides),
		idealdl = getIdealDelayInSeconds(sides),
		abs = u_rndInt(0, sides - 1),
		rel = 0,
		rof = 0,
		mirror = getRandomDir(),
		tolerance = self.tolerance:get(),
	}
	local args = {...}
	for i = 1, #args do
		stack:push(args[i])
	end
	return interpret(self, program, INSTRUCTIONS, env, stack, 2)
end

function Patternizer:restrict(program)
	if not Filter.TABLE(program) then errorf(2, 'Interpret', 'Argument #1 is not a table.') end
	if not program.restrict then return true end
	return interpret(nil, program, BASIC_INSTRUCTIONS, {
		pc = program.restrict,
		sides = self.sides:get()
	}, Stack:new(), 2) ~= 0
end

-- Directly interprets a string.
function Patternizer:send(str, ...)
	return self:interpret(self.compile(str), ...)
end



--[[
	* Pattern Organizers
]]

function Patternizer:disable() self.spawn = __NIL end
function Patternizer:enable() self.spawn = nil end

-- Begins the pattern sequence.
-- This function is disabled while a pattern exists on the timeline.
function Patternizer:spawn()
	local patterns, plistlen, exclude = self.pattern.list, self.pattern.total, self.pattern.previous
	local pool, len = {}, 0
	for i = 1, plistlen do
		if patterns[i] ~= exclude and self:restrict(patterns[i]) then
			len = len + 1
			pool[len] = patterns[i]
		end
	end
	if len > 0 then
		local choice = pool[u_rndInt(1, len)]
		self:interpret(choice)
		self.pattern.previous = choice
		self:disable()
	end
end

-- Stops or resumes pattern generation. The timeline will still run.
function Patternizer:pause() self.pspawn = __NIL end
function Patternizer:resume() self.pspawn = nil end

-- Same as spawn but can be disabled by pause and resume functions.
function Patternizer:pspawn()
	self:spawn()
end

-- Adds patterns
function Patternizer:add(...)
	local t, start = {...}, self.pattern.total
	local len = #t
	for i = 1, len do
		self.pattern.list[start + i] = self.compile(t[i])
	end
	self.pattern.total = start + len
end

-- Removes all patterns
function Patternizer:clear()
	for i = 1, self.pattern.total do
		self.pattern.list[i] = nil
	end
	self.pattern.total = 0
	self.pattern.previous = nil
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