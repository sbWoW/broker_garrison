local ADDON_NAME, private = ...

local LibStub = _G.LibStub

local BrokerGarrison = LibStub('AceAddon-3.0'):NewAddon(ADDON_NAME, 'AceConsole-3.0', "AceHook-3.0", 'AceEvent-3.0', 'AceTimer-3.0', "LibSink-2.0")
local Garrison = BrokerGarrison

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local L = LibStub:GetLibrary( "AceLocale-3.0" ):GetLocale(ADDON_NAME)
local LibQTip = LibStub('LibQTip-1.0')
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local Toast = LibStub("LibToast-1.0")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")

-- Local variables
local _G = getfenv(0)
local math = _G.math
local string = _G.string
local table = _G.table
local print = _G.print
local pairs = _G.pairs
local ipairs = _G.ipairs
local tonumber = _G.tonumber
local strupper = _G.strupper
local BreakUpLargeNumbers = _G.BreakUpLargeNumbers
local C_Garrison = _G.C_Garrison
local select = _G.select
local GetCurrencyInfo = _G.GetCurrencyInfo
local time = _G.time
local COLOR_TABLE = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
local InterfaceOptionsFrameAddOns = _G.InterfaceOptionsFrameAddOns
local OptionsListButtonToggle_OnClick = _G.OptionsListButtonToggle_OnClick
local IsAddOnLoaded = _G.IsAddOnLoaded 
local UIParentLoadAddOn = _G.UIParentLoadAddOn
local GarrisonLandingPage = _G.GarrisonLandingPage
local ShowUIPanel = _G.ShowUIPanel
local HideUIPanel = _G.HideUIPanel
local CreateFont = _G.CreateFont
local toolTipRef

local garrisonDb
local configDb
local globalDb
local DEFAULT_FONT

-- Constants
local addonInitialized = false
local CONFIG_VERSION = 1
local DEBUG = true
local fonts = {}
local timers = {}
local colors = {
	green = {r=0, g=1, b=0, a=1},
	white = {r=1, g=1, b=1, a=1},
	lightGray = {r=0.25, g=0.25, b=0.25, a=1},
	darkGray = {r=0.1, g=0.1, b=0.1, a=1},
}
local GARRISON_CURRENCY = 824;
local ICON_CURRENCY = string.format("\124TInterface\\Icons\\Inv_Garrison_Resource:%d:%d:1:0\124t", 16, 16)
local ICON_MINUS = [[|TInterface\MINIMAP\UI-Minimap-ZoomOutButton-Up:16:16|t]]
local ICON_MINUS_DOWN = [[|TInterface\MINIMAP\UI-Minimap-ZoomOutButton-Down:16:16|t]]
local ICON_PLUS = [[|TInterface\MINIMAP\UI-Minimap-ZoomInButton-Up:16:16|t]]
local ICON_PLUS_DOWN = [[|TInterface\MINIMAP\UI-Minimap-ZoomInButton-Down:16:16|t]]
local SECONDS_PER_DAY = 24 * 60 * 60
local SECONDS_PER_HOUR = 60 * 60
local TOAST_MISSION_COMPLETE = "BrokerGarrisonMissionComplete"

local DB_DEFAULTS = {
	profile = {
		ldbConfig = {
			showCurrency = true,
			showProgress = true,
			showComplete = true,
		},
		notification = {
			enabled = true,
			repeatOnLoad = false,
			sink = {},
			toastEnabled = true,
			toastPersistent = true,
		},			
		tooltip = {
			scale = 1,
			autoHideDelay = 0.25,
		},		
		configVersion = CONFIG_VERSION,
	},
	global = {
		data = {}
	}
}

-- Player info
local charInfo = {
	playerName = UnitName("player"),
	playerClass = UnitClass("player"),	
	playerFaction = UnitFactionGroup("player"),
	realmName = GetRealmName(),
}	


-- Cache
local unitColor = {}

-- LDB init
Garrison.dataobj = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, 
  { type = "data source", 
   label = L["Broker Garrison"], 
	icon = "Interface\\Icons\\Inv_Garrison_Resource",
	text = "Garrison: Missions",
   })

local ldb_object = Garrison.dataobj

-- Helper Functions
local function tableSize(T) 
	local count = 0
	if T then
		for _ in pairs(T) do count = count + 1 end
	end
	return count
