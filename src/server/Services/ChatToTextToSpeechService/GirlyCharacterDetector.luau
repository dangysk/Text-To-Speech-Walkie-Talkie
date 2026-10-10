-- Below is pure AI slop, dont hold me accountable if it fails to work or anything
local GirlyDetector = {}

local CollectionService = game:GetService("CollectionService")

GirlyDetector.Version = "2.0.0"

GirlyDetector.Defaults = {
	Threshold = 55,
	MinConfidence = 0.12,
	UseColorAnalysis = true,
	UseAccessoryAnalysis = true,
	UseClothingAnalysis = true,
	UseNameAnalysis = true,
	UseCustomTags = true,
	MaxInstances = 1500,
	CacheDuration = 0, -- 0 disables caching
}

-- Each category has a fixed maximum influence on the final score.
local CATEGORY_WEIGHTS = {
	Accessories = 0.32,
	Clothing = 0.25,
	Colors = 0.20,
	Hair = 0.13,
	CustomTags = 0.10,
}

local KEYWORDS = {
	Accessories = {
		{ "bow", 1.0 },
		{ "ribbon", 0.95 },
		{ "tiara", 1.0 },
		{ "crown", 0.65 },
		{ "flower", 0.75 },
		{ "floral", 0.65 },
		{ "heart", 0.55 },
		{ "handbag", 0.75 },
		{ "purse", 0.75 },
		{ "earring", 0.70 },
		{ "necklace", 0.50 },
		{ "bracelet", 0.50 },
		{ "pearl", 0.75 },
		{ "lace", 0.75 },
		{ "frill", 0.80 },
		{ "ruffle", 0.75 },
		{ "veil", 0.65 },
		{ "fairy", 0.85 },
		{ "angel", 0.70 },
		{ "butterfly", 0.70 },
		{ "teddy", 0.55 },
		{ "plush", 0.55 },
		{ "kitty", 0.65 },
		{ "cat ear", 0.65 },
		{ "headband", 0.60 },
		{ "coquette", 1.0 },
		{ "ballet", 0.75 },
		{ "aesthetic", 0.30 },
	},

	Clothing = {
		{ "skirt", 0.90 },
		{ "dress", 1.0 },
		{ "pink", 0.60 },
		{ "pastel", 0.70 },
		{ "cardigan", 0.55 },
		{ "blouse", 0.80 },
		{ "corset", 0.85 },
		{ "lace", 0.70 },
		{ "frilly", 0.80 },
		{ "ruffle", 0.75 },
		{ "kawaii", 0.90 },
		{ "cute", 0.55 },
		{ "princess", 0.90 },
		{ "balletcore", 0.95 },
		{ "coquette", 1.0 },
		{ "soft girl", 0.95 },
		{ "lolita", 0.85 },
		{ "gown", 0.85 },
		{ "heels", 0.65 },
		{ "bow", 0.70 },
		{ "floral", 0.60 },
	},

	Hair = {
		{ "long hair", 0.65 },
		{ "ponytail", 0.55 },
		{ "pigtail", 0.75 },
		{ "twin tail", 0.80 },
		{ "braid", 0.45 },
		{ "bun", 0.40 },
		{ "curly hair", 0.35 },
		{ "wavy hair", 0.40 },
		{ "pink hair", 0.90 },
		{ "pastel hair", 0.85 },
		{ "hair bow", 0.85 },
		{ "flower hair", 0.75 },
		{ "princess hair", 0.95 },
	},

	Styles = {
		{ "coquette", 1.0 },
		{ "kawaii", 0.95 },
		{ "soft girl", 0.95 },
		{ "balletcore", 0.95 },
		{ "fairycore", 0.85 },
		{ "pastel goth", 0.65 },
		{ "princess", 0.90 },
		{ "doll", 0.65 },
		{ "glam", 0.55 },
		{ "elegant", 0.50 },
		{ "cute", 0.50 },
		{ "feminine", 0.90 },
	},
}

