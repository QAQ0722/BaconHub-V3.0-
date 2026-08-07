if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local AssetService = game:GetService("AssetService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PREFIX = "BaconShader_"
local ENABLED = true
local WEATHER_CONTROL = {

    Percent = 0.20,
    VisualMultiplier = 0.70,
    ImpactMultiplier = 0.70,
    WaterMultiplier = 1.00,
    PanelHeight = 224,
}

local SETTINGS_ATTRIBUTE = "BaconShader_UITransparency"

local rememberedTransparency = player:GetAttribute(SETTINGS_ATTRIBUTE)
if typeof(rememberedTransparency) ~= "number" then
    rememberedTransparency = 1.00
end
rememberedTransparency = math.clamp(rememberedTransparency, 0, 1)

local SETTINGS_CONTROL = {

    SavedTransparency = rememberedTransparency,
    PreviewTransparency = rememberedTransparency,
    Page = "Main",
}

local RUNTIME = {
    Alive = true,
    MainConnection = nil,
}

local PANEL_SIZE = Vector2.new(286, 204)
local PANEL_MIN_HEIGHT = 42
local PANEL_START_CENTER = Vector2.new(165, 230)
local PANEL_RADIUS = 26

local GLASS_DISTANCE = 6

local GLASS_TRANSPARENCY = 0.55
local GLASS_POWER = 1.45

local GLASS_SCALE_X = 1.00
local GLASS_SCALE_Y = 1.00

local GLASS_INSET = 10
local CORNER_SEGMENTS = 12

local USE_WORLD_GLASS_REFRACTION = false
local LIQUID_GLASS_UPDATE_RATE = 1 / 30

local USE_REAL_LIQUID_GLASS_HANDLER = true
local LIQUID_GLASS_MODULE_NAME = "LiquidGlassHandler"
local LIQUID_GLASS_TAG = "LiquidGlass"

local LIQUID_GLASS_SEARCH_WORKSPACE = true

local LIQUID_GLASS_ASSET_ID = 78675735649311
local TRY_CLIENT_LOAD_LIQUID_GLASS_ASSET = true

local LIQUID_GLASS_TAG_COMPONENTS = true

local AUTO_GUI_INSET_FIX = true

local GLASS_OFFSET_X = 0
local GLASS_OFFSET_Y = 0

local targetCenter = PANEL_START_CENTER
local currentVelocity = Vector2.zero

local DAY_CYCLE_ENABLED_DEFAULT = false

local DEFAULT_DAY_MINUTES = 3
local DEFAULT_NIGHT_MINUTES = 2

local DAY_START_CLOCK = 6
local NIGHT_START_CLOCK = 18

local MIN_CYCLE_MINUTES = 0.1
local MAX_CYCLE_MINUTES = 60

local dayCycleMinutes = DEFAULT_DAY_MINUTES
local nightCycleMinutes = DEFAULT_NIGHT_MINUTES

local function isDayClockTime(t)
	t %= 24
	return t >= DAY_START_CLOCK and t < NIGHT_START_CLOCK
end

local function getDayNightCycleSpeed(t)
	if isDayClockTime(t) then
		return 12 / (math.max(dayCycleMinutes, MIN_CYCLE_MINUTES) * 60)
	else
		return 12 / (math.max(nightCycleMinutes, MIN_CYCLE_MINUTES) * 60)
	end
end

local function New(className, props, parent)
	local obj = Instance.new(className)

	for k, v in pairs(props or {}) do
		obj[k] = v
	end

	if parent then
		obj.Parent = parent
	end

	return obj
end

local function Corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
	return c
end

local function Stroke(parent, thickness, transparency, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Transparency = transparency
	s.Color = color
	s.Parent = parent
	return s
end

local function clamp01(v)
	return math.clamp(v, 0, 1)
end

local function smoothstep(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

local function lerpNumber(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(a, b, t)
	return Color3.new(
		lerpNumber(a.R, b.R, t),
		lerpNumber(a.G, b.G, t),
		lerpNumber(a.B, b.B, t)
	)
end

local function safeSet(callback)
	local ok, err = pcall(callback)
	if not ok then
		warn("[BaconShader] 設定失敗：", err)
	end
end

local function getEffect(name)
	return Lighting:FindFirstChild(PREFIX .. name)
end

local ORIGINAL_STATE = {
    Properties = {},
    Effects = {},
}

do
    local properties = {
        "Ambient",
        "Brightness",
        "ClockTime",
        "ColorShift_Bottom",
        "ColorShift_Top",
        "EnvironmentDiffuseScale",
        "EnvironmentSpecularScale",
        "ExposureCompensation",
        "FogColor",
        "FogEnd",
        "FogStart",
        "GeographicLatitude",
        "GlobalShadows",
        "OutdoorAmbient",
        "ShadowSoftness",
        "Technology",
    }

    for _, property in ipairs(properties) do
        pcall(function()
            ORIGINAL_STATE.Properties[property] = Lighting[property]
        end)
    end

    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("BloomEffect")
            or child:IsA("ColorCorrectionEffect")
            or child:IsA("BlurEffect")
            or child:IsA("SunRaysEffect")
            or child:IsA("DepthOfFieldEffect")
            or child:IsA("Atmosphere")
            or child:IsA("Sky") then

            local ok, clone = pcall(function()
                return child:Clone()
            end)

            if ok and clone then
                table.insert(ORIGINAL_STATE.Effects, clone)
            end
        end
    end
end

local function restoreOriginalLighting()
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("BloomEffect")
            or child:IsA("ColorCorrectionEffect")
            or child:IsA("BlurEffect")
            or child:IsA("SunRaysEffect")
            or child:IsA("DepthOfFieldEffect")
            or child:IsA("Atmosphere")
            or child:IsA("Sky") then
            child:Destroy()
        end
    end

    for property, value in pairs(ORIGINAL_STATE.Properties) do
        pcall(function()
            Lighting[property] = value
        end)
    end

    for _, stored in ipairs(ORIGINAL_STATE.Effects) do
        pcall(function()
            stored:Clone().Parent = Lighting
        end)
    end
end

local oldGui = playerGui:FindFirstChild(PREFIX .. "LiquidTimeGui")
if oldGui then
	oldGui:Destroy()
end

local oldBaconShaderGui = playerGui:FindFirstChild("BaconShader_LiquidTimeGui")
if oldBaconShaderGui then
	oldBaconShaderGui:Destroy()
end

local OLD_GLASS_NAMES = {
	[PREFIX .. "WorldGlassRig"] = true,

	["BaconShader_WorldGlassRig"] = true,
	["BaconShader_WorldGlassRig_v10"] = true,
	["BaconShader_WorldGlassRig_v11"] = true,
	["BaconShader_WorldGlassRig_v12"] = true,
	["BaconShader_WorldGlassRig_v13"] = true,
	["BaconShader_WorldGlassRig_v14"] = true,
	["BaconShader_WorldGlassRig_v15"] = true,
	["BaconShader_WorldGlassRig_v16"] = true,
	["BaconShader_WorldGlassRig_v17"] = true,
	["BaconShader_WorldGlassRig_v18"] = true,
	["BaconShader_WorldGlassRig_v19"] = true,
	["BaconShader_WorldGlassRig_v20"] = true,
	["BaconShader_WorldGlassRig_v21"] = true,
	["BaconShader_WorldGlassRig_v1"] = true,
	["BaconShader_WorldGlassRig_v2"] = true,
	["BaconShader_WorldGlassRig_v3"] = true,
	["BaconShader_WorldGlassRig_v4"] = true,
	["BaconShader_WorldGlassRig_v5"] = true,
	[PREFIX .. "WorldGlassRig_v21"] = true,
	[PREFIX .. "WorldGlassRig_v1"] = true,
	[PREFIX .. "WorldGlassRig_v2"] = true,
	["LiquidGlassWorldRig"] = true,
	["LiquidGlassWorldRig_v10"] = true,
}

local function clearOldWorldGlass(keep)

	local roots = { workspace }

	if workspace.CurrentCamera then
		table.insert(roots, workspace.CurrentCamera)
	end

	for _, root in ipairs(roots) do
		for _, obj in ipairs(root:GetChildren()) do
			if OLD_GLASS_NAMES[obj.Name] and obj ~= keep then
				pcall(function()
					obj:Destroy()
				end)
			end
		end
	end
end

clearOldWorldGlass()

local function clearOldEffects()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("BloomEffect")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("BlurEffect")
			or child:IsA("SunRaysEffect")
			or child:IsA("DepthOfFieldEffect")
			or child:IsA("Atmosphere")
			or child:IsA("Sky") then
			child:Destroy()
		end
	end
end

local keyframes = {
	{
		time = 0,
		Brightness = 1.10,
		Exposure = -0.03,
		ShadowSoftness = 0.24,

		ColorTop = Color3.fromRGB(118, 128, 158),
		ColorBottom = Color3.fromRGB(22, 25, 38),
		Ambient = Color3.fromRGB(42, 46, 62),
		OutdoorAmbient = Color3.fromRGB(54, 60, 78),

		FogColor = Color3.fromRGB(40, 47, 67),
		FogStart = 210,
		FogEnd = 1650,

		AtmosphereColor = Color3.fromRGB(112, 126, 158),
		AtmosphereDecay = Color3.fromRGB(36, 42, 61),
		AtmosphereDensity = 0.20,
		AtmosphereOffset = 0.03,
		AtmosphereGlare = 0.015,
		AtmosphereHaze = 0.55,

		BloomIntensity = 0.025,
		BloomThreshold = 0.93,
		BloomSize = 24,

		SunRaysIntensity = 0,
		SunRaysSpread = 0.65,

		BlurSize = 0.18,

		ColorBrightness = -0.005,
		ColorContrast = 0.09,
		ColorSaturation = -0.08,
		TintColor = Color3.fromRGB(205, 214, 235),

		DofFar = 0.05,
	},

	{
		time = 4.35,
		Brightness = 1.22,
		Exposure = -0.015,
		ShadowSoftness = 0.22,

		ColorTop = Color3.fromRGB(132, 144, 176),
		ColorBottom = Color3.fromRGB(28, 33, 49),
		Ambient = Color3.fromRGB(49, 55, 72),
		OutdoorAmbient = Color3.fromRGB(64, 72, 94),

		FogColor = Color3.fromRGB(56, 65, 88),
		FogStart = 190,
		FogEnd = 1550,

		AtmosphereColor = Color3.fromRGB(135, 150, 184),
		AtmosphereDecay = Color3.fromRGB(45, 53, 74),
		AtmosphereDensity = 0.22,
		AtmosphereOffset = 0.04,
		AtmosphereGlare = 0.025,
		AtmosphereHaze = 0.68,

		BloomIntensity = 0.03,
		BloomThreshold = 0.92,
		BloomSize = 27,

		SunRaysIntensity = 0,
		SunRaysSpread = 0.68,

		BlurSize = 0.20,

		ColorBrightness = 0,
		ColorContrast = 0.09,
		ColorSaturation = -0.06,
		TintColor = Color3.fromRGB(214, 222, 240),

		DofFar = 0.055,
	},

	{
		time = 5.5,
		Brightness = 1.62,
		Exposure = 0.025,
		ShadowSoftness = 0.19,

		ColorTop = Color3.fromRGB(196, 183, 184),
		ColorBottom = Color3.fromRGB(64, 57, 66),
		Ambient = Color3.fromRGB(66, 63, 72),
		OutdoorAmbient = Color3.fromRGB(86, 81, 91),

		FogColor = Color3.fromRGB(101, 96, 108),
		FogStart = 160,
		FogEnd = 1450,

		AtmosphereColor = Color3.fromRGB(205, 195, 202),
		AtmosphereDecay = Color3.fromRGB(87, 75, 82),
		AtmosphereDensity = 0.24,
		AtmosphereOffset = 0.065,
		AtmosphereGlare = 0.07,
		AtmosphereHaze = 0.88,

		BloomIntensity = 0.04,
		BloomThreshold = 0.89,
		BloomSize = 31,

		SunRaysIntensity = 0.008,
		SunRaysSpread = 0.72,

		BlurSize = 0.25,

		ColorBrightness = 0.005,
		ColorContrast = 0.09,
		ColorSaturation = -0.01,
		TintColor = Color3.fromRGB(236, 226, 231),

		DofFar = 0.065,
	},

	{
		time = 6.7,
		Brightness = 2.55,
		Exposure = 0.12,
		ShadowSoftness = 0.12,

		ColorTop = Color3.fromRGB(255, 190, 85),
		ColorBottom = Color3.fromRGB(120, 78, 42),
		Ambient = Color3.fromRGB(94, 72, 50),
		OutdoorAmbient = Color3.fromRGB(116, 88, 58),

		FogColor = Color3.fromRGB(160, 128, 82),
		FogStart = 130,
		FogEnd = 1400,

		AtmosphereColor = Color3.fromRGB(255, 210, 135),
		AtmosphereDecay = Color3.fromRGB(135, 90, 45),
		AtmosphereDensity = 0.32,
		AtmosphereOffset = 0.12,
		AtmosphereGlare = 0.28,
		AtmosphereHaze = 1.8,

		BloomIntensity = 0.07,
		BloomThreshold = 0.84,
		BloomSize = 42,

		SunRaysIntensity = 0.045,
		SunRaysSpread = 0.86,

		BlurSize = 0.45,

		ColorBrightness = 0.015,
		ColorContrast = 0.12,
		ColorSaturation = 0.08,
		TintColor = Color3.fromRGB(255, 235, 205),

		DofFar = 0.1,
	},

	{
		time = 12,
		Brightness = 3.15,
		Exposure = 0.1,
		ShadowSoftness = 0.18,

		ColorTop = Color3.fromRGB(255, 255, 255),
		ColorBottom = Color3.fromRGB(180, 180, 175),
		Ambient = Color3.fromRGB(130, 130, 128),
		OutdoorAmbient = Color3.fromRGB(155, 155, 150),

		FogColor = Color3.fromRGB(220, 225, 225),
		FogStart = 280,
		FogEnd = 2500,

		AtmosphereColor = Color3.fromRGB(245, 248, 250),
		AtmosphereDecay = Color3.fromRGB(175, 185, 190),
		AtmosphereDensity = 0.16,
		AtmosphereOffset = 0.03,
		AtmosphereGlare = 0.12,
		AtmosphereHaze = 0.45,

		BloomIntensity = 0.035,
		BloomThreshold = 0.92,
		BloomSize = 26,

		SunRaysIntensity = 0.018,
		SunRaysSpread = 0.7,

		BlurSize = 0.15,

		ColorBrightness = 0.005,
		ColorContrast = 0.06,
		ColorSaturation = 0.02,
		TintColor = Color3.fromRGB(255, 255, 250),

		DofFar = 0.045,
	},

	{
		time = 17.7,
		Brightness = 2.55,
		Exposure = 0.1,
		ShadowSoftness = 0.12,

		ColorTop = Color3.fromRGB(255, 178, 65),
		ColorBottom = Color3.fromRGB(130, 75, 38),
		Ambient = Color3.fromRGB(96, 68, 45),
		OutdoorAmbient = Color3.fromRGB(120, 84, 55),

		FogColor = Color3.fromRGB(170, 118, 72),
		FogStart = 120,
		FogEnd = 1350,

		AtmosphereColor = Color3.fromRGB(255, 195, 115),
		AtmosphereDecay = Color3.fromRGB(145, 82, 40),
		AtmosphereDensity = 0.34,
		AtmosphereOffset = 0.13,
		AtmosphereGlare = 0.32,
		AtmosphereHaze = 2,

		BloomIntensity = 0.08,
		BloomThreshold = 0.84,
		BloomSize = 46,

		SunRaysIntensity = 0.055,
		SunRaysSpread = 0.88,

		BlurSize = 0.5,

		ColorBrightness = 0.012,
		ColorContrast = 0.13,
		ColorSaturation = 0.09,
		TintColor = Color3.fromRGB(255, 230, 198),

		DofFar = 0.11,
	},

	{
		time = 19.5,
		Brightness = 1.35,
		Exposure = 0.03,
		ShadowSoftness = 0.22,

		ColorTop = Color3.fromRGB(195, 195, 200),
		ColorBottom = Color3.fromRGB(40, 40, 45),
		Ambient = Color3.fromRGB(60, 60, 66),
		OutdoorAmbient = Color3.fromRGB(86, 86, 94),

		FogColor = Color3.fromRGB(75, 75, 82),
		FogStart = 180,
		FogEnd = 1500,

		AtmosphereColor = Color3.fromRGB(210, 210, 205),
		AtmosphereDecay = Color3.fromRGB(62, 62, 70),
		AtmosphereDensity = 0.23,
		AtmosphereOffset = 0.05,
		AtmosphereGlare = 0.04,
		AtmosphereHaze = 0.8,

		BloomIntensity = 0.035,
		BloomThreshold = 0.9,
		BloomSize = 28,

		SunRaysIntensity = 0,
		SunRaysSpread = 0.65,

		BlurSize = 0.25,

		ColorBrightness = 0.01,
		ColorContrast = 0.08,
		ColorSaturation = -0.03,
		TintColor = Color3.fromRGB(235, 235, 230),

		DofFar = 0.06,
	},

	{
		time = 24,
		Brightness = 1.25,
		Exposure = 0.02,
		ShadowSoftness = 0.22,

		ColorTop = Color3.fromRGB(185, 188, 198),
		ColorBottom = Color3.fromRGB(35, 35, 42),
		Ambient = Color3.fromRGB(58, 58, 64),
		OutdoorAmbient = Color3.fromRGB(82, 82, 90),

		FogColor = Color3.fromRGB(72, 72, 78),
		FogStart = 180,
		FogEnd = 1500,

		AtmosphereColor = Color3.fromRGB(205, 205, 200),
		AtmosphereDecay = Color3.fromRGB(62, 62, 70),
		AtmosphereDensity = 0.22,
		AtmosphereOffset = 0.05,
		AtmosphereGlare = 0.04,
		AtmosphereHaze = 0.75,

		BloomIntensity = 0.035,
		BloomThreshold = 0.9,
		BloomSize = 28,

		SunRaysIntensity = 0,
		SunRaysSpread = 0.65,

		BlurSize = 0.25,

		ColorBrightness = 0.01,
		ColorContrast = 0.08,
		ColorSaturation = -0.03,
		TintColor = Color3.fromRGB(235, 235, 230),

		DofFar = 0.06,
	},
}

local function getFramePair(t)
	t = math.clamp(t, 0, 24)

	for i = 1, #keyframes - 1 do
		local a = keyframes[i]
		local b = keyframes[i + 1]

		if t >= a.time and t <= b.time then
			local alpha = (t - a.time) / (b.time - a.time)
			return a, b, smoothstep(alpha)
		end
	end

	return keyframes[1], keyframes[1], 0
end

local function applyFrame(t)
	local a, b, alpha = getFramePair(t)

	local atmosphere = getEffect("Atmosphere")
	local bloom = getEffect("Bloom")
	local sunRays = getEffect("SunRays")
	local blur = getEffect("SoftBlur")
	local color = getEffect("ColorCorrection")
	local dof = getEffect("DepthOfField")

	Lighting.Brightness = lerpNumber(a.Brightness, b.Brightness, alpha)
	Lighting.ExposureCompensation = lerpNumber(a.Exposure, b.Exposure, alpha)
	Lighting.ShadowSoftness = lerpNumber(a.ShadowSoftness, b.ShadowSoftness, alpha)

	Lighting.ColorShift_Top = lerpColor(a.ColorTop, b.ColorTop, alpha)
	Lighting.ColorShift_Bottom = lerpColor(a.ColorBottom, b.ColorBottom, alpha)
	Lighting.Ambient = lerpColor(a.Ambient, b.Ambient, alpha)
	Lighting.OutdoorAmbient = lerpColor(a.OutdoorAmbient, b.OutdoorAmbient, alpha)

	Lighting.FogColor = lerpColor(a.FogColor, b.FogColor, alpha)
	Lighting.FogStart = lerpNumber(a.FogStart, b.FogStart, alpha)
	Lighting.FogEnd = lerpNumber(a.FogEnd, b.FogEnd, alpha)

	if atmosphere then
		atmosphere.Color = lerpColor(a.AtmosphereColor, b.AtmosphereColor, alpha)
		atmosphere.Decay = lerpColor(a.AtmosphereDecay, b.AtmosphereDecay, alpha)
		atmosphere.Density = lerpNumber(a.AtmosphereDensity, b.AtmosphereDensity, alpha)
		atmosphere.Offset = lerpNumber(a.AtmosphereOffset, b.AtmosphereOffset, alpha)
		atmosphere.Glare = lerpNumber(a.AtmosphereGlare, b.AtmosphereGlare, alpha)
		atmosphere.Haze = lerpNumber(a.AtmosphereHaze, b.AtmosphereHaze, alpha)
	end

	if bloom then
		bloom.Intensity = lerpNumber(a.BloomIntensity, b.BloomIntensity, alpha)
		bloom.Threshold = lerpNumber(a.BloomThreshold, b.BloomThreshold, alpha)
		bloom.Size = lerpNumber(a.BloomSize, b.BloomSize, alpha)
	end

	if sunRays then
		sunRays.Intensity = lerpNumber(a.SunRaysIntensity, b.SunRaysIntensity, alpha)
		sunRays.Spread = lerpNumber(a.SunRaysSpread, b.SunRaysSpread, alpha)
	end

	if blur then
		blur.Size = lerpNumber(a.BlurSize, b.BlurSize, alpha)
	end

	if color then
		color.Brightness = lerpNumber(a.ColorBrightness, b.ColorBrightness, alpha)
		color.Contrast = lerpNumber(a.ColorContrast, b.ColorContrast, alpha)
		color.Saturation = lerpNumber(a.ColorSaturation, b.ColorSaturation, alpha)
		color.TintColor = lerpColor(a.TintColor, b.TintColor, alpha)
	end

	if dof then
		dof.FarIntensity = lerpNumber(a.DofFar, b.DofFar, alpha)
		dof.FocusDistance = 120
		dof.InFocusRadius = 70
		dof.NearIntensity = 0.02
	end
end

local function applyBaconShader()
	clearOldEffects()

	safeSet(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.75
	Lighting.EnvironmentSpecularScale = 0.65

	local sky = Instance.new("Sky")
	sky.Name = PREFIX .. "CleanSky"
	sky.SunAngularSize = 11
	sky.MoonAngularSize = 12
	sky.StarCount = 2800
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	New("Atmosphere", { Name = PREFIX .. "Atmosphere" }, Lighting)
	New("BloomEffect", { Name = PREFIX .. "Bloom" }, Lighting)
	New("SunRaysEffect", { Name = PREFIX .. "SunRays" }, Lighting)
	New("BlurEffect", { Name = PREFIX .. "SoftBlur" }, Lighting)
	New("ColorCorrectionEffect", { Name = PREFIX .. "ColorCorrection" }, Lighting)
	New("DepthOfFieldEffect", { Name = PREFIX .. "DepthOfField" }, Lighting)

	applyFrame(Lighting.ClockTime)
end

local function disableBaconShader()
	restoreOriginalLighting()
end

local WEATHER_MODE = "Sunny"
local weatherBlend = 0
local targetWeatherBlend = 0
local weatherKindBlend = 0
local targetWeatherKindBlend = 0

local WEATHER_TRANSITION_SPEED = 0.30
local RAIN_STREAK_COUNT = 900
local IMPACTS_PER_SECOND_SUN = 34
local IMPACTS_PER_SECOND_OVERCAST = 58
local RAIN_RADIUS = 62
local RAIN_TOP = 46
local RAIN_BOTTOM = -12
local WATER_GRID = 5
local WATER_MAX_CELLS = 42
local WATER_DRY_SPEED = 0.008
local WATER_GAIN_GROUND = 0.065
local WATER_GAIN_WATER = 0.042

local WATER_RULES = {
    MergeRadius = 7.5,
    FallbackRadius = 22,
    WetThreshold = 0.04,
    PuddleThreshold = 0.22,
    FullThreshold = 0.985,
    MinDiameter = 3.8,
    MaxDiameter = 8.5,
}

local weatherFolder = New("Folder", { Name = PREFIX .. "Weather" }, Workspace)
local rainFolder = New("Folder", { Name = "RainStreaks" }, weatherFolder)
local waterFolder = New("Folder", { Name = "DynamicWater" }, weatherFolder)
local effectFolder = New("Folder", { Name = "ImpactEffects" }, weatherFolder)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local rainStreaks = {}
local waterCells = {}
local waterCellCount = 0
local impactAccumulator = 0
local rng = Random.new()

local function weatherLerp(a, b, t)
    return a + (b - a) * t
end

local function weatherColor(a, b, t)
    return a:Lerp(b, t)
end

local function setWeather(mode)
    WEATHER_MODE = mode
    if mode == "Sunny" then
        targetWeatherBlend = 0
        impactAccumulator = 0
    elseif mode == "SunRain" then
        targetWeatherBlend = 1
        targetWeatherKindBlend = 0
    else
        targetWeatherBlend = 1
        targetWeatherKindBlend = 1
    end

    if WEATHER_CONTROL.SetExpanded then
        WEATHER_CONTROL.SetExpanded(mode ~= "Sunny")
    end
end

local function resetRainStreak(streak, center, randomY)
    local y = randomY and rng:NextNumber(RAIN_BOTTOM, RAIN_TOP) or rng:NextNumber(RAIN_TOP, RAIN_TOP + 22)
    streak.offset = Vector3.new(
        rng:NextNumber(-RAIN_RADIUS, RAIN_RADIUS),
        y,
        rng:NextNumber(-RAIN_RADIUS, RAIN_RADIUS)
    )
    streak.speed = rng:NextNumber(78, 122)
    streak.part.Position = center + streak.offset
end

for i = 1, RAIN_STREAK_COUNT do
    local p = New("Part", {
        Name = "Rain",
        Anchored = true,
        CanCollide = false,
        CanTouch = false,
        CanQuery = false,
        CastShadow = false,
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(196, 220, 244),
        Transparency = 1,
        Size = Vector3.new(0.035, rng:NextNumber(2.7, 5.2), 0.035),
    }, rainFolder)
    local item = { part = p, offset = Vector3.zero, speed = 90 }
    resetRainStreak(item, Vector3.zero, true)
    rainStreaks[i] = item
end

local function cellKey(pos)
    return math.floor(pos.X / WATER_GRID) .. ":" .. math.floor(pos.Z / WATER_GRID)
end

local function makeWaterPatch(cell, hitPos, hitNormal)
    local model = New("Model", { Name = "WaterPatch" }, waterFolder)
    cell.model = model
    cell.parts = {}
    cell.maxDiameter = rng:NextNumber(WATER_RULES.MinDiameter, WATER_RULES.MaxDiameter)

    for i = 1, 6 do
        local patch = New("Part", {
            Name = "WaterLobe",
            Anchored = true,
            CanCollide = false,
            CanTouch = false,
            CanQuery = false,
            CastShadow = false,
            Material = Enum.Material.SmoothPlastic,
            Color = Color3.fromRGB(82, 96, 108),
            Transparency = 1,
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(0.12, 0.018, 0.12),
        }, model)

        local angle = rng:NextNumber(0, math.pi * 2)
        cell.parts[i] = {
            part = patch,
            direction = Vector3.new(math.cos(angle), 0, math.sin(angle)),
            offsetRatio = i == 1 and 0 or rng:NextNumber(0.08, 0.27),
            scaleX = rng:NextNumber(0.52, 0.92),
            scaleZ = rng:NextNumber(0.45, 0.86),
        }
    end
end

local function createRipple(pos, size, strength)
    local ring = New("Part", {
        Name = "Ripple",
        Anchored = true,
        CanCollide = false,
        CanTouch = false,
        CanQuery = false,
        CastShadow = false,
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(205, 230, 248),
        Transparency = 0.28,
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.025, size * 0.2, size * 0.2),
        CFrame = CFrame.new(pos + Vector3.new(0, 0.025, 0)) * CFrame.Angles(0, 0, math.rad(90)),
    }, effectFolder)

    TweenService:Create(ring, TweenInfo.new(0.32 + strength * 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.018, size, size),
        Transparency = 1,
    }):Play()
    task.delay(0.5, function() if ring then ring:Destroy() end end)
end

local function createSplash(pos, strong)
    local count = strong and rng:NextInteger(4, 7) or rng:NextInteger(1, 3)
    for _ = 1, count do
        local d = New("Part", {
            Name = "SplashDrop",
            Anchored = true,
            CanCollide = false,
            CanTouch = false,
            CanQuery = false,
            CastShadow = false,
            Material = Enum.Material.Neon,
            Color = Color3.fromRGB(215, 235, 250),
            Transparency = 0.12,
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(0.06, 0.11, 0.06) * (strong and 1.25 or 0.8),
            Position = pos + Vector3.new(0, 0.04, 0),
        }, effectFolder)
        local angle = rng:NextNumber(0, math.pi * 2)
        local radius = rng:NextNumber(0.2, strong and 0.9 or 0.45)
        local target = pos + Vector3.new(math.cos(angle) * radius, rng:NextNumber(0.18, strong and 0.65 or 0.35), math.sin(angle) * radius)
        TweenService:Create(d, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target }):Play()
        task.delay(0.13, function()
            if d and d.Parent then
                TweenService:Create(d, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = Vector3.new(target.X, pos.Y + 0.02, target.Z),
                    Transparency = 1,
                }):Play()
            end
        end)
        task.delay(0.36, function() if d then d:Destroy() end end)
    end
end

local function addWaterAt(hitPos, hitNormal)
    if hitNormal.Y < 0.78 then
        return false
    end

    local cell
    local cellKeyFound
    local nearestDistance = WATER_RULES.MergeRadius

    for key, candidate in pairs(waterCells) do
        if candidate.amount < WATER_RULES.FullThreshold then
            local distance = (Vector2.new(candidate.position.X, candidate.position.Z)
                - Vector2.new(hitPos.X, hitPos.Z)).Magnitude

            if distance <= nearestDistance then
                nearestDistance = distance
                cell = candidate
                cellKeyFound = key
            end
        end
    end

    if not cell and waterCellCount >= WATER_MAX_CELLS then
        nearestDistance = WATER_RULES.FallbackRadius

        for key, candidate in pairs(waterCells) do
            if candidate.amount < WATER_RULES.FullThreshold then
                local distance = (Vector2.new(candidate.position.X, candidate.position.Z)
                    - Vector2.new(hitPos.X, hitPos.Z)).Magnitude

                if distance <= nearestDistance then
                    nearestDistance = distance
                    cell = candidate
                    cellKeyFound = key
                end
            end
        end
    end

    if not cell then
        if waterCellCount >= WATER_MAX_CELLS then
            return false
        end

        cellKeyFound = cellKey(hitPos)
            .. "#"
            .. tostring(math.floor(os.clock() * 1000))
            .. ":"
            .. tostring(rng:NextInteger(1, 999999))

        cell = {
            amount = 0,
            position = hitPos + hitNormal * 0.018,
            normal = hitNormal,
            lastHit = os.clock(),
        }

        waterCells[cellKeyFound] = cell
        waterCellCount += 1
        makeWaterPatch(cell, hitPos, hitNormal)
    end

    local alreadyWater = cell.amount >= WATER_RULES.PuddleThreshold
    local gain = alreadyWater and WATER_GAIN_WATER or WATER_GAIN_GROUND

    cell.amount = math.clamp(
        cell.amount + gain * WEATHER_CONTROL.WaterMultiplier,
        0,
        1
    )
    cell.lastHit = os.clock()

    return alreadyWater
end

local function impactRain(cameraPos)
    local origin = cameraPos + Vector3.new(rng:NextNumber(-RAIN_RADIUS, RAIN_RADIUS), RAIN_TOP, rng:NextNumber(-RAIN_RADIUS, RAIN_RADIUS))
    local direction = Vector3.new(-4, -(RAIN_TOP + 85), -1.5)
    local character = player.Character
    rayParams.FilterDescendantsInstances = { character, weatherFolder, workspace.CurrentCamera }
    local hit = Workspace:Raycast(origin, direction, rayParams)
    if not hit then return end
    if hit.Instance and hit.Instance:IsDescendantOf(weatherFolder) then return end

    local waterHit = addWaterAt(hit.Position, hit.Normal)
    createRipple(hit.Position, waterHit and rng:NextNumber(0.8, 1.6) or rng:NextNumber(0.28, 0.65), waterHit and 1 or 0.3)
    createSplash(hit.Position, waterHit)
end

local function updateWater(dt)
    for key, cell in pairs(waterCells) do
        local drying = WEATHER_MODE == "Sunny"
            and WATER_DRY_SPEED
            or WATER_DRY_SPEED * 0.10

        cell.amount = math.max(0, cell.amount - drying * dt)

        if cell.amount <= 0.001 then
            if cell.model then
                cell.model:Destroy()
            end

            waterCells[key] = nil
            waterCellCount -= 1
        else

            local wetAlpha = math.clamp(
                cell.amount / WATER_RULES.PuddleThreshold,
                0,
                1
            )

            local puddleAlpha = math.clamp(
                (cell.amount - WATER_RULES.PuddleThreshold)
                    / (1 - WATER_RULES.PuddleThreshold),
                0,
                1
            )

            local growth = smoothstep(cell.amount)
            local diameter = math.min(
                0.32 + (cell.maxDiameter - 0.32) * growth,
                cell.maxDiameter
            )

            for _, info in ipairs(cell.parts or {}) do
                local p = info.part

                if p then
                    local offset = info.direction
                        * diameter
                        * info.offsetRatio

                    p.Position = cell.position + offset
                    p.Size = Vector3.new(
                        math.min(diameter * info.scaleX, cell.maxDiameter),
                        0.018 + puddleAlpha * 0.025,
                        math.min(diameter * info.scaleZ, cell.maxDiameter)
                    )

                    if puddleAlpha < 0.02 then

                        p.Material = Enum.Material.SmoothPlastic
                        p.Color = weatherColor(
                            Color3.fromRGB(75, 88, 98),
                            Color3.fromRGB(53, 63, 77),
                            weatherKindBlend
                        )
                        p.Transparency = 1 - wetAlpha * 0.23
                    else

                        p.Material = Enum.Material.Glass
                        p.Color = weatherColor(
                            Color3.fromRGB(125, 155, 180),
                            Color3.fromRGB(65, 86, 108),
                            weatherKindBlend
                        )
                        p.Transparency = 0.88
                            - puddleAlpha * (0.18 + weatherKindBlend * 0.07)
                    end
                end
            end
        end
    end
end

local function applyWeatherOverlay(t)
    if not ENABLED then return end
    local a, b, alpha = getFramePair(t)

    local baseBrightness = lerpNumber(a.Brightness, b.Brightness, alpha)
    local baseExposure = lerpNumber(a.Exposure, b.Exposure, alpha)
    local baseAmbient = lerpColor(a.Ambient, b.Ambient, alpha)
    local baseOutdoor = lerpColor(a.OutdoorAmbient, b.OutdoorAmbient, alpha)
    local baseFogColor = lerpColor(a.FogColor, b.FogColor, alpha)
    local baseFogStart = lerpNumber(a.FogStart, b.FogStart, alpha)
    local baseFogEnd = lerpNumber(a.FogEnd, b.FogEnd, alpha)

    local rain = weatherBlend
    local dark = weatherKindBlend * rain
    Lighting.Brightness = baseBrightness * weatherLerp(1, weatherLerp(0.96, 0.52, weatherKindBlend), rain)
    Lighting.ExposureCompensation = baseExposure + weatherLerp(0, weatherLerp(-0.04, -0.52, weatherKindBlend), rain)
    Lighting.Ambient = baseAmbient:Lerp(weatherColor(Color3.fromRGB(112, 120, 128), Color3.fromRGB(52, 62, 76), weatherKindBlend), rain * (0.35 + dark * 0.5))
    Lighting.OutdoorAmbient = baseOutdoor:Lerp(weatherColor(Color3.fromRGB(140, 148, 156), Color3.fromRGB(66, 78, 94), weatherKindBlend), rain * (0.32 + dark * 0.55))
    Lighting.FogColor = baseFogColor:Lerp(weatherColor(Color3.fromRGB(185, 198, 210), Color3.fromRGB(104, 118, 136), weatherKindBlend), rain * (0.28 + dark * 0.48))
    Lighting.FogStart = weatherLerp(baseFogStart, weatherLerp(120, 24, weatherKindBlend), rain)
    Lighting.FogEnd = weatherLerp(baseFogEnd, weatherLerp(1400, 390, weatherKindBlend), rain)

    local atmosphere = getEffect("Atmosphere")
    local bloom = getEffect("Bloom")
    local sunRays = getEffect("SunRays")
    local blur = getEffect("SoftBlur")
    local color = getEffect("ColorCorrection")

    if atmosphere then
        atmosphere.Density = weatherLerp(lerpNumber(a.AtmosphereDensity, b.AtmosphereDensity, alpha), weatherLerp(0.24, 0.47, weatherKindBlend), rain)
        atmosphere.Haze = weatherLerp(lerpNumber(a.AtmosphereHaze, b.AtmosphereHaze, alpha), weatherLerp(1.05, 3.4, weatherKindBlend), rain)
        atmosphere.Glare = weatherLerp(lerpNumber(a.AtmosphereGlare, b.AtmosphereGlare, alpha), weatherLerp(0.07, 0, weatherKindBlend), rain)
    end
    if sunRays then
        local base = lerpNumber(a.SunRaysIntensity, b.SunRaysIntensity, alpha)
        sunRays.Intensity = weatherLerp(base, base * weatherLerp(0.72, 0.03, weatherKindBlend), rain)
    end
    if bloom then
        bloom.Intensity = weatherLerp(lerpNumber(a.BloomIntensity, b.BloomIntensity, alpha), weatherLerp(0.055, 0.025, weatherKindBlend), rain)
    end
    if blur then
        blur.Size = weatherLerp(lerpNumber(a.BlurSize, b.BlurSize, alpha), weatherLerp(0.35, 0.85, weatherKindBlend), rain)
    end
    if color then
        color.Brightness = weatherLerp(lerpNumber(a.ColorBrightness, b.ColorBrightness, alpha), weatherLerp(0.005, -0.09, weatherKindBlend), rain)
        color.Contrast = weatherLerp(lerpNumber(a.ColorContrast, b.ColorContrast, alpha), weatherLerp(0.08, 0.14, weatherKindBlend), rain)
        color.Saturation = weatherLerp(lerpNumber(a.ColorSaturation, b.ColorSaturation, alpha), weatherLerp(-0.08, -0.42, weatherKindBlend), rain)
        color.TintColor = lerpColor(a.TintColor, b.TintColor, alpha):Lerp(weatherColor(Color3.fromRGB(238, 247, 255), Color3.fromRGB(178, 198, 222), weatherKindBlend), rain)
    end
end

local function updateWeather(dt)

    local blendSpeed = targetWeatherBlend <= 0
        and 4.5
        or WEATHER_TRANSITION_SPEED

    weatherBlend += (targetWeatherBlend - weatherBlend)
        * math.clamp(dt * blendSpeed, 0, 1)

    weatherKindBlend += (targetWeatherKindBlend - weatherKindBlend)
        * math.clamp(dt * WEATHER_TRANSITION_SPEED, 0, 1)

    local camera = Workspace.CurrentCamera
    if not camera then return end
    local center = camera.CFrame.Position

    local baseVisibleCount = weatherLerp(212, 294, weatherKindBlend)
    local visibleCount = math.floor(
        baseVisibleCount
            * weatherBlend
            * (WEATHER_CONTROL.VisualMultiplier / 0.70)
    )
    visibleCount = math.clamp(visibleCount, 0, RAIN_STREAK_COUNT)
    local windX = weatherLerp(3.5, 9.5, weatherKindBlend)

    for i, streak in ipairs(rainStreaks) do
        local p = streak.part
        if i <= visibleCount and weatherBlend > 0.01 then
            streak.offset -= Vector3.new(windX, streak.speed, 2.2) * dt
            if streak.offset.Y < RAIN_BOTTOM then resetRainStreak(streak, center, false) end
            p.Position = center + streak.offset
            p.Transparency = weatherLerp(0.62, 0.22, weatherBlend) + weatherKindBlend * 0.06
            p.Color = weatherColor(Color3.fromRGB(222, 238, 250), Color3.fromRGB(165, 198, 230), weatherKindBlend)
        else
            p.Transparency = 1
        end
    end

    local rate = weatherLerp(
        IMPACTS_PER_SECOND_SUN,
        IMPACTS_PER_SECOND_OVERCAST,
        weatherKindBlend
    ) * weatherBlend * WEATHER_CONTROL.ImpactMultiplier
    impactAccumulator += dt * rate
    while impactAccumulator >= 1 do
        impactAccumulator -= 1
        impactRain(center)
    end

    updateWater(dt)
    applyWeatherOverlay(Lighting.ClockTime)
end

local gui = New("ScreenGui", {
	Name = PREFIX .. "LiquidTimeGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local main = New("Frame", {
	Name = "LiquidGlassPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(PANEL_START_CENTER.X, PANEL_START_CENTER.Y),
	Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.74,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Active = true,
	ZIndex = 50,
}, gui)

Corner(main, UDim.new(0, PANEL_RADIUS))

local uiScale = New("UIScale", { Scale = 1 }, main)

local tint = New("Frame", {
	Name = "GlassTint",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.74,
	BorderSizePixel = 0,
	ZIndex = 51,
}, main)

Corner(tint, UDim.new(0, PANEL_RADIUS))

local tintGradient = New("UIGradient", {
	Rotation = 25,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(218, 235, 255)),
		ColorSequenceKeypoint.new(0.68, Color3.fromRGB(255, 240, 205)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.58),
		NumberSequenceKeypoint.new(0.5, 0.91),
		NumberSequenceKeypoint.new(1, 0.62),
	}),
}, tint)

