
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PREFIX = "BaconShader_"
local ENABLED = true



local PANEL_SIZE = Vector2.new(286, 178)
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
	[PREFIX .. "WorldGlassRig_v21"] = true,
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

	{
		time = 5.5,
		Brightness = 1.7,
		Exposure = 0.04,
		ShadowSoftness = 0.18,

		ColorTop = Color3.fromRGB(230, 205, 160),
		ColorBottom = Color3.fromRGB(80, 62, 50),
		Ambient = Color3.fromRGB(72, 62, 52),
		OutdoorAmbient = Color3.fromRGB(92, 78, 62),

		FogColor = Color3.fromRGB(120, 105, 82),
		FogStart = 150,
		FogEnd = 1400,

		AtmosphereColor = Color3.fromRGB(235, 205, 150),
		AtmosphereDecay = Color3.fromRGB(115, 88, 55),
		AtmosphereDensity = 0.26,
		AtmosphereOffset = 0.08,
		AtmosphereGlare = 0.12,
		AtmosphereHaze = 1,

		BloomIntensity = 0.045,
		BloomThreshold = 0.87,
		BloomSize = 34,

		SunRaysIntensity = 0.018,
		SunRaysSpread = 0.75,

		BlurSize = 0.3,

		ColorBrightness = 0.01,
		ColorContrast = 0.09,
		ColorSaturation = 0.02,
		TintColor = Color3.fromRGB(255, 238, 210),

		DofFar = 0.07,
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
	clearOldEffects()

	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = 0
	Lighting.ShadowSoftness = 0.2

	Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)

	Lighting.Ambient = Color3.fromRGB(70, 70, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)

	Lighting.FogColor = Color3.fromRGB(192, 192, 192)
	Lighting.FogStart = 0
	Lighting.FogEnd = 100000
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
	BackgroundTransparency = 0.88,
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
	BackgroundTransparency = 0.88,
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
	Text = "🥓培根光影🥓",
	TextColor3 = Color3.fromRGB(255, 255, 255),
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
		ZIndex = 100,
	}, contentGroup)

	Corner(btn, UDim.new(0, 10))
	Stroke(btn, 1, 0.72, Color3.fromRGB(255, 255, 255))

	return btn
end

local btnNight = makeButton("夜晚", 18)
local btnMorning = makeButton("清晨", 82)
local btnNoon = makeButton("中午", 146)
local btnSunset = makeButton("日落", 210)

local cycleLabel = New("TextLabel", {
	Name = "CycleLabel",
	Position = UDim2.fromOffset(18, 118),
	Size = UDim2.fromOffset(142, 18),
	BackgroundTransparency = 1,
	Text = "日夜循環",
	TextColor3 = Color3.fromRGB(245, 250, 255),
	TextTransparency = 0.08,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 100,
}, contentGroup)

local cycleStateText = New("TextLabel", {
	Name = "CycleStateText",
	Position = UDim2.fromOffset(158, 118),
	Size = UDim2.fromOffset(54, 18),
	BackgroundTransparency = 1,
	Text = "OFF",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextTransparency = 0.18,
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 102,
}, contentGroup)

local cycleToggle = New("TextButton", {
	Name = "CycleToggle",
	Position = UDim2.fromOffset(222, 115),
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
	Position = UDim2.fromOffset(12, 112),
	Size = UDim2.fromOffset(PANEL_SIZE.X - 24, 28),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 180,
}, contentGroup)

local dayCycleEnabled = DAY_CYCLE_ENABLED_DEFAULT


local dayMinuteLabel = New("TextLabel", {
	Name = "DayMinuteLabel",
	Position = UDim2.fromOffset(18, 146),
	Size = UDim2.fromOffset(36, 18),
	BackgroundTransparency = 1,
	Text = "白天",
	TextColor3 = Color3.fromRGB(245, 250, 255),
	TextTransparency = 0.08,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 100,
}, contentGroup)