end

local function round(num, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

local function debugPrint(text) 
	if(DEBUG) then
		print(("%s: %s"):format(ADDON_NAME, text))
	end
end

local function pairsByKeys(t,f)
	local a = {}
		for n in pairs(t) do table.insert(a, n) end
		table.sort(a, f)
		local i = 0      -- iterator variable
		local iter = function ()   -- iterator function
			i = i + 1
			if a[i] == nil then return nil
			else return a[i], t[a[i]]
			end
		end
	return iter
end

local function getColoredUnitName (name, class)
	local colorUnitName
	
	if(not unitColor[name]) then
		local classColor = COLOR_TABLE[strupper(string.gsub(class, " ", ""))]	
		colorUnitName = string.format("|cff%02x%02x%02x%s|r",classColor.r*255,classColor.g*255,classColor.b*255,name)	
	
		unitColor[name] = colorUnitName
	else
		colorUnitName = unitColor[name]
	end	
	return colorUnitName
end

local function getColoredTooltipString(text, conditionTable)
	local retText = text

	for name, val in pairs(conditionTable) do
		if (val.condition) then
			retText = string.format("|cff%02x%02x%02x%s|r",val.color.r*255,val.color.g*255,val.color.b*255, text)	
		end
	end
	
	return retText
end

local function getColoredString(text, color)
	return string.format("|cff%02x%02x%02x%s|r",color.r*255,color.g*255,color.b*255, text)	
end

local function FormattedSeconds(seconds)
	local negative = ""

	if not seconds then
		seconds = 0
	end

	if seconds < 0 then
		negative = "-"
		seconds = -seconds
	end
	local L_DAY_ONELETTER_ABBR = _G.DAY_ONELETTER_ABBR:gsub("%s*%%d%s*", "")

	if not seconds or seconds >= SECONDS_PER_DAY * 36500 then -- 100 years
		return ("%s**%s **:**"):format(negative, L_DAY_ONELETTER_ABBR)
	elseif seconds >= SECONDS_PER_DAY then
		return ("%s%d%s %d:%02d"):format(negative, seconds / SECONDS_PER_DAY, L_DAY_ONELETTER_ABBR, math.fmod(seconds / SECONDS_PER_HOUR, 24), math.fmod(seconds / 60, 60))
	else
		return ("%s%d:%02d:%02d"):format(negative, seconds / SECONDS_PER_HOUR, math.fmod(seconds / 60, 60), math.fmod(seconds, 60))
	end
end

local function FormatRealmPlayer(paramCharInfo, colored)
	if colored then
		return ("%s (%s)"):format(getColoredUnitName(paramCharInfo.playerName, paramCharInfo.playerClass), paramCharInfo.realmName);
	else		
		return ("%s-%s"):format(paramCharInfo.playerName, paramCharInfo.realmName);
	end
end

function Garrison:GetFonts()
	for k in pairs(fonts) do fonts[k] = nil end

	for _, name in pairs(LSM:List(LSM.MediaType.FONT)) do
		fonts[name] = name
	end
	
	return fonts
end


function Garrison:SendNotification(paramCharInfo, missionData)
	local notificationText = (L["Mission complete (%s): %s"]):format(FormatRealmPlayer(paramCharInfo, false), missionData.name)
	local toastText = ("%s\n\n%s"):format(FormatRealmPlayer(paramCharInfo, true), missionData.name)

	debugPrint(notificationText)
	self:Pour(notificationText, colors.green.r, colors.green.g, colors.green.b)

	if configDb.notification.toastEnabled then
		Toast:Spawn(TOAST_MISSION_COMPLETE, toastText)
	end

	missionData.notification = 1 
end 

function Garrison:HandleMission(paramCharInfo, missionData, timeLeft) 
	if timeLeft == 0 then
		if configDb.notification.enabled then
			if (missionData.notification == 0 or (not addonInitialized and configDb.notification.repeatOnLoad)) then
				-- Show Notification

				Garrison:SendNotification(paramCharInfo, missionData)				
			end
		end
	end
end

function Garrison:GetPlayerMissionCount(paramCharInfo, missionCount, missions)
	local now = time()

	local numMissionsPlayer = tableSize(missions)

	if numMissionsPlayer > 0 then
		for missionID, missionData in pairs(missions) do
			local timeLeft = math.max(0, missionData.duration - (now - missionData.start))
			-- Do mission handling while we are at it
			Garrison:HandleMission(paramCharInfo, missionData, timeLeft) 

			if (timeLeft == 0) then
				missionCount.complete = missionCount.complete + 1
			else
				missionCount.inProgress = missionCount.inProgress + 1
			end	
		end
		missionCount.total = missionCount.total + numMissionsPlayer
	end	
end

function Garrison:GetMissionCount(paramCharInfo)	
	local missionCount = {
		total = 0,
		inProgress = 0,
		complete = 0,
	}

	if paramCharInfo then		
		Garrison:GetPlayerMissionCount(paramCharInfo, missionCount, globalDb.data[paramCharInfo.realmName][paramCharInfo.playerName].missions)
	else 
		for realmName, realmData in pairs(globalDb.data) do		
			for playerName, playerData in pairs(realmData) do									
				Garrison:GetPlayerMissionCount(playerData.info, missionCount, playerData.missions)
			end
		end
	end

	return missionCount.total, missionCount.inProgress, missionCount.complete
end

   
function Garrison:UpdateConfig() 		
	Garrison:SetSinkStorage(configDb.notification.sink)

	Toast:Register(TOAST_MISSION_COMPLETE, function(toast, ...)
		if configDb.notification.toastPersistent then
			toast:MakePersistent()
		end
		toast:SetTitle(L["Garrison: Mission complete"])
		toast:SetFormattedText(getColoredString(..., colors.green))
		toast:SetIconTexture([[Interface\Icons\Inv_Garrison_Resource]])
	end)	

end

local DrawTooltip
do
	local NUM_TOOLTIP_COLUMNS = 7
	local tooltip
	local LDB_anchor

	local function ExpandButton_OnMouseUp(tooltip_cell, realm_and_character)
		local realm, character_name = (":"):split(realm_and_character, 2)

		globalDb.data[realm][character_name].expanded = not globalDb.data[realm][character_name].expanded
		DrawTooltip(LDB_anchor)
	end

	local function ExpandButton_OnMouseDown(tooltip_cell, is_expanded)
		local line, column = tooltip_cell:GetPosition()
		tooltip:SetCell(line, column, is_expanded and ICON_MINUS_DOWN or ICON_PLUS_DOWN)
	end

	local function Tooltip_OnRelease(self)
		tooltip = nil
		LDB_anchor = nil
	end	

	local function AddSeparator(tooltip)
		tooltip:AddSeparator(1, colors.lightGray.r, colors.lightGray.g, colors.lightGray.b, colors.lightGray.a)
	end

	function DrawTooltip(anchor_frame)
		if not anchor_frame then
			return
		end
		LDB_anchor = anchor_frame
	
		if not tooltip then
			tooltip = LibQTip:Acquire("BrokerGarrisonTooltip", NUM_TOOLTIP_COLUMNS, "LEFT", "LEFT", "LEFT", "LEFT", "LEFT", "LEFT", "LEFT")
			tooltip.OnRelease = Tooltip_OnRelease
			tooltip:EnableMouse(true)
			tooltip:SmartAnchorTo(anchor_frame)
			tooltip:SetAutoHideDelay(configDb.tooltip.autoHideDelay or 0.25, LDB_anchor)
			tooltip:SetScale(configDb.tooltip.scale or 1)
			local font = LSM:Fetch("font", configDb.tooltip.fontName or DEFAULT_FONT)
			local fontSize = configDb.tooltip.fontSize or 12

			local tmpFont = CreateFont("BrokerGarrisonTooltipFont")
			tmpFont:SetFont(font, fontSize)
			tooltip:SetFont(tmpFont)
		end

		toolTipRef = tooltip
		
		local now = time()
		local name, row, realmName, realmData, playerName, playerData, missionID, missionData

		tooltip:Clear()
		tooltip:SetCellMarginH(0)
		tooltip:SetCellMarginV(0)

		for realmName, realmData in pairsByKeys(globalDb.data) do
			row = tooltip:AddLine()
			tooltip:SetCell(row, 1, ("%s"):format(getColoredString(("%s"):format(realmName), colors.lightGray)), nil, "LEFT", 3)

			row = tooltip:AddLine(" ")
			AddSeparator(tooltip)

			for playerName, playerData in pairsByKeys(realmData) do				
				
				local numMissionsTotal, numMissionsInProgress, numMissionsCompleted = Garrison:GetMissionCount(playerData.info)

				row = tooltip:AddLine(" ")
				row = tooltip:AddLine()

				tooltip:SetCell(row, 1, playerData.expanded and ICON_MINUS or ICON_PLUS)
				tooltip:SetCell(row, 2, ("%s"):format(getColoredUnitName(playerData.info.playerName, playerData.info.playerClass)))
				tooltip:SetCell(row, 3, ("%s %s"):format(ICON_CURRENCY, BreakUpLargeNumbers(playerData.currencyAmount or 0)))
				
				tooltip:SetCell(row, 4, getColoredString((L["Total: %s"]):format(numMissionsTotal), colors.lightGray))
				tooltip:SetCell(row, 5, getColoredString((L["In Progress: %s"]):format(numMissionsInProgress), colors.lightGray))
				tooltip:SetCell(row, 6, getColoredString((L["Complete: %s"]):format(numMissionsCompleted), colors.lightGray))
						
				tooltip:SetCellScript(row, 1, "OnMouseUp", ExpandButton_OnMouseUp, ("%s:%s"):format(realmName, playerName))
				tooltip:SetCellScript(row, 1, "OnMouseDown", ExpandButton_OnMouseDown, playerData.expanded)

				if playerData.expanded and numMissionsTotal > 0 then
					row = tooltip:AddLine(" ")
					AddSeparator(tooltip)

					row = tooltip:AddLine(" ")
					tooltip:SetLineColor(row, colors.darkGray.r, colors.darkGray.g, colors.darkGray.b, 1)

					for missionID, missionData in pairs(playerData.missions) do
						local timeLeft = math.max(0, missionData.duration - (now - missionData.start))

						row = tooltip:AddLine(" ")
						
						tooltip:SetCell(row, 2, missionData.name, nil, "LEFT", 2)

						tooltip:SetLineColor(row, colors.darkGray.r, colors.darkGray.g, colors.darkGray.b, 1)
						
						if (timeLeft == 0) then
							tooltip:SetCell(row, 4, getColoredString(L["Complete!"], colors.green), nil, "RIGHT", 3)
						else							
							tooltip:SetCell(row, 4, ("%s%s"):format(
								getColoredString(("%s | "):format(FormattedSeconds(missionData.duration)), colors.lightGray),
								getColoredString(FormattedSeconds(timeLeft), colors.white)
							), nil, "RIGHT", 3)
						end
					end

					row = tooltip:AddLine(" ")
					tooltip:SetLineColor(row, colors.darkGray.r, colors.darkGray.g, colors.darkGray.b, 1)					

					AddSeparator(tooltip)
				end
			end
			row = tooltip:AddLine(" ")
		end	   
	   tooltip:Show()		
	end

	function ldb_object:OnEnter()
		DrawTooltip(self)
	end

	function ldb_object:OnLeave()
	end

	function ldb_object:OnClick(button)
		if button == "LeftButton" then
			if not GarrisonLandingPage then
				debugPrint("Loading Blizzard_GarrisonUI...");
				if UIParentLoadAddOn("Blizzard_GarrisonUI") then					
					GarrisonLandingPage = _G.GarrisonLandingPage
				end
			end

			if GarrisonLandingPage then
				if (not GarrisonLandingPage:IsShown()) then
					ShowUIPanel(GarrisonLandingPage);
				else
					HideUIPanel(GarrisonLandingPage);
				end
			else
				
			end
		else	
			for i, button in ipairs(InterfaceOptionsFrameAddOns.buttons) do
				if button.element and button.element.name == ADDON_NAME and button.element.collapsed then
					OptionsListButtonToggle_OnClick(button.toggle)
				end
			end									
			if AceConfigDialog.OpenFrames[ADDON_NAME] then
				AceConfigDialog:Close(ADDON_NAME)
			else
				AceConfigDialog:Open(ADDON_NAME)
			end	
		end		
	end
end


function Garrison:UpdateEvent(...)
	local arg = {n=select('#',...),...}
	local event = arg[1]
	local missionID = arg[2]

	if (event == "GARRISON_MISSION_STARTED") then

		for key,garrisonMission in pairs(C_Garrison.GetInProgressMissions()) do

			if (garrisonMission.missionID == missionID) then
				local mission = {
					id = garrisonMission.missionID,
					name = garrisonMission.name,
					start = time(),
					duration = garrisonMission.durationSeconds,
					notification = 0,
				}

				globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID] = mission

				debugPrint("Added Mission: "..missionID)
			end

		end
	end

	if (event == "GARRISON_MISSION_COMPLETED") then
		if (globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID]) then				
			debugPrint("Removed Mission: "..missionID)
			globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID] = nil
		end
	end

	Garrison:Update()
