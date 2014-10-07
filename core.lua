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
local UIParentLoadAddOn = _G.UIParentLoadAddOn
local GarrisonLandingPage = _G.GarrisonLandingPage
local GarrisonMissionFrame = _G.GarrisonMissionFrame
local ShowUIPanel = _G.ShowUIPanel
local HideUIPanel = _G.HideUIPanel
local CreateFont = _G.CreateFont
local GarrisonLandingPageMinimapButton = _G.GarrisonLandingPageMinimapButton
local toolTipRef
local PlaySoundFile = _G.PlaySoundFile

local garrisonDb
local configDb
local globalDb
local DEFAULT_FONT

-- Constants
local TOOLTIP_BUILDING = 1
local TOOLTIP_MISSION = 2

local addonInitialized = false
local delayedInit = false
local CONFIG_VERSION = 1
local DEBUG = true
local timers = {}
local colors = {
	green = {r=0, g=1, b=0, a=1},
	white = {r=1, g=1, b=1, a=1},
	lightGray = {r=0.25, g=0.25, b=0.25, a=1},
	darkGray = {r=0.1, g=0.1, b=0.1, a=1},
}
local COMPLETED_PATTERN = "^[^%d]*(0)[^%d]*$"
local GARRISON_CURRENCY = 824;
local ICON_CURRENCY = string.format("\124TInterface\\Icons\\Inv_Garrison_Resource:%d:%d:1:0\124t", 16, 16)

local ICON_OPEN = string.format("\124TInterface\\AddOns\\Broker_Garrison\\Media\\Open:%d:%d:1:0\124t", 16, 16)
local ICON_CLOSE = string.format("\124TInterface\\AddOns\\Broker_Garrison\\Media\\Close:%d:%d:1:0\124t", 16, 16)

local ICON_OPEN_DOWN = ICON_OPEN
local ICON_CLOSE_DOWN = ICON_CLOSE

local SECONDS_PER_DAY = 24 * 60 * 60
local SECONDS_PER_HOUR = 60 * 60
local TOAST_MISSION_COMPLETE = "BrokerGarrisonMissionComplete"

local DB_DEFAULTS = {
	profile = {
		ldbConfig = {
			showCurrency = true,
			showProgress = true,
			showComplete = true,
			hideGarrisonMinimapButton = false,
		},
		notification = {
			enabled = true,
			repeatOnLoad = false,
			sink = {},
			toastEnabled = true,
			toastPersistent = true,
			hideBlizzardNotificationBuilding = false,
			hideBlizzardNotificationMission = false,
		},			
		tooltip = {
			scale = 1,
			autoHideDelay = 0.25,
		},		
		configVersion = CONFIG_VERSION,
		debugPrint = false,
	},
	global = {
		data = {}
	}
}

-- Player info
local charInfo = {
	playerName = UnitName("player"),	
	playerClass = select(2, UnitClass("player")),
	playerFaction = UnitFactionGroup("player"),
	realmName = GetRealmName(),
}	


-- Cache
local unitColor = {}

-- LDB init
local ldb_object_mission = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME.."Mission", 
  { type = "data source", 
   label = L["Garrison-Missions"], 
	icon = "Interface\\Icons\\Inv_Garrison_Resource",	
	text = "Garrison: Missions",
   })

local ldb_object_building = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME.."Building", 
  { type = "data source", 
   label = L["Garrison-Buildings"], 
	icon = "Interface\\Icons\\Inv_Garrison_Resource",	
	text = "Garrison: Buildings",
   })

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
	if(configDb.debugPrint) then
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
		local classColor = COLOR_TABLE[class]

		if not classColor then
			classColor = colors.white
		end

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

local function toastCallback (callbackType, mouseButton, buttonDown, payload)

	local missionData = payload[1]

	if callbackType == "primary" then
		debugPrint("OK: "..payload[1].id.." ("..payload[1].name..")")
	end
	if callbackType == "secondary" then	
		debugPrint("Dismiss: "..payload[1].id.." ("..payload[1].name..")")
		missionData.notification = 2 -- Mission dismissed, never show again
	end
