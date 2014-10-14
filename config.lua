local ADDON_NAME, private = ...

local Garrison = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local table, print, pairs = _G.table, _G.print, _G.pairs

local garrisonDb, globalDb, configDb

local debugPrint = Garrison.debugPrint

local fonts = {}
local sounds = {}

function Garrison:returnchars()
	local a = {}

	for realmName,realmData in Garrison.pairsByKeys(globalDb.data) do
		for playerName,value in Garrison.pairsByKeys(realmData) do

			if (not (Garrison.charInfo.playerName == playerName and Garrison.charInfo.realmName == realmName)) then
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

function Garrison:GetTemplates(paramType)
	local templates = {}
	for k,v in pairs(Garrison.ldbTemplate) do
		if not v.type or v.type == paramType then
			templates[k] = v.name
		end
	end

	templates["custom"] = L["Custom"]

	return templates
end

function Garrison:GetLDBVariables(paramType)
	local vars = {}

	for k,v in Garrison.sort(Garrison.ldbVars, "name,a") do
		if not v.type or v.type == paramType then
			vars[k] = v.name
		end
	end

	return vars
end


function Garrison:GetLDBText(paramType)
	local template = configDb.general[paramType].ldbTemplate

	local ldbText = ""

	--debugPrint(paramType)
	--debugPrint(template)

	if template == "custom" then
		ldbText = configDb.general[paramType].ldbText
	elseif Garrison.ldbTemplate and Garrison.ldbTemplate[template] then

		ldbText = Garrison.ldbTemplate[template].text
	end

	return ldbText
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

	debugPrint(("%s deleted."):format(realm_and_character))
end


