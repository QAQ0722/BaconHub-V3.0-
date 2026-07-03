local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local TOP_SPEED = 85
local TURN_SMOOTHNESS = 0.12
local FRICTION = 0.98
local CRASH_THRESHOLD = 45
local isMobile = UserInputService.TouchEnabled
local AUDIO_URL = "https://image2url.com/r2/default/audio/1774688302764-57a82f77-027d-4977-8219-bfa09157f5cb.mp3"

local drone = nil
local droneSound = nil
local currentVel = Vector3.new(0, 0, 0)
local inputs = {fwd = 0, side = 0, up = 0}
local isControlling = false
local jointConnection = nil

local ScreenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
ScreenGui.Name = "Drone_Hardcore_UI"
ScreenGui.ResetOnSpawn = false

local MsgLabel = Instance.new("TextLabel", ScreenGui)
MsgLabel.Size = UDim2.new(0, 300, 0, 40)
MsgLabel.Position = UDim2.new(0.5, -150, 0.1, 0)
MsgLabel.BackgroundTransparency = 0.5; MsgLabel.BackgroundColor3 = Color3.new(0, 0, 0)
MsgLabel.TextColor3 = Color3.new(1, 1, 1); MsgLabel.Font = Enum.Font.GothamBold; MsgLabel.TextSize = 18
MsgLabel.Text = ""; Instance.new("UICorner", MsgLabel)

local function ShowMsg(text, color, duration)
    MsgLabel.Text = text; MsgLabel.TextColor3 = color or Color3.new(1, 1, 1)
    task.delay(duration or 2, function() if MsgLabel.Text == text then MsgLabel.Text = "" end end)
end

local MobileControls = Instance.new("Frame", ScreenGui)
MobileControls.Size = UDim2.new(1, 0, 1, 0); MobileControls.BackgroundTransparency = 1; MobileControls.Visible = false

if isMobile then
    local function createMobileBtn(text, pos, key, val)
        local b = Instance.new("TextButton", MobileControls)
        b.Text = text; b.Size = UDim2.new(0, 80, 0, 80); b.Position = pos
        b.BackgroundColor3 = Color3.new(0, 0, 0); b.BackgroundTransparency = 0.5; b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold; b.TextSize = 30; Instance.new("UICorner", b)
        b.MouseButton1Down:Connect(function() inputs[key] = val end)
        b.MouseButton1Up:Connect(function() inputs[key] = 0 end)
    end
    createMobileBtn("▲", UDim2.new(0.1, 0, 0.6, 0), "fwd", 1)
    createMobileBtn("▼", UDim2.new(0.1, 0, 0.8, 0), "fwd", -1)
    createMobileBtn("升", UDim2.new(0.8, 0, 0.6, 0), "up", 1)
    createMobileBtn("降", UDim2.new(0.8, 0, 0.8, 0), "up", -1)
end

local function LoadExternalSound(name, url)
    local fileName = name .. ".mp3"
    if not isfile(fileName) then
        local success, content = pcall(function() return game:HttpGet(url) end)
        if success then writefile(fileName, content) end
    end
    local s = Instance.new("Sound")
    s.SoundId = getcustomasset(fileName); s.Volume = 1; s.Looped = true
    return s
end

local function explodeDrone()
    if not drone then return end
    isControlling = false
    camera.CameraSubject = player.Character.Humanoid
    MobileControls.Visible = false
    ShowMsg("💥 無人機已墜毀！", Color3.new(1, 0, 0), 3)

    if jointConnection then jointConnection:Disconnect(); jointConnection = nil end
    if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        player.Character.Humanoid.Sit = false
    end
    
    if drone:FindFirstChild("BodyVelocity") then drone.BodyVelocity:Destroy() end
    if drone:FindFirstChild("BodyGyro") then drone.BodyGyro:Destroy() end
    if droneSound then droneSound:Stop() end
    
    drone.Color = Color3.new(1, 0, 0)
    drone.Velocity = Vector3.new(math.random(-5,5), 10, math.random(-5,5))
    task.wait(1.5)
    if drone then drone:Destroy(); drone = nil end
end

