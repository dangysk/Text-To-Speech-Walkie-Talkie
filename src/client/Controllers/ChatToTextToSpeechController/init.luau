local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local BroadcasterObject = require(script.BroadcasterObject)

local ChatToTextToSpeechController = {}
local Broadcasters = {}

local TaggedBroadcasterInstances = CollectionService:GetTagged("Broadcaster")

for _, BroadcasterInstance in ipairs(TaggedBroadcasterInstances) do
	if BroadcasterInstance:IsDescendantOf(workspace) then -- Make sure its loaded in the map
		local Broadcaster = BroadcasterObject.New()
		Broadcaster:BindToInstance(BroadcasterInstance)
		table.insert(Broadcasters, Broadcaster)
	end
end

--[[
If you want to add new broadcasters per-session (like when you create a new police car)
just add it into the ExistingBroadcaster table here and it will probably work
]]

local function IsSenderHoldingTransmitter(Transmitter: Player)
	local Character = Transmitter.Character

	if Character then
		local EquippedTool = Character:FindFirstChildOfClass("Tool")

		if EquippedTool and EquippedTool:HasTag("Transmitter") then
			return true
		end
	end

	return false
end

TextChatService.OnIncomingMessage = function(Message)
	if Message.Status ~= Enum.TextChatMessageStatus.Success then
		return
	end

	if not Message.TextSource or Message.Text == "" then
		return
	end

	local Sender = Players:GetPlayerByUserId(Message.TextSource.UserId)

	if Sender and IsSenderHoldingTransmitter(Sender) then
		for _, Broadcaster in ipairs(Broadcasters) do
			Broadcaster:Transmit(Message.Text, Sender)
		end
	end
end

return ChatToTextToSpeechController