local stroke = Stroke(main, 1.6, 0.2, Color3.fromRGB(255, 255, 255))

local strokeGradient = New("UIGradient", {
	Rotation = 0,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(220, 232, 245)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(175, 195, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04),
		NumberSequenceKeypoint.new(0.5, 0.32),
		NumberSequenceKeypoint.new(1, 0.08),
	}),
}, stroke)

local topShine = New("Frame", {
	Name = "TopShine",
	Position = UDim2.fromOffset(20, 10),
	Size = UDim2.new(1, -40, 0, 31),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.74,
	BorderSizePixel = 0,
	ZIndex = 55,
}, main)

Corner(topShine, UDim.new(1, 0))

local topShineGradient = New("UIGradient", {
	Rotation = 0,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.16),
		NumberSequenceKeypoint.new(0.7, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, topShine)

local waveHolder = New("Frame", {
	Name = "GlassWaves",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 56,
}, main)

local function makeWave(name, y, h, rot, transparency)
	local wave = New("Frame", {
		Name = name,
		Position = UDim2.fromOffset(-85, y),
		Size = UDim2.new(1, 170, 0, h),
		Rotation = rot,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 56,
	}, waveHolder)

	Corner(wave, UDim.new(1, 0))

	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.28, 0.82),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(0.72, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, wave)

	return wave
