local AH = AHSniper
AH.UI = {}

local UI = AH.UI

local SIDEBAR_WIDTH = 128
local FRAME_WIDTH = 760
local FRAME_HEIGHT = 660
local ROW_HEIGHT = 20
local TABLE_LEFT = SIDEBAR_WIDTH + 24
local TABLE_WIDTH = FRAME_WIDTH - TABLE_LEFT - 36

local COLUMN_DEFS = {
	{ key = "name", label = "Item", width = 175, align = "LEFT" },
	{ key = "minBuyout", label = "Buyout", width = 72, align = "RIGHT" },
	{ key = "marketPrice", label = "Market", width = 72, align = "RIGHT" },
	{ key = "reference", label = "Ref", width = 72, align = "RIGHT" },
	{ key = "dealPercent", label = "Deal%", width = 40, align = "RIGHT" },
	{ key = "profit", label = "Profit", width = 72, align = "RIGHT" },
	{ key = "numAuctions", label = "Qty", width = 26, align = "RIGHT" },
	{ key = "_copy", label = "Copy", width = 36, align = "CENTER" },
}

local private = {
	mainFrame = nil,
	settingsFrame = nil,
	copyFrame = nil,
	scrollFrame = nil,
	scrollChild = nil,
	statusText = nil,
	scanButton = nil,
	contentFrames = {},
	headerButtons = {},
	columns = {},
	filterDropDown = nil,
	filterPanelOpen = false,
	listTop = -88,
}

local function BuildColumnLayout()
	local cols = {}
	local x = 0
	for i = 1, #COLUMN_DEFS do
		local def = COLUMN_DEFS[i]
		cols[i] = {
			key = def.key,
			label = def.label,
			left = x,
			width = def.width,
			align = def.align,
			right = x + def.width,
		}
		x = x + def.width
	end
	private.columns = cols
	return cols
end

local function CreateBackdrop(frame)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
end

local function CreateTitleBar(parent, title)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	text:SetPoint("TOP", 0, -16)
	text:SetText(title)
	return text
end

