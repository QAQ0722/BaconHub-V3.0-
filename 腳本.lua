local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function getRandomName()
    return HttpService:GenerateGUID(false):sub(1, 8)
end

local hiddenParent = nil
if gethui then
    hiddenParent = gethui()
elseif CoreGui:FindFirstChild("RobloxGui") then
    hiddenParent = CoreGui.RobloxGui
else
    hiddenParent = player:WaitForChild("PlayerGui")
end

local GITHUB_LOGO_URL = "https://files.catbox.moe/qm0uev.png"
local AUDIO_URL = "https://files.catbox.moe/a94j77.mp3"

local LOGO_LOCAL_FILE = "BaconLogo_QAQ.png"
local AUDIO_LOCAL_FILE = "BaconIntro_New_QAQ.mp3"

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = getRandomName()
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
pcall(function() ScreenGui.Parent = hiddenParent end)

local Background = Instance.new("Frame")
Background.Name = getRandomName()
Background.Size = UDim2.new(1, 0, 1, 0)
Background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Background.BackgroundTransparency = 0
Background.BorderSizePixel = 0
Background.Parent = ScreenGui

local LogoImage = Instance.new("ImageLabel")
LogoImage.Name = getRandomName()
LogoImage.Size = UDim2.new(0.45, 0, 0.45, 0)
LogoImage.Position = UDim2.new(0.5, 0, 0.5, 0)
LogoImage.AnchorPoint = Vector2.new(0.5, 0.5)
LogoImage.BackgroundTransparency = 1
LogoImage.ImageTransparency = 1
LogoImage.BorderSizePixel = 0
LogoImage.ScaleType = Enum.ScaleType.Fit
LogoImage.Parent = Background

local AspectConstraint = Instance.new("UIAspectRatioConstraint")
AspectConstraint.AspectRatio = 1
AspectConstraint.DominantAxis = Enum.DominantAxis.Width
AspectConstraint.Parent = LogoImage

local imageReady = false
task.spawn(function()
    pcall(function()
        if not isfile(LOGO_LOCAL_FILE) then
            local logoData = game:HttpGetAsync(GITHUB_LOGO_URL)
            if logoData then writefile(LOGO_LOCAL_FILE, logoData) end
        end
        LogoImage.Image = getcustomasset(LOGO_LOCAL_FILE)
        imageReady = true
    end)
end)

local IntroSound = Instance.new("Sound")
IntroSound.Name = getRandomName()
IntroSound.Volume = 0.8
IntroSound.Parent = game.Workspace

local musicStarted = false

task.spawn(function()
    pcall(function()
        if not isfile(AUDIO_LOCAL_FILE) then
            local audioData = game:HttpGetAsync(AUDIO_URL)
            if audioData then writefile(AUDIO_LOCAL_FILE, audioData) end
        end
        if isfile(AUDIO_LOCAL_FILE) then
            IntroSound.SoundId = getcustomasset(AUDIO_LOCAL_FILE)
            if not IntroSound.IsLoaded then IntroSound.Loaded:Wait() end
            IntroSound:Play()
            musicStarted = true
        end
    end)
    task.delay(1.5, function() musicStarted = true end)
end)

local function fadeGui(object, property, startValue, endValue, duration)
    local steps = 80
    local increment = (endValue - startValue) / steps
    local waitTime = duration / steps
    object[property] = startValue
    for i = 1, steps do
        object[property] = object[property] + increment
        task.wait(waitTime)
    end
    object[property] = endValue
end

local CurrentSettings = {
    WalkSpeed = 16,
    JumpPower = 50
}

local AimbotEnabled = false
local AimPart = "Head"
local AimbotKey = Enum.UserInputType.MouseButton2
local AimbotSmoothness = 5
local WallCheckEnabled = false
local TeamCheckEnabled = false

local FovRadius = 100
local FovColor = Color3.fromRGB(255, 255, 255)
local FovSides = 64
local FovCircleEnabled = false

local FOVCircle
local drawingSuccess = pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible = false
    FOVCircle.Thickness = 1.5
    FOVCircle.Radius = FovRadius
    FOVCircle.Color = FovColor
    FOVCircle.NumSides = FovSides
    FOVCircle.Filled = false
end)
if not drawingSuccess then FOVCircle = nil end

local EspEnabled = false
local TracerEnabled = false
local RgbEnabled = false
local EspColor = Color3.fromRGB(255, 0, 0)

