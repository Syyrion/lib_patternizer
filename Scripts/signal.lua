local extmath = {}

---sign function
---@param x number
---@return integer
function extmath.sgn(x)
    return x > 0 and 1 or x == 0 and 0 or -1
end

---clamp function
---@param t number
---@param a number
---@param b number
---@return number
function extmath.clamp(t, a, b)
    if t < a then
        return a
    end
    if t > b then
        return b
    end
    return t
end

---Linear interpolation between `a` and `b` with parameter `t`
---@param a number
---@param b number
---@param t number
---@return number
function extmath.lerp(a, b, t)
    return (1 - t) * a + t * b
end

local weak_values = { __mode = "v" }
local weak_keys = { __mode = "k" }

local updateable = setmetatable({}, weak_values)
local persistent = {}

local get_value = function(this)
    return this.value
end

local signal = {}

---@class Signal
signal.Signal = {}

---Turns on persistence, preventing the signal from being garbage collected.
function signal.Signal:persist()
    persistent[self] = true
end

---Turns off persistence, allowing the signal to be garbage collected.
function signal.Signal:no_persist()
    persistent[self] = nil
end

---@alias signalparam number|function|table|Signal

--#region Waveform

---@class Waveform:Signal
---@field private freq Signal
---@field private curve function
---@field private t number
---@field private value number
---@field private suspended boolean
signal.Waveform = setmetatable({}, signal.Signal)

---Updates the signal
---@param dt number
function signal.Waveform:update(dt)
    if self.suspended then
        return
    end
    self.t = self.t + self.freq() * dt
    if self.t >= 1 then
        self.t = self.t - 1
    end
    self.value = self.curve(self.t)
end

---Suspends updates
function signal.Waveform:suspend()
    self.suspended = true
end

---Resumes updates
function signal.Waveform:resume()
    self.suspended = false
end

--#endregion

--#region Queue

-- Event type enum
local KEYFRAME_EVENT, WAVEFORM_EVENT, WAIT_EVENT, SET_VALUE_EVENT, CALL_EVENT, RELATIVE_KEYFRAME_EVENT =
    1, 2, 3, 4, 5, 6

---@class Event
---@field type `KEYFRAME_EVENT`|`WAVEFORM_EVENT`|`WAIT_EVENT`|`SET_VALUE_EVENT`|`CALL_EVENT`|`RELATIVE_KEYFRAME_EVENT`
---@field next Event?
---@field value number?
---@field fn function?
---@field freq number?

---@class Queue:Signal
---@field private current_event Event
---@field private last_event Event
---@field private value number
---@field private processing `KEYFRAME_EVENT`|`WAVEFORM_EVENT`|`WAIT_EVENT`|`RELATIVE_KEYFRAME_EVENT`|nil
---@field private start_value number
signal.Queue = setmetatable({}, signal.Signal)