end

local function toastMissionComplete (toast, text, missionData)
	if configDb.notification.toastPersistent then
		toast:MakePersistent()
	end
	toast:SetTitle(L["Garrison: Mission complete"])
	toast:SetFormattedText(getColoredString(text, colors.green))
	toast:SetIconTexture([[Interface\Icons\Inv_Garrison_Resource]])
	if configDb.notification.extendedToast then
		toast:SetPrimaryCallback(_G.OKAY, toastCallback)
		toast:SetSecondaryCallback(L["Dismiss"], toastCallback)		
		toast:SetPayload(missionData)
	end
end

function Garrison:OnDependencyLoaded()
	GarrisonLandingPage = _G.GarrisonLandingPage
	GarrisonMissionFrame = _G.GarrisonMissionFrame
end

function Garrison:LoadDependencies()
	if not GarrisonMissionFrame or not GarrisonLandingPage then
		debugPrint("Loading Blizzard_GarrisonUI...");
		if UIParentLoadAddOn("Blizzard_GarrisonUI") then					
			Garrison:OnDependencyLoaded()
		end
	end
end

function Garrison:SendNotification(paramCharInfo, missionData)
	local notificationText = (L["Mission complete (%s): %s"]):format(FormatRealmPlayer(paramCharInfo, false), missionData.name)
	local toastText = ("%s\n\n%s"):format(FormatRealmPlayer(paramCharInfo, true), missionData.name)

	debugPrint(notificationText)
	self:Pour(notificationText, colors.green.r, colors.green.g, colors.green.b)

	if configDb.notification.toastEnabled then
		Toast:Spawn(TOAST_MISSION_COMPLETE, toastText, missionData)
	end

	if configDb.notification.playSound then
		PlaySoundFile(LSM:Fetch("sound", configDb.notification.soundName or "None"))
	end

	missionData.notification = 1 
end 

function Garrison:HandleMission(paramCharInfo, missionData, timeLeft) 
	if  (timeLeft < 0 and missionData.start == -1) then
		-- Detect completed mission
		

		-- Deprecated - should be detected on finished event
		local parsedTimeLeft = string.match(missionData.timeLeft, COMPLETED_PATTERN)
		if (parsedTimeLeft == "0") then
			-- 1 * 0 found in string -> assuming mission complete
			missionData.start = 0
		end
	end

	if (timeLeft < 0 and missionData.start >= 0) then
		if configDb.notification.enabled then
			if  (missionData.notification == 0 or 
				(not addonInitialized and configDb.notification.repeatOnLoad and missionData.notification ~= 2)
				) then
				-- Show Notification

				if delayedInit then
					Garrison:SendNotification(paramCharInfo, missionData)	
				end
			end			
		end
	end
end

function Garrison:GetPlayerMissionCount(paramCharInfo, missionCount, missions)
	local now = time()

	local numMissionsPlayer = tableSize(missions)

	if numMissionsPlayer > 0 then
		for missionID, missionData in pairs(missions) do
			local timeLeft = missionData.duration - (now - missionData.start)

			-- Do mission handling while we are at it
			Garrison:HandleMission(paramCharInfo, missionData, timeLeft) 

			if missionData.start > 0 then
				if (timeLeft <= 0) then
					missionCount.complete = missionCount.complete + 1
				else
					missionCount.inProgress = missionCount.inProgress + 1
				end	
			else
				if missionData.start == 0 then
					missionCount.complete = missionCount.complete + 1
				else
					missionCount.inProgress = missionCount.inProgress + 1
				end
			end			
			missionCount.total = missionCount.total + numMissionsPlayer
		end
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
	if GarrisonLandingPageMinimapButton then	
		if GarrisonLandingPageMinimapButton:IsShown() then
			if configDb.ldbConfig.hideGarrisonMinimapButton then
				GarrisonLandingPageMinimapButton:Hide()
			end
		else
			if not configDb.ldbConfig.hideGarrisonMinimapButton then
				GarrisonLandingPageMinimapButton:Show()
			end
		end
	end
