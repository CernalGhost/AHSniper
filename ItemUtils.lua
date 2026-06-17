local AH = AHSniper
AH.ItemUtils = {}

local ItemUtils = AH.ItemUtils

local PET_CAGE_ITEM_ID = 82800

local CLASS_KEYS = {
	"weapon", "armor", "container", "gem", "enhancement", "consumable",
	"glyph", "reagent", "tradegoods", "recipe", "misc", "battlepet", "mount",
}

local CLASS_ID = {
	consumable = 0,
	container = 1,
	weapon = 2,
	gem = 3,
	armor = 4,
	reagent = 5,
	tradegoods = 7,
	enhancement = 8,
	recipe = 9,
	misc = 13,
	glyph = 14,
	battlepet = 15,
}

local QUALITY_KEYS = { "poor", "common", "uncommon", "rare", "epic", "legendary", "artifact" }

local QUALITY_ID = {
	poor = 0,
	common = 1,
	uncommon = 2,
	rare = 3,
	epic = 4,
	legendary = 5,
	artifact = 6,
}

local QUALITY_RGB = {
	poor = { 0.62, 0.62, 0.62 },
	common = { 1, 1, 1 },
	uncommon = { 0.12, 1, 0 },
	rare = { 0, 0.44, 0.87 },
	epic = { 0.64, 0.21, 0.93 },
	legendary = { 1, 0.5, 0 },
	artifact = { 0.9, 0.8, 0.5 },
}

function ItemUtils.GetClassKeys()
	return CLASS_KEYS
end

function ItemUtils.GetQualityKeys()
	return QUALITY_KEYS
end

function ItemUtils.GetQualityRGB(qualityKey)
	local rgb = QUALITY_RGB[qualityKey] or QUALITY_RGB.common
	return rgb[1], rgb[2], rgb[3]
end

function ItemUtils.GetClassLabel(classKey)
	local labels = {
		consumable = "Consumables",
		container = "Containers",
		weapon = "Weapons",
		gem = "Gems",
		armor = "Armor",
		reagent = "Reagents",
		tradegoods = "Trade Goods",
		enhancement = "Item Enhancements",
		recipe = "Recipes",
		misc = "Miscellaneous",
		glyph = "Glyphs",
		battlepet = "Battle Pets",
		mount = "Mounts",
	}
	return labels[classKey] or classKey
end

function ItemUtils.IsMountItem(itemID)
	if not itemID or not C_MountJournal or not C_MountJournal.GetMountFromItem then
		return false
	end
	local mountID = C_MountJournal.GetMountFromItem(itemID)
	return mountID ~= nil and mountID > 0
end

function ItemUtils.GetQualityLabel(qualityKey)
	local labels = {
		poor = "Poor",
		common = "Common",
		uncommon = "Uncommon",
		rare = "Rare",
		epic = "Epic",
		legendary = "Legendary",
		artifact = "Artifact",
	}
	return labels[qualityKey] or qualityKey
end

ItemUtils.GetTSMPrice = AH.GetTSMPrice

function ItemUtils.ParseTSMItemString(itemString)
	local petSpeciesID = tonumber(itemString:match("^p:(%d+)"))
	if petSpeciesID then
		return PET_CAGE_ITEM_ID, 0, petSpeciesID, true
	end
	local itemID = tonumber(itemString:match("^i:(%d+)"))
	local itemLevel = tonumber(itemString:match("::i(%d+)")) or 0
	return itemID, itemLevel, nil, false
end

function ItemUtils.GetAHSearchString(deal)
	if deal.searchName and deal.searchName ~= "" then
		return deal.searchName
	end
	if deal.name and deal.name ~= deal.itemString then
		return deal.name
	end
	if deal.link then
		local bracket = deal.link:match("%[(.-)%]")
		if bracket then
			return bracket
		end
	end
	return deal.itemString
end

function ItemUtils.ResolveClassKey(classID, isPet, isMount)
	if isPet then
		return "battlepet"
	end
	if isMount then
		return "mount"
	end
	if classID then
		for classKey, id in pairs(CLASS_ID) do
			if classID == id then
				return classKey
			end
		end
	end
	return "misc"
end

function ItemUtils.ResolveQualityKey(quality)
	if quality == nil then
		return nil
	end
	for qualityKey, id in pairs(QUALITY_ID) do
		if quality == id then
			return qualityKey
		end
	end
	return nil
end

function ItemUtils.EnrichDeal(deal)
	local itemID, itemLevel, petSpeciesID, isPet = ItemUtils.ParseTSMItemString(deal.itemString)
	deal.itemID = itemID
	deal.itemLevel = itemLevel
	deal.petSpeciesID = petSpeciesID
	deal.isPet = isPet
	deal.isMount = itemID and ItemUtils.IsMountItem(itemID) or false

	if itemID and C_Item and C_Item.GetItemInfoInstant then
		local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
		deal.classID = classID
		deal.subClassID = subClassID
	end

	if deal.link and deal.link ~= deal.itemString then
		local name, _, quality = GetItemInfo(deal.link)
		if name then
			deal.searchName = name
		end
		if quality then
			deal.quality = quality
		end
	end

	if deal.quality == nil and itemID then
		if C_Item and C_Item.GetItemQualityByID then
			deal.quality = C_Item.GetItemQualityByID(itemID)
		end
		if deal.quality == nil then
			local name, _, quality = GetItemInfo(itemID)
			if name then
				deal.searchName = name
			end
			deal.quality = quality
		end
	end

	deal.classKey = ItemUtils.ResolveClassKey(deal.classID, isPet, deal.isMount)
	deal.qualityKey = ItemUtils.ResolveQualityKey(deal.quality)

	deal.marketPrice = deal.marketPrice or ItemUtils.GetTSMPrice("DBMarket", deal.itemString)
	deal.dbHistorical = deal.dbHistorical or ItemUtils.GetTSMPrice("DBHistorical", deal.itemString)
	deal.dbRecent = deal.dbRecent or ItemUtils.GetTSMPrice("DBRecent", deal.itemString)
	deal.regionSaleAvg = deal.regionSaleAvg or ItemUtils.GetTSMPrice("DBRegionSaleAvg", deal.itemString)

	return deal
