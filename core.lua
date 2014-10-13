local ADDON_NAME, private = ...

local LibStub = _G.LibStub

local BrokerGarrison = LibStub('AceAddon-3.0'):NewAddon(ADDON_NAME, 'AceConsole-3.0', "AceHook-3.0", 'AceEvent-3.0', 'AceTimer-3.0', "LibSink-2.0")
local Garrison = BrokerGarrison

Garrison.versionString = GetAddOnMetadata(ADDON_NAME, "Version");
Garrison.cleanName = "Broker Garrison"

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local L = LibStub:GetLibrary( "AceLocale-3.0" ):GetLocale(ADDON_NAME)
local LibQTip = LibStub('LibQTip-1.0')
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local Toast = LibStub("LibToast-1.0")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")

-- LUA
local _G = getfenv(0)
local math, string, table, print, pairs, ipairs = _G.math, _G.string, _G.table, _G.print, _G.pairs, _G.ipairs
local tonumber, strupper, select, time = _G.tonumber, _G.strupper, _G.select, _G.time
-- Blizzard
local BreakUpLargeNumbers, C_Garrison, GetCurrencyInfo = _G.BreakUpLargeNumbers, _G.C_Garrison, _G.GetCurrencyInfo
-- UI Elements
local InterfaceOptionsFrameAddOns, UIParentLoadAddOn, GarrisonLandingPage = _G.InterfaceOptionsFrameAddOns, _G.UIParentLoadAddOn, _G.GarrisonLandingPage
local GarrisonMissionFrame, GarrisonLandingPageMinimapButton = _G.GarrisonMissionFrame ,_G.GarrisonLandingPageMinimapButton
-- UI Functions
local ShowUIPanel, HideUIPanel, CreateFont, PlaySoundFile = _G.ShowUIPanel, _G.HideUIPanel, _G.CreateFont, _G.PlaySoundFile
-- UI Hooks
local OptionsListButtonToggle_OnClick = _G.OptionsListButtonToggle_OnClick

local garrisonDb, configDb, globalDb, DEFAULT_FONT

-- Constants
local TYPE_BUILDING = "building"
local TYPE_MISSION = "mission"
local TYPE_SHIPMENT = "shipment"

Garrison.TYPE_BUILDING = TYPE_BUILDING
Garrison.TYPE_MISSION = TYPE_MISSION
Garrison.TYPE_SHIPMENT = TYPE_SHIPMENT

local addonInitialized = false
local delayedInit = false
local CONFIG_VERSION = 1
local DEBUG = true
local timers = {}
Garrison.timers = timers

-- Garrison Functions
local debugPrint, pairsByKeys, formatRealmPlayer, tableSize, isCurrentChar, getColoredString, getColoredUnitName, formattedSeconds, getIconString

local colors = {
	green = {r=0, g=1, b=0, a=1},
	white = {r=1, g=1, b=1, a=1},
	lightGray = {r=0.25, g=0.25, b=0.25, a=1},
	darkGray = {r=0.1, g=0.1, b=0.1, a=1},
}
Garrison.colors = colors
Garrison.GARRISON_CURRENCY = 824

local COLOR_TABLE = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
Garrison.COLOR_TABLE = COLOR_TABLE

local COMPLETED_PATTERN = "^[^%d]*(0)[^%d]*$"

local ICON_CURRENCY = string.format("\124TInterface\\Icons\\Inv_Garrison_Resource:%d:%d:1:0\124t", 16, 16)

local ICON_OPEN = string.format("\124TInterface\\AddOns\\Broker_Garrison\\Media\\Open:%d:%d:1:0\124t", 16, 16)
local ICON_CLOSE = string.format("\124TInterface\\AddOns\\Broker_Garrison\\Media\\Close:%d:%d:1:0\124t", 16, 16)

local ICON_OPEN_DOWN = ICON_OPEN
local ICON_CLOSE_DOWN = ICON_CLOSE

local TOAST_MISSION_COMPLETE = "BrokerGarrisonMissionComplete"
local TOAST_BUILDING_COMPLETE = "BrokerGarrisonBuildingComplete"
local TOAST_SHIPMENT_COMPLETE = "BrokerGarrisonShipmentComplete"

