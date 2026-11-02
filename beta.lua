local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Bersihkan eksekusi sebelumnya (anti dobel)
local env = (getgenv and getgenv()) or _G
if env.__ESP_CLEANUP then
    pcall(env.__ESP_CLEANUP)
end

local pumpkinEnabled = true
local doorEnabled = true
local running = true

local conns = {}
local entries = {}
local trackedPumpkins = {}
local trackedDoors = {}

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(conns, c)
    return c
end

local function destroyEntry(e)
    if e.highlight then e.highlight:Destroy() end
    if e.billboard then e.billboard:Destroy() end
end

-- ================= ESP =================

local function createPumpkinESP(part)
    local highlight = Instance.new("Highlight")
    highlight.Name = "Pumpkin_ESP"
    highlight.Adornee = part
    highlight.FillColor = Color3.fromRGB(255, 140, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = pumpkinEnabled
    highlight.Parent = part

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

    table.insert(entries, {
        kind = "pumpkin",
        part = part,
        highlight = highlight,
        billboard = billboard,
        label = label,
    })
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

    local entry = {
        kind = "door",
        part = frame,
        model = doorModel,
        highlight = highlight,
        billboard = billboard,
        label = label,
        visited = false,
    }

    local function markVisited()
        if entry.visited then return end
        entry.visited = true
        highlight.FillColor = Color3.fromRGB(50, 255, 50)
        label.TextColor3 = Color3.fromRGB(50, 255, 50)
    end

    for _, d in ipairs(doorModel:GetDescendants()) do
        if d:IsA("ClickDetector") then
            connect(d.MouseClick, function(player)
                if player == LocalPlayer then markVisited() end
            end)
        elseif d:IsA("ProximityPrompt") then
            connect(d.Triggered, function(player)
                if player == LocalPlayer then markVisited() end
            end)
        end
    end

    table.insert(entries, entry)
end

-- Satu loop untuk semua update jarak
connect(RunService.RenderStepped, function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    for i = #entries, 1, -1 do
        local e = entries[i]
        if not e.part or not e.part.Parent then
            destroyEntry(e)
            if e.kind == "pumpkin" then
                trackedPumpkins[e.part] = nil
            else
                trackedDoors[e.model] = nil
            end
            table.remove(entries, i)
        elseif root then
            local active = (e.kind == "pumpkin" and pumpkinEnabled) or (e.kind == "door" and doorEnabled)
            if active then
                local dist = math.floor((root.Position - e.part.Position).Magnitude)
                if e.kind == "pumpkin" then
                    e.label.Text = string.format("Pumpkin [%d]", dist)
                elseif e.visited then
                    e.label.Text = string.format("Visited [%d]", dist)
                else
                    e.label.Text = string.format("Door [%d]", dist)
                end
            end
        end
    end
end)

-- ================= SCAN =================

local function scanAll()
    if pumpkinEnabled then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("pumpkin") and not trackedPumpkins[obj] then
                if obj.Transparency < 0.9 then
                    local maxDim = math.max(obj.Size.X, obj.Size.Y, obj.Size.Z)
                    if maxDim <= 15 then
                        local isDuplicate = false
                        for trackedPart in pairs(trackedPumpkins) do
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
    while running do
        task.wait(2)
        if running then scanAll() end
    end
end)

-- ================= GUI =================

local gui = Instance.new("ScreenGui")
gui.Name = "PumpkinDoorESP_Gui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 150, 0, 120)
frame.AnchorPoint = Vector2.new(0, 0.5)
frame.Position = UDim2.new(0.0475, 40, 0.305, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Active = true
frame.Visible = false
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

-- Tombol buka/tutup menu (tetap di kiri)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 50, 0, 50)
toggleBtn.AnchorPoint = Vector2.new(0.5, 0.5)
toggleBtn.Position = UDim2.new(0.0475, 0, 0.305, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
toggleBtn.Text = "≡"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 28
toggleBtn.Parent = gui

local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 8)
tc.Parent = toggleBtn

connect(toggleBtn.MouseButton1Click, function()
    frame.Visible = not frame.Visible
end)

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

local function setKind(kind, enabled)
    for _, e in ipairs(entries) do
        if e.kind == kind then
            e.highlight.Enabled = enabled
            e.billboard.Enabled = enabled
        end
    end
end

connect(pumpkinBtn.MouseButton1Click, function()
    pumpkinEnabled = not pumpkinEnabled
    pumpkinBtn.Text = "Pumpkin: " .. (pumpkinEnabled and "ON" or "OFF")
    pumpkinBtn.BackgroundColor3 = pumpkinEnabled and Color3.fromRGB(200, 100, 0) or Color3.fromRGB(60, 60, 60)
    setKind("pumpkin", pumpkinEnabled)
    if pumpkinEnabled then scanAll() end
end)

connect(doorBtn.MouseButton1Click, function()
    doorEnabled = not doorEnabled
    doorBtn.Text = "Doors: " .. (doorEnabled and "ON" or "OFF")
    doorBtn.BackgroundColor3 = doorEnabled and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(60, 60, 60)
    setKind("door", doorEnabled)
    if doorEnabled then scanAll() end
end)

-- Drag menu
local dragging, dragInput, dragStart, startPos
connect(frame.InputBegan, function(input)
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

connect(frame.InputChanged, function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

connect(UserInputService.InputChanged, function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- Cleanup untuk eksekusi berikutnya
env.__ESP_CLEANUP = function()
    running = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    for _, e in ipairs(entries) do
        destroyEntry(e)
    end
    if gui then gui:Destroy() end
end