end

function ItemUtils.RequestItemLoad(itemID, callback)
	if not itemID then
		callback()
		return
	end
	if Item and Item.CreateFromItemID then
		local item = Item:CreateFromItemID(itemID)
		if item:IsItemDataLoaded() then
			callback()
		else
			item:ContinueOnItemLoad(callback)
		end
		return
	end
	callback()
end

function ItemUtils.TryAuctionHouseSearch(deal)
	if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
		return false
	end
	if not C_AuctionHouse or not C_AuctionHouse.SendSearchQuery then
		return false
	end

	local itemID = deal.itemID
	local petSpeciesID = deal.petSpeciesID
	if not itemID and not petSpeciesID then
		return false
	end

	local function DoSearch()
		local itemKey
		if petSpeciesID then
			itemKey = C_AuctionHouse.MakeItemKey(PET_CAGE_ITEM_ID, 0, 0, petSpeciesID)
		else
			itemKey = C_AuctionHouse.MakeItemKey(itemID, 0, 0, nil)
		end
		local sorts = {}
		if Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price then
			sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
		end
		C_AuctionHouse.SendSearchQuery({ itemKey }, sorts, not deal.isCommodity, false)
	end

	if itemID then
		ItemUtils.RequestItemLoad(itemID, DoSearch)
	else
		DoSearch()
	end
	return true
end

function ItemUtils.AttachTooltip(frame, deal)
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", function(self)
		-- Mark that this window is supplying its own (richer) price block, so
		-- the global AH tooltip hook skips adding a duplicate set of lines.
		GameTooltip.ahSniperManual = true
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()

		if deal.link and deal.link:find("|H") then
			GameTooltip:SetHyperlink(deal.link)
		elseif deal.itemID then
			GameTooltip:SetItemByID(deal.itemID)
		end

		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("AH Sniper Prices", 0, 0.75, 1)
		GameTooltip:AddDoubleLine("Scan Buyout", AH.FormatMoney(deal.minBuyout), 1, 1, 1, 1, 1, 1)
		if deal.marketPrice then
			GameTooltip:AddDoubleLine("DB Market", AH.FormatMoney(deal.marketPrice), 1, 1, 1, 0.8, 0.8, 0.8)
		end
		if deal.dbHistorical then
			GameTooltip:AddDoubleLine("DB Historical", AH.FormatMoney(deal.dbHistorical), 1, 1, 1, 0.8, 0.8, 0.8)
		end
		if deal.dbRecent then
			GameTooltip:AddDoubleLine("DB Recent", AH.FormatMoney(deal.dbRecent), 1, 1, 1, 0.8, 0.8, 0.8)
		end
		if deal.regionSaleAvg then
			GameTooltip:AddDoubleLine("Region Sale Avg", AH.FormatMoney(deal.regionSaleAvg), 1, 1, 1, 0.8, 0.8, 0.8)
		end
		if deal.isReset then
			GameTooltip:AddDoubleLine("Relist At (Market)", AH.FormatMoney(deal.reference), 0.4, 1, 0.4, 1, 1, 1)
			GameTooltip:AddDoubleLine("Reset ROI / Profit", string.format("%.0f%%", deal.dealPercent), AH.FormatMoney(deal.profit), 0.4, 1, 0.4, 0.4, 1, 0.4)
			if deal.saleRate then
				GameTooltip:AddDoubleLine("Region Sale Rate", string.format("%.0f%%", deal.saleRate * 100), 1, 1, 1, 0.8, 0.8, 0.8)
			end
			if deal.soldPerDay then
				GameTooltip:AddDoubleLine("Sold / Day", string.format("%.1f", deal.soldPerDay), 1, 1, 1, 0.8, 0.8, 0.8)
			end
		else
			GameTooltip:AddDoubleLine("Deal Reference", AH.FormatMoney(deal.reference), 0.4, 1, 0.4, 1, 1, 1)
			GameTooltip:AddDoubleLine("Deal / Profit", string.format("%.0f%%", deal.dealPercent), AH.FormatMoney(deal.profit), 0.4, 1, 0.4, 0.4, 1, 0.4)
		end

		if deal.filteredOutlier then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Possible price outlier", 1, 0.3, 0.3)
			if deal.outlierReason then
				GameTooltip:AddLine(deal.outlierReason, 1, 0.6, 0.6)
			end
		end

		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Click Copy to get AH search text", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip.ahSniperManual = false
		GameTooltip:Hide()
	end)
end
