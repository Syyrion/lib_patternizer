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

u_execDependencyScript("library_extbase", "extbase", "syyrion", "utils.lua")
u_execDependencyScript("library_extbase", "extbase", "syyrion", "common.lua")
u_execScript("signal.lua")

--[[
    * Patternizer
]]
---@class Patternizer
---@field link table
---@field included_functions table
Patternizer = {
    link = {
        ["c"] = function(...)
            cWall(...)
        end,
        ["o"] = function(...)
            oWall(...)
        end,
        ["r"] = function(...)
            rWall(...)
        end,
    },
    sides = Cascade.new(Filter.SIDE_COUNT, nil, function(self)
        return self.val or l_getSides()
    end),
    mirroring = Cascade.new(Filter.BOOLEAN, true),
    randsideinit = Cascade.new(Filter.BOOLEAN, true),
    tolerance = Cascade.new(Filter.NUMBER, 4),
}

Patternizer.link["."] = Patternizer.link["c"]
Patternizer.link["1"] = Patternizer.link["c"]
Patternizer.link.__index = Patternizer.link
Patternizer.__index = Patternizer

function Patternizer:new(...)
    local newInst = setmetatable({
        new = __NIL,
        link = setmetatable({}, self.link),
        timeline = Signal.new_queue(),
        sides = self.sides:new(),
        mirroring = self.mirroring:new(),
        randsideinit = self.randsideinit:new(),
        tolerance = self.tolerance:new(),
        pattern = {
            list = {},
            total = 0,
        },
        included_functions = {},
    }, self)

    local t = { ... }
    for i = 1, #t do
        newInst:add_program(Patternizer.compile(t[i]))
    end

    return newInst
end

-- Links characters to functions so that certain actions are performed when those characters appear in a pattern string.
-- Functions to be linked must have the form: function (side, thickness) end
-- Doubles as the table for links
function Patternizer.link.__call(_, self, char, fn)
    if not Filter.FUNCTION(fn) then
        errorf(2, "Link", "Argument #2 is not a function.")
    end
    if not (Filter.STRING(char) and char:match("^([%w%._])$")) then
        errorf(2, "Link", "Argument #1 is not a single alphanumeric character, period, or underscore.")
    end
    self.link[char] = fn
end

-- Unlinks a character
function Patternizer:unlink(char)
    if not (Filter.STRING(char) and char:match("^([%w%._])$")) then
        errorf(2, "Link", "Argument #1 is not a single alphanumeric character, period, or underscore.")
    end
    self.link[char] = nil
end

--[[
    * Stack class
]]

---@class Stack
---@field sp number Holds the index of the next available slot
---@field list table Contains all objects in the stack
local Stack = {}
Stack.__index = Stack

function Stack:new()
    ---@class Stack
    local newinst = {
        sp = 1,
        list = {},
    }
    return setmetatable(newinst, self)
end

function Stack:push(n)
    self.list[self.sp] = n
    self.sp = self.sp + 1
end

function Stack:pop()
    self.sp = self.sp - 1
    if self.sp == 0 then
        errorf(0, "Stack", "Stack underflow (bad pop).")
    end
    local temp = self.list[self.sp]
    self.list[self.sp] = nil
    return temp
end

function Stack:peek(depth)
    local n = self.sp - 1 - (depth or 0)
    if n <= 0 then
        errorf(0, "Stack", "Stack underflow (bad peek).")
    end
    return self.list[n]
end

local RuntimeStack = {}
RuntimeStack.__index = RuntimeStack

function RuntimeStack:new()
    local newinst = {
        stack = Stack:new(),
        scope_stack = Stack:new(),
    }
    newinst.scope_stack:push(0)
    return setmetatable(newinst, self)
end

function RuntimeStack:push(n)
    self.stack:push(n)
end

function RuntimeStack:pop()
    if self.stack.sp == self.scope_stack:peek() then
        errorf(0, "Runtime", "Unable to modify stack snapshot after function statement has begun (bad pop).")
    end
    return self.stack:pop()
end

function RuntimeStack:peek(depth)
    return self.stack:peek(depth)
end

function RuntimeStack:begin_args()
    self.scope_stack:push(self.stack.sp)
end