local function CreateCloseButton(parent, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
	button:SetPoint("TOPRIGHT", -6, -6)
	button:SetScript("OnClick", onClick)
	return button
end

local function PlaceText(fs, col, y)
	local parent = fs:GetParent()
	fs:SetWidth(col.width - 4)
	if col.align == "RIGHT" then
		fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", col.right - 2, y)
		fs:SetJustifyH("RIGHT")
	elseif col.align == "CENTER" then
		fs:SetPoint("TOP", parent, "TOPLEFT", col.left + col.width / 2, y)
		fs:SetJustifyH("CENTER")
	else
		fs:SetPoint("TOPLEFT", parent, "TOPLEFT", col.left + 2, y)
		fs:SetJustifyH("LEFT")
	end
end

local function PlaceHeader(btn, col)
	local parent = btn:GetParent()
	btn:SetSize(col.width - 4, 16)
	if col.align == "RIGHT" then
		btn:SetPoint("TOPRIGHT", parent, "TOPLEFT", col.right - 2, -1)
	elseif col.align == "CENTER" then
		btn:SetPoint("TOP", parent, "TOPLEFT", col.left + col.width / 2, -1)
		btn:SetSize(44, 16)
	else
		btn:SetPoint("TOPLEFT", parent, "TOPLEFT", col.left + 2, -1)
	end
end

local function CreateHeaderButton(parent, col)
	if col.key == "_copy" then
		local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("TOPLEFT", parent, "TOPLEFT", col.left + 8, -2)
		label:SetText("Copy")
		return label
	end

	local btn = CreateFrame("Button", nil, parent)
	btn:SetNormalFontObject("GameFontHighlightSmall")
	btn.sortKey = col.key
	PlaceHeader(btn, col)

	local function UpdateArrow()
		local active = AH.Config.Get("sortColumn") == col.key
		local asc = AH.Config.Get("sortAscending")
		local suffix = active and (asc and " ^" or " v") or ""
		btn:SetText(col.label .. suffix)
	end

	btn.UpdateArrow = UpdateArrow
	btn:SetScript("OnClick", function()
		if AH.Config.Get("sortColumn") == col.key then
			AH.Config.Set("sortAscending", not AH.Config.Get("sortAscending"))
		else
			AH.Config.Set("sortColumn", col.key)
			AH.Config.Set("sortAscending", col.key == "name")
		end
		for _, header in ipairs(private.headerButtons) do
			if header.UpdateArrow then
				header.UpdateArrow()
			end
		end
		UI.RebuildResults()
	end)
	UpdateArrow()
	private.headerButtons[#private.headerButtons + 1] = btn
	return btn
end

function UI.ShowCopyDialog(deal)
	UI.CreateMainFrame()
	if not private.copyFrame then
		local frame = CreateFrame("Frame", "AHSniperCopyFrame", UIParent, "BackdropTemplate")
		frame:SetSize(420, 200)
		frame:SetPoint("CENTER", 0, 80)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		CreateBackdrop(frame)
		CreateTitleBar(frame, "Copy AH Search Text")
		CreateCloseButton(frame, function()
			frame:Hide()
		end)

		local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		hint:SetPoint("TOP", 0, -42)
		hint:SetWidth(380)
		hint:SetText("Paste this into the Auction House search box (Ctrl+C)")

		local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		editBox:SetAutoFocus(true)
		editBox:SetSize(360, 24)
		editBox:SetPoint("TOP", 0, -72)
		editBox:SetScript("OnEscapePressed", function()
			frame:Hide()
		end)
		frame.editBox = editBox

		local tryBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		tryBtn:SetSize(140, 24)
		tryBtn:SetPoint("BOTTOMLEFT", 24, 20)
		tryBtn:SetText("Try AH Search")
		tryBtn:SetScript("OnClick", function()
			if frame.deal and not AH.ItemUtils.TryAuctionHouseSearch(frame.deal) then
				AH.Print("Open the Auction House first, or paste the text manually.")
			end
		end)

		local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		closeBtn:SetSize(80, 24)
		closeBtn:SetPoint("BOTTOMRIGHT", -24, 20)
		closeBtn:SetText("Close")
		closeBtn:SetScript("OnClick", function()
			frame:Hide()
		end)

		private.copyFrame = frame
	end

	local searchText = AH.ItemUtils.GetAHSearchString(deal)
	private.copyFrame.deal = deal
	private.copyFrame.editBox:SetText(searchText)
	private.copyFrame.editBox:HighlightText()
	private.copyFrame:Show()
	private.copyFrame.editBox:SetFocus()
end

local function CreateItemRow(parent, deal, yOffset)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(TABLE_WIDTH, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, yOffset)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	row:GetHighlightTexture():SetAlpha(0.2)

	if deal.filteredOutlier then
		local tint = row:CreateTexture(nil, "BACKGROUND")
		tint:SetAllPoints()
		tint:SetColorTexture(0.35, 0.12, 0.12, 0.3)
	end

	local cols = private.columns

	local linkText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	PlaceText(linkText, cols[1], -3)
	linkText:SetWordWrap(false)
	linkText:SetText(deal.link)

	local buyoutText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	PlaceText(buyoutText, cols[2], -3)
	buyoutText:SetText(AH.FormatMoney(deal.minBuyout))

	local marketText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	PlaceText(marketText, cols[3], -3)
	marketText:SetText(deal.marketPrice and AH.FormatMoney(deal.marketPrice) or "-")

	local refText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	PlaceText(refText, cols[4], -3)
	refText:SetText(AH.FormatMoney(deal.reference))

	local dealText = row:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
	PlaceText(dealText, cols[5], -3)
	dealText:SetText(string.format("%.0f%%", deal.dealPercent))

	local profitText = row:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
	PlaceText(profitText, cols[6], -3)
	profitText:SetText(AH.FormatMoney(deal.profit))

	local qtyText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	PlaceText(qtyText, cols[7], -3)
	qtyText:SetText(tostring(deal.numAuctions or 0))

	local copyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	copyBtn:SetSize(40, 16)
	copyBtn:SetPoint("TOPLEFT", cols[8].left + 2, -2)
	copyBtn:SetText("Copy")
	copyBtn:SetScript("OnClick", function()
		UI.ShowCopyDialog(deal)
	end)

	AH.ItemUtils.AttachTooltip(row, deal)
	row:SetScript("OnClick", function()
		UI.ShowCopyDialog(deal)
	end)

	return row
end

local function CreateSectionHeader(parent, text, yOffset, count)
	local header = CreateFrame("Frame", nil, parent)
	header:SetSize(TABLE_WIDTH, 20)
	header:SetPoint("TOPLEFT", 0, yOffset)

	local bg = header:CreateTexture(nil, "BACKGROUND")
	bg:SetColorTexture(0.12, 0.22, 0.32, 0.75)
	bg:SetAllPoints()

	local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("LEFT", 6, 0)
	label:SetText(string.format("%s (%d)", text, count))
	return header, 22
end

local function ClearScrollList()
	if not private.scrollChild then
		return
	end
	for i = #private.contentFrames, 1, -1 do
		local child = private.contentFrames[i]
		if child then
			child:Hide()
			child:SetParent(nil)
		end
	end
	wipe(private.contentFrames)
	private.scrollChild:SetHeight(1)
	private.scrollFrame:SetVerticalScroll(0)
end

function UI.RebuildResults()
	if not private.scrollFrame then
		return
	end
	ClearScrollList()

	local visible = AH.Filters.CollectVisibleDeals(AH.Scanner.GetResults())
	local yOffset = 0
	local totalDeals = #visible
	local isReset = AH.Config.Get("scanMode") == "resets"

	if AH.Config.Get("groupByPercent") and not isReset then
		local grouped = AH.Filters.GroupByBucket(visible)
		for _, bucketLabel in ipairs(grouped._order) do
			local deals = grouped[bucketLabel]
			if deals and #deals > 0 then
				local header, h = CreateSectionHeader(private.scrollChild, bucketLabel, yOffset, #deals)
				private.contentFrames[#private.contentFrames + 1] = header
				yOffset = yOffset - h
				for i = 1, #deals do
					private.contentFrames[#private.contentFrames + 1] = CreateItemRow(private.scrollChild, deals[i], yOffset)
					yOffset = yOffset - ROW_HEIGHT
				end
				yOffset = yOffset - 4
			end
		end
	else
		for i = 1, #visible do
			private.contentFrames[#private.contentFrames + 1] = CreateItemRow(private.scrollChild, visible[i], yOffset)
			yOffset = yOffset - ROW_HEIGHT
		end
	end

	private.scrollChild:SetHeight(max(1, -yOffset + 16))
	if private.scrollFrame.UpdateScrollChildRect then
		private.scrollFrame:UpdateScrollChildRect()
	end
	if private.statusText then
		if totalDeals > 0 and isReset then
			private.statusText:SetText(string.format(
				"%d resets | buy low, relist at market | sale rate \226\137\165 %.0f%% | armor %s",
				totalDeals,
				(AH.Config.Get("resetMinSaleRate") or 0) * 100,
				AH.Config.Get("resetIgnoreArmor") and "ignored" or "included"
			))
		elseif totalDeals > 0 then
			private.statusText:SetText(string.format(
				"%d deals | Market=DBMarket | Ref=%s | outliers %s",
				totalDeals,
				AH.Config.Get("referencePrice"),
				AH.Config.Get("hideOutliers") and "hidden" or "shown"
			))
		elseif isReset then
			private.statusText:SetText("No reset flips match filters.")
		else
			private.statusText:SetText("No deals match filters.")
		end
	end
end

local function ToggleFilterPanel()
	private.filterPanelOpen = not private.filterPanelOpen
	if private.filterPanel then
		private.filterPanel:SetShown(private.filterPanelOpen)
	end
end

local function BuildFilterDropdown(parent)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(70, 22)
	btn:SetPoint("TOPLEFT", TABLE_LEFT, -56)
	btn:SetText("Filter")
	btn:SetScript("OnClick", ToggleFilterPanel)

	local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	panel:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
	panel:SetSize(220, 280)
	panel:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	panel:Hide()

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText("Rarity")

	local y = -30
	for _, qualityKey in ipairs(AH.ItemUtils.GetQualityKeys()) do
		if qualityKey == "poor" then
			-- Grey/junk is always hidden; skip the toggle.
		else
		local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
		cb:SetSize(22, 22)
		cb:SetPoint("TOPLEFT", 10, y)
		cb:SetChecked(AH.Filters.IsQualityEnabled(qualityKey))

		local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
		label:SetText(AH.ItemUtils.GetQualityLabel(qualityKey))
		label:SetTextColor(AH.ItemUtils.GetQualityRGB(qualityKey))

		cb:SetScript("OnClick", function(self)
			AH.Config.Get("qualityFilters")[qualityKey] = self:GetChecked()
			UI.RebuildResults()
		end)
		y = y - 24
		end
	end

	local junkNote = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	junkNote:SetPoint("TOPLEFT", 34, y + 4)
	junkNote:SetText("Grey junk always hidden")
	y = y - 18

	local typeTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	typeTitle:SetPoint("TOPLEFT", 12, y)
	typeTitle:SetText("Special")
	y = y - 22

	local mountsCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	mountsCb:SetSize(22, 22)
	mountsCb:SetPoint("TOPLEFT", 10, y)
	mountsCb:SetChecked(AH.Config.Get("typeFilters").mountsOnly)
	local mountsLabel = mountsCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	mountsLabel:SetPoint("LEFT", mountsCb, "RIGHT", 2, 0)
	mountsLabel:SetText("Mounts only")
	mountsCb:SetScript("OnClick", function(self)
		AH.Config.Get("typeFilters").mountsOnly = self:GetChecked()
		UI.RebuildResults()
	end)
	y = y - 24

	local highValueCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	highValueCb:SetSize(22, 22)
	highValueCb:SetPoint("TOPLEFT", 10, y)
	highValueCb:SetChecked(AH.Config.Get("typeFilters").highValueOnly)
	local highValueLabel = highValueCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	highValueLabel:SetPoint("LEFT", highValueCb, "RIGHT", 2, 0)
	highValueLabel:SetText(string.format("High value (≥%s)", AH.FormatMoney(AH.Config.Get("highValueMinCopper"))))
	highValueCb:SetScript("OnClick", function(self)
		AH.Config.Get("typeFilters").highValueOnly = self:GetChecked()
		UI.RebuildResults()
	end)
	y = y - 24

	local outlierCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	outlierCb:SetSize(22, 22)
	outlierCb:SetPoint("TOPLEFT", 10, y)
	outlierCb:SetChecked(AH.Config.Get("hideOutliers"))
	local outlierLabel = outlierCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	outlierLabel:SetPoint("LEFT", outlierCb, "RIGHT", 2, 0)
	outlierLabel:SetText("Hide outliers")
	outlierCb:SetScript("OnClick", function(self)
		AH.Config.Set("hideOutliers", self:GetChecked())
		UI.RebuildResults()
	end)

	local groupCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	groupCb:SetSize(22, 22)
	groupCb:SetPoint("LEFT", btn, "RIGHT", 8, 0)
	groupCb:SetChecked(AH.Config.Get("groupByPercent"))
	local groupLabel = groupCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	groupLabel:SetPoint("LEFT", groupCb, "RIGHT", 2, 0)
	groupLabel:SetText("Group by %")
	groupCb:SetScript("OnClick", function(self)
		AH.Config.Set("groupByPercent", self:GetChecked())
		UI.RebuildResults()
	end)

	private.filterPanel = panel
	private.filterDropDown = btn
end

local function BuildCategorySidebar(parent)
	local sidebar = CreateFrame("Frame", nil, parent)
	sidebar:SetPoint("TOPLEFT", 18, private.listTop + 18)
	sidebar:SetPoint("BOTTOMLEFT", 18, 18)
	sidebar:SetWidth(SIDEBAR_WIDTH)

	local title = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 0, 0)
	title:SetText("Categories")

	local scroll = CreateFrame("ScrollFrame", nil, sidebar, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -18)
	scroll:SetPoint("BOTTOMRIGHT", -22, 0)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetWidth(SIDEBAR_WIDTH - 24)
	scroll:SetScrollChild(child)

	local y = 0
	for _, classKey in ipairs(AH.ItemUtils.GetClassKeys()) do
		local cb = CreateFrame("CheckButton", nil, child, "UICheckButtonTemplate")
		cb:SetSize(20, 20)
		cb:SetPoint("TOPLEFT", 0, y)
		cb:SetChecked(AH.Filters.IsClassEnabled(classKey))

		local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", cb, "RIGHT", 0, 0)
		label:SetWidth(SIDEBAR_WIDTH - 44)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		label:SetText(AH.ItemUtils.GetClassLabel(classKey))

		cb:SetScript("OnClick", function(self)
			AH.Config.Get("classFilters")[classKey] = self:GetChecked()
			UI.RebuildResults()
		end)
		y = y - 22
	end
	child:SetHeight(-y + 8)

	local divider = parent:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(0.4, 0.4, 0.4, 0.5)
	divider:SetWidth(1)
	divider:SetPoint("TOPLEFT", TABLE_LEFT - 8, private.listTop + 16)
	divider:SetPoint("BOTTOMLEFT", TABLE_LEFT - 8, 18)
end

local function BuildColumnHeader(parent)
	local header = CreateFrame("Frame", nil, parent)
	header:SetPoint("TOPLEFT", TABLE_LEFT, private.listTop + 18)
	header:SetSize(TABLE_WIDTH, 18)

	local line = header:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(0.45, 0.45, 0.45, 0.55)
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", 0, -2)
	line:SetPoint("BOTTOMRIGHT", 0, -2)

	wipe(private.headerButtons)
	for i = 1, #private.columns do
		CreateHeaderButton(header, private.columns[i])
	end
	return header
end

function UI.CreateMainFrame()
	if private.mainFrame then
		return private.mainFrame
	end

	BuildColumnLayout()

	local frame = CreateFrame("Frame", "AHSniperMainFrame", UIParent, "BackdropTemplate")
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetFrameStrata("HIGH")
	frame:Hide()
	CreateBackdrop(frame)

	CreateTitleBar(frame, "|cff00ccffAH Sniper|r - Deal Finder")
	CreateCloseButton(frame, function()
		frame:Hide()
	end)

	local status = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	status:SetPoint("TOPLEFT", TABLE_LEFT, -40)
	status:SetWidth(FRAME_WIDTH - TABLE_LEFT - 40)
	status:SetJustifyH("LEFT")
	status:SetText("Market = TSM DBMarket. Ref = price used for deal %. Click Copy to search AH.")
	private.statusText = status

	local scanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	scanBtn:SetSize(70, 24)
	scanBtn:SetPoint("TOPRIGHT", -48, -12)
	scanBtn:SetText("Scan")
	scanBtn:SetScript("OnClick", function()
		UI.RunScan()
	end)
	private.scanButton = scanBtn

	local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	resetBtn:SetSize(70, 24)
	resetBtn:SetPoint("RIGHT", scanBtn, "LEFT", -4, 0)
	resetBtn:SetText("Resets")
	resetBtn:SetScript("OnClick", function()
		UI.RunScan("resets")
	end)
	private.resetButton = resetBtn

	local settingsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	settingsBtn:SetSize(70, 24)
	settingsBtn:SetPoint("RIGHT", resetBtn, "LEFT", -4, 0)
	settingsBtn:SetText("Settings")
	settingsBtn:SetScript("OnClick", function()
		UI.ShowSettings()
	end)

	BuildFilterDropdown(frame)
	BuildCategorySidebar(frame)
	BuildColumnHeader(frame)

	local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", TABLE_LEFT, private.listTop)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 16)
	private.scrollFrame = scrollFrame

	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(TABLE_WIDTH, 1)
	scrollFrame:SetScrollChild(scrollChild)
	private.scrollChild = scrollChild

	-- Re-anchor the scrollbar into the reserved right-hand gutter so it no
	-- longer floats over the title bar / content. Works for both the modern
	-- WowScrollBar (scrollFrame.ScrollBar, no arrow buttons) and the legacy
	-- template (with ScrollUp/ScrollDownButton that need vertical padding).
	local scrollBar = scrollFrame.ScrollBar
	if scrollBar then
		local hasArrows = scrollBar.ScrollUpButton ~= nil
		local pad = hasArrows and 18 or 0
		scrollBar:ClearAllPoints()
		scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 6, -pad)
		scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 6, pad)
		if scrollBar.ScrollUpButton then
			scrollBar.ScrollUpButton:ClearAllPoints()
			scrollBar.ScrollUpButton:SetPoint("BOTTOM", scrollBar, "TOP", 0, 2)
		end
		if scrollBar.ScrollDownButton then
			scrollBar.ScrollDownButton:ClearAllPoints()
			scrollBar.ScrollDownButton:SetPoint("TOP", scrollBar, "BOTTOM", 0, -2)
		end
	end

	private.mainFrame = frame
	return frame
end

function UI.ShowSettings()
	if not private.settingsFrame then
		local frame = CreateFrame("Frame", "AHSniperSettingsFrame", UIParent, "BackdropTemplate")
		frame:SetSize(420, 470)
		frame:SetPoint("CENTER", 300, 0)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
		frame:SetFrameStrata("DIALOG")
		CreateBackdrop(frame)
		CreateTitleBar(frame, "AH Sniper Settings")
		CreateCloseButton(frame, function()
			frame:Hide()
		end)

		local y = -50
		local function AddSlider(label, key, minVal, maxVal, step, formatFn)
			local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			text:SetPoint("TOPLEFT", 20, y)
			text:SetWidth(380)
			text:SetJustifyH("LEFT")

			local slider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
			slider:SetPoint("TOPLEFT", 20, y - 18)
			slider:SetWidth(360)
			slider:SetMinMaxValues(minVal, maxVal)
			slider:SetValueStep(step)
			slider:SetObeyStepOnDrag(true)
			slider:SetValue(AH.Config.Get(key))
			slider.Low:SetText(tostring(minVal))
			slider.High:SetText(tostring(maxVal))

			local function UpdateText()
				text:SetText(label .. ": " .. formatFn(slider:GetValue()))
			end
			UpdateText()
			slider:SetScript("OnValueChanged", function(_, value)
				AH.Config.Set(key, value)
				UpdateText()
			end)
			y = y - 50
		end

		AddSlider("Minimum deal %", "minDealPercent", 5, 80, 5, function(v)
			return string.format("%.0f%%", v)
		end)
		AddSlider("Minimum profit", "minProfitCopper", 0, 50000, 100, function(v)
			return AH.FormatMoney(v)
		end)
		AddSlider("Minimum market price", "minReferenceCopper", 0, 100000, 500, function(v)
			return AH.FormatMoney(v)
		end)
		AddSlider("Max deal % (outlier cap)", "outlierMaxDealPercent", 50, 99, 1, function(v)
			return string.format("%.0f%%", v)
		end)
		AddSlider("Max ref/median ratio", "outlierMaxRefToMedianRatio", 1.5, 5, 0.1, function(v)
			return string.format("%.1fx", v)
		end)
		AddSlider("Min auctions (liquidity)", "outlierMinNumAuctions", 1, 10, 1, function(v)
			return tostring(v)
		end)
		AddSlider("High value threshold", "highValueMinCopper", 10000, 5000000, 10000, function(v)
			return AH.FormatMoney(v)
		end)

		local refLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		refLabel:SetPoint("TOPLEFT", 20, y)
		refLabel:SetText("Deal reference price (Ref column):")

		local refDropdown = CreateFrame("Frame", "AHSniperRefDropdown", frame, "UIDropDownMenuTemplate")
		refDropdown:SetPoint("TOPLEFT", 10, y - 14)

		local function RefDropdown_OnClick(self)
			AH.Config.Set("referencePrice", self.value)
			UIDropDownMenu_SetText(refDropdown, self.text)
		end

		local function RefDropdown_Initialize()
			for _, opt in ipairs(AH.Config.GetReferenceOptions()) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = opt.label
				info.value = opt.key
				info.func = RefDropdown_OnClick
				info.checked = (opt.key == AH.Config.Get("referencePrice"))
				UIDropDownMenu_AddButton(info)
			end
		end

		UIDropDownMenu_Initialize(refDropdown, RefDropdown_Initialize)
		for _, opt in ipairs(AH.Config.GetReferenceOptions()) do
			if opt.key == AH.Config.Get("referencePrice") then
				UIDropDownMenu_SetText(refDropdown, opt.label)
				break
			end
		end

		private.settingsFrame = frame
	end
	private.settingsFrame:Show()
end

function UI.RunScan(mode)
	if AH.Scanner.IsRunning() then
		return
	end
	mode = (mode == "resets") and "resets" or "deals"
	AH.Config.Set("scanMode", mode)
	UI.CreateMainFrame()
	local status = private.statusText
	local scanBtn = private.scanButton
	local resetBtn = private.resetButton
	local label = (mode == "resets") and "Hunting resets" or "Scanning"
	if status then
		status:SetText(label .. "...")
	end
	if scanBtn then
		scanBtn:Disable()
	end
	if resetBtn then
		resetBtn:Disable()
	end
	AH.Scanner.Start(
		mode,
		function(progress)
			if status then
				status:SetText(string.format("%s... %.0f%%", label, progress * 100))
			end
		end,
		function()
			if scanBtn then
				scanBtn:Enable()
			end
			if resetBtn then
				resetBtn:Enable()
			end
			UI.RebuildResults()
		end
	)
end

function UI.Show()
	UI.CreateMainFrame()
	private.mainFrame:Show()
end
