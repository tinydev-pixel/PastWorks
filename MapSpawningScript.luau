-- References
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local serverStorage = game:GetService("ServerStorage")

-- Config
local CHUNK_TEMPLATE = serverStorage.Maps:WaitForChild("GrassMap")
local SPAWN_DISTANCE = 150 -- Raycast length
local CHUNK_OFFSET = 200   -- Distance between chunk origins
local DESPAWN_DIST = 400   -- How far before a map is destroyed
local MAPS_FOLDER = workspace:WaitForChild("Maps")

local isSpawning = false

-- Function to find the map furthest in the Z direction
local function getFurthestMap(directionZ)
	local furthestMap = nil
	local maxDist = -math.huge

	for _, map in pairs(MAPS_FOLDER:GetChildren()) do
		if map:IsA("Model") then
			local mapZ = map:GetPivot().Position.Z
			local relativePos = mapZ * directionZ 
			if relativePos > maxDist then
				maxDist = relativePos
				furthestMap = map
			end
		end
	end
	return furthestMap
end

-- Spawn Logic (Z-Axis)
local function spawnNewChunk(directionZ)
	if isSpawning then return end
	isSpawning = true

	local leadMap = getFurthestMap(directionZ)
	local spawnZ = 0

	if leadMap then
		spawnZ = leadMap:GetPivot().Position.Z + (CHUNK_OFFSET * directionZ)
	else
		spawnZ = 0
	end

	local newMap = CHUNK_TEMPLATE:Clone()
	newMap.Parent = MAPS_FOLDER
	newMap:PivotTo(CFrame.new(235.9, 37.18, spawnZ)) -- Locked to Z-Axis movement

	task.wait(0.5) 
	isSpawning = false
end

-- Cleanup Logic (Z-Axis)
local function cleanRemoteMaps(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	for _, map in pairs(MAPS_FOLDER:GetChildren()) do
		if map:IsA("Model") then
			local dist = math.abs(map:GetPivot().Position.Z - root.Position.Z)
			if dist > DESPAWN_DIST then
				map:Destroy()
			end
		end
	end
end

-- Main Loop
players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local root = char:WaitForChild("HumanoidRootPart")

		runService.Heartbeat:Connect(function()
			-- Detect direction on Z-axis
			local lookDir = root.CFrame.LookVector
			local directionZ = math.sign(lookDir.Z)

			if directionZ ~= 0 then
				local rayParams = RaycastParams.new()
				rayParams.FilterDescendantsInstances = {char, MAPS_FOLDER}
				rayParams.FilterType = Enum.RaycastFilterType.Exclude

				-- Raycast forward along Z-axis
				local forwardRay = workspace:Raycast(root.Position, Vector3.new(0, 0, directionZ) * SPAWN_DISTANCE, rayParams)

				if not forwardRay then
					spawnNewChunk(directionZ)
				end
			end

			cleanRemoteMaps(char)
		end)
	end)
end)