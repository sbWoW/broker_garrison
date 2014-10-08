local ADDON_NAME, private = ...

local Garrison = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local table = _G.table
local print = _G.print
local pairs = _G.pairs

local garrisonDb
local globalDb
local configDb

local fonts = {}
local sounds = {}

function Garrison:returnchars()
	local a = {}

	for realmName,realmData in self.pairsByKeys(globalDb.data) do
		for playerName,value in self.pairsByKeys(realmData) do

			if (not (self.charInfo.playerName == playerName and self.charInfo.realmName == realmName)) then
				table.insert(a,playerName..":"..realmName)
			end
		end
	end

	table.sort(a)
	return a
end

function Garrison:GetFonts()
	for k in pairs(fonts) do fonts[k] = nil end

	for _, name in pairs(LSM:List(LSM.MediaType.FONT)) do
		fonts[name] = name
	end
	
	return fonts
end

function Garrison:GetSounds()
	for k in pairs(sounds) do sounds[k] = nil end

	for _, name in pairs(LSM:List(LSM.MediaType.SOUND)) do
		sounds[name] = name
	end
	
	return sounds
end


function Garrison:deletechar(realm_and_character)
	local playerName, realmName = (":"):split(realm_and_character, 2)
	if not realmName or realmName == nil or realmName == "" then return nil end
	if not playerName or playerName == nil or playerName == "" then return nil end

	globalDb.data[realmName][playerName] = nil

	local lastPlayer = true
	for realmName,realmData in pairs(globalDb.data[realmName]) do
		lastPlayer = false
	end

	if lastPlayer then
		globalDb.data[realmName] = nil
	end

	self.debugPrint(("%s deleted."):format(realm_and_character))
end


