-- slap.lua — loadstring entry (v7.2: fast-walk loot, cancelable, paced)
-- usage: loadstring(game:HttpGet("URL_HERE"))()

local CONFIG = {
    PROMPT_PARENT_PATTERNS = {
        "crate", "box", "loot", "barrel", "chest", "supply", "apple", "banana",
    },
    ROYALE_MARKER_NAME = "_______NEVER_MATCH_______",
    AURA_TEXTURE_ID    = "rbxassetid://0",
    AURA_PARK_HEIGHT   = 5000,
    LOOT_COOLDOWN      = 3.0,
    LOOT_JITTER        = 0.5,
    LOOT_RANGE         = 500,
    WALK_TIMEOUT       = 8.0,
    ARRIVE_DISTANCE    = 6,
    PRE_PROMPT_DELAY_MIN = 0.15,
    PRE_PROMPT_DELAY_MAX = 0.40,
    LOOT_WALKSPEED     = 32,
    ESP_RANGE          = 2000,
    BASE_HITBOX        = 5,
    SLIDER_MAX         = 10,
}

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local LP = Players.LocalPlayer

local STATE = {
    AUTO_LOOT   = false,
    ESP_PLAYERS = false,
    ESP_ITEMS   = false,
    HIDE_AURA   = false,
    SLAP_AURA   = false,
    EXPANDER    = 1,
}

local AURA_PART = nil
local LOOT_GEN  = 0
local SAVED_WALKSPEED = nil

local function get_hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function get_humanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function boost_walkspeed()
    local hum = get_humanoid()
    if not hum then return end
    if SAVED_WALKSPEED == nil then SAVED_WALKSPEED = hum.WalkSpeed end
    hum.WalkSpeed = CONFIG.LOOT_WALKSPEED
end

local function restore_walkspeed()
    local hum = get_humanoid()
    if not hum then SAVED_WALKSPEED = nil return end
    if SAVED_WALKSPEED ~= nil then
        hum.WalkSpeed = SAVED_WALKSPEED
        SAVED_WALKSPEED = nil
    end
end

local function in_royale()
    local m = Workspace:FindFirstChild(CONFIG.ROYALE_MARKER_NAME)
        or game:GetService("ReplicatedStorage"):FindFirstChild(CONFIG.ROYALE_MARKER_NAME)
    return m ~= nil
end

local function matches(name)
    local l = name:lower()
    for _, p in ipairs(CONFIG.PROMPT_PARENT_PATTERNS) do
        if l:find(p, 1, true) then return true end
    end
    return false
end

local function prompt_part(prompt)
    local p = prompt.Parent
    if not p then return nil end
    if p:IsA("BasePart") then return p end
    return p:FindFirstChildWhichIsA("BasePart")
end

-- hitbox
local HITBOX_NAMES = { "Hitbox", "SlapHitbox", "Aura", "SlapAura", "Handle" }

local function find_hitbox(char)
    if not char then return nil end
    for _, name in ipairs(HITBOX_NAMES) do
        local p = char:FindFirstChild(name, true)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
end

local function apply_expander()
    local char = LP.Character
    if not char then return end
    local hb = find_hitbox(char)
    if not hb then return end
    local mult = STATE.SLAP_AURA and STATE.EXPANDER or 1
    local s = CONFIG.BASE_HITBOX * mult
    hb.Size = Vector3.new(s, s, s)
    hb.CanCollide = false
    hb.Massless = true
    if STATE.SLAP_AURA then
        hb.Transparency = math.clamp(0.6 - (STATE.EXPANDER - 1) * 0.05, 0.2, 0.6)
    end
end

-- esp
local playerDrawings, itemDrawings = {}, {}

local function new_text(color)
    local t = Drawing.new("Text")
    t.Size = 16
    t.Center = true
    t.Outline = true
    t.OutlineColor = Color3.new(0, 0, 0)
    t.Font = 2
    t.Color = color
    t.Visible = false
    return t
end

