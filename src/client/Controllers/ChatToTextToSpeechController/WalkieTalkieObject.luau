local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WalkieTalkie = {}
WalkieTalkie.__index = WalkieTalkie

function WalkieTalkie.New()
	local self = setmetatable({}, WalkieTalkie)

	self.Instance = nil
	self.MessageQueue = {}
	self.IsTransmitting = false

	return self
end

local function AddGutsToWalkieTalkie(BasePart)
	for _, Gut in ipairs(ReplicatedStorage.Assets.WalkieTalkieGuts:GetChildren()) do
		local GutClone = Gut:Clone()
		GutClone.Parent = BasePart
	end
end

function WalkieTalkie:WireAudioInstances()
	local AudioEmitter = self.Instance:FindFirstChildOfClass("AudioEmitter")
	local AudioTextToSpeech = self.Instance:FindFirstChildOfClass("AudioTextToSpeech")

	if AudioEmitter and AudioTextToSpeech then
		local TTSWire = AudioTextToSpeech:FindFirstChildOfClass("Wire")
		TTSWire.SourceInstance = AudioTextToSpeech
		TTSWire.TargetInstance = AudioEmitter
	end
end

function WalkieTalkie:BindToInstance(BasePart: BasePart)
	if not self.Instance then
		AddGutsToWalkieTalkie(BasePart)
		self.Instance = BasePart

		self:WireAudioInstances()
	end
end

local function PlayTextToSpeech(AudioTextToSpeech, Message)
	AudioTextToSpeech.Text = Message
	AudioTextToSpeech:Play()

	AudioTextToSpeech.Ended:Wait()
end

function WalkieTalkie:Transmit(Message)
	if not self.Instance then
		return
	end

	local AudioTextToSpeech: AudioTextToSpeech = self.Instance:FindFirstChildOfClass("AudioTextToSpeech")
	if not AudioTextToSpeech then
		warn("Walkie-talkie is missing an AudioTextToSpeech instance")
		return
	end

	table.insert(self.MessageQueue, Message)
	if self.IsTransmitting then
		return
	end

	self.IsTransmitting = true
	task.spawn(function()
		while #self.MessageQueue > 0 do
			local QueuedMessage = table.remove(self.MessageQueue, 1)
			local StaticSound: Sound = self.Instance:FindFirstChild("Static")
			if StaticSound then
				StaticSound:Stop()
				StaticSound:Play()
			end

			PlayTextToSpeech(AudioTextToSpeech, QueuedMessage)
		end

		self.IsTransmitting = false
	end)
end

return WalkieTalkie
