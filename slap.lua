-- slap.lua — v8 (UI-first, defensive, feature-complete)
-- usage: loadstring(game:HttpGet("URL?v="..tick()))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local LP = Players.LocalPlayer

local CONFIG = {
    PROMPT_PARENT_PATTERNS = {
        "crate", "box", "loot", "barrel", "chest", "supply", "apple", "banana",
    },
    ROYALE_MARKER_NAME = "Arena",
    AURA_TEXTURE_ID    = "rbxassetid://0",
    AURA_PARK_HEIGHT   = 5000,
    LOOT_COOLDOWN      = 3.0,
    LOOT_JITTER        = 0.5,
    LOOT_RANGE         = 500,
    WALK_TIMEOUT       = 8.0,
    ARRIVE_DISTANCE    = 6,
    LOOT_WALKSPEED     = 32,
    ESP_RANGE          = 2000,
    BASE_HITBOX        = 5,
    SLIDER_MAX         = 10,
}

local STATE = {
    AUTO_LOOT   = false,
    ESP_PLAYERS = false,
    ESP_ITEMS   = false,
    HIDE_AURA   = false,
    HIDE_LOBBY  = false,
    SLAP_AURA   = false,
    EXPANDER    = 1,
}

local AURA_PART = nil
local LOOT_GEN  = 0
local SAVED_WALKSPEED = nil

-- ============================ helpers ============================
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
end

-- ============================ UI (BUILT FIRST) ============================
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
    danger   = Color3.fromRGB(200, 70, 70),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "_oll_ui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 260, 0, 500)
panel.Position = UDim2.new(0, 20, 0, 20)
panel.BackgroundColor3 = COLORS.bg
panel.BorderSizePixel = 0
panel.Parent = ScreenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = COLORS.panel
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

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

print("v8: UI shell built")

-- ============================ widgets ============================
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

    local function start_drag(input)
        if locked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end
    knob.InputBegan:Connect(start_drag)
    fill.InputBegan:Connect(start_drag)

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

print("v8: widgets defined")