local POSITIVE_TAGS = {
	girly = 1.0,
	feminine = 1.0,
	coquette = 1.0,
	kawaii = 0.95,
	softgirl = 0.95,
	pastel = 0.80,
	princess = 0.90,
	balletcore = 0.90,
	fairycore = 0.85,
}

local NEGATIVE_TAGS = {
	masculine = -0.75,
	rugged = -0.50,
	tactical = -0.50,
	military = -0.45,
	industrial = -0.30,
}

local STYLE_KEYWORDS = {
	Coquette = { "coquette", "bow", "ribbon", "lace", "pearl" },
	Kawaii = { "kawaii", "kitty", "plush", "cute", "pastel" },
	Princess = { "princess", "tiara", "crown", "gown" },
	SoftGirl = { "soft girl", "cardigan", "pastel", "cute" },
	Fairycore = { "fairy", "butterfly", "flower", "angel" },
	Elegant = { "elegant", "pearl", "gown", "lace" },
	Glam = { "glam", "heels", "jewelry", "luxury" },
}

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("[%p_%-]", " ")
end

local function containsKeyword(text, keyword)
	text = normalize(text)
	keyword = normalize(keyword)

	-- Plain substring matching is useful for catalogue names.
	return text:find(keyword, 1, true) ~= nil
end

local function getOptions(options)
	local result = table.clone(GirlyDetector.Defaults)

	for key, value in pairs(options or {}) do
		if result[key] ~= nil then
			result[key] = value
		end
	end

	result.Threshold = math.clamp(tonumber(result.Threshold) or 55, 0, 100)
	result.MinConfidence = math.clamp(tonumber(result.MinConfidence) or 0.12, 0, 1)
	result.MaxInstances = math.max(1, math.floor(tonumber(result.MaxInstances) or 1500))

	return result
end

local function addEvidence(state, category, label, strength)
	strength = math.clamp(strength, 0, 1)

	state.Signals[category] = state.Signals[category] or {}

	table.insert(state.Signals[category], {
		Label = label,
		Strength = strength,
	})
end

local function scanKeywords(state, category, text, keywords)
	for _, item in ipairs(keywords) do
		local keyword = item[1]
		local strength = item[2]

		if containsKeyword(text, keyword) then
			addEvidence(state, category, keyword, strength)
		end
	end
end

local function hasVisualTag(instance)
	local tags = CollectionService:GetTags(instance)

	for _, tag in ipairs(tags) do
		local key = normalize(tag):gsub("%s+", "")

		if POSITIVE_TAGS[key] then
			return key, POSITIVE_TAGS[key]
		end
	end

	return nil, 0
end

local function analyzeColor(color)
	local h, s, v = color:ToHSV()

	local pastel = v >= 0.78 and s >= 0.12 and s <= 0.65
	local pink = h >= 0.90 or h <= 0.045
	local purple = h >= 0.70 and h <= 0.88
	local lightBlue = h >= 0.48 and h <= 0.59
	local peach = h >= 0.045 and h <= 0.12
	local white = s <= 0.12 and v >= 0.82

	local score = 0
	local traits = {}

	if pink and s >= 0.18 and v >= 0.45 then
		score = math.max(score, 0.95)
		table.insert(traits, "Pink")
	end

	if purple and s >= 0.18 and v >= 0.45 then
		score = math.max(score, 0.70)
		table.insert(traits, "Purple")
	end

	if pastel then
		score = math.max(score, 0.65)
		table.insert(traits, "Pastel")
	end

	if lightBlue and v >= 0.65 then
		score = math.max(score, 0.50)
		table.insert(traits, "Soft Blue")
	end

	if peach and v >= 0.70 then
		score = math.max(score, 0.65)
		table.insert(traits, "Peach")
	end

	if white then
		score = math.max(score, 0.35)
		table.insert(traits, "White")
	end

	return score, traits