end

local DrawTooltip
do
	local NUM_TOOLTIP_COLUMNS = 7
	local tooltip
	local LDB_anchor
	local tooltipType

	local function ExpandButton_OnMouseUp(tooltip_cell, realm_and_character)
		local realm, character_name = (":"):split(realm_and_character, 2)

		globalDb.data[realm][character_name].expanded = not globalDb.data[realm][character_name].expanded
		DrawTooltip(LDB_anchor)
	end

	local function ExpandButton_OnMouseDown(tooltip_cell, is_expanded)
		local line, column = tooltip_cell:GetPosition()
		tooltip:SetCell(line, column, is_expanded and ICON_CLOSE_DOWN or ICON_OPEN_DOWN)
	end

	local function Tooltip_OnRelease(self)
		tooltip = nil
		LDB_anchor = nil
		tooltipType = nil
	end	

	local function AddSeparator(tooltip)
		tooltip:AddSeparator(1, colors.lightGray.r, colors.lightGray.g, colors.lightGray.b, colors.lightGray.a)
	end

	function DrawTooltip(anchor_frame, paramTooltipType)
		if not anchor_frame then
			return
		end
		LDB_anchor = anchor_frame
		tooltipType = paramTooltipType
	
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

		if tooltipType == TOOLTIP_MISSION then
			for realmName, realmData in pairsByKeys(globalDb.data) do
				row = tooltip:AddLine()
				tooltip:SetCell(row, 1, ("%s"):format(getColoredString(("%s"):format(realmName), colors.lightGray)), nil, "LEFT", 3)

				row = tooltip:AddLine(" ")
				AddSeparator(tooltip)

				for playerName, playerData in pairsByKeys(realmData) do				
					
					local numMissionsTotal, numMissionsInProgress, numMissionsCompleted = Garrison:GetMissionCount(playerData.info)

					row = tooltip:AddLine(" ")
					row = tooltip:AddLine()

					tooltip:SetCell(row, 1, playerData.expanded and ICON_CLOSE or ICON_OPEN)
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
							local timeLeft = missionData.duration - (now - missionData.start)

							row = tooltip:AddLine(" ")
							
							tooltip:SetCell(row, 2, missionData.name, nil, "LEFT", 2)

							tooltip:SetLineColor(row, colors.darkGray.r, colors.darkGray.g, colors.darkGray.b, 1)
							
							if (missionData.start == -1) then
								tooltip:SetCell(row, 4, ("%s%s"):format(
									getColoredString(("%s | "):format(FormattedSeconds(missionData.duration)), colors.lightGray),
									getColoredString("~"..missionData.timeLeft, colors.white)
								), nil, "RIGHT", 3)						
							elseif (missionData.start == 0 or timeLeft < 0) then
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
		elseif tooltipType == TOOLTIP_BUILDING then
			for realmName, realmData in pairsByKeys(globalDb.data) do
				row = tooltip:AddLine()
				tooltip:SetCell(row, 1, ("%s"):format(getColoredString(("%s"):format(realmName), colors.lightGray)), nil, "LEFT", 3)

				row = tooltip:AddLine(" ")
				AddSeparator(tooltip)

				for playerName, playerData in pairsByKeys(realmData) do		
					local numBuildings, numWorkordersInProgress, numWorkordersAvailable

					row = tooltip:AddLine(" ")
					row = tooltip:AddLine()

					tooltip:SetCell(row, 1, playerData.expandedBuildings and ICON_CLOSE or ICON_OPEN)
					tooltip:SetCell(row, 2, ("%s"):format(getColoredUnitName(playerData.info.playerName, playerData.info.playerClass)))
					tooltip:SetCell(row, 3, ("%s %s"):format(ICON_CURRENCY, BreakUpLargeNumbers(playerData.currencyAmount or 0)))

					if #playerData.buildings > 0 then
						row = tooltip:AddLine(" ")
						AddSeparator(tooltip)

						row = tooltip:AddLine(" ")
						tooltip:SetLineColor(row, colors.darkGray.r, colors.darkGray.g, colors.darkGray.b, 1)


						for buildingID, buildingData in pairs(playerData.buildings) do
							-- Display building and Workorder data
							row = tooltip:AddLine(" ")					
							tooltip:SetLineColor(row, colors.darkGray.r, colors.darkGray.g, colors.darkGray.b, 1)

							tooltip:SetCell(row, 2, buildingData.name, nil, "LEFT", 2)

							if buildingData.isBuilding then
								local timeLeft = buildingData.duration - (now - buildingData.buildTime)

								tooltip:SetCell(row, 4, ("%s%s"):format(
									getColoredString(("%s | "):format(FormattedSeconds(buildingData.buildTime)), colors.lightGray),
									getColoredString(FormattedSeconds(timeLeft), colors.white)
								), nil, "RIGHT", 3)
							else
								if buildingData.shipment.shipmentsReady and buildingData.shipment.shipmentsTotal and buildingData.shipment.shipmentsReady < buildingData.shipment.shipmentsTotal then
									-- Unfinished shipments! - display remaining time till next/last shipment
									local openShipments = buildingData.shipment.shipmentsTotal - buildingData.shipment.shipmentsReady

									local timeLeft = buildingData.shipment.duration - (now - buildingData.creationTime)									
									
									print(("openShipments: %s"):format(openShipments))
									print(("timeLeft: %s"):format(FormattedSeconds(timeLeft)))							

									if (openShipments == 1) then

									else
										local timeLeftTotal = timeLeft * openShipments

										print(("timeLeftTotal: %s"):format(FormattedSeconds(timeLeftTotal)))							
									end
									

											
								end
							end
							tooltip:SetCell(row, 4, buildingData.name, nil, "LEFT", 1)
							tooltip:SetCell(row, 5, buildingData.name, nil, "LEFT", 1)
							tooltip:SetCell(row, 6, buildingData.name, nil, "LEFT", 1)
							tooltip:SetCell(row, 7, buildingData.name, nil, "LEFT", 1)

						end

					end

				end			
			end
			row = tooltip:AddLine(" ")	

		end

	  	tooltip:Show()		
	end

	function ldb_object_building:OnEnter()
		DrawTooltip(self, TOOLTIP_BUILDING)
	end

	function ldb_object_building:OnLeave()
	end	

	function ldb_object_mission:OnEnter()
		DrawTooltip(self, TOOLTIP_MISSION)
	end
 
	function ldb_object_mission:OnLeave()
	end

	function ldb_object_mission:OnClick(button)
		if button == "LeftButton" then
			Garrison:LoadDependencies()

			if GarrisonLandingPage then
				if (not GarrisonLandingPage:IsShown()) then
					ShowUIPanel(GarrisonLandingPage);
				else
					HideUIPanel(GarrisonLandingPage);
				end
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


