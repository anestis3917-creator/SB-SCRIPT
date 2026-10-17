-- slap.lua — v14.0 (Universal: All Gloves, Royale + Normal SB)
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP                = Players.LocalPlayer

local STATE = {
    SLAP_AURA   = false,
    AURA_RADIUS = 8, 
    IS_ROYALE   = false,
}

local AURA_RING    = nil
local lastSlap     = {}
local ActiveRemotes = {}

local function get_hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

-- AUTO-DETECT REMOTES
local function scan_remotes()
    ActiveRemotes = {}
    local folder = ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage:FindFirstChild("Remotes")
    if not folder then return end

    for _, v in pairs(folder:GetChildren()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            -- Grab any remote that looks like a slap or a hit
            if n:find("slap") or n:find("hit") or n:find("swing") or n:find("punch") then
                table.insert(ActiveRemotes, v)
            end
        end
    end
end

-- Detect if we are in Royale based on the map layout
local function check_game_mode()
    -- Slap Royale has a "BusModel" or specific lobby parts
    local isRoyale = Workspace:FindFirstChild("BusModel") ~= nil or Workspace:FindFirstChild("RoyaleMap") ~= nil
    if isRoyale ~= STATE.IS_ROYALE then
        STATE.IS_ROYALE = isRoyale
        scan_remotes() -- Rescan remotes when map changes
    end
end

local function build_ring()
    if AURA_RING and AURA_RING.Parent then return AURA_RING end
    local p = Instance.new("Part")
    p.Name         = "_oll_aura_ring"
    p.Shape        = Enum.PartType.Cylinder
    p.Anchored     = true
    p.CanCollide   = false
    p.CanQuery     = false
    p.CanTouch     = false
    p.Transparency = 0.5
    p.Color        = Color3.fromRGB(0, 150, 255)
    p.Material     = Enum.Material.ForceField
    p.Parent       = Workspace
    AURA_RING = p
    return p
end

local function kill_ring()
    if AURA_RING then pcall(function() AURA_RING:Destroy() end) end
    AURA_RING = nil
end

local function in_circle(targetPos, myPos, r)
    local a = Vector3.new(targetPos.X, 0, targetPos.Z)
    local b = Vector3.new(myPos.X, 0, myPos.Z)
    return (a - b).Magnitude <= r
end

local function fire_all_slaps(target)
    -- 1. Spoof the click so the game thinks you swung your glove
    local char = LP.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then pcall(function() tool:Activate() end) end
    end

    -- 2. Fire every single slap/hit remote we found
    local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    for _, remote in ipairs(ActiveRemotes) do
        pcall(function()
            remote:FireServer(target)
            if hrp then remote:FireServer(target, hrp.CFrame.LookVector) end
        end)
    end
end

local function slap_aura_step()
    if not STATE.SLAP_AURA then return end
    local myHrp = get_hrp()
    if not myHrp then return end

    -- Update ring
    local ring = build_ring()
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LP.Character}
    local ray = Workspace:Raycast(myHrp.Position, Vector3.new(0, -50, 0), rayParams)
    local floorY = ray and ray.Position.Y or (myHrp.Position.Y - 3)
    
    ring.CFrame = CFrame.new(myHrp.Position.X, floorY + 0.1, myHrp.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
    ring.Size = Vector3.new(0.2, STATE.AURA_RADIUS * 2, STATE.AURA_RADIUS * 2)

    -- Check targets
    local now = tick()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            
            if hrp and hum and hum.Health > 0 and in_circle(hrp.Position, myHrp.Position, STATE.AURA_RADIUS) then
                local last = lastSlap[p] or 0
                -- Anti-kick limit: slap each player only once every 0.25 seconds
                if now - last >= 0.25 then
                    lastSlap[p] = now
                    fire_all_slaps(p)
                end
            end
        end
    end
end

-- Auto-scan on load, and re-scan when respawning
scan_remotes()
task.spawn(function()
    while task.wait(2) do check_game_mode() end
end)

-- UI CODE
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
title.Text = "ollie • slap v14"
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

RunService.RenderStepped:Connect(function()
    if STATE.SLAP_AURA then pcall(slap_aura_step) end
end)

print("[ollie] slap v14 live. remotes found:", #ActiveRemotes)
