-- slap.lua — v8.3 (Tool-based loot, rarity-colored item ESP, fixed panel)
-- usage: loadstring(game:HttpGet("URL?v="..tick()))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

local CONFIG = {
    BUS_MARKER_NAME    = "BusModel",
    ITEMS_FOLDER_NAME  = "Items",
    AURA_TEXTURE_ID    = "rbxassetid://0",
    AURA_PARK_HEIGHT   = 5000,
    LOOT_COOLDOWN      = 3.0,
    LOOT_JITTER        = 0.5,
    LOOT_RANGE         = 500,
    ESP_RANGE          = 5000,
    BASE_HITBOX        = 5,
    SLIDER_MAX         = 10,
    DEFAULT_ITEM_COLOR = Color3.fromRGB(90, 255, 130),
     ITEM_RARITY = {
        -- Common (Grey / White)
        ["apple"]               = Color3.fromRGB(220, 220, 220),
        ["bull's essence"]      = Color3.fromRGB(220, 220, 220),
        ["cube of ice"]         = Color3.fromRGB(220, 220, 220),
        
        -- Uncommon (Green)
        ["healing potion"]      = Color3.fromRGB(80, 255, 100),
        
        -- Rare (Blue)
        ["bandage"]             = Color3.fromRGB(80, 160, 255),
        ["forcefield crystal"]  = Color3.fromRGB(80, 160, 255),
        ["bomb"]                = Color3.fromRGB(80, 160, 255),
        ["frog potion"]         = Color3.fromRGB(80, 160, 255),
        
        -- Epic (Purple)
        ["first aid kit"]       = Color3.fromRGB(200, 80, 255),
        ["boba"]                = Color3.fromRGB(200, 80, 255),
        ["potion of strength"]  = Color3.fromRGB(200, 80, 255),
        ["sphere of fury"]      = Color3.fromRGB(200, 80, 255),
        
        -- Legendary (Yellow)
        ["healing potion"]      = Color3.fromRGB(255, 230, 60),
        ["speed potion"]        = Color3.fromRGB(255, 230, 60),
        ["lightning potion"]    = Color3.fromRGB(255, 230, 60),
        
        -- Godly / Mythical (Red)
        ["true power"]          = Color3.fromRGB(255, 80, 80),
    },

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
local gloveCache = {}
local playerDrawings, itemDrawings = {}, {}
local itemScanAccum = 0

local function get_hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function detect_bus()
    return Workspace:FindFirstChild(CONFIG.BUS_MARKER_NAME) ~= nil
end

local function get_items_folder()
    return Workspace:FindFirstChild(CONFIG.ITEMS_FOLDER_NAME)
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

local COLORS = {
    bg       = Color3.fromRGB(18, 18, 22),
    panel    = Color3.fromRGB(26, 26, 32),
    row      = Color3.fromRGB(36, 36, 44),
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
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 260, 0, 500)
panel.Position = UDim2.new(0, 20, 0, 20)
panel.BackgroundColor3 = COLORS.bg
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = ScreenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = COLORS.panel
titleBar.BorderSizePixel = 0
titleBar.Active = true
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

local dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = input.Position
        startPos = panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement
                      or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = nil
    end
end)

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
        if not on and key == "AUTO_LOOT" then LOOT_GEN = LOOT_GEN + 1 end
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
    local dragging = false

    local function refresh()
        local pct = (value - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -7, 0.5, -7)
        valLbl.Text = value .. "x"
    end
    refresh()

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

    return {
        set_locked = function(v)
            locked = v
            fill.BackgroundTransparency = v and 0.6 or 0
            knob.BackgroundTransparency = v and 0.5 or 0
            lbl.TextTransparency = v and 0.4 or 0
            valLbl.TextTransparency = v and 0.4 or 0
        end,
        reset = function(v) value = v refresh() end,
    }
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
lootToggle = toggle_row("Auto Loot", "AUTO_LOOT")

local lootRow = lootToggle.row
local lootBtn = lootRow:FindFirstChildOfClass("TextButton")
local lootLbl = lootRow:FindFirstChildOfClass("TextLabel")
local lootLocked = true

local function set_loot_locked(v)
    lootLocked = v
    if lootBtn then
        lootBtn.Active = not v
        lootBtn.AutoButtonColor = not v
    end
    if lootLbl then lootLbl.TextTransparency = v and 0.5 or 0 end
end
set_loot_locked(true)

