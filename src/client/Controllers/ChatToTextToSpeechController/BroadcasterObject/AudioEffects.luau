-- These make the voice sound a little more distorted for a radio/walkie-talkie effect
-- You're free to remove the contents of the return table below if you want to effects!

return {
	["AudioDistortion"] = {
		Level = 0.25,
	},

	["AudioEqualizer"] = {
		HighGain = -12,
		LowGain = -20,
		MidGain = 5,
		MidRange = NumberRange.new(300, 2400),
	},

	["AudioReverb"] = {
		DecayRatio = 0.5,
		DecayTime = 0.1,
		Density = 0.1,
		Diffusion = 0.1,
		DryLevel = 0,
		EarlyDelayTime = 0,
		HighCutFrequency = 4000,
		LateDelayTime = 0,
		LowShelfFrequency = 250,
		LowShelfGain = -6,
		ReferenceFrequency = 1000,
		WetLevel = -30,
	},

	["AudioCompressor"] = {
		Attack = 0.01,
		MakeupGain = 3,
		Ratio = 4,
		Release = 0.1,
		Threshold = -20,
	},
}
