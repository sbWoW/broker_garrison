local ADDON_NAME, private = ...

local _G = getfenv(0)
local LibStub = _G.LibStub

local Garrison = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub:GetLibrary( "AceLocale-3.0" ):GetLocale(ADDON_NAME)

Garrison.colors = {
	green = {r=0, g=1, b=0, a=1},
	white = {r=1, g=1, b=1, a=1},
	lightGray = {r=0.25, g=0.25, b=0.25, a=1},
	darkGray = {r=0.1, g=0.1, b=0.1, a=1},
}

Garrison.GARRISON_CURRENCY = 824
Garrison.GARRISON_CURRENCY_APEXIS = 823

Garrison.instanceId = {
	[1153] = "HL3",
	[1330] = "HL2",
	[1331] = "AL2",
	[1158] = "AL1",
	[1159] = "AL3",
}
	

Garrison.STATE_BUILDING_ACTIVE = 0
Garrison.STATE_BUILDING_COMPLETE = 1
Garrison.STATE_BUILDING_BUILDING = 2

Garrison.STATE_MISSION_COMPLETE = 0
Garrison.STATE_MISSION_INPROGRESS = 1

Garrison.COLOR_TABLE = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS

Garrison.COMPLETED_PATTERN = "^[^%d]*(0)[^%d]*$"
Garrison.ICON_CURRENCY = string.format("\124TInterface\\Icons\\Inv_Garrison_Resource:%d:%d:1:0\124t", 16, 16)

Garrison.ICON_CURRENCY_APEXIS = string.format("\124TInterface\\Icons\\Inv_Apexis_Draenor:%d:%d:1:0\124t", 16, 16)

Garrison.ICON_OPEN = string.format("\124TInterface\\AddOns\\Broker_Garrison\\Media\\Open:%d:%d:1:0\124t", 16, 16)
Garrison.ICON_CLOSE = string.format("\124TInterface\\AddOns\\Broker_Garrison\\Media\\Close:%d:%d:1:0\124t", 16, 16)

Garrison.ICON_OPEN_DOWN = Garrison.ICON_OPEN
Garrison.ICON_CLOSE_DOWN = Garrison.ICON_CLOSE

Garrison.tooltipConfig = {
	["-"] = {
		name = " - ",
	},
	["b.canActivate"] = {
		value = "canActivate",
		name = L["Can be activated"],
		type = Garrison.TYPE_BUILDING,
	},
	["b.isBuilding"]= {
		value = "isBuilding",
		name = L["Is Building"],
		type = Garrison.TYPE_BUILDING,
	},
	["b.shipmentsReady"] = {
		value = "shipment.shipmentsReadyEstimate",
		name = L["Shipments Ready"],
		type = Garrison.TYPE_BUILDING,
	},	
	["b.shipmentsInProgress"] = {
		value = "shipment.shipmentsInProgress",
		name = L["Shipments In Progress"],
		type = Garrison.TYPE_BUILDING,
	},
	["b.shipmentsTotal"] = {
		value = "shipment.shipmentsTotal",
		name = L["Shipments Total (Progress+Ready)"],
		type = Garrison.TYPE_BUILDING,
	},		
	["b.shipmentsAvailable"] = {
		value = "shipment.shipmentsAvailable",
		name = L["Shipments Available"],
		type = Garrison.TYPE_BUILDING,
	},
	["b.shipmentCapacity"] = {
		value = "shipment.shipmentCapacity",
		name = L["Shipment Capacity"],
		type = Garrison.TYPE_BUILDING,
	},
	["b.buildingState"] = {
		value = "buildingState",
		name = L["Building State (Active, Complete, Building)"],
		type = Garrison.TYPE_BUILDING,
	},	
	["b.size"] = {
		value = "plotSize",
		name = L["Building Size"],
		type = Garrison.TYPE_BUILDING,
	},	
	["b.rank"] = {
		value = "rank",
		name = L["Building Rank"],
		type = Garrison.TYPE_BUILDING,
	},	
	["b.name"] = {
		value = "name",
		name = L["Building Name"],
		type = Garrison.TYPE_BUILDING,
	},
	["m.timeLeft"] = {
		value = "timeLeftCalc",
		name = L["Remaining Time"],
		type = Garrison.TYPE_MISSION,
	},	
	["m.level"] = {
		value = "level",
		name = L["Mission Level"],
		type = Garrison.TYPE_MISSION,
	},
	["m.missionState"] = {
		value = "missionState",
		name = L["Mission State (Complete, In Progress)"],
		type = Garrison.TYPE_MISSION,
	},	
	["m.name"] = {
		value = "name",
		name = L["Mission Name"],
		type = Garrison.TYPE_MISSION,
	},
}