end

local wave1Base = Vector2.new(-85, 39)
local wave2Base = Vector2.new(-95, 84)
local wave1 = makeWave("Wave1", wave1Base.Y, 25, -7, 0.91)
local wave2 = makeWave("Wave2", wave2Base.Y, 21, 7, 0.94)

local realLiquidGlassActive = false

local LiquidGlass = {
	Items = {},
}

local liquidModuleLayer = New("Frame", {
	Name = "LiquidGlassModuleLayer",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 58,
}, main)

local function createLiquidBlob(name, pos, size, color, transparency, z)
	local blob = New("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = size,
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = z or 58,
	}, liquidModuleLayer)

	Corner(blob, UDim.new(1, 0))

	local gradient = New("UIGradient", {
		Rotation = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.22, 0.72),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(0.78, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, blob)

	table.insert(LiquidGlass.Items, {
		Kind = "Blob",
		Object = blob,
		Gradient = gradient,
		BasePosition = pos,
		BaseTransparency = transparency,
		Seed = #LiquidGlass.Items * 1.73 + 0.45,
	})

	return blob
end

local liquidBlob1 = createLiquidBlob(
	"LiquidRefractionBlob_A",
	UDim2.new(0.2, 0, 0.28, 0),
	UDim2.fromOffset(170, 55),
	Color3.fromRGB(255, 255, 255),
	0.92,
	58
)

local liquidBlob2 = createLiquidBlob(
	"LiquidRefractionBlob_B",
	UDim2.new(0.76, 0, 0.68, 0),
	UDim2.fromOffset(150, 46),
	Color3.fromRGB(210, 232, 255),
	0.94,
	58
)

local liquidBlob3 = createLiquidBlob(
	"LiquidRefractionBlob_C",
	UDim2.new(0.52, 0, 0.48, 0),
	UDim2.fromOffset(220, 34),
	Color3.fromRGB(255, 238, 200),
	0.955,
	58
)

local innerEdge = New("Frame", {
	Name = "LiquidInnerEdge",
	Position = UDim2.fromOffset(3, 3),
	Size = UDim2.new(1, -6, 1, -6),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 59,
}, main)

Corner(innerEdge, UDim.new(0, PANEL_RADIUS - 3))
local innerEdgeStroke = Stroke(innerEdge, 1.1, 0.52, Color3.fromRGB(255, 255, 255))

local innerEdgeGradient = New("UIGradient", {
	Rotation = 28,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.38, Color3.fromRGB(190, 210, 230)),
		ColorSequenceKeypoint.new(0.62, Color3.fromRGB(255, 244, 214)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(0.5, 0.78),
		NumberSequenceKeypoint.new(1, 0.2),
	}),
}, innerEdgeStroke)

local liquidSpecular = New("Frame", {
	Name = "LiquidSpecularSweep",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.52, 0.5),
	Size = UDim2.new(1, 96, 0, 28),
	Rotation = -16,
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.86,
	BorderSizePixel = 0,
	ZIndex = 60,
}, liquidModuleLayer)

Corner(liquidSpecular, UDim.new(1, 0))

local liquidSpecularGradient = New("UIGradient", {
	Rotation = 0,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.84),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(0.65, 0.84),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, liquidSpecular)