end

local function analyzeCustomTags(state, instance)
	local attributeNames = {
		"Aesthetic",
		"GirlyStyle",
		"AvatarStyle",
	}

	for _, attributeName in ipairs(attributeNames) do
		local value = instance:GetAttribute(attributeName)

		if typeof(value) == "string" then
			scanKeywords(state, "CustomTags", value, KEYWORDS.Styles)

			local normalized = normalize(value):gsub("%s+", "")

			if POSITIVE_TAGS[normalized] then
				addEvidence(state, "CustomTags", "Attribute: " .. value, POSITIVE_TAGS[normalized])
			elseif NEGATIVE_TAGS[normalized] then
				addEvidence(state, "CustomTags", "Attribute: " .. value, math.abs(NEGATIVE_TAGS[normalized]) * 0.15)
			end
		end
	end

	local tag, strength = hasVisualTag(instance)

	if tag then
		addEvidence(state, "CustomTags", "Collection tag: " .. tag, strength)
	end
end

local function getCategoryScore(signals)
	if not signals or #signals == 0 then
		return 0
	end

	-- Multiple matching words should help, but cannot inflate
	-- a single category indefinitely.
	local remaining = 1
	local total = 0

	for _, signal in ipairs(signals) do
		local contribution = signal.Strength * 0.65
		total += remaining * contribution
		remaining *= (1 - contribution)
	end

	return math.clamp(total, 0, 1)
end

local function collectTraits(signals)
	local result = {}
	local seen = {}

	for _, categorySignals in pairs(signals) do
		for _, signal in ipairs(categorySignals) do
			local label = signal.Label

			if not seen[label] then
				seen[label] = true
				table.insert(result, label)
			end
		end
	end

	table.sort(result)
	return result
end

local function detectStyle(signals)
	local textParts = {}

	for _, categorySignals in pairs(signals) do
		for _, signal in ipairs(categorySignals) do
			table.insert(textParts, signal.Label)
		end
	end

	local text = table.concat(textParts, " ")
	local bestStyle = "Mixed / Undetermined"
	local bestScore = 0

	for style, keywords in pairs(STYLE_KEYWORDS) do
		local score = 0

		for _, keyword in ipairs(keywords) do
			if containsKeyword(text, keyword) then
				score += 1
			end
		end

		if score > bestScore then
			bestScore = score
			bestStyle = style
		end
	end

	return bestStyle
end