Garrison.ldbTemplate = {
	["A1"] = {
		name = L["Garrison Resources (Current char)"],
		text = "%resfmt% %resicon%",
	},
	["A1"] = {
		name = L["Garrison Resources (No icon)"],
		text = "%resfmt%",
	},
	["M1"] = {
		name = L["Progress, Complete"],
		text = L["In Progress: %mp% Complete: %mc%"],
		type = Garrison.TYPE_MISSION,
	},	
	["M2"] = {
		name = L["Missions Complete + Time to next completion (All characters)"],
		text = L["Complete: %mc% Next: %mnt|-%"],
		type = Garrison.TYPE_MISSION,
	},	
	["M3"] = {
		name = L["Missions Complete + Time/Char to next completion (All characters)"],
		text = L["Complete: %mc% Next: %mnt|-% (%mnc|-%)"],
		type = Garrison.TYPE_MISSION,
	},	
	["B1"] = {
		name = L["Shipments Ready (All characters)"],
		text = L["Shipments Ready: %sr%"],
		type = Garrison.TYPE_BUILDING,
	},
	["B2"] = {
		name = L["Shipments Ready + Time to next shipment (All characters)"],
		text = L["Ready: %sr% Next: %snt|-%"],
		type = Garrison.TYPE_BUILDING,
	},	
	["B3"] = {
		name = L["Shipments Ready + Time/Char to next shipment (All characters)"],
		text = L["Ready: %sr% Next: %snt|-% (%snc|-%)"],
		type = Garrison.TYPE_BUILDING,
	},		
}

