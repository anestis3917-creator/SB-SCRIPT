-- slap.lua — MINIMAL TEST BUILD
-- proves the UI renders before adding features

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

print("STEP 1: script started")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "_oll_test"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LP:WaitForChild("PlayerGui")
print("STEP 2: ScreenGui created")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 260, 0, 300)
panel.Position = UDim2.new(0, 20, 0, 20)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.BorderSizePixel = 0
panel.Parent = ScreenGui
print("STEP 3: panel created")

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 34)
title.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
title.Text = "ollie  •  slap"
title.TextColor3 = Color3.fromRGB(230, 230, 235)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.BorderSizePixel = 0
title.Parent = panel
print("STEP 4: title created")

local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 10)
tc.Parent = title

local testBtn = Instance.new("TextButton")
testBtn.Size = UDim2.new(1, -20, 0, 40)
testBtn.Position = UDim2.new(0, 10, 0, 50)
testBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
testBtn.Text = "if you see this, it works"
testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
testBtn.Font = Enum.Font.GothamBold
testBtn.TextSize = 13
testBtn.BorderSizePixel = 0
testBtn.Parent = panel
print("STEP 5: button created")

local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 6)
bc.Parent = testBtn

print("STEP 6: DONE — panel should be visible")
