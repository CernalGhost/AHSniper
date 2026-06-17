-- Must run before TradeSkillMaster_AppHelper loads AppData.lua.
-- Do not add OptionalDeps on AppHelper in the .toc — that forces us to load too late.

local originalLoadData = TSM_APPHELPER_LOAD_DATA

function TSM_APPHELPER_LOAD_DATA(tag, realmOrRegion, data)
	if AHSniper and AHSniper.AppData then
		AHSniper.AppData.OnLoadData(tag, realmOrRegion, data)
	end
	if originalLoadData then
		originalLoadData(tag, realmOrRegion, data)
	end
end
