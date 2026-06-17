local AH = AHSniper
AH.AppData = {}

local AppData = AH.AppData

local REALM_TAGS = {
	AUCTIONDB_NON_COMMODITY_DATA = true,
	AUCTIONDB_NON_COMMODITY_HISTORICAL = true,
}

local COMMODITY_TAGS = {
	AUCTIONDB_COMMODITY_DATA = true,
}

local private = {
	realmListings = nil,
	commodityListings = nil,
	realmHistorical = nil,
	regionName = nil,
	lastDataTime = 0,
	captureLog = {},
	seenRealms = {},
}

local function SanitizeRealmName(realm)
	return (realm:gsub("\226", "'"))
end

local function GetAppDataRegion()
	local lib = LibStub("LibRealmInfo", true)
	if lib and lib.GetCurrentRegion then
		return lib:GetCurrentRegion()
	end
	local portal = GetCVar("portal")
	if portal == "public-test" then
		return "PTR"
	end
	return portal
end

local function IsCurrentRealm(realm)
	local current = SanitizeRealmName(GetRealmName())
	local target = SanitizeRealmName(realm)
	if strlower(current) == strlower(target) then
		return true
	end
	-- Classic-style connected realm entries include faction suffix.
	local faction = UnitFactionGroup("player")
	if faction then
		return strlower(current .. "-" .. faction) == strlower(target)
	end
	return false
end

local function IsCurrentRegion(region)
	return strupper(region or "") == strupper(GetAppDataRegion() or "")
end

local function UnpackBase32(val)
	if not val or val == "" then
		return nil
	end
	if #val > 6 then
		return tonumber(val:sub(-6), 32) + tonumber(val:sub(1, -7), 32) * (2 ^ 30)
	end
	return tonumber(val, 32)
end

local function ParseAppDataBlob(data)
	local metadataEndIndex, dataStartIndex = data:find(",data={")
	if not metadataEndIndex then
		return nil
	end
	local itemData = data:sub(dataStartIndex + 1, -3)
	local metadataStr = data:sub(1, metadataEndIndex - 1) .. "}"
	local metadata = assert(loadstring(metadataStr))()
	local fieldLookup = {}
	for i = 2, #metadata.fields do
		fieldLookup[metadata.fields[i]] = i - 1
	end
	local items = {}
	for itemString, otherData in itemData:gmatch('{"?([^,"]+)"?,([^}]+)}') do
		if tonumber(itemString) then
			itemString = "i:" .. itemString
		end
		items[itemString] = otherData
	end
	return {
		fieldLookup = fieldLookup,
		items = items,
		downloadTime = metadata.downloadTime,
	}
end

local function UnpackRow(parsed, itemString)
	local raw = parsed.items[itemString]
	if not raw then
		return nil
	end
	if type(raw) == "table" then
		return raw
	end
	local values = { strsplit(",", raw) }
	for i = 1, #values do
		values[i] = UnpackBase32(values[i])
	end
	parsed.items[itemString] = values
	return values
end

local function GetField(parsed, itemString, field)
	local row = UnpackRow(parsed, itemString)
	if not row then
		return nil
	end
	local index = parsed.fieldLookup[field]
	if not index then
		return nil
	end
	local value = row[index]
	if value and value > 0 then
		return value
	end
	return nil
end

