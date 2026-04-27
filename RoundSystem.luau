local module = {}

-- Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local players = game:GetService("Players")

-- References
local bindEvents = replicatedStorage.Events.BindableEvents
local remoteEvents = replicatedStorage.Events.RemoteEvents
local remoteFunctions = replicatedStorage.Functions.RemoteFunctions

-- Modules
local roleHandler = require(script.Parent.RoleHandler)
local teleportHandler = require(script.Parent.TeleportHandler)
local alarmModule = require(script.Parent.AlarmModule)

-- Variables
local MIN_PLAYERS = 2
local TIMER_LENGTHS = {
	["Intermission"] = 10,
	["Hiding"] = 10,
	["Hunting"] = 65,
	["Ending Round"] = 10,
}
local ALARM_TIMES = { [30] = true, [60] = true, [120] = true, [180] = true, [240] = true, [270] = true }
local RoundState = {
	Idle    = "Idle",
	Running = "Running",
	Ending  = "Ending",
}
local roundState   = RoundState.Idle
local participants = {}
local hunters      = {}

local function getSurvivorCount()
	local count = 0
	for _, player in ipairs(players:GetPlayers()) do
		if player:GetAttribute("Survivor") then
			count += 1
		end
	end
	
	return count
end

local function hasLiveHunter()
	for _, player in ipairs(players:GetPlayers()) do
		if player:GetAttribute("Hunter") then return true end
	end
	
	return false
end

local function hasLiveSurvivor()
	for _, player in ipairs(players:GetPlayers()) do
		if player:GetAttribute("Survivor") then return true end
	end
	
	return false
end

local function clearTools(player)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			item:Destroy()
		end
	end

	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do
			if item:IsA("Tool") then item:Destroy() end
		end
	end
end

local function checkWinConditions()
	local noHunters   = not hasLiveHunter()
	local noSurvivors = not hasLiveSurvivor()

	if noHunters or noSurvivors then
		return noSurvivors and "Hunters" or "Survivors"
	end

	return nil
end

local function cleanupRound()
	for _, player in ipairs(players:GetPlayers()) do
		player:SetAttribute("Hunter", nil)
		player:SetAttribute("Survivor", nil)
		player.CameraMode = Enum.CameraMode.Classic
		clearTools(player)
	end

	bindEvents.ClearClones:Fire()
	bindEvents.ResetCharacters:Fire(participants)
end

local function endRound()
	cleanupRound()
	teleportHandler.TeleportBackPlayers(participants)

	participants = {}
	hunters      = {}
	roundState   = RoundState.Idle
end

local function handleTimer(phase)
	local length = TIMER_LENGTHS[phase]
	if not length then
		warn("handleTimer: Unknown phase '" .. tostring(phase) .. "'")
		return false
	end

	local endTime = os.time() + length

	while os.time() < endTime do

		if roundState == RoundState.Ending then break end

		local remaining = endTime - os.time()
		remoteEvents.UpdateRoundUi:FireAllClients(phase, remaining, getSurvivorCount())

		if phase == "Hunting" or phase == "Hiding" then
			if phase == "Hunting" and ALARM_TIMES[remaining] then
				alarmModule.ActivateAlarm(participants)
			end

			local winners = checkWinConditions()
			if winners then
				return winners
			end
		end

		task.wait(1)
	end

	remoteEvents.UpdateRoundUi:FireAllClients(phase, 0, getSurvivorCount())
	return nil
end

local function finishRound(winners)
	if roundState == RoundState.Ending then return end
	roundState = RoundState.Ending

	for _, userId in ipairs(participants) do
		local player = players:GetPlayerByUserId(userId)
		if player then
			remoteEvents.RoundOver:FireClient(player, winners)
		end
	end

	for _, userId in ipairs(participants) do
		local player = players:GetPlayerByUserId(userId)
		if player then
			remoteEvents.HandleRoundUi:FireClient(player, true)
		end
	end

	for _, userId in ipairs(participants) do
		local player = players:GetPlayerByUserId(userId)
		if player and player:GetAttribute("Survivor") then
			remoteEvents.UpdateSoundboard:FireClient(player, false)
		end
	end

	handleTimer("Ending Round")
	endRound()
end

local function hasEnoughPlayers()
	local count = 0
	for _, player in ipairs(players:GetPlayers()) do
		if not player:GetAttribute("AFK") then
			count += 1
		end
	end
	
	return count >= MIN_PLAYERS
end

local function buildParticipants()
	local list = {}
	for _, player in ipairs(players:GetPlayers()) do
		if not player:GetAttribute("AFK") then
			table.insert(list, player.UserId)
		end
	end
	
	return list
end

local function runRound()
	roundState = RoundState.Running
	table.clear(hunters)

	for _, player in ipairs(players:GetPlayers()) do
		if not player:GetAttribute("AFK") then
			remoteEvents.HandleLoadingScreen:FireClient(player)
		end
	end

	task.wait(1)

	local newHunters = roleHandler.NewRound()
	if not newHunters then
		warn("runRound: roleHandler.NewRound() returned nil — aborting round.")
		roundState = RoundState.Idle
		return
	end
	hunters = newHunters

	task.wait(6)

	participants = buildParticipants()
	participants = teleportHandler.TeleportPlayers(participants)

	for _, userId in ipairs(participants) do
		local player = players:GetPlayerByUserId(userId)
		if player then
			remoteEvents.HandleRoundUi:FireClient(player, false)
		end
	end

	for _, userId in ipairs(participants) do
		local player = players:GetPlayerByUserId(userId)
		-- TODO: add gamepass check for soundboard here
		if player and player:GetAttribute("Survivor") then
			remoteEvents.UpdateSoundboard:FireClient(player, true)
		end
	end

	teleportHandler.UpdateTable(hunters)
	teleportHandler.ReleasePlayers(participants)

	local hidingWinner = handleTimer("Hiding")
	if hidingWinner then
		finishRound(hidingWinner)
		return
	end

	teleportHandler.ReleaseHunters(hunters)

	local huntingWinner = handleTimer("Hunting")
	if huntingWinner then
		finishRound(huntingWinner)
		return
	end

	if roundState ~= RoundState.Ending then
		finishRound("Survivors")
	end
end

function module.StartGameLoop()
	task.spawn(function()

		players.PlayerAdded:Connect(function(player)
			player.AttributeChanged:Connect(function(attr)
				if attr == "Survivor" then
					remoteEvents.UpdateRoundUi:FireAllClients(nil, nil, getSurvivorCount())
				end
			end)
		end)

		while true do

			if not hasEnoughPlayers() then
				remoteEvents.UpdateRoundUi:FireAllClients("Waiting for Players", 0, nil)
				repeat task.wait(1) until hasEnoughPlayers()
			end

			handleTimer("Intermission")

			if hasEnoughPlayers() then

				local ok, err = pcall(runRound)
				if not ok then
					warn("runRound error:", err)

					participants = {}
					hunters      = {}
					roundState   = RoundState.Idle
				end
			end
		end
	end)
end

return module