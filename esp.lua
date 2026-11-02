local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local pumpkinEnabled = true
local doorEnabled = true

local pumpkinObjects = {}
local doorObjects = {}
local trackedPumpkins = {}
local trackedDoors = {}

for _, obj in pairs(Workspace:GetDescendants()) do
    if obj.Name == "Pumpkin_ESP" or obj.Name == "Pumpkin_Label"
    or obj.Name == "Door_ESP" or obj.Name == "Door_Label" then
        obj:Destroy()
    end
end
local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("PumpkinDoorESP_Gui")
if oldGui then oldGui:Destroy() end

local function createPumpkinESP(part)
    if not part or not part:IsA("BasePart") then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "Pumpkin_ESP"
    highlight.Adornee = part
    highlight.FillColor = Color3.fromRGB(255, 140, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = pumpkinEnabled
    highlight.Parent = part
    table.insert(pumpkinObjects, highlight)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Pumpkin_Label"
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 120, 0, 24)
    billboard.StudsOffset = Vector3.new(0, 1.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = pumpkinEnabled
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 140, 0)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    label.Text = "Pumpkin"
    label.Parent = billboard
    table.insert(pumpkinObjects, billboard)

    RunService.RenderStepped:Connect(function()
        if not part.Parent then return end
        if not pumpkinEnabled then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local dist = math.floor((root.Position - part.Position).Magnitude)
            label.Text = string.format("Pumpkin [%d]", dist)
        end
    end)
end

local function createDoorESP(doorModel)
    local frame = doorModel:FindFirstChild("Frame")
    if not frame or not frame:IsA("BasePart") then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "Door_ESP"
    highlight.Adornee = doorModel
    highlight.FillColor = Color3.fromRGB(255, 50, 50)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = doorEnabled
    highlight.Parent = doorModel
    table.insert(doorObjects, highlight)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Door_Label"
    billboard.Adornee = frame
    billboard.Size = UDim2.new(0, 150, 0, 24)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = doorEnabled
    billboard.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 50, 50)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    label.Text = "Door"
    label.Parent = billboard
    table.insert(doorObjects, billboard)

    local isVisited = false
    local function markVisited()
        if isVisited then return end
        isVisited = true
        highlight.FillColor = Color3.fromRGB(50, 255, 50)
        label.TextColor3 = Color3.fromRGB(50, 255, 50)
    end

    for _, d in ipairs(doorModel:GetDescendants()) do
        if d:IsA("ClickDetector") then
            d.MouseClick:Connect(function(player)
                if player == LocalPlayer then markVisited() end
            end)
        elseif d:IsA("ProximityPrompt") then
            d.Triggered:Connect(function(player)
                if player == LocalPlayer then markVisited() end
            end)
        end
    end

    RunService.RenderStepped:Connect(function()
        if not frame.Parent then return end
        if not doorEnabled then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local dist = math.floor((root.Position - frame.Position).Magnitude)
            if isVisited then
                label.Text = string.format("Visited [%d]", dist)
            else
                label.Text = string.format("Door [%d]", dist)
            end
        end
    end)
end

local function scanAll()
    if pumpkinEnabled then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("pumpkin") and not trackedPumpkins[obj] then
                if obj.Transparency < 0.9 then
                    local maxDim = math.max(obj.Size.X, obj.Size.Y, obj.Size.Z)
                    if maxDim <= 15 then
                        local isDuplicate = false
                        for trackedPart, _ in pairs(trackedPumpkins) do
                            if (trackedPart.Position - obj.Position).Magnitude < 1.5 then
                                isDuplicate = true
                                break
                            end
                        end

                        if not isDuplicate then
                            trackedPumpkins[obj] = true
                            createPumpkinESP(obj)
                        end
                    end
                end
            end
        end
    end

    if doorEnabled then
        local currentRoom = Workspace:FindFirstChild("CurrentRoom")
        local halloweenMap = currentRoom and currentRoom:FindFirstChild("HalloweenMap2")
        local doorsFolder = halloweenMap and halloweenMap:FindFirstChild("TrickOrTreatDoors")

        if doorsFolder then
            for _, doorModel in pairs(doorsFolder:GetChildren()) do
                if doorModel:IsA("Model") and doorModel:FindFirstChild("Frame") and not trackedDoors[doorModel] then
                    trackedDoors[doorModel] = true
                    createDoorESP(doorModel)
                end
            end
        end
    end
end

scanAll()
task.spawn(function()
    while task.wait(2) do
        scanAll()
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "PumpkinDoorESP_Gui"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 150, 0, 120)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 24)
title.BackgroundTransparency = 1
title.Text = "ESP Menu"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 14
title.Parent = frame

local function createToggleButton(posY, text, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 26)
    btn.Position = UDim2.new(0, 8, 0, posY)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 12
    btn.Parent = frame

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = btn
    return btn
end

local pumpkinBtn = createToggleButton(28, "Pumpkin: ON", Color3.fromRGB(200, 100, 0))
local doorBtn = createToggleButton(60, "Doors: ON", Color3.fromRGB(200, 40, 40))

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, 0, 0, 16)
footer.Position = UDim2.new(0, 0, 1, -20)
footer.BackgroundTransparency = 1
footer.Text = "made by 2od"
footer.TextColor3 = Color3.fromRGB(140, 140, 140)
footer.Font = Enum.Font.SourceSans
footer.TextSize = 12
footer.Parent = frame

pumpkinBtn.MouseButton1Click:Connect(function()
    pumpkinEnabled = not pumpkinEnabled
    pumpkinBtn.Text = "Pumpkin: " .. (pumpkinEnabled and "ON" or "OFF")
    pumpkinBtn.BackgroundColor3 = pumpkinEnabled and Color3.fromRGB(200, 100, 0) or Color3.fromRGB(60, 60, 60)
    for _, obj in ipairs(pumpkinObjects) do
        obj.Enabled = pumpkinEnabled
    end
    if pumpkinEnabled then scanAll() end
end)

doorBtn.MouseButton1Click:Connect(function()
    doorEnabled = not doorEnabled
    doorBtn.Text = "Doors: " .. (doorEnabled and "ON" or "OFF")
    doorBtn.BackgroundColor3 = doorEnabled and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(60, 60, 60)
    for _, obj in ipairs(doorObjects) do
        obj.Enabled = doorEnabled
    end
    if doorEnabled then scanAll() end
end)

local dragging, dragInput, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
