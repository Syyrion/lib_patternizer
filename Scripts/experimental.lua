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
    sides = Cascade.new(Filter.SIDE_COUNT, nil, function (self) return self.val or l_getSides() end),
    mirroring = Cascade.new(Filter.BOOLEAN, true),
    randsideinit = Cascade.new(Filter.BOOLEAN, true),
    spawndistance = Cascade.new(Filter.NON_NEGATIVE, nil, l_getWallSpawnDistance)
}

Patternizer.link['.'] = Patternizer.link['c']
Patternizer.link['1'] = Patternizer.link['c']
Patternizer.link.__index = Patternizer.link
Patternizer.__index = Patternizer

function Patternizer:new(...)
    local newInst = setmetatable({
        new = __NIL,
        link = setmetatable({}, self.link),

        sides = self.sides:new(),
        mirroring = self.mirroring:new(),
        randsideinit = self.randsideinit:new(),

        spawndistance = self.spawndistance:new(),
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
    char = Filter.STRING(char) and char:match('^([%w%._])$') or errorf(2, 'Link', 'Argument #1 is not an alphanumeric character, period, or underscore.')
    self.link[char] = Filter.FUNCTION(fn) and fn or errorf(2, 'Link', 'Argument #2 is not a function.')
end

-- Unlinks a character
function Patternizer:unlink(...)
    local t = {...}
    local len = #t
    for i = 1, len do
        local char = t[i]
        char = Filter.STRING(char) and char:match('^([%w%._])$') or errorf(2, 'Link', 'Argument #%d is not an alphanumeric character, period, or underscore.', i)
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
    ['abs'] = function (_, stack) stack:push(math.abs(stack:pop())) end,
    ['sgn'] = function (_, stack) stack:push(getSign(stack:pop())) end,

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

    -- Variables
    ['$sides'] = function (_, stack, env) stack:push(env.sides) end,
    ['$hsides'] = function (_, stack, env) stack:push(env.hsides) end
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
        if depth == 0 or times == 0 then return end
        depth = depth % stack.sp
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
    -- ['if'] = ['while']
    ['else'] = function (_, _, env, jump) env.pc = jump end,
    -- ['end'] = ['else'],
    ['return'] = __TRUE,
    ['#restrict'] = __TRUE,

    -- Variables
    ['$th'] = function (_, stack) stack:push(THICKNESS) end,
    ['$idealth'] = function (_, stack, env) stack:push(env.idealth) end,
    ['$idealdl'] = function (_, stack, env) stack:push(env.idealdl) end,
    ['$sperpr'] = function (_, stack) stack:push(SECONDS_PER_PLAYER_ROTATION) end,
    ['$abs'] = function (_, stack, env) stack:push(env.abs) end,
    ['$rel'] = function (_, stack, env) stack:push(env.rel) end,
    ['$rof'] = function (_, stack, env) stack:push(env.rof) end,
    ['$mirror'] = function (_, stack, env) stack:push(env.mirror) end,
    ['$tolerance'] = function (_, stack, env) stack:push(env.tolerance) end,

    -- Position functions
    ['rmv'] = function (_, stack, env)
        local ofs = stack:pop()
        env.rof = (ofs + env.hsides) % env.sides - env.hsides
        env.rel = (env.rel + ofs * env.mirror) % env.sides
    end,
    ['amv'] = function (_, stack, env)
        local ofs = stack:pop() * env.mirror
        local old = env.rel
        env.rel = ofs % env.sides
        env.rof = (env.rel - old) * env.mirror
    end,
    ['>>'] = function (_, stack, env)
        local b = stack:pop() * env.mirror; stack:push((stack:pop() + b) % env.sides)
    end,
    ['<<'] = function (_, stack, env)
        local b = stack:pop() * env.mirror; stack:push((stack:pop() - b) % env.sides)
    end,

    -- ['a'] = ['$abs']
    ['r'] = function (_, stack, env) stack:push((env.abs + env.rel) % env.sides) end,

    -- Thickness functions
    ['i'] = function (_, stack, env) stack:push(stack:pop() * env.idealth) end,
    ['spath'] = function (_, stack, env) stack:push(math.abs(env.rof) * env.idealth) end,
    ['lpath'] = function (_, stack, env) stack:push((env.sides - math.abs(env.rof)) * env.idealth) end,
    ['th2s'] = function (_, stack) stack:push(thicknessToSeconds(stack:pop())) end,
    ['s2th'] = function (_, stack) stack:push(secondsToThickness(stack:pop())) end,

    -- Timeline functions
    ['sleep'] = function (self, stack) self.timeline:event(stack:pop()) end,
    ['thsleep'] = function (self, stack) self.timeline:event(thicknessToSeconds(stack:pop())) end,
    ['rsleep'] = function (self, stack) self.timeline:event(SECONDS_PER_PLAYER_ROTATION * stack:pop()) end,
    ['call:'] = function (self, stack, env, char)
        local args = {}
        for i = stack:pop(), 1, -1 do
            args[i] = stack:pop()
        end
        self.timeline:eval(0, self.link[char], unpack(args))
        env.pc = env.pc + 1
    end,

    ['h:'] = function (self, stack, env, data)
        local th = stack:pop()
        self.timeline:eval(0, horizontal, self.link, stack:pop(), env.sides, th, env.mirror, data)
        env.pc = env.pc + 1
    end,
    ['t:'] = function (self, stack, env, data)
        local th = stack:pop()
        self.timeline:eval(0, horizontal, self.link, stack:pop(), env.sides, th + env.tolerance, env.mirror, data)
        env.pc = env.pc + 1
    end,
    ['p:'] = function (self, stack, env, data)
        local th = stack:pop()
        self.timeline:eval(0, horizontal, self.link, stack:pop(), env.sides, th + env.tolerance, env.mirror, data)
        self.timeline:event(thicknessToSeconds(th))
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

function Patternizer:strwall(str, pos, th)
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
-- ! Legacy name
Patternizer.strWall = Patternizer.strwall



-- Compiles a string into a table.
function Patternizer.compile(str)
    str = (Filter.STRING(str) and str or errorf(2, 'Compilation', 'Argument #1 is not a string.')):gsub('//[^\n]*', ''):match('^%s*(.-)%s*$')
    if str:len() == 0 then return {} end
    local ix, newProgram, stack = 1, {}, Stack:new()

    local tokenizer

    local restricttokenizer = function (ins)
        newProgram[ix] = BASIC_INSTRUCTIONS[ins] and ins or tonumber(ins) or errorf(3, 'Compilation', 'Unrecognized or illegal "%s" at instruction %d after #restrict.', ins, ix)
    end

    local bodytokenizer = function(ins)
        if ins == '#restrict' then
            newProgram[ix] = ins
            newProgram.restrict = ix + 1
            tokenizer = restricttokenizer
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
            if ins == 'h:' or ins == 't:' or ins == 'p:' then
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

    tokenizer = bodytokenizer

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
        hsides = sides * 0.5,
        idealth = getIdealThickness(sides),
        idealdl = getIdealDelayInSeconds(sides),
        abs = self.randsideinit:get() and u_rndInt(0, sides - 1) or 0,
        rel = 0,
        rof = 0,
        mirror = self.mirroring:get() and getRandomDir() or 1,
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
    local sides = self.sides:get()
    return interpret(nil, program, BASIC_INSTRUCTIONS, {
        pc = program.restrict,
        sides = sides,
        hsides = sides * 0.5
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
        local p = patterns[i]
        if p ~= exclude and self:restrict(p) then
            len = len + 1
            pool[len] = p
        end
    end
    if len > 0 then
        local choice = pool[u_rndInt(1, len)]
        self:interpret(choice)
        self.pattern.previous = choice
        self.timeline:eval(0, self.enable, self)
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

-- Adds compiles and patterns
function Patternizer:add(...)
    local t = {...}
    for i = 1, #t do
        t[i] = self.compile(t[i])
    end
    self:addProgram(unpack(t))
end

-- Accepts already compiled patterns
function Patternizer:addprogram(...)
    local t, start = {...}, self.pattern.total
    local len = #t
    for i = 1, len do
        local program = t[i]
        self.pattern.list[start + i] = Filter.TABLE(program) and program or errorf(2, 'AddProgram', 'Argument #%d is not a table.', i)
    end
    self.pattern.total = start + len
end
-- ! Legacy name
Patternizer.addProgram = Patternizer.addprogram

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