task.spawn(function()
    while task.wait(0.25) do
        local onBus = detect_bus()
        if onBus and lootLocked then
            set_loot_locked(false)
        elseif not onBus and not lootLocked then
            set_loot_locked(true)
            if STATE.AUTO_LOOT then
                lootToggle.set(false)
                LOOT_GEN = LOOT_GEN + 1
            end
        end
    end
end)

action_row("Stop Looting", function()
    LOOT_GEN = LOOT_GEN + 1
    STATE.AUTO_LOOT = false
    if lootToggle then lootToggle.set(false) end
end, true)

section("ESP")
toggle_row("Player ESP", "ESP_PLAYERS", function(v)
    if not v then
        for _, d in pairs(playerDrawings) do
            for _, o in pairs(d) do pcall(function() o.Visible = false end) end
        end
    end
end)
toggle_row("Item ESP", "ESP_ITEMS", function(v)
    if not v then
        for _, d in pairs(itemDrawings) do
            if d.label then pcall(function() d.label.Visible = false end) end
            if d.box then pcall(function() d.box.Visible = false end) end
        end
    end
end)

section("MISC")
toggle_row("Hide Aura Above Lobby", "HIDE_AURA")
toggle_row("Hide Above Waiting Lobby", "HIDE_LOBBY")

print("v8.3: sections built")

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

local function new_box(color)
    local b = Drawing.new("Square")
    b.Thickness = 1
    b.Filled = false
    b.Color = color
    b.Visible = false
    return b
end

local function get_glove(p)
    if gloveCache[p] then return gloveCache[p] end
    local candidates = {
        p:FindFirstChild("Glove"),
        p:FindFirstChild("EquippedGlove"),
        p:FindFirstChild("CurrentGlove"),
        p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Glove"),
    }
    local result = "?"
    for _, c in ipairs(candidates) do
        if c and (c:IsA("StringValue") or c:IsA("ValueBase")) then
            result = tostring(c.Value)
            break
        end
    end
    if result == "?" then
        local char = p.Character
        if char then
            for _, c in ipairs(char:GetChildren()) do
                if c:IsA("Tool") then result = c.Name break end
            end
        end
    end
    gloveCache[p] = result
    return result
end

local function update_item_esp()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local my_hrp = get_hrp()
    local my_pos = my_hrp and my_hrp.Position
    if not my_pos then return end
    local folder = get_items_folder()
    if not folder then
        for _, d in pairs(itemDrawings) do
            if d.label then d.label.Visible = false end
            if d.box then d.box.Visible = false end
        end
        return
    end
    local seen = {}
    
    for _, tool in ipairs(folder:GetChildren()) do
        if tool:IsA("Tool") then
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                local dist = (handle.Position - my_pos).Magnitude
                if dist <= CONFIG.ESP_RANGE then
                    
                    local sp, on = cam:WorldToViewportPoint(handle.Position)
                    if on then
                        local nameLower = tool.Name:lower()
                        local col = CONFIG.ITEM_RARITY[nameLower] or CONFIG.DEFAULT_ITEM_COLOR
                        
                        seen[tool] = true
                        
                        if not itemDrawings[tool] then
                            local l = new_text(col)
                            l.Size = 14
                            local b = new_box(col)
                            b.Thickness = 2
                            itemDrawings[tool] = { label = l, box = b }
                        end
                        
                        local d = itemDrawings[tool]
                        
                        -- Force color update every frame
                        d.label.Color = col
                        d.box.Color = col
                        
                        local cf = handle.CFrame
                        local size = handle.Size
                        local half = size / 2
                        
                        local posTop = cf * CFrame.new(0, half.Y, 0)
                        local posBot = cf * CFrame.new(0, -half.Y, 0)
                        
                        local spTop, onTop = cam:WorldToViewportPoint(posTop.Position)
                        local spBot, onBot = cam:WorldToViewportPoint(posBot.Position)
                        
                        if onTop and onBot then
                            local h = math.abs(spBot.Y - spTop.Y)
                            local w = h * 0.8
                            local boxTop = math.min(spTop.Y, spBot.Y)
                            
                            d.box.Size = Vector2.new(w, h)
                            d.box.Position = Vector2.new(spTop.X - w/2, boxTop)
                            d.box.Visible = true
                            
                            d.label.Text = tool.Name
                            d.label.Position = Vector2.new(spTop.X, boxTop - 16)
                            d.label.Visible = true
                        end
                    end
                end
            end
        end
    end
    for tool, d in pairs(itemDrawings) do
        if not seen[tool] or not tool.Parent then
            if d.label then pcall(function() d.label:Remove() end) end
            if d.box then pcall(function() d.box:Remove() end) end
            itemDrawings[tool] = nil
        end
    end
