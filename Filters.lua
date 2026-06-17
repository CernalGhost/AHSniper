local AH = AHSniper
AH.Filters = {}

local Filters = AH.Filters

local SORT_COLUMNS = {
	{ key = "name", label = "Item" },
	{ key = "minBuyout", label = "Buyout" },
	{ key = "marketPrice", label = "Market" },
	{ key = "reference", label = "Ref" },
	{ key = "dealPercent", label = "Deal%" },
	{ key = "profit", label = "Profit" },
	{ key = "numAuctions", label = "Qty" },
}

function Filters.GetSortColumns()
	return SORT_COLUMNS
end

function Filters.IsQualityEnabled(qualityKey)
	if not qualityKey then
		return true
	end
	local filters = AH.Config.Get("qualityFilters")
	if not filters then
		return true
	end
	return filters[qualityKey] ~= false
end

function Filters.IsClassEnabled(classKey)
	if not classKey then
		classKey = "misc"
	end
	local filters = AH.Config.Get("classFilters")
	if not filters then
		return true
	end
	return filters[classKey] ~= false
end

function Filters.AnyClassEnabled()
	local filters = AH.Config.Get("classFilters")
	if not filters then
		return true
	end
	for _, classKey in ipairs(AH.ItemUtils.GetClassKeys()) do
		if filters[classKey] ~= false then
			return true
		end
	end
	return false
end

function Filters.PassesUI(deal)
	-- Deals always arrive enriched (EnrichDeal runs in the Scanner), so the
	-- metadata fields below are already populated.
	if deal.quality == 0 or deal.qualityKey == "poor" then
		return false
	end

	-- Fallback when item quality isn't cached yet: poor items always carry the
	-- grey hex color (ff9d9d9d) in their link, so hide those too.
	if deal.link and deal.link:find("ff9d9d9d") then
		return false
	end

	if deal.filteredOutlier and AH.Config.Get("hideOutliers") then
		return false
	end

	local typeFilters = AH.Config.Get("typeFilters")
	if typeFilters then
		if typeFilters.mountsOnly and not deal.isMount then
			return false
		end
		if typeFilters.highValueOnly then
			local minCopper = AH.Config.Get("highValueMinCopper") or 0
			if (deal.reference or 0) < minCopper then
				return false
			end
		end
	end

	if not Filters.AnyClassEnabled() then
		return false
	end

	if deal.classKey and not Filters.IsClassEnabled(deal.classKey) then
		return false
	end

	if deal.qualityKey and not Filters.IsQualityEnabled(deal.qualityKey) then
		return false
	end

	return true
end

function Filters.SortDeals(deals, sortKey, ascending)
	table.sort(deals, function(a, b)
		local av = a[sortKey]
		local bv = b[sortKey]
		if sortKey == "name" then
			av = a.name or ""
			bv = b.name or ""
			if ascending then
				return av < bv
			end
			return av > bv
		end
		av = av or 0
		bv = bv or 0
		if av ~= bv then
			if ascending then
				return av < bv
			end
			return av > bv
		end
		return (a.profit or 0) > (b.profit or 0)
	end)
end

function Filters.CollectVisibleDeals(results)
	local all = {}
	for bucket, deals in pairs(results) do
		if type(deals) == "table" and bucket ~= "_order" then
			for i = 1, #deals do
				if Filters.PassesUI(deals[i]) then
					all[#all + 1] = deals[i]
				end
			end
		end
	end
	local sortKey = AH.Config.Get("sortColumn") or "dealPercent"
	local ascending = AH.Config.Get("sortAscending") == true
	Filters.SortDeals(all, sortKey, ascending)
	return all
end

function Filters.GroupByBucket(deals)
	local grouped = {}
	local order = {}
	local buckets = AH.Config.Get("buckets")
	for i = 1, #buckets do
		grouped[buckets[i].label] = {}
		order[#order + 1] = buckets[i].label
	end
	grouped._order = order
	for i = 1, #deals do
		local deal = deals[i]
		local bucket = deal.bucket
		if grouped[bucket] then
			grouped[bucket][#grouped[bucket] + 1] = deal
		end
	end
	local sortKey = AH.Config.Get("sortColumn") or "dealPercent"
	local ascending = AH.Config.Get("sortAscending") == true
	for i = 1, #order do
		Filters.SortDeals(grouped[order[i]], sortKey, ascending)
	end
	return grouped
end