local dayMinuteBox = New("TextBox", {
	Name = "DayMinuteBox",
	Position = UDim2.fromOffset(54, 143),
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
	Position = UDim2.fromOffset(106, 146),
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
	Position = UDim2.fromOffset(134, 146),
	Size = UDim2.fromOffset(36, 18),
	BackgroundTransparency = 1,
	Text = "夜晚",
	TextColor3 = Color3.fromRGB(245, 250, 255),
	TextTransparency = 0.08,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 100,
}, contentGroup)

local nightMinuteBox = New("TextBox", {
	Name = "NightMinuteBox",
	Position = UDim2.fromOffset(174, 143),
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
	Position = UDim2.fromOffset(226, 146),
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

local camera = workspace.CurrentCamera

local glassRig = Instance.new("Folder")
glassRig.Name = PREFIX .. "WorldGlassRig_v21"
glassRig.Parent = camera or workspace

local panelGlassParts = {}
local cornerStrips = {
	TL = {},
	TR = {},
	BL = {},
	BR = {},
}

local function createGlassPart(name)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Material = Enum.Material.Glass
	part.Color = Color3.fromRGB(255, 255, 255)
	part.Transparency = GLASS_TRANSPARENCY
	part.Reflectance = 0.08
	part.Shape = Enum.PartType.Block
	part.Parent = glassRig

	table.insert(panelGlassParts, part)
	return part
end

local glassMiddle = createGlassPart("GlassMiddle")
local glassLeft = createGlassPart("GlassLeft")
local glassRight = createGlassPart("GlassRight")

for i = 1, CORNER_SEGMENTS do
	table.insert(cornerStrips.TL, createGlassPart("CornerTL_" .. i))
	table.insert(cornerStrips.TR, createGlassPart("CornerTR_" .. i))
	table.insert(cornerStrips.BL, createGlassPart("CornerBL_" .. i))
	table.insert(cornerStrips.BR, createGlassPart("CornerBR_" .. i))
end

local function getCurrentCamera()
	local cam = workspace.CurrentCamera

	if cam ~= camera then
		camera = cam

		if camera and glassRig then
			glassRig.Parent = camera
		end
	end

	return camera
end

local function getPixelWorldScale(cam)
	local viewport = cam.ViewportSize

	if viewport.Y <= 1 then
		return 0.01
	end

	local heightAtDistance = 2 * GLASS_DISTANCE * math.tan(math.rad(cam.FieldOfView) / 2)
	return heightAtDistance / viewport.Y
end

local function updateWorldGlass()
	local cam = getCurrentCamera()
	if not cam then
		return
	end

	local viewport = cam.ViewportSize
	if viewport.X <= 1 or viewport.Y <= 1 then
		return
	end

	local uiSize = main.AbsoluteSize
	if uiSize.X <= 1 or uiSize.Y <= 1 then
		return
	end

	local pixelScale = getPixelWorldScale(cam)

	local absPos = main.AbsolutePosition
	local absSize = main.AbsoluteSize
	local center = absPos + absSize * 0.5

	if AUTO_GUI_INSET_FIX then
		local ok, inset = pcall(function()
			return GuiService:GetGuiInset()
		end)

		if ok and typeof(inset) == "Vector2" then
			center += inset
		end
	end

	center += Vector2.new(GLASS_OFFSET_X, GLASS_OFFSET_Y)

	local localX = (center.X - viewport.X * 0.5) * pixelScale
	local localY = -(center.Y - viewport.Y * 0.5) * pixelScale

	local bounceScale = uiScale.Scale

	local glassW = math.max(uiSize.X - GLASS_INSET * 2, 10) * pixelScale * GLASS_SCALE_X * bounceScale
	local glassH = math.max(uiSize.Y - GLASS_INSET * 2, 10) * pixelScale * GLASS_SCALE_Y * bounceScale

	local thickness = 0.055 + GLASS_POWER * 0.055

	local baseCF =
		cam.CFrame
		* CFrame.new(localX, localY, -GLASS_DISTANCE)

	local radius = math.clamp(
		PANEL_RADIUS * pixelScale * bounceScale,
		0.02,
		math.min(glassW, glassH) * 0.48
	)

	local overlap = 0.006
	local stripW = radius / CORNER_SEGMENTS + overlap

	local function placeBlock(part, sx, sy, sz, ox, oy)
		part.Size = Vector3.new(
			math.max(sx, 0.01),
			math.max(sy, 0.01),
			math.max(sz, 0.01)
		)

		part.CFrame = baseCF * CFrame.new(ox, oy, 0)
		part.Transparency = GLASS_TRANSPARENCY
	end

	placeBlock(
		glassMiddle,
		math.max(glassW - radius * 2 + overlap * 2, 0.01),
		glassH,
		thickness,
		0,
		0
	)

	placeBlock(
		glassLeft,
		radius + overlap,
		math.max(glassH - radius * 2 + overlap * 2, 0.01),
		thickness,
		-glassW * 0.5 + radius * 0.5,
		0
	)

	placeBlock(
		glassRight,
		radius + overlap,
		math.max(glassH - radius * 2 + overlap * 2, 0.01),
		thickness,
		glassW * 0.5 - radius * 0.5,
		0
	)

	local leftEdge = -glassW * 0.5
	local rightEdge = glassW * 0.5
	local topEdge = glassH * 0.5
	local bottomEdge = -glassH * 0.5

	for i = 1, CORNER_SEGMENTS do
		local t0 = (i - 1) / CORNER_SEGMENTS
		local t1 = i / CORNER_SEGMENTS
		local t = (t0 + t1) * 0.5

		local xMid = t * radius
		local dx = radius - xMid
		local boundaryDown = radius - math.sqrt(math.max(radius * radius - dx * dx, 0))

		local stripH = math.max(radius - boundaryDown + overlap * 2, 0.01)

		local topStripCenterY = topEdge - boundaryDown - stripH * 0.5 + overlap
		local bottomStripCenterY = bottomEdge + boundaryDown + stripH * 0.5 - overlap

		placeBlock(cornerStrips.TL[i], stripW, stripH, thickness, leftEdge + xMid, topStripCenterY)
		placeBlock(cornerStrips.TR[i], stripW, stripH, thickness, rightEdge - xMid, topStripCenterY)
		placeBlock(cornerStrips.BL[i], stripW, stripH, thickness, leftEdge + xMid, bottomStripCenterY)
		placeBlock(cornerStrips.BR[i], stripW, stripH, thickness, rightEdge - xMid, bottomStripCenterY)
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

btnNight.MouseButton1Click:Connect(function()
	clickBounce()
	setTargetTime(23.3)
end)

btnMorning.MouseButton1Click:Connect(function()
	clickBounce()
	setTargetTime(6.7)
end)

btnNoon.MouseButton1Click:Connect(function()
	clickBounce()
	setTargetTime(12)
end)

btnSunset.MouseButton1Click:Connect(function()
	clickBounce()
	setTargetTime(17.7)
end)

local draggingPanel = false
local dragStart = nil
local startCenter = nil
local lastPointer = Vector2.zero

local function startDrag(input)
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
			UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
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

local cleanupTimer = 0
local lastAppliedTime = -999

RunService.RenderStepped:Connect(function(dt)
	cleanupTimer += dt
	if cleanupTimer >= 8 then
		cleanupTimer = 0

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

		if math.abs(getClockDelta(lastAppliedTime, currentTime)) > 0.003 then
			lastAppliedTime = currentTime
			Lighting.ClockTime = currentTime
			applyFrame(currentTime)
		end
	end

	updateWorldGlass()
end)

applyBaconShader()

currentTime = 6.7
targetTime = 6.7

Lighting.ClockTime = currentTime
applyFrame(currentTime)
updateGuiTime(targetTime)
updateWorldGlass()