local DB_DEFAULTS = {
	profile = {
		general = {
			mission = {
				showCurrency = true,
				showProgress = true,
				showComplete = true,
			},
			building = {
				hideBuildingWithoutShipments = false,
			},
			hideGarrisonMinimapButton = false,
		},
		notification = {
			sink = {},
			['**'] = {
				enabled = true,
				repeatOnLoad = false,
				toastEnabled = true,
				toastPersistent = true,
				hideBlizzardNotification = true,
				hideMinimapPulse = false,
			}
		},
		tooltip = {
			scale = 1,
			autoHideDelay = 0.1,
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
Garrison.charInfo = charInfo

local location = {
	garrisonMapName = _G.GetMapNameByID(976),
	zoneName = nil,
	inGarrison = nil,
}
Garrison.location = location

-- LDB init
local ldb_object_mission = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME.."Mission",
  { type = "data source",
   label = L["Garrison: Missions"],
	icon = "Interface\\Icons\\Inv_Garrison_Resource",
	text = L["Garrison: Missions"],
   })

local ldb_object_building = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME.."Building",
  { type = "data source",
   label = L["Garrison: Buildings"],
	icon = "Interface\\Icons\\Inv_Garrison_Resource",
	text = L["Garrison: Buildings"],
   })


function Garrison:OnDependencyLoaded()
	GarrisonLandingPage = _G.GarrisonLandingPage
	GarrisonMissionFrame = _G.GarrisonMissionFrame
end

function Garrison:LoadDependencies()
	if not GarrisonMissionFrame or not GarrisonLandingPage then
		debugPrint("Loading Blizzard_GarrisonUI...")
		if UIParentLoadAddOn("Blizzard_GarrisonUI") then
			Garrison:OnDependencyLoaded()
		end
	end
end
-- Helper Functions

local function toastCallback (callbackType, mouseButton, buttonDown, payload)

	local missionData = payload[1]

	if callbackType == "primary" then
		debugPrint("OK: "..payload[1].id.." ("..payload[1].name..")")
	end
	if callbackType == "secondary" then
		debugPrint("Dismiss: "..payload[1].id.." ("..payload[1].name..")")
		missionData.notification = 2 -- Mission dismissed, never show again
		missionData.notificationDismissed = true
	end
end

local function toastMissionComplete (toast, text, missionData)
	if configDb.notification.mission.toastPersistent then
		toast:MakePersistent()
	end
	toast:SetTitle(L["Garrison: Mission complete"])
	toast:SetFormattedText(getColoredString(text, colors.green))
	toast:SetIconTexture([[Interface\Icons\Inv_Garrison_Resource]])
	if configDb.notification.mission.extendedToast then
		toast:SetPrimaryCallback(_G.OKAY, toastCallback)
		toast:SetSecondaryCallback(L["Dismiss"], toastCallback)
		toast:SetPayload(missionData)
	end
end

local function toastBuildingComplete (toast, text, buildingData)
	if configDb.notification.building.toastPersistent then
		toast:MakePersistent()
	end
	toast:SetTitle(L["Garrison: Building complete"])
	toast:SetFormattedText(getColoredString(text, colors.green))
	toast:SetIconTexture(buildingData.icon)
	if configDb.notification.building.extendedToast then
		toast:SetPrimaryCallback(_G.OKAY, toastCallback)
		toast:SetSecondaryCallback(L["Dismiss"], toastCallback)
		toast:SetPayload(buildingData)
	end
end

local function toastShipmentComplete (toast, text, shipmentData)
	if configDb.notification.shipment.toastPersistent then
		toast:MakePersistent()
	end
	toast:SetTitle(L["Garrison: Shipment complete"])
	toast:SetFormattedText(getColoredString(text, colors.green))
	toast:SetIconTexture(shipmentData.texture)
	if configDb.notification.shipment.extendedToast then
		toast:SetPrimaryCallback(_G.OKAY, toastCallback)
		toast:SetSecondaryCallback(L["Dismiss"], toastCallback)
		toast:SetPayload(shipmentData)
	end
end



function Garrison:SendNotification(paramCharInfo, data, notificationType)

	local retVal = false

	if delayedInit then
		if configDb.notification[notificationType].enabled then
			if  (not data.notification or
				(data.notification == 0) or
				(not addonInitialized and configDb.notification[notificationType].repeatOnLoad and not data.notificationDismissed) or
				(notificationType == TYPE_SHIPMENT and (not data.notificationValue or data.shipmentsReadyEstimate > data.notificationValue))
			) then

				local notificationText, toastName, toastText, soundName, toastEnabled, playSound

				toastText = ("%s\n\n%s"):format(formatRealmPlayer(paramCharInfo, true), data.name)
				toastEnabled = configDb.notification[notificationType].toastEnabled
				playSound = configDb.notification[notificationType].PlaySound
				soundName = configDb.notification[notificationType].SoundName or "None"

				if (notificationType == TYPE_MISSION) then
					notificationText = (L["Mission complete (%s): %s"]):format(formatRealmPlayer(paramCharInfo, false), data.name)
					toastName = TOAST_MISSION_COMPLETE
				elseif (notificationType == TYPE_BUILDING) then
					notificationText = (L["Building complete (%s): %s"]):format(formatRealmPlayer(paramCharInfo, false), data.name)
					toastName = TOAST_BUILDING_COMPLETE
				elseif (notificationType == TYPE_SHIPMENT) then
					toastText = ("%s\n\n%s (%s / %s)"):format(formatRealmPlayer(paramCharInfo, true), data.name, data.shipmentsReadyEstimate, data.shipmentsTotal)
					notificationText = (L["Shipment complete (%s): %s (%s / %s)"]):format(formatRealmPlayer(paramCharInfo, false), data.name, data.shipmentsReadyEstimate, data.shipmentsTotal)
					toastName = TOAST_SHIPMENT_COMPLETE

					data.notificationValue = data.shipmentsReadyEstimate
				end

				debugPrint(notificationText)

				self:Pour(notificationText, colors.green.r, colors.green.g, colors.green.b)

				if toastEnabled then
					Toast:Spawn(toastName, toastText, data)
				end

				if playSound then
					PlaySoundFile(LSM:Fetch("sound", soundName))
				end

				data.notification = 1

				retVal = true
			end
		end
	end

	return retVal
end

function Garrison:GetPlayerMissionCount(paramCharInfo, missionCount, missions)
	local now = time()

	local numMissionsPlayer = tableSize(missions)

	if numMissionsPlayer > 0 then
		missionCount.total = missionCount.total + numMissionsPlayer

		for missionID, missionData in pairs(missions) do
			local timeLeft = missionData.duration - (now - missionData.start)

			-- Do mission handling while we are at it
			if  (timeLeft < 0 and missionData.start == -1) then
				-- Detect completed mission


				-- Deprecated - should be detected on finished event
				local parsedTimeLeft = string.match(missionData.timeLeft, COMPLETED_PATTERN)
				if (parsedTimeLeft == "0") then
					-- 1 * 0 found in string -> assuming mission complete
					missionData.start = 0
				end
			end

			-- Count
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

			if (timeLeft < 0 and missionData.start >= 0) then
				Garrison:SendNotification(paramCharInfo, missionData, TYPE_MISSION)
			end
		end

	end
end


function Garrison:DoShipmentMagic(shipmentData, paramCharInfo)
	local now = time()

	local shipmentsReady, shipmentsInProgress, shipmentsAvailable
	local timeLeftNext = 0
	local timeLeftTotal = 0
	local shipmentsAvailable = shipmentData.shipmentCapacity

	if shipmentData and shipmentData.shipmentsTotal then
		local openShipments = shipmentData.shipmentsTotal - shipmentData.shipmentsReady

		local timeDiff = (now - shipmentData.creationTime)
		local shipmentsReadyByTime = 0
		if shipmentData.duration and shipmentData.duration > 0 then
			shipmentsReadyByTime = math.floor(timeDiff / shipmentData.duration)
		end

		if isCurrentChar(paramCharInfo) then
			shipmentsReady = shipmentData.shipmentsReady
		else
			-- Only for other chars
			shipmentsReady = math.min(shipmentData.shipmentsReady + shipmentsReadyByTime, shipmentData.shipmentsTotal)
		end
		shipmentsInProgress = shipmentData.shipmentsTotal - shipmentsReady
		shipmentsAvailable = shipmentData.shipmentCapacity - shipmentData.shipmentsTotal

		timeLeftNext = shipmentData.duration - timeDiff

		if shipmentsInProgress == 0 then
			timeLeftNext = 0
		else
			timeLeftNext = timeLeftNext + (shipmentData.duration * shipmentsReadyByTime)
			timeLeftTotal = timeLeftNext + (shipmentData.duration * (shipmentsInProgress - 1))
		end

		return shipmentsReady, shipmentsInProgress, shipmentsAvailable, timeLeftNext, timeLeftTotal
	else
		return 0, 0, shipmentsAvailable, 0, 0
	end
end

function Garrison:GetPlayerBuildingCount(paramCharInfo, buildingCount, buildings)
	local now = time()

	local numBuildingsPlayer = tableSize(buildings)

	if numBuildingsPlayer > 0 then
		buildingCount.total = buildingCount.total + numBuildingsPlayer

		for plotID, buildingData in pairs(buildings) do

			if buildingData.isBuilding or buildingData.canActivate then
				-- Check for building complete
				local timeLeft = buildingData.buildTime - (now - buildingData.timeStart)

				if buildingData.canActivate or timeLeft < 0 then
					Garrison:SendNotification(paramCharInfo, buildingData, TYPE_BUILDING)
					buildingCount.complete = buildingCount.complete + 1
					buildingData.canActivate = true

				else
					buildingCount.building = buildingCount.building + 1
				end	
			else
				buildingCount.active = buildingCount.active + 1

				local shipmentData = buildingData.shipment

				-- Check for work orders
				if shipmentData and shipmentData.name and shipmentData.shipmentsTotal then

					local shipmentsReady, shipmentsInProgress, shipmentsAvailable = Garrison:DoShipmentMagic(shipmentData, paramCharInfo)

					shipmentData.shipmentsReadyEstimate = shipmentsReady

					if shipmentData.shipmentsReadyEstimate > 0 then						
						Garrison:SendNotification(paramCharInfo, shipmentData, TYPE_SHIPMENT)
					end

					if shipmentData.notificationValue and shipmentData.shipmentsReadyEstimate < shipmentData.notificationValue then
							shipmentData.notificationValue = shipmentData.shipmentsReadyEstimate
					end

					buildingCount.shipmentsInProgress = buildingCount.shipmentsInProgress + shipmentsInProgress
					buildingCount.shipmentsReady = buildingCount.shipmentsReady + shipmentsReady
					buildingCount.shipmentsTotal = buildingCount.shipmentsTotal + shipmentData.shipmentsTotal
					buildingCount.shipmentsAvailable = buildingCount.shipmentsAvailable + shipmentsAvailable
				elseif shipmentData and shipmentData.name then
					buildingCount.shipmentsAvailable = buildingCount.shipmentsAvailable + shipmentData.shipmentCapacity
				end
			end
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

	--return missionCount.total, missionCount.inProgress, missionCount.complete
	return missionCount
end

function Garrison:GetBuildingCount(paramCharInfo)
	local buildingCount = {
		total = 0,
		building = 0,
		complete = 0,
		active = 0,
		shipmentsInProgress = 0,
		shipmentsReady = 0,
		shipmentsTotal = 0,
		shipmentsAvailable = 0,
	}

	if paramCharInfo then
		Garrison:GetPlayerBuildingCount(paramCharInfo, buildingCount, globalDb.data[paramCharInfo.realmName][paramCharInfo.playerName].buildings)
	else
		for realmName, realmData in pairs(globalDb.data) do
			for playerName, playerData in pairs(realmData) do
				Garrison:GetPlayerBuildingCount(playerData.info, buildingCount, playerData.buildings)
			end
		end
	end

	--return buildingCount.total, buildingCount.building, buildingCount.active, buildingCount.shipmentInProgress, buildingCount.shipmentReady, buildingCount.shipmentTotal
	return buildingCount
end


function Garrison:UpdateConfig()
	if GarrisonLandingPageMinimapButton then
		if GarrisonLandingPageMinimapButton:IsShown() then
			if configDb.general.hideGarrisonMinimapButton then
				GarrisonLandingPageMinimapButton:Hide()
			end
		else
			if not configDb.general.hideGarrisonMinimapButton then
				GarrisonLandingPageMinimapButton:Show()
			end
		end
	end
end

local DrawTooltip
do
	local NUM_TOOLTIP_COLUMNS = 9
	local tooltipRegistry = {}	
	local LDB_anchor
	local tooltipType
	local tooltip
	local locked = false

	local function ExpandButton_OnMouseUp(tooltip_cell, realm_and_character)
		local realm, character_name = (":"):split(realm_and_character, 2)

		if tooltipType == TYPE_MISSION then
			globalDb.data[realm][character_name].missionsExpanded = not globalDb.data[realm][character_name].missionsExpanded
		else
			globalDb.data[realm][character_name].buildingsExpanded = not globalDb.data[realm][character_name].buildingsExpanded
		end

		DrawTooltip(LDB_anchor, tooltipType)
	end

	local function ExpandButton_OnMouseDown(tooltip_cell, is_expanded)
		local line, column = tooltip_cell:GetPosition()
		tooltip:SetCell(line, column, is_expanded and ICON_CLOSE_DOWN or ICON_OPEN_DOWN)
	end

	local function Tooltip_OnRelease_Mission(arg)
		--debugPrint(arg)
		tooltipRegistry[TYPE_MISSION] = nil
		--tooltip = nil
		LDB_anchor = nil
		tooltipType = nil		
	end

	local function Tooltip_OnRelease_Building(arg)
		--debugPrint(arg)
		tooltipRegistry[TYPE_BUILDING] = nil
		--tooltip = nil
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
		tooltip	= tooltipRegistry[tooltipType]

		locked = true

		if not tooltip then
			tooltipRegistry[tooltipType] = LibQTip:Acquire("BrokerGarrisonTooltip-"..paramTooltipType, NUM_TOOLTIP_COLUMNS, "LEFT", "LEFT", "LEFT", "LEFT", "LEFT", "LEFT", "LEFT", "LEFT", "LEFT")
			tooltip = tooltipRegistry[tooltipType]

			if tooltipType == TYPE_MISSION then
				tooltip.OnRelease = Tooltip_OnRelease_Mission
			elseif tooltipType == TYPE_BUILDING then
				tooltip.OnRelease = Tooltip_OnRelease_Building
			end
			tooltip:EnableMouse(true)
			tooltip:SmartAnchorTo(anchor_frame)
			tooltip:SetAutoHideDelay(configDb.tooltip.autoHideDelay or 0.1, LDB_anchor)
			tooltip:SetScale(configDb.tooltip.scale or 1)
			local font = LSM:Fetch("font", configDb.tooltip.fontName or DEFAULT_FONT)
			local fontSize = configDb.tooltip.fontSize or 12

			local tmpFont = CreateFont("BrokerGarrisonTooltipFont")
			tmpFont:SetFont(font, fontSize)
			tooltip:SetFont(tmpFont)
		end

		local now = time()
		local name, row, realmName, realmData, playerName, playerData, missionID, missionData

		tooltip:Clear()
		tooltip:SetCellMarginH(0)

		tooltip:SetCellMarginV(0)

		if tooltipType == TYPE_MISSION then
			for realmName, realmData in pairsByKeys(globalDb.data) do
				row = tooltip:AddLine()
				tooltip:SetCell(row, 1, ("%s"):format(getColoredString(("%s"):format(realmName), colors.lightGray)), nil, "LEFT", 3)

				row = tooltip:AddLine(" ")
				AddSeparator(tooltip)

				for playerName, playerData in pairsByKeys(realmData) do

					local missionCount = Garrison:GetMissionCount(playerData.info)

					row = tooltip:AddLine(" ")
					row = tooltip:AddLine()


					tooltip:SetCell(row, 1, playerData.missionsExpanded and ICON_CLOSE or ICON_OPEN)
					tooltip:SetCell(row, 2, ("%s"):format(getColoredUnitName(playerData.info.playerName, playerData.info.playerClass)))
					tooltip:SetCell(row, 3, ("%s %s"):format(ICON_CURRENCY, BreakUpLargeNumbers(playerData.currencyAmount or 0)))

					tooltip:SetCell(row, 4, getColoredString((L["Total: %s"]):format(missionCount.total), colors.lightGray))
					tooltip:SetCell(row, 5, getColoredString((L["In Progress: %s"]):format(missionCount.inProgress), colors.lightGray))
					tooltip:SetCell(row, 6, getColoredString((L["Complete: %s"]):format(missionCount.complete), colors.lightGray))

					tooltip:SetCellScript(row, 1, "OnMouseUp", ExpandButton_OnMouseUp, ("%s:%s"):format(realmName, playerName))
					tooltip:SetCellScript(row, 1, "OnMouseDown", ExpandButton_OnMouseDown, playerData.missionsExpanded)

					if playerData.missionsExpanded and missionCount.total > 0 then
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
									getColoredString(("%s | "):format(formattedSeconds(missionData.duration)), colors.lightGray),
									getColoredString("~"..missionData.timeLeft, colors.white)
								), nil, "RIGHT", 3)
							elseif (missionData.start == 0 or timeLeft < 0) then
								tooltip:SetCell(row, 4, getColoredString(L["Complete!"], colors.green), nil, "RIGHT", 3)
							else
								tooltip:SetCell(row, 4, ("%s%s"):format(
									getColoredString(("%s | "):format(formattedSeconds(missionData.duration)), colors.lightGray),
									getColoredString(formattedSeconds(timeLeft), colors.white)
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
		elseif tooltipType == TYPE_BUILDING then
			for realmName, realmData in pairsByKeys(globalDb.data) do
				row = tooltip:AddLine()
				tooltip:SetCell(row, 1, ("%s"):format(getColoredString(("%s"):format(realmName), colors.lightGray)), nil, "LEFT", 3)

				row = tooltip:AddLine(" ")
				AddSeparator(tooltip)

				for playerName, playerData in pairsByKeys(realmData) do
					local buildingCount = Garrison:GetBuildingCount(playerData.info)

					row = tooltip:AddLine(" ")
					row = tooltip:AddLine()

					tooltip:SetCell(row, 1, playerData.buildingsExpanded and ICON_CLOSE or ICON_OPEN)
					tooltip:SetCell(row, 2, ("%s"):format(getColoredUnitName(playerData.info.playerName, playerData.info.playerClass)))
					tooltip:SetCell(row, 3, ("%s %s"):format(ICON_CURRENCY, BreakUpLargeNumbers(playerData.currencyAmount or 0)))

					tooltip:SetCell(row, 4, getColoredString((L["Total: %s"]):format(buildingCount.total), colors.lightGray))

					tooltip:SetCellScript(row, 1, "OnMouseUp", ExpandButton_OnMouseUp, ("%s:%s"):format(realmName, playerName))
					tooltip:SetCellScript(row, 1, "OnMouseDown", ExpandButton_OnMouseDown, playerData.buildingsExpanded)

					if playerData.buildingsExpanded and buildingCount.total > 0 then
						row = tooltip:AddLine(" ")
						AddSeparator(tooltip)

						row = tooltip:AddLine(" ")
						tooltip:SetLineColor(row, colors.darkGray.r, colors.darkGray.g, colors.darkGray.b, 1)


						local sortedBuildingTable = Garrison.sort(playerData.buildings, "canActivate,d", "isBuilding,a", "shipment.shipmentsTotal,d", "shipment.shipmentCapacity,d", "name,a")
						--local sortedBuildingTable = Garrison.sort(playerData.buildings, "name,a")

						for plotID, buildingData in sortedBuildingTable do

							if not configDb.general.building.hideBuildingWithoutShipments or 
								(buildingData.isBuilding or buildingData.canActivate) or
								(buildingData.shipment and buildingData.shipment.shipmentCapacity) then 							

								-- Display building and Workorder data
								row = tooltip:AddLine(" ")
								tooltip:SetLineColor(row, colors.darkGray.r, colors.darkGray.g, colors.darkGray.b, 1)


								local rank
								if buildingData.isBuilding or buildingData.canActivate then
									rank = string.format("%s->%s", (buildingData.rank - 1), buildingData.rank)
								else
									rank = buildingData.rank
								end

								tooltip:SetCell(row, 1, getIconString(buildingData.icon, 16), nil, "LEFT", 1)
								tooltip:SetCell(row, 2, buildingData.name, nil, "LEFT", 1)
								tooltip:SetCell(row, 3, rank, nil, "LEFT", 1) -- TODO: Icon

								local timeLeftBuilding = buildingData.buildTime - (now - buildingData.timeStart)

								if ((buildingData.isBuilding and timeLeftBuilding <= 0) or buildingData.canActivate) then
									tooltip:SetCell(row, 4, getColoredString(L["Complete!"], colors.green), nil, "RIGHT", 3)
								elseif buildingData.isBuilding then
									tooltip:SetCell(row, 6, ("%s%s"):format(
										getColoredString(("%s | "):format(formattedSeconds(buildingData.buildTime)), colors.lightGray),
										getColoredString(formattedSeconds(timeLeftBuilding), colors.white)
									), nil, "RIGHT", 1)
								elseif buildingData.shipment and buildingData.shipment.name then
									local shipmentData = buildingData.shipment

									local shipmentsReady, shipmentsInProgress, shipmentsAvailable, timeLeftNext, timeLeftTotal = Garrison:DoShipmentMagic(shipmentData, playerData.info)

									tooltip:SetCell(row, 4, shipmentsInProgress, nil, "LEFT", 1)
									tooltip:SetCell(row, 5, shipmentsReady, nil, "LEFT", 1)

									if timeLeftNext > 0 then
										tooltip:SetCell(row, 6, formattedSeconds(timeLeftNext), nil, "LEFT", 1)

										if timeLeftTotal > 0 then
											tooltip:SetCell(row, 7, formattedSeconds(timeLeftTotal), nil, "LEFT", 1)
										end
									end

									tooltip:SetCell(row, 9, shipmentsAvailable, nil, "LEFT", 1)

								else
									tooltip:SetCell(row, 4, "-", nil, "LEFT", 1)
									tooltip:SetCell(row, 5, "-", nil, "LEFT", 1)
									tooltip:SetCell(row, 9, "-", nil, "LEFT", 1)
								end

							end
						end
					end
				end
			end
			row = tooltip:AddLine(" ")

		end

	  	tooltip:Show()

	  	locked = false
	end

	function ldb_object_building:OnEnter()
		DrawTooltip(self, TYPE_BUILDING)
	end

	function ldb_object_building:OnLeave()
		
	end

	function ldb_object_mission:OnEnter()
		DrawTooltip(self, TYPE_MISSION)
	end

	function ldb_object_mission:OnLeave()

	end

	local function onclick(button)
		if button == "LeftButton" then
			Garrison:LoadDependencies()

			if GarrisonLandingPage then
				if (not GarrisonLandingPage:IsShown()) then
					ShowUIPanel(GarrisonLandingPage)
				else
					HideUIPanel(GarrisonLandingPage)
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

	function ldb_object_mission:OnClick(button)
		onclick(button)
	end

	function ldb_object_building:OnClick(button)
		onclick(button)
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

--function Garrison:UpdateShipmentInfo()

--end


function Garrison:Update()
	Garrison:FullUpdateBuilding(TYPE_SHIPMENT)

	Garrison:UpdateUnknownMissions(false)

	-- LDB Text
	local missionCount = Garrison:GetMissionCount(nil)
	local buildingCount = Garrison:GetBuildingCount(nil)

	local conditionTable = {
		completed = {
			condition = (missionCount.total > 0 and missionCount.complete > 0),
			color = { r = 0, g = 1, b = 0 }
		},
		inprogress = {
			condition = (missionCount.total > 0 and missionCount.complete == 0),
			color = { r = 1, g = 1, b = 1 }
		},
		nomission = {
			condition = (missionCount.total == 0),
			color = { r = 1, g = 0, b = 0 }
		},
	}

	local ldbText = ""

	if configDb.general.mission.showCurrency then
		local currencyAmount = globalDb.data[charInfo.realmName][charInfo.playerName].currencyAmount
		ldbText = ldbText..("%s %s"):format(BreakUpLargeNumbers(currencyAmount), ICON_CURRENCY)
	end
	if configDb.general.mission.showProgress then
		ldbText = ldbText.." "..(L["In Progress: %s"]):format(missionCount.inProgress)
	end
	if configDb.general.mission.showComplete then
		ldbText = ldbText.." "..(L["Complete: %s"]):format(missionCount.complete)
	end


	if ldbText == "" then
		ldbText = L["Missions"]
	end

	ldb_object_mission.text = Garrison.getColoredTooltipString(ldbText, conditionTable)
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
			buildings = {},
			missionsExpanded = true,
			buildingsExpanded = true,
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

	self:InitHelper()
	self:InitEvent()

	-- Assign functions
	debugPrint, pairsByKeys, formatRealmPlayer, tableSize = Garrison.debugPrint, Garrison.pairsByKeys, Garrison.formatRealmPlayer, Garrison.tableSize
	getColoredString, getColoredUnitName, formattedSeconds  = Garrison.getColoredString, Garrison.getColoredUnitName, Garrison.formattedSeconds
	isCurrentChar, getIconString = Garrison.isCurrentChar, Garrison.getIconString

	self:SetupOptions()

	Garrison:SetSinkStorage(configDb.notification.sink)

	Toast:Register(TOAST_MISSION_COMPLETE, toastMissionComplete)
	Toast:Register(TOAST_BUILDING_COMPLETE, toastBuildingComplete)
	Toast:Register(TOAST_SHIPMENT_COMPLETE, toastShipmentComplete)

	Garrison:UpdateConfig()

	self:RegisterEvent("GARRISON_MISSION_STARTED", "GARRISON_MISSION_STARTED")
	self:RegisterEvent("GARRISON_MISSION_COMPLETE_RESPONSE", "GARRISON_MISSION_COMPLETE_RESPONSE")
	self:RegisterEvent("GARRISON_MISSION_FINISHED", "GARRISON_MISSION_FINISHED")

	self:RegisterEvent("GARRISON_SHOW_LANDING_PAGE", "GARRISON_SHOW_LANDING_PAGE")
	self:RegisterEvent("GARRISON_MISSION_NPC_OPENED", "GARRISON_MISSION_NPC_OPENED")

	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_NEW_AREA")

	self:RegisterEvent("ADDON_LOADED", "CheckAddonLoaded")

	self:RawHook("GarrisonMissionAlertFrame_ShowAlert", true)
	self:RawHook("GarrisonBuildingAlertFrame_ShowAlert", true)

	self:RawHook("GarrisonMinimapBuilding_ShowPulse", true)
	self:RawHook("GarrisonMinimapShipmentCreated_ShowPulse", true)
	self:RawHook("GarrisonMinimapMission_ShowPulse", true)		

	timers.icon_update = Garrison:ScheduleRepeatingTimer("SlowUpdate", 60)	
	timers.init_update = Garrison:ScheduleTimer("DelayedUpdate", 5)
end


function Garrison:DelayedUpdate()
	delayedInit = true
	Garrison:UpdateCurrency()

	Garrison:FullUpdateBuilding(TYPE_BUILDING)

	Garrison:UpdateLocation()

	self:RegisterEvent("GARRISON_BUILDING_PLACED", "BuildingUpdate")
	self:RegisterEvent("GARRISON_BUILDING_REMOVED", "BuildingUpdate")
	self:RegisterEvent("GARRISON_BUILDING_UPDATE", "BuildingUpdate")
	self:RegisterEvent("GARRISON_BUILDING_ACTIVATED", "BuildingUpdate")
	--self:RegisterEvent("GARRISON_BUILDING_LIST_UPDATE", "BuildingUpdate")
	self:RegisterEvent("GARRISON_UPDATE", "BuildingUpdate")
	self:RegisterEvent("SHIPMENT_UPDATE", "ShipmentStatusUpdate")

	--self:RegisterEvent("SHIPMENT_CRAFTER_CLOSED", "ShipmentUpdate")
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "UpdateCurrency")

	timers.notify_update = Garrison:ScheduleRepeatingTimer("QuickUpdate", 10)
end