local backpack = player:WaitForChild("Backpack")
local deployTool = Instance.new("Tool", backpack); deployTool.Name = "📦 部署"; deployTool.RequiresHandle = false
local controlTool = Instance.new("Tool", backpack); controlTool.Name = "🎮 遙控"; controlTool.RequiresHandle = false

deployTool.Activated:Connect(function()
    if drone then drone:Destroy() end
    drone = Instance.new("Part", workspace)
    drone.Name = "FPV_Drone_Hardcore"; drone.Size = Vector3.new(1.4, 0.3, 1.4)
    drone.Color = Color3.fromRGB(0, 255, 150); drone.Material = Enum.Material.Neon
    drone.CFrame = CFrame.new(mouse.Hit.p + Vector3.new(0, 1.5, 0))
    
    droneSound = LoadExternalSound("DroneEngine", AUDIO_URL)
    if droneSound then droneSound.Parent = drone end
    
    local bv = Instance.new("BodyVelocity", drone); bv.MaxForce = Vector3.new(0, 0, 0)
    local bg = Instance.new("BodyGyro", drone); bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6); bg.P = 2000
    
    ShowMsg("🚀 已部署，碰撞即損毀！", Color3.new(1, 1, 1), 2)

    drone.Touched:Connect(function(hit)
        if isControlling and not hit:IsDescendantOf(player.Character) then
            if drone.Velocity.Magnitude > CRASH_THRESHOLD then
                explodeDrone()
            end
        end
    end)
end)

controlTool.Equipped:Connect(function()
    if drone then
        isControlling = true; camera.CameraSubject = drone
        if isMobile then MobileControls.Visible = true end
        if droneSound then droneSound:Play() end

        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Sit = true
            
            jointConnection = RunService.Stepped:Connect(function()
                if not isControlling or not char.Parent then return end
                
                local pRS, pLS
                if hum.RigType == Enum.HumanoidRigType.R15 then
                    pRS = char:FindFirstChild("RightUpperArm") and char.RightUpperArm:FindFirstChild("RightShoulder")
                    pLS = char:FindFirstChild("LeftUpperArm") and char.LeftUpperArm:FindFirstChild("LeftShoulder")
                else
                    pRS = char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Right Shoulder")
                    pLS = char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Left Shoulder")
                end

                if pRS then pRS.Transform = CFrame.new(-0.1, -0.2, 0) * CFrame.Angles(math.rad(60), 0, math.rad(15)) end
                if pLS then pLS.Transform = CFrame.new(0.1, -0.2, 0) * CFrame.Angles(math.rad(60), 0, math.rad(-15)) end
            end)
        end
    else
        ShowMsg("❌ 尚未部署無人機", Color3.new(1, 0, 0), 2)
    end
end)

controlTool.Unequipped:Connect(function()
    isControlling = false; camera.CameraSubject = player.Character.Humanoid
    MobileControls.Visible = false
    if droneSound then droneSound:Stop() end
    for k in pairs(inputs) do inputs[k] = 0 end

    if jointConnection then jointConnection:Disconnect(); jointConnection = nil end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.Sit = false end

end)

RunService.RenderStepped:Connect(function(dt)
    if drone and isControlling and drone:FindFirstChild("BodyVelocity") then
        if not isMobile then
            inputs.fwd = UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or (UserInputService:IsKeyDown(Enum.KeyCode.S) and -1 or 0)
            inputs.up = UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and -1 or 0)
            inputs.side = UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or (UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0)
        end
        
        local look = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local moveDir = (look * inputs.fwd) + (Vector3.new(0, 1, 0) * inputs.up) + (right * inputs.side)
        
        if moveDir.Magnitude > 0 then
            currentVel = currentVel:Lerp(moveDir.Unit * TOP_SPEED, TURN_SMOOTHNESS)
            drone.BodyGyro.P = 50000; drone.BodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        else
            currentVel = currentVel * FRICTION
            if currentVel.Magnitude < 0.5 then
                currentVel = Vector3.new(0, 0, 0)
                drone.BodyGyro.P = 2000; drone.BodyVelocity.MaxForce = Vector3.new(0, 0, 0)
            end
        end
        drone.BodyVelocity.Velocity = currentVel
        drone.BodyGyro.CFrame = camera.CFrame
    end
end)