local function get_glove(p)
    local candidates = {
        p:FindFirstChild("Glove"),
        p:FindFirstChild("EquippedGlove"),
        p:FindFirstChild("CurrentGlove"),
        p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Glove"),
    }
    for _, c in ipairs(candidates) do
        if c and (c:IsA("StringValue") or c:IsA("ValueBase")) then
            return tostring(c.Value)
        end
    end
    local char = p.Character
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Tool") then return c.Name end
        end
    end
    return "?"
end

local function update_player_esp()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local my_hrp = get_hrp()
    local my_pos = my_hrp and my_hrp.Position
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local vis = false
            if hrp and head and hum and hum.Health > 0 then
                local dist = my_pos and (hrp.Position - my_pos).Magnitude or 0
                if dist <= CONFIG.ESP_RANGE then
                    local sp, on = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 2, 0))
                    if on then
                        if not playerDrawings[p] then
                            playerDrawings[p] = {
                                name = new_text(Color3.fromRGB(255, 90, 90)),
                                glove = new_text(Color3.fromRGB(255, 220, 80)),
                            }
                        end
                        local d = playerDrawings[p]
                        d.name.Text = p.Name
                        d.name.Position = Vector2.new(sp.X, sp.Y)
                        d.name.Visible = true
                        d.glove.Text = "[" .. get_glove(p) .. "]"
                        d.glove.Position = Vector2.new(sp.X, sp.Y + 18)
                        d.glove.Visible = true
                        vis = true
                    end
                end
            end
            if not vis and playerDrawings[p] then
                for _, o in pairs(playerDrawings[p]) do o.Visible = false end
            end
        end
    end
end

local function update_item_esp()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local my_hrp = get_hrp()
    local my_pos = my_hrp and my_hrp.Position
    local seen = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Parent then
            if matches(obj.Parent.Name) then
                local part = prompt_part(obj)
                if part then
                    local dist = my_pos and (part.Position - my_pos).Magnitude or 0
                    if dist <= CONFIG.ESP_RANGE then
                        local sp, on = cam:WorldToViewportPoint(part.Position + Vector3.new(0, 2, 0))
                        if on then
                            seen[obj] = true
                            if not itemDrawings[obj] then
                                itemDrawings[obj] = { label = new_text(Color3.fromRGB(90, 255, 130)) }
                            end
                            local d = itemDrawings[obj]
                            local n = obj.Parent.Name:gsub("%d+$", ""):gsub("_", " ")
                            d.label.Text = n
                            d.label.Position = Vector2.new(sp.X, sp.Y)
                            d.label.Visible = true
                        end
                    end
                end
            end
        end
    end
    for obj, d in pairs(itemDrawings) do
        if not seen[obj] or not obj.Parent then
            for _, o in pairs(d) do pcall(function() o:Remove() end) end
            itemDrawings[obj] = nil
        end
    end
end

-- loot
local function nearest_prompt()
    local hrp = get_hrp()
    if not hrp then return nil end
    local my_pos = hrp.Position
    local best, best_dist = nil, CONFIG.LOOT_RANGE
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Parent and matches(obj.Parent.Name) then
            local part = prompt_part(obj)
            if part then
                local d = (part.Position - my_pos).Magnitude
                if d < best_dist then best_dist = d best = obj end
            end
        end
    end
    return best, best_dist
end