function Garrison:UpdateUnknownMissions(missionsLoaded)
	local activeMissions = {}

	for key,garrisonMission in pairs(C_Garrison.GetInProgressMissions()) do
		activeMissions[garrisonMission.missionID] = true
		-- Mission not found in Database
		if not globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID] 
			or globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID].start == -1 then
			local mission = {
				id = garrisonMission.missionID,
				name = garrisonMission.name,
				start = -1,
				duration = garrisonMission.durationSeconds,
				notification = 0,
				timeLeft = garrisonMission.timeLeft,
				type = garrisonMission.type,
			}
			globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID] = mission

			-- debugPrint("Update untracked Mission: "..garrisonMission.missionID)
		end
	end

	if missionsLoaded then
		-- cleanup unknown missions
		local missionID
		for missionID, _ in pairs(globalDb.data[charInfo.realmName][charInfo.playerName].missions) do
			if not activeMissions[missionID] then
				globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID] = nil
				debugPrint("Removed unknown Mission: "..missionID)
			end
		end
	end

	for key,garrisonMission in pairs(C_Garrison.GetCompleteMissions()) do
		if (globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID]) then			
			if globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID].start == -1 then
				debugPrint("Finished Mission (Loop): "..garrisonMission.missionID)
				globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID].start = 0
			end	
		else
			debugPrint("Unknown Mission (Loop): "..garrisonMission.missionID)
		end		
	end