function RuntimeStack:flush()
    local target_sp = self.scope_stack:pop()
    local current_sp = self.stack.sp
    local args = {}
    for i = current_sp - target_sp, 1, -1 do
        args[i] = self.stack:pop()
    end
    return args
end

--[[
    * Wall generator
    Creates a single row of walls
]]
---@param link table table of linked characters
---@param pos integer starting side
---@param sides integer number of sides
---@param th number thickness
---@param dir integer -1 or 1. Direction of generation
---@param data table
local function horizontal(link, pos, sides, th, dir, data)
    local step, ix = sides / data.length, 0
    dir = dir * data.dir
    local function make(str, stop)
        str:gsub("[%w%._]", function(char)
            (link[char] or __NIL)((ix + pos) % sides, th)
            ix = ix + dir
            if ix == stop then
                error()
            end
            return char
        end)
    end

    for i = 1, data.length do
        local stop = data[i].d(i * step) * dir
        if pcall(make, data[i].nl, stop) then
            local l = data[i].l
            if l then
                while pcall(make, l, stop) do
                end
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
    ["+"] = function(stack)
        stack:push(stack:pop() + stack:pop())
    end,
    ["-"] = function(stack)
        local b = stack:pop()
        stack:push(stack:pop() - b)
    end,
    ["*"] = function(stack)
        stack:push(stack:pop() * stack:pop())
    end,
    ["/"] = function(stack)
        local b = stack:pop()
        stack:push(stack:pop() / b)
    end,
    ["%"] = function(stack)
        local b = stack:pop()
        stack:push(stack:pop() % b)
    end,
    ["floor"] = function(stack)
        stack:push(math.floor(stack:pop()))
    end,
    ["ceil"] = function(stack)
        stack:push(math.ceil(stack:pop()))
    end,
    ["abs"] = function(stack)
        stack:push(math.abs(stack:pop()))
    end,
    ["sgn"] = function(stack)
        stack:push(getSign(stack:pop()))
    end,
    -- Random function
    ["rnd"] = function(stack)
        local b = stack:pop()
        stack:push(math.random(stack:pop(), b))
    end,

    -- Logic
    ["=="] = function(stack)
        stack:push((stack:pop() == stack:pop()) and 1 or 0)
    end,
    ["!="] = function(stack)
        stack:push((stack:pop() ~= stack:pop()) and 1 or 0)
    end,
    ["<"] = function(stack)
        local b = stack:pop()
        stack:push((stack:pop() < b) and 1 or 0)
    end,
    ["<="] = function(stack)
        local b = stack:pop()
        stack:push((stack:pop() <= b) and 1 or 0)
    end,
    [">"] = function(stack)
        local b = stack:pop()
        stack:push((stack:pop() > b) and 1 or 0)
    end,
    [">="] = function(stack)
        local b = stack:pop()
        stack:push((stack:pop() >= b) and 1 or 0)
    end,
    ["or"] = function(stack)
        local b = stack:pop()
        stack:push((stack:pop() ~= 0 or b ~= 0) and 1 or 0)
    end,
    ["and"] = function(stack)
        local b = stack:pop()
        stack:push((stack:pop() ~= 0 and b ~= 0) and 1 or 0)
    end,
    ["not"] = function(stack)
        stack:push(stack:pop() == 0 and 1 or 0)
    end,

    -- Variables
    ["$sides"] = function(stack, env)
        stack:push(env.sides)
    end,
    ["$hsides"] = function(stack, env)
        stack:push(env.hsides)
    end,

    ["#restrict"] = __TRUE,
    ["#abs"] = __TRUE,
    ["#mirror"] = __TRUE,
    ["#tolerance"] = __TRUE,
}

local function jump(_, env, jump)
    env.pc = jump
end

local function jump_if_zero(stack, env, jump)
    env.pc = stack:pop() == 0 and jump or env.pc + 1
end

local function push_abs_pos(stack, env)
    stack:push(env.abs)
end

local function begin_args(stack)
    stack:begin_args()
end

