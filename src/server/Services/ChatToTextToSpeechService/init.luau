local Players = game:GetService("Players")
local AvailableVoices = require(script.AvailableVoices)
local GirlyCharacterDetector = require(script.GirlyCharacterDetector)

local ChatToTextToSpeechService = {}

local VoiceRandom = Random.new()

local function AssignVoiceId(Player: Player)
	local IsPlayerFemale = true

	if not AvailableVoices.MaleVoicesOnly then
		IsPlayerFemale = GirlyCharacterDetector.IsGirly(Player.Character, 0.2)
	end

	local AppropriateVoices = IsPlayerFemale and AvailableVoices.GirlsVoices or AvailableVoices.MaleVoices

	local ExistingVoiceId = Player:GetAttribute("VoiceId")
	if table.find(AppropriateVoices, ExistingVoiceId) then
		return
	end

	local VoiceIdCounts: { [string]: number } = {}

	for _, VoiceId in ipairs(AppropriateVoices) do
		VoiceIdCounts[VoiceId] = 0
	end

	for _, ExistingPlayer in ipairs(Players:GetPlayers()) do
		local VoiceId = ExistingPlayer:GetAttribute("VoiceId")

		if VoiceIdCounts[VoiceId] ~= nil then
			VoiceIdCounts[VoiceId] += 1
		end
	end

	local AvailableVoiceIds = {}

	for _, VoiceId in ipairs(AppropriateVoices) do
		if VoiceIdCounts[VoiceId] == 0 then
			table.insert(AvailableVoiceIds, VoiceId)
		end
	end

	if #AvailableVoiceIds == 0 then
		AvailableVoiceIds = AppropriateVoices
	end

	local SelectedVoiceId = AvailableVoiceIds[VoiceRandom:NextInteger(1, #AvailableVoiceIds)]
	Player:SetAttribute("VoiceId", SelectedVoiceId)
end

Players.PlayerAdded:Connect(function(Player: Player)
	Player.CharacterAdded:Connect(function(Character)
		AssignVoiceId(Player)
	end)
end)

for _, Player in ipairs(Players:GetPlayers()) do
	AssignVoiceId(Player)
end

return ChatToTextToSpeechService
