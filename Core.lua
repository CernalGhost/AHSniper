local ADDON_NAME = ...

AHSniper = AHSniper or {}
local AH = AHSniper

AH.ADDON_NAME = ADDON_NAME
AH.version = "1.4.0"

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

local function RegisterSlashCommands()
	SLASH_AHSNIPER1 = "/ahsniper"
	SLASH_AHSNIPER2 = "/ahs"
	SlashCmdList["AHSNIPER"] = function(msg)
		local ok, err = pcall(AH.HandleSlash, msg or "")
		if not ok then
			AH.Print("Error: " .. tostring(err))
		end
	end
end

frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		AH.Config.Init()
		RegisterSlashCommands()
		print("|cff00ccffAH Sniper|r v" .. AH.version .. " loaded. Type /ahs")
	elseif event == "PLAYER_LOGIN" then
		if AH.Tooltip and AH.Tooltip.Init then
			AH.Tooltip.Init()
		end
		C_Timer.After(2, function()
			if not TSM_API then
				AH.Print("TradeSkillMaster is required but TSM_API was not found.")
			elseif not AH.AppData.HasData() then
				AH.Print("AuctionDB data not captured yet — run /reload after updating the addon.")
			end
		end)
	end
end)

function AH.HandleSlash(msg)
	msg = strtrim(msg):lower()
	if msg == "scan" or msg == "" then
		AH.UI.Show()
		AH.UI.RunScan()
	elseif msg == "resets" or msg == "reset" or msg == "flip" then
		AH.UI.Show()
		AH.UI.RunScan("resets")
	elseif msg == "config" or msg == "settings" then
		AH.UI.ShowSettings()
	elseif msg == "debug" then
		AH.AppData.PrintDebug()
	else
		print("|cff00ccffAH Sniper|r commands:")
		print("  /ahs - Open deal list and scan")
		print("  /ahs scan - Scan for deals")
		print("  /ahs resets - Hunt fast-moving items to buy low and relist at market")
		print("  /ahs config - Open settings")
		print("  /ahs debug - Show data capture status")
	end
end

function AH.Print(msg)
	print("|cff00ccffAH Sniper|r: " .. msg)
end

function AH.IsTSMReady()
	return TSM_API ~= nil
end

-- TSM custom-price lookup, nil unless TSM is loaded and the value is positive.
function AH.GetTSMPrice(source, itemString)
	if not TSM_API then
		return nil
	end
	local value = TSM_API.GetCustomPriceValue(source, itemString)
	if value and value > 0 then
		return value
	end
	return nil
end

local function AddThousandsSeparator(value)
	local formatted = tostring(value)
	while true do
		local replaced
		formatted, replaced = formatted:gsub("^(%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return formatted
end

-- Simplified money: floored gold with thousands separators (e.g. 19,999g).
-- Falls back to silver/copper only for sub-gold amounts.
function AH.FormatMoney(copper)
	copper = math.floor((copper or 0) + 0.5)
	local gold = math.floor(copper / 10000)
	if gold > 0 then
		return AddThousandsSeparator(gold) .. "g"
	end
	local silver = math.floor((copper % 10000) / 100)
	local copperRem = copper % 100
	if silver > 0 then
		return string.format("%ds %dc", silver, copperRem)
	end
	return string.format("%dc", copperRem)
end

function AH.NormalizeItemString(itemString)
	if tonumber(itemString) then
		return "i:" .. itemString
	end
	return itemString
end
