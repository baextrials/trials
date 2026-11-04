-- Auto Tap Spirit: kunci target + auto kamera + GUI (ON/OFF, Minimize, Close)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

-- ===== PENGATURAN =====
local CONFIG = {
    DISTANCE = 6,        -- jarak berdiri dari spirit (stud)
    HEIGHT = 3,          -- tinggi di atas spirit (stud)
    TIMEOUT = 15,        -- detik maksimal per target sebelum pindah
    SKIP_TIME = 30,      -- detik target yang menyerah dilewati
    TAP_INTERVAL = 0.03, -- jeda antar putaran (detik), makin kecil makin cepat
    TAPS_PER_LOOP = 3,   -- jumlah tap per putaran
    REPOSITION_DIST = 14,-- teleport ulang hanya kalau jarak ke spirit lebih dari ini
    CLICK_Y_OFFSET = 0,  -- ubah ke 36 kalau klik meleset ke atas
}

local state = {
    enabled = false,
    useCamera = true,
    alive = true,
    target = nil,
    targetPart = nil,
}
local skipped = {} -- [spirit] = waktu kedaluwarsa

-- ===== LOGIKA =====
local function getFolder()
    return workspace:FindFirstChild("ActiveSpirits")
end

local function isValid(spirit)
    if not spirit or not spirit.Parent then return false end
    local hum = spirit:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function getTargetPart(spirit)
    return spirit:FindFirstChild("Banana")
        or spirit.PrimaryPart
        or spirit:FindFirstChild("HumanoidRootPart")
end

local function nearestSpirit(hrp)
    local folder = getFolder()
    if not folder then return nil end
    local best, bestDist = nil, math.huge
    local now = os.clock()
    for _, s in ipairs(folder:GetChildren()) do
        if isValid(s) and not (skipped[s] and skipped[s] > now) then
            local part = s:FindFirstChild("HumanoidRootPart") or getTargetPart(s)
            if part then
                local d = (part.Position - hrp.Position).Magnitude
                if d < bestDist then best, bestDist = s, d end
            end
        end
    end
    return best
end

local function tap(worldPos)
    local pos, onScreen = cam:WorldToViewportPoint(worldPos)
    if onScreen then
        local x, y = pos.X, pos.Y + CONFIG.CLICK_Y_OFFSET
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end
end

-- Auto kamera: dijalankan tiap frame supaya tidak ditimpa kamera bawaan
local camConn = RunService.RenderStepped:Connect(function()
    if state.enabled and state.useCamera and state.targetPart and state.targetPart.Parent then
        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, state.targetPart.Position)
    end
end)

-- ===== GUI =====
local function guiParent()
    local ok, ui = pcall(function() return gethui() end)
    if ok and ui then return ui end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then return core end
    return player:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoTapGui"
gui.ResetOnSpawn = false
gui.Parent = guiParent()

local FULL_H, MIN_H = 130, 28

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(210, FULL_H)
frame.Position = UDim2.new(0, 20, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, MIN_H)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
titleBar.BorderSizePixel = 0
titleBar.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -64, 1, 0)
title.Position = UDim2.fromOffset(8, 0)
title.BackgroundTransparency = 1
title.Text = "Auto Tap Spirit"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.Parent = titleBar

local function makeButton(parent, text, size, pos, color)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.AutoButtonColor = true
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local minBtn = makeButton(titleBar, "-", UDim2.fromOffset(24, 20), UDim2.new(1, -54, 0, 4), Color3.fromRGB(90, 90, 110))
local closeBtn = makeButton(titleBar, "X", UDim2.fromOffset(24, 20), UDim2.new(1, -28, 0, 4), Color3.fromRGB(190, 60, 60))

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -MIN_H)
body.Position = UDim2.fromOffset(0, MIN_H)
body.BackgroundTransparency = 1
body.Parent = frame

local toggleBtn = makeButton(body, "OFF", UDim2.new(1, -20, 0, 32), UDim2.fromOffset(10, 10), Color3.fromRGB(190, 60, 60))
local camBtn = makeButton(body, "Kamera: ON", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 48), Color3.fromRGB(60, 130, 90))

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 20)
status.Position = UDim2.fromOffset(10, 80)
status.BackgroundTransparency = 1
status.Text = "Status: berhenti"
status.TextColor3 = Color3.fromRGB(200, 200, 210)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.Parent = body

local function setStatus(t) status.Text = "Status: " .. t end

-- Drag lewat title bar (mouse & sentuh)
do
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

toggleBtn.MouseButton1Click:Connect(function()
    state.enabled = not state.enabled
    toggleBtn.Text = state.enabled and "ON" or "OFF"
    toggleBtn.BackgroundColor3 = state.enabled and Color3.fromRGB(60, 160, 90) or Color3.fromRGB(190, 60, 60)
    if not state.enabled then
        state.target, state.targetPart = nil, nil
        setStatus("berhenti")
    end
end)

camBtn.MouseButton1Click:Connect(function()
    state.useCamera = not state.useCamera
    camBtn.Text = "Kamera: " .. (state.useCamera and "ON" or "OFF")
    camBtn.BackgroundColor3 = state.useCamera and Color3.fromRGB(60, 130, 90) or Color3.fromRGB(90, 90, 110)
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    frame.Size = UDim2.fromOffset(210, minimized and MIN_H or FULL_H)
    minBtn.Text = minimized and "+" or "-"
end)

closeBtn.MouseButton1Click:Connect(function()
    state.alive = false
    state.enabled = false
    camConn:Disconnect()
    gui:Destroy()
end)

-- ===== LOOP UTAMA =====
task.spawn(function()
    local since = 0
    local lastTeleported = nil
    while state.alive do
        if state.enabled then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- kunci target: pilih baru hanya jika target lama mati/hilang
                if not isValid(state.target) then
                    state.target = nearestSpirit(hrp)
                    since = os.clock()
                elseif os.clock() - since > CONFIG.TIMEOUT then
                    skipped[state.target] = os.clock() + CONFIG.SKIP_TIME
                    state.target = nearestSpirit(hrp)
                    since = os.clock()
                end

                local part = state.target and getTargetPart(state.target)
                state.targetPart = part

                if part then
                    local tp = part.Position
                    local dist = (hrp.Position - tp).Magnitude
                    -- teleport hanya saat target baru atau spirit sudah terlalu jauh
                    if state.target ~= lastTeleported or dist > CONFIG.REPOSITION_DIST then
                        local standPos = tp + Vector3.new(0, CONFIG.HEIGHT, CONFIG.DISTANCE)
                        hrp.CFrame = CFrame.lookAt(standPos, Vector3.new(tp.X, standPos.Y, tp.Z))
                        lastTeleported = state.target
                        task.wait(0.05)
                    end
                    for _ = 1, CONFIG.TAPS_PER_LOOP do
                        if part.Parent then tap(part.Position) end
                    end
                    setStatus(state.target.Name)
                else
                    setStatus("mencari spirit...")
                end
            end
        end
        task.wait(CONFIG.TAP_INTERVAL)
    end
end)