end

function Garrison:UpdateBuildingInfo()

	local buildings = C_Garrison.GetBuildings();

	-- Clear old datag
	globalDb.data[charInfo.realmName][charInfo.playerName].buildings = {}

	for i = 1, #buildings do

		local buildingID = buildings[i].buildingID;
		local plotID = buildings[i].plotID		
		
		if plotID then			 
			local id, name, texPrefix, icon, rank, isBuilding, timeStart, buildTime, canActivate, canUpgrade, isPrebuilt = C_Garrison.GetOwnedBuildingInfoAbbrev(plotID);			      

			globalDb.data[charInfo.realmName][charInfo.playerName].buildings[i] = {
				id = id,
				name = name,
				texPrefix = texPrefix,
				icon = icon,
				rank = rank,
				isBuilding = isBuilding,
				timeStart = timeStart,
				buildTime = buildTime,				
				shipment = {}
			}			
		end

		if ( buildingID) then
			local name, texture, shipmentCapacity, shipmentsReady, shipmentsTotal, creationTime, duration, timeleftString, itemName, itemIcon, itemQuality, itemID = C_Garrison.GetLandingPageShipmentInfo(buildingID);

			globalDb.data[charInfo.realmName][charInfo.playerName].buildings[i].shipment = {
				name = name,
				texture = texture,
				shipmentCapacity = shipmentCapacity,
				shipmentsReady = shipmentsReady,
				shipmentsTotal = shipmentsTotal,
				creationTime = creationTime,
				duration = duration,
				timeleftString = timeleftString,
				itemName = itemName,
				itemQuality = itemQuality,
				itemID = itemID
			}
		end
	end	
end

function Garrison:GARRISON_MISSION_COMPLETE_RESPONSE(event, missionID, canComplete, succeeded)
	if (globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID]) then				
		debugPrint("Removed Mission: "..missionID.." ("..event..")")
		globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID] = nil
	else
		debugPrint("Unknown Mission: "..missionID.." ("..event..")")
	end

	Garrison:Update()
end

function Garrison:GARRISON_MISSION_STARTED(event, missionID)

	for key,garrisonMission in pairs(C_Garrison.GetInProgressMissions()) do
		if (garrisonMission.missionID == missionID) then
			local mission = {
				id = garrisonMission.missionID,
				name = garrisonMission.name,
				start = time(),
				duration = garrisonMission.durationSeconds,
				notification = 0,
				timeLeft = garrisonMission.timeLeft,
				type = garrisonMission.type,
			}
			globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID] = mission
			debugPrint("Added Mission: "..missionID)
		end
	end

	Garrison:Update()
end

function Garrison:GARRISON_MISSION_FINISHED(event, missionID)
	if (globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID]) then
		debugPrint("Finished Mission: "..missionID)
		if globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID].start == -1 then
			globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID].start = 0
		end	
	else
		debugPrint("Unknown Mission: "..missionID)
	end

	Garrison:Update()
end

function Garrison:GARRISON_SHOW_LANDING_PAGE(...)
	Garrison:UpdateConfig()

	Garrison:UpdateUnknownMissions(true)
end

function Garrison:GARRISON_MISSION_NPC_OPENED(...)
	Garrison:UpdateConfig()

	Garrison:UpdateUnknownMissions(true)
end


function Garrison:UpdateCurrency()
	local _, amount, _ = GetCurrencyInfo(GARRISON_CURRENCY);
	globalDb.data[charInfo.realmName][charInfo.playerName].currencyAmount = amount

	Garrison:Update()
end

