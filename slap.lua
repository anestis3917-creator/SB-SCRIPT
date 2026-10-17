-- slap.lua — v19.4 (Pure Velocity Freeze)
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local LP                = Players.LocalPlayer

local STATE = {
    ESP_PLAYERS = false,
    ESP_ITEMS   = false,
    ANTI_SLAP   = false,
}

local antiSlapConnection = nil

local function get_hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

-- ================= ANTI-SLAP =================
local function toggle_anti_slap(on)
    if antiSlapConnection then
        antiSlapConnection:Disconnect()
        antiSlapConnection = nil
        local char = LP.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end

    if not on then return end

    antiSlapConnection = RunService.Heartbeat:Connect(function()
        local char = LP.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        -- Glove check: if no tool, you are slapped/ragdolled
        local tool = char:FindFirstChildOfClass("Tool")
        local isSlapped = (tool == nil) 

        if isSlapped then
            -- Kill velocity ONLY. Do not anchor.
            hrp.Velocity = Vector3.new(0, 0, 0)
            hum.WalkSpeed = 0
        else
            -- Unfreeze
            if hum.WalkSpeed == 0 then
                hum.WalkSpeed = 16
            end
        end
    end)
end

-- ================= UI =================
local COLORS = {
    bg = Color3.fromRGB(18, 18, 22), panel = Color3.fromRGB(26, 26, 32), row = Color3.fromRGB(36, 36, 44),
    accent = Color3.fromRGB(0, 200, 120), accentOff = Color3.fromRGB(60, 60, 70), text = Color3.fromRGB(230, 230, 235),
    textDim = Color3.fromRGB(130, 130, 140), track = Color3.fromRGB(45, 45, 54), danger = Color3.fromRGB(200, 70, 70),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "_oll_ui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 260, 0, 440)
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
titleLabel.Text = "ollie  •  slap v19.4"
titleLabel.TextColor3 = COLORS.text
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "x"
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
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = input.Position
        startPos = panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragStart = nil end
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
        TweenService:Create(swTrack, TweenInfo.new(0.15), {BackgroundColor3 = v and COLORS.accent or COLORS.accentOff}):Play()
        TweenService:Create(swKnob, TweenInfo.new(0.15), {Position = v and UDim2.new(0, 20, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
        if callback then callback(v) end
    end
    btn.MouseButton1Click:Connect(function() set(not on) end)
    return { row = row, set = set, get = function() return on end }
end

section("COMBAT")
toggle_row("Anti-Slap (Velocity)", "ANTI_SLAP", function(v) toggle_anti_slap(v) end)

section("ESP")
toggle_row("Player ESP", "ESP_PLAYERS", function(v) if not v then for _, d in pairs(playerDrawings) do for _, o in pairs(d) do pcall(function() o.Visible = false end) end end end end)
toggle_row("Item ESP", "ESP_ITEMS", function(v) if not v then for _, d in pairs(itemDrawings) do if d.label then pcall(function() d.label.Visible = false end) end if d.box then pcall(function() d.box.Visible = false end) end end end end)

-- ================= ESP DRAWING =================
local playerDrawings, itemDrawings = {}, {}
local gloveCache = {}
local CONFIG = {
    ITEMS_FOLDER_NAME = "Items",
    ESP_RANGE = 2500,
    DEFAULT_ITEM_COLOR = Color3.fromRGB(90, 255, 130),
    ITEM_RARITY = {
        ["apple"]              = Color3.fromRGB(220, 220, 220),
        ["healing potion"]     = Color3.fromRGB(80, 255, 100),
        ["bandage"]            = Color3.fromRGB(80, 160, 255),
        ["forcefield crystal"] = Color3.fromRGB(80, 160, 255),
        ["bomb"]               = Color3.fromRGB(80, 160, 255),
        ["first aid kit"]      = Color3.fromRGB(200, 80, 255),
        ["boba"]               = Color3.fromRGB(200, 80, 255),
        ["potion of strength"] = Color3.fromRGB(200, 80, 255),
        ["speed potion"]       = Color3.fromRGB(255, 230, 60),
        ["true power"]         = Color3.fromRGB(255, 80, 80),
    },
}

local function get_items_folder()
    return Workspace:FindFirstChild(CONFIG.ITEMS_FOLDER_NAME)
end

local function item_color(name)
    return CONFIG.ITEM_RARITY[name:lower()] or CONFIG.DEFAULT_ITEM_COLOR
end

local function new_text(color) local t = Drawing.new("Text") t.Size = 16 t.Center = true t.Outline = true t.OutlineColor = Color3.new(0, 0, 0) t.Font = 2 t.Color = color t.Visible = false return t end
local function new_box(color) local b = Drawing.new("Square") b.Thickness = 1 b.Filled = false b.Color = color b.Visible = false return b end

local function get_glove(p)
    if gloveCache[p] then return gloveCache[p] end
    local result = "?" 
    local c = p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Glove")
    if c then result = tostring(c.Value) else local char = p.Character if char then for _, v in ipairs(char:GetChildren()) do if v:IsA("Tool") then result = v.Name break end end end end
    gloveCache[p] = result return result
end

local function update_player_esp()
    local cam = Workspace.CurrentCamera if not cam then return end
    local my_hrp = get_hrp() local my_pos = my_hrp and my_hrp.Position
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local char = p.Character local hrp = char and char:FindFirstChild("HumanoidRootPart") local head = char and char:FindFirstChild("Head") local hum = char and char:FindFirstChildOfClass("Humanoid")
            local vis = false
            if hrp and head and hum and hum.Health > 0 then
                local dist = my_pos and (hrp.Position - my_pos).Magnitude or 0
                if dist <= CONFIG.ESP_RANGE then
                    local spTop, onTop = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0))
                    local spBot, onBot = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                    if onTop and onBot then
                        if not playerDrawings[p] then playerDrawings[p] = {name = new_text(Color3.fromRGB(255, 255, 255)), glove = new_text(Color3.fromRGB(200, 200, 200)), box = new_box(Color3.fromRGB(255, 255, 255))} end
                        local d = playerDrawings[p] local h = math.abs(spBot.Y - spTop.Y) local w = h * 0.4 local boxTop = math.min(spTop.Y, spBot.Y)
                        d.box.Size = Vector2.new(w, h) d.box.Position = Vector2.new(spTop.X - w/2, boxTop) d.box.Visible = true
                        d.name.Text = p.Name d.name.Position = Vector2.new(spTop.X, boxTop - 16) d.name.Visible = true
                        d.glove.Text = get_glove(p) d.glove.Position = Vector2.new(spTop.X, boxTop + h + 2) d.glove.Visible = true
                        vis = true
                    end
                end
            end
            if not vis and playerDrawings[p] then for _, o in pairs(playerDrawings[p]) do o.Visible = false end end
        end
    end
end

local function update_item_esp()
    local cam = Workspace.CurrentCamera if not cam then return end
    local my_hrp = get_hrp() local my_pos = my_hrp and my_hrp.Position if not my_pos then return end
    local folder = get_items_folder() if not folder then for _, d in pairs(itemDrawings) do if d.label then d.label.Visible = false end if d.box then d.box.Visible = false end end return end
    local seen = {}
    for _, tool in ipairs(folder:GetChildren()) do
        if tool:IsA("Tool") then
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                local dist = (handle.Position - my_pos).Magnitude
                if dist <= CONFIG.ESP_RANGE then
                    local sp, on = cam:WorldToViewportPoint(handle.Position + Vector3.new(0, 2, 0))
                    if on then
                        local col = item_color(tool.Name) seen[tool] = true
                        if not itemDrawings[tool] then itemDrawings[tool] = {label = new_text(col), box = new_box(col)} end
                        local d = itemDrawings[tool] d.label.Color = col d.box.Color = col
                        local spTop = cam:WorldToViewportPoint(handle.Position + Vector3.new(0, 2.5, 0))
                        local spBot = cam:WorldToViewportPoint(handle.Position - Vector3.new(0, 2.5, 0))
                        if spTop and spBot then
                            local h = math.abs(spBot.Y - spTop.Y) local w = h * 0.7
                            d.box.Size = Vector2.new(w, h) d.box.Position = Vector2.new(sp.X - w/2, spTop.Y) d.box.Visible = true
                        end
                        d.label.Text = tool.Name d.label.Position = Vector2.new(sp.X, sp.Y - 20) d.label.Visible = true
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

RunService.RenderStepped:Connect(function()
    if STATE.ESP_PLAYERS then pcall(update_player_esp) end
    if STATE.ESP_ITEMS then pcall(update_item_esp) end
end)

closeBtn.MouseButton1Click:Connect(function()
    STATE.ANTI_SLAP = false
    if antiSlapConnection then antiSlapConnection:Disconnect() end
    for _, d in pairs(playerDrawings) do for _, o in pairs(d) do pcall(function() o:Remove() end) end end
    for _, d in pairs(itemDrawings) do if d.label then pcall(function() d.label:Remove() end) end if d.box then pcall(function() d.box:Remove() end) end end
    ScreenGui:Destroy()
end)

print("[ollie] slap v19.4 live.")
