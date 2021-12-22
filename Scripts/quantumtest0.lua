THICKNESS = 40 --typical wall thickness
--speedMult is a lie! actual speed of walls is below, along with true delay
--1.25 factor is due to vee's abitrary mods (specifically a factor of 5 and 0.25)
function trueSpeedMult()
	return l_getSpeedMult()*(u_getDifficultyMult()^0.65)*1.25
end
--just set delay to 0 to prevent the below interference. these patterns dont use it anyway.
function trueDelayMult()
	return l_getDelayMult()*(u_getDifficultyMult()^0.1)
end

--finds the smallest possible speed at which you can traverse a vortex without wall collisions
--and compares to current value.
function smoothSailing(smoothLim)
	if trueSpeedMult() >= smoothLim * l_getSides() * (THICKNESS + l_getBeatPulseMax() + l_getRadiusMin() * ((l_getPulseMax()/l_getPulseMin()) - 1)) * 21/3200 then
		return true
		else return false
	end	
end

--for ease of use
--thickPulse = (THICKNESS + l_getBeatPulseMax() + l_getRadiusMin() * ((l_getPulseMax()/l_getPulseMin()) - 1))
--pulseContrib = l_getBeatPulseMax() + l_getRadiusMin() * ((l_getPulseMax()/l_getPulseMin()) - 1)

function thickPulse()
	return (THICKNESS + l_getBeatPulseMax() + l_getRadiusMin() * ((l_getPulseMax()/l_getPulseMin()) - 1))
end

function pulseContrib()
	return l_getBeatPulseMax() + l_getRadiusMin() * ((l_getPulseMax()/l_getPulseMin()) - 1)
end

function setZoom(base1,base2,base3,base4,factor)
--takes the base value and zooms out by factor.
	l_setRadiusMin(base1/factor)
	l_setPulseMax(base2/factor)
	l_setPulseMin(base3/factor)
	l_setBeatPulseMax(base4/factor)
end

function sideDistance(side1,side2)
	local sides = l_getSides()
	local offset1 = side1 - side2
	local offset2 = side2 - side1
	--don't be an idiot and put sides count not in 0 to sides-1 range.
	--this is doing a modular sides calculation.
	--if the first isn't negative, the second must be.
	--it can't be 0 because they aren't equal.
	if offset1 < 0 then
		offset1 = offset1 + sides
	else offset2 = offset2 + sides
	end
	--this looks at the two side offsets and finds the smallest.
	if offset1 >= offset2 then
		return offset2
	else return offset1
	end
end

-- cWall: creates a wall with the common THICKNESS
function cWall(mSide)
	w_wall(mSide, THICKNESS)
end

--general pattern for a single wall pattern
function roundnRound()
	local sides = l_getSides()
	local delay = 800/21
	for j = 0, 9 do
	
		for i = 0, sides - 2 do
			w_wall(i, THICKNESS)
		end	
		t_wait(delay)
	end	
end

--general pattern for a single wall pattern
function oneGapOLD()
	local sides = l_getSides() 
	local position = u_rndInt(0, sides - 1)
	local delay = 800/(21*sides)
	
	for i = 0, sides - 2 do
		cWall(position + i + 1)
	end	
	t_wait(delay)
end

--creates a wall with a single gap multiple times with delay varying on distance to next gap.
--DOESNT WORK
function oneGapN(times)
	local sides = l_getSides()
	--position1 is the first gap coming towards you, position 2 is second.
	--position2 is ensured not be be equal to position1
	local position1 = u_rndInt(0, sides - 1)
	local position2 = position1 + u_rndInt(1, sides - 1)
	local delay = 800/(21*sides)
	
	--times controls the successive walls, sides controls the number of adjacent walls.
	for i = 0, times - 1 do
		for j = 0, sides - 1 do
			cWall(position1 + i)
		end
		--wait between successive walls within a pattern
		t_wait(delay*sideDistance(position1,position2))
		position1 = position2 + u_rndInt(1, sides - 1)
	end
	t_wait(delay*math.floor(sides/2)) --wait between patterns equal to max needed
end

--IF YOU USE DELAYMULT, SET smoothLim TO 0. also, stay above 1. -> hardcore if you want lower.
function qDynamicRandomBarrage(times,smoothLim,delayMult)
	local sides = l_getSides()
	local delay = (800*delayMult)/(21*sides)
	local side1 = u_rndInt(0, sides - 1)
	local side2 = side1 + u_rndInt(1, sides - 1)
	
	if smoothSailing(smoothLim) == true then
	
		for i = 0, times - 1 do
			for j = 0, sides - 2 do
				cWall(side1 + j + 1)
			end
			t_wait(delay*sideDistance(side1,side2))
			side1 = side2
			side2 = side2 + u_rndInt(1, sides - 1)
		end
		t_wait(delay*math.floor(sides/2))
	
	end
	
end