local function walk_to(part, gen)
    local hrp = get_hrp()
    local hum = get_humanoid()
    if not hrp or not hum then return false end

    boost_walkspeed()

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
    })
    local ok = pcall(function()
        path:ComputeAsync(hrp.Position, part.Position)
    end)

    if not ok or path.Status ~= Enum.PathStatus.Success then
        hum:MoveTo(part.Position)
        local t0 = tick()
        while (tick() - t0) < CONFIG.WALK_TIMEOUT do
            if gen ~= LOOT_GEN or not STATE.AUTO_LOOT then
                hum:MoveTo(hrp.Position)
                restore_walkspeed()
                return false
            end
            if (hrp.Position - part.Position).Magnitude <= CONFIG.ARRIVE_DISTANCE then
                return true
            end
            task.wait(0.05)
        end
        return false
    end

    for i = 2, #path:GetWaypoints() do
        if gen ~= LOOT_GEN or not STATE.AUTO_LOOT then
            hum:MoveTo(hrp.Position)
            restore_walkspeed()
            return false
        end
        local wp = path:GetWaypoints()[i]
        if wp.Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
        end
        hum:MoveTo(wp.Position)
        local t0 = tick()
        local reached = false
        while (tick() - t0) < CONFIG.WALK_TIMEOUT / math.max(1, #path:GetWaypoints()) do
            if gen ~= LOOT_GEN or not STATE.AUTO_LOOT then
                hum:MoveTo(hrp.Position)
                restore_walkspeed()
                return false
            end
            if (hrp.Position - wp.Position).Magnitude <= 3 then
                reached = true
                break
            end
            task.wait(0.03)
        end
        if not reached then return false end
    end
    hum:MoveTo(hrp.Position)
    return true
end

local function loot_cycle()
    local my_gen = LOOT_GEN
    local prompt = nearest_prompt()
    if not prompt then return false end
    local part = prompt_part(prompt)
    if not part then return false end

    local arrived = walk_to(part, my_gen)
    if my_gen ~= LOOT_GEN or not STATE.AUTO_LOOT then
        restore_walkspeed()
        return false
    end
    if not arrived then
        restore_walkspeed()
        return false
    end

    restore_walkspeed()

    local pre = CONFIG.PRE_PROMPT_DELAY_MIN
        + math.random() * (CONFIG.PRE_PROMPT_DELAY_MAX - CONFIG.PRE_PROMPT_DELAY_MIN)
    task.wait(pre)
    if my_gen ~= LOOT_GEN or not STATE.AUTO_LOOT then return false end

    if prompt.Parent then
        pcall(function()
            prompt.RequiresLineOfSight = false
            prompt.MaxActivationDistance = 9e9
        end)
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.05)
            prompt:InputHoldEnd()
        end)
    end
    return true
end

task.spawn(function()
    while task.wait(0.5) do
        if STATE.AUTO_LOOT and in_royale() then
            pcall(loot_cycle)
            restore_walkspeed()

            local wait_for = CONFIG.LOOT_COOLDOWN
                + (math.random() * 2 - 1) * CONFIG.LOOT_JITTER
            local t0 = tick()
            while (tick() - t0) < wait_for do
                if not STATE.AUTO_LOOT then break end
                task.wait(0.1)
            end
        end
    end
end)

-- aura
local function make_aura()
    if AURA_PART then return end
    local part = Instance.new("Part")
    part.Size = Vector3.new(2, 2, 2)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Name = "_oll_aura_anchor"
    part.Parent = Workspace
    local att = Instance.new("Attachment")
    att.Parent = part
    local aura = Instance.new("ParticleEmitter")
    aura.Texture = CONFIG.AURA_TEXTURE_ID
    aura.Rate = 20
    aura.Lifetime = NumberRange.new(0.5)
    aura.Speed = NumberRange.new(0)
    aura.Parent = att
    AURA_PART = part
end

local function park_aura()
    if AURA_PART then AURA_PART.CFrame = CFrame.new(0, CONFIG.AURA_PARK_HEIGHT, 0) end
end

local function follow_aura()
    if not AURA_PART then return end
    local hrp = get_hrp()
    if hrp then AURA_PART.CFrame = hrp.CFrame end
end

LP.CharacterAdded:Connect(function()
    task.wait(1)
    SAVED_WALKSPEED = nil
    if STATE.SLAP_AURA then apply_expander() end
end)

RunService.RenderStepped:Connect(function()
    if STATE.ESP_PLAYERS then pcall(update_player_esp) end
    if STATE.ESP_ITEMS   then pcall(update_item_esp) end
    if STATE.HIDE_AURA then
        make_aura()
        if in_royale() then follow_aura() else park_aura() end
    end
    if STATE.SLAP_AURA then pcall(apply_expander) end
end)