-- The full set of instructions
local INSTRUCTIONS = {
    -- Stack operations
    ["dup"] = function(stack)
        stack:push(stack:peek())
    end,
    ["drop"] = function(stack)
        stack:pop()
    end,
    ["swap"] = function(stack)
        local a = stack:pop()
        local b = stack:pop()
        stack:push(a)
        stack:push(b)
    end,
    ["over"] = function(stack)
        stack:push(stack:peek(1))
    end,
    ["raise"] = function(stack)
        local depth = stack:pop()
        stack:push(stack:peek(depth))
    end,
    ["clone"] = function(stack)
        local size = stack.sp - 1
        for i = 1, size do
            stack:push(stack:peek(size - 1))
        end
    end,

    ["roll"] = function(stack)
        local times = stack:pop()
        local depth = stack:pop()
        -- These specific inputs don't do anything.
        if depth == 0 or depth == 1 or times == 0 then
            return
        end
        depth = depth % stack.sp
        local buffer = {}
        for i = depth - 1, 0, -1 do
            buffer[i] = stack:pop()
        end
        for i = 0, depth - 1 do
            stack:push(buffer[(i + times) % depth])
        end
    end,

    -- Control flow
    ["if"] = jump_if_zero,
    ["while"] = jump_if_zero,
    ["for"] = function(stack, env, jump)
        local i = stack:pop()
        if i == 0 then
            env.pc = jump
        else
            stack:push(i - 1)
            env.pc = env.pc + 1
        end
    end,

    ["else"] = jump,
    ["end"] = jump,
    ["endif"] = jump,

    -- Returning true ends the program
    ["return"] = __TRUE,

    -- Variables
    ["$th"] = function(stack)
        stack:push(THICKNESS)
    end,
    ["$idealth"] = function(stack, env)
        stack:push(env.idealth)
    end,
    ["$idealdl"] = function(stack, env)
        stack:push(env.idealdl)
    end,
    ["$sperpr"] = function(stack)
        stack:push(SECONDS_PER_PLAYER_ROTATION)
    end,
    ["$abs"] = push_abs_pos,
    ["$rel"] = function(stack, env)
        stack:push(env.rel)
    end,
    ["$rof"] = function(stack, env)
        stack:push(env.rof)
    end,
    ["$mirror"] = function(stack, env)
        stack:push(env.mirror)
    end,
    ["$tolerance"] = function(stack, env)
        stack:push(env.tolerance)
    end,

    -- Position functions
    ["rmv"] = function(stack, env)
        local ofs = stack:pop()
        env.rof = (ofs + env.hsides) % env.sides - env.hsides
        env.rel = (env.rel + ofs * env.mirror) % env.sides
    end,
    ["amv"] = function(stack, env)
        local ofs = stack:pop() * env.mirror
        local old = env.rel
        env.rel = ofs % env.sides
        env.rof = (env.rel - old) * env.mirror
    end,
    [">>"] = function(stack, env)
        local b = stack:pop() * env.mirror
        stack:push((stack:pop() + b) % env.sides)
    end,
    ["<<"] = function(stack, env)
        local b = stack:pop() * env.mirror
        stack:push((stack:pop() - b) % env.sides)
    end,
    ["a"] = push_abs_pos,
    ["r"] = function(stack, env)
        stack:push((env.abs + env.rel) % env.sides)
    end,

    -- Thickness functions
    ["i"] = function(stack, env)
        stack:push(stack:pop() * env.idealth)
    end,
    ["spath"] = function(stack, env)
        stack:push(math.abs(env.rof) * env.idealth)
    end,
    ["lpath"] = function(stack, env)
        stack:push((env.sides - math.abs(env.rof)) * env.idealth)
    end,
    ["th2s"] = function(stack)
        stack:push(thicknessToSeconds(stack:pop()))
    end,
    ["s2th"] = function(stack)
        stack:push(secondsToThickness(stack:pop()))
    end,

    -- Timeline functions
    ["sleep"] = function(stack, _, _, self)
        self.timeline:wait(stack:pop())
    end,
    ["thsleep"] = function(stack, _, _, self)
        self.timeline:wait(thicknessToSeconds(stack:pop()))
    end,
    ["rsleep"] = function(stack, _, _, self)
        self.timeline:wait(SECONDS_PER_PLAYER_ROTATION * stack:pop())
    end,

    -- ! Deprecated
    ["call:"] = function(stack, env, char, self)
        local args = {}
        for i = stack:pop(), 1, -1 do
            args[i] = stack:pop()
        end
        self.timeline:call(function()
            self.link[char](unpack(args))
        end)
        env.pc = env.pc + 1
    end,

    ["T:"] = function(stack, env, data, self)
        local th = stack:pop()
        local pos = stack:pop()
        self.timeline:call(function()
            horizontal(self.link, pos, env.sides, th, env.mirror, data)
        end)
        env.pc = env.pc + 1
    end,
    -- ['h:'] = ['T:']

    ["t:"] = function(stack, env, data, self)
        local th = stack:pop()
        local pos = stack:pop()
        self.timeline:call(function()
            horizontal(self.link, pos, env.sides, th + env.tolerance, env.mirror, data)
        end)
        env.pc = env.pc + 1
    end,

    ["P:"] = function(stack, env, data, self)
        local th = stack:pop()
        local pos = stack:pop()
        self.timeline:call(function()
            horizontal(self.link, pos, env.sides, th, env.mirror, data)
        end)
        self.timeline:wait(thicknessToSeconds(th))
        env.pc = env.pc + 1
    end,

    ["p:"] = function(stack, env, data, self)
        local th = stack:pop()
        local pos = stack:pop()
        self.timeline:call(function()
            horizontal(self.link, pos, env.sides, th + env.tolerance, env.mirror, data)
        end)
        self.timeline:wait(thicknessToSeconds(th))
        env.pc = env.pc + 1
    end,

    ["#("] = begin_args,
    ["("] = begin_args,
    [")"] = function(stack, env, data, self)
        local args = stack:flush()

        local fn
        if data.from_link then
            fn = self.link[data.fn_name]
            if not fn then
                errorf(0, "Runtime", "Attempted to call an undefined function \"'%s'\".", data.fn_name)
            end
        else
            fn = self.included_functions[data.fn_name]
            if not fn then
                errorf(0, "Runtime", 'Attempted to call an undefined function "%s".', data.fn_name)
            end
        end

        if data.timeline then
            self.timeline:call(function()
                fn(unpack(args))
            end)
        else
            local ret = { fn(unpack(args)) }
            for i = 1, #ret do
                if not Filter.NUMBER(ret[i]) then
                    errorf(0, "Runtime", 'Function "%s" returned a non-numeric value.', data.fn_name)
                end
                stack:push(ret[i])
            end
        end
        env.pc = env.pc + 1
    end,
}