function GirlyDetector.Analyze(character, userOptions)
	local options = getOptions(userOptions)

	local result = {
		IsGirly = false,
		Score = 0,
		Confidence = 0,
		Style = "Mixed / Undetermined",
		Traits = {},
		Breakdown = {},
		Evidence = {},
		Recommendations = {},
		Version = GirlyDetector.Version,
	}

	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		result.Error = "Expected a character Model."
		return result
	end

	local state = {
		Signals = {},
		Inspected = 0,
		Relevant = 0,
	}

	for category in pairs(CATEGORY_WEIGHTS) do
		state.Signals[category] = {}
	end

	local descendants = character:GetDescendants()

	for index, instance in ipairs(descendants) do
		if index > options.MaxInstances then
			break
		end

		state.Inspected += 1

		if options.UseNameAnalysis then
			local name = instance.Name

			if options.UseAccessoryAnalysis and instance:IsA("Accessory") then
				scanKeywords(state, "Accessories", name, KEYWORDS.Accessories)

				scanKeywords(state, "Accessories", name, KEYWORDS.Styles)
			end

			if
				options.UseClothingAnalysis
				and (instance:IsA("Shirt") or instance:IsA("Pants") or instance:IsA("ShirtGraphic"))
			then
				scanKeywords(state, "Clothing", name, KEYWORDS.Clothing)
			end

			if instance:IsA("Accessory") or instance:IsA("BasePart") then
				scanKeywords(state, "Hair", name, KEYWORDS.Hair)
			end

			if
				instance:IsA("Accessory")
				or instance:IsA("Shirt")
				or instance:IsA("Pants")
				or instance:IsA("ShirtGraphic")
			then
				scanKeywords(state, "Clothing", name, KEYWORDS.Styles)
			end
		end

		if options.UseCustomTags then
			analyzeCustomTags(state, instance)
		end

		if options.UseColorAnalysis and instance:IsA("BasePart") then
			local score, colorTraits = analyzeColor(instance.Color)

			if score > 0 then
				addEvidence(state, "Colors", table.concat(colorTraits, ", "), score)
			end
		end
	end

	-- Evaluate each category independently.
	local weightedScore = 0
	local availableWeight = 0
	local evidenceCount = 0

	for category, weight in pairs(CATEGORY_WEIGHTS) do
		local categoryScore = getCategoryScore(state.Signals[category])

		local enabled = (category == "Accessories" and options.UseAccessoryAnalysis)
			or (category == "Clothing" and options.UseClothingAnalysis)
			or (category == "Colors" and options.UseColorAnalysis)
			or (category == "Hair" and options.UseNameAnalysis)
			or (category == "CustomTags" and options.UseCustomTags)

		if enabled then
			weightedScore += categoryScore * weight
			availableWeight += weight
		end

		result.Breakdown[category] = math.floor(categoryScore * 100 + 0.5)

		for _, signal in ipairs(state.Signals[category]) do
			evidenceCount += 1

			table.insert(result.Evidence, {
				Category = category,
				Feature = signal.Label,
				Strength = signal.Strength,
			})
		end
	end

	if availableWeight > 0 then
		result.Score = math.floor(math.clamp(weightedScore / availableWeight * 100, 0, 100) + 0.5)
	end

	-- Confidence measures available evidence, not certainty
	-- about a character's identity.
	local categoryCount = 0

	for category, weight in pairs(CATEGORY_WEIGHTS) do
		local enabled = (category == "Accessories" and options.UseAccessoryAnalysis)
			or (category == "Clothing" and options.UseClothingAnalysis)
			or (category == "Colors" and options.UseColorAnalysis)
			or (category == "Hair" and options.UseNameAnalysis)
			or (category == "CustomTags" and options.UseCustomTags)

		if enabled and #state.Signals[category] > 0 then
			categoryCount += 1
		end
	end

	local evidenceFactor = 1 - math.exp(-evidenceCount / 5)
	local diversityFactor = math.min(categoryCount / 3, 1)

	result.Confidence = math.floor(math.clamp(evidenceFactor * (0.45 + diversityFactor * 0.55), 0, 1) * 100 + 0.5) / 100

	result.IsGirly = result.Score >= options.Threshold and result.Confidence >= options.MinConfidence

	result.Style = detectStyle(state.Signals)
	result.Traits = collectTraits(state.Signals)

	table.sort(result.Evidence, function(a, b)
		return a.Strength > b.Strength
	end)

	if result.Confidence < 0.25 then
		table.insert(
			result.Recommendations,
			"Low visual evidence. Add descriptive avatar tags or inspect catalog asset metadata."
		)
	end

	if result.Score >= 75 then
		table.insert(result.Recommendations, "Strong match for the configured aesthetic signals.")
	elseif result.Score >= 45 then
		table.insert(result.Recommendations, "Mixed aesthetic signals; inspect the category breakdown.")
	else
		table.insert(result.Recommendations, "Few matching aesthetic signals were detected.")
	end

	result.InspectedInstances = state.Inspected
	result.EvidenceCount = evidenceCount

	return result
end

function GirlyDetector.IsGirly(character, threshold)
	local result = GirlyDetector.Analyze(character, {
		Threshold = threshold or GirlyDetector.Defaults.Threshold,
	})

	return result.IsGirly, result.Score, result
end

return GirlyDetector
