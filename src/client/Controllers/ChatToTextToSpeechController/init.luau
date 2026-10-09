local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local WalkieTalkieObject = require(script.WalkieTalkieObject)

local ChatToTextToSpeechController = {}

local TestTalkie = WalkieTalkieObject.New()
TestTalkie:BindToInstance(workspace.WalkieTalkieTest)

TextChatService.OnIncomingMessage = function(Message)
	if Message.Status.Name ~= "Success" then
		return
	end

	if Message.TextSource and Message.TextSource.UserId then
		local Sender = Players:GetPlayerByUserId(Message.TextSource.UserId)

		if Sender then
			TestTalkie:Transmit(Message.Text)
		end
	end
end

return ChatToTextToSpeechController
