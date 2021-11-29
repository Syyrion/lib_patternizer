-- * Run this dependency script since some constants and functions are duplicated here
u_execDependencyScript("ohvrvanilla", "base", "vittorio romeo", "common.lua")

-- * Unnecessary. Provided in the common.lua script
-- THICKNESS = 40 --typical wall thickness

-- * These values are used quite often so I've put them into a single function and variable
-- Number of frame to make one full revolution
DELAYCONSTANT = 800 / 21
-- * delayMult defaults to 1 so passing nothing won't break anything
function getDelayAndSides(delayMult)
	delayMult = delayMult or 1
	local sides = l_getSides()
	return DELAYCONSTANT / sides * delayMult, sides
end


-- * Put spaces after the double hyphen for comments
-- speedMult is a lie! actual speed of walls is below, along with true delay
-- 1.25 factor is due to vee's abitrary mods (specifically a factor of 5 and 0.25)
-- * Spaces before and after operators
-- * Removed unnecesary parentheses
function trueSpeedMult()
	return l_getSpeedMult() * u_getDifficultyMult() ^ 0.65 * 1.25
end
-- just set delay to 0 to prevent the below interference. these patterns dont use it anyway.
-- * Spaces before and after operators
-- * Removed unnecesary parentheses
function trueDelayMult()
	return l_getDelayMult() * u_getDifficultyMult() ^ 0.1
end

cWallEx = function (mSide, mExtra)
	local exLoopDir = 1
	if mExtra < 0 then exLoopDir = -1 end
	for i = 0, mExtra, exLoopDir do cWall(mSide + i) end
end


-- for ease of use
-- thickPulse = THICKNESS + l_getBeatPulseMax() + l_getRadiusMin() * (l_getPulseMax() / l_getPulseMin() - 1)
-- pulseContrib = l_getBeatPulseMax() + l_getRadiusMin() * (l_getPulseMax() / l_getPulseMin() - 1)
function pulseContrib()
	return l_getBeatPulseMax() + l_getRadiusMin() * (l_getPulseMax() / l_getPulseMin() - 1)
end

-- * Removed unnecesary parentheses
function thickPulse()
	return THICKNESS + pulseContrib()
end

-- finds the smallest possible speed at which you can traverse a vortex without wall collisions
-- and compares to current value.
-- * The >= operator will return a boolean so the if statement is unnecesary
function smoothSailing(smoothLim)
	return trueSpeedMult() >= smoothLim * l_getSides() * thickPulse() * 21 / 3200
end

--takes the base value and zooms out by factor.
function setZoom(factor, base1, base2, base3, base4)
	l_setRadiusMin((base1 or l_getRadiusMin()) / factor)
	l_setPulseMax((base2 or l_getPulseMax()) / factor)
	l_setPulseMin((base3 or l_getPulseMin()) / factor)
	l_setBeatPulseMax((base4 or l_getBeatPulseMax()) / factor)
end

-- * Reimplementation
function sideDistance(side1, side2)
	-- * removed unnecesary variable after reimplementation
	local offset = side1 - side2
	-- don't be an idiot and put sides count not in 0 to sides-1 range.
	-- this is doing a modular sides calculation.
	-- if the first isn't negative, the second must be.
	-- it can't be 0 because they aren't equal.
	-- * This should be equivalent to those if statements
	-- * math.min() return the smallest value in a list of values
	return offset < 0 and math.min(offset + l_getSides(), -offset) or math.min(offset, l_getSides() - offset)
end

-- * Unnecessary. Provided in the common.lua script
-- cWall: creates a wall with the common THICKNESS
-- function cWall(mSide)
-- 	w_wall(mSide, THICKNESS)
-- end

-- general pattern for a single wall pattern
-- * Formatting. Use an _ for a variable that isn't used. (You sometimes have to be careful if there are multiple _ variables)
function roundnRound()
	local sides = l_getSides()
	for _ = 0, 9 do
		-- * Equivalent function from common.lua
		cBarrage(0)
		-- * Use constant
		t_wait(DELAYCONSTANT)
	end
end

-- general pattern for a single wall pattern
function oneGapOLD()
	local delay, sides = getDelayAndSides()
	local position = getRandomSide()
	-- * Equivalent function from common.lua
	cBarrage(position)
	t_wait(delay)
end

--creates a wall with a single gap multiple times with delay varying on distance to next gap.
--DOESNT WORK
-- * Formatting. Use an _ for a variable that isn't used. (You sometimes have to be careful if there are multiple _ variables)
function oneGapN(times)
	-- * Use new function
	local delay, sides = getDelayAndSides()
	--position1 is the first gap coming towards you, position 2 is second.
	--position2 is ensured not be be equal to position1
	local position1 = getRandomSide()
	local position2 = position1 + u_rndInt(1, sides - 1)
	--times controls the successive walls, sides controls the number of adjacent walls.
	for i = 0, times - 1 do
		cWall(position1 + i)
		--wait between successive walls within a pattern
		t_wait(delay * sideDistance(position1, position2))
		position1 = position2 + u_rndInt(1, sides - 1)
	end
	t_wait(delay * math.floor(sides / 2)) --wait between patterns equal to max needed