-- Options
function Garrison:GetOptions()
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
			ldbGroup = {
				order = 100,
				type = "group",
				name = "LDB",
				cmdHidden = true,
				args = {
					garrisonMinimapButton = {
						order = 110, 
						type = "toggle", 
						width = "full",
						name = L["Hide Garrison Minimap-Button"],
						desc = L["Hide Garrison Minimap-Button"],
						get = function() return configDb.ldbConfig.hideGarrisonMinimapButton end,
						set = function(_,v) configDb.ldbConfig.hideGarrisonMinimapButton = v 
							Garrison:Update()
						end,
					},				
					showCurrency = {
						order = 120, 
						type = "toggle", 
						width = "full",
						name = L["Show resources"],
						desc = L["Show garrison resources in LDB"],
						get = function() return configDb.ldbConfig.showCurrency end,
						set = function(_,v) configDb.ldbConfig.showCurrency = v 
							Garrison:Update()
						end,
					},

					showProgress = {
						order = 130, 
						type = "toggle", 
						width = "full",
						name = L["Show active missions"],
						desc = L["Show active missions in LDB"],
						get = function() return configDb.ldbConfig.showProgress end,
						set = function(_,v) configDb.ldbConfig.showProgress = v 
							Garrison:Update()
						end,
					},		
					showComplete = {
						order = 140, 
						type = "toggle", 
						width = "full",
						name = L["Show completed missions"],
						desc = L["Show completed missions in LDB"],
						get = function() return configDb.ldbConfig.showComplete end,
						set = function(_,v) configDb.ldbConfig.showComplete = v 
							Garrison:Update()
						end,
					},
				},
			},		
			dataGroup = {
				order = 200,
				type = "group",
				name = "Data",
				cmdHidden = true,
				args = {
					deletechar = {
						name = L["Delete char"],
						desc = L["Delete the selected char"],
						order = 201,
						type = "select",
						values = Garrison:returnchars(),
						set = function(info, val) local t=Garrison:returnchars(); Garrison:deletechar(t[val]) end,
						get = function(info) return nil end,
						width = "double",
					},		
				},
			},
			notificationGroup = {
				order = 300,
				type = "group",
				name = L["Notifications"],
				cmdHidden = true,
				args = {		
					notificationToggle = {
						order = 100, 
						type = "toggle", 
						width = "full",
						name = L["Enable Notifications"],
						desc = L["Enable Notifications"],
						get = function() return configDb.notification.enabled end,
						set = function(_,v) configDb.notification.enabled = v 
							Garrison:Update()
						end,
					},				
					notificationRepeatOnLoad = {
						order = 200,
						type = "toggle", 
						width = "full",
						name = L["Repeat on Load"],
						desc = L["Shows notification on each login/ui-reload"],
						get = function() return configDb.notification.repeatOnLoad end,
						set = function(_,v) configDb.notification.repeatOnLoad = v 
							Garrison:Update()
						end,
						disabled = function() return not configDb.notification.enabled end,
					},		
					toastHeader = {
						order = 300,
						type = "header",
						name = L["Toast Notifications"],
						cmdHidden = true,
					},					
					toastToggle = {
						order = 310, 
						type = "toggle", 
						width = "full",
						name = L["Enable Toasts"],
						desc = L["Enable Toasts"],
						get = function() return configDb.notification.toastEnabled end,
						set = function(_,v) configDb.notification.toastEnabled = v 
							Garrison:Update()
						end,
						disabled = function() return not configDb.notification.enabled end,
					},		
					toastPersistent = {
						order = 320, 
						type = "toggle", 
						width = "full",
						name = L["Persistent Toasts"],
						desc = L["Make Toasts persistent (no auto-hide)"],
						get = function() return configDb.notification.toastPersistent end,
						set = function(_,v) configDb.notification.toastPersistent = v 
							Garrison:Update()
						end,
						disabled = function() return not configDb.notification.enabled 
												or not configDb.notification.toastEnabled end,
					},
					notificationExtendedToast = {
						order = 330,
						type = "toggle", 
						width = "full",
						name = L["Advanced Toast controls"],
						desc = L["Adds OK/Dismiss Button to Toasts (Requires 'Repeat on Load')"],
						get = function() return configDb.notification.extendedToast end,
						set = function(_,v) configDb.notification.extendedToast = v 
						end,
						disabled = function() return not configDb.notification.enabled 
												or not configDb.notification.toastEnabled
												or not configDb.notification.repeatOnLoad
												 end,
					},		
					miscHeader = {
						order = 400,
						type = "header",
						name = L["Misc"],
						cmdHidden = true,
					},								
					hideBlizzardNotificationMission = {
						order = 410, 
						type = "toggle", 
						width = "full",
						name = L["Hide Blizzard notifications"],
						desc = L["Don't show the built-in notifications"],
						get = function() return configDb.notification.hideBlizzardNotificationMission end,
						set = function(_,v) 
							configDb.notification.hideBlizzardNotificationMission = v 
							Garrison:UpdateConfig()
						end,
						disabled = function() return not configDb.notification.enabled end,
					},
					hideBlizzardNotificationBuilding = {
						order = 420, 
						type = "toggle", 
						width = "full",
						name = L["Hide Blizzard notifications"],
						desc = L["Don't show the built-in notifications"],
						get = function() return configDb.notification.hideBlizzardNotificationBuilding end,
						set = function(_,v) 
							configDb.notification.hideBlizzardNotificationBuilding = v 
							Garrison:UpdateConfig()
						end,
						disabled = function() return not configDb.notification.enabled end,
					},					
					playSound = {
						order = 420,
						type = "toggle",
						name = L["Play Sound"],
						desc = L["Play Sound"],
						get = function() return configDb.notification.playSound end,
						set = function(_,v) 
							configDb.notification.playSound = v
						end,					
						disabled = function() return not configDb.notification.enabled end,
					},					
					playSoundOnMissionCompleteName = {
						order = 430,
						type = "select",
						name = L["Sound"],
						desc = L["Sound"],
						dialogControl = "LSM30_Sound",
						values = LSM:HashTable("sound"),
						get = function() return configDb.notification.soundName end,
						set = function(_,v) 
							configDb.notification.soundName = v
						end,					
						disabled = function() return not configDb.notification.enabled or not configDb.notification.playSound end,

					},
					outputHeader = {
						order = 500,
						type = "header",
						name = L["Output"],
						cmdHidden = true,
					},		
					notificationLibSink = Garrison:GetSinkAce3OptionsDataTable(),				
				},
			},
			tooltipGroup = {
				order = 100,
				type = "group",
				name = L["Tooltip"],
				cmdHidden = true,
				args = {
					scale = {
						order = 110,
						type = "range",
						width = "full",
						name = L["Tooltip Scale"],
						min = 0.5,
						max = 2,
						step = 0.01,
						get = function()
							return configDb.tooltip.scale or 1
						end,
						set = function(info, value)
							configDb.tooltip.scale = value
						end,
					},
					autoHideDelay = {
						order = 120,
						type = "range",
						width = "full",
						name = L["Auto-Hide delay"],
						min = 0.1,
						max = 3,
						step = 0.01,
						get = function()
							return configDb.tooltip.autoHideDelay or 0.25
						end,
						set = function(info, value)
							configDb.tooltip.autoHideDelay = value
						end,
					},
					fontName = {
						order = 130,
						type = "select",
						name = L["Font"],
						desc = L["Font"],
						dialogControl = "LSM30_Font",
						values = LSM:HashTable("font"),
						get = function() return configDb.tooltip.fontName end,
						set = function(_,v) 
							configDb.tooltip.fontName = v
						end,					
					},
					fontSize = {
						order = 140, 
						type = "range", 
						min = 9,
						max = 20,
						step = 1,
						width = "full",
						name = L["Font Size"],
						desc = L["Font Size"],
						get = function() return configDb.tooltip.fontSize or 12 end,
						set = function(_,v) 
							configDb.tooltip.fontSize = v 
						end,
					},					
				},
			},
			aboutGroup = {
				order = 900,
				type = "group",
				name = "About",
				cmdHidden = true,
				args = {
					about = {
						order = 910,
						type = "description",
						name = ("Author: %s <EU-Khaz'Goroth>\nLayout: %s <EU-Khaz'Goroth>"):format(self.getColoredUnitName("Smb","PRIEST"), self.getColoredUnitName("Hotaruby","DRUID")),
						cmdHidden = true,
					},		
					todoText = {
						order = 920,
						type = "description",
						name = "TODO: MORE OPTIONS!!!11",
						cmdHidden = true,
					},
				},
			},
		},
		plugins = {},
	}	

	return options
end

function Garrison:SetupOptions()
	garrisonDb = self.DB
	configDb = garrisonDb.profile
	globalDb = garrisonDb.global

	local options = Garrison:GetOptions()

	AceConfigRegistry:RegisterOptionsTable(ADDON_NAME, options)
	Garrison.optionsFrame = AceConfigDialog:AddToBlizOptions(ADDON_NAME)

	-- Fix sink config options
	options.args.notificationGroup.args.notificationLibSink.order = 600
	options.args.notificationGroup.args.notificationLibSink.inline = true
	options.args.notificationGroup.args.notificationLibSink.name = ""
	options.args.notificationGroup.args.notificationLibSink.disabled = function() return not configDb.notification.enabled end


	options.plugins["profiles"] = {
		profiles = AceDBOptions:GetOptionsTable(garrisonDb)
	}
	options.plugins.profiles.profiles.order = 800
end
