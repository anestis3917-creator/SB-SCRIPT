-- slap.lua — v12.0 (True Slap Aura: Spoof Click + Remote + Anti-Kick)
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local LP                = Players.LocalPlayer

local STATE = {
    SLAP_AURA      = false,
    AURA_RADIUS    = 8,     -- Default radius
    SKIP_RAGDOLL   = true,  -- Don't slap downed players
    MAX_PER_BURST  = 2,     -- How many players to slap at once
    BURST_COOLDOWN = 2.0,   -- Wait 2 seconds before slapping again (Anti-Kick)
}

local AURA_RING    = nil
local lastBurst    = 0

local function get_hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local Remotes = ReplicatedStorage:WaitForChild("Events", 10)
-- OnAcrobatSlap usually covers most basic gloves
local SlapRemote = Remotes and Remotes:FindFirstChild("OnAcrobatSlap")

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

local function is_ragdolled(character)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return true end
    -- Check if they are downed/ragdolled (Health is low or they have a specific ragdoll state)
    if hum.Health <= 0 then return true end
    -- Slap Battles usually puts a "Ragdoll" bool or a "Ragdolled" tag when downed
    if character:FindFirstChild("Ragdoll") or hum:GetState() == Enum.HumanoidStateType.Physics then
        return true
    end
    return false
end

-- 1. SPOOF CLICK (Simulates you actually clicking your mouse)
local function spoof_click()
    pcall(function()
        -- Tap LMB in the game engine
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(Vector2.new(0, 0))
    end)
    -- Also try to Activate the equipped tool (the glove) directly
    local char = LP.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function() tool:Activate() end)
        end
    end
end

-- 2. REMOTE FIRE
local function fire_remote(target)
    if not SlapRemote then return end
    local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    pcall(function()
        SlapRemote:FireServer(target)
        if hrp then SlapRemote:FireServer(target, hrp.CFrame.LookVector) end
    end)
end

local function slap_aura_step()
    if not STATE.SLAP_AURA then return end
    local myHrp = get_hrp()
    if not myHrp then return end

    local ring = build_ring()
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LP.Character}
    local ray = Workspace:Raycast(myHrp.Position, Vector3.new(0, -50, 0), rayParams)
    local floorY = ray and ray.Position.Y or (myHrp.Position.Y - 3)
    
    ring.CFrame = CFrame.new(myHrp.Position.X, floorY + 0.1, myHrp.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
    ring.Size = Vector3.new(0.2, STATE.AURA_RADIUS * 2, STATE.AURA_RADIUS * 2)

    local now = tick()
    -- Anti-Cheat Guard: Wait for the burst cooldown before hitting anyone
    if now - lastBurst < STATE.BURST_COOLDOWN then return end

    local targetsHit = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and in_circle(hrp.Position, myHrp.Position, STATE.AURA_RADIUS) then
                
                -- AuraRagdollCheck toggle
                if STATE.SKIP_RAGDOLL and is_ragdolled(p.Character) then
                    continue
                end

                -- Execute BOTH execution methods
                spoof_click()
                fire_remote(p)
                
                targetsHit = targetsHit + 1
                if targetsHit >= STATE.MAX_PER_BURST then
                    break
                end
            end
        end
    end

    if targetsHit > 0 then
        lastBurst = now -- Reset the anti-kick timer
    end
end

-- UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "_oll_ui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 240, 0, 160)
panel.Position = UDim2.new(0, 20, 0, 20)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.BorderSizePixel = 0
panel.Parent = ScreenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "ollie • slap v12"
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

local ragdollBtn = Instance.new("TextButton")
ragdollBtn.Size = UDim2.new(1, -20, 0, 25)
ragdollBtn.Position = UDim2.new(0, 10, 0, 110)
ragdollBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 120) -- On by default
ragdollBtn.Text = "Skip Ragdolled: ON"
ragdollBtn.TextColor3 = Color3.fromRGB(18, 18, 22)
ragdollBtn.Font = Enum.Font.GothamBold
ragdollBtn.TextSize = 12
ragdollBtn.Parent = panel
Instance.new("UICorner", ragdollBtn).CornerRadius = UDim.new(0, 6)

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
    if STATE.AURA_RADIUS > 16 then STATE.AURA_RADIUS = 2 end
    slider.Text = "Radius: " .. STATE.AURA_RADIUS
end)

ragdollBtn.MouseButton1Click:Connect(function()
    STATE.SKIP_RAGDOLL = not STATE.SKIP_RAGDOLL
    if STATE.SKIP_RAGDOLL then
        ragdollBtn.Text = "Skip Ragdolled: ON"
        ragdollBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
        ragdollBtn.TextColor3 = Color3.fromRGB(18, 18, 22)
    else
        ragdollBtn.Text = "Skip Ragdolled: OFF"
        ragdollBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
        ragdollBtn.TextColor3 = Color3.fromRGB(230, 230, 235)
    end
end)

RunService.RenderStepped:Connect(function()
    if STATE.SLAP_AURA then pcall(slap_aura_step) end
end)

print("[ollie] slap v12 live. remote=", SlapRemote ~= nil)
