local player = game.Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")

local pgui = player:WaitForChild("PlayerGui")
if pgui:FindFirstChild("BaconFreecam_Universal") then
    pgui.BaconFreecam_Universal:Destroy()
end

local FreecamActive = false
local FreecamSpeed = 1.5
local sens = 0.3
local rotX, rotY = 0, 0 
local keysDown = {}
local rotating = false
local isMobile = UserInputService.TouchEnabled

local main = Instance.new("ScreenGui")
main.Name = "BaconFreecam_Universal"
main.Parent = pgui
main.ResetOnSpawn = false

local Frame = Instance.new("Frame", main)
Frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Frame.Position = UDim2.new(0.1, 0, 0.4, 0)
Frame.Size = UDim2.new(0, 220, 0, 110)
Frame.Active = true
Frame.Draggable = true
Instance.new("UICorner", Frame)

local Title = Instance.new("TextLabel", Frame)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = isMobile and "🥓 培根相機 (手機模式)" or "🥓 培根相機 (電腦模式)"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.BackgroundTransparency = 1
Title.TextSize = 16

local ToggleBtn = Instance.new("TextButton", Frame)
ToggleBtn.Position = UDim2.new(0.05, 0, 0.35, 0)
ToggleBtn.Size = UDim2.new(0.9, 0, 0.3, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
ToggleBtn.Text = "🎥 啟動自由相機"
ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", ToggleBtn)

local SpeedLabel = Instance.new("TextLabel", Frame)
SpeedLabel.Position = UDim2.new(0.05, 0, 0.7, 0)
SpeedLabel.Size = UDim2.new(0.4, 0, 0.25, 0)
SpeedLabel.Text = "速度: 1.5"
SpeedLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
SpeedLabel.BackgroundTransparency = 1

local function createSpeedBtn(text, xPos, offset)
    local btn = Instance.new("TextButton", Frame)
    btn.Size = UDim2.new(0.2, 0, 0.25, 0)
    btn.Position = UDim2.new(xPos, 0, 0.7, 0)
    btn.Text = text
    btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    btn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", btn)
    btn.MouseButton1Click:Connect(function()
        FreecamSpeed = math.clamp(FreecamSpeed + offset, 0.1, 10)
        SpeedLabel.Text = "速度: " .. string.format("%.1f", FreecamSpeed)
    end)
end
createSpeedBtn("-", 0.5, -0.5)
createSpeedBtn("+", 0.75, 0.5)

local function ToggleFreecam()
    FreecamActive = not FreecamActive
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if FreecamActive then
        ToggleBtn.Text = "❌ 關閉"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 255, 60)
        
        local look = Camera.CFrame.LookVector
        rotX = math.atan2(-look.X, -look.Z)
        rotY = math.asin(math.clamp(look.Y, -0.99, 0.99))
        
        Camera.CameraType = Enum.CameraType.Scriptable
        
        if not isMobile then
            CAS:BindAction("FreecamFreeze", function() return Enum.ContextActionResult.Sink end, false, 
                Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space)
        end
    else
        ToggleBtn.Text = "🎥 自由相機"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        Camera.CameraType = Enum.CameraType.Custom
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        if not isMobile then CAS:UnbindAction("FreecamFreeze") end
        keysDown = {}
    end
end

UserInputService.InputChanged:Connect(function(input)
    if not FreecamActive then return end
    if isMobile and input.UserInputType == Enum.UserInputType.Touch then
        if input.Position.X > (Camera.ViewportSize.X * 0.4) then
            local delta = input.Delta
            rotX = rotX - delta.X * 0.007
            rotY = math.clamp(rotY - delta.Y * 0.007, -math.rad(89), math.rad(89))
        end
    elseif not isMobile and rotating and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Delta
        rotX = rotX - delta.X * (sens/50)
        rotY = math.clamp(rotY - delta.Y * (sens/50), -math.rad(89), math.rad(89))
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    end
end)

if not isMobile then
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode ~= Enum.KeyCode.Unknown then keysDown[input.KeyCode.Name] = true end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then rotating = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode ~= Enum.KeyCode.Unknown then keysDown[input.KeyCode.Name] = false end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then 
            rotating = false 
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end)
end

RunService.RenderStepped:Connect(function()
    if not FreecamActive then return end
    
    Camera.CFrame = CFrame.new(Camera.CFrame.Position) * CFrame.Angles(0, rotX, 0) * CFrame.Angles(rotY, 0, 0)
    
    local move = Vector3.new(0,0,0)
    if isMobile then  
        local success, result = pcall(function()
            local PlayerModule = player.PlayerScripts:FindFirstChild("PlayerModule")
            if PlayerModule then
                local controls = require(PlayerModule):GetControls()
                return controls:GetMoveVector()
            end
        end)
        if success and result and result.Magnitude > 0 then
            move = (Camera.CFrame.LookVector * -result.Z) + (Camera.CFrame.RightVector * result.X)
        end
    else
        local dir = Vector3.new(0,0,0)
        if keysDown["W"] then dir += Vector3.new(0,0,-1) end
        if keysDown["S"] then dir += Vector3.new(0,0,1) end
        if keysDown["A"] then dir += Vector3.new(-1,0,0) end
        if keysDown["D"] then dir += Vector3.new(1,0,0) end
        if keysDown["E"] then dir += Vector3.new(0,1,0) end
        if keysDown["Q"] then dir += Vector3.new(0,-1,0) end
        if dir.Magnitude > 0 then move = Camera.CFrame:VectorToWorldSpace(dir) end
    end
    
    if move.Magnitude > 0 then
        Camera.CFrame = Camera.CFrame + (move * FreecamSpeed)
    end
end)

ToggleBtn.MouseButton1Click:Connect(ToggleFreecam)