end

--IF YOU USE DELAYMULT, SET smoothLim TO 0. also, stay above 1. -> hardcore if you want lower.
-- * Formatting. Use an _ for a variable that isn't used. (You sometimes have to be careful if there are multiple _ variables)
function qDynamicRandomBarrage(times, smoothLim, delayMult)
	-- * You don't need to check whether the statement is equal to true. Just pass the return value directly
	if not smoothSailing(smoothLim) then return end
	local delay, sides = getDelayAndSides(delayMult)
	local side1 = getRandomSide()
	local side2 = side1 + u_rndInt(1, sides - 1)
	for _ = 0, times - 1 do
		cBarrage(side1)
		t_wait(delay * sideDistance(side1, side2))
		side1 = side2
		side2 = side2 + u_rndInt(1, sides - 1)
	end
	t_wait(delay * math.floor(sides / 2))
end

-- * Formatting. Use an _ for a variable that isn't used. (You sometimes have to be careful if there are multiple _ variables)
function qStaticRandomBarrage(times, delayMult)
	local delay, sides = getDelayAndSides(delayMult)
	local position = getRandomSide()
	for _ = 0, times - 1 do
		cBarrage(position)
		position = position + u_rndInt(1, sides - 1)
		t_wait(delay * math.floor(sides / 2))
	end
	t_wait(delay * math.floor(sides / 2))
end

function qHardcoreDynamicRandomBarrage(times,delayMult)
--delayMult goes between 0 and 1, 0 is tight and 1 is loose
	local DEL, sides = getDelayAndSides()
	local finalSideDelay = thickPulse() / 4 / trueSpeedMult()
	if DEL - finalSideDelay <= 0 then return end
	
	-- * Variable assigned immedietly
	local sideLim = sides % 2 == 0 and sides / 2 or (sides - 1) / 2
	local delay = 0
	local side1 = 0
	local side2 = getRandomSide()
	-- * From common.lua. Returns 1 or -1
	local direction = getRandomDir()
	-- * Variable assigned immedietly
	local idealDelay = 0
	local minDelay = 0

	--sides are counted clockwise
	-- * If statement removed. Value of sideLim is immedietly assigned with ternary operator

	for _ = 0, times - 1 do
		side1 = side2
		direction = direction * -1
		side2 = side2 + u_rndInt(1, sideLim) * direction
		--side2 = side2 >= sides and side2 - sides or (side2 < 0 and side2 + sides or side2)
		side2 = side2 % sides

		cBarrage(side1)

		idealDelay = DEL * sideDistance(side1,side2)
		minDelay = DEL * (sideDistance(side1,side2) - 1)
		delay = minDelay + finalSideDelay + delayMult * (idealDelay - minDelay - finalSideDelay)

		t_wait(delay)
	end
	t_wait(DEL * math.floor(sides/2))
end

-- ! Depreciated
function gapDir(side1,side2)
	local interval = side1

	while not interval == side2 do
		interval = interval + 1
	end

	interval = interval - side1

	if interval == l_getSides()/2 then
		return 0 --opposite
	elseif interval == sideDistance(side1,side2) then
		return 1 --clockwise
	else
		return -1 --anticlockwise
	end
end

function qTunnel(times, delayMult, direction)
	local DEL, sides = getDelayAndSides()
	local trueMult = trueSpeedMult()
	local finalSideDelay = thickPulse() / (4 * trueMult)
	if DEL - finalSideDelay <= 0 then return end
	local delay = DEL * delayMult
	local position = getRandomSide()
	local toggle = -1 ^ direction
	--1 is right first, -1 is left first
	local idealDelay = 0
	local minDelay = 0

	--checks to see if pattern is possible
	for i = 0, times - 1 do
		if i ~= times - 1 then
			--1.05 multiplier added to overlap the walls.
			w_wall(position + sides - 1, 4 * trueMult * delay * 1.05)
		end

		cWallEx(position + toggle, (sides - 3) * toggle)

		toggle = toggle * -1

		idealDelay = DEL * (sides - 2)
		minDelay = DEL * (sides - 3)
		delay = minDelay + finalSideDelay + delayMult * (idealDelay - minDelay - finalSideDelay)
		t_wait(delay) --delay between walls
	end
	t_wait(DEL * math.floor(sides / 2)) --delay between patterns
end

function winding(low, high)
	local sides = l_getSides()
	--STAY ABOVE WINDING OF 1
	return u_rndInt(math.floor(low * sides), math.floor(high * sides))
	--this function allows you to set a winding amount rather than number of walls for qSpiral.
end

