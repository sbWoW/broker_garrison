local ADDON_NAME, private = ...

local Garrison = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local SECONDS_PER_HOUR = 60 * 60
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR

local _G = getfenv(0)
local pairs, tonumber, string, print, table, math, assert, loadstring, tostring = _G.pairs, _G.tonumber, _G.string, _G.print, _G.table, _G.math, _G.assert, _G.loadstring, _G.tostring
local sort, select, format = table.sort, _G.select, string.format

local garrisonDb, globalDb, configDb
local charInfo = Garrison.charInfo

function Garrison.tableSize(T)
	local count = 0
	if T then
		for _ in pairs(T) do count = count + 1 end
	end
	return count
end

function Garrison.round(num, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

local function debugPrint(text)
	if(configDb.debugPrint) then
		print(("%s: %s"):format(ADDON_NAME, text))
	end
end
Garrison.debugPrint = debugPrint

function Garrison.pairsByKeys(t,f)
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

local unitColor = {}
local lexcmps = {}
local lexsort
do
	local function sortByValue(t,f)
		local a = {}
			for k,v in pairs(t) do table.insert(a, { key = k, value = v })
			end
			table.sort(a, f)
			local i = 0      -- iterator variable
			local iter = function ()   -- iterator function
				i = i + 1
				if a[i] == nil then return nil
				else return a[i].key, a[i].value
				end
			end
		return iter
	end

 	local function lexcmp(...)
		local code = {"local lhs, rhs = ..."}
		local cnt = select('#', ...)
	 	for i = 1, cnt do
	  		local k = select(i, ...)
	 		local key,v = string.match(k, '([%a.]*),?([ad]?)')
	 		code[#code+1] = format("local lv, rv, key, desc = lhs.value.%s, rhs.value.%s, '%s', %s", key, key, key, tostring(v == '' or v == 'd'))
			--de[#code+1] = "print(('%s/%s - %s: %s <> %s = %s'):format(lname, rname, key, lv or '-', rv or '-', 'ret'))"
			code[#code+1] = "if lv == nil and rv ~= nil then return false end"
			code[#code+1] = "if lv ~= nil and rv == nil then return true end"
			code[#code+1] = "if lv ~= nil and rv ~= nil then"
			code[#code+1] = "  if type(lv) == 'boolean' and type(rv) == 'boolean' then"
			code[#code+1] = "		lv, rv = (lv == true and 1 or 0), (rv == true and 1 or 0)"
			code[#code+1] = "  end"
			code[#code+1] = "  if desc and (lv > rv) then return true end"
			code[#code+1] = "  if desc and (lv < rv) then return false end"
			code[#code+1] = "  if not desc and (lv < rv) then return true end"
			code[#code+1] = "  if not desc and (lv > rv) then return false end"
			code[#code+1] = "end"
			if i == cnt then
	 			code[#code+1] = "return false"
			end
		end
		local retCode = table.concat(code, "\n")
		--print(retCode)
		return assert(loadstring(retCode))
	end
	function lexsort(t, ...)
		local key = table.concat({n=select('#',...),...}, "\0")
		local cmp = lexcmps[key]
		if not cmp then
 			cmp = lexcmp(...)
			lexcmps[key] = cmp
		end
		return sortByValue(t, cmp)
	end
end

function Garrison.getIconString(name, size)
	local icon

	if name and size then
		icon = string.format("\124T%s:%d:%d:1:0\124t", name, size, size)
	else
		icon = string.format("\124T%s:%d:%d:1:0\124t", "Interface\\Icons\\INV_Misc_QuestionMark", size, size)
	end

	return icon
end

function Garrison.getColoredUnitName (name, class)
	local colorUnitName

	if(not unitColor[name]) then
		local classColor = Garrison.COLOR_TABLE[class]

		if not classColor then
			classColor = Garrison.colors.white
		end

		colorUnitName = string.format("|cff%02x%02x%02x%s|r",classColor.r*255,classColor.g*255,classColor.b*255,name)

		unitColor[name] = colorUnitName
	else
		colorUnitName = unitColor[name]
	end
	return colorUnitName
end

function Garrison.getColoredTooltipString(text, conditionTable)
	local retText = text

	for name, val in pairs(conditionTable) do
		if (val.condition) then
			retText = string.format("|cff%02x%02x%02x%s|r",val.color.r*255,val.color.g*255,val.color.b*255, text)
		end
	end

	return retText
end

function Garrison.getColoredString(text, color)
	return string.format("|cff%02x%02x%02x%s|r",color.r*255,color.g*255,color.b*255, text)
end

function Garrison.isCurrentChar(paramCharInfo)
	return paramCharInfo and charInfo and paramCharInfo.playerName == charInfo.playerName and paramCharInfo.realmName == charInfo.realmName
end

function Garrison.formattedSeconds(seconds)
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

function Garrison.formatRealmPlayer(paramCharInfo, colored)
	if colored then
		return ("%s (%s)"):format(Garrison.getColoredUnitName(paramCharInfo.playerName, paramCharInfo.playerClass), paramCharInfo.realmName)
	else
		return ("%s-%s"):format(paramCharInfo.playerName, paramCharInfo.realmName)
	end
end

function Garrison:InitHelper()
	garrisonDb = self.DB
	configDb = garrisonDb.profile
	globalDb = garrisonDb.global

	Garrison.sort = lexsort
end