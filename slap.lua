-- slap.lua — v17.0 (Physical Hitbox)
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP                = Players.LocalPlayer

local STATE = {
    SLAP_AURA   = false,
    AURA_RADIUS = 8,
}

local AURA_PART = nil
local lastSlap = {}
local ActiveRemotes = {}

local function scan_remotes()
    ActiveRemotes = {}
    local folder = ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage:FindFirstChild("Remotes")
    if folder then
        for _, v in pairs(folder:GetChildren()) do
            if v:IsA("RemoteEvent") then
                local n = v.Name:lower()
                if n:find("slap") or n:find("hit") or n:find("swing") or n:find("punch") then
                    table.insert(ActiveRemotes, v)
                end
            end
        end
    end
end

local function build_ring()
    if AURA_PART and AURA_PART.Parent then return AURA_PART end
    
    local p = Instance.new("Part")
    p.Name         = "_oll_aura_ring"
    p.Shape        = Enum.PartType.Cylinder
    p.Anchored     = true
    p.CanCollide   = true -- MUST be true for Touched to fire
    p.CanTouch     = true
    p.Transparency = 0.5
    p.Color        = Color3.fromRGB(0, 150, 255)
    p.Material     = Enum.Material.ForceField
    p.Size         = Vector3.new(0.2, STATE.AURA_RADIUS * 2, STATE.AURA_RADIUS * 2)
    p.Parent       = Workspace
    
    p.Touched:Connect(function(hit)
        if not STATE.SLAP_AURA then return end
        
        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)
        
        if player and player ~= LP then
            local now = tick()
            local last = lastSlap[player] or 0
            
            if now - last >= 0.3 then
                lastSlap[player] = now
                
                local char = LP.Character
                local tool = char and char:FindFirstChildOfClass("Tool")
                if tool then pcall(function() tool:Activate() end) end
                
                local thrp = character:FindFirstChild("HumanoidRootPart")
                for _, remote in ipairs(ActiveRemotes) do
                    pcall(function()
                        remote:FireServer(player)
                        if thrp then remote:FireServer(player, thrp.CFrame.LookVector) end
                    end)
                end
            end
        end
    end)
    
    AURA_PART = p
    return p
end

local function kill_ring()
    if AURA_PART then pcall(function() AURA_PART:Destroy() end) end
    AURA_PART = nil
end

-- Update the ring position every frame so it stays flat on the floor
RunService.RenderStepped:Connect(function()
    if STATE.SLAP_AURA then
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            if not AURA_PART or not AURA_PART.Parent then build_ring() end
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {LP.Character}
            local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -50, 0), rayParams)
            local floorY = ray and ray.Position.Y or (hrp.Position.Y - 3)
            
            AURA_PART.CFrame = CFrame.new(hrp.Position.X, floorY + 0.1, hrp.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
            AURA_PART.Size = Vector3.new(0.2, STATE.AURA_RADIUS * 2, STATE.AURA_RADIUS * 2)
        end
    end
end)

LP.CharacterAdded:Connect(function()
    kill_ring()
    lastSlap = {}
end)

scan_remotes()

-- UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "_oll_ui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 220, 0, 110)
panel.Position = UDim2.new(0, 20, 0, 20)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.BorderSizePixel = 0
panel.Parent = ScreenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "ollie • slap v17"
title.TextColor3 = Color3.fromRGB(230, 230, 235)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.Parent = panel

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -20, 0, 30)
btn.Position = UDim2.new(0, 10, 0, 35)
btn.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
btn.Text = "Slap Aura: OFF"
btn.TextColor3 = Color3.fromRGB(230, 230, 235)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 13
btn.Parent = panel
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

local slider = Instance.new("TextButton")
slider.Size = UDim2.new(1, -20, 0, 25)
slider.Position = UDim2.new(0, 10, 0, 75)
slider.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
slider.Text = "Radius: " .. STATE.AURA_RADIUS
slider.TextColor3 = Color3.fromRGB(150, 150, 160)
slider.Font = Enum.Font.Gotham
slider.TextSize = 12
slider.Parent = panel
Instance.new("UICorner", slider).CornerRadius = UDim.new(0, 6)

btn.MouseButton1Click:Connect(function()
    STATE.SLAP_AURA = not STATE.SLAP_AURA
    if STATE.SLAP_AURA then
        btn.Text = "Slap Aura: ON"
        btn.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
        build_ring()
    else
        btn.Text = "Slap Aura: OFF"
        btn.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
        kill_ring()
    end
end)

slider.MouseButton1Click:Connect(function()
    STATE.AURA_RADIUS = STATE.AURA_RADIUS + 2
    if STATE.AURA_RADIUS > 16 then STATE.AURA_RADIUS = 4 end
    slider.Text = "Radius: " .. STATE.AURA_RADIUS
end)

print("[ollie] slap v17 live. remotes found:", #ActiveRemotes)