-- UI
local COLORS = {
    bg       = Color3.fromRGB(18, 18, 22),
    panel    = Color3.fromRGB(26, 26, 32),
    row      = Color3.fromRGB(36, 36, 44),
    rowHov   = Color3.fromRGB(46, 46, 56),
    accent   = Color3.fromRGB(0, 200, 120),
    accentOff= Color3.fromRGB(60, 60, 70),
    text     = Color3.fromRGB(230, 230, 235),
    textDim  = Color3.fromRGB(130, 130, 140),
    track    = Color3.fromRGB(45, 45, 54),
    hud      = Color3.fromRGB(0, 255, 140),
    danger   = Color3.fromRGB(200, 70, 70),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "_oll_ui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 260, 0, 460)
panel.Position = UDim2.new(0, 20, 0, 20)
panel.BackgroundColor3 = COLORS.bg
panel.BorderSizePixel = 0
panel.Parent = ScreenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(50, 50, 60)
stroke.Thickness = 1
stroke.Parent = panel

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = COLORS.panel
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 12)
titleFix.Position = UDim2.new(0, 0, 1, -12)
titleFix.BackgroundColor3 = COLORS.panel
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "ollie  •  slap"
titleLabel.TextColor3 = COLORS.text
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 24, 0, 24)
minBtn.Position = UDim2.new(1, -56, 0, 5)
minBtn.BackgroundColor3 = COLORS.row
minBtn.Text = "–"
minBtn.TextColor3 = COLORS.text
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.BorderSizePixel = 0
minBtn.Parent = titleBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "×"
closeBtn.TextColor3 = COLORS.text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -12, 1, -46)
content.Position = UDim2.new(0, 6, 0, 40)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = COLORS.accent
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local function section(text)
    local h = Instance.new("TextLabel")
    h.Size = UDim2.new(1, -8, 0, 22)
    h.BackgroundTransparency = 1
    h.Text = text
    h.TextColor3 = COLORS.textDim
    h.Font = Enum.Font.GothamBold
    h.TextSize = 10
    h.TextXAlignment = Enum.TextXAlignment.Left
    h.Parent = content
    return h
end

local function toggle_row(text, key, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 34)
    row.BackgroundColor3 = COLORS.row
    row.BorderSizePixel = 0
    row.Parent = content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = COLORS.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local swTrack = Instance.new("Frame")
    swTrack.Size = UDim2.new(0, 38, 0, 20)
    swTrack.Position = UDim2.new(1, -50, 0.5, -10)
    swTrack.BackgroundColor3 = COLORS.accentOff
    swTrack.BorderSizePixel = 0
    swTrack.Parent = row
    Instance.new("UICorner", swTrack).CornerRadius = UDim.new(1, 0)

    local swKnob = Instance.new("Frame")
    swKnob.Size = UDim2.new(0, 16, 0, 16)
    swKnob.Position = UDim2.new(0, 2, 0.5, -8)
    swKnob.BackgroundColor3 = COLORS.text
    swKnob.BorderSizePixel = 0
    swKnob.Parent = swTrack
    Instance.new("UICorner", swKnob).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row

    local on = false
    local function set(v)
        on = v
        STATE[key] = v
        TweenService:Create(swTrack, TweenInfo.new(0.15), {
            BackgroundColor3 = v and COLORS.accent or COLORS.accentOff
        }):Play()
        TweenService:Create(swKnob, TweenInfo.new(0.15), {
            Position = v and UDim2.new(0, 20, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        if callback then callback(v) end
    end
    btn.MouseButton1Click:Connect(function()
        set(not on)
        if not on and key == "AUTO_LOOT" then
            LOOT_GEN = LOOT_GEN + 1
            local hum = get_humanoid()
            local hrp = get_hrp()
            if hum and hrp then hum:MoveTo(hrp.Position) end
            restore_walkspeed()
        end
    end)
    btn.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.1), { BackgroundColor3 = COLORS.rowHov }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.1), { BackgroundColor3 = COLORS.row }):Play()
    end)

    return { row = row, set = set, get = function() return on end }
end

local function action_row(text, callback, danger)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -8, 0, 30)
    row.BackgroundColor3 = danger and COLORS.danger or COLORS.row
    row.Text = text
    row.TextColor3 = COLORS.text
    row.Font = Enum.Font.GothamBold
    row.TextSize = 12
    row.BorderSizePixel = 0
    row.Parent = content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    row.MouseButton1Click:Connect(callback)
    return row
end