---Adds a keyframe event.
---@param duration number Event duration
---@param value number Absolute target value
---@param easing? function Easing function
function signal.Queue:keyframe(duration, value, easing)
    ---@type Event
    local newevent = {
        type = KEYFRAME_EVENT,
        value = value,
        fn = easing or function(t)
            return t
        end,
        freq = 1 / duration,
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

--- TODO: Adds a keyframe event which works relative to the current value.
---@param duration number Event duration
---@param value number Relative target value
---@param easing? function Easing function
function signal.Queue:relative_keyframe(duration, value, easing)
    ---@type Event
    local newevent = {
        type = KEYFRAME_EVENT,
        value = value,
        fn = easing or function(t)
            return t
        end,
        freq = 1 / duration,
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

---Adds a waveform event. The value will be set to what `curve` returns for the duration of the event.
---@param duration number Event duration
---@param curve function A function that accepts one argument ranging from [0, 1] and returns a number.
function signal.Queue:waveform(duration, curve)
    ---@type Event
    local newevent = {
        type = WAVEFORM_EVENT,
        fn = curve,
        freq = 1 / duration,
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

---Adds a wait event.
-- ! freq is now duration !
---@param duration number
function signal.Queue:wait(duration)
    ---@type Event
    local newevent = {
        type = WAIT_EVENT,
        freq = duration,
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

---Adds an event that instantly sets the value of the signal to `value`
---@param value number
function signal.Queue:set_value(value)
    ---@type Event
    local newevent = {
        type = SET_VALUE_EVENT,
        value = value,
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

---Adds a function call event.
---A call event is instant. If a call event adds itself to the event queue with no delay, this will cause an infinite loop.
---@param fn function
function signal.Queue:call(fn)
    ---@type Event
    local newevent = {
        type = CALL_EVENT,
        fn = fn,
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

---Sets the value of the queue. If events that update the value are being processed,
---this value will get overwritten on the next update.
---@param value number
function signal.Queue:set_immediate_value(value)
    self.value = value
end

---Stops the queue and deletes all events. The value remains at its last value.
function signal.Queue:stop()
    self.current_event = self.last_event
    self.processing = nil
    self.t = 1
end

---Evaluates all remaining events. DO NOT run this if call events in the queue iterate on themselves! This will cause an infinite loop.
function signal.Queue:fast_forward()
    while self.current_event.next do
        if self.current_event.next.type == KEYFRAME_EVENT or self.current_event.next.type == SET_VALUE_EVENT then
            self.value = self.current_event.next.value
        elseif self.current_event.next.type == WAVEFORM_EVENT then
            self.value = self.current_event.next.fn(1)
        elseif self.current_event.next.type == CALL_EVENT then
            self.current_event.next.fn()
        end
        self.current_event = self.current_event.next
    end
    self.processing = nil
    self.t = 1
end

-- ! freq is now duration !
---Updates the signal.
---@param ft number
function signal.Queue:update(ft)
    if self.suspended then
        return
    end

    if self.processing then
        self.t = self.t - ft / FRAMES_PER_SECOND
        if self.t > 0 then
            -- Processing in progress
            if self.processing == KEYFRAME_EVENT then
                self.value =
                    extmath.lerp(self.start_value, self.current_event.next.value, self.current_event.next.fn(self.t))
            elseif self.processing == WAVEFORM_EVENT then
                self.value = self.current_event.next.fn(self.t)
            end
            return
        end

        -- Processing has concluded
        if self.processing == KEYFRAME_EVENT then
            self.value = self.current_event.next.value
        elseif self.processing == WAVEFORM_EVENT then
            self.value = self.current_event.next.fn(1)
        end

        self.current_event = self.current_event.next
    end

    -- Check for next event
    if not self.current_event.next then
        self.t, self.processing = 0, nil
        return
    end

    -- Process instantaneous events
    while self.current_event.next.type == CALL_EVENT or self.current_event.next.type == SET_VALUE_EVENT do
        if self.current_event.next.type == CALL_EVENT then
            self.current_event.next.fn()
        else
            self.value = self.current_event.next.value
        end
        self.current_event = self.current_event.next

        -- Exit if there were only instantaneous events to process
        if not self.current_event.next then
            self.t, self.processing = 0, nil
            return
        end
    end

    self.t = self.t + self.current_event.next.freq

    self.processing = self.current_event.next.type
    if self.processing == KEYFRAME_EVENT then
        self.start_value = self.value
        self.value = extmath.lerp(self.start_value, self.current_event.next.value, self.current_event.next.fn(self.t))
    elseif self.processing == WAVEFORM_EVENT then
        self.value = self.current_event.next.fn(self.t)
    end
end

---Suspends updates
function signal.Queue:suspend()
    self.suspended = true
end

---Resumes updates
function signal.Queue:resume()
    self.suspended = false
end

--#endregion

--#region Operations

---@class Lerp:Signal
---@field private a Signal
---@field private b Signal
---@field private t Signal
---@field private value number
signal.Lerp = setmetatable({}, signal.Signal)

function signal.Lerp:update()
    self.value = extmath.lerp(self.a(), self.b(), self.t())
end

---@class Add:Signal
---@field private a Signal
---@field private b Signal
---@field private value number
signal.Add = setmetatable({}, signal.Signal)

function signal.Add:update()
    self.value = self.a() + self.b()
end

---@class Sub:Signal
---@field private a Signal
---@field private b Signal
---@field private value number
signal.Sub = setmetatable({}, signal.Signal)

function signal.Sub:update()
    self.value = self.a() - self.b()
end

---@class Mul:Signal
---@field private a Signal
---@field private b Signal
---@field private value number
signal.Mul = setmetatable({}, signal.Signal)

function signal.Mul:update()
    self.value = self.a() * self.b()
end

---@class Div:Signal
---@field private a Signal
---@field private b Signal
---@field private value number
signal.Div = setmetatable({}, signal.Signal)

function signal.Div:update()
    self.value = self.a() / self.b()
end

--#endregion

-- Square wave function with period 1 and amplitude 1 at value `x` with duty cycle `d`.
local square = function(x, d)
    local _, frac = math.modf(x)
    if x < 0 then
        frac = 1 + frac
    end
    return -extmath.sgn(frac - extmath.clamp(d, 0, 1))
end

-- Asymmetrical triangle wave function with period 1 and amplitude 1 at value `x`.
-- Asymmetry can be adjusted with `d`.
-- An asymmetry of 1 is equivalent to sawtooth wave.
-- An asymmetry of 0 is equivalent to a reversed sawtooth wave.
local triangle = function(x, d)
    x = x % 1
    d = extmath.clamp(d, 0, 1)
    local p, x2 = 1 - d, 2 * x
    if x < 0.5 * d then
        return x2 / d
    elseif 0.5 * (1 + p) <= x then
        return (x2 - 2) / d
    else
        return (1 - x2) / p
    end
end

-- Sawtooth wave function with period 1 and amplitude 1 at value x.
local sawtooth = function(x)
    return 2 * (x - math.floor(0.5 + x))
end

local M = {}

local const_signal_cache = setmetatable({}, weak_values)

---Create a new signal.
---If value is a `number`, returns the constant signal of that number.
---If value is already a signal, returns that signal.
---@param value signalparam
---@return Signal|function
function M.new_signal(value)
    if type(value) == "number" then
        if const_signal_cache[value] then
            return const_signal_cache[value]
        end
        local newinst = function()
            return value
        end
        const_signal_cache[value] = newinst
        return newinst
    end
    return value
end

---Creates a new looping signal with frequency `freq` defined by the function `curve`.
---@param freq signalparam Waveform frequency
---@param curve function A function that accepts one argument ranging from [0, 1] and returns a number.
---@return Waveform
function M.new_waveform(freq, curve)
    local newinst = setmetatable({
        t = 0,
        freq = M.new_signal(freq),
        curve = curve,
        suspended = false,
        value = 0,
    }, signal.Waveform)
    table.insert(updateable, newinst)
    return newinst
end

---Creates a new queue signal
---@param value number? Starting value
---@return Queue
function M.new_queue(value)
    local dummy_event = {}
    local newinst = setmetatable({
        t = 0,
        current_event = dummy_event,
        last_event = dummy_event,
        suspended = false,
        value = value or 0,
    }, signal.Queue)
    table.insert(updateable, newinst)
    -- persist by default
    newinst:persist()
    return newinst
end

---Creates a new signal that is the lerp of 3 signals `a`, `b`, and `t`.
---@param a signalparam
---@param b signalparam
---@param t signalparam
---@return Lerp
function M.lerp(a, b, t)
    local newinst = setmetatable({
        a = M.new_signal(a),
        b = M.new_signal(b),
        t = M.new_signal(t),
        value = 0,
    }, signal.Lerp)
    table.insert(updateable, newinst)
    return newinst
end

---Creates a new signal that is the sum of two signals `a` and `b`.
---@param a signalparam
---@param b signalparam
---@return Add
function M.add(a, b)
    local newinst = setmetatable({
        a = M.new_signal(a),
        b = M.new_signal(b),
        value = 0,
    }, signal.Add)
    table.insert(updateable, newinst)
    return newinst
end

---Creates a new signal that is the difference of two signals `a` and `b`.
---@param a signalparam
---@param b signalparam
---@return Sub
function M.sub(a, b)
    local newinst = setmetatable({
        a = M.new_signal(a),
        b = M.new_signal(b),
        value = 0,
    }, signal.Sub)
    table.insert(updateable, newinst)
    return newinst
end

---Creates a new signal that is the product of two signals `a` and `b`.
---@param a signalparam
---@param b signalparam
---@return Mul
function M.mul(a, b)
    local newinst = setmetatable({
        a = M.new_signal(a),
        b = M.new_signal(b),
        value = 0,
    }, signal.Mul)
    table.insert(updateable, newinst)
    return newinst
end

---Creates a new signal that is the quotient of two signals `a` and `b`.
---@param a signalparam
---@param b signalparam
---@return Div
function M.div(a, b)
    local newinst = setmetatable({
        a = M.new_signal(a),
        b = M.new_signal(b),
        value = 0,
    }, signal.Div)
    table.insert(updateable, newinst)
    return newinst
end

---Updates all signals
---@param dt number
function M.update(dt)
    for _, sig in ipairs(updateable) do
        sig:update(dt)
    end
end

for _, class in pairs(signal) do
    class.__index = class
    class.__call = get_value
    class.__add = M.add
    class.__sub = M.sub
    class.__mul = M.mul
    class.__div = M.div
end

Signal = M