function Garrison:Update()	
	Garrison:UpdateUnknownMissions(false)

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

	ldb_object_mission.text = getColoredTooltipString(ldbText, conditionTable)
	for name, val in pairs(conditionTable) do
		if (val.condition) then		
			ldb_object_mission.iconR, ldb_object_mission.iconG, ldb_object_mission.iconB = val.color.r, val.color.g, val.color.b
		end
	end	

	-- First update 
	if delayedInit then
		addonInitialized = true
	end
end

function Garrison:CheckAddonLoaded(event, addon)	
	if addon == "Blizzard_GarrisonUI" then
		-- Addon Loaded: Garrison UI - Hook AlertFrame
		debugPrint("Event: Blizzard_GarrisonUI loaded")
		Garrison:OnDependencyLoaded()		
		self:UnregisterEvent("ADDON_LOADED")
	end		
end

function Garrison:GarrisonMissionAlertFrame_ShowAlert(missionID)
	if configDb.notification.hideBlizzardNotificationMission then
		debugPrint("Blizzard notification hidden: "..missionID)
	else
		debugPrint("Show blizzard notification"..missionID)
		self.hooks.GarrisonMissionAlertFrame_ShowAlert(missionID)
	end
end

function Garrison:GarrisonBuildingAlertFrame_ShowAlert(name)
	if configDb.notification.hideBlizzardNotificationBuilding then
		debugPrint("Blizzard notification hidden: "..name)
	else
		debugPrint("Show blizzard notification"..name)
		self.hooks.GarrisonBuildingAlertFrame_ShowAlert(name)
	end
end



function Garrison:OnInitialize()	
	local _, _, _, tocversion = _G.GetBuildInfo()
	if (tocversion < 60000) then
		print("BrokerGarrison requires WoW 6.0 / Warlords of Draenor")
		return
	end

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
			buildings = {},
			expanded = true,
			info = charInfo,
			currencyAmount = 0,
		}
	end

	if (not globalDb.data[charInfo.realmName][charInfo.playerName]["missions"]) then		
		globalDb.data[charInfo.realmName][charInfo.playerName]["missions"] = {}
	end
	if (not globalDb.data[charInfo.realmName][charInfo.playerName]["buildings"]) then		
		globalDb.data[charInfo.realmName][charInfo.playerName]["buildings"] = {}
	end	

	self.getColoredUnitName = getColoredUnitName
	self.pairsByKeys = pairsByKeys
	self.debugPrint = debugPrint
	self.charInfo = charInfo

	self:SetupOptions()

	Garrison:SetSinkStorage(configDb.notification.sink)

	Toast:Register(TOAST_MISSION_COMPLETE, toastMissionComplete)

	Garrison:UpdateConfig()	

	self:RegisterEvent("GARRISON_MISSION_STARTED", "GARRISON_MISSION_STARTED")
	self:RegisterEvent("GARRISON_MISSION_COMPLETE_RESPONSE", "GARRISON_MISSION_COMPLETE_RESPONSE")
	self:RegisterEvent("GARRISON_MISSION_FINISHED", "GARRISON_MISSION_FINISHED")
	
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "UpdateCurrency")	
	self:RegisterEvent("GARRISON_SHOW_LANDING_PAGE", "GARRISON_SHOW_LANDING_PAGE")
	self:RegisterEvent("GARRISON_MISSION_NPC_OPENED", "GARRISON_MISSION_NPC_OPENED")

	self:RegisterEvent("ADDON_LOADED", "CheckAddonLoaded")

	self:RawHook("GarrisonMissionAlertFrame_ShowAlert", true)
	self:RawHook("GarrisonBuildingAlertFrame_ShowAlert", true)

	timers.icon_update = Garrison:ScheduleRepeatingTimer("Update", 60)
	timers.icon_update = Garrison:ScheduleTimer("DelayedUpdate", 5)
	
end


function Garrison:DelayedUpdate()	
	delayedInit = true
	Garrison:UpdateCurrency()	

	Garrison:UpdateBuildingInfo()
end