local liquidBottomShade = New("Frame", {
	Name = "LiquidBottomShade",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 8),
	Size = UDim2.new(1, -24, 0, 42),
	BackgroundColor3 = Color3.fromRGB(120, 140, 165),
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
	ZIndex = 57,
}, main)

Corner(liquidBottomShade, UDim.new(1, 0))

local liquidBottomGradient = New("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.55, 0.46),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, liquidBottomShade)

local function pulseLiquidGlass(strength)
	if realLiquidGlassActive then
		TweenService:Create(innerEdgeStroke, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Transparency = 0.26,
			Thickness = 1.35,
		}):Play()

		task.delay(0.14, function()
			TweenService:Create(innerEdgeStroke, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Transparency = 0.52,
				Thickness = 1.1,
			}):Play()
		end)

		return
	end

	strength = strength or 1

	TweenService:Create(liquidSpecular, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundTransparency = math.clamp(0.76 - strength * 0.08, 0.58, 0.9),
		Size = UDim2.new(1, 118 + strength * 16, 0, 30 + strength * 4),
	}):Play()

	TweenService:Create(innerEdgeStroke, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Transparency = math.clamp(0.34 - strength * 0.08, 0.18, 0.64),
		Thickness = 1.25 + strength * 0.18,
	}):Play()

	task.delay(0.13, function()
		TweenService:Create(liquidSpecular, TweenInfo.new(0.32, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.86,
			Size = UDim2.new(1, 96, 0, 28),
		}):Play()

		TweenService:Create(innerEdgeStroke, TweenInfo.new(0.32, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Transparency = 0.52,
			Thickness = 1.1,
		}):Play()
	end)
end

local dragBar = New("TextButton", {
	Name = "DragBar",
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, 0, 0, 42),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 90,
}, main)

local title = New("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(17, 9),
	Size = UDim2.new(1, -55, 0, 24),
	BackgroundTransparency = 1,
	Text = "培根光影",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextStrokeColor3 = Color3.fromRGB(20, 24, 30),
	TextStrokeTransparency = 0.88,
	TextTransparency = 0.02,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 100,
}, main)

local mini = New("TextButton", {
	Name = "Mini",
	Position = UDim2.new(1, -37, 0, 9),
	Size = UDim2.fromOffset(25, 25),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.72,
	BorderSizePixel = 0,
	Text = "－",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	ZIndex = 110,
}, main)

Corner(mini, UDim.new(1, 0))
Stroke(mini, 1, 0.55, Color3.fromRGB(255, 255, 255))

local miniScale = New("UIScale", { Scale = 1 }, mini)

local contentGroup = New("CanvasGroup", {
	Name = "ContentGroup",
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
	BackgroundTransparency = 1,
	GroupTransparency = 0,
	ZIndex = 95,
}, main)

local timeText = New("TextLabel", {
	Name = "TimeText",
	Position = UDim2.fromOffset(17, 34),
	Size = UDim2.new(1, -34, 0, 20),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(245, 250, 255),
	TextStrokeColor3 = Color3.fromRGB(20, 24, 30),
	TextStrokeTransparency = 0.88,
	TextTransparency = 0.08,
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 100,
}, contentGroup)

local track = New("TextButton", {
	Name = "LiquidSliderTrack",
	Position = UDim2.fromOffset(24, 68),
	Size = UDim2.new(1, -48, 0, 6),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.54,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 120,
}, contentGroup)

Corner(track, UDim.new(1, 0))
Stroke(track, 1, 0.8, Color3.fromRGB(255, 255, 255))

local fill = New("Frame", {
	Name = "LiquidSliderProgress",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.34,
	BorderSizePixel = 0,
	ZIndex = 121,
}, track)

Corner(fill, UDim.new(1, 0))

local fillGradient = New("UIGradient", {
	Rotation = 0,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 235, 190)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(0.5, 0.08),
		NumberSequenceKeypoint.new(1, 0.25),
	}),
}, fill)

local knob = New("TextButton", {
	Name = "LiquidSliderThumb",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromOffset(42, 24),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.16,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ClipsDescendants = true,
	ZIndex = 130,
}, track)

Corner(knob, UDim.new(1, 0))

local knobStroke = Stroke(knob, 1.1, 0.42, Color3.fromRGB(255, 255, 255))

local knobGlassFilter = New("Frame", {
	Name = "GlassFilter",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.82,
	BorderSizePixel = 0,
	ZIndex = 131,
}, knob)

Corner(knobGlassFilter, UDim.new(1, 0))

local knobFilterGradient = New("UIGradient", {
	Rotation = 25,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(220, 235, 255)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 245, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.82),
		NumberSequenceKeypoint.new(0.5, 0.46),
		NumberSequenceKeypoint.new(1, 0.84),
	}),
}, knobGlassFilter)

local knobOverlay = New("Frame", {
	Name = "GlassOverlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
	ZIndex = 132,
}, knob)

Corner(knobOverlay, UDim.new(1, 0))

local knobSpecular = New("Frame", {
	Name = "GlassSpecular",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 133,
}, knob)

Corner(knobSpecular, UDim.new(1, 0))

local knobSpecStroke = Stroke(knobSpecular, 1.2, 0.22, Color3.fromRGB(255, 255, 255))

local knobInnerGlow = New("Frame", {
	Name = "InnerGlow",
	Position = UDim2.fromOffset(2, 2),
	Size = UDim2.new(1, -4, 1, -4),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 134,
}, knob)

Corner(knobInnerGlow, UDim.new(1, 0))

local innerGlowStroke = Stroke(knobInnerGlow, 1, 0.66, Color3.fromRGB(255, 255, 255))

local knobTopHighlight = New("Frame", {
	Name = "TopHighlight",
	Position = UDim2.fromOffset(8, 4),
	Size = UDim2.new(1, -16, 0, 7),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	ZIndex = 135,
}, knob)

Corner(knobTopHighlight, UDim.new(1, 0))

local knobTopGradient = New("UIGradient", {
	Rotation = 0,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.12),
		NumberSequenceKeypoint.new(0.72, 0.58),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, knobTopHighlight)

local knobBottomShade = New("Frame", {
	Name = "BottomShade",
	Position = UDim2.new(0, 7, 1, -9),
	Size = UDim2.new(1, -14, 0, 6),
	BackgroundColor3 = Color3.fromRGB(170, 185, 200),
	BackgroundTransparency = 0.84,
	BorderSizePixel = 0,
	ZIndex = 134,
}, knob)

Corner(knobBottomShade, UDim.new(1, 0))

local knobActive = false

local function setKnobActive(active)
	knobActive = active

	if active then
		pulseLiquidGlass(1)
		TweenService:Create(knob, TweenInfo.new(0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(48, 23),
			BackgroundTransparency = 0.62,
		}):Play()

		TweenService:Create(knobStroke, TweenInfo.new(0.14), {
			Transparency = 0.18,
			Thickness = 1.6,
		}):Play()

		TweenService:Create(knobGlassFilter, TweenInfo.new(0.14), {
			BackgroundTransparency = 0.72,
		}):Play()

		TweenService:Create(knobOverlay, TweenInfo.new(0.14), {
			BackgroundTransparency = 0.82,
		}):Play()

		TweenService:Create(knobTopHighlight, TweenInfo.new(0.14), {
			BackgroundTransparency = 0.3,
		}):Play()

		TweenService:Create(knobBottomShade, TweenInfo.new(0.14), {
			BackgroundTransparency = 0.72,
		}):Play()
	else
		TweenService:Create(knob, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(42, 24),
			BackgroundTransparency = 0.16,
		}):Play()

		TweenService:Create(knobStroke, TweenInfo.new(0.22), {
			Transparency = 0.42,
			Thickness = 1.1,
		}):Play()

		TweenService:Create(knobGlassFilter, TweenInfo.new(0.22), {
			BackgroundTransparency = 0.82,
		}):Play()

		TweenService:Create(knobOverlay, TweenInfo.new(0.22), {
			BackgroundTransparency = 0.9,
		}):Play()

		TweenService:Create(knobTopHighlight, TweenInfo.new(0.22), {
			BackgroundTransparency = 0.45,
		}):Play()

		TweenService:Create(knobBottomShade, TweenInfo.new(0.22), {
			BackgroundTransparency = 0.84,
		}):Play()
	end
end

local function makeButton(text, x)
	local btn = New("TextButton", {
		Size = UDim2.fromOffset(58, 21),
		Position = UDim2.fromOffset(x, 88),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTransparency = 0.04,
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		AutoButtonColor = false,
		ClipsDescendants = true,
		ZIndex = 100,
	}, contentGroup)

	Corner(btn, UDim.new(0, 10))
	local btnStroke = Stroke(btn, 1, 0.68, Color3.fromRGB(255, 255, 255))

	New("UIGradient", {
		Rotation = 22,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.52, Color3.fromRGB(215, 232, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 245, 220)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(0.52, 0.48),
			NumberSequenceKeypoint.new(1, 0.86),
		}),
	}, btn)

	local btnShine = New("Frame", {
		Name = "ButtonLiquidShine",
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.new(1, -12, 0, 6),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.62,
		BorderSizePixel = 0,
		ZIndex = 101,
	}, btn)

	Corner(btnShine, UDim.new(1, 0))

	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 0.18),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, btnShine)

	return btn
end

local btnNight = nil
local btnMorning = nil
local btnNoon = nil
local btnSunset = nil

WEATHER_CONTROL.MenuExpanded = false
WEATHER_CONTROL.MenuProgress = 0
WEATHER_CONTROL.MenuTarget = 0
WEATHER_CONTROL.MenuVelocity = 0
WEATHER_CONTROL.MenuAnimating = false

WEATHER_CONTROL.MenuButton = New("TextButton", {
    Name = "WeatherMenuButton",
    Position = UDim2.fromOffset(18, 91),
    Size = UDim2.new(1, -36, 0, 32),
    BackgroundColor3 = Color3.fromRGB(255, 205, 95),
    BackgroundTransparency = 0.76,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 140,
}, contentGroup)
Corner(WEATHER_CONTROL.MenuButton, UDim.new(0, 10))
Stroke(WEATHER_CONTROL.MenuButton, 1, 0.62, Color3.fromRGB(255, 255, 255))

WEATHER_CONTROL.MenuLabel = New("TextLabel", {
    Position = UDim2.fromOffset(12, 0),
    Size = UDim2.fromOffset(70, 29),
    BackgroundTransparency = 1,
    Text = "天氣",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 11,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 141,
}, WEATHER_CONTROL.MenuButton)

WEATHER_CONTROL.MenuValue = New("TextLabel", {
    Position = UDim2.new(0, 80, 0, 0),
    Size = UDim2.new(1, -112, 1, 0),
    BackgroundTransparency = 1,
    Text = "晴天",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 141,
}, WEATHER_CONTROL.MenuButton)

WEATHER_CONTROL.MenuArrow = New("TextLabel", {
    Position = UDim2.new(1, -28, 0, 0),
    Size = UDim2.fromOffset(20, 29),
    BackgroundTransparency = 1,
    Text = "⌄",
    Rotation = 0,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    ZIndex = 141,
}, WEATHER_CONTROL.MenuButton)

local function makeWeatherButton(text, x, width)
    local btn = New("TextButton", {
        Size = UDim2.fromOffset(width, 25),
        Position = UDim2.fromOffset(x, 127),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 10,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 140,
    }, contentGroup)
    Corner(btn, UDim.new(0, 9))
    Stroke(btn, 1, 0.7, Color3.fromRGB(255,255,255))
    return btn
end

local btnSunnyWeather = makeWeatherButton("晴天", 18, 75)
local btnSunRain = makeWeatherButton("太陽雨", 105, 75)
local btnOvercastRain = makeWeatherButton("陰天雨", 192, 76)

local weatherButtons = {
    Sunny = btnSunnyWeather,
    SunRain = btnSunRain,
    OvercastRain = btnOvercastRain,
}

local function refreshWeatherButtons()
    local uiValue = SETTINGS_CONTROL.PreviewTransparency
        or SETTINGS_CONTROL.SavedTransparency
        or 1

    local inactiveTextColor = lerpColor(
        Color3.fromRGB(28, 33, 42),
        Color3.fromRGB(255, 255, 255),
        uiValue
    )

    local activeTransparency = lerpNumber(0.06, 0.28, uiValue)
    local inactiveTransparency = lerpNumber(0.10, 0.58, uiValue)

    for mode, btn in pairs(weatherButtons) do
        local active = mode == WEATHER_MODE
        local activeColor

        if mode == "Sunny" then
            activeColor = Color3.fromRGB(255, 205, 95)
        elseif mode == "SunRain" then
            activeColor = Color3.fromRGB(125, 190, 245)
        else
            activeColor = Color3.fromRGB(80, 105, 138)
        end

        TweenService:Create(
            btn,
            TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {
                BackgroundTransparency = active
                    and activeTransparency
                    or inactiveTransparency,

                BackgroundColor3 = active
                    and activeColor
                    or Color3.fromRGB(255, 255, 255),

                TextColor3 = active
                    and Color3.fromRGB(255, 255, 255)
                    or inactiveTextColor,

                TextTransparency = 0,
            }
        ):Play()
    end
end

SETTINGS_CONTROL.RefreshWeatherButtons = refreshWeatherButtons

function WEATHER_CONTROL.RefreshMenuButton(animated)
    local names = {
        Sunny = "晴天",
        SunRain = "太陽雨",
        OvercastRain = "陰天雨",
    }

    local colors = {
        Sunny = Color3.fromRGB(255, 205, 95),
        SunRain = Color3.fromRGB(125, 190, 245),
        OvercastRain = Color3.fromRGB(80, 105, 138),
    }

    local value = SETTINGS_CONTROL.PreviewTransparency
        or SETTINGS_CONTROL.SavedTransparency
        or 1

    WEATHER_CONTROL.MenuValue.Text = names[WEATHER_MODE] or "晴天"

    local props = {
        BackgroundColor3 = colors[WEATHER_MODE] or colors.Sunny,
        BackgroundTransparency = lerpNumber(0.08, 0.56, value),
    }

    if animated then
        TweenService:Create(
            WEATHER_CONTROL.MenuButton,
            TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            props
        ):Play()
    else
        WEATHER_CONTROL.MenuButton.BackgroundColor3 = props.BackgroundColor3
        WEATHER_CONTROL.MenuButton.BackgroundTransparency = props.BackgroundTransparency
    end

    WEATHER_CONTROL.MenuLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    WEATHER_CONTROL.MenuValue.TextColor3 = Color3.fromRGB(255, 255, 255)
    WEATHER_CONTROL.MenuArrow.TextColor3 = Color3.fromRGB(255, 255, 255)
end

refreshWeatherButtons()
WEATHER_CONTROL.RefreshMenuButton(false)

local cycleLabel = New("TextLabel", {
	Name = "CycleLabel",
	Position = UDim2.fromOffset(18, 138),
	Size = UDim2.fromOffset(142, 18),
	BackgroundTransparency = 1,
	Text = "日夜循環",
	TextColor3 = Color3.fromRGB(245, 250, 255),
	TextStrokeColor3 = Color3.fromRGB(20, 24, 30),
	TextStrokeTransparency = 0.88,
	TextTransparency = 0.08,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 100,
}, contentGroup)

local cycleStateText = New("TextLabel", {
	Name = "CycleStateText",
	Position = UDim2.fromOffset(158, 138),
	Size = UDim2.fromOffset(54, 18),
	BackgroundTransparency = 1,
	Text = "OFF",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextStrokeColor3 = Color3.fromRGB(20, 24, 30),
	TextStrokeTransparency = 0.88,
	TextTransparency = 0.18,
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 102,
}, contentGroup)

