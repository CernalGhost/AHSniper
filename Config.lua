local AH = AHSniper
AH.Config = {}

local Config = AH.Config

local DEFAULT_QUALITY_FILTERS = {
	poor = false,
	common = true,
	uncommon = true,
	rare = true,
	epic = true,
	legendary = true,
	artifact = true,
}

local DEFAULT_CLASS_FILTERS = {
	consumable = true,
	container = true,
	weapon = true,
	gem = true,
	armor = true,
	reagent = true,
	tradegoods = true,
	enhancement = true,
	recipe = true,
	misc = true,
	glyph = true,
	battlepet = true,
	mount = true,
}

local DEFAULT_TYPE_FILTERS = {
	mountsOnly = false,
	highValueOnly = false,
}

local DEFAULTS = {
	minDealPercent = 15,
	minProfitCopper = 500,
	minReferenceCopper = 1000,
	referencePrice = "DBHistorical",
	includeCommodities = true,
	maxResultsPerBucket = 200,
	hideOutliers = true,
	groupByPercent = true,
	sortColumn = "dealPercent",
	sortAscending = false,
	qualityFilters = DEFAULT_QUALITY_FILTERS,
	classFilters = DEFAULT_CLASS_FILTERS,
	typeFilters = DEFAULT_TYPE_FILTERS,
	highValueMinCopper = 1000000,
	outlierMaxDealPercent = 80,
	outlierMaxRefToMedianRatio = 2.5,
	outlierMinNumAuctions = 2,
	-- Reset Hunter: buy underpriced fast-movers and relist at market.
	scanMode = "deals",
	resetMinSaleRate = 0.15,
	resetMinSoldPerDay = 1,
	resetMinProfitCopper = 50000,
	resetMinRoiPercent = 25,
	resetAHCutPercent = 5,
	resetIgnoreArmor = true,
	buckets = {
		{ label = "50%+ off", min = 50 },
		{ label = "40-50% off", min = 40 },
		{ label = "30-40% off", min = 30 },
		{ label = "20-30% off", min = 20 },
		{ label = "10-20% off", min = 10 },
		{ label = "5-10% off", min = 5 },
	},
}

local REFERENCE_OPTIONS = {
	{ key = "DBHistorical", label = "Historical (realm)" },
	{ key = "DBMarket", label = "Market Value (realm)" },
	{ key = "DBRecent", label = "Recent Value (realm)" },
	{ key = "DBRegionHistorical", label = "Historical (region)" },
	{ key = "DBRegionMarketAvg", label = "Market Avg (region)" },
	{ key = "max(DBHistorical,DBMarket)", label = "Max(Historical, Market)" },
	{ key = "avg(DBHistorical,DBMarket)", label = "Avg(Historical, Market)" },
}

local function CopyDefaults(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		if type(v) == "table" then
			copy[k] = CopyDefaults(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function Config.Init()
	AHSniperDB = AHSniperDB or {}
	for key, value in pairs(DEFAULTS) do
		if AHSniperDB[key] == nil then
			AHSniperDB[key] = CopyDefaults(value)
		elseif type(value) == "table" and type(AHSniperDB[key]) == "table" then
			for subKey, subValue in pairs(value) do
				if AHSniperDB[key][subKey] == nil then
					AHSniperDB[key][subKey] = subValue
				end
			end
		end
	end
end

function Config.Get(key)
	return AHSniperDB[key]
end

function Config.Set(key, value)
	AHSniperDB[key] = value
end

function Config.ToggleQuality(qualityKey)
	local filters = AHSniperDB.qualityFilters
	filters[qualityKey] = not filters[qualityKey]
end

function Config.ToggleClass(classKey)
	local filters = AHSniperDB.classFilters
	filters[classKey] = not filters[classKey]
end

function Config.GetReferenceOptions()
	return REFERENCE_OPTIONS
end

function Config.GetBucketForPercent(percent)
	local buckets = AHSniperDB.buckets
	for i = 1, #buckets do
		local bucket = buckets[i]
		local maxPercent = (buckets[i - 1] and buckets[i - 1].min) or 100
		if percent >= bucket.min and percent < maxPercent then
			return bucket.label, i
		end
	end
	return nil, nil
end
