local AvailableVoices = {}
local ForeignVoicesEnabled = false -- Turn autolocalise off in BroadcasterObject if you're enabling this or it wont work
AvailableVoices.MaleVoicesOnly = false -- Enabling this disables the feature where characters are checked to be 'girly' or not and matches voice with them

AvailableVoices.MaleVoices = {
	"1",
	"3",
	"5",
	"7",
}

AvailableVoices.GirlsVoices = {
	"2",
	"4",
	"6",
	"8",
}

local ForeignMaleVoices = {
	"101",
	"201",
	"301",
	"401",
	"501",
	"601",
	"701",
	"801",
	"901",
	"1001",
}

if ForeignVoicesEnabled == true then
	for _, VoiceId in pairs(ForeignMaleVoices) do
		table.insert(AvailableVoices.MaleVoices, VoiceId)
	end
end

return AvailableVoices