local cycleToggle = New("TextButton", {
	Name = "CycleToggle",
	Position = UDim2.fromOffset(222, 157),
	Size = UDim2.fromOffset(50, 24),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.84,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 100,
}, contentGroup)

Corner(cycleToggle, UDim.new(1, 0))
local cycleToggleStroke = Stroke(cycleToggle, 1.2, 0.64, Color3.fromRGB(255, 255, 255))

local cycleToggleFill = New("Frame", {
	Name = "ToggleFill",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(120, 120, 125),
	BackgroundTransparency = 0.74,
	BorderSizePixel = 0,
	ZIndex = 101,
}, cycleToggle)

Corner(cycleToggleFill, UDim.new(1, 0))

local cycleToggleFillGradient = New("UIGradient", {
	Rotation = 0,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(185, 185, 190)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.5, 0.12),
		NumberSequenceKeypoint.new(1, 0.45),
	}),
}, cycleToggleFill)

local cycleToggleKnob = New("Frame", {
	Name = "ToggleKnob",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 4, 0.5, 0),
	Size = UDim2.fromOffset(16, 16),
	BackgroundColor3 = Color3.fromRGB(245, 245, 245),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	ZIndex = 104,
}, cycleToggle)

Corner(cycleToggleKnob, UDim.new(1, 0))
local cycleKnobStroke = Stroke(cycleToggleKnob, 1, 0.42, Color3.fromRGB(255, 255, 255))

local cycleToggleGlow = New("Frame", {
	Name = "ToggleGlow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 10, 1, 10),
	BackgroundColor3 = Color3.fromRGB(255, 210, 95),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 99,
}, cycleToggle)

Corner(cycleToggleGlow, UDim.new(1, 0))

local cycleFlash = New("Frame", {
	Name = "CycleFlash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 220, 120),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 57,
}, main)

Corner(cycleFlash, UDim.new(0, PANEL_RADIUS))

local cycleStateScale = New("UIScale", {
	Scale = 1,
}, cycleStateText)

local cycleClickArea = New("TextButton", {
	Name = "CycleClickArea",
	Position = UDim2.fromOffset(12, 132),
	Size = UDim2.fromOffset(PANEL_SIZE.X - 24, 28),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 180,
}, contentGroup)

local dayCycleEnabled = DAY_CYCLE_ENABLED_DEFAULT

local dayMinuteLabel = New("TextLabel", {
	Name = "DayMinuteLabel",
	Position = UDim2.fromOffset(18, 166),
	Size = UDim2.fromOffset(36, 18),
	BackgroundTransparency = 1,
	Text = "白天",
	TextColor3 = Color3.fromRGB(245, 250, 255),
	TextStrokeColor3 = Color3.fromRGB(20, 24, 30),
	TextStrokeTransparency = 0.88,
	TextTransparency = 0.08,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 100,
}, contentGroup)

local dayMinuteBox = New("TextBox", {
	Name = "DayMinuteBox",
	Position = UDim2.fromOffset(54, 163),
	Size = UDim2.fromOffset(48, 23),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.82,
	BorderSizePixel = 0,
	Text = tostring(DEFAULT_DAY_MINUTES),
	PlaceholderText = tostring(DEFAULT_DAY_MINUTES),
	ClearTextOnFocus = false,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextTransparency = 0.02,
	PlaceholderColor3 = Color3.fromRGB(210, 220, 230),
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 190,
}, contentGroup)

Corner(dayMinuteBox, UDim.new(0, 9))
Stroke(dayMinuteBox, 1, 0.72, Color3.fromRGB(255, 255, 255))

local dayMinuteUnit = New("TextLabel", {
	Name = "DayMinuteUnit",
	Position = UDim2.fromOffset(106, 166),
	Size = UDim2.fromOffset(18, 18),
	BackgroundTransparency = 1,
	Text = "分",
	TextColor3 = Color3.fromRGB(245, 250, 255),
	TextTransparency = 0.1,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 100,
}, contentGroup)

local nightMinuteLabel = New("TextLabel", {
	Name = "NightMinuteLabel",
	Position = UDim2.fromOffset(134, 166),
	Size = UDim2.fromOffset(36, 18),
	BackgroundTransparency = 1,
	Text = "夜晚",
	TextColor3 = Color3.fromRGB(245, 250, 255),
	TextStrokeColor3 = Color3.fromRGB(20, 24, 30),
	TextStrokeTransparency = 0.88,
	TextTransparency = 0.08,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 100,
}, contentGroup)

local nightMinuteBox = New("TextBox", {
	Name = "NightMinuteBox",
	Position = UDim2.fromOffset(174, 163),
	Size = UDim2.fromOffset(48, 23),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.82,
	BorderSizePixel = 0,
	Text = tostring(DEFAULT_NIGHT_MINUTES),
	PlaceholderText = tostring(DEFAULT_NIGHT_MINUTES),
	ClearTextOnFocus = false,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextTransparency = 0.02,
	PlaceholderColor3 = Color3.fromRGB(210, 220, 230),
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 190,
}, contentGroup)

Corner(nightMinuteBox, UDim.new(0, 9))
Stroke(nightMinuteBox, 1, 0.72, Color3.fromRGB(255, 255, 255))

local nightMinuteUnit = New("TextLabel", {
	Name = "NightMinuteUnit",
	Position = UDim2.fromOffset(226, 166),
	Size = UDim2.fromOffset(18, 18),
	BackgroundTransparency = 1,
	Text = "分",
	TextColor3 = Color3.fromRGB(245, 250, 255),
	TextTransparency = 0.1,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 100,
}, contentGroup)

do
    local RAIN_AMOUNT_MIN = 0.20
    local RAIN_AMOUNT_MAX = 1.00
    local WEATHER_PANEL_SHIFT = 66
    local PANEL_RAIN_HEIGHT = 272
    local serial = 0
    local dragging = false

    local group = New("CanvasGroup", {
        Name = "RainAmountGroup",
        Position = UDim2.fromOffset(0, 145),
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        Visible = false,
        ZIndex = 145,
    }, contentGroup)

    New("TextLabel", {
        Name = "RainAmountLabel",
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.fromOffset(120, 18),
        BackgroundTransparency = 1,
        Text = "雨量",
        TextColor3 = Color3.fromRGB(245, 250, 255),
        TextTransparency = 0.06,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 150,
    }, group)

    local valueText = New("TextLabel", {
        Name = "RainAmountValue",
        Position = UDim2.fromOffset(196, 0),
        Size = UDim2.fromOffset(72, 18),
        BackgroundTransparency = 1,
        Text = "普通雨 20%",
        TextColor3 = Color3.fromRGB(225, 240, 255),
        TextTransparency = 0.02,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 150,
    }, group)

    local slider = New("TextButton", {
        Name = "RainAmountTrack",
        Position = UDim2.fromOffset(24, 31),
        Size = UDim2.new(1, -48, 0, 6),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.62,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 150,
    }, group)
    Corner(slider, UDim.new(1, 0))
    Stroke(slider, 1, 0.78, Color3.fromRGB(255, 255, 255))

    local fill = New("Frame", {
        Name = "RainAmountFill",
        Size = UDim2.fromScale(0.02, 1),
        BackgroundColor3 = Color3.fromRGB(190, 225, 255),
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        ZIndex = 151,
    }, slider)
    Corner(fill, UDim.new(1, 0))

    local thumb = New("TextButton", {
        Name = "RainAmountThumb",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(34, 20),
        BackgroundColor3 = Color3.fromRGB(235, 247, 255),
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 153,
    }, slider)
    Corner(thumb, UDim.new(1, 0))
    Stroke(thumb, 1.1, 0.38, Color3.fromRGB(255, 255, 255))

    local lowerControls = {
        cycleLabel, cycleStateText, cycleToggle, cycleClickArea,
        dayMinuteLabel, dayMinuteBox, dayMinuteUnit,
        nightMinuteLabel, nightMinuteBox, nightMinuteUnit,
    }
    local basePositions = {}
    for _, object in ipairs(lowerControls) do
        basePositions[object] = object.Position
    end

    local function getRainName(displayPercent)
        if displayPercent < 40 then
            return "普通雨"
        elseif displayPercent < 60 then
            return "密雨"
        elseif displayPercent < 80 then
            return "大雨"
        elseif displayPercent < 100 then
            return "暴雨"
        else
            return "極端暴雨"
        end
    end

    local function setPercent(percent)
        percent = math.clamp(percent, 0, 1)

        local amount = RAIN_AMOUNT_MIN + (RAIN_AMOUNT_MAX - RAIN_AMOUNT_MIN) * percent
        local curveVisual = percent ^ 1.35
        local curveImpact = percent ^ 1.20
        local curveWater = percent ^ 1.25

        WEATHER_CONTROL.Percent = amount

        WEATHER_CONTROL.VisualMultiplier = 0.70 + (2.80 - 0.70) * curveVisual

        WEATHER_CONTROL.ImpactMultiplier = 0.70 + (1.75 - 0.70) * curveImpact

        WEATHER_CONTROL.WaterMultiplier = 1.00 + 2.00 * curveWater

        fill.Size = UDim2.fromScale(math.max(percent, 0.02), 1)
        thumb.Position = UDim2.fromScale(percent, 0.5)

        local shown = math.floor(amount * 100 + 0.5)
        valueText.Text = string.format("%s %d%%", getRainName(shown), shown)
    end

    local function updateFromX(x)
        local width = math.max(slider.AbsoluteSize.X, 1)
        setPercent((x - slider.AbsolutePosition.X) / width)
    end

    local function beginDrag(input)
        dragging = true
        updateFromX(input.Position.X)
        TweenService:Create(thumb, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(40, 22),
            BackgroundTransparency = 0.08,
        }):Play()
    end

    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end)

    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            TweenService:Create(thumb, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.fromOffset(34, 20),
                BackgroundTransparency = 0.18,
            }):Play()
        end
    end)

    WEATHER_CONTROL.SetExpanded = function(show)
        serial += 1
        local thisSerial = serial
        local menuShift = WEATHER_CONTROL.MenuExpanded and 36 or 0
        local rainShift = show and WEATHER_PANEL_SHIFT or 0

        WEATHER_CONTROL.PanelHeight = PANEL_SIZE.Y + menuShift + rainShift

        if show then
            group.Visible = true
            group.GroupTransparency = 1
            group.Position = UDim2.fromOffset(0, 117 + menuShift)
        end

        TweenService:Create(main, TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(PANEL_SIZE.X, WEATHER_CONTROL.PanelHeight),
        }):Play()

        TweenService:Create(contentGroup, TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(PANEL_SIZE.X, WEATHER_CONTROL.PanelHeight),
        }):Play()

        for _, object in ipairs(lowerControls) do
            local base = basePositions[object]
            TweenService:Create(object, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(
                    base.X.Scale,
                    base.X.Offset,
                    base.Y.Scale,
                    base.Y.Offset + menuShift + rainShift
                ),
            }):Play()
        end

        TweenService:Create(group, TweenInfo.new(
            show and 0.34 or 0.20,
            Enum.EasingStyle.Sine,
            show and Enum.EasingDirection.Out or Enum.EasingDirection.In
        ), {
            GroupTransparency = show and 0 or 1,
            Position = UDim2.fromOffset(
                0,
                (show and 145 or 137) + menuShift
            ),
        }):Play()

        if not show then
            task.delay(0.22, function()
                if serial == thisSerial and WEATHER_MODE == "Sunny" then
                    group.Visible = false
                end
            end)
        end
    end

    WEATHER_CONTROL.MenuBasePositions = WEATHER_CONTROL.MenuBasePositions or {}
    WEATHER_CONTROL.MenuBasePositions[cycleLabel] = cycleLabel.Position
    WEATHER_CONTROL.MenuBasePositions[cycleStateText] = cycleStateText.Position
    WEATHER_CONTROL.MenuBasePositions[cycleToggle] = cycleToggle.Position
    WEATHER_CONTROL.MenuBasePositions[cycleClickArea] = cycleClickArea.Position
    WEATHER_CONTROL.MenuBasePositions[dayMinuteLabel] = dayMinuteLabel.Position
    WEATHER_CONTROL.MenuBasePositions[dayMinuteBox] = dayMinuteBox.Position
    WEATHER_CONTROL.MenuBasePositions[dayMinuteUnit] = dayMinuteUnit.Position
    WEATHER_CONTROL.MenuBasePositions[nightMinuteLabel] = nightMinuteLabel.Position
    WEATHER_CONTROL.MenuBasePositions[nightMinuteBox] = nightMinuteBox.Position
    WEATHER_CONTROL.MenuBasePositions[nightMinuteUnit] = nightMinuteUnit.Position

    local function appleEase(x)
        x = math.clamp(x, 0, 1)

        return x * x * x * (x * (x * 6 - 15) + 10)
    end

    local function setObjectY(object, base, yOffset)
        object.Position = UDim2.new(
            base.X.Scale,
            base.X.Offset,
            base.Y.Scale,
            base.Y.Offset + yOffset
        )
    end

    local function applyWeatherMenuMorph(rawProgress)
        local p = appleEase(rawProgress)
        local rainOpen = WEATHER_MODE ~= "Sunny"
        local menuShift = 38 * p
        local rainShift = rainOpen and (WEATHER_PANEL_SHIFT * p) or 0
        local totalShift = menuShift + rainShift

        local targetHeight = PANEL_SIZE.Y + totalShift
        main.Size = UDim2.fromOffset(PANEL_SIZE.X, targetHeight)
        contentGroup.Size = UDim2.fromOffset(PANEL_SIZE.X, targetHeight)
        WEATHER_CONTROL.PanelHeight = targetHeight

        local buttonInset = 2.5 * p
        WEATHER_CONTROL.MenuButton.Position = UDim2.fromOffset(
            18 + buttonInset,
            91
        )
        WEATHER_CONTROL.MenuButton.Size = UDim2.new(
            1,
            -36 - buttonInset * 2,
            0,
            29 + 2 * p
        )

        WEATHER_CONTROL.MenuArrow.Text = "⌄"
        WEATHER_CONTROL.MenuArrow.Rotation = 180 * p

        local optionY = 123 + 6 * p
        local optionAlpha = p
        local optionScale = 0.94 + 0.06 * p

        for _, data in ipairs({
            {btnSunnyWeather, 18},
            {btnSunRain, 105},
            {btnOvercastRain, 192},
        }) do
            local btn = data[1]
            local x = data[2]
            btn.Visible = rawProgress > 0.001
            btn.Position = UDim2.fromOffset(x, optionY)
            btn.TextTransparency = 1 - optionAlpha

            local uiValue = SETTINGS_CONTROL.PreviewTransparency
                or SETTINGS_CONTROL.SavedTransparency
                or 1

            local isActive = (
                (btn == btnSunnyWeather and WEATHER_MODE == "Sunny")
                or (btn == btnSunRain and WEATHER_MODE == "SunRain")
                or (btn == btnOvercastRain and WEATHER_MODE == "OvercastRain")
            )

            local baseTransparency = isActive
                and lerpNumber(0.06, 0.28, uiValue)
                or lerpNumber(0.10, 0.58, uiValue)

            btn.BackgroundTransparency = lerpNumber(
                1,
                baseTransparency,
                optionAlpha
            )

            local scale = btn:FindFirstChild("WeatherMorphScale")
            if not scale then
                scale = Instance.new("UIScale")
                scale.Name = "WeatherMorphScale"
                scale.Parent = btn
            end
            scale.Scale = optionScale
        end

        for object, base in pairs(WEATHER_CONTROL.MenuBasePositions) do
            if object and object.Parent then
                setObjectY(object, base, totalShift)
            end
        end

        if rainOpen then
            group.Visible = rawProgress > 0.001
            group.GroupTransparency = 1 - p
            group.Position = UDim2.fromOffset(0, 117 + menuShift + 8 * p)
        else
            group.GroupTransparency = 1
            if rawProgress <= 0.001 then
                group.Visible = false
            end
        end
    end

    WEATHER_CONTROL.ApplyWeatherMenuMorph = applyWeatherMenuMorph

    WEATHER_CONTROL.SetMenuExpanded = function(show)
        if SETTINGS_CONTROL.Page ~= "Main" or minimized then
            return
        end

        WEATHER_CONTROL.MenuExpanded = show
        WEATHER_CONTROL.MenuTarget = show and 1 or 0
        WEATHER_CONTROL.MenuAnimating = true

        if show then
            btnSunnyWeather.Visible = true
            btnSunRain.Visible = true
            btnOvercastRain.Visible = true

            if WEATHER_MODE ~= "Sunny" then
                group.Visible = true
            end
        end
    end

    local function chooseWeather(mode)
        setWeather(mode)
        refreshWeatherButtons()
        WEATHER_CONTROL.RefreshMenuButton(true)

        if WEATHER_CONTROL.ApplyWeatherMenuMorph then
            WEATHER_CONTROL.ApplyWeatherMenuMorph(WEATHER_CONTROL.MenuProgress)
        end
    end

    WEATHER_CONTROL.MenuButton.MouseButton1Click:Connect(function()
        WEATHER_CONTROL.SetMenuExpanded(not WEATHER_CONTROL.MenuExpanded)
    end)

    btnSunnyWeather.MouseButton1Click:Connect(function()
        chooseWeather("Sunny")
    end)

    btnSunRain.MouseButton1Click:Connect(function()
        chooseWeather("SunRain")
    end)

    btnOvercastRain.MouseButton1Click:Connect(function()
        chooseWeather("OvercastRain")
    end)

    applyWeatherMenuMorph(0)

    setPercent(0)
    WEATHER_CONTROL.PanelHeight = PANEL_SIZE.Y
    group.Visible = false
    group.GroupTransparency = 1
