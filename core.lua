local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local L = LibStub:GetLibrary( "AceLocale-3.0" ):GetLocale( "Broker_Garrison")
local LibQTip = LibStub('LibQTip-1.0')
local L_GOLD = L["g"]
local L_SILVER = L["s"]
local L_COPPER = L["c"]


local Garrison = CreateFrame("frame")
LibStub("AceEvent-3.0"):Embed(Garrison)

Garrison.dataobj = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(L["Broker_Garrison"], 
  { type = "data source", 
   label = L["Broker Garrison"], 
	icon = "Interface\\garrison_building_salvageyard",
	text = "5",
   })


local charInfo = {
	playerName = UnitName("player"),
	playerClass = UnitClass("player"),	
	playerFaction = UnitFactionGroup("player"),
	playerLevel = UnitLevel("player"),
	realmName = GetRealmName(),
}	


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
	for name,value in pairsByKeys(Broker_GarrisonDB.data[charInfo.realmName].Alliance) do
		table.insert(a,name)
	end
	for name,value in pairsByKeys(Broker_GarrisonDB.data[charInfo.realmName].Horde) do
		table.insert(a,name)
	end
	table.sort(a)
	return a
end

local function deletechar(char)
	if not char or char == nil or char == "" then return nil end
	for factionName,factionTable in pairs(Broker_GarrisonDB.data[charInfo.realmName]) do	
		for name,value in pairsByKeys(factionTable) do
			if name == char then
				Broker_GarrisonDB.data[charInfo.realmName][charInfo.factionName][charInfo.playerName] = nil
				print("Broker_Garrison: "..char.." deleted.")
			end
		end
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
			name = L["Simple instance-lock+vp/jp display for LDB\n"],
			cmdHidden = true,
		},
		showCoinIcons = {
			order = 10, 
			type = "toggle", 
			width = "full",
			name = L["Compress LFR display"],
			desc = L["Display LFR information as one column"],
			get = function() return true end,
			set = function(_,v) local val = v end,
		},
		deletechar = {
			name = L["Delete char"],
			desc = L["Delete the selected char"],
			order = 100,
			type = "select",
			values = returnchars,
			set = function(info, val) local t=returnchars(); deletechar(t[val]); Garrison:UpdateConfig() end,
			get = function(info) return nil end
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
			name = "Author: "..sbi:getColoredUnitName("Smb","PRIEST").." <EU-Khaz'Goroth>\nAddon-idea/inspiration: "..sbi:getColoredUnitName("Mordac","ROGUE").." <EU-Khaz'Goroth>",
			cmdHidden = true,
		},		
	}
}	
   
LibStub("AceConfig-3.0"):RegisterOptionsTable(L["Broker Garrison"], options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(L["Broker Garrison"])

local toolTipRef

function Garrison:UpdateConfig() 
	if not Broker_GarrisonConfig then 
		Broker_GarrisonConfig = { 		
			Sorting = "Name",
			SortReverse = false,
			ShowAllCharacters = false,
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

	if (not Broker_GarrisonDB.data[charInfo.realmName]["Horde"] or not Broker_GarrisonDB.data[charInfo.realmName]["Alliance"]) then
		Broker_GarrisonDB.data[charInfo.realmName] = {}
		Broker_GarrisonDB.data[charInfo.realmName]["Horde"] = {}
		Broker_GarrisonDB.data[charInfo.realmName]["Alliance"] = {}		
	end

	if (not Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerFaction][charInfo.playerName]) then
		Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerFaction][charInfo.playerName] = {
			lfr = {},
			dungeon = {},
			raid = {},
			currency = {}, -- VP/JP/...?
			info = charInfo,
		}
	end
	
	Garrison:Update()
end


function Garrison:getColoredUnitName (name, class)
	local colorUnitName
	
	if(not unitColor[name]) then
		local classColor = RAID_CLASS_COLORS[strupper(string.gsub(class, " ", ""))]	
		colorUnitName = string.format("|cff%02x%02x%02x%s",classColor.r*255,classColor.g*255,classColor.b*255,name)	
	
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
			retText = string.format("|cff%02x%02x%02x%s",val.color.r*255,val.color.g*255,val.color.b*255, text)	
		end
	end
	
	return retText