local espTag = getRandomName()
local beamTag = getRandomName()
local attachTag = getRandomName()

local Rayfield = nil
local Window = nil

local function initMainScript()
    getgenv().SecureMode = true 
    
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    Window = Rayfield:CreateWindow({
        Name = " 🥓培根腳本中心 V3",
        LoadingTitle = " 🥓培根 V3 正式版載入中...",
        LoadingSubtitle = "by QAQ0722",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "BaconScripts",
            FileName = "BaconHubV3"
        },
        KeySystem = false,
    })

    task.spawn(function()
        pcall(function()
            if IntroSound and IntroSound.IsPlaying then
                for v = IntroSound.Volume, 0, -0.05 do
                    IntroSound.Volume = v
                    task.wait(0.04)
                end
                IntroSound:Stop()
                IntroSound:Destroy()
            end
        end)
    end)

    local TabHome = Window:CreateTab("🥓培根中心🥓", 4483362458)
    local TabInfo = Window:CreateTab("使用者詳細個資", "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150")
    local TabPlayer = Window:CreateTab("客戶端", 4483362458)
    local TabVisuals = Window:CreateTab("視覺", 4483362458)
    local TabAimbot = Window:CreateTab("自動瞄準", 4483362458)
   
    TabHome:CreateSection("歡迎使用培根中心")
    TabHome:CreateParagraph({Title = "🔥 培根腳本中心 V3 正式啟用", Content = "全新 V3 介面已優化完成！移成了容易崩潰的舊程式碼，改用最穩定、最直觀的精準輸入框控制，讓你玩得更流暢。"})
    TabHome:CreateSection("—— Discord群 ——")
    TabHome:CreateButton({
        Name = "複製Discord群連結",
        Callback = function()
            if setclipboard then
                setclipboard("https://discord.gg/u3d6Eszk3s")
                Rayfield:Notify({Title = " 🥓 培根腳本中心 🥓 ", Content = "Discord 連結已複製到剪貼簿！", Duration = 6.5, Image = 10493023908})
            else
                Rayfield:Notify({Title = " 錯誤 ", Content = "您的執行器不支持自動複製，請手動輸入連結。", Duration = 6.5})
            end
        end,
    })

    TabAimbot:CreateSection("自瞄")
    TabAimbot:CreateToggle({
        Name = "啟用自動瞄準 (按住右鍵鎖定)",
        CurrentValue = false,
        Flag = "AimbotToggle",
        Callback = function(Value) AimbotEnabled = Value end,
    })
    TabAimbot:CreateDropdown({
        Name = "瞄準部位",
        Options = {"Head", "HumanoidRootPart"},
        CurrentOption = "Head",
        Flag = "AimPartDropdown",
        Callback = function(Option) AimPart = Option end,
    })
    TabAimbot:CreateSlider({
        Name = "自瞄平滑度 (1為最快，數字越大越像人)",
        Range = {1, 10},
        Increment = 0.5,
        Suffix = "Speed",
        CurrentValue = 5,
        Flag = "AimbotSmoothSlider",
        Callback = function(Value) AimbotSmoothness = Value end,
    })

    TabAimbot:CreateSection("FOV環")
    TabAimbot:CreateToggle({
        Name = "顯示 FOV 範圍環",
        CurrentValue = false,
        Flag = "FovCircleToggle",
        Callback = function(Value)
            FovCircleEnabled = Value
            if FOVCircle then FOVCircle.Visible = Value end
        end,
    })
    TabAimbot:CreateSlider({
        Name = "FOV 半徑大小",
        Range = {30, 500},
        Increment = 5,
        Suffix = "px",
        CurrentValue = 100,
        Flag = "FovRadiusSlider",
        Callback = function(Value)
            FovRadius = Value
            if FOVCircle then FOVCircle.Radius = Value end
        end,
    })
    TabAimbot:CreateColorPicker({
        Name = "FOV 環顏色 (非RGB狀態下生效)",
        Color = Color3.fromRGB(255, 255, 255),
        Flag = "FovColorPicker",
        Callback = function(Value)
            FovColor = Value
            if FOVCircle and not RgbEnabled then FOVCircle.Color = Value end
        end,
    })

    TabAimbot:CreateSection("進階安全檢測")
    TabAimbot:CreateToggle({
        Name = "啟用牆壁檢測",
        CurrentValue = false,
        Flag = "WallCheckToggle",
        Callback = function(Value) WallCheckEnabled = Value end,
    })
    TabAimbot:CreateToggle({
        Name = "啟用隊伍檢測",
        CurrentValue = false,
        Flag = "TeamCheckToggle",
        Callback = function(Value) TeamCheckEnabled = Value end,
    })

    TabInfo:CreateSection("💉 當前使用注入器環境")
    pcall(function()
        local executorName, executorVersion = "未知注入器 / 未偵測到環境", "N/A"
        if identifyexecutor then
            local name, ver = identifyexecutor()
            if name then executorName = tostring(name) end
            if ver then executorVersion = tostring(ver) end
        elseif getexecutorname then
            executorName = tostring(getexecutorname())
        end
        TabInfo:CreateParagraph({Title = "🛠️ 注入器名稱", Content = executorName})
        TabInfo:CreateParagraph({Title = "📌 注入器版本", Content = executorVersion})
    end)
    TabInfo:CreateSection("📋 基本公開檔案")
    pcall(function()
        TabInfo:CreateParagraph({Title = "👤 顯示名稱 (DisplayName)", Content = player.DisplayName})
        TabInfo:CreateParagraph({Title = "🆔 帳號名稱 (Username)", Content = player.Name})
        TabInfo:CreateParagraph({Title = "🔢 帳號 ID (UserID)", Content = tostring(player.UserId)})
    end)
    TabInfo:CreateSection("🕵️‍♂️ 帳號深度隱私資訊")
    pcall(function()
        local ageDays = player.AccountAge
        local joinYear = os.date("%Y") - math.floor(ageDays / 365)
        TabInfo:CreateParagraph({Title = "⏳ 帳號年齡", Content = tostring(ageDays) .. " 天 (大約於 " .. tostring(joinYear) .. " 年註冊)"})
        local friendCount = 0
        local success, page = pcall(function() return Players:GetFriendsAsync(player.UserId) end)
        if success and page then friendCount = #page:GetCurrentPage() end
        TabInfo:CreateParagraph({Title = "🤝 好友數量", Content = tostring(friendCount) .. " 人"})
    end)
    TabInfo:CreateSection("🌐 當前伺服器與物理環境")
    local PingParagraph
    pcall(function()
        TabInfo:CreateParagraph({Title = "🎮 遊戲 PlaceID", Content = tostring(game.PlaceId)})
        TabInfo:CreateParagraph({Title = "🔑 伺服器唯一識別碼 (JobId)", Content = game.JobId ~= "" and game.JobId or "單人/本地伺服器"})
        PingParagraph = TabInfo:CreateParagraph({Title = "📶 網路延遲 (Ping)", Content = "計算中..."})
    end)
    task.spawn(function()
        while task.wait(1) do
            pcall(function()
                if PingParagraph and player then
                    local currentPing = player:GetNetworkPing() * 1000
                    PingParagraph:Set({Title = "📶 網路延遲 (Ping)", Content = string.format("%.1f ms", currentPing)})
                end
            end)
        end
    end)

    TabPlayer:CreateSlider({
        Name = "調整玩家血量",
        Range = {0, 100}, Increment = 1, Suffix = "HP", CurrentValue = 100, Flag = "HealthSlider",
        Callback = function(Value)
            if player.Character and player.Character:FindFirstChild("Humanoid") then player.Character.Humanoid.Health = Value end
        end,
    })
    TabPlayer:CreateInput({
        Name = "輸入自訂速度 (預設: 16)",
        PlaceholderText = "目前速度: " .. tostring(CurrentSettings.WalkSpeed),
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local Number = tonumber(Text)
            if Number then
                CurrentSettings.WalkSpeed = Number
                pcall(function() if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Number end end)
            end
        end,
    })
    TabPlayer:CreateInput({
        Name = "輸入自訂跳躍力 (預設: 50)",
        PlaceholderText = "目前跳躍力: " .. tostring(CurrentSettings.JumpPower),
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local Number = tonumber(Text)
            if Number then
                CurrentSettings.JumpPower = Number
                pcall(function() if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then local humanoid = player.Character:FindFirstChildOfClass("Humanoid") humanoid.UseJumpPower = true humanoid.JumpPower = Number end end)
            end
        end,
    })
    TabPlayer:CreateInput({
        Name = "輸入自訂重力 (預設: 196.2)",
        PlaceholderText = "目前重力: " .. tostring(workspace.Gravity),
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local Number = tonumber(Text)
            if Number then pcall(function() workspace.Gravity = Number end) end
        end,
    })
    TabPlayer:CreateButton({
        Name = "恢復",
        Callback = function()
            local DEFAULT_GRAVITY = 196.2
            local DEFAULT_JUMPPOWER = 50
            if CurrentSettings then CurrentSettings.Gravity = DEFAULT_GRAVITY CurrentSettings.JumpPower = DEFAULT_JUMPPOWER end
            pcall(function() workspace.Gravity = DEFAULT_GRAVITY end)
            pcall(function()
                if player.Character then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid then humanoid.UseJumpPower = true humanoid.JumpPower = DEFAULT_JUMPPOWER end
                end
            end)
        end,
    })
    TabPlayer:CreateSection(" ")
    TabPlayer:CreateButton({
        Name = "飛行",
        Callback = function() loadstring(game:HttpGet("https://pastebin.com/raw/feYeCwiR"))() end,
    })
    local InfiniteJumpEnabled = false
    game:GetService("UserInputService").JumpRequest:Connect(function()
        if InfiniteJumpEnabled then
            pcall(function()
                if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
                    player.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        end
    end)
    TabPlayer:CreateButton({
        Name = "無限跳",
        Callback = function() InfiniteJumpEnabled = true end,
    })
    local featureConnection = nil
    TabPlayer:CreateToggle({
       Name = "穿牆",
       CurrentValue = false,
       Flag = "MysteryFeatureToggle",
       Callback = function(Value)
          if Value then

             featureConnection = RunService.Stepped:Connect(function()
                if player.Character then
                    for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso", "Head"}) do
                        local part = player.Character:FindFirstChild(name)
                        if part and part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
             end)
             Rayfield:Notify({Title = "穿牆", Content = "已啟動", Duration = 2})
          else
             if featureConnection then featureConnection:Disconnect() featureConnection = nil end
             Rayfield:Notify({Title = "穿牆", Content = "已關閉", Duration = 2})
          end
       end,
    })
    TabPlayer:CreateButton({
        Name = "自由相機",
        Callback = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/QAQ0722/BaconHub-V3.0-/refs/heads/main/%E8%87%AA%E7%94%B1%E7%9B%B8%E6%A9%9F.lua"))() end,
    })


    local function updateESP()
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local pChar = p.Character
                local pHrp = pChar:FindFirstChild("HumanoidRootPart")
                local existingEsp = pChar:FindFirstChild(espTag)
                local existingBeam = pChar:FindFirstChild(beamTag)
                local pAttachment = pHrp and pHrp:FindFirstChild(attachTag)
                if EspEnabled then
                    if not existingEsp then
                        local highlight = Instance.new("Highlight")
                        highlight.Name = espTag
                        highlight.FillColor = EspColor
                        highlight.FillTransparency = 0.5
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.Parent = pChar
                    else existingEsp.FillColor = EspColor end
                else if existingEsp then existingEsp:Destroy() end end
               
                if TracerEnabled and p ~= player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and pHrp then
                    local localHrp = player.Character.HumanoidRootPart
                    local localAttachment = localHrp:FindFirstChild("RootAttachment") or localHrp:FindFirstChildOfClass("Attachment")
                    if not pAttachment then
                        pAttachment = Instance.new("Attachment")
                        pAttachment.Name = attachTag
                        pAttachment.Parent = pHrp
                    end
                    if localAttachment and pAttachment then
                        if not existingBeam then
                            local beam = Instance.new("Beam")
                            beam.Name = beamTag
                            beam.Attachment0 = localAttachment
                            beam.Attachment1 = pAttachment
                            beam.Width0, beam.Width1 = 0.1, 0.1
                            beam.Color = ColorSequence.new(EspColor)
                            beam.FaceCamera = true
                            beam.Parent = pChar
                        else existingBeam.Color = ColorSequence.new(EspColor) end
                    end
                else
                    if existingBeam then existingBeam:Destroy() end
                    if pAttachment then pAttachment:Destroy() end
                end
            end
        end
    end

    TabVisuals:CreateToggle({Name = "玩家ESP", CurrentValue = false, Flag = "PlayerEspToggle", Callback = function(Value) EspEnabled = Value updateESP() end})
    TabVisuals:CreateToggle({Name = "追蹤線", CurrentValue = false, Flag = "PlayerTracerToggle", Callback = function(Value) TracerEnabled = Value updateESP() end})
    TabVisuals:CreateColorPicker({Name = "顏色設定", Color = Color3.fromRGB(255, 0, 0), Flag = "EspColorPicker", Callback = function(Value) if not RgbEnabled then EspColor = Value updateESP() end end})
    TabVisuals:CreateToggle({Name = "RGB", CurrentValue = false, Flag = "RgbEspToggle", Callback = function(Value) RgbEnabled = Value end})
    TabVisuals:CreateSection(" ")
    TabVisuals:CreateButton({Name = "夜視", Callback = function() game.Lighting.OutdoorAmbient = Color3.new(1,1,1) game.Lighting.Ambient = Color3.new(1,1,1) game.Lighting.TimeOfDay = "12:00:00" end})
    
    TabVisuals:CreateButton({
        Name = "培根光影",
        Callback = function() 
            pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/QAQ0722/BaconHub-V3.0-/refs/heads/main/%E5%9F%B9%E6%A0%B9%E5%85%89%E5%BD%B1.lua"))() 
            end)
        end, 
    })

    task.spawn(function()
        while task.wait(0.1) do if EspEnabled or TracerEnabled then updateESP() end end
    end)

    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        pcall(function() local humanoid = char:FindFirstChildOfClass("Humanoid") if humanoid then humanoid.WalkSpeed = CurrentSettings.WalkSpeed humanoid.UseJumpPower = true humanoid.JumpPower = CurrentSettings.JumpPower end end)
    end)