end

local function cleanMinuteText(text)
	text = tostring(text or "")
	text = text:gsub("[^%d%.]", "")

	local firstDot = text:find("%.")
	if firstDot then
		local before = text:sub(1, firstDot)
		local after = text:sub(firstDot + 1):gsub("%.", "")
		text = before .. after
	end

	return text
end

local function readMinuteBox(box, fallback)
	local raw = cleanMinuteText(box.Text)
	local value = tonumber(raw)

	if not value then
		value = fallback
	end

	value = math.clamp(value, MIN_CYCLE_MINUTES, MAX_CYCLE_MINUTES)

	if math.abs(value - math.floor(value)) < 0.001 then
		box.Text = tostring(math.floor(value))
	else
		box.Text = string.format("%.1f", value)
	end

	return value
end

local function refreshCycleMinuteInputs()
	dayCycleMinutes = readMinuteBox(dayMinuteBox, DEFAULT_DAY_MINUTES)
	nightCycleMinutes = readMinuteBox(nightMinuteBox, DEFAULT_NIGHT_MINUTES)
end

dayMinuteBox.FocusLost:Connect(function()
	refreshCycleMinuteInputs()
end)

nightMinuteBox.FocusLost:Connect(function()
	refreshCycleMinuteInputs()
end)

dayMinuteBox:GetPropertyChangedSignal("Text"):Connect(function()
	local cleaned = cleanMinuteText(dayMinuteBox.Text)

	if dayMinuteBox.Text ~= cleaned then
		dayMinuteBox.Text = cleaned
	end
end)

nightMinuteBox:GetPropertyChangedSignal("Text"):Connect(function()
	local cleaned = cleanMinuteText(nightMinuteBox.Text)

	if nightMinuteBox.Text ~= cleaned then
		nightMinuteBox.Text = cleaned
	end
end)

refreshCycleMinuteInputs()

local function pulseCycleState()
	TweenService:Create(cycleStateScale, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.18,
	}):Play()

	task.delay(0.08, function()
		TweenService:Create(cycleStateScale, TweenInfo.new(0.22, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)
end

local function setDayCycleEnabled(state)
	dayCycleEnabled = state
	pulseCycleState()

	if state then
		refreshCycleMinuteInputs()
		cycleStateText.Text = "ON"
		cycleStateText.TextColor3 = Color3.fromRGB(255, 232, 145)

		TweenService:Create(cycleToggle, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.42,
			BackgroundColor3 = Color3.fromRGB(255, 214, 105),
		}):Play()

		TweenService:Create(cycleToggleFill, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.18,
			BackgroundColor3 = Color3.fromRGB(255, 205, 75),
		}):Play()

		TweenService:Create(cycleToggleStroke, TweenInfo.new(0.18), {
			Transparency = 0.1,
			Thickness = 1.8,
			Color = Color3.fromRGB(255, 245, 190),
		}):Play()

		TweenService:Create(cycleKnobStroke, TweenInfo.new(0.18), {
			Transparency = 0.12,
			Color = Color3.fromRGB(255, 245, 190),
		}):Play()

		TweenService:Create(cycleToggleKnob, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(1, -20, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 0.02,
			BackgroundColor3 = Color3.fromRGB(255, 255, 245),
		}):Play()

		TweenService:Create(cycleToggleGlow, TweenInfo.new(0.18), {
			BackgroundTransparency = 0.48,
			BackgroundColor3 = Color3.fromRGB(255, 210, 95),
		}):Play()

		TweenService:Create(cycleLabel, TweenInfo.new(0.18), {
			TextTransparency = 0,
			TextColor3 = Color3.fromRGB(255, 244, 205),
		}):Play()

		TweenService:Create(cycleStateText, TweenInfo.new(0.18), {
			TextTransparency = 0,
		}):Play()

		cycleFlash.BackgroundColor3 = Color3.fromRGB(255, 220, 120)
		cycleFlash.BackgroundTransparency = 0.82
		TweenService:Create(cycleFlash, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
	else
		cycleStateText.Text = "OFF"
		cycleStateText.TextColor3 = Color3.fromRGB(235, 240, 245)

		TweenService:Create(cycleToggle, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.84,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		}):Play()

		TweenService:Create(cycleToggleFill, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.74,
			BackgroundColor3 = Color3.fromRGB(120, 120, 125),
		}):Play()

		TweenService:Create(cycleToggleStroke, TweenInfo.new(0.18), {
			Transparency = 0.64,
			Thickness = 1.2,
			Color = Color3.fromRGB(255, 255, 255),
		}):Play()

		TweenService:Create(cycleKnobStroke, TweenInfo.new(0.18), {
			Transparency = 0.42,
			Color = Color3.fromRGB(255, 255, 255),
		}):Play()

		TweenService:Create(cycleToggleKnob, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 0.08,
			BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		}):Play()

		TweenService:Create(cycleToggleGlow, TweenInfo.new(0.18), {
			BackgroundTransparency = 1,
			BackgroundColor3 = Color3.fromRGB(255, 210, 95),
		}):Play()

		TweenService:Create(cycleLabel, TweenInfo.new(0.18), {
			TextTransparency = 0.08,
			TextColor3 = Color3.fromRGB(245, 250, 255),
		}):Play()

		TweenService:Create(cycleStateText, TweenInfo.new(0.18), {
			TextTransparency = 0.18,
		}):Play()

		cycleFlash.BackgroundColor3 = Color3.fromRGB(210, 220, 235)
		cycleFlash.BackgroundTransparency = 0.88
		TweenService:Create(cycleFlash, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
	end
end

local function toggleDayCycleFromUi()
	setDayCycleEnabled(not dayCycleEnabled)
end

cycleToggle.MouseButton1Click:Connect(toggleDayCycleFromUi)
cycleClickArea.MouseButton1Click:Connect(toggleDayCycleFromUi)

cycleClickArea.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		TweenService:Create(cycleToggleKnob, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Size = dayCycleEnabled and UDim2.fromOffset(16, 16) or UDim2.fromOffset(18, 18),
		}):Play()
	end
end)

cycleClickArea.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		TweenService:Create(cycleToggleKnob, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = dayCycleEnabled and UDim2.fromOffset(18, 18) or UDim2.fromOffset(16, 16),
		}):Play()
	end
end)

setDayCycleEnabled(dayCycleEnabled)