INSTRUCTIONS["h:"] = INSTRUCTIONS["T:"]

setmetatable(INSTRUCTIONS, { __index = BASIC_INSTRUCTIONS })

function Patternizer:include(name, fn)
    if not Filter.FUNCTION(fn) then
        errorf(2, "Include", "Argument #1 is not a function.")
    end
    if not Filter.STRING(name) then
        errorf(2, "Include", "Argument #2 is not a string.")
    end
    if INSTRUCTIONS[name] or not name:match("^[%a_][%w_]*$") then
        errorf(2, "Include", "Argument #2 is not a valid function name.")
    end
    self.included_functions[name] = fn
end

--[[
    * Compilers
]]

local function decode(dir, pattern)
    local data, init, plen = {}, 1, pattern:len()
    repeat
        local _, last, nonloop, loop, div = pattern:find("([%w%._]*)|?([%w%._]*)([%+%-]?)", init)
        table.insert(data, {
            nl = nonloop,
            l = loop:len() > 0 and loop or nil,
            d = div == "+" and math.ceil or math.floor,
        })
        init = last + 1
    until last == plen
    data.length = #data
    data.dir = dir == "~" and -1 or 1
    return data
end

function Patternizer:strwall(str, pos, th)
    local dir, pattern = str:match("^(~?)([%w%._|%+%-]-)$")
    if not dir then
        errorf(3, "WallString", "Invalid pattern.", ix, ins)
    end
    horizontal(
        self.link,
        Filter.INTEGER(pos) and pos or errorf(2, "WallString", "Argument #2 is not an integer."),
        self.sides:get(),
        Filter.NUMBER(th) and th or errorf(2, "WallString", "Argument #3 is not a number."),
        1,
        decode(dir, pattern)
    )
end
-- ! Legacy name
Patternizer.strWall = Patternizer.strwall