end
    local seen = {}
    
    for _, tool in ipairs(folder:GetChildren()) do
        if tool:IsA("Tool") then
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                local dist = (handle.Position - my_pos).Magnitude
                if dist <= CONFIG.ESP_RANGE then
                    
                    local sp, on = cam:WorldToViewportPoint(handle.Position)
                    if on then
                        local col = item_color(tool.Name)
                        seen[tool] = true
                        
                        if not itemDrawings[tool] then
                            local l = new_text(col)
                            l.Size = 14
                            local b = new_box(col)
                            b.Thickness = 2
                            itemDrawings[tool] = { label = l, box = b }
                        end
                        
                        local d = itemDrawings[tool]
                        d.label.Color = col
                        d.box.Color = col
                        
                        -- Calculate real 3D corners of the handle
                        local cf = handle.CFrame
                        local size = handle.Size
                        local half = size / 2
                        
                        -- Top front and bottom back corners to get height
                        local posTop = cf * CFrame.new(0, half.Y, 0)
                        local posBot = cf * CFrame.new(0, -half.Y, 0)
                        
                        local spTop, onTop = cam:WorldToViewportPoint(posTop.Position)
                        local spBot, onBot = cam:WorldToViewportPoint(posBot.Position)
                        
                        if onTop and onBot then
                            local h = math.abs(spBot.Y - spTop.Y)
                            local w = h * 0.8
                            
                            local boxTop = math.min(spTop.Y, spBot.Y)
                            
                            d.box.Size = Vector2.new(w, h)
                            d.box.Position = Vector2.new(spTop.X - w/2, boxTop)
                            d.box.Visible = true
                            
                            d.label.Text = tool.Name
                            d.label.Position = Vector2.new(spTop.X, boxTop - 16)
                            d.label.Visible = true
                        end
                    end
                end
            end
        end
    end
    for tool, d in pairs(itemDrawings) do
        if not seen[tool] or not tool.Parent then
            if d.label then pcall(function() d.label:Remove() end) end
            if d.box then pcall(function() d.box:Remove() end) end
            itemDrawings[tool] = nil
        end
    end
end
local function item_color(name)
    local lower = name:lower()
    return CONFIG.ITEM_RARITY[lower] or CONFIG.DEFAULT_ITEM_COLOR
end

local function update_item_esp()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local my_hrp = get_hrp()
    local my_pos = my_hrp and my_hrp.Position
    if not my_pos then return end
    local folder = get_items_folder()
    if not folder then
        for _, d in pairs(itemDrawings) do
            if d.label then d.label.Visible = false end
            if d.box then d.box.Visible = false end
        end
        return
    end
    local seen = {}
    for _, tool in ipairs(folder:GetChildren()) do
        if tool:IsA("Tool") then
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                local dist = (handle.Position - my_pos).Magnitude
                if dist <= CONFIG.ESP_RANGE then
                    local sp, on = cam:WorldToViewportPoint(handle.Position + Vector3.new(0, 2, 0))
                    if on then
                        local col = item_color(tool.Name)
                        seen[tool] = true
                        if not itemDrawings[tool] then
                            itemDrawings[tool] = {
                                label = new_text(col),
                                box = new_box(col),
                            }
                        end
                        local d = itemDrawings[tool]
                        d.label.Color = col
                        d.box.Color = col
                        local spTop = cam:WorldToViewportPoint(handle.Position + Vector3.new(0, 2.5, 0))
                        local spBot = cam:WorldToViewportPoint(handle.Position - Vector3.new(0, 2.5, 0))
                        if spTop and spBot then
                            local h = math.abs(spBot.Y - spTop.Y)
                            local w = h * 0.7
                            d.box.Size = Vector2.new(w, h)
                            d.box.Position = Vector2.new(sp.X - w/2, spTop.Y)
                            d.box.Visible = true
                        end
                        d.label.Text = tool.Name
                        d.label.Position = Vector2.new(sp.X, sp.Y - 20)
                        d.label.Visible = true
                    end
                end
            end
        end
    end
    for tool, d in pairs(itemDrawings) do
        if not seen[tool] or not tool.Parent then
            if d.label then pcall(function() d.label:Remove() end) end
            if d.box then pcall(function() d.box:Remove() end) end
            itemDrawings[tool] = nil
        end
    end
end

