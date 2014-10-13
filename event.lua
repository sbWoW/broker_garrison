local ADDON_NAME, private = ...

local Garrison = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local debugPrint, charInfo, timers = Garrison.debugPrint, Garrison.charInfo, Garrison.timers
local garrisonDb, globalDb, configDb

local _G = getfenv(0)

local pairs, time, C_Garrison, GetCurrencyInfo = _G.pairs, _G.time, _G.C_Garrison, _G.GetCurrencyInfo

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
				typeAtlas = garrisonMission.typeAtlas,
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

function Garrison:UpdateLocation()
	Garrison.location.mapName = _G.GetRealZoneText()
	Garrison.location.inGarrison = (Garrison.location.mapName and Garrison.location.garrisonMapName and Garrison.location.mapName == Garrison.location.garrisonMapName)
	debugPrint(("ZoneUpdate: %s (%s)"):format(Garrison.location.mapName or "-", _G.tostring(Garrison.location.inGarrison)))
end

function Garrison:ZONE_CHANGED_NEW_AREA(...)
	Garrison:UpdateLocation()
end

function Garrison:GetShipmentData(buildingID)
	local name, texture, shipmentCapacity, shipmentsReady, shipmentsTotal, creationTime, duration, timeleftString, itemName, itemIcon, itemQuality, itemID = C_Garrison.GetLandingPageShipmentInfo(buildingID)

	local tmpShipment = {
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

	return tmpShipment
end

function Garrison:GetBuildingData(plotID)
	local id, name, texPrefix, icon, rank, isBuilding, timeStart, buildTime, canActivate, canUpgrade, isPrebuilt = C_Garrison.GetOwnedBuildingInfoAbbrev(plotID)

	local tmpBuilding = {
		plotID = plotID,
		id = id,
		name = name,
		texPrefix = texPrefix,
		icon = icon,
		rank = rank,
		isBuilding = isBuilding,
		canActivate = canActivate,
		timeStart = timeStart,
		buildTime = buildTime,
	}

	return tmpBuilding
end


function Garrison:UpdateShipment(buildingID, shipmentData)	
	local tmpShipment = nil
	if buildingID then
		tmpShipment = Garrison:GetShipmentData(buildingID)

		if shipmentData then
		 	if shipmentData.shipmentsTotal and shipmentData.shipmentsTotal > 0 then

				tmpShipment.notificationValue = shipmentData.notificationValue or 0
				tmpShipment.notificationDismissed = shipmentData.notificationDismissed or false
				tmpShipment.notification = shipmentData.notification

				if tmpShipment.notificationValue then
					debugPrint(("Update Shipment (%s) - NotificationValue=%s"):format(tmpShipment.name, tmpShipment.notificationValue))
				end
			end
		end
	end

	return tmpShipment
end

function Garrison:UpdateBuilding(plotID)
 
	local tmpBuilding = Garrison:GetBuildingData(plotID)

	local buildingData = globalDb.data[charInfo.realmName][charInfo.playerName].buildings[plotID]

	local shipmentData = nil

	if buildingData then
		tmpBuilding.notificationDismissed = buildingData.notificationDismissed
		tmpBuilding.notification = buildingData.notification

		shipmentData = buildingData.shipment
	end

	tmpBuilding.shipment = Garrison:UpdateShipment(tmpBuilding.id, shipmentData)

	return tmpBuilding
end

function Garrison:FullUpdateBuilding(updateType)
	C_Garrison.RequestLandingPageShipmentInfo()

	local buildings = C_Garrison.GetBuildings()
	local tmpBuildings = {}	

	for i = 1, #buildings do
		local buildingID = buildings[i].buildingID
		local plotID = buildings[i].plotID

		if updateType == Garrison.TYPE_BUILDING then
			tmpBuildings[plotID] = Garrison:UpdateBuilding(plotID)
		end
		if updateType == Garrison.TYPE_SHIPMENT then
			local buildingData = globalDb.data[charInfo.realmName][charInfo.playerName].buildings[plotID]			

			if not buildingData then
				debugPrint("UpdateShipment: Unknown Building: "..buildingID)
			else
				local tmpShipment = Garrison:UpdateShipment(buildingID, buildingData.shipment)

				globalDb.data[charInfo.realmName][charInfo.playerName].buildings[plotID].shipment = tmpShipment
			end
		end
	end

	if updateType == Garrison.TYPE_BUILDING then
		globalDb.data[charInfo.realmName][charInfo.playerName].buildings = tmpBuildings
	end
end

function Garrison:BuildingUpdate(event, ...)
	if event == "GARRISON_BUILDING_PLACED" then
		local plotID, newPlacement = ...;		

		local tmpBuilding = Garrison:GetBuildingData(plotID)
		if newPlacement then
			debugPrint(("New Building (%s): %s (%s)"):format(tmpBuilding.name, tmpBuilding.rank, tmpBuilding.id))
			globalDb.data[charInfo.realmName][charInfo.playerName].buildings[plotID] = tmpBuilding
		else
			if globalDb.data[charInfo.realmName][charInfo.playerName].buildings and globalDb.data[charInfo.realmName][charInfo.playerName].buildings[plotID] then
				local currentBuilding = globalDb.data[charInfo.realmName][charInfo.playerName].buildings[plotID]
				-- Already exists, check for update

				if currentBuilding.id == tmpBuilding.id then
					-- Ignore
				else
					-- Upgrade
					debugPrint(("BuildingUpgrade (%s): %s (%s) -> %s (%s)"):format(tmpBuilding.name, currentBuilding.rank, currentBuilding.id, tmpBuilding.rank, tmpBuilding.id))

					globalDb.data[charInfo.realmName][charInfo.playerName].buildings[plotID] = tmpBuilding
				end
			end
		end
	elseif event == "GARRISON_BUILDING_REMOVED" then
		local plotID, buildingID = ...;
		debugPrint(("Removed Building %s"):format(buildingID))
		globalDb.data[charInfo.realmName][charInfo.playerName].buildings[plotID] = nil		
	elseif event == "GARRISON_BUILDING_ACTIVATED" or event == "GARRISON_BUILDING_UPDATE" then
		local plotID, buildingID = ...;
		local tmpBuilding = Garrison:UpdateBuilding(plotID)

		debugPrint(("BuildingInfoUpdate %s (%s)"):format(plotID, tmpBuilding.name or buildingID or '-'))

		globalDb.data[charInfo.realmName][charInfo.playerName].buildings[plotID] = tmpBuilding	
	else
		debugPrint("BuildingUpdate")
		Garrison:FullUpdateBuilding()
	end
end

function Garrison:ShipmentStatusUpdate(event, shipmentStarted)
	if shipmentStarted then
		debugPrint("ShipmentStatusUpdate")
		C_Garrison.RequestLandingPageShipmentInfo()
		--timers.shipment_update = Garrison:ScheduleTimer("UpdateShipmentInfo", 5)
	end
end

function Garrison:UpdateCurrency()
	local _, amount, _ = GetCurrencyInfo(Garrison.GARRISON_CURRENCY)
	globalDb.data[charInfo.realmName][charInfo.playerName].currencyAmount = amount

	Garrison:Update()
end

function Garrison:QuickUpdate()
	if Garrison.location.inGarrison then
		-- on garrison - full update
		Garrison:Update()
	else
		-- outside - only notifications
		Garrison:GetMissionCount(nil)
		Garrison:GetBuildingCount(nil)
	end
end

function Garrison:SlowUpdate()
	if not Garrison.location.inGarrison then
		-- on garrison - full update
		Garrison:Update()
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
	if configDb.notification.mission.hideBlizzardNotification then
		debugPrint("Blizzard notification hidden: "..missionID)
	else
		debugPrint("Show blizzard notification"..missionID)
		self.hooks.GarrisonMissionAlertFrame_ShowAlert(missionID)
	end
end

function Garrison:GarrisonBuildingAlertFrame_ShowAlert(name)
	if configDb.notification.building.hideBlizzardNotification then
		debugPrint("Blizzard notification hidden: "..name)
	else
		debugPrint("Show blizzard notification"..name)
		self.hooks.GarrisonBuildingAlertFrame_ShowAlert(name)
	end
end

function Garrison:GarrisonMinimapBuilding_ShowPulse()
	if configDb.notification.building.hideMinimapPulse then
		debugPrint("Hide Pulse (Building)")		
	else
		debugPrint("Play Pulse (Building)")
		self.hooks.GarrisonMinimapBuilding_ShowPulse(_G.GarrisonLandingPageMinimapButton)		
	end
end
function Garrison:GarrisonMinimapShipmentCreated_ShowPulse()
	if configDb.notification.shipment.hideMinimapPulse then
		debugPrint("Hide Pulse (Shipment)")		
	else
		debugPrint("Play Pulse (Shipment)")
		self.hooks.GarrisonMinimapShipmentCreated_ShowPulse(_G.GarrisonLandingPageMinimapButton)
	end
end
function Garrison:GarrisonMinimapMission_ShowPulse()
	if configDb.notification.mission.hideMinimapPulse then
		debugPrint("Hide Pulse (Mission)")		
	else
		debugPrint("Play Pulse (Mission)")
		self.hooks.GarrisonMinimapMission_ShowPulse(_G.GarrisonLandingPageMinimapButton)
	end
end


function Garrison:InitEvent()
	garrisonDb = self.DB
	configDb = garrisonDb.profile
	globalDb = garrisonDb.global
end

