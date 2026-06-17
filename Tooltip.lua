local AH = AHSniper
AH.Tooltip = {}

local Tooltip = AH.Tooltip

local GetPrice = AH.GetTSMPrice

-- Only decorate tooltips while the Auction House window is open.
local function ShouldShow()
	return AuctionHouseFrame ~= nil and AuctionHouseFrame:IsShown()
end

local function ResolveItemID(tooltip, data)
	if data and data.id then
		return data.id
	end
	if tooltip.GetItem then
		local _, link = tooltip:GetItem()
		if link then
			return tonumber(link:match("item:(%d+)"))
		end
	end
	return nil
end

local function AddPriceLines(tooltip, itemID)
	if not itemID or not TSM_API or not ShouldShow() then
		return
	end

	-- The in-window deal list supplies its own richer block; don't double up.
	if tooltip == GameTooltip and GameTooltip.ahSniperManual then
		return
	end

	local itemString = "i:" .. itemID
	local minBuyout = AH.AppData.GetMinBuyout(itemString)
	local market = GetPrice("DBMarket", itemString)
	local historical = GetPrice("DBHistorical", itemString)
	local recent = GetPrice("DBRecent", itemString)
	local regionAvg = GetPrice("DBRegionSaleAvg", itemString)

	if not (minBuyout or market or historical or recent or regionAvg) then
		return
	end

	tooltip:AddLine(" ")
	tooltip:AddLine("AH Sniper Prices", 0, 0.75, 1)
	if minBuyout then
		tooltip:AddDoubleLine("AH Min Buyout", AH.FormatMoney(minBuyout), 1, 1, 1, 1, 1, 1)
	end
	if market then
		tooltip:AddDoubleLine("DB Market", AH.FormatMoney(market), 1, 1, 1, 0.8, 0.8, 0.8)
	end
	if historical then
		tooltip:AddDoubleLine("DB Historical", AH.FormatMoney(historical), 1, 1, 1, 0.8, 0.8, 0.8)
	end
	if recent then
		tooltip:AddDoubleLine("DB Recent", AH.FormatMoney(recent), 1, 1, 1, 0.8, 0.8, 0.8)
	end
	if regionAvg then
		tooltip:AddDoubleLine("Region Sale Avg", AH.FormatMoney(regionAvg), 1, 1, 1, 0.8, 0.8, 0.8)
	end

	-- Deal vs. the configured reference price, mirroring the main scanner.
	local refSource = AH.Config.Get("referencePrice")
	local reference = GetPrice(refSource, itemString) or historical
	if reference and minBuyout and minBuyout < reference then
		local profit = reference - minBuyout
		local dealPercent = (profit / reference) * 100
		tooltip:AddDoubleLine("Deal Reference", AH.FormatMoney(reference), 0.4, 1, 0.4, 1, 1, 1)
		tooltip:AddDoubleLine(
			"Deal / Profit",
			string.format("%.0f%%  %s", dealPercent, AH.FormatMoney(profit)),
			0.4, 1, 0.4, 0.4, 1, 0.4
		)
	end

	tooltip:Show()
end

function Tooltip.Init()
	if Tooltip._initialized then
		return
	end
	Tooltip._initialized = true

	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
		and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		-- Modern (Dragonflight+/Midnight) tooltip system.
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
			AddPriceLines(tooltip, ResolveItemID(tooltip, data))
		end)
	elseif GameTooltip.HookScript then
		-- Legacy fallback for older clients.
		GameTooltip:HookScript("OnTooltipSetItem", function(self)
			AddPriceLines(self, ResolveItemID(self, nil))
		end)
	end
end