local function initializeSettingsPage()
    local MAIN_HEIGHT = PANEL_SIZE.Y
    local SETTINGS_SIZE = Vector2.new(330, 252)
    local CONFIRM_SIZE = Vector2.new(246, 126)
    local pageSerial = 0
    local transparencyDragging = false
    local pendingTransparency = SETTINGS_CONTROL.SavedTransparency

    local settingsButton = New("TextButton", {
        Name = "SettingsButton",
        Position = UDim2.new(1, -68, 0, 9),
        Size = UDim2.fromOffset(25, 25),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        Text = "⚙",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 112,
    }, main)
    Corner(settingsButton, UDim.new(1, 0))
    local settingsButtonStroke = Stroke(settingsButton, 1, 0.55, Color3.fromRGB(255, 255, 255))

    local settingsGroup = New("CanvasGroup", {
        Name = "SettingsPage",
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(SETTINGS_SIZE.X, SETTINGS_SIZE.Y),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        Visible = false,
        ZIndex = 200,
    }, main)

    local settingsTitle = New("TextLabel", {
        Position = UDim2.fromOffset(22, 18),
        Size = UDim2.new(1, -44, 0, 28),
        BackgroundTransparency = 1,
        Text = "設定",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 205,
    }, settingsGroup)

    local transparencyLabel = New("TextLabel", {
        Position = UDim2.fromOffset(22, 62),
        Size = UDim2.fromOffset(170, 21),
        BackgroundTransparency = 1,
        Text = "UI 透明度",
        TextColor3 = Color3.fromRGB(245, 250, 255),
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 205,
    }, settingsGroup)

    local transparencyValue = New("TextLabel", {
        Position = UDim2.new(1, -92, 0, 62),
        Size = UDim2.fromOffset(70, 21),
        BackgroundTransparency = 1,
        Text = "100%",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 205,
    }, settingsGroup)

    local transparencyTrack = New("TextButton", {
        Position = UDim2.fromOffset(26, 94),
        Size = UDim2.new(1, -52, 0, 8),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.58,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 206,
    }, settingsGroup)
    Corner(transparencyTrack, UDim.new(1, 0))
    Stroke(transparencyTrack, 1, 0.72, Color3.fromRGB(255, 255, 255))

    local transparencyFill = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(210, 232, 255),
        BackgroundTransparency = 0.26,
        BorderSizePixel = 0,
        ZIndex = 207,
    }, transparencyTrack)
    Corner(transparencyFill, UDim.new(1, 0))

    local transparencyThumb = New("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(34, 20),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 210,
    }, transparencyTrack)
    Corner(transparencyThumb, UDim.new(1, 0))
    Stroke(transparencyThumb, 1.1, 0.38, Color3.fromRGB(255, 255, 255))

    local hint = New("TextLabel", {
        Position = UDim2.fromOffset(22, 116),
        Size = UDim2.new(1, -44, 0, 36),
        BackgroundTransparency = 1,
        Text = "100% 液態玻璃　→　0% 彩色／白色壓克力",
        TextColor3 = Color3.fromRGB(225, 232, 242),
        TextTransparency = 0.18,
        TextSize = 9,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 205,
    }, settingsGroup)

    local closeShaderButton = New("TextButton", {
        Position = UDim2.fromOffset(22, 163),
        Size = UDim2.new(1, -44, 0, 32),
        BackgroundColor3 = Color3.fromRGB(215, 68, 75),
        BackgroundTransparency = 0.50,
        BorderSizePixel = 0,
        Text = "關閉培根光影",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 208,
    }, settingsGroup)
    Corner(closeShaderButton, UDim.new(0, 11))
    local closeStroke = Stroke(closeShaderButton, 1.1, 0.42, Color3.fromRGB(255, 205, 208))

    local saveButton = New("TextButton", {
        Position = UDim2.fromOffset(22, 207),
        Size = UDim2.new(1, -44, 0, 32),
        BackgroundColor3 = Color3.fromRGB(105, 166, 225),
        BackgroundTransparency = 0.46,
        BorderSizePixel = 0,
        Text = "Save",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 208,
    }, settingsGroup)
    Corner(saveButton, UDim.new(0, 11))
    local saveStroke = Stroke(saveButton, 1.1, 0.42, Color3.fromRGB(215, 237, 255))

    local confirmGroup = New("CanvasGroup", {
        Name = "CloseConfirmPage",
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromOffset(CONFIRM_SIZE.X, CONFIRM_SIZE.Y),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        Visible = false,
        ZIndex = 250,
    }, main)

    local confirmTitle = New("TextLabel", {
        Position = UDim2.fromOffset(12, 22),
        Size = UDim2.new(1, -24, 0, 25),
        BackgroundTransparency = 1,
        Text = "是否關閉 UI",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 255,
    }, confirmGroup)

    local noButton = New("TextButton", {
        Position = UDim2.fromOffset(18, 70),
        Size = UDim2.fromOffset(98, 34),
        BackgroundColor3 = Color3.fromRGB(65, 190, 112),
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        Text = "否",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 256,
    }, confirmGroup)
    Corner(noButton, UDim.new(0, 12))
    local noStroke = Stroke(noButton, 1.1, 0.38, Color3.fromRGB(205, 255, 220))

    local yesButton = New("TextButton", {
        Position = UDim2.fromOffset(130, 70),
        Size = UDim2.fromOffset(98, 34),
        BackgroundColor3 = Color3.fromRGB(220, 64, 70),
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        Text = "是",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 256,
    }, confirmGroup)
    Corner(yesButton, UDim.new(0, 12))
    local yesStroke = Stroke(yesButton, 1.1, 0.38, Color3.fromRGB(255, 205, 208))

    local acrylicObjects = {
        { Object = main, Glass = 0.84, Acrylic = 0.16 },
        { Object = tint, Glass = 0.82, Acrylic = 0.32 },
        { Object = mini, Glass = 0.72, Acrylic = 0.12 },
        { Object = settingsButton, Glass = 0.72, Acrylic = 0.12 },
        { Object = track, Glass = 0.54, Acrylic = 0.12 },
        { Object = knob, Glass = 0.16, Acrylic = 0.08 },
        { Object = cycleToggle, Glass = 0.64, Acrylic = 0.12 },
        { Object = dayMinuteBox, Glass = 0.62, Acrylic = 0.12 },
        { Object = nightMinuteBox, Glass = 0.62, Acrylic = 0.12 },
        { Object = btnSunnyWeather, Glass = 0.82, Acrylic = 0.12 },
        { Object = btnSunRain, Glass = 0.82, Acrylic = 0.12 },
        { Object = btnOvercastRain, Glass = 0.82, Acrylic = 0.12 },
        { Object = WEATHER_CONTROL.MenuButton, Glass = 0.76, Acrylic = 0.10 },
        { Object = transparencyTrack, Glass = 0.58, Acrylic = 0.12 },
        { Object = transparencyFill, Glass = 0.26, Acrylic = 0.08 },
        { Object = transparencyThumb, Glass = 0.18, Acrylic = 0.08 },
        { Object = closeShaderButton, Glass = 0.50, Acrylic = 0.10 },
        { Object = saveButton, Glass = 0.46, Acrylic = 0.10 },
        { Object = noButton, Glass = 0.42, Acrylic = 0.08 },
        { Object = yesButton, Glass = 0.42, Acrylic = 0.08 },

    }

    local adaptiveTextObjects = {
        title,
        timeText,
        cycleLabel,
        cycleStateText,
        dayMinuteLabel,
        dayMinuteBox,
        dayMinuteUnit,
        nightMinuteLabel,
        nightMinuteBox,
        nightMinuteUnit,
        settingsTitle,
        transparencyLabel,
        transparencyValue,
        hint,
        confirmTitle,
    }

    local coloredTextObjects = {
        closeShaderButton,
        saveButton,
        noButton,
        yesButton,
        WEATHER_CONTROL.MenuLabel,
        WEATHER_CONTROL.MenuValue,
        WEATHER_CONTROL.MenuArrow,
    }

    local neutralButtonTextObjects = {
    }

    local function setTextAppearance(object, color, transparency, animated)
        if not object or not object.Parent then
            return
        end

        local properties = {
            TextColor3 = color,
            TextTransparency = transparency,
        }

        if animated then
            TweenService:Create(
                object,
                TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                properties
            ):Play()
        else
            object.TextColor3 = color
            object.TextTransparency = transparency
        end
    end

    local function applyAdaptiveText(value, animated)

        local neutralColor = lerpColor(
            Color3.fromRGB(28, 33, 42),
            Color3.fromRGB(255, 255, 255),
            value
        )

        local secondaryColor = lerpColor(
            Color3.fromRGB(52, 59, 70),
            Color3.fromRGB(235, 242, 250),
            value
        )

        for _, object in ipairs(adaptiveTextObjects) do
            local color = object == hint and secondaryColor or neutralColor
            setTextAppearance(object, color, object == hint and 0.08 or 0, animated)
        end

        for _, object in ipairs(neutralButtonTextObjects) do
            setTextAppearance(object, neutralColor, 0, animated)
        end

        for _, object in ipairs(coloredTextObjects) do
            setTextAppearance(object, Color3.fromRGB(255, 255, 255), 0, animated)
        end

        setTextAppearance(settingsButton, neutralColor, 0, animated)
        setTextAppearance(mini, neutralColor, 0, animated)
    end

    local function applyUiTransparency(value, animated)
        value = math.clamp(value, 0, 1)
        SETTINGS_CONTROL.PreviewTransparency = value
        transparencyValue.Text = tostring(math.floor(value * 100 + 0.5)) .. "%"
        transparencyFill.Size = UDim2.fromScale(value, 1)
        transparencyThumb.Position = UDim2.fromScale(value, 0.5)

        for _, entry in ipairs(acrylicObjects) do
            local object = entry.Object
            if object and object.Parent then
                local target = lerpNumber(entry.Acrylic, entry.Glass, value)
                if animated then
                    TweenService:Create(object, TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                        BackgroundTransparency = target,
                    }):Play()
                else
                    object.BackgroundTransparency = target
                end
            end
        end

        local edgeTransparency = lerpNumber(0.22, 0.55, value)
        for _, edge in ipairs({
            settingsButtonStroke, closeStroke, saveStroke,
            noStroke, yesStroke
        }) do
            if edge then
                edge.Transparency = edgeTransparency
            end
        end

        applyAdaptiveText(value, animated)

        if SETTINGS_CONTROL.RefreshWeatherButtons then
            SETTINGS_CONTROL.RefreshWeatherButtons()
        end

        if WEATHER_CONTROL.RefreshMenuButton then
            WEATHER_CONTROL.RefreshMenuButton(animated)
        end
    end

    local function setPanelSize(size, duration, style)
        TweenService:Create(main, TweenInfo.new(
            duration or 0.42,
            style or Enum.EasingStyle.Quart,
            Enum.EasingDirection.Out
        ), {
            Size = UDim2.fromOffset(size.X, size.Y),
        }):Play()
    end

    local function showSettingsPage()
        if SETTINGS_CONTROL.Page ~= "Main" then
            return
        end

        if WEATHER_CONTROL.SetMenuExpanded and WEATHER_CONTROL.MenuExpanded then
            WEATHER_CONTROL.MenuTarget = 0
            WEATHER_CONTROL.MenuProgress = 0
            WEATHER_CONTROL.MenuExpanded = false
            WEATHER_CONTROL.MenuAnimating = false
            if WEATHER_CONTROL.ApplyWeatherMenuMorph then
                WEATHER_CONTROL.ApplyWeatherMenuMorph(0)
            end
        end

        pageSerial += 1
        SETTINGS_CONTROL.Page = "Settings"
        pendingTransparency = SETTINGS_CONTROL.SavedTransparency

        settingsGroup.Visible = true
        settingsGroup.GroupTransparency = 1
        settingsGroup.Position = UDim2.fromOffset(0, 8)

        TweenService:Create(contentGroup, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
            GroupTransparency = 1,
            Position = UDim2.fromOffset(0, -7),
        }):Play()

        TweenService:Create(settingsButton, TweenInfo.new(0.18), {
            BackgroundTransparency = 1,
            TextTransparency = 1,
        }):Play()

        setPanelSize(SETTINGS_SIZE, 0.40)

        task.delay(0.16, function()
            if SETTINGS_CONTROL.Page ~= "Settings" then
                return
            end
            contentGroup.Visible = false
            TweenService:Create(settingsGroup, TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                GroupTransparency = 0,
                Position = UDim2.fromOffset(0, 0),
            }):Play()
        end)
    end

    local function returnToMainPage()
        pageSerial += 1
        SETTINGS_CONTROL.Page = "Main"

        TweenService:Create(settingsGroup, TweenInfo.new(0.19, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
            GroupTransparency = 1,
            Position = UDim2.fromOffset(0, -6),
        }):Play()

        local targetHeight = WEATHER_MODE == "Sunny" and MAIN_HEIGHT or WEATHER_CONTROL.PanelHeight
        setPanelSize(Vector2.new(PANEL_SIZE.X, targetHeight), 0.42)

        task.delay(0.15, function()
            if SETTINGS_CONTROL.Page ~= "Main" then
                return
            end

            settingsGroup.Visible = false
            contentGroup.Visible = true
            contentGroup.GroupTransparency = 1
            contentGroup.Position = UDim2.fromOffset(0, 7)

            TweenService:Create(contentGroup, TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                GroupTransparency = 0,
                Position = UDim2.fromOffset(0, 0),
            }):Play()

            TweenService:Create(settingsButton, TweenInfo.new(0.24), {
                BackgroundTransparency = lerpNumber(0.12, 0.72, SETTINGS_CONTROL.SavedTransparency),
                TextTransparency = 0,
            }):Play()
        end)
    end

    local function showCloseConfirm()
        if SETTINGS_CONTROL.Page ~= "Settings" then
            return
        end

        SETTINGS_CONTROL.Page = "Confirm"
        confirmGroup.Visible = true
        confirmGroup.GroupTransparency = 1
        confirmGroup.Position = UDim2.fromOffset(20, 6)

        TweenService:Create(settingsGroup, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
            GroupTransparency = 1,
            Position = UDim2.fromOffset(0, -7),
        }):Play()

        TweenService:Create(settingsButton, TweenInfo.new(0.16), {
            BackgroundTransparency = 1,
            TextTransparency = 1,
        }):Play()

        TweenService:Create(mini, TweenInfo.new(0.16), {
            BackgroundTransparency = 1,
            TextTransparency = 1,
        }):Play()

        setPanelSize(CONFIRM_SIZE, 0.42, Enum.EasingStyle.Back)

        task.delay(0.16, function()
            if SETTINGS_CONTROL.Page ~= "Confirm" then
                return
            end
            settingsGroup.Visible = false
            TweenService:Create(confirmGroup, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                GroupTransparency = 0,
                Position = UDim2.fromOffset(0, 0),
            }):Play()
        end)
    end

    local function returnToSettings()
        SETTINGS_CONTROL.Page = "Settings"

        TweenService:Create(confirmGroup, TweenInfo.new(0.17, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
            GroupTransparency = 1,
            Position = UDim2.fromOffset(0, -5),
        }):Play()

        setPanelSize(SETTINGS_SIZE, 0.40)

        task.delay(0.15, function()
            if SETTINGS_CONTROL.Page ~= "Settings" then
                return
            end
            confirmGroup.Visible = false
            settingsGroup.Visible = true
            settingsGroup.GroupTransparency = 1
            settingsGroup.Position = UDim2.fromOffset(0, 7)

            TweenService:Create(settingsGroup, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                GroupTransparency = 0,
                Position = UDim2.fromOffset(0, 0),
            }):Play()

            TweenService:Create(mini, TweenInfo.new(0.22), {
                BackgroundTransparency = lerpNumber(0.12, 0.72, pendingTransparency),
                TextTransparency = 0,
            }):Play()
        end)
    end

    local function shutdownBaconShader()
        if not RUNTIME.Alive then
            return
        end

        RUNTIME.Alive = false
        ENABLED = false
        dayCycleEnabled = false

        targetWeatherBlend = 0
        weatherBlend = 0
        targetWeatherKindBlend = 0
        weatherKindBlend = 0

        TweenService:Create(confirmGroup, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
            GroupTransparency = 1,
        }):Play()

        TweenService:Create(main, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(80, 38),
            BackgroundTransparency = 1,
        }):Play()

        TweenService:Create(uiScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Scale = 0.82,
        }):Play()

        task.delay(0.38, function()
            if RUNTIME.MainConnection then
                pcall(function()
                    RUNTIME.MainConnection:Disconnect()
                end)
            end

            pcall(function()
                weatherFolder:Destroy()
            end)

            pcall(clearOldWorldGlass)
            restoreOriginalLighting()

            pcall(function()
                gui:Destroy()
            end)

            print("🥓 培根光影已啟用")
        end)
    end

    local function updateTransparencyFromX(x)
        local width = math.max(transparencyTrack.AbsoluteSize.X, 1)
        pendingTransparency = math.clamp(
            (x - transparencyTrack.AbsolutePosition.X) / width,
            0,
            1
        )
        applyUiTransparency(pendingTransparency, false)
    end

    local function beginTransparencyDrag(input)
        transparencyDragging = true
        updateTransparencyFromX(input.Position.X)

        TweenService:Create(transparencyThumb, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(40, 19),
        }):Play()
    end

    transparencyTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginTransparencyDrag(input)
        end
    end)

    transparencyThumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginTransparencyDrag(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if transparencyDragging
            and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
            updateTransparencyFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if transparencyDragging
            and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
            transparencyDragging = false
            TweenService:Create(transparencyThumb, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.fromOffset(34, 20),
            }):Play()
        end
    end)

    settingsButton.MouseButton1Click:Connect(showSettingsPage)

    saveButton.MouseButton1Click:Connect(function()
        SETTINGS_CONTROL.SavedTransparency = pendingTransparency

        player:SetAttribute(
            SETTINGS_ATTRIBUTE,
            SETTINGS_CONTROL.SavedTransparency
        )

        applyUiTransparency(SETTINGS_CONTROL.SavedTransparency, true)
        returnToMainPage()
    end)

    closeShaderButton.MouseButton1Click:Connect(showCloseConfirm)
    noButton.MouseButton1Click:Connect(returnToSettings)
    yesButton.MouseButton1Click:Connect(shutdownBaconShader)

    SETTINGS_CONTROL.ApplyTransparency = applyUiTransparency
    SETTINGS_CONTROL.ShowSettings = showSettingsPage

    player:SetAttribute(
        SETTINGS_ATTRIBUTE,
        SETTINGS_CONTROL.SavedTransparency
    )

    applyUiTransparency(SETTINGS_CONTROL.SavedTransparency, false)
end

initializeSettingsPage()

local realLiquidGlassObjects = {}

local function findModuleInRoot(root)
	if not root then
		return nil
	end

	local direct = root:FindFirstChild(LIQUID_GLASS_MODULE_NAME, true)

	if direct and direct:IsA("ModuleScript") then
		return direct
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ModuleScript") then
			local lowerName = obj.Name:lower()

			if obj.Name == LIQUID_GLASS_MODULE_NAME
				or lowerName:find("liquidglasshandler")
				or lowerName:find("liquidglass") then

				return obj
			end
		end
	end

	return nil
end

local function tryClientLoadLiquidGlassAsset()
	if not TRY_CLIENT_LOAD_LIQUID_GLASS_ASSET then
		return nil
	end

	local oldLoaded = playerGui:FindFirstChild(PREFIX .. "LoadedLiquidGlassAsset")

	if oldLoaded then
		local module = findModuleInRoot(oldLoaded)

		if module then
			return module
		end

		oldLoaded:Destroy()
	end

	local ok, loadedModelOrErr = pcall(function()
		return AssetService:LoadAssetAsync(LIQUID_GLASS_ASSET_ID)
	end)

	if not ok then
		warn("[培根光影] 客戶端嘗試載入 LiquidGlassHandler 失敗：", loadedModelOrErr)
		return nil
	end

	local loadedModel = loadedModelOrErr
	loadedModel.Name = PREFIX .. "LoadedLiquidGlassAsset"

	loadedModel.Parent = playerGui

	local module = findModuleInRoot(loadedModel)

	if not module then
		warn("[培根光影] 資產已載入，但裡面找不到 ModuleScript：", loadedModel:GetFullName())
		return nil
	end

	print("[培根光影] 已從 Creator Store 本地載入 LiquidGlassHandler：", module:GetFullName())
	return module
end

local function findRealLiquidGlassModule()
	local searchRoots = {
		ReplicatedStorage,
		player:FindFirstChild("PlayerScripts"),
		playerGui,
		script.Parent,
		script,
	}

	if LIQUID_GLASS_SEARCH_WORKSPACE then
		table.insert(searchRoots, Workspace)
	end

	for _, root in ipairs(searchRoots) do
		local module = findModuleInRoot(root)

		if module then
			return module
		end
	end

	return tryClientLoadLiquidGlassAsset()
end

local function tagLiquidGlassObject(obj)
	if not obj or not obj:IsA("GuiObject") then
		return
	end

	if not CollectionService:HasTag(obj, LIQUID_GLASS_TAG) then
		CollectionService:AddTag(obj, LIQUID_GLASS_TAG)
	end

	table.insert(realLiquidGlassObjects, obj)
end

local function makeUiTransparentForRealGlass()

	main.BackgroundTransparency = 1
	tint.BackgroundTransparency = 0.965
	topShine.BackgroundTransparency = 0.82

	if liquidModuleLayer then
		liquidModuleLayer.Visible = false
	end

	if liquidBottomShade then
		liquidBottomShade.Visible = false
	end

	for _, btn in ipairs({ btnNight, btnMorning, btnNoon, btnSunset }) do
		btn.BackgroundTransparency = 0.93
	end

	mini.BackgroundTransparency = 0.88
	track.BackgroundTransparency = 0.72
	fill.BackgroundTransparency = 0.52
	knob.BackgroundTransparency = 0.54
	cycleToggle.BackgroundTransparency = 0.9
	dayMinuteBox.BackgroundTransparency = 0.9
	nightMinuteBox.BackgroundTransparency = 0.9
end

