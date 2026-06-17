local AH = AHSniper
AH.Scanner = {}

local Scanner = AH.Scanner

local private = {
	running = false,
	mode = "deals",
	results = {},
	totalItems = 0,
	processedItems = 0,
	itemQueue = nil,
	onUpdate = nil,
	onComplete = nil,
}

-- Item classes excluded from Reset Hunter (armor moves slowly / is gear-locked).
local RESET_EXCLUDED_CLASSES = {
	[4] = true, -- Armor
}

local GetTSMPrice = AH.GetTSMPrice

local function GetReferencePrice(itemString)
	if not TSM_API then
		return AH.AppData.GetHistoricalPrice(itemString)
	end
	local refSource = AH.Config.Get("referencePrice")
	local value = TSM_API.GetCustomPriceValue(refSource, itemString)
	if value and value > 0 then
		return value
	end
	return AH.AppData.GetHistoricalPrice(itemString)
end

local function GetMedianPrice(itemString)
	local prices = {}
	local sources = { "DBMarket", "DBRecent", "DBHistorical", "DBRegionMarketAvg" }
	for i = 1, #sources do
		local price = GetTSMPrice(sources[i], itemString)
		if price then
			prices[#prices + 1] = price
		end
	end
	if #prices == 0 then
		return nil
	end
	table.sort(prices)
	return prices[math.ceil(#prices / 2)]
end

local function IsOutlier(itemString, reference, minBuyout, dealPercent, numAuctions)
	local maxDeal = AH.Config.Get("outlierMaxDealPercent")
	if dealPercent > maxDeal then
		return true, "extreme_discount"
	end

	local median = GetMedianPrice(itemString)
	if median and reference > median * AH.Config.Get("outlierMaxRefToMedianRatio") then
		return true, "inflated_reference"
	end

	if median and minBuyout < median * 0.05 and dealPercent > 60 then
		return true, "suspicious_buyout"
	end

	local minAuctions = AH.Config.Get("outlierMinNumAuctions")
	if numAuctions and numAuctions < minAuctions and dealPercent > 50 then
		return true, "low_auctions"
	end

	local saleRate = GetTSMPrice("DBRegionSaleRate", itemString)
	if saleRate and saleRate < 0.05 and dealPercent > 40 then
		return true, "low_sale_rate"
	end

	local market = GetTSMPrice("DBMarket", itemString)
	local recent = GetTSMPrice("DBRecent", itemString)
	if market and recent then
		local consensus = (market + recent) / 2
		if reference > consensus * 2 and dealPercent > 30 then
			return true, "stale_pricing"
		end
	end

	return false
end

local function GetItemName(itemString)
	if TSM_API then
		return TSM_API.GetItemName(itemString) or itemString
	end
	local id = itemString:match("^i:(%d+)") or itemString:match("^p:(%d+)")
	if id then
		return GetItemInfo(tonumber(id)) or itemString
	end
	return itemString
end

local function GetItemLink(itemString)
	if TSM_API then
		return TSM_API.GetItemLink(itemString)
	end
	local id = itemString:match("^i:(%d+)")
	if id then
		return select(2, GetItemInfo(tonumber(id))) or ("|cff9d9d9d|Hitem:" .. id .. "|h[Unknown]|h|r")
	end
	return itemString
end

local function BuildItemQueue()
	local queue = {}
	local includeCommodities = AH.Config.Get("includeCommodities")
	AH.AppData.IterateListings(function(itemString, minBuyout, isCommodity, numAuctions)
		if isCommodity and not includeCommodities then
			return
		end
		queue[#queue + 1] = {
			itemString = itemString,
			minBuyout = minBuyout,
			isCommodity = isCommodity,
			numAuctions = numAuctions or 0,
		}
	end)
	return queue
end

local function EvaluateDeal(entry)
	local minBuyout = entry.minBuyout
	local reference = GetReferencePrice(entry.itemString)
	if not reference or not minBuyout then
		return nil
	end
	if reference < AH.Config.Get("minReferenceCopper") then
		return nil
	end
	if minBuyout >= reference then
		return nil
	end
	local profit = reference - minBuyout
	if profit < AH.Config.Get("minProfitCopper") then
		return nil
	end
	local dealPercent = (profit / reference) * 100
	if dealPercent < AH.Config.Get("minDealPercent") then
		return nil
	end
	local bucketLabel = AH.Config.GetBucketForPercent(dealPercent)
	if not bucketLabel then
		return nil
	end

	local isOutlier, outlierReason = IsOutlier(entry.itemString, reference, minBuyout, dealPercent, entry.numAuctions)

	local deal = {
		itemString = entry.itemString,
		name = GetItemName(entry.itemString),
		link = GetItemLink(entry.itemString),
		minBuyout = minBuyout,
		reference = reference,
		marketPrice = GetTSMPrice("DBMarket", entry.itemString),
		dbHistorical = GetTSMPrice("DBHistorical", entry.itemString),
		dbRecent = GetTSMPrice("DBRecent", entry.itemString),
		regionSaleAvg = GetTSMPrice("DBRegionSaleAvg", entry.itemString),
		referenceSource = AH.Config.Get("referencePrice"),
		profit = profit,
		dealPercent = dealPercent,
		bucket = bucketLabel,
		isCommodity = entry.isCommodity,
		numAuctions = entry.numAuctions,
		filteredOutlier = isOutlier,
		outlierReason = outlierReason,
	}
	return AH.ItemUtils.EnrichDeal(deal)
end

-- Reset Hunter: find underpriced, fast-moving items worth buying out and
-- relisting at market. Ignores armor and anything that doesn't sell often.
local function EvaluateReset(entry)
	local minBuyout = entry.minBuyout
	if not minBuyout or minBuyout <= 0 then
		return nil
	end

	local itemString = entry.itemString
	local market = GetTSMPrice("DBMarket", itemString)
	if not market then
		return nil
	end

	-- Must be a proven fast mover.
	local saleRate = GetTSMPrice("DBRegionSaleRate", itemString)
	if not saleRate or saleRate < AH.Config.Get("resetMinSaleRate") then
		return nil
	end
	local soldPerDay = GetTSMPrice("DBRegionSoldPerDay", itemString)
	if not soldPerDay or soldPerDay < AH.Config.Get("resetMinSoldPerDay") then
		return nil
	end

	-- Ignore armor (and any other excluded classes).
	if AH.Config.Get("resetIgnoreArmor") then
		local itemID = AH.ItemUtils.ParseTSMItemString(itemString)
		if itemID and C_Item and C_Item.GetItemInfoInstant then
			local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
			if classID and RESET_EXCLUDED_CLASSES[classID] then
				return nil
			end
		end
	end

	-- Guard against obviously broken data (price a tiny fraction of market).
	if minBuyout < market * 0.02 then
		return nil
	end

	local cut = (AH.Config.Get("resetAHCutPercent") or 5) / 100
	local netSale = market * (1 - cut)
	local profit = netSale - minBuyout
	if profit < AH.Config.Get("resetMinProfitCopper") then
		return nil
	end
	local roi = (profit / minBuyout) * 100
	if roi < AH.Config.Get("resetMinRoiPercent") then
		return nil
	end

	local deal = {
		itemString = itemString,
		name = GetItemName(itemString),
		link = GetItemLink(itemString),
		minBuyout = minBuyout,
		reference = market,
		marketPrice = market,
		dbHistorical = GetTSMPrice("DBHistorical", itemString),
		dbRecent = GetTSMPrice("DBRecent", itemString),
		regionSaleAvg = GetTSMPrice("DBRegionSaleAvg", itemString),
		referenceSource = "DBMarket",
		saleRate = saleRate,
		soldPerDay = soldPerDay,
		profit = profit,
		dealPercent = roi,
		bucket = "Resets",
		isCommodity = entry.isCommodity,
		numAuctions = entry.numAuctions,
		isReset = true,
	}
	return AH.ItemUtils.EnrichDeal(deal)
end

local function SortDeals(a, b)
	if a.dealPercent ~= b.dealPercent then
		return a.dealPercent > b.dealPercent
	end
	return a.profit > b.profit
end

local function ProcessBatch()
	if not private.running then
		return
	end
	local batchSize = 100
	local queue = private.itemQueue
	for _ = 1, batchSize do
		local index = private.processedItems + 1
		if index > private.totalItems then
			private.FinishScan()
			return
		end
		private.processedItems = index
		local evaluator = (private.mode == "resets") and EvaluateReset or EvaluateDeal
		local deal = evaluator(queue[index])
		if deal then
			local bucket = private.results[deal.bucket]
			if not bucket then
				bucket = {}
				private.results[deal.bucket] = bucket
			end
			if #bucket < AH.Config.Get("maxResultsPerBucket") then
				bucket[#bucket + 1] = deal
			end
		end
	end
	if private.onUpdate then
		private.onUpdate(private.processedItems / private.totalItems)
	end
	C_Timer.After(0, ProcessBatch)
end

function private.FinishScan()
	for _, deals in pairs(private.results) do
		table.sort(deals, SortDeals)
	end
	private.running = false
	if private.onComplete then
		private.onComplete(private.results, private.processedItems)
	end
	private.onUpdate = nil
	private.onComplete = nil
end

function Scanner.IsRunning()
	return private.running
end

function Scanner.GetResults()
	return private.results
end

function Scanner.GetMode()
	return private.mode
end

function Scanner.Start(mode, onUpdate, onComplete)
	if private.running then
		return
	end
	if not AH.AppData.EnsureReady() then
		return
	end
	if not AH.IsTSMReady() then
		AH.Print("Waiting for TradeSkillMaster... try again in a few seconds.")
		return
	end
	private.mode = (mode == "resets") and "resets" or "deals"
	private.running = true
	private.results = {}
	private.itemQueue = BuildItemQueue()
	private.totalItems = #private.itemQueue
	private.processedItems = 0
	private.onUpdate = onUpdate
	private.onComplete = onComplete
	if private.totalItems == 0 then
		AH.Print("No auction listings found in TSM data for your realm.")
		private.running = false
		return
	end
	local dataAge = AH.AppData.GetDataAge()
	if dataAge then
		AH.Print(string.format("Scanning %d listings (TSM data is %s old)...", private.totalItems, SecondsToTime(dataAge)))
	else
		AH.Print(string.format("Scanning %d listings...", private.totalItems))
	end
	C_Timer.After(0, ProcessBatch)
end

function Scanner.Stop()
	private.running = false
end