-- Options
function Garrison:GetOptions()
	local options = {
		name = L["Broker Garrison"],
		type = "group",
		childGroups = "tab",
		handler = self,
		args = {
			confdesc = {
				order = 1,
				type = "description",
				name = L["Garrison display for LDB\n"],
				cmdHidden = true,
			},
			general = {
				order = 100,
				type = "group",
				name = "General",
				cmdHidden = true,
				args = {				
					garrisonMinimapButton = {
						order = 100,
						type = "toggle",
						width = "full",
						name = L["Hide Garrison Minimap-Button"],
						desc = L["Hide Garrison Minimap-Button"],
						get = function() return configDb.general.hideGarrisonMinimapButton end,
						set = function(_,v) configDb.general.hideGarrisonMinimapButton = v
							Garrison:UpdateConfig()
						end,
					},	
					missionGroup = {
						order = 100,
						type = "group",
						name = L["Mission"],
						cmdHidden = true,
						args = {
							ldbHeader = {
								order = 100,
								type = "header",
								name = L["LDB Display"],
								cmdHidden = true,
							},
							ldbTemplateSelect = {
								order = 120,
								type = "select",
								width = "full",
								name = L["LDB Text"],
								desc = L["LDB Text"],
								values = Garrison:GetTemplates(Garrison.TYPE_MISSION),
								get = function() return configDb.general.mission.ldbTemplate end,
								set = function(_,v) 
									if v then
										if configDb.general.mission.ldbText == "custom" then
											configDb.general.mission.ldbText = Garrison:GetLDBText(Garrison.TYPE_MISSION) or ""
											configDb.general.mission.ldbTemplate = v
										else
											configDb.general.mission.ldbTemplate = v
											configDb.general.mission.ldbText = Garrison:GetLDBText(Garrison.TYPE_MISSION) or ""
										end
									end
								end,
							},							
							ldbText = {
								order = 130,
								type = "input",
								width = "full",
								name = L["Custom LDB Text"],
								desc = L["Custom LDB Text"],
								get = function() return configDb.general.mission.ldbText end,
								set = function(_,v) configDb.general.mission.ldbText = v
								end,
								disabled = function() return not configDb.general.mission.ldbTemplate or not (configDb.general.mission.ldbTemplate == "custom") end,
							},
							ldbVar = {
								order = 140,
								type = "select",
								width = "full",
								name = L["Add item to custom LDB Text"],
								name = L["Add item to custom LDB Text"],
								values = Garrison:GetLDBVariables(Garrison.TYPE_MISSION),
								get = function() return "" end,
								set = function(_,v) 									
									configDb.general.mission.ldbText = ("%s%%%s%%"):format(configDb.general.mission.ldbText or "", v or "")
								end,
								disabled = function() return not configDb.general.mission.ldbTemplate or not (configDb.general.mission.ldbTemplate == "custom") end,
							},

						},
					},
					buildingGroup = {
						order = 200,
						type = "group",
						name = L["Building"],
						cmdHidden = true,
						args = {
						hideBuildingWithoutShipments = {
								order = 10,
								type = "toggle",
								width = "full",
								name = L["Hide buildings without shipments"],
								desc = L["Don't display buildings without shipments (barracks, stables, ...)"],
								get = function() return configDb.general.building.hideBuildingWithoutShipments end,
								set = function(_,v) configDb.general.building.hideBuildingWithoutShipments = v
									Garrison:Update()
								end,						
							},						
							ldbHeader = {
								order = 100,
								type = "header",
								name = L["LDB Display"],
								cmdHidden = true,
							},	
							ldbTemplateSelect = {
								order = 120,
								type = "select",
								width = "full",
								name = L["LDB Text"],
								desc = L["LDB Text"],
								values = Garrison:GetTemplates(Garrison.TYPE_BUILDING),
								get = function() return configDb.general.building.ldbTemplate end,
								set = function(_,v) 
									if v then
										if configDb.general.building.ldbText == "custom" then
											configDb.general.building.ldbText = Garrison:GetLDBText(Garrison.TYPE_BUILDING) or ""
											configDb.general.building.ldbTemplate = v
										else
											configDb.general.building.ldbTemplate = v
											configDb.general.building.ldbText = Garrison:GetLDBText(Garrison.TYPE_BUILDING) or ""
										end
									end
									
								end,
							},							
							ldbText = {
								order = 130,
								type = "input",
								width = "full",
								name = L["Custom LDB Text"],
								desc = L["Custom LDB Text"],
								get = function() return configDb.general.building.ldbText end,
								set = function(_,v) configDb.general.building.ldbText = v
								end,
								disabled = function() return not configDb.general.building.ldbTemplate or not (configDb.general.building.ldbTemplate == "custom") end,
							},
							ldbVar = {
								order = 140,
								type = "select",
								width = "full",
								name = L["Add item to custom LDB Text"],
								name = L["Add item to custom LDB Text"],
								values = Garrison:GetLDBVariables(Garrison.TYPE_BUILDING),
								get = function() return "" end,
								set = function(_,v) 									
									configDb.general.building.ldbText = ("%s%%%s%%"):format(configDb.general.building.ldbText or "", v or "")
								end,
								disabled = function() return not configDb.general.building.ldbTemplate or not (configDb.general.building.ldbTemplate == "custom") end,
							},							
	
						},
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
					notificationMissionGroup = {
						order = 100,
						type = "group",
						name = L["Mission"],
						cmdHidden = true,
						args = {
							notificationToggle = {
								order = 100,
								type = "toggle",
								width = "full",
								name = L["Enable Notifications"],
								desc = L["Enable Notifications"],
								get = function() return configDb.notification.mission.enabled end,
								set = function(_,v) configDb.notification.mission.enabled = v
								end,
							},
							notificationRepeatOnLoad = {
								order = 200,
								type = "toggle",
								width = "full",
								name = L["Repeat on Load"],
								desc = L["Shows notification on each login/ui-reload"],
								get = function() return configDb.notification.mission.repeatOnLoad end,
								set = function(_,v) configDb.notification.mission.repeatOnLoad = v
								end,
								disabled = function() return not configDb.notification.mission.enabled end,
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
								get = function() return configDb.notification.mission.toastEnabled end,
								set = function(_,v) configDb.notification.mission.toastEnabled = v
								end,
								disabled = function() return not configDb.notification.mission.enabled end,
							},
							toastPersistent = {
								order = 320,
								type = "toggle",
								width = "full",
								name = L["Persistent Toasts"],
								desc = L["Make Toasts persistent (no auto-hide)"],
								get = function() return configDb.notification.mission.toastPersistent end,
								set = function(_,v) configDb.notification.mission.toastPersistent = v
								end,
								disabled = function() return not configDb.notification.mission.enabled
														or not configDb.notification.mission.toastEnabled end,
							},
							notificationExtendedToast = {
								order = 330,
								type = "toggle",
								width = "full",
								name = L["Advanced Toast controls"],
								desc = L["Adds OK/Dismiss Button to Toasts (Requires 'Repeat on Load')"],
								get = function() return configDb.notification.mission.extendedToast end,
								set = function(_,v) configDb.notification.mission.extendedToast = v
								end,
								disabled = function() return not configDb.notification.mission.enabled
														or not configDb.notification.mission.toastEnabled
														or not configDb.notification.mission.repeatOnLoad
														 end,
							},
							miscHeader = {
								order = 400,
								type = "header",
								name = L["Misc"],
								cmdHidden = true,
							},
							hideBlizzardNotification = {
								order = 410,
								type = "toggle",
								width = "full",
								name = L["Hide Blizzard notifications"],
								desc = L["Don't show the built-in notifications"],
								get = function() return configDb.notification.mission.hideBlizzardNotification end,
								set = function(_,v)
									configDb.notification.mission.hideBlizzardNotification = v
									Garrison:UpdateConfig()
								end,
								disabled = function() return not configDb.notification.mission.enabled end,
							},
							garrisonMinimapButtonAnimation = {
								order = 420,
								type = "toggle",
								width = "full",
								name = L["Hide Minimap-Button animation"],
								desc = L["Don't play pulse/flash animations on Minimap-Button"],
								get = function() return configDb.notification.mission.hideMinimapPulse end,
								set = function(_,v) configDb.notification.mission.hideMinimapPulse = v end,
								disabled = function() return configDb.ldbConfig.hideGarrisonMinimapButton end,
							},
							playSound = {
								order = 430,
								type = "toggle",
								name = L["Play Sound"],
								desc = L["Play Sound"],
								get = function() return configDb.notification.mission.playSound end,
								set = function(_,v)
									configDb.notification.mission.playSound = v
								end,
								disabled = function() return not configDb.notification.mission.enabled end,
							},
							playSoundOnMissionCompleteName = {
								order = 440,
								type = "select",
								name = L["Sound"],
								desc = L["Sound"],
								dialogControl = "LSM30_Sound",
								values = LSM:HashTable("sound"),
								get = function() return configDb.notification.mission.soundName end,
								set = function(_,v)
									configDb.notification.mission.soundName = v
								end,
								disabled = function() return not configDb.notification.mission.enabled or not configDb.notification.mission.playSound end,
							},
						},
					},
					notificationBuildingGroup = {
						order = 200,
						type = "group",
						name = L["Building"],
						cmdHidden = true,
						args = {
							notificationToggle = {
								order = 100,
								type = "toggle",
								width = "full",
								name = L["Enable Notifications"],
								desc = L["Enable Notifications"],
								get = function() return configDb.notification.building.enabled end,
								set = function(_,v) configDb.notification.building.enabled = v
									Garrison:Update()
								end,
							},
							notificationRepeatOnLoad = {
								order = 200,
								type = "toggle",
								width = "full",
								name = L["Repeat on Load"],
								desc = L["Shows notification on each login/ui-reload"],
								get = function() return configDb.notification.building.repeatOnLoad end,
								set = function(_,v) configDb.notification.building.repeatOnLoad = v
									Garrison:Update()
								end,
								disabled = function() return not configDb.notification.building.enabled end,
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
								get = function() return configDb.notification.building.toastEnabled end,
								set = function(_,v) configDb.notification.building.toastEnabled = v
								end,
								disabled = function() return not configDb.notification.building.enabled end,
							},
							toastPersistent = {
								order = 320,
								type = "toggle",
								width = "full",
								name = L["Persistent Toasts"],
								desc = L["Make Toasts persistent (no auto-hide)"],
								get = function() return configDb.notification.building.toastPersistent end,
								set = function(_,v) configDb.notification.building.toastPersistent = v
								end,
								disabled = function() return not configDb.notification.building.enabled
														or not configDb.notification.building.toastEnabled end,
							},
							notificationExtendedToast = {
								order = 330,
								type = "toggle",
								width = "full",
								name = L["Advanced Toast controls"],
								desc = L["Adds OK/Dismiss Button to Toasts (Requires 'Repeat on Load')"],
								get = function() return configDb.notification.building.extendedToast end,
								set = function(_,v) configDb.notification.building.extendedToast = v
								end,
								disabled = function() return not configDb.notification.building.enabled
														or not configDb.notification.building.toastEnabled
														or not configDb.notification.building.repeatOnLoad
														 end,
							},
							miscHeader = {
								order = 400,
								type = "header",
								name = L["Misc"],
								cmdHidden = true,
							},
							hideBlizzardNotification = {
								order = 410,
								type = "toggle",
								width = "full",
								name = L["Hide Blizzard notifications"],
								desc = L["Don't show the built-in notifications"],
								get = function() return configDb.notification.building.hideBlizzardNotification end,
								set = function(_,v)
									configDb.notification.building.hideBlizzardNotification = v
									Garrison:UpdateConfig()
								end,
								disabled = function() return not configDb.notification.building.enabled end,
							},
							garrisonMinimapButtonAnimation = {
								order = 420,
								type = "toggle",
								width = "full",
								name = L["Hide Minimap-Button animation"],
								desc = L["Don't play pulse/flash animations on Minimap-Button"],
								get = function() return configDb.notification.building.hideMinimapPulse end,
								set = function(_,v) configDb.notification.building.hideMinimapPulse = v
								end,
								disabled = function() return configDb.ldbConfig.hideGarrisonMinimapButton end,
							},							
							playSound = {
								order = 430,
								type = "toggle",
								name = L["Play Sound"],
								desc = L["Play Sound"],
								get = function() return configDb.notification.building.playSound end,
								set = function(_,v)
									configDb.notification.building.playSound = v
								end,
								disabled = function() return not configDb.notification.building.enabled end,
							},
							playSoundOnMissionCompleteName = {
								order = 440,
								type = "select",
								name = L["Sound"],
								desc = L["Sound"],
								dialogControl = "LSM30_Sound",
								values = LSM:HashTable("sound"),
								get = function() return configDb.notification.building.soundName end,
								set = function(_,v)
									configDb.notification.building.soundName = v
								end,
								disabled = function() return not configDb.notification.building.enabled or not configDb.notification.building.playSound end,
							},
						},
					},
					notificationShipmentGroup = {
						order = 300,
						type = "group",
						name = L["Shipment"],
						cmdHidden = true,
						args = {
							notificationToggle = {
								order = 100,
								type = "toggle",
								width = "full",
								name = L["Enable Notifications"],
								desc = L["Enable Notifications"],
								get = function() return configDb.notification.shipment.enabled end,
								set = function(_,v) configDb.notification.shipment.enabled = v
									Garrison:Update()
								end,
							},
							notificationRepeatOnLoad = {
								order = 200,
								type = "toggle",
								width = "full",
								name = L["Repeat on Load"],
								desc = L["Shows notification on each login/ui-reload"],
								get = function() return configDb.notification.shipment.repeatOnLoad end,
								set = function(_,v) configDb.notification.shipment.repeatOnLoad = v
									Garrison:Update()
								end,
								disabled = function() return not configDb.notification.shipment.enabled end,
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
								get = function() return configDb.notification.shipment.toastEnabled end,
								set = function(_,v) configDb.notification.shipment.toastEnabled = v
								end,
								disabled = function() return not configDb.notification.shipment.enabled end,
							},
							toastPersistent = {
								order = 320,
								type = "toggle",
								width = "full",
								name = L["Persistent Toasts"],
								desc = L["Make Toasts persistent (no auto-hide)"],
								get = function() return configDb.notification.shipment.toastPersistent end,
								set = function(_,v) configDb.notification.shipment.toastPersistent = v
								end,
								disabled = function() return not configDb.notification.shipment.enabled
														or not configDb.notification.shipment.toastEnabled end,
							},
							notificationExtendedToast = {
								order = 330,
								type = "toggle",
								width = "full",
								name = L["Advanced Toast controls"],
								desc = L["Adds OK/Dismiss Button to Toasts (Requires 'Repeat on Load')"],
								get = function() return configDb.notification.shipment.extendedToast end,
								set = function(_,v) configDb.notification.shipment.extendedToast = v
								end,
								disabled = function() return not configDb.notification.shipment.enabled
														or not configDb.notification.shipment.toastEnabled
														or not configDb.notification.shipment.repeatOnLoad
														 end,
							},
							miscHeader = {
								order = 400,
								type = "header",
								name = L["Misc"],
								cmdHidden = true,
							},
							hideBlizzardNotification = {
								order = 410,
								type = "toggle",
								width = "full",
								name = L["Hide Blizzard notifications"],
								desc = L["Don't show the built-in notifications"],
								get = function() return configDb.notification.shipment.hideBlizzardNotification end,
								set = function(_,v)
									configDb.notification.shipment.hideBlizzardNotification = v
									Garrison:UpdateConfig()
								end,
								disabled = true --function() return not configDb.notification.shipment.enabled end,
							},
							garrisonMinimapButtonAnimation = {
								order = 420,
								type = "toggle",
								width = "full",
								name = L["Hide Minimap-Button animation"],
								desc = L["Don't play pulse/flash animations on Minimap-Button"],
								get = function() return configDb.notification.shipment.hideMinimapPulse end,
								set = function(_,v) configDb.notification.shipment.hideMinimapPulse = v
								end,
								disabled = function() return configDb.ldbConfig.hideGarrisonMinimapButton end,
							},
							playSound = {
								order = 430,
								type = "toggle",
								name = L["Play Sound"],
								desc = L["Play Sound"],
								get = function() return configDb.notification.shipment.playSound end,
								set = function(_,v)
									configDb.notification.shipment.playSound = v
								end,
								disabled = function() return not configDb.notification.shipment.enabled end,								
							},
							playSoundOnMissionCompleteName = {
								order = 440,
								type = "select",
								name = L["Sound"],
								desc = L["Sound"],
								dialogControl = "LSM30_Sound",
								values = LSM:HashTable("sound"),
								get = function() return configDb.notification.shipment.soundName end,
								set = function(_,v)
									configDb.notification.shipment.soundName = v
								end,
								disabled = function() return not configDb.notification.shipment.enabled or not configDb.notification.shipment.playSound end,
							},
						},
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
			displayGroup = {
				order = 500,
				type = "group",
				name = L["Display"],
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
							return configDb.display.scale or 1
						end,
						set = function(info, value)
							configDb.display.scale = value
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
							return configDb.display.autoHideDelay or 0.25
						end,
						set = function(info, value)
							configDb.display.autoHideDelay = value
						end,
					},
					fontName = {
						order = 130,
						type = "select",
						name = L["Font"],
						desc = L["Font"],
						dialogControl = "LSM30_Font",
						values = LSM:HashTable("font"),
						get = function() return configDb.display.fontName end,
						set = function(_,v)
							configDb.display.fontName = v
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
						get = function() return configDb.display.fontSize or 12 end,
						set = function(_,v)
							configDb.display.fontSize = v
						end,
					},
					showIcon = {
						order = 150,
						type = "toggle",
						name = L["Show Icons"],
						desc = L["Show Icons"],
						get = function() return configDb.display.showIcon end,
						set = function(_,v)
							configDb.display.showIcon = v
						end,
					},					
					iconSize = {
						order = 160,
						type = "range",
						min = 0,
						max = 64,
						step = 1,
						width = "full",
						name = L["Icon Size"],
						desc = L["Icon Size"],
						get = function() return configDb.display.iconSize or 24 end,
						set = function(_,v)
							configDb.display.iconSize = v
						end,
						disabled = function() return not configDb.display.showIcon end,
					},					
				},
			},
			aboutGroup = {
				order = 900,
				type = "group",
				name = "About",
				cmdHidden = true,
				args = {
					aboutHeader = {
						order = 100,
						type = "header",
						name = L["Broker Garrison"],
						cmdHidden = true,
					},
					version = {				
						order = 200,
						type = "description",
						name = ("Version: %s\n"):format(Garrison.versionString),
						cmdHidden = true,
					},
					about = {
						order = 300,
						type = "description",
						name = ("Author: %s <EU-Khaz'Goroth>\nLayout: %s <EU-Khaz'Goroth>"):format(Garrison.getColoredUnitName("Smb","PRIEST"), Garrison.getColoredUnitName("Hotaruby","DRUID")),
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
	Garrison.optionsFrame = AceConfigDialog:AddToBlizOptions(ADDON_NAME, Garrison.cleanName)
	

	-- Fix sink config options
	options.args.notificationGroup.args.notificationLibSink.order = 600
	options.args.notificationGroup.args.notificationLibSink.inline = true
	options.args.notificationGroup.args.notificationLibSink.name = ""
	options.args.notificationGroup.args.notificationLibSink.disabled = function() return not configDb.notification.enabled end

	options.plugins["profiles"] = {
		profiles = AceDBOptions:GetOptionsTable(garrisonDb)
	}
	options.plugins.profiles.profiles.order = 800

	--local sortedOptions = Garrison.sort(options.args, "order,a")
	--for k, v in sortedOptions do
	--	if v and v.type == "group" then
	--		print("AddOption "..k)
	--		AceConfigRegistry:RegisterOptionsTable(ADDON_NAME.."-"..k, v)			
	--		AceConfigDialog:AddToBlizOptions(ADDON_NAME.."-"..k, v.name, Garrison.cleanName)
	--	end
	--end
end
