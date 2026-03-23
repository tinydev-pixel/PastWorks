-- References
local collectionService = game:GetService("CollectionService")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local spawnBoxes = game.Workspace:WaitForChild("SpawnBoxes")
local fishes = game.ServerStorage:WaitForChild("FishModels")
local fishData = require(game.ServerScriptService.Modules.FishData)
local mutationData = require(game.ServerScriptService.Modules.MutationData)

-- VFX
local vfxFolder = game.ServerStorage:WaitForChild("VFX")
local legVFX = vfxFolder.LegendarySpawningVFX
local mythicVFX = vfxFolder.MythicSpawningVFX

-- SFX
local legSFX = game.SoundService.SpawnSounds:WaitForChild("LegendarySpawnSound")
local mythicSFX = game.SoundService.SpawnSounds:WaitForChild("MythicSpawnSound")

------------------------------------------------
-- PLAY VFX FUNCTION
------------------------------------------------
local function playVFX(fishClone, rarity, spawnbox)
	if rarity == "Legendary" then
		local clone = legVFX:Clone()
		clone.Parent = fishClone
		clone.Position = fishClone.HitBox.Position

		for _, vfx in ipairs(clone:GetDescendants()) do
			if vfx:IsA("ParticleEmitter") then
				task.delay(0.35, function()
					vfx.Enabled = true
					vfx:Emit(1)
					legSFX:Play()
					task.delay(0.5, function()
						vfx.Enabled = false
					end)
				end)
			end
		end
	elseif rarity == "Mythic" then
		local vfxClone = mythicVFX:Clone()
		local attachment = vfxClone.Attachment
		vfxClone.Parent = spawnbox
		vfxClone.Position = fishClone.HitBox.Position - Vector3.new(2.5, 0, 0)

		mythicSFX:Play()

		-- Helper to trigger bursts
		local function fire(emitter, count)
			if emitter then emitter:Emit(count or 1) end
		end

		task.spawn(function()
			-- 0.0s: Initial Burst
			fire(attachment.Emit1)

			task.wait(0.25)
			fire(attachment.Emit1Delay05)

			task.wait(0.65) 
			fire(attachment.Emit1Delay18)

			task.wait(0.1) -- Original 0.2 / 2
			fire(attachment.Emit1Delay2)
			fire(attachment.Emit1Delay22)
			fire(attachment.Emit1RepeatCount1RepetDelay2)
			fire(attachment.Emit1Delay2, 2)
		end)

		game:GetService("Debris"):AddItem(vfxClone, 3)
	end
end