-- Compiles a string into a table.
function Patternizer.compile(source)
    if not Filter.STRING(source) then
        errorf(2, "Compilation", "Argument #1 is not a string.")
    end

    -- Strip comments
    source = string.gsub(source, "%-%-[^\n]*", "")

    -- Pad parentheses
    source = string.gsub(source, "#?[%(%)]", " %0 ")

    local address, new_program, scope_stack = 1, {}, Stack:new()

    local tokenizer

    local preprocessor_tokenizer = function(instruction)
        if
            instruction == "#restrict"
            or instruction == "#abs"
            or instruction == "#mirror"
            or instruction == "#tolerance"
        then
            new_program[address] = instruction
            -- Add the preprocessor statement address.
            new_program[string.sub(instruction, 2)] = address + 1
        elseif BASIC_INSTRUCTIONS[instruction] then
            new_program[address] = instruction
        else
            local number = tonumber(instruction)
            if not number then
                errorf(
                    3,
                    "Compilation",
                    'Unrecognized or illegal "%s" at instruction %d after preprocessor instruction.',
                    instruction,
                    address
                )
            end
            new_program[address] = number
        end
    end

    local tokenize_as_function = nil
    local body_tokenizer = function(instruction)
        if tokenize_as_function then
            local new_ins = {
                ins = ")",
                data = {},
            }

            -- Ensure function name is valid
            local link_fn_name = string.match(instruction, "^'([%w%._])'$")
            if link_fn_name then
                new_ins.data.fn_name = link_fn_name
                new_ins.data.from_link = true
            else
                if INSTRUCTIONS[instruction] or not instruction:match("^[%a_][%w_]*$") then
                    errorf(3, "Compilation", 'Invalid function name "%s" at instruction %d', instruction, address)
                end
                new_ins.data.fn_name = instruction
            end

            if tokenize_as_function == "#(" then
                new_ins.data.timeline = true
            else
                new_ins.data.timeline = false
            end
            new_program[address] = new_ins

            -- Clear the flag
            tokenize_as_function = nil
        elseif
            instruction == "#restrict"
            or instruction == "#abs"
            or instruction == "#mirror"
            or instruction == "#tolerance"
        then
            new_program[address] = instruction
            -- Add the preprocessor statement address.
            new_program[string.sub(instruction, 2)] = address + 1
            -- Switch tokenizers
            tokenizer = preprocessor_tokenizer
        elseif instruction == "while" or instruction == "for" or instruction == "if" then
            -- Push the instruction type and address.
            scope_stack:push({ type = instruction, address = address })
            -- Add the instruction to the program. Jump information will get filled later.
            new_program[address] = { ins = instruction }
        elseif instruction == "else" then
            -- Pop the scope stack
            local success, top = pcall(scope_stack.pop, scope_stack)
            if not (success and top.type == "if") then
                errorf(3, "Compilation", 'Unmatched "%s" at instruction %d', instruction, address)
            end

            -- Add the instruction to the program. Jump information will get filled later.
            new_program[address] = { ins = instruction }
            -- Add the jump address to the corresponding if.
            new_program[top.address].data = address + 1
            -- Push the else instruction and address.
            scope_stack:push({ type = instruction, address = address })
        elseif instruction == "end" then
            local success, top = pcall(scope_stack.pop, scope_stack)
            if not success then
                errorf(3, "Compilation", 'Unmatched "%s" at instruction %d', instruction, address)
            end

            local new_ins = { ins = instruction }
            if top.type == "while" or top.type == "for" then
                -- Whiles and fors jump back to top
                new_ins.data = top.address
            else
                -- Ifs and elses jump to next address
                new_ins.data = address + 1
            end
            new_program[address] = new_ins

            -- Add the jump address to the corresponding instruction.
            new_program[top.address].data = address + 1
        elseif instruction == "endif" then
            local success, top = pcall(scope_stack.pop, scope_stack)

            -- One closure is required
            if not (success and (top.type == "if" or top.type == "else")) then
                errorf(3, "Compilation", 'Unmatched "%s" at instruction %d', instruction, address)
            end

            -- Add instruction to program. Only need to do this once.
            new_program[address] = { ins = instruction, data = address + 1 }
            -- Add the jump address to the corresponding instruction.
            new_program[top.address].data = address + 1

            -- Repeat until all ifs and elses are closed
            success, top = pcall(scope_stack.peek, scope_stack)
            while success and (top.type == "if" or top.type == "else") do
                -- Discard the top value (we just peeked it so we have it).
                scope_stack:pop()
                -- Add the jump address to the corresponding instruction.
                new_program[top.address].data = address + 1
                success, top = pcall(scope_stack.peek, scope_stack)
            end
        elseif instruction == "(" or instruction == "#(" then
            -- Push and add instruction
            scope_stack:push({ type = instruction })
            new_program[address] = instruction
        elseif instruction == ")" then
            local success, top = pcall(scope_stack.pop, scope_stack)
            if not (success and (top.type == "(" or top.type == "#(")) then
                errorf(3, "Compilation", 'Unmatched "%s" at instruction %d', instruction, address)
            end
            -- Flag the next instruction as a function name.
            -- The instruction type is used as a flag so we know whether it's for the timeline or not.
            tokenize_as_function = top.type
            -- This doesn't add an instruction. That will happen on the next iteration.
            address = address - 1
        else
            local chars
            instruction, chars = instruction:match("^([^:]+:?)(.-)$")
            if instruction == "h:" or instruction == "t:" or instruction == "p:" then
                local dir, pattern = chars:match("^(~?)([%w%._|%+%-]-)$")
                if not dir then
                    errorf(3, "Compilation", 'Invalid pattern at instruction %d, "%s".', address, instruction)
                end
                new_program[address] = { ins = instruction, data = decode(dir, pattern) }
            elseif instruction == "call:" then
                new_program[address] = {
                    ins = instruction,
                    data = chars:match("^[%w%._]$") or errorf(
                        3,
                        "Compilation",
                        'At instruction %d, "%s" can only accept one function character.',
                        address,
                        instruction
                    ),
                }
            else
                new_program[address] = INSTRUCTIONS[instruction] and instruction
                    or tonumber(instruction)
                    or errorf(3, "Compilation", 'Unrecognized "%s" at instruction %d.', instruction, address)
            end
        end
    end

    tokenizer = body_tokenizer

    -- Iterate through tokens
    for match in string.gmatch(source, "[^%s]+%s*") do
        -- trim whitespace
        local token = string.match(match, "^%s*(.-)%s*$")
        tokenizer(token)
        address = address + 1
    end

    -- Check that the stack is empty
    if scope_stack.sp > 1 then
        local top = scope_stack:pop()
        errorf(2, "Compilation", 'Unmatched "%s" at instruction %d.', top.type, top.address)
    end

    return new_program
