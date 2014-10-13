local ADDON_NAME, private = ...

local Garrison = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub:GetLibrary( "AceLocale-3.0" ):GetLocale(ADDON_NAME)

Garrison.colors = {
	green = {r=0, g=1, b=0, a=1},
	white = {r=1, g=1, b=1, a=1},
	lightGray = {r=0.25, g=0.25, b=0.25, a=1},
	darkGray = {r=0.1, g=0.1, b=0.1, a=1},
}

Garrison.GARRISON_CURRENCY = 824

Garrison.instanceId = {
	[1153] = "HL3",
	[1330] = "HL2",
	[1331] = "AL2",
	[1158] = "AL1",
	[1159] = "AL3",
}
	

Garrison.COLOR_TABLE = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS

Garrison.COMPLETED_PATTERN = "^[^%d]*(0)[^%d]*$"
Garrison.ICON_CURRENCY = string.format("\124TInterface\\Icons\\Inv_Garrison_Resource:%d:%d:1:0\124t", 16, 16)
Garrison.ICON_OPEN = string.format("\124TInterface\\AddOns\\Broker_Garrison\\Media\\Open:%d:%d:1:0\124t", 16, 16)
Garrison.ICON_CLOSE = string.format("\124TInterface\\AddOns\\Broker_Garrison\\Media\\Close:%d:%d:1:0\124t", 16, 16)

Garrison.ICON_OPEN_DOWN = ICON_OPEN
Garrison.ICON_CLOSE_DOWN = ICON_CLOSE

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
		text = L["Complete: %mc% Next: %mnt%"],
		type = Garrison.TYPE_MISSION,
	},	
	["M3"] = {
		name = L["Missions Complete + Time/Char to next completion (All characters)"],
		text = L["Complete: %mc% Next: %mnt% (%mnc%)"],
		type = Garrison.TYPE_MISSION,
	},	
	["B1"] = {
		name = L["Shipments Ready (All characters)"],
		text = "Shipments Ready: %sr%",
		type = Garrison.TYPE_BUILDING,
	},
	["B2"] = {
		name = L["Shipments Ready + Time to next shipment (All characters)"],
		text = "Ready: %sr% Next: %snt%",
		type = Garrison.TYPE_BUILDING,
	},	
	["B3"] = {
		name = L["Shipments Ready + Time/Char to next shipment (All characters)"],
		text = "Ready: %sr% Next: %snt% (%snc%)",
		type = Garrison.TYPE_BUILDING,
	},		
}