end

function Garrison:UpdateCurrency()
	local _, amount, _ = GetCurrencyInfo(GARRISON_CURRENCY);
	globalDb.data[charInfo.realmName][charInfo.playerName].currencyAmount = amount

	Garrison:Update()
end

function Garrison:Update()	

	-- LDB Text
	local numMissionsTotal, numMissionsInProgress, numMissionsCompleted = Garrison:GetMissionCount(nil)

	local conditionTable = {
		completed = {
			condition = (numMissionsTotal > 0 and numMissionsCompleted > 0),
			color = { r = 0, g = 1, b = 0 }
		},
		inprogress = {
			condition = (numMissionsTotal > 0 and numMissionsCompleted == 0),
			color = { r = 1, g = 1, b = 1 }
		},
		nomission = {
			condition = (numMissionsTotal == 0),
			color = { r = 1, g = 0, b = 0 }
		},
	}	

	local ldbText = ""

	if configDb.ldbConfig.showCurrency then
		local currencyAmount = globalDb.data[charInfo.realmName][charInfo.playerName].currencyAmount
		ldbText = ldbText..("%s %s"):format(BreakUpLargeNumbers(currencyAmount), ICON_CURRENCY)
	end
	if configDb.ldbConfig.showProgress then
		ldbText = ldbText.." "..(L["In Progress: %s"]):format(numMissionsInProgress)
	end
	if configDb.ldbConfig.showComplete then
		ldbText = ldbText.." "..(L["Complete: %s"]):format(numMissionsCompleted)
	end	


	if ldbText == "" then
		ldbText = L["Missions"]
	end

	ldb_object.text = getColoredTooltipString(ldbText, conditionTable)
	for name, val in pairs(conditionTable) do
		if (val.condition) then		
			ldb_object.iconR, ldb_object.iconG, ldb_object.iconB = val.color.r, val.color.g, val.color.b
		end
	end	

	-- First update 
	addonInitialized = true
