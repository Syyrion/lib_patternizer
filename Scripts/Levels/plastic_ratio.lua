-- include useful files
u_execDependencyScript("ohvrvanilla", "base", "vittorio romeo", "utils.lua")
u_execDependencyScript("ohvrvanilla", "base", "vittorio romeo", "common.lua")
u_execDependencyScript("ohvrvanilla", "base", "vittorio romeo", "commonpatterns.lua")
u_execScript("quantumtest.lua")

DIFFICULTY = simplifyFloat(u_getDifficultyMult(), 2)

-- shuffle the keys, and then call them to add all the patterns
-- shuffling is better than randomizing - it guarantees all the patterns will be called
index = 0

function sideCounts()
	l_setSides(useSide[u_rndIntUpper(#useSide)])
end


-- onInit is an hardcoded function that is called when the level is first loaded
function onInit()
	if DIFFICULTY == 0.98 then
		keys = {0, 1, 2, 3}
		shuffle(keys)
		useSide = {5, 6}

		l_setSpeedMult(1.5)
		l_setSpeedInc(0.05)

		l_setRotationSpeed(0.1)
		l_setRotationSpeedMax(0.6)
		l_setRotationSpeedInc(0.05)

		function addPattern(mKey)
			local sides, dir = l_getSides(), u_rndInt(0, 1)
				if mKey == 0 then qSpiral(winding(1.5, 2.5), 1, dir, 1, sides-1, true, 4) --single spiral
			elseif mKey == 1 and sides % 2 == 0 then qSpiral(u_rndInt(6, 12), 10, dir, 1, (sides/2) -1, true, 4) --double spiral
			elseif mKey == 2 then qSpiral(winding(1.5, 2.5), 1, dir, sides-3, 3, true, 4) --2/3-single spiral
			elseif mKey == 3 then qSmoothBarrageSpiral(u_rndInt(5, 8), 10, 10, 2, dir, 1, 3, 2) --barrage-1
			end
		end
	elseif DIFFICULTY == 0.99 then
		shuffle(keys)
		
		keys = {0, 1, 2, 3, 4}
		shuffle(keys)
		useSide = {3, 4, 5, 6}

		l_setSpeedMult(1.75)
		l_setSpeedInc(0.05)

		l_setRotationSpeed(0.25)
		l_setRotationSpeedMax(0.75)
		l_setRotationSpeedInc(0.05)

		function addPattern(mKey)
			local sides, dir = l_getSides(), u_rndInt(0, 1)
				if mKey == 0 and sides == 6 then qSpiral(6, 1, dir, 2, 1, false, 3) -- 2, 1-spiral
			elseif mKey == 1 and sides >= 5 then qSpiral(winding(1.5, 2.5), 1, dir, sides-2, 2, true, 3) --4-single spiral
			elseif mKey == 2 then qSmoothBarrageSpiral(u_rndInt(5, 8), 10, 10, 1, dir, 1, 3, 1) --barrage-1
			elseif mKey == 3 and sides == 4 then qSmoothBarrageSpiral(u_rndInt(3, 5), 10, 10, 2, dir, 1, 3, 1) --barrage-1
			elseif mKey == 4 and sides <= 4 then qSpiral(winding(1.5, 2.5), 1, dir, 1, sides-1, true, 3) --single spiral
			end
		end
	elseif DIFFICULTY == 1 then
		keys = {0, 1, 2, 3, 4, 5, 6, 7}
		shuffle(keys)
		useSide = {4, 6, 8}

		l_setSpeedMult(2)
		l_setSpeedInc(0.05)

		l_setRotationSpeed(0.4)
		l_setRotationSpeedMax(0.9)
		l_setRotationSpeedInc(0.05)

		function addPattern(mKey)
			local sides, dir = l_getSides(), u_rndInt(0, 1)
				if mKey == 0 and sides ~= 4 then qSpiral(winding(1.5, 2.5), 0.25, dir, 1, (sides/2) -1, false, 2) --double spiral
			elseif mKey == 1 and sides ~= 4 then qSpiral(sides, 1, dir, 1, 1, false, 2) --1-spiral
			elseif mKey == 2 and sides ~= 8 then qSmoothBarrageSpiral(u_rndInt(5, 8), 10, 10, 1, dir, 1, 2, 1) --barrage-1
			elseif mKey == 3 and sides ~= 8 then qSmoothBarrageSpiral(8, 4, 4, 1, dir, 1, 2, 1) --barrage-1, 4
			elseif mKey == 4 then qSmoothBarrageSpiral(u_rndInt(3, 5), 10, 10, 2, dir, 1, 2, 1) --barrage-2
			elseif mKey == 5 and sides ~= 8 then qSpiral(winding(1.5, 2.5), 0.25, dir, sides-2, 2, true, 4) --2/4-single spiral
			elseif mKey == 6 and sides == 8 then qSpiral(winding(1.5, 2.5), 0, dir, 2, 2, true, 1.5) --2thick double
			elseif mKey == 7 and sides == 8 then qSmoothBarrageSpiral(u_rndInt(8, 12), 12, 12, 2, dir, 1, 1.5, 2) --2gap 2 step barrage
			end
		end
	elseif DIFFICULTY == 1.01 then
		keys = {0, 1, 2, 3, 4, 5, 6, 7, 8}
		shuffle(keys)
		useSide = {6, 7, 8}

		l_setSpeedMult(2.25)
		l_setSpeedInc(0.05)

		l_setRotationSpeed(0.55)
		l_setRotationSpeedMax(1.05)
		l_setRotationSpeedInc(0.05)

		function addPattern(mKey)
			local sides, dir = l_getSides(), u_rndInt(0, 1)
				if mKey == 0 then qSpiral(10, 0, dir, 0, sides-1, false, 1.5) --single spiral
			elseif mKey == 1 then qSpiral(winding(1.5, 2.5), 0, dir, sides-2, 2, true, 1.5) --2gap single
			elseif mKey == 2 and sides ~= 8 then qSmoothBarrageSpiral(u_rndInt(8, 12), 4, u_rndInt(4, 7), 2, dir, 1, 1.5, 1) --2s 1g r barrage
			elseif mKey == 3 and sides == 8 then qSpiral(winding(1.5, 2.5), 0, dir, 2, 2, true, 1.5) --2thick double
			elseif mKey == 4 and sides >= 7 then qSmoothBarrageSpiral(u_rndInt(8, 12), 5, u_rndInt(5, 8), 2, dir, 1, 1.5, 2) --2s 2g r barrage
			elseif mKey == 5 and sides ~= 7 then qSpiral(sides, 1, dir, 1, 1, false, 1.5) --tri, quad 1-spiral
			elseif mKey == 6 and sides == 8 then qSmoothBarrageSpiral(u_rndInt(8, 12), 4, u_rndInt(4, 7), 3, dir, 1, 1.5, 2) --3s 2g r barrage
			elseif mKey == 7 and sides >= 7 then qSmoothBarrageSpiral(u_rndInt(8, 12), 12, 12, 1, dir, 1, 1.5, 2) --1s 2g r barrage
			elseif mKey == 8 and sides == 6 then qSmoothBarrageSpiral(u_rndInt(8, 12), 3, 3, 1, dir, 1, 1.5, 1) --1s 1g 3c barrage
			end
		end
	elseif DIFFICULTY == 1.02 then
		keys = {0, 1, 2, 3, 4}
		shuffle(keys)
		useSide = {9, 10}

		l_setSpeedMult(2.5)
		l_setSpeedInc(0.05)

		l_setRotationSpeed(0.7)
		l_setRotationSpeedMax(1.2)
		l_setRotationSpeedInc(0.05)

		function addPattern(mKey)
			local sides, dir = l_getSides(), u_rndInt(0, 1)
			if mKey == 0 and sides == 9 then qSpiral(9, 0, dir, 1, 2, true, 1) --triple spiral
			elseif mKey == 1 and sides == 9 then qSpiral(9, 0, dir, 2, 1, false, 1) -- tri 1-spiral
			elseif mKey == 2 and sides == 10 then qSpiral(10, 0, dir, 1, 1, false, 1) -- penta 1-spiral
			elseif mKey == 3 then qSmoothBarrageSpiral(12, 5, u_rndInt(5, 8), 2, dir, 1, 1.5, 2) --2s 2g r barrage
			elseif mKey == 4 then qSmoothBarrageSpiral(u_rndInt(8, 12), 12, 12, 2, dir, 1, 1.5, 1) --2s 1g barrage
			end
		end
	end

	l_setDelayMult(1)
	l_setDelayInc(0.0)
	l_setFastSpin(0.0)

	l_setIncTime(10)

	l_setRadiusMin(72)
	l_setPulseMin(72)
	l_setPulseMax(72)

	l_setBeatPulseMax(0)

	--l_setBeatPulseMax(14)
	--l_setBeatPulseDelayMax(21.95) -- BPM is 164, 3600/164 is 21.95
	--l_setBeatPulseSpeedMult(0.45) -- Slows down the center going back to normal

	l_setDarkenUnevenBackgroundChunk(false)
	l_enableRndSideChanges(false)

	sideCounts()

	startSpeed = l_getSpeedMult()
	startSize = l_getRadiusMin()
end

-- onLoad is an hardcoded function that is called when the level is started/restarted
function onLoad()
	print(startSpeed)
	print(startSize)
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
	sideCounts()
	--setZoom(72, (l_getSpeedMult()/startSpeed)) --not working for some reason. need to find out why.
	print(startSize)
	print(l_getRadiusMin())
	print((l_getSpeedMult()/startSpeed))
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