end


local function GetTipAnchor(frame)
	local x,y = frame:GetCenter()
	if not x or not y then return "TOPLEFT", "BOTTOMLEFT" end
	local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
	return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
end

function Garrison.dataobj.OnLeave()
   -- Release the tooltip
   LibQTip:Release(toolTipRef)
   toolTipRef = nil
end


function Garrison:setTooltipText(tooltip, row, col, text)
	tooltip:SetCell(row, col, text, nil, "CENTER")
end


local next = next
function Garrison.dataobj.OnEnter(self)
	local tooltip = LibQTip:Acquire("BrokerGarrisonTooltip", 4, "LEFT", "RIGHT", "RIGHT", "RIGHT")
	toolTipRef = tooltip
   
	--row, _ = tooltip:AddHeader("Broker_Garrison")
	local name, playerObj
	local headerTable = {}	
	local columnTable = {}	
	local col = 1
		
	headerTable[col] = "Character"
	col = col + 1	

	local row, _ = tooltip:AddLine()

	for hCol, hName in pairs(headerTable) do
		if (hCol % 2 == 0) then
			tooltip:SetColumnColor(hCol, 0.25, 0.25, 0.25)			
		else
			tooltip:SetColumnColor(hCol, 0, 0, 0)
		end
		Garrison:setTooltipText(tooltip, row, hCol, hName)
	end


	for name,playerObj in pairs(Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerFaction]) do
		if playerObj ~= nil then
			row, _ = tooltip:AddSeparator()			
			row, _ = tooltip:AddLine()
			tooltip:SetCell(row, 1, Garrison:getColoredUnitName(playerObj.info.name, playerObj.info.class))			
			local col = 2

			if(playerObj.missions ~= nil) then

				for missionId, missionObj in pairs(playerObj.missions) do
					
					Garrison:setTooltipText(tooltip, row, 1,  string.format("%s: ", missionObj.name))
					Garrison:setTooltipText(tooltip, row, 2,  string.format("%s", missionObj.timeLeft))
					Garrison:setTooltipText(tooltip, row, 3,  string.format("%s: ", missionObj.duration))

				end
			end
		end
	end

	tooltip:AddLine(" ")
	

	
   tooltip:SmartAnchorTo(self)
   
   tooltip:Show()
end


function sbi:testDump()
	for name,playerObj in pairs(Broker_GarrisonDB.data[charInfo.realmName][charInfo.playerFaction]) do
		if playerObj ~= nil then
			print(unpack({Garrison:getColoredUnitName(playerObj.info.name, playerObj.info.class)}))

			row = row + 1

			if(playerObj.missions ~= nil) then

				for missionId, missionObj in pairs(playerObj.missions) do
					print(unpack({string.format("%s: ", missionObj.name), 
						string.format("%s", missionObj.timeLeft),
						string.format("%s", missionObj.duration)}))

					row = row + 1

				end
			end
		end
	end
end


local function round(num, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

function Garrison:getData()
	return Broker_GarrisonDB.data
end


function Garrison:Update()
	
	Broker_GarrisonDB.data[charInfo.realmName][charInfo.faction][charInfo.playerName].missions = C_Garrison.GetInProgressMissions()
	Broker_GarrisonDB.data[charInfo.realmName][charInfo.faction][charInfo.playerName].updateTime = time()
	

	if tipshown then dataobj.OnEnter(tipshown) end
end

function Garrison:EnteringWorld()
	Garrison:UpdateConfig()
end

Garrison:RegisterEvent("GARRISON_MISSION_STARTED", "Update")
Garrison:RegisterEvent("GARRISON_MISSION_COMPLETED", "Update")
Garrison:RegisterEvent("PLAYER_LOGIN", "EnteringWorld")

Garrison:UpdateConfig()