end

function Garrison:OnInitialize()	
	garrisonDb = LibStub("AceDB-3.0"):New(ADDON_NAME .. "DB", DB_DEFAULTS, true)
	globalDb = garrisonDb.global
	configDb = garrisonDb.profile

	self.DB = garrisonDb

	-- Data migration
	if _G.Broker_GarrisonDB.data then
		globalDb.data = _G.Broker_GarrisonDB.data
		_G.Broker_GarrisonDB.data = nil
	end

	-- DB
	if not globalDb.data[charInfo.realmName] then
		globalDb.data[charInfo.realmName] = {}
	end

	if (not globalDb.data[charInfo.realmName][charInfo.playerName]) then
		globalDb.data[charInfo.realmName][charInfo.playerName] = {
			missions = {},
			expanded = true,
			info = charInfo,
			currencyAmount = 0,
		}
	end

	if (not globalDb.data[charInfo.realmName][charInfo.playerName]["missions"]) then		
		globalDb.data[charInfo.realmName][charInfo.playerName]["missions"] = {}
	end

	self.getColoredUnitName = getColoredUnitName
	self.pairsByKeys = pairsByKeys
	self.debugPrint = debugPrint
	self.charInfo = charInfo

	self:SetupOptions()

	Garrison:UpdateConfig()

	Garrison:RegisterEvent("GARRISON_MISSION_STARTED", "UpdateEvent")
	Garrison:RegisterEvent("GARRISON_MISSION_COMPLETED", "UpdateEvent")
	Garrison:RegisterEvent("GARRISON_MISSION_FINISHED", "UpdateEvent")
	Garrison:RegisterEvent("PLAYER_LOGIN", "EnteringWorld")

end


function Garrison:EnteringWorld()	
	Garrison:Update()

	timers.icon_update = Garrison:ScheduleRepeatingTimer("Update", 60)

	Garrison:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "UpdateCurrency")	
end