end

--[[
    * Interpreters
]]

local INSTRUCTION_LIMIT = 99999999

local function interpret(self, program, instruction_set, env, stack)
    for _ = 1, INSTRUCTION_LIMIT do
        local ins = program[env.pc]
        local instype = type(ins)

        if instype == "number" then
            stack:push(ins)
            env.pc = env.pc + 1
        elseif instype == "string" then
            if instruction_set[ins](stack, env, nil, self) then
                return unpack(stack.stack.list)
            end
            env.pc = env.pc + 1
        elseif instype == "table" then
            instruction_set[ins.ins](stack, env, ins.data, self)
        else
            return unpack(stack.stack.list)
        end
    end
    errorf(1, "Runtime", "Instruction limit of %d reached.", INSTRUCTION_LIMIT)
end

-- Interprets a compiled program.
function Patternizer:interpret(program, ...)
    if not Filter.TABLE(program) then
        errorf(2, "Interpret", "Argument #1 is not a table.")
    end
    local env, stack = nil, RuntimeStack:new()
    local sides = self.sides:get()
    env = {
        pc = 1,
        sides = sides,
        hsides = sides * 0.5,
        idealth = getIdealThickness(sides),
        idealdl = getIdealDelayInSeconds(sides),
        rel = 0,
        rof = 0,
    }

    if program.abs then
        local abs = interpret(nil, program, BASIC_INSTRUCTIONS, {
            pc = program.abs,
            sides = sides,
            hsides = sides * 0.5,
        }, RuntimeStack:new())

        if abs then
            env.abs = math.floor(abs % sides)
            goto abs_continue
        end
    end
    env.abs = self.randsideinit:get() and u_rndInt(0, sides - 1) or 0
    ::abs_continue::

    if program.mirror then
        local mirror = interpret(nil, program, BASIC_INSTRUCTIONS, {
            pc = program.mirror,
            sides = sides,
            hsides = sides * 0.5,
        }, RuntimeStack:new())

        if mirror then
            if mirror == -1 then
                env.mirror = -1
            else
                env.mirror = 1
            end
            goto mirror_continue
        end
    end
    env.mirror = self.mirroring:get() and getRandomDir() or 1
    ::mirror_continue::

    if program.tolerance then
        local tolerance = interpret(nil, program, BASIC_INSTRUCTIONS, {
            pc = program.tolerance,
            sides = sides,
            hsides = sides * 0.5,
        }, RuntimeStack:new())

        if tolerance then
            env.tolerance = tolerance
            goto tolerance_continue
        end
    end
    env.tolerance = self.tolerance:get()
    ::tolerance_continue::

    local args = { ... }
    for i = 1, #args do
        stack:push(args[i])
    end
    return interpret(self, program, INSTRUCTIONS, env, stack)
