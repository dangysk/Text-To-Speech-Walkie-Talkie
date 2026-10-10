local BroadcasterObject = {}
BroadcasterObject.__index = BroadcasterObject

local AudioEffects = require(script.AudioEffects)
local OnBroadcastSoundEffects = require(script.OnBroadcastSoundEffects)
local AutoLocalise = true
--[[ 
Enable AutoLocalise if you want text to speech to auto translate to player's language
Enabling this makes you lose out on broken-english accents such as Japanese, french, german, etc if they're enabled
This is because they auto translate to an english accent D:
]]

type QueuedMessage = {
	Text: string,
	Transmitter: Player,
}

function BroadcasterObject.New()
	local self = setmetatable({}, BroadcasterObject)

	self.Instance = nil
	self.MessageQueue = {} :: { QueuedMessage }
	self.OnBroadcastSounds = {} :: { Sound }
	self.IsTransmitting = false

	return self
end

function BroadcasterObject:AddAudioInstances()
	local AudioEmitter = Instance.new("AudioEmitter")
	AudioEmitter.DistanceAttenuationBounds = NumberRange.new(10, 120) -- Min and max range to hear reciever
	AudioEmitter.Parent = self.Instance

	local AudioTextToSpeech = Instance.new("AudioTextToSpeech")
	AudioTextToSpeech.AutoLocalize = AutoLocalise
	AudioTextToSpeech.Parent = self.Instance

	local AudioEffectsFolder = Instance.new("Folder")
	AudioEffectsFolder.Name = "Effects"
	AudioEffectsFolder.Parent = self.Instance

	for InstanceName, Properties in pairs(AudioEffects) do
		local AudioEffect = Instance.new(InstanceName)
		AudioEffect.Parent = AudioEffectsFolder

		for Property, PropertyValue in pairs(Properties) do
			AudioEffect[Property] = PropertyValue
		end
	end

	for SoundName, Properties in pairs(OnBroadcastSoundEffects) do
		local Sound = Instance.new("Sound")
		Sound.Name = SoundName
		Sound.Parent = self.Instance

		for Property, PropertyValue in pairs(Properties) do
			Sound[Property] = PropertyValue
		end

		table.insert(self.OnBroadcastSounds, Sound)
	end
end

function BroadcasterObject:WireAudioInstances()
	local AudioEmitter = self.Instance:FindFirstChildOfClass("AudioEmitter")
	local AudioTextToSpeech = self.Instance:FindFirstChildOfClass("AudioTextToSpeech")
	local Effects = self.Instance.Effects:GetChildren()

	local LastSoundEffect = AudioTextToSpeech

	for _, SoundEffect: AudioDistortion in ipairs(Effects) do
		local Wire = Instance.new("Wire")
		Wire.Parent = SoundEffect
		Wire.SourceInstance = LastSoundEffect
		Wire.TargetInstance = SoundEffect

		LastSoundEffect = SoundEffect
	end

	if LastSoundEffect ~= AudioTextToSpeech and AudioEmitter then
		local Wire = Instance.new("Wire")
		Wire.Parent = LastSoundEffect
		Wire.SourceInstance = LastSoundEffect
		Wire.TargetInstance = AudioEmitter
	end
end

function BroadcasterObject:BindToInstance(BasePart: BasePart)
	if not self.Instance then
		self.Instance = BasePart

		self:AddAudioInstances()
		self:WireAudioInstances()
	end
end

local function GetTransmitterVoiceId(Transmitter: Player): string
	local VoiceId = Transmitter:GetAttribute("VoiceId")

	while typeof(VoiceId) ~= "string" do
		Transmitter:GetAttributeChangedSignal("VoiceId"):Wait()
		VoiceId = Transmitter:GetAttribute("VoiceId")
	end

	return VoiceId
end

local function PlayTextToSpeech(AudioTextToSpeech: AudioTextToSpeech, Message: QueuedMessage)
	AudioTextToSpeech.VoiceId = GetTransmitterVoiceId(Message.Transmitter)
	AudioTextToSpeech.Text = Message.Text

	local LoadSucceeded, LoadStatus = pcall(function()
		return AudioTextToSpeech:LoadAsync()
	end)

	if not LoadSucceeded then
		return
	end

	if LoadStatus ~= Enum.AssetFetchStatus.Success then
		return
	end

	AudioTextToSpeech:Play()
	AudioTextToSpeech.Ended:Wait()
end

function BroadcasterObject:Transmit(Message: string, Transmitter: Player)
	if not self.Instance then
		return
	end

	local AudioTextToSpeech: AudioTextToSpeech = self.Instance:FindFirstChildOfClass("AudioTextToSpeech")

	if not AudioTextToSpeech then
		warn("Walkie-talkie is missing an AudioTextToSpeech instance")
		return
	end

	table.insert(self.MessageQueue, {
		Text = Message,
		Transmitter = Transmitter,
	})

	if self.IsTransmitting then
		return
	end

	self.IsTransmitting = true

	task.spawn(function()
		while #self.MessageQueue > 0 do
			local QueuedMessage = table.remove(self.MessageQueue, 1)

			for _, Sound in ipairs(self.OnBroadcastSounds) do
				Sound:Play()
			end

			local PlaybackSucceeded, PlaybackError = pcall(PlayTextToSpeech, AudioTextToSpeech, QueuedMessage)

			if not PlaybackSucceeded then
				warn(PlaybackError)
			end
		end

		self.IsTransmitting = false
	end)
end

return BroadcasterObject