local function enableRealLiquidGlass()
	if not USE_REAL_LIQUID_GLASS_HANDLER then
		return false
	end

	local moduleScript = findRealLiquidGlassModule()

	if not moduleScript then
		warn("[培根光影] 找不到 LiquidGlassHandler，也無法客戶端載入。若要最穩，請在 Studio 把 LiquidGlassHandler 放到 ReplicatedStorage。")
		return false
	end

	print("[培根光影] 找到 LiquidGlassHandler：", moduleScript:GetFullName())

	local ok, result = pcall(function()
		return require(moduleScript)
	end)

	if not ok then
		warn("[培根光影] LiquidGlassHandler 載入失敗：", result)
		return false
	end

	realLiquidGlassActive = true

	if type(result) == "table" and result.new then
		print("[培根光影] LiquidGlassHandler API 確認成功")
	end

	makeUiTransparentForRealGlass()

	tagLiquidGlassObject(main)

	if LIQUID_GLASS_TAG_COMPONENTS then

		tagLiquidGlassObject(mini)
		tagLiquidGlassObject(track)
		tagLiquidGlassObject(knob)
		tagLiquidGlassObject(cycleToggle)
		tagLiquidGlassObject(dayMinuteBox)
		tagLiquidGlassObject(nightMinuteBox)

		tagLiquidGlassObject(btnNight)
		tagLiquidGlassObject(btnMorning)
		tagLiquidGlassObject(btnNoon)
		tagLiquidGlassObject(btnSunset)
	end

	print("🥓 培根光影已啟用")
	return true
end

enableRealLiquidGlass()

local glassRig = nil

local function updateWorldGlass()
	if USE_WORLD_GLASS_REFRACTION then

	end
end

local currentTime = 6.7
local targetTime = 6.7

local function formatTime(t)
	local hour = math.floor(t)
	local minute = math.floor((t - hour) * 60 + 0.5)

	if minute >= 60 then
		hour += 1
		minute = 0
	end

	hour %= 24

	return string.format("%02d:%02d", hour, minute)
end

local function updateGuiTime(value)
	local percent = math.clamp(value / 24, 0, 1)

	fill.Size = UDim2.fromScale(percent, 1)
	knob.Position = UDim2.fromScale(percent, 0.5)

	timeText.Text = "時間：" .. formatTime(value) .. "  /  ClockTime " .. string.format("%.2f", value)
end

local function setTargetTime(value)
	value = math.clamp(value, 0, 24)

	if value >= 24 then
		value = 0
	end

	targetTime = value

	if dayCycleEnabled then
		currentTime = value
	end

	updateGuiTime(value)
end

local function getClockDelta(fromTime, toTime)
	local from = fromTime % 24
	local to = toTime % 24
	local delta = (to - from + 12) % 24 - 12
	return delta
end

local sliderDragging = false

local function updateSliderFromX(x)
	local left = track.AbsolutePosition.X
	local width = track.AbsoluteSize.X
	local percent = math.clamp((x - left) / width, 0, 1)

	setTargetTime(percent * 24)
end

local scaleTween

local function tweenScale(scale, time, style, direction)
	if scaleTween then
		scaleTween:Cancel()
	end

	scaleTween = TweenService:Create(
		uiScale,
		TweenInfo.new(
			time or 0.18,
			style or Enum.EasingStyle.Back,
			direction or Enum.EasingDirection.Out
		),
		{ Scale = scale }
	)

	scaleTween:Play()
end

local function clickBounce()
	pulseLiquidGlass(0.85)
	tweenScale(1.012, 0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.delay(0.08, function()
		tweenScale(1, 0.22, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	end)
end

track.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		sliderDragging = true
		setKnobActive(true)
		clickBounce()
		updateSliderFromX(input.Position.X)
	end
end)

knob.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		sliderDragging = true
		setKnobActive(true)
		clickBounce()
	end
end)

local draggingPanel = false
local dragStart = nil
local startCenter = nil
local lastPointer = Vector2.zero

local function startDrag(input)
	pulseLiquidGlass(0.65)
	draggingPanel = true
	dragStart = input.Position
	startCenter = targetCenter
	lastPointer = Vector2.new(input.Position.X, input.Position.Y)
	currentVelocity = Vector2.zero

	tweenScale(1.02, 0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	TweenService:Create(stroke, TweenInfo.new(0.15), {
		Thickness = 1.9,
		Transparency = 0.1,
	}):Play()

	TweenService:Create(tint, TweenInfo.new(0.15), {
		BackgroundTransparency = 0.9,
	}):Play()
end

local function stopDrag()
	if not draggingPanel then
		return
	end

	draggingPanel = false
	currentVelocity = Vector2.zero

	tweenScale(1, 0.34, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

	TweenService:Create(stroke, TweenInfo.new(0.18), {
		Thickness = 1.6,
		Transparency = 0.2,
	}):Play()

	TweenService:Create(tint, TweenInfo.new(0.18), {
		BackgroundTransparency = 0.88,
	}):Play()

	TweenService:Create(wave1, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(wave1Base.X, wave1Base.Y),
	}):Play()

	TweenService:Create(wave2, TweenInfo.new(0.34, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(wave2Base.X, wave2Base.Y),
	}):Play()
end

dragBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		startDrag(input)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	if sliderDragging then
		updateSliderFromX(input.Position.X)
		return
	end

	if draggingPanel and dragStart and startCenter then
		local delta = input.Position - dragStart

		targetCenter = Vector2.new(
			startCenter.X + delta.X,
			startCenter.Y + delta.Y
		)

		main.Position = UDim2.fromOffset(targetCenter.X, targetCenter.Y)

		local now = Vector2.new(input.Position.X, input.Position.Y)
		currentVelocity = now - lastPointer
		lastPointer = now

		local ox = math.clamp(currentVelocity.X * 0.38, -14, 14)
		local oy = math.clamp(currentVelocity.Y * 0.32, -9, 9)

		wave1.Position = UDim2.fromOffset(wave1Base.X + ox, wave1Base.Y + oy)
		wave2.Position = UDim2.fromOffset(wave2Base.X - ox * 0.45, wave2Base.Y - oy * 0.25)

		updateWorldGlass()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		sliderDragging = false
		setKnobActive(false)
		stopDrag()
	end
end)

local minimized = false
local collapseSerial = 0
local mainSizeTween
local contentTween
local tintTween

local function tweenPanelSize(targetSize, info)
	if mainSizeTween then
		mainSizeTween:Cancel()
	end

	mainSizeTween = TweenService:Create(main, info, {
		Size = targetSize,
	})

	mainSizeTween:Play()
end

local function setContentVisibleSmooth(visible)
	collapseSerial += 1
	local serial = collapseSerial

	if contentTween then
		contentTween:Cancel()
	end

	if visible then
		contentGroup.Visible = true
		contentGroup.GroupTransparency = 1
		contentGroup.Position = UDim2.fromOffset(0, 8)

		contentTween = TweenService:Create(
			contentGroup,
			TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				GroupTransparency = 0,
				Position = UDim2.fromOffset(0, 0),
			}
		)

		contentTween:Play()
	else
		contentTween = TweenService:Create(
			contentGroup,
			TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{
				GroupTransparency = 1,
				Position = UDim2.fromOffset(0, -5),
			}
		)

		contentTween:Play()

		task.delay(0.19, function()
			if collapseSerial == serial and minimized then
				contentGroup.Visible = false
			end
		end)
	end
end

local function setMinimized(state)
	if WEATHER_CONTROL.SetMenuExpanded and WEATHER_CONTROL.MenuExpanded then
		WEATHER_CONTROL.MenuTarget = 0
		WEATHER_CONTROL.MenuProgress = 0
		WEATHER_CONTROL.MenuExpanded = false
		WEATHER_CONTROL.MenuAnimating = false
		if WEATHER_CONTROL.ApplyWeatherMenuMorph then
			WEATHER_CONTROL.ApplyWeatherMenuMorph(0)
		end
	end

	if SETTINGS_CONTROL.Page ~= "Main" then
		return
	end

	if minimized == state then
		return
	end

	minimized = state
	clickBounce()

	if minimized then
		mini.Text = "+"

		setContentVisibleSmooth(false)

		tweenPanelSize(
			UDim2.fromOffset(PANEL_SIZE.X, PANEL_MIN_HEIGHT),
			TweenInfo.new(0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		)

		if tintTween then
			tintTween:Cancel()
		end

		tintTween = TweenService:Create(tint, TweenInfo.new(0.25), {
			BackgroundTransparency = 0.9,
		})
		tintTween:Play()
	else
		mini.Text = "－"

		contentGroup.Visible = true

		tweenPanelSize(
			UDim2.fromOffset(PANEL_SIZE.X, WEATHER_CONTROL.PanelHeight),
			TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		)

		task.delay(0.06, function()
			if not minimized then
				setContentVisibleSmooth(true)
			end
		end)

		if tintTween then
			tintTween:Cancel()
		end

		tintTween = TweenService:Create(tint, TweenInfo.new(0.28), {
			BackgroundTransparency = 0.88,
		})
		tintTween:Play()
	end

	task.defer(updateWorldGlass)
end

mini.MouseEnter:Connect(function()
	TweenService:Create(miniScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.08,
	}):Play()

	TweenService:Create(mini, TweenInfo.new(0.14), {
		BackgroundTransparency = 0.62,
	}):Play()
end)

mini.MouseLeave:Connect(function()
	TweenService:Create(miniScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	TweenService:Create(mini, TweenInfo.new(0.14), {
		BackgroundTransparency = 0.72,
	}):Play()
end)

mini.MouseButton1Click:Connect(function()
	if SETTINGS_CONTROL.Page ~= "Main" then
		return
	end

	setMinimized(not minimized)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.RightShift then
		ENABLED = not ENABLED

		if ENABLED then
			applyBaconShader()
		else
			disableBaconShader()
		end
	end
end)

RUNTIME.LiquidGlassTimer = 0

function RUNTIME.UpdateLiquidGlass(dt)
	if realLiquidGlassActive then
		return
	end

	RUNTIME.LiquidGlassTimer += dt

	local activeMotion = draggingPanel or sliderDragging or knobActive or dayCycleEnabled
	local targetRate = activeMotion and LIQUID_GLASS_UPDATE_RATE or 1 / 12

	if RUNTIME.LiquidGlassTimer < targetRate then
		return
	end

	RUNTIME.LiquidGlassTimer = 0

	local now = os.clock()
	local motion = activeMotion and 1 or 0.35

	for _, item in ipairs(LiquidGlass.Items) do
		local obj = item.Object
		local seed = item.Seed

		if obj then
			local ox = math.sin(now * (0.55 + seed * 0.06) + seed) * 10 * motion
			local oy = math.cos(now * (0.46 + seed * 0.05) + seed * 1.4) * 5 * motion

			obj.Position = item.BasePosition + UDim2.fromOffset(ox, oy)
			obj.Rotation = math.sin(now * 0.32 + seed) * 4 * motion

			if item.Gradient then
				item.Gradient.Rotation = (item.Gradient.Rotation + 4 * motion) % 360
			end
		end
	end

	local dragLean = math.clamp(currentVelocity.X * 0.015, -7, 7)
	local dragLift = math.clamp(currentVelocity.Y * 0.006, -2, 2)

	liquidSpecular.Position = UDim2.fromScale(
		0.52 + math.sin(now * 0.42) * 0.025,
		0.43 + math.cos(now * 0.38) * 0.018
	)

	liquidSpecular.Rotation = -16 + dragLean
	liquidSpecularGradient.Offset = Vector2.new(math.sin(now * 0.78) * 0.32, 0)
	innerEdgeGradient.Rotation = (innerEdgeGradient.Rotation + 1.8 * motion) % 360
	liquidBottomShade.Position = UDim2.new(0.5, 0, 1, 8 + dragLift)
end

RUNTIME.FrameState = {
    CleanupTimer = 0,
    LastAppliedTime = -999,
}

RUNTIME.MainConnection = RunService.RenderStepped:Connect(function(dt)
	if not RUNTIME.Alive then
		return
	end

	if WEATHER_CONTROL.MenuAnimating and WEATHER_CONTROL.ApplyWeatherMenuMorph then
		local target = WEATHER_CONTROL.MenuTarget or 0
		local current = WEATHER_CONTROL.MenuProgress or 0

		local response = 1 - math.exp(-dt * 10.5)
		current = current + (target - current) * response

		if math.abs(target - current) < 0.0015 then
			current = target
			WEATHER_CONTROL.MenuAnimating = false
		end

		WEATHER_CONTROL.MenuProgress = current
		WEATHER_CONTROL.ApplyWeatherMenuMorph(current)

		if current <= 0.001 and target == 0 then
			btnSunnyWeather.Visible = false
			btnSunRain.Visible = false
			btnOvercastRain.Visible = false
			if WEATHER_MODE == "Sunny" then

				local rainGroup = contentGroup:FindFirstChild("RainAmountGroup")
				if rainGroup then
					rainGroup.Visible = false
				end
			end
		end
	end

	RUNTIME.FrameState.CleanupTimer += dt
	if RUNTIME.FrameState.CleanupTimer >= 8 then
		RUNTIME.FrameState.CleanupTimer = 0

		clearOldWorldGlass(glassRig)

		for _, child in ipairs(playerGui:GetChildren()) do
			if (child.Name == PREFIX .. "LiquidTimeGui" or child.Name == "BaconShader_LiquidTimeGui") and child ~= gui then
				pcall(function()
					child:Destroy()
				end)
			end
		end
	end
	strokeGradient.Rotation = (strokeGradient.Rotation + dt * 5) % 360
	tintGradient.Rotation = (tintGradient.Rotation + dt * 3) % 360
	topShineGradient.Offset = Vector2.new(math.sin(os.clock() * 1.35) * 0.35, 0)
	RUNTIME.UpdateLiquidGlass(dt)

	fillGradient.Rotation = (fillGradient.Rotation + dt * 8) % 360
	knobFilterGradient.Rotation = (knobFilterGradient.Rotation + dt * 16) % 360
	knobTopGradient.Offset = Vector2.new(math.sin(os.clock() * 2.2) * 0.3, 0)
	cycleToggleFillGradient.Rotation = (cycleToggleFillGradient.Rotation + dt * (dayCycleEnabled and 36 or 8)) % 360

	if dayCycleEnabled then
		local glowPulse = 0.5 + math.sin(os.clock() * 5.5) * 0.5
		cycleToggleGlow.BackgroundTransparency = 0.42 + glowPulse * 0.18
	end

	if knobActive then
		local pulse = 0.5 + math.sin(os.clock() * 9) * 0.5
		knobSpecStroke.Transparency = 0.12 + pulse * 0.16
		innerGlowStroke.Transparency = 0.46 + pulse * 0.18
	end

	if not draggingPanel then
		currentVelocity = currentVelocity:Lerp(Vector2.zero, 0.2)
	end

	if ENABLED then
		if dayCycleEnabled then
			currentTime = (currentTime + getDayNightCycleSpeed(currentTime) * dt) % 24
			targetTime = currentTime
			updateGuiTime(currentTime)
		else
			local delta = getClockDelta(currentTime, targetTime)
			currentTime = (currentTime + delta * math.clamp(dt * 8, 0, 1)) % 24
		end

		if math.abs(getClockDelta(RUNTIME.FrameState.LastAppliedTime, currentTime)) > 0.003 then
			RUNTIME.FrameState.LastAppliedTime = currentTime
			Lighting.ClockTime = currentTime
			applyFrame(currentTime)
		end
	end

	updateWeather(dt)
	updateWorldGlass()
end)

applyBaconShader()

currentTime = 6.7
targetTime = 6.7

Lighting.ClockTime = currentTime
applyFrame(currentTime)
applyWeatherOverlay(currentTime)
updateGuiTime(targetTime)
updateWorldGlass()

if realLiquidGlassActive then
	print("🥓 培根光影已啟用")
else
	warn("🥓 培根光影已啟用，但 LiquidGlassHandler 尚未接入；UI 會使用內建仿玻璃。")
end