function AppData.OnLoadData(tag, realmOrRegion, data)
	private.captureLog[#private.captureLog + 1] = { tag = tag, scope = realmOrRegion, bytes = #data }
	if REALM_TAGS[tag] then
		private.seenRealms[realmOrRegion] = true
	end

	if REALM_TAGS[tag] and IsCurrentRealm(realmOrRegion) then
		if tag == "AUCTIONDB_NON_COMMODITY_DATA" then
			private.realmListings = ParseAppDataBlob(data)
			if private.realmListings then
				private.lastDataTime = max(private.lastDataTime, private.realmListings.downloadTime or 0)
			end
		elseif tag == "AUCTIONDB_NON_COMMODITY_HISTORICAL" then
			private.realmHistorical = ParseAppDataBlob(data)
		end
	elseif COMMODITY_TAGS[tag] and IsCurrentRegion(realmOrRegion) then
		private.commodityListings = ParseAppDataBlob(data)
		private.regionName = realmOrRegion
		if private.commodityListings then
			private.lastDataTime = max(private.lastDataTime, private.commodityListings.downloadTime or 0)
		end
	end
end

function AppData.EnsureReady()
	if AppData.HasData() then
		return true
	end
	AH.Print("No AuctionDB data was captured at login.")
	AH.Print("Run |cff00ff00/reload|r — the addon must load before TradeSkillMaster_AppHelper.")
	AH.Print("Run |cff00ff00/ahs debug|r for details.")
	return false
end

function AppData.PrintDebug()
	local hooked = TSM_APPHELPER_LOAD_DATA ~= nil
	AH.Print("Hook installed: " .. (hooked and "yes" or "no"))
	AH.Print("Your realm: " .. SanitizeRealmName(GetRealmName()))
	AH.Print("Your region: " .. tostring(GetAppDataRegion()))
	AH.Print("Data captures this session: " .. #private.captureLog)
	if #private.captureLog == 0 then
		AH.Print("No AppData blobs captured — addon likely loaded after AppHelper.")
	else
		for i = 1, min(5, #private.captureLog) do
			local entry = private.captureLog[i]
			AH.Print(string.format("  %s / %s (%d bytes)", entry.tag, entry.scope, entry.bytes))
		end
		if #private.captureLog > 5 then
			AH.Print(string.format("  ... and %d more", #private.captureLog - 5))
		end
	end
	local realms = {}
	for realm in pairs(private.seenRealms) do
		realms[#realms + 1] = realm
	end
	if #realms > 0 then
		AH.Print("Realms in AppData: " .. table.concat(realms, ", "))
	end
	local realmCount = 0
	if private.realmListings then
		for _ in pairs(private.realmListings.items) do
			realmCount = realmCount + 1
		end
	end
	local commodityCount = 0
	if private.commodityListings then
		for _ in pairs(private.commodityListings.items) do
			commodityCount = commodityCount + 1
		end
	end
	AH.Print(string.format(
		"Stored: realm=%d items, commodities=%d items, historical=%s",
		realmCount,
		commodityCount,
		private.realmHistorical and "yes" or "no"
	))
end

function AppData.HasData()
	return private.realmListings ~= nil or private.commodityListings ~= nil
end

function AppData.GetDataAge()
	if private.lastDataTime <= 0 then
		return nil
	end
	return time() - private.lastDataTime
end

function AppData.GetListedItemCount()
	local count = 0
	if private.realmListings then
		for _ in pairs(private.realmListings.items) do
			count = count + 1
		end
	end
	if private.commodityListings then
		for _ in pairs(private.commodityListings.items) do
			count = count + 1
		end
	end
	return count
end

function AppData.IterateListings(callback)
	if private.realmListings then
		local parsed = private.realmListings
		for itemString in pairs(parsed.items) do
			local minBuyout = GetField(parsed, itemString, "minBuyout")
			if minBuyout then
				local numAuctions = GetField(parsed, itemString, "numAuctions") or 0
				callback(AH.NormalizeItemString(itemString), minBuyout, false, numAuctions)
			end
		end
	end
	if private.commodityListings then
		local parsed = private.commodityListings
		for itemString in pairs(parsed.items) do
			local minBuyout = GetField(parsed, itemString, "minBuyout")
			if minBuyout then
				local numAuctions = GetField(parsed, itemString, "numAuctions") or 0
				callback(AH.NormalizeItemString(itemString), minBuyout, true, numAuctions)
			end
		end
	end
end

-- Returns the captured AuctionDB min buyout for an item, plus whether it came
-- from the region commodity table. Used by the global tooltip hook.
function AppData.GetMinBuyout(itemString)
	itemString = AH.NormalizeItemString(itemString)
	if private.realmListings then
		local price = GetField(private.realmListings, itemString, "minBuyout")
		if price then
			return price, false
		end
	end
	if private.commodityListings then
		local price = GetField(private.commodityListings, itemString, "minBuyout")
		if price then
			return price, true
		end
	end
	return nil
end

function AppData.GetHistoricalPrice(itemString)
	itemString = AH.NormalizeItemString(itemString)
	if private.realmHistorical then
		local price = GetField(private.realmHistorical, itemString, "historical")
		if price then
			return price
		end
	end
	if private.realmListings then
		local price = GetField(private.realmListings, itemString, "marketValueRecent")
		if price then
			return price
		end
	end
	return nil
end
