local ADDON_NAME, private = ...

local BrokerGarrison = LibStub('AceAddon-3.0'):NewAddon(ADDON_NAME, 'AceConsole-3.0', 'AceEvent-3.0', 'AceTimer-3.0')
local Garrison = BrokerGarrison

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local L = LibStub:GetLibrary( "AceLocale-3.0" ):GetLocale(ADDON_NAME)
local LibQTip = LibStub('LibQTip-1.0')
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

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

local toolTipRef

local DEBUG = true
local timers = {}
local colors = {
	green = {r=0, g=1, b=0, a=1},
	white = {r=1, g=1, b=1, a=1},
	lightGray = {r=0.25, g=0.25, b=0.25, a=1},
	darkGray = {r=0.1, g=0.1, b=0.1, a=1},
}
local GARRISON_CURRENCY = 824;
local ICON_CURRENCY = string.format("\124TInterface\\Icons\\Inv_Garrison_Resource:%d:%d:1:0\124t", 16, 16)

local charInfo = {
	playerName = UnitName("player"),
	playerClass = UnitClass("player"),	
	playerFaction = UnitFactionGroup("player"),
	realmName = GetRealmName(),
}	

local unitColor = {}
local SECONDS_PER_DAY = 24 * 60 * 60
local SECONDS_PER_HOUR = 60 * 60

local ICON_MINUS = [[|TInterface\MINIMAP\UI-Minimap-ZoomOutButton-Up:16:16|t]]
local ICON_MINUS_DOWN = [[|TInterface\MINIMAP\UI-Minimap-ZoomOutButton-Down:16:16|t]]

local ICON_PLUS = [[|TInterface\MINIMAP\UI-Minimap-ZoomInButton-Up:16:16|t]]
local ICON_PLUS_DOWN = [[|TInterface\MINIMAP\UI-Minimap-ZoomInButton-Down:16:16|t]]


Garrison.dataobj = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, 
  { type = "data source", 
   label = L["Broker Garrison"], 
	icon = "Interface\\Icons\\Inv_Garrison_Resource",
	text = "Garrison: Missions",
   })

local ldb_object = Garrison.dataobj

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

function Garrison:getData()
	return Broker_GarrisonDB.data
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

local function returnchars()
	local a = {}

	for realmName,realmData in pairsByKeys(Broker_GarrisonDB.data) do
		for playerName,value in pairsByKeys(realmData) do
			table.insert(a,playerName..":"..realmName)
		end
	end

	table.sort(a)
	return a
end


local function deletechar(realm_and_character)
	local playerName, realmName = (":"):split(realm_and_character, 2)
	if not realmName or realmName == nil or realmName == "" then return nil end
	if not playerName or playerName == nil or playerName == "" then return nil end

	Broker_GarrisonDB.data[realmName][playerName] = nil
	debugPrint(("%s deleted."):format(realm_and_character))
end


function Garrison:getColoredUnitName (name, class)
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

function Garrison:getColoredTooltipString(text, conditionTable)
	local retText = text

	for name, val in pairs(conditionTable) do
		if (val.condition) then
			retText = string.format("|cff%02x%02x%02x%s|r",val.color.r*255,val.color.g*255,val.color.b*255, text)	
		end
	end
	
	return retText
end

function Garrison:getColoredString(text, color)
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


local sorting = {
	["Time left"] = L["Time left"],
	["Name"] = L["Name"],
}