local function slider_row(text, min, max, initial, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 54)
    row.BackgroundColor3 = COLORS.row
    row.BorderSizePixel = 0
    row.Parent = content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = COLORS.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(1, -12, 0, 20)
    valLbl.Position = UDim2.new(0, 12, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(initial) .. "x"
    valLbl.TextColor3 = COLORS.accent
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 13
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 6)
    track.Position = UDim2.new(0, 12, 0, 38)
    track.BackgroundColor3 = COLORS.track
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = COLORS.accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, -7, 0.5, -7)
    knob.BackgroundColor3 = COLORS.text
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local value = initial
    local locked = false

    local function refresh()
        local pct = (value - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -7, 0.5, -7)
        valLbl.Text = value .. "x"
    end
    refresh()

    local dragging = false
    local function from_x(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(rel * (max - min) + 0.5) + min
        refresh()
        if callback and not locked then callback(value) end
    end

    knob.InputBegan:Connect(function(input)
        if locked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    fill.InputBegan:Connect(function(input)
        if locked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch) then
            from_x(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local api = {}
    function api.set_locked(v)
        locked = v
        TweenService:Create(track, TweenInfo.new(0.15), { BackgroundTransparency = v and 0.5 or 0 }):Play()
        fill.BackgroundTransparency = v and 0.6 or 0
        knob.BackgroundTransparency = v and 0.5 or 0
        lbl.TextTransparency = v and 0.4 or 0
        valLbl.TextTransparency = v and 0.4 or 0
    end
    function api.reset(v)
        value = v
        refresh()
    end
    return api
end

section("COMBAT")

local slapAuraApi
toggle_row("Slap Aura", "SLAP_AURA", function(v)
    if v then
        if slapAuraApi then slapAuraApi.set_locked(false) end
        apply_expander()
    else
        if slapAuraApi then slapAuraApi.set_locked(true) slapAuraApi.reset(1) end
        STATE.EXPANDER = 1
        apply_expander()
    end
end)

slapAuraApi = slider_row("Hitbox Expander", 1, CONFIG.SLIDER_MAX, 1, function(v)
    STATE.EXPANDER = v
    apply_expander()
end)
slapAuraApi.set_locked(true)

section("LOOT")

local lootToggle
lootToggle = toggle_row("Auto Loot  (walk + collect)", "AUTO_LOOT")

action_row("Stop Looting", function()
    LOOT_GEN = LOOT_GEN + 1
    STATE.AUTO_LOOT = false
    if lootToggle then lootToggle.set(false) end
    local hum = get_humanoid()
    local hrp = get_hrp()
    if hum and hrp then hum:MoveTo(hrp.Position) end
    restore_walkspeed()
end, true)

section("ESP")

toggle_row("Player ESP  (name + glove)", "ESP_PLAYERS")
toggle_row("Item ESP  (name label)",      "ESP_ITEMS")

section("MISC")

toggle_row("Hide Aura Above Lobby", "HIDE_AURA")

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -8, 0, 20)
footer.BackgroundTransparency = 1
footer.Text = "ready."
footer.TextColor3 = COLORS.textDim
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.Parent = content

task.spawn(function()
    while task.wait(0.5) do
        local live = {}
        for k, v in pairs(STATE) do
            if v and v ~= false and v ~= 1 then table.insert(live, k) end
        end
        footer.Text = #live == 0 and "ready." or ("live: " .. table.concat(live, ", "))
    end
end)

local minimized = false
local fullSize = panel.Size
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        content.Visible = false
        panel.Size = UDim2.new(0, 260, 0, 34)
    else
        content.Visible = true
        panel.Size = fullSize
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    LOOT_GEN = LOOT_GEN + 1
    STATE.AUTO_LOOT = false
    local hum = get_humanoid()
    local hrp = get_hrp()
    if hum and hrp then hum:MoveTo(hrp.Position) end
    restore_walkspeed()
    for _, d in pairs(playerDrawings) do
        for _, o in pairs(d) do pcall(function() o:Remove() end) end
    end
    for _, d in pairs(itemDrawings) do
        for _, o in pairs(d) do pcall(function() o:Remove() end) end
    end
    if AURA_PART then pcall(function() AURA_PART:Destroy() end) end
    ScreenGui:Destroy()
end)

local dragging, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(input)
   