local function nearest_tool()
    local folder = get_items_folder()
    if not folder then return nil end
    local hrp = get_hrp()
    if not hrp then return nil end
    local my_pos = hrp.Position
    local best, best_dist = nil, CONFIG.LOOT_RANGE
    for _, tool in ipairs(folder:GetChildren()) do
        if tool:IsA("Tool") then
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                local d = (handle.Position - my_pos).Magnitude
                if d < best_dist then best_dist = d best = tool end
            end
        end
    end
    return best, best_dist
end

local function loot_cycle()
    local my_gen = LOOT_GEN
    local tool = nearest_tool()
    if not tool then return false end
    local handle = tool:FindFirstChild("Handle")
    if not handle then return false end
    
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- Fly to the item smoothly
    local startPos = hrp.Position
    local targetPos = handle.Position + Vector3.new(0, 3, 0)
    local distance = (startPos - targetPos).Magnitude
    
    -- speed: roughly 75 studs per second (fast but not instant)
    local speed = 75
    local timeToTake = distance / speed
    local t0 = tick()
    
    while (tick() - t0) < timeToTake do
        if my_gen ~= LOOT_GEN or not STATE.AUTO_LOOT then return false end
        local alpha = (tick() - t0) / timeToTake
        if alpha > 1 then alpha = 1 end
        
        hrp.CFrame = CFrame.new(startPos:Lerp(targetPos, alpha))
        task.wait()
    end
    
    hrp.CFrame = CFrame.new(targetPos)
    
    -- wait for game to register touch/pickup
    task.wait(0.2)
    if my_gen ~= LOOT_GEN or not STATE.AUTO_LOOT then return false end
    
    return true
end
task.spawn(function()
    while task.wait(0.5) do
        if STATE.AUTO_LOOT and not detect_bus() then
            pcall(loot_cycle)
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
                    local spTop, onTop = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0))
                    local spBot, onBot = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                    
                    if onTop and onBot then
                        if not playerDrawings[p] then
                            playerDrawings[p] = {
                                name = new_text(Color3.fromRGB(255, 255, 255)),
                                glove = new_text(Color3.fromRGB(200, 200, 200)),
                                box = new_box(Color3.fromRGB(255, 255, 255)),
                            }
                        end
                        local d = playerDrawings[p]
                        
                        local h = math.abs(spBot.Y - spTop.Y)
                        local w = h * 0.4
                        local boxTop = math.min(spTop.Y, spBot.Y)
                        
                        d.box.Size = Vector2.new(w, h)
                        d.box.Position = Vector2.new(spTop.X - w/2, boxTop)
                        d.box.Visible = true
                        
                        d.name.Text = p.Name
                        d.name.Position = Vector2.new(spTop.X, boxTop - 16)
                        d.name.Visible = true
                        
                        d.glove.Text = get_glove(p)
                        d.glove.Position = Vector2.new(spTop.X, boxTop + h + 2)
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
RunService.RenderStepped:Connect(function()
    if STATE.ESP_PLAYERS then pcall(update_player_esp) end

    if STATE.ESP_ITEMS then
        itemScanAccum = itemScanAccum + 1
        if itemScanAccum >= 1 then
            itemScanAccum = 0
            pcall(update_item_esp)
        end
    end

    if STATE.HIDE_AURA or STATE.HIDE_LOBBY then
        make_aura()
        if STATE.HIDE_LOBBY then park_aura() else follow_aura() end
    end

    if STATE.SLAP_AURA then pcall(apply_expander) end
end)

minBtn.MouseButton1Click:Connect(function()
    if content.Visible then
        content.Visible = false
        panel.Size = UDim2.new(0, 260, 0, 34)
    else
        content.Visible = true
        panel.Size = UDim2.new(0, 260, 0, 500)
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    LOOT_GEN = LOOT_GEN + 1
    STATE.AUTO_LOOT = false
    for _, d in pairs(playerDrawings) do
        for _, o in pairs(d) do pcall(function() o:Remove() end) end
    end
    for _, d in pairs(itemDrawings) do
        if d.label then pcall(function() d.label:Remove() end) end
        if d.box then pcall(function() d.box:Remove() end) end
    end
    if AURA_PART then pcall(function() AURA_PART:Destroy() end) end
    ScreenGui:Destroy()
end)

LP.CharacterAdded:Connect(function()
    gloveCache[LP] = nil
    task.wait(1)
    if STATE.SLAP_AURA then apply_expander() end
end)

Players.PlayerRemoving:Connect(function(p)
    gloveCache[p] = nil
end)

print("v8.3: features live")

print("v8.3: widgets ready")