end

local function checkWallVisibility(targetPart)
    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {player.Character, targetPart.Parent}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true
   
    local result = workspace:Raycast(origin, direction, raycastParams)
    if result then return false end
    return true
end

local function getClosestPlayerInFOV()
    local target = nil
    local maxDistance = FovRadius
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
       
        if TeamCheckEnabled then
            if player.Team and p.Team and player.Team == p.Team then continue end
            if player.TeamColor and p.TeamColor and player.TeamColor == p.TeamColor then continue end
        end

        if p.Character and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local aimTargetPart = p.Character:FindFirstChild(AimPart)
            if not aimTargetPart then continue end

            local screenPos, onScreen = camera:WorldToViewportPoint(aimTargetPart.Position)
            if onScreen then
                local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                if distanceToCenter < maxDistance then
                    if WallCheckEnabled and not checkWallVisibility(aimTargetPart) then continue end
                    maxDistance = distanceToCenter
                    target = aimTargetPart
                end
            end
        end
    end
    return target
end

local lastMouseState = true 
RunService.RenderStepped:Connect(function()
    if RgbEnabled then
        local hue = (tick() % 5) / 5
        EspColor = Color3.fromHSV(hue, 1, 1)
        if FOVCircle and FovCircleEnabled then FOVCircle.Color = EspColor end
    else
        if FOVCircle and FovCircleEnabled then FOVCircle.Color = FovColor end
    end

    if FOVCircle and FOVCircle.Visible then
        FOVCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    end

    if AimbotEnabled and UserInputService:IsMouseButtonPressed(AimbotKey) then
        if lastMouseState == true then
            UserInputService.MouseIconEnabled = false
            lastMouseState = false
        end
       
        local targetPart = getClosestPlayerInFOV()
        if targetPart then
            local targetCFrame = CFrame.new(camera.CFrame.Position, targetPart.Position)
            camera.CFrame = camera.CFrame:Lerp(targetCFrame, 1 / AimbotSmoothness)
        end
    else
        if lastMouseState == false then
            UserInputService.MouseIconEnabled = true
            lastMouseState = true
        end
    end
end)

task.spawn(function()
    repeat task.wait(0.05) until musicStarted and imageReady
    fadeGui(LogoImage, "ImageTransparency", 1, 0, 1.8)
    task.wait(1.5)
    task.spawn(function() fadeGui(LogoImage, "ImageTransparency", 0, 1, 1.2) end)
    fadeGui(Background, "BackgroundTransparency", 0, 1, 1.2)
    ScreenGui:Destroy()
    task.wait(0.1)
    initMainScript()
end)

pcall(function()
    for _, connection in ipairs(getconnections(player.Idled)) do
        if connection.Disable then connection:Disable() elseif connection.Disconnect then connection:Disconnect() end
    end
end)
pcall(function() player.Idled:Connect(function() return end) end)