local options = {
	name = L["Broker Garrison"],
	type = "group",
	args = {
		confdesc = {
			order = 1,
			type = "description",
			name = L["Garrison Mission display for LDB\n"],
			cmdHidden = true,
		},
		ldbHeader = {
			order = 100,
			type = "header",
			name = "LDB",
			cmdHidden = true,
		},		
		showCurrency = {
			order = 101, 
			type = "toggle", 
			width = "full",
			name = L["Show currency"],
			desc = L["Show garrison currency in LDB"],
			get = function() return Broker_GarrisonConfig.showCurrency end,
			set = function(_,v) Broker_GarrisonConfig.showCurrency = v 
				Garrison:UpdateIcon()
			end,
		},

		showProgress = {
			order = 102, 
			type = "toggle", 
			width = "full",
			name = L["Show active missions"],
			desc = L["Show active missions in LDB"],
			get = function() return Broker_GarrisonConfig.showProgress end,
			set = function(_,v) Broker_GarrisonConfig.showProgress = v 
				Garrison:UpdateIcon()
			end,
		},		
		showComplete = {
			order = 103, 
			type = "toggle", 
			width = "full",
			name = L["Show completed missions"],
			desc = L["Show completed missions in LDB"],
			get = function() return Broker_GarrisonConfig.showComplete end,
			set = function(_,v) Broker_GarrisonConfig.showComplete = v 
				Garrison:UpdateIcon()
			end,
		},	
		deleteHeader = {
			order = 200,
			type = "header",
			name = "Data",
			cmdHidden = true,
		},		
		deletechar = {
			name = L["Delete char"],
			desc = L["Delete the selected char"],
			order = 201,
			type = "select",
			values = returnchars,
			set = function(info, val) local t=returnchars(); deletechar(t[val]); Garrison:UpdateConfig() end,
			get = function(info) return nil end,
			width = "double",
		},		
		todoText = {
			order = 505,
			type = "description",
			name = "TODO: MORE OPTIONS!!!11",
			cmdHidden = true,
		},			
		aboutHeader = {
			order = 900,
			type = "header",
			name = "About",
			cmdHidden = true,
		},
		about = {
			order = 910,
			type = "description",
			name = ("Author: %s <EU-Khaz'Goroth>\nLayout: %s <EU-Khaz'Goroth>"):format(Garrison:getColoredUnitName("Smb","PRIEST"), Garrison:getColoredUnitName("Hotaruby","DRUID")),
			cmdHidden = true,
		},		
	}
}	
   
LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME)

function BrokerGarrison:OnInitialize()
	debugPrint("OnInitialize!!!!")
end

function Garrison:UpdateConfig() 
	if not Broker_GarrisonConfig then
		Broker_GarrisonConfig = {
			showCurrency = true,
			showProgress = true,
			showComplete = true,
		}
	end
	
	if not Broker_GarrisonDB or not Broker_GarrisonDB.data then
		Broker_GarrisonDB = {			
			data = {},
		}
	end
	if not Broker_GarrisonDB.data[charInfo.realmName] then
		Broker_GarrisonDB.data[charInfo.realmName] = {}
	end


	if (not Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName]) then
		Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName] = {
			missions = {},
			expanded = true,
			info = charInfo,
			currencyAmount = 0,
		}
	end

	if (not Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName]["missions"]) then		
		Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName]["missions"] = {}
	end
	
end


function Garrison:GetPlayerMissionCount(missionCount, missions)
	local now = time()

	local numMissionsPlayer = tableSize(missions)

	if numMissionsPlayer > 0 then
		for missionID, missionData in pairs(missions) do
			local timeLeft = math.max(0, missionData.duration - (now - missionData.start))
			if (timeLeft == 0) then
				missionCount.complete = missionCount.complete + 1
			else
				missionCount.inProgress = missionCount.inProgress + 1
			end	
		end
		missionCount.total = missionCount.total + numMissionsPlayer
	end	
end

function Garrison:GetMissionCount(paramRealmName, paramPlayerName)	
	local missionCount = {
		total = 0,
		inProgress = 0,
		complete = 0,
	}

	if paramRealmName and paramPlayerName then		
		Garrison:GetPlayerMissionCount(missionCount, Broker_GarrisonDB.data[paramRealmName][paramPlayerName].missions)
	else 
		for realmName, realmData in pairs(Broker_GarrisonDB.data) do		
			for playerName, playerData in pairs(realmData) do									
				Garrison:GetPlayerMissionCount(missionCount, playerData.missions)
			end
		end
	end

	return missionCount.total, missionCount.inProgress, missionCount.complete
end