------------------------------------------------
-- WEIGHTED FISH PICKER (NEW)
------------------------------------------------
local function getWeightedFish()
	local totalWeight = 0

	-- Calculate total rarity weight from the ModuleData
	for name, data in pairs(fishData) do
		totalWeight += data.Rarity or 0
	end

	local roll = math.random() * totalWeight
	local running = 0

	for name, data in pairs(fishData) do
		running += data.Rarity or 0
		if roll <= running then
			-- Find the actual model in ServerStorage that matches the name in Data
			local model = fishes:FindFirstChild(name)
			if model then
				return model
			end
		end
	end

	return fishes:GetChildren()[math.random(#fishes:GetChildren())]
end

-- Function to generate fish size, weight, and apply model scale
local function generateFishStats(fishClone)
	local fish = fishData[fishClone.Name]
	if not fish then return end

	if not fishClone:GetAttribute("BaseScale") then
		fishClone:SetAttribute("BaseScale", fish.BaseScale or 1)
	end

	------------------------------------------------
	-- SIZE
	------------------------------------------------
	local size = math.random(fish.MinSize * 10, fish.MaxSize * 10) / 10
	local sizeRatio = size / fish.MaxSize

	------------------------------------------------
	-- WEIGHT
	------------------------------------------------
	local weight =
		fish.BaseWeight *
		(sizeRatio ^ 3) *
		fish.Density

	weight *= math.random(97, 103) / 100
	weight = math.floor(weight * 100) / 100

	------------------------------------------------
	-- VALUE
	------------------------------------------------
	local value = math.max(1, math.floor(weight * fish.ValuePerKg))

	------------------------------------------------
	-- SCALE MODEL
	------------------------------------------------
	local baseScale = fishClone:GetAttribute("BaseScale")
	local scaleMultiplier = math.lerp(0.7, 1.25, sizeRatio)
	fishClone:ScaleTo(baseScale * scaleMultiplier)

	------------------------------------------------
	-- STORE
	------------------------------------------------
	fishClone:SetAttribute("Size", size)
	fishClone:SetAttribute("Weight", weight)
	fishClone:SetAttribute("Value", value)

	return {
		Size = size,
		Weight = weight,
		Value = value,
		Scale = scaleMultiplier
	}
end

------------------------------------------------
-- WEIGHTED MUTATION PICKER
------------------------------------------------
local function getWeightedMutation()
	local totalWeight = 0

	for _, mutation in ipairs(mutationData) do
		totalWeight += mutation.Weight or 0
	end

	local roll = math.random() * totalWeight
	local running = 0

	for _, mutation in ipairs(mutationData) do
		running += mutation.Weight or 0
		if roll <= running then
			return mutation
		end
	end
end

-- Function to adjust the fish ui
local function adjustFishUI(fishClone, mutation, finalValue)
	local frame = fishClone:FindFirstChild("BillboardGui") and fishClone.BillboardGui:FindFirstChild("Frame")
	if not frame then return end

	local fishMutationName = frame:FindFirstChild("Mutation")
	local fishNameUi = frame:FindFirstChild("FishName")
	local fishValueText = frame:FindFirstChild("Value")

	local RARITIES = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Unique"}
	local rarity = "Common"
	for _, tag in ipairs(RARITIES) do
		if collectionService:HasTag(fishClone, tag) then
			rarity = tag
			break
		end
	end

	local rarityTemplate = game.ServerStorage.Ui.Rarities:FindFirstChild(rarity)
	local clonedUi = rarityTemplate and rarityTemplate:Clone()
	if clonedUi then
		clonedUi.Parent = frame
	end

	if mutation and mutation.Name ~= "" then
		if clonedUi then
			clonedUi.Position = UDim2.new(0, 0, 0, 0)
			clonedUi.Size = UDim2.new(1, 0, 0.25, 0)
		end
	else
		if fishMutationName then fishMutationName:Destroy() end

		if fishNameUi then
			fishNameUi.Position = UDim2.new(0, 0, 0.5, 0)
			fishNameUi.Size = UDim2.new(1, 0, 0.25, 0)
		end

		if fishValueText then
			fishValueText.Position = UDim2.new(0, 0, 0.75, 0)
			fishValueText.Size = UDim2.new(1, 0, 0.25, 0)
		end

		if clonedUi then
			clonedUi.Position = UDim2.new(0, 0, 0.25, 0)
			clonedUi.Size = UDim2.new(1, 0, 0.25, 0)
		end
	end

	if fishMutationName and fishMutationName.Parent then -- Check Parent because it might have been destroyed
		fishMutationName.Text = mutation.Name
		fishMutationName.TextColor3 = mutation.Color or Color3.new(1,1,1)

		local texture = fishMutationName:FindFirstChild("Texture")
		if texture then
			texture.Image = mutation.TextureId or ""
		end
	end

	if fishValueText then
		fishValueText.Text = "$ " .. finalValue .. "/s"
	end
end

------------------------------------------------
-- APPLY MUTATION
------------------------------------------------
local function applyMutation(fishClone)
	local mutation = getWeightedMutation()
	if not mutation then return end

	local baseValue = fishClone:GetAttribute("Value") or 1
	local multiplier = mutation.Multiplier or 1
	local finalValue = math.max(1, math.floor(baseValue * multiplier))

	fishClone:SetAttribute("Value", finalValue)
	fishClone:SetAttribute("Mutation", mutation.Name)

	adjustFishUI(fishClone, mutation, finalValue)

	for _, obj in ipairs(fishClone:GetDescendants()) do
		if obj:IsA("BasePart") then
			if mutation.Color then obj.Color = mutation.Color end
			if mutation.Material then obj.Material = mutation.Material end
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			if mutation.TextureId then
				obj.Texture = mutation.TextureId
			end
		end
	end
end

local function animateFish(spawnBox, fishClone)
	local speed = 6
	local moveConnection
	local stopConnection
	local resumeConnection

	local hitBox = fishClone:FindFirstChild("HitBox")

	local function startMoving()
		if moveConnection then moveConnection:Disconnect() end 

		moveConnection = runService.Heartbeat:Connect(function(dt)
			if not fishClone or not fishClone.Parent then
				if moveConnection then moveConnection:Disconnect() end
				return
			end

			-- Stop if Caught
			if fishClone:GetAttribute("Caught") then 
				if moveConnection then moveConnection:Disconnect() end
				return 
			end

			-- Move the fish
			fishClone:PivotTo(fishClone:GetPivot() * CFrame.new(speed * dt, 0, 0))

			local checkPos = fishClone:GetPivot().Position
			local nearbyParts = workspace:GetPartBoundsInRadius(checkPos, 2) 
			local nearbyParts2 = workspace:GetPartBoundsInRadius(checkPos, 2.5) 
			
			for _, part in ipairs(nearbyParts2) do
				if part.Name == "DespawnBox" then
					hitBox:Destroy()
				end
			end

			for _, part in ipairs(nearbyParts) do
				if part.Name == "DespawnBox" then
					-- Clean up everything and delete fish
					if moveConnection then moveConnection:Disconnect() end
					if stopConnection then stopConnection:Disconnect() end
					if resumeConnection then resumeConnection:Disconnect() end
					fishClone:Destroy()
					return 
				end
			end
		end)
	end

	stopConnection = replicatedStorage.BindableEvents.FreezeFish.Event:Connect(function(targetFish)
		if targetFish == fishClone then
			if moveConnection then moveConnection:Disconnect() end
		end
	end)

	resumeConnection = replicatedStorage.BindableEvents.UnfreezeFish.Event:Connect(function(targetFish)
		if targetFish == fishClone then
			startMoving()
		end
	end)

	fishClone.AncestryChanged:Connect(function()
		if not fishClone.Parent then
			if moveConnection then moveConnection:Disconnect() end
			if stopConnection then stopConnection:Disconnect() end
			if resumeConnection then resumeConnection:Disconnect() end
		end
	end)

	startMoving()
end

------------------------------------------------
-- MAIN SPAWN LOOP
------------------------------------------------
while true do
	for _, spawnBox in ipairs(spawnBoxes:GetChildren()) do
		if spawnBox.Name == "SpawnBox" then
			
			local fishTemplate = getWeightedFish()

			if fishTemplate then
				local fishClone = fishTemplate:Clone()
				fishClone.Parent = spawnBox
				
				for _, part in ipairs(fishClone:GetDescendants()) do
					if part:IsA("BasePart") and part ~= fishClone.PrimaryPart then
						part.Anchored = true
						part.CanCollide = false
					end
				end

				if not fishClone:GetAttribute("BaseScale") then
					fishClone:SetAttribute("BaseScale", fishClone:GetScale())
				end
				
				generateFishStats(fishClone)
				applyMutation(fishClone)
				animateFish(spawnBox, fishClone)
				
				fishClone:PivotTo(spawnBox.CFrame * CFrame.new(0, -1, math.random(-10, 10)))
				
				runService.Heartbeat:Wait()

				if fishClone:HasTag("Legendary") then
					playVFX(fishClone, "Legendary", spawnBox)
				elseif fishClone:HasTag("Mythic") then
					playVFX(fishClone, "Mythic", spawnBox)
				end
			end
		end
	end

	task.wait(2)
end