function qStaticRandomBarrage(times,delayMult)
	local sides = l_getSides()
	local delay = (800*delayMult)/(21*sides)
	local position = u_rndInt(0,sides - 1)
	
	for i = 0, times - 1 do
		for j = 0, sides - 2 do
			cWall(position + j + 1)
		end
		position = position + u_rndInt(1,sides - 1)
		t_wait(delay * math.floor(sides/2))
	end
	t_wait(delay * math.floor(sides/2))
end

function qHardcoreDynamicRandomBarrage(times,delayMult)
--delayMult goes between 0 and 1, 0 is tight and 1 is loose
	local sides = l_getSides() 
	local delay = 0
	local side1 = 0
	local side2 = u_rndInt(0, sides - 1)
	local direction = u_rndInt(0,1)
	local sideLim = 0
	local finalSideDelay = 0
	local idealDelay = 0
	local minDelay = 0
	
	--sides are counted clockwise
	
	if sides % 2 == 0 then
		sideLim = sides/2
	else sideLim = (sides - 1)/2
	end
	
	finalSideDelay = (thickPulse()/(4*trueSpeedMult()))
	
	
	if (800/(21*sides)) - finalSideDelay > 0 then
	
		for i = 0, times - 1 do
		
			side1 = side2
			direction = direction + 1
			side2 = side2 + u_rndInt(1,sideLim) * (-1)^direction
			
			if side2 >= sides then
				side2 = side2 - sides
			elseif side2 < 0 then
				side2 = side2 + sides
			end
			
			for j = 0, sides - 2 do
				cWall(side1 + j + 1)
			end
			
			idealDelay = (800/(21*sides)) * sideDistance(side1,side2)
			minDelay = ((800/(21*sides)) * (sideDistance(side1,side2)-1))
			delay = minDelay + finalSideDelay + delayMult * (idealDelay - minDelay - finalSideDelay)
			
			t_wait(delay)
		end
		t_wait(800/(21*sides) * math.floor(sides/2))
	
	end
	
end

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
	else return -1 --anticlockwise
	end
end

function qTunnel(times,delayMult,direction)
	local sides = l_getSides()
	local delay = (800*delayMult)/(21*sides)
	local position = u_rndInt(0,sides - 1)
	local toggle = -1^(direction)
	--1 is right first, -1 is left first
	local finalSideDelay = 0
	local idealDelay = 0
	local minDelay = 0
	
	finalSideDelay = (thickPulse()/(4*trueSpeedMult()))
	
	if (800/(21*sides)) - finalSideDelay > 0 then
	--checks to see if pattern is possible
		for i = 0, times - 1 do
			--this needs to alternate around the big wall (+1. -1)
			for j = 0, sides - 2 do
				if toggle > 0 then
					if (sides - 1) ~= (j + 1) then
						cWall(position + j + 1)
					end
				elseif (sides - 1) ~= (j - 1) then
					cWall(position + j - 1)
				end
			end
			
			toggle = toggle * (-1)
			
			idealDelay = (800/(21*sides)) * (sides - 2)
			minDelay = (800/(21*sides)) * (sides - 3)
			delay = minDelay + finalSideDelay + delayMult * (idealDelay - minDelay - finalSideDelay)
			
			if i ~= times - 1 then
				--1.05 multiplier added to overlap the walls.
				w_wall(position + sides - 1, 4*trueSpeedMult()*delay*1.05)
			end
			
			t_wait(delay) --delay between walls
		end
		t_wait(800/(21*sides) * math.floor(sides/2)) --delay between patterns
	end
end

function winding(low,high)
	local sides = l_getSides()
	--STAY ABOVE WINDING OF 1
	return u_rndInt(math.floor(low*sides),math.floor(high*sides))
	--this function allows you to set a winding amount rather than nuber of walls for qSpiral.
end

function qSpiral(times,delayMult,direction,width,gap,seamless,spacing)
	local sides = l_getSides() 
	local remaining = times
	local position = u_rndInt(0,sides - 1)
	local position2 = 0
	local pulseDelay = pulseContrib()/(4*trueSpeedMult())
	local unit = width + gap
	local multiplicity = math.floor(times/unit)
	local minDelay = (800/(21*sides)) * (times - gap - 1)/(times - 2)* 1.01 + pulseDelay
	local idealDelay = 800/(21*sides)
	local delay = minDelay + delayMult * (idealDelay - minDelay)
	local thick = 4*trueSpeedMult()*delay
	
	for k = 0, times - 1 do
		
		for j = 0, multiplicity - 1 do
			for i = 0, width - 1 do
			
				if seamless then
					minDelay = (800/(21*sides)) * (times - gap - 1)/(times - 2)* 1.01 * 1.1 + pulseDelay
					thick = 4*trueSpeedMult()*delay * 1.1
				end
				
				w_wall(position + 1 + (i + j*unit + k)*(-1)^(direction), thick)
			end
		end
		t_wait(delay)
	end
	
	t_wait(800/(21*sides) * math.floor(sides/2) * spacing)
end


--universal smooth barrage spiral pattern
function qSmoothBarrageSpiral(times,dirLow,dirHigh,step,direction,smoothLim,spacing,gap)
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
	local position = u_rndInt(0, sides - 1)
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
	t_wait(delay*step)
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