function qSpiral(times, delayMult, direction, width, gap, seamless, spacing, connect)
	local DEL, sides = getDelayAndSides()
	local position = getRandomSide()
	local pulseDelay = pulseContrib() / (4 * trueSpeedMult())
	local unit = width + gap
	local multiplicity = math.floor(times / unit)
	local minDelay = DEL * (times - gap - 1) / (times - (connect and 1 or 2)) * 1.01 * (seamless and 1.1 or 1) + pulseDelay
	local idealDelay = DEL
	local delay = minDelay + delayMult * (idealDelay - minDelay)
	local thick = 4 * trueSpeedMult() * delay * (seamless and 1.1 or 1)

	for k = 0, times - 1 do
		for j = 0, multiplicity - 1 do
			for i = 0, width - 1 do
				if connect then
					if direction == 0 then
						if k ~= times - 1 then
							t_eval([[l_setWallSkewLeft(0)]])
							t_eval(string.format([[l_setWallSkewRight(%d)]],-thick))
							--spawn up wall 
							w_wall(position + 1 + (i + j * unit + k) * (-1) ^ (direction), thick)
						end
						
						if k ~= 0 then
							t_eval(string.format([[l_setWallSkewLeft(%d)]],-thick))
							t_eval(string.format([[l_setWallSkewRight(%d)]],-2*thick))
							--spawn down wall
							w_wall(position + 1 + (i + j * unit + k) * (-1) ^ (direction), thick)
						end
					else
						if k ~= times - 1 then
							t_eval([[l_setWallSkewRight(0)]])
							t_eval(string.format([[l_setWallSkewLeft(%d)]],-thick))
							--spawn up wall
							w_wall(position + 1 + (i + j * unit + k) * (-1) ^ (direction), thick)
						end
						
						if k ~= 0 then
							t_eval(string.format([[l_setWallSkewRight(%d)]],-thick))
							t_eval(string.format([[l_setWallSkewLeft(%d)]],-2*thick))
							--spawn down wall
							w_wall(position + 1 + (i + j * unit + k) * (-1) ^ (direction), thick)
						end
						
					end
					t_eval([[l_setWallSkewLeft(0)]])
					t_eval([[l_setWallSkewRight(0)]])
					
				else w_wall(position + 1 + (i + j * unit + k) * (-1) ^ (direction), thick)
				end
			end
		end
		t_wait(delay)
	end
	t_wait(DEL * math.floor(sides/2) * spacing)
end

--[[
if connect then
					if direction == 0 then
						l_setWallSkewRight(thick)
						--spawn up wall 
						w_wall(position + 1 + (i + j * unit + k) * (-1) ^ (direction), thick)
						
						if k~= 0 then
							l_setWallSkewRight(2*thick)
							l_setWallSkewLeft(thick)
							--spawn down wall
							w_wall(position + 1 + (i + j * unit + k) * (-1) ^ (direction), thick)
						end
						
					else
						l_setWallSkewLeft(thick)
						--spawn up wall 
						w_wall(position + 1 + (i + j * unit + k) * (-1) ^ (direction), thick)
						
						if k~= 0 then
							l_setWallSkewLeft(2*thick)
							l_setWallSkewRight(thick)
							--spawn down wall
							w_wall(position + 1 + (i + j * unit + k) * (-1) ^ (direction), thick)
						end
						
					end
					l_setWallSkewLeft(0)
					l_setWallSkewRight(0)
					
				else w_wall(position + 1 + (i + j * unit + k) * (-1) ^ (direction), thick)
				
				--]]


--universal smooth barrage spiral pattern
function qSmoothBarrageSpiral(times, dirLow, dirHigh, step, direction, smoothLim, spacing, gap)
--times is total number of successive walls
--dirChange is how many successive walls have the same direction. dirLow/High are bounds
--position is initial gap position(removed currently)
--step is how distant the next gap is
--direction is whether left or right; odd is anticlockwise, even is clockwise
--smoothLim is a maxiumum on how tight the vortexes are. 1 is minimum for being possible smoothly.
	local sides = l_getSides()
	local delay = 800/(21*sides)
	local remaining = times
	local dirChange = u_rndInt(dirLow,dirHigh)
	local position = getRandomSide()
--if a barrage spiral is possible with level stats * smoothLim then will spawn
--will make dirChange number of walls that shift position according to steps and direction.
--then it will change direction and repeat this until the wall total is used up.
	if smoothSailing(smoothLim) == true then
		if step > math.floor(sides/2) then
			step = sides - step
			direction = direction + 1
		end

		while remaining >= dirChange do

			for i = 0, dirChange - 1 do
				position = position + step * ((-1) ^ direction)
				oneGap(sides,step,position,delay,gap)
			end

			direction = direction + 1
			dirChange = u_rndInt(dirLow,dirHigh)
			remaining = remaining - dirChange
		end

		for i = 0, remaining - 1 do
			position = position + step * ((-1) ^ direction)
			oneGap(sides,step,position,delay,gap)			
		end

		t_wait(spacing*delay*(math.floor(sides/2)))
		--there was a -step after the math floor. reason for that?
	end

end

--subpattern to make vortex pattern code less bulky
function oneGap(sides,step,position,delay,gap)
	for i = 0, sides - 2 - (gap - 1) do
		cWall((position + i + 1) % sides)
	end
	t_wait(delay * step)
end


--example of using arrays
--chooseSide = useSide[u_rndIntUpper(#useSide)]
--l_setSides(chooseSide)


--[[
what do we need?

-arrays are x={},
-position is [],
-#x is length of array, index 1+
-concatenate things with ..


1. value for number of arrays generated (one for each layer)
2. 

--]]