local DrawTooltip
do
	local NUM_TOOLTIP_COLUMNS = 7
	local tooltip
	local LDB_anchor

	local function ExpandButton_OnMouseUp(tooltip_cell, realm_and_character)
		local realm, character_name = (":"):split(realm_and_character, 2)

		Broker_GarrisonDB.data[realm][character_name].expanded = not Broker_GarrisonDB.data[realm][character_name].expanded
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
			tooltip:SetAutoHideDelay(0.25, anchor_frame)
			tooltip:SetScale(1)
		end
		
		local now = time()
		local name, row, realmName, realmData, playerName, playerData, missionID, missionData

		tooltip:Clear()
		tooltip:SetCellMarginH(0)
		tooltip:SetCellMarginV(0)

		for realmName, realmData in pairsByKeys(Broker_GarrisonDB.data) do
			row = tooltip:AddLine()
			tooltip:SetCell(row, 1, ("%s"):format(Garrison:getColoredString(("%s"):format(realmName), colors.lightGray)), nil, "LEFT", 3)

			row = tooltip:AddLine(" ")
			AddSeparator(tooltip)

			for playerName, playerData in pairsByKeys(realmData) do				
				
				local numMissionsTotal, numMissionsInProgress, numMissionsCompleted = Garrison:GetMissionCount(realmName, playerName)

				row = tooltip:AddLine(" ")
				row = tooltip:AddLine()

				tooltip:SetCell(row, 1, playerData.expanded and ICON_MINUS or ICON_PLUS)
				tooltip:SetCell(row, 2, ("%s"):format(Garrison:getColoredUnitName(playerData.info.playerName, playerData.info.playerClass)))
				tooltip:SetCell(row, 3, ("%s %s"):format(ICON_CURRENCY, BreakUpLargeNumbers(playerData.currencyAmount or 0)))
				
				tooltip:SetCell(row, 4, Garrison:getColoredString((L["Total: %s"]):format(numMissionsTotal), colors.lightGray))
				tooltip:SetCell(row, 5, Garrison:getColoredString((L["In Progress: %s"]):format(numMissionsInProgress), colors.lightGray))
				tooltip:SetCell(row, 6, Garrison:getColoredString((L["Complete: %s"]):format(numMissionsCompleted), colors.lightGray))
						
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
							tooltip:SetCell(row, 4, Garrison:getColoredString(L["Complete!"], colors.green), nil, "RIGHT", 3)
						else							
							tooltip:SetCell(row, 4, ("%s%s"):format(
								Garrison:getColoredString(("%s | "):format(FormattedSeconds(missionData.duration)), colors.lightGray),
								Garrison:getColoredString(FormattedSeconds(timeLeft), colors.white)
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
			-- Show Garrison Mission UI?!
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


function Garrison:Update(...)
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
				}

				Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName].missions[missionID] = mission

				debugPrint("Added Mission: "..missionID)
			elseif (not Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName].missions[missionID]) then				
				-- Not current mission but Mission not found - record

				local mission = {
					id = garrisonMission.missionID,
					name = garrisonMission.name,
					start = time(),
					duration = garrisonMission.durationSeconds,
					timeLeft = garrisonMission.timeLeft,
				}

				Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName].missions[missionID] = mission

			end

		end
	end

	if (event == "GARRISON_MISSION_COMPLETED") then
		if (Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName].missions[missionID]) then				
			debugPrint("Removed Mission: "..missionID)
			Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName].missions[missionID] = nil
		end
	end

	Garrison:UpdateIcon()
end

function Garrison:UpdateCurrency()
	local _, amount, _ = GetCurrencyInfo(GARRISON_CURRENCY);
	Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName].currencyAmount = amount

	Garrison:UpdateIcon()
end

function Garrison:UpdateIcon()	

	local numMissionsTotal, numMissionsInProgress, numMissionsCompleted = Garrison:GetMissionCount(nil, nil)

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

	if Broker_GarrisonConfig.showCurrency then
		local currencyAmount = Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerName].currencyAmount
		ldbText = ldbText..("%s %s"):format(BreakUpLargeNumbers(currencyAmount), ICON_CURRENCY)
	end
	if Broker_GarrisonConfig.showProgress then
		ldbText = ldbText.." "..(L["In Progress: %s"]):format(numMissionsInProgress)
	end
	if Broker_GarrisonConfig.showComplete then
		ldbText = ldbText.." "..(L["Complete: %s"]):format(numMissionsCompleted)
	end	


	if ldbText == "" then
		ldbText = L["Missions"]
	end

	ldb_object.text = Garrison:getColoredTooltipString(ldbText, conditionTable)
	for name, val in pairs(conditionTable) do
		if (val.condition) then		
			ldb_object.iconR, ldb_object.iconG, ldb_object.iconB = val.color.r, val.color.g, val.color.b
		end
	end	
end


function Garrison:EnteringWorld()
	Garrison:UpdateConfig()

	Garrison:UpdateIcon()
	timers.icon_update = Garrison:ScheduleRepeatingTimer("UpdateIcon", 60)
end

Garrison:RegisterEvent("GARRISON_MISSION_STARTED", "Update")
Garrison:RegisterEvent("GARRISON_MISSION_COMPLETED", "Update")
Garrison:RegisterEvent("GARRISON_MISSION_FINISHED", "Update")
Garrison:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "UpdateCurrency")
Garrison:RegisterEvent("PLAYER_LOGIN", "EnteringWorld")

Garrison:UpdateConfig()