Garrison.ldbVars = {
	["mt"] = {
		name = L["Missions: Total"],
		data = function(data) return Garrison.getTableValue(data, "missionCount", "total") end,
		type = Garrison.TYPE_MISSION,
	},
	["mp"] = {
		name = L["Missions: In Progress"],
		data = function(data) return Garrison.getTableValue(data, "missionCount", "inProgress") end,
		type = Garrison.TYPE_MISSION,
	},
	["mc"] = {
		name = L["Missions: Complete"],
		data = function(data) return Garrison.getTableValue(data, "missionCount", "complete") end,
		type = Garrison.TYPE_MISSION,
	},
	["mnt"] = {
		name = L["Time until next mission"],
		data = function(data) 
			local time = Garrison.getTableValue(data, "missionCount", "nextTime") or 0
			if time > 0 then
				return Garrison.formattedSeconds(time)
			else
				return nil
			end
		end,
		type = Garrison.TYPE_MISSION,
	},
	["mnr"] = {
		name = L["Realm next mission"],
		data = function(data) 
			return Garrison.getTableValue(data, "missionCount", "nextChar", "playerRealm")
		end,
		type = Garrison.TYPE_MISSION,
	},
	["mnc"] = {
		name = L["Character next mission"],
		data = function(data) 
			return Garrison.getTableValue(data, "missionCount", "nextChar", "playerName")
		end,
		type = Garrison.TYPE_MISSION,
	},	
	["cmt"] = {
		name = L["Current Player Missions: Total"],
		data = function(data) return Garrison.getTableValue(data, "missionCountCurrent", "total") end,
		type = Garrison.TYPE_MISSION,
	},
	["cmp"] = {
		name = L["Current Player Missions: In Progress"],
		data = function(data) return Garrison.getTableValue(data, "missionCountCurrent", "inProgress") end,
		type = Garrison.TYPE_MISSION,
	},
	["cmc"] = {
		name = L["Current Player Missions: Complete"],
		data = function(data) return Garrison.getTableValue(data, "missionCountCurrent", "complete") end,
		type = Garrison.TYPE_MISSION,
	},	
	["bt"] = {
		name = L["Buildings: Total"],
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "building", "total") end,
		type = Garrison.TYPE_BUILDING,
	},
	["bb"] = {
		name = L["Buildings: Building"],
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "building", "building") end,
		type = Garrison.TYPE_BUILDING,
	},
	["bc"] = {
		name = L["Buildings: Complete"],
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "building", "complete") end,
		type = Garrison.TYPE_BUILDING,
	},
	["ba"] = {
		name = L["Buildings: Active"],
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "building", "active") end,
		type = Garrison.TYPE_BUILDING,
	},
	["st"] = {
		name = L["Shipments: Total"],
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "shipment", "total") end,
		type = Garrison.TYPE_BUILDING,
	},
	["sp"] = {
		name = L["Shipments: In Progress"],
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "shipment", "inProgress") end,
		type = Garrison.TYPE_BUILDING,
	},
	["sr"] = {
		name = L["Shipments: Ready"],
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "shipment", "ready") end,
		type = Garrison.TYPE_BUILDING,
	},
	["sa"] = {
		name = L["Shipments: Available"],
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "shipment", "available") end,
		type = Garrison.TYPE_BUILDING,
	},
	["snt"] = {
		name = L["Time until next shipment"],
		data = function(data) 
			local time = Garrison.getTableValue(data, "buildingCount", "shipment", "nextTime") or 0
			if time > 0 then
				return Garrison.formattedSeconds(time)
			else
				return nil
			end
		end,
		type = Garrison.TYPE_BUILDING,
	},
	["sncr"] = {
		name = L["Realm next shipment"],
		data = function(data) 
			return Garrison.getTableValue(data, "buildingCount", "shipment", "nextChar", "playerRealm")
		end,
		type = Garrison.TYPE_BUILDING,
	},
	["snc"] = {
		name = L["Character next shipment"],
		data = function(data) 
			return Garrison.getTableValue(data, "buildingCount", "shipment", "nextChar", "playerName")
		end,
		type = Garrison.TYPE_BUILDING,
	},	
	["cbt"] = {
		name = L["Current Player Buildings: Total"],
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "building", "total") end,
		type = Garrison.TYPE_BUILDING,
	},
	["cbb"] = {
		name = L["Current Player Buildings: Building"],
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "building", "building") end,
		type = Garrison.TYPE_BUILDING,
	},
	["cbc"] = {
		name = L["Current Player Buildings: Complete"],
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "building", "complete") end,
		type = Garrison.TYPE_BUILDING,
	},
	["cba"] = {
		name = L["Current Player Buildings: Active"],
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "building", "active") end,
		type = Garrison.TYPE_BUILDING,
	},
	["cst"] = {
		name = L["Current Player Shipments: Total"],
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "shipment", "total") end,
		type = Garrison.TYPE_BUILDING,
	},
	["csp"] = {
		name = L["Current Player Shipments: In Progress"],
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "shipment", "inProgress") end,
		type = Garrison.TYPE_BUILDING,
	},
	["csr"] = {
		name = L["Current Player Shipments: Ready"],
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "shipment", "ready") end,
		type = Garrison.TYPE_BUILDING,
	},
	["csa"] = {
		name = L["Current Player Shipments: Available"],
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "shipment", "available") end,
		type = Garrison.TYPE_BUILDING,
	},
	["res"] = {
		name = L["Garrison Resources"],
		data = function(data) return Garrison.getTableValue(data, "currencyAmount") or 0 end,
	},
	["resfmt"] = {
		name = L["Garrison Resources (Formatted)"],
		data = function(data) return _G.BreakUpLargeNumbers(Garrison.getTableValue(data, "currencyAmount") or 0) end,
	},
	["tres"] = {
		name = L["Garrison Resources (Total)"],
		data = function(data) return Garrison.getTableValue(data, "currencyTotal") or 0 end,
	},
	["tresfmt"] = {
		name = L["Garrison Resources (Total, Formatted)"],
		data = function(data) return _G.BreakUpLargeNumbers(Garrison.getTableValue(data, "currencyTotal") or 0) end,
	},
	["resicon"] = {
		name = L["Icon: Garrison Resource"],
		data = function(data) return Garrison.ICON_CURRENCY end,
	},
	["apexis"] = {
		name = L["Apexis Crystals"],
		data = function(data) return Garrison.getTableValue(data, "currencyApexisAmount") or 0 end,
	},
	["tapexis"] = {
		name = L["Apexis Crystals (Total)"],
		data = function(data) return Garrison.getTableValue(data, "currencyApexisTotal") or 0 end,
	},
	["apexisicon"] = {
		name = L["Icon: Apexis Crystal"],
		data = function(data) return Garrison.ICON_CURRENCY_APEXIS end,
	},	
}
