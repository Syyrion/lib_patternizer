u_execDependencyScript('library_extbase', 'extbase', 'syyrion', 'utils.lua')
u_execDependencyScript('library_extbase', 'extbase', 'syyrion', 'common.lua')
u_execDependencyScript('library_slider', 'slider', 'syyrion', 'master.lua')

local FRAMES_PER_PLAYER_ROTATION = 800 / 21

Patternizer = {}

-- Creates a single ring of walls

function Patternizer.horizontal(str)
	local sides, ix = l_getSides(), 0
	str = type(str) == 'string' and str or error('Argument #1 is not a string', 2)
    local loc = str:find('|')
	local nonLoop, loop
	if loc then
		nonLoop, loop = str:sub(0, loc - 1), str:sub(loc + 1)
	else
		nonLoop, loop = str, ''
	end

	local function make(p)
		p:gsub('[cor%. _]', function (s)
			({
				['c'] = cWall,
				['.'] = cWall,
				['o'] = oWall,
				['r'] = rWall,
				[' '] = nop,
				['_'] = nop,
			})[s](ix)
			ix = ix + 1
			if ix == sides then error() end
			return s
		end)
	end

	if not pcall(make, nonLoop) then return end

	if loop:len() == 0 then return end

	while pcall(make, loop) do end
end

