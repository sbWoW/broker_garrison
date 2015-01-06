local ADDON_NAME, private = ...

local _G = getfenv(0)
local Garrison = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local garrisonDb, globalDb, configDb

local debugPrint = Garrison.debugPrint

local string, CreateFrame = _G.string, _G.CreateFrame


local offsetY, offsetX = 4, 8

local function getMissionTimers(realm, name)
	local missionStr = '';

	local playerData = globalDb.data[realm][name]
	local sortOptions = Garrison.getSortOptions(Garrison.TYPE_MISSION, "name")

	local now = time()

	if playerData then

		local sortedMissionTable = Garrison.sort(playerData.missions, unpack(sortOptions))

		for missionID, missionData in sortedMissionTable do

			local timeLeft = missionData.duration - (now - missionData.start)
			if timeLeft > 0 then
				local timeLeftMinutes = math.ceil(timeLeft / 60)

				local length = string.len(missionStr);
				local str = missionID .. ':' .. timeLeftMinutes;			

				if (string.len(str) + length) <= 900 then
					missionStr = missionStr .. str .. ',';
				end
			end
		end
	end

	return string.sub(missionStr, 1, -2)
end


local function getShipmentTimers(realm, name)
	local shipmentStr = '';

	local playerData = globalDb.data[realm][name]
	local sortOptions = Garrison.getSortOptions(Garrison.TYPE_BUILDING, "name")

	local now = time()

	if playerData then
		local sortedBuildingTable = Garrison.sort(playerData.buildings, unpack(sortOptions))

		for plotID, buildingData in sortedBuildingTable do

			if  buildingData.shipment and buildingData.shipment.name and (buildingData.shipment.shipmentCapacity ~= nil and buildingData.shipment.shipmentCapacity > 0) then
				local shipmentData = buildingData.shipment

				local shipmentsReady, shipmentsInProgress, shipmentsAvailable, timeLeftNext, timeLeftTotal = Garrison:DoShipmentMagic(shipmentData, playerData.info)

                if timeLeftTotal > 0 then
                	local timeLeftMinutes = math.ceil(timeLeftTotal / 60)

                    local length = string.len(shipmentStr);
                    local str = buildingData.id .. ':' .. timeLeftMinutes;

                    if (string.len(str) + length) <= 600 then
                        shipmentStr = shipmentStr .. str .. ',';
                    end
                end
			end
		end
	end

	return string.sub(shipmentStr, 1, -2)
	
end


local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64encode(data)
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function reset()
    for y=1,80 do
        for x=1,80 do
            _G["qr"..x.."_"..y]:Hide();
        end
    end
end

local function showQR(paramCharInfo)
	local character = base64encode(paramCharInfo.playerName .. '-' .. paramCharInfo.realmName);
    local str = '1=' .. getMissionTimers(paramCharInfo.realmName, paramCharInfo.playerName) .. ';2=' .. getShipmentTimers(paramCharInfo.realmName, paramCharInfo.playerName) .. ';3=' .. character
	local title = ("%s - %s"):format(Garrison.getColoredUnitName(paramCharInfo.playerName, paramCharInfo.playerClass, paramCharInfo.realmName), paramCharInfo.realmName)   
    
    local t = select(2, qrcode(str));
    local size = (#t * 4) + 16

    reset();

    debugPrint(size)

    Garrison.qrFrame.viewFrame:SetWidth(size);
    Garrison.qrFrame.viewFrame:SetHeight(size);

    Garrison.qrFrame:SetWidth(size + 10)
	Garrison.qrFrame:SetHeight(size + 30)
	Garrison.qrFrame.titletext:SetText(title)


    for y = 1, #t do
        for x = 1, #t[1] do
            if (t[y][x] < 0) then
                _G["qr"..x.."_"..y]:Hide();
                _G["qr"..x.."_"..y]:SetPoint("BOTTOMLEFT", offsetY + (y * 4), offsetX + ((#t - x) * 4));
            else
                _G["qr"..x.."_"..y]:Show();
                _G["qr"..x.."_"..y]:SetPoint("BOTTOMLEFT", offsetY + (y * 4), offsetX + ((#t - x) * 4));
            end
        end
    end   

	Garrison.qrFrame:Show()
end

function Garrison:SetupQRExport()
	garrisonDb = self.DB
	configDb = garrisonDb.profile
	globalDb = garrisonDb.global

	Garrison.showQR = showQR

	local qrFrame = CreateFrame("Frame", "BrokerGarrisonQRView", UIParent, "BasicFrameTemplate")
	qrFrame:SetWidth(150)
	qrFrame:SetHeight(160)
	qrFrame:SetPoint("CENTER")
	qrFrame:SetMovable(true)
	qrFrame:EnableMouse(true)
	qrFrame:SetUserPlaced(true)	
	qrFrame:SetFrameStrata("TOOLTIP")
	qrFrame:SetClampedToScreen(true)	
	qrFrame:Hide()

    qrFrame:SetScript("OnMouseDown", function() 
    	qrFrame:StartMoving()
    end)
    
    qrFrame:SetScript("OnMouseUp", function() 
    	qrFrame:StopMovingOrSizing()
            --posx = f:GetLeft()
        	--posy = UIParent:GetTop() - (f:GetTop()*f:GetScale())
    end)    

	local titletext = qrFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titletext:SetPoint("TOPLEFT", 14, -3)
	titletext:SetPoint("TOPRIGHT", -14, -3)
	titletext:SetJustifyH("LEFT")
	titletext:SetHeight(18)
	qrFrame.titletext = titletext

	local viewFrame = CreateFrame("Frame", "BrokerGarrisonQRView", qrFrame)
	viewFrame:SetPoint("TOPLEFT", qrFrame, "TOPLEFT", 4, -25)
	viewFrame.texture = viewFrame:CreateTexture()
	viewFrame.texture:SetAllPoints(viewFrame)
	viewFrame.texture:SetTexture(1,1,1,1)
	viewFrame.texture:Show()
	viewFrame:Show()
	qrFrame.viewFrame = viewFrame

	Garrison.qrFrame = qrFrame

    for y=1,80 do
        for x=1,80 do
            local f = CreateFrame("Frame", "qr" .. x .. "_" .. y, viewFrame);
            f:SetWidth(4);
            f:SetHeight(4);
            f.texture = f:CreateTexture();
            f.texture:SetAllPoints(f);
            f.texture:SetTexture(0, 0, 0);
            f:SetPoint("BOTTOMLEFT", offsetY + (y * 4), offsetX + ((35 - x) * 4));
            f:Hide();
        end
    end
end


