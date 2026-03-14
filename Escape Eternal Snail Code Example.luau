------------------------------
-- Map Spawning Script
------------------------------

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

------------------------------
-- Shop Purchase handling
------------------------------

-- References
local remoteEvents = game.ReplicatedStorage.RemoteEvents
local dataManager = require(game.ServerScriptService.Data.DataManager)
local devProducts = require(game.ServerScriptService.Libraries.DevProducts)
local marketplaceService = game:GetService("MarketplaceService")
local dataStoreService = game:GetService("DataStoreService")
local donationsDataStore = dataStoreService:GetOrderedDataStore("DonationsLeaderboard")

-- Function to handle robux purchases
local function HandleRobuxPurchase(player, productName)
	local productId = devProducts[productName]
	if not productId then return end

	marketplaceService:PromptProductPurchase(player, productId)
end

-- Function to handle tix purchases
local function HandleTixPurchase(player, productName)
	if productName == "OneSpeed" then
		dataManager.RemoveTix(player, 100)
		dataManager.AddSpeed(player, 1)
	elseif productName == "FiveSpeed" then
		dataManager.RemoveTix(player, 500)
		dataManager.AddSpeed(player, 5)
	elseif productName == "TenSpeed" then
		dataManager.RemoveTix(player, 1000)
		dataManager.AddSpeed(player, 10)
	end
end

-- Function to process receipts
marketplaceService.ProcessReceipt = function(receiptInfo)
	local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId
	local productName = nil

	for name, id in pairs(devProducts) do
		if id == productId then
			productName = name
			break
		end
	end

	-- 1. Handle Gameplay Upgrades
	if productName == "DoubleSpeed" then
		dataManager.PurchaseDoubleSpeed(player)
	elseif productName == "OneSpeed" then
		dataManager.AddSpeed(player, 1)
	elseif productName == "FiveSpeed" then
		dataManager.AddSpeed(player, 5)
	elseif productName == "TenSpeed" then
		dataManager.AddSpeed(player, 10)

		-- 2. Handle Donation Leaderboard (Fixed UpdateAsync)
	elseif productName == "HundredRobux" or productName == "FiveHundredRobux" or productName == "ThousandRobux" then
		local amount = 0
		if productName == "HundredRobux" then amount = 100
		elseif productName == "FiveHundredRobux" then amount = 500
		elseif productName == "ThousandRobux" then amount = 1000 end

		-- Increment the player's total in the OrderedDataStore
		pcall(function()
			donationsDataStore:UpdateAsync(tostring(player.UserId), function(oldValue)
				return (oldValue or 0) + amount
			end)
		end)
	else
		-- Product name not recognized
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- If code reached here, the purchase was successful
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Connect functions to events
remoteEvents.PurchaseDevProduct.OnServerEvent:Connect(function(player, productName)
	HandleRobuxPurchase(player, productName)
end)

remoteEvents.PurchaseUpgrade.OnServerEvent:Connect(function(player, productName, boolean)
	if boolean then
		HandleRobuxPurchase(player, productName)
	else
		HandleTixPurchase(player, productName)
	end
end)