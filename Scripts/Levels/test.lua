-- include useful files
u_execDependencyScript("ohvrvanilla", "base", "vittorio romeo", "utils.lua")
u_execDependencyScript("ohvrvanilla", "base", "vittorio romeo", "common.lua")
u_execDependencyScript("ohvrvanilla", "base", "vittorio romeo", "commonpatterns.lua")
u_execScript("quantumtest1.lua")

-- this function adds a pattern to the timeline based on a key

--qSpiral(times, delayMult, position, direction, width, gap, step, spacing)

function addPattern(mKey)
    if mKey == 0 then qSpiral(10,1,0,0,1,7,{1},4)
	--if mKey == 0 then qConnectingSpiral(10,1,0,0,2,2,4)
    --elseif mKey == 1 then pInverseBarrage(0)	
    end
end

-- shuffle the keys, and then call them to add all the patterns
-- shuffling is better than randomizing - it guarantees all the patterns will be called
keys = { 0 }
shuffle(keys)
index = 0

-- onInit is an hardcoded function that is called when the level is first loaded
function onInit()
    l_setSpeedMult(2.5)
    l_setSpeedInc(0)
    l_setRotationSpeed(0.04)
    l_setRotationSpeedMax(0.4)
    l_setRotationSpeedInc(0)
    l_setDelayMult(1)
    l_setDelayInc(0.0)
    l_setFastSpin(0.0)
    l_setSides(8)
    l_setSidesMin(8)
    l_setSidesMax(8)
    l_setIncTime(15)
	
	l_setRadiusMin(72)
	l_setPulseMin(72)
	l_setPulseMax(72)
	
	l_setBeatPulseMax(0)

    --l_setBeatPulseMax(14)
    --l_setBeatPulseDelayMax(21.95) -- BPM is 164, 3600/164 is 21.95
    --l_setBeatPulseSpeedMult(0.45) -- Slows down the center going back to normal
end

-- onLoad is an hardcoded function that is called when the level is started/restarted
function onLoad()

end

-- onStep is an hardcoded function that is called when the level timeline is empty
-- onStep should contain your pattern spawning logic
function onStep()

	addPattern(keys[index])
	index = index + 1


	if index - 1 == #keys then
		index = 1
		shuffle(keys)
	end
	

end

-- onIncrement is an hardcoded function that is called when the level difficulty is incremented
function onIncrement()
end

-- onUnload is an hardcoded function that is called when the level is closed/restarted
function onUnload()
end

-- onInput is a hardcoded function invoked when the player executes input
function onInput(mFrameTime, mMovement, mFocus, mSwap)
end

-- onUpdate is an hardcoded function that is called every frame
function onUpdate(mFrameTime)
end

-- onPreDeath is an hardcoded function that is called when the player is killed, even
-- in tutorial mode
function onPreDeath()
end