end

function Patternizer:restrict(program)
    if not Filter.TABLE(program) then
        errorf(2, "Interpret", "Argument #1 is not a table.")
    end
    if not program.restrict then
        return true
    end
    local sides = self.sides:get()
    return interpret(nil, program, BASIC_INSTRUCTIONS, {
        pc = program.restrict,
        sides = sides,
        hsides = sides * 0.5,
    }, RuntimeStack:new()) ~= 0
end

-- Directly interprets a string.
function Patternizer:send(str, ...)
    return self:interpret(self.compile(str), ...)
end

--[[
    * Pattern Organizers
]]

function Patternizer:allow_pattern_repeat()
    self.pattern.allow_repeat = true
end

function Patternizer:disable_pattern_repeat()
    self.pattern.allow_repeat = false
end

-- Stops or resumes pattern generation. The timeline will still run.
function Patternizer:suspend()
    self.pattern.suspended = true
end
-- ! Legacy function name
Patternizer.pause = Patternizer.suspend

function Patternizer:resume()
    self.pattern.suspended = false
end

-- Begins the pattern sequence.
-- This function is disabled while a pattern exists on the timeline.
function Patternizer:spawn()
    if self.pattern.suspended or self.pattern.disabled then
        return
    end

    local patterns, plistlen = self.pattern.list, self.pattern.total

    local exclude = nil
    if not self.pattern.allow_repeat then
        exclude = self.pattern.previous
    end

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
        self.timeline:call(function()
            self.pattern.disabled = false
        end)
        self.pattern.disabled = true
    end
end

-- Appends a single program to the program pool
function Patternizer:add_program(program)
    if not Filter.TABLE(program) then
        errorf(2, "AddProgram", "Argument #1 is not a table")
    end
    local n = self.pattern.total + 1
    self.pattern.list[n] = program
    self.pattern.total = n
end

-- Replaces the pattern pool
function Patternizer:set_program_pool(program_list)
    self.pattern.list = program_list
    self.pattern.total = #program_list
    self.pattern.previous = nil
end

-- ! Depreciated functions
--#region

-- ! Depreciated
-- Adds compiles and patterns
function Patternizer:add(...)
    local t = { ... }
    for i = 1, #t do
        t[i] = self.compile(t[i])
    end
    self:addprogram(unpack(t))
end

-- ! Depreciated
-- Accepts already compiled patterns
function Patternizer:addprogram(...)
    local t, start = { ... }, self.pattern.total
    local len = #t
    for i = 1, len do
        local program = t[i]
        self.pattern.list[start + i] = Filter.TABLE(program) and program
            or errorf(2, "AddProgram", "Argument #%d is not a table.", i)
    end
    self.pattern.total = start + len
end
-- ! Legacy name
Patternizer.addProgram = Patternizer.addprogram

-- ! Deprecated
function Patternizer:disable()
    self.spawn = __NIL
end

-- ! Deprecated
function Patternizer:enable()
    self.spawn = nil
end

-- ! Deprecated
-- Same as spawn but can be disabled by pause and resume functions.
function Patternizer:pspawn()
    self:spawn()
end

--#endregion

-- Removes all patterns
function Patternizer:clear()
    self.set_program_pool({})
end

-- Runs the patternizer timeline without spawning patterns
function Patternizer:run_timeline(mFrameTime)
    self.timeline:update(mFrameTime)
end
-- ! Deprecated
Patternizer.step = Patternizer.run_timeline

-- Runs the patternizer
function Patternizer:run(mFrameTime)
    self:spawn()
    self.timeline:update(mFrameTime)
end