Garrison.ldbVars = {
	["mt"] = {
		name = "Missions: Total",
		data = function(data) return Garrison.getTableValue(data, "missionCount", "total") end,
		type = Garrison.TYPE_MISSION,
	},
	["mp"] = {
		name = "Missions: In Progress",
		data = function(data) return Garrison.getTableValue(data, "missionCount", "inProgress") end,
		type = Garrison.TYPE_MISSION,
	},
	["mc"] = {
		name = "Missions: Complete",
		data = function(data) return Garrison.getTableValue(data, "missionCount", "complete") end,
		type = Garrison.TYPE_MISSION,
	},
	["mnt"] = {
		name = "Time until next mission",
		data = function(data) 
			local time = Garrison.getTableValue(data, "missionCount", "nextTime") or 0
			if time > 0 then
				return Garrison.formattedSeconds(time)
			else
				return "-"
			end
		end,
		type = Garrison.TYPE_MISSION,
	},
	["mnc"] = {
		name = "Character/Realm next mission",
		data = function(data) 
			local char = Garrison.getTableValue(data, "missionCount", "nextChar")
			if char ~= nil then
				return Garrison.formatRealmPlayer(char, true)
			else
				return "-"
			end
		end,
		type = Garrison.TYPE_MISSION,
	},	
	["cmt"] = {
		name = "Current Player Missions: Total",
		data = function(data) return Garrison.getTableValue(data, "missionCountCurrent", "total") end,
		type = Garrison.TYPE_MISSION,
	},
	["cmp"] = {
		name = "Current Player Missions: In Progress",
		data = function(data) return Garrison.getTableValue(data, "missionCountCurrent", "inProgress") end,
		type = Garrison.TYPE_MISSION,
	},
	["cmc"] = {
		name = "Current Player Missions: Complete",
		data = function(data) return Garrison.getTableValue(data, "missionCountCurrent", "complete") end,
		type = Garrison.TYPE_MISSION,
	},	
	["bt"] = {
		name = "Buildings: Total",
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "building", "total") end,
		type = Garrison.TYPE_BUILDING,
	},
	["bb"] = {
		name = "Buildings: Building",
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "building", "building") end,
		type = Garrison.TYPE_BUILDING,
	},
	["bc"] = {
		name = "Buildings: Complete",
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "building", "complete") end,
		type = Garrison.TYPE_BUILDING,
	},
	["ba"] = {
		name = "Buildings: Active",
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "building", "active") end,
		type = Garrison.TYPE_BUILDING,
	},
	["st"] = {
		name = "Shipments: Total",
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "shipment", "total") end,
		type = Garrison.TYPE_BUILDING,
	},
	["sp"] = {
		name = "Shipments: In Progress",
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "shipment", "inProgress") end,
		type = Garrison.TYPE_BUILDING,
	},
	["sr"] = {
		name = "Shipments: Ready",
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "shipment", "ready") end,
		type = Garrison.TYPE_BUILDING,
	},
	["sa"] = {
		name = "Shipments: Available",
		data = function(data) return Garrison.getTableValue(data, "buildingCount", "shipment", "available") end,
		type = Garrison.TYPE_BUILDING,
	},
	["snt"] = {
		name = "Time until next shipment",
		data = function(data) 
			local time = Garrison.getTableValue(data, "buildingCount", "shipment", "nextTime") or 0
			if time > 0 then
				return Garrison.formattedSeconds(time)
			else
				return "-"
			end
		end,
		type = Garrison.TYPE_BUILDING,
	},
	["snc"] = {
		name = "Character/Realm next shipment",
		data = function(data) 
			local char = Garrison.getTableValue(data, "buildingCount", "shipment", "nextChar")
			if char then
				return Garrison.formatRealmPlayer(char, true)
			else
				return "-"
			end
		end,
		type = Garrison.TYPE_BUILDING,
	},
	["cbt"] = {
		name = "Current Player Buildings: Total",
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "building", "total") end,
		type = Garrison.TYPE_BUILDING,
	},
	["cbb"] = {
		name = "Current Player Buildings: Building",
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "building", "building") end,
		type = Garrison.TYPE_BUILDING,
	},
	["cbc"] = {
		name = "Current Player Buildings: Complete",
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "building", "complete") end,
		type = Garrison.TYPE_BUILDING,
	},
	["cba"] = {
		name = "Current Player Buildings: Active",
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "building", "active") end,
		type = Garrison.TYPE_BUILDING,
	},
	["cst"] = {
		name = "Current Player Shipments: Total",
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "shipment", "total") end,
		type = Garrison.TYPE_BUILDING,
	},
	["csp"] = {
		name = "Current Player Shipments: In Progress",
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "shipment", "inProgress") end,
		type = Garrison.TYPE_BUILDING,
	},
	["csr"] = {
		name = "Current Player Shipments: Ready",
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "shipment", "ready") end,
		type = Garrison.TYPE_BUILDING,
	},
	["csa"] = {
		name = "Current Player Shipments: Available",
		data = function(data) return Garrison.getTableValue(data, "buildingCountCurrent", "shipment", "available") end,
		type = Garrison.TYPE_BUILDING,
	},
	["res"] = {
		name = "Garrison Resources",
		data = function(data) return Garrison.getTableValue(data, "currencyAmount") or 0 end,
	},
	["resfmt"] = {
		name = "Garrison Resources (Formatted)",
		data = function(data) return BreakUpLargeNumbers(Garrison.getTableValue(data, "currencyAmount") or 0) end,
	},
	["tres"] = {
		name = "Garrison Resources (Total)",
		data = function(data) return Garrison.getTableValue(data, "currencyTotal") or 0 end,
	},
	["tresfmt"] = {
		name = "Garrison Resources (Total, Formatted)",
		data = function(data) return BreakUpLargeNumbers(Garrison.getTableValue(data, "currencyTotal") or 0) end,
	},
	["resicon"] = {
		name = "Icon: Garrison Resource",
		data = function(data) return Garrison.ICON_CURRENCY end,
	},		
}
