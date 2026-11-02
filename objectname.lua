local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

-- Anti dobel
local env = (getgenv and getgenv()) or _G
if env.__NAMECHECK_CLEANUP then pcall(env.__NAMECHECK_CLEANUP) end

-- ===== Pengaturan =====
local radius = 100
local labelsOn = false
local tapOn = false
local MAXLIST = 60
local MAXLABELS = 25
local filters = { Pemain = true, Musuh = true, Entitas = true }
local COLORS = {
    Pemain = Color3.fromRGB(80, 255, 120),
    Musuh = Color3.fromRGB(255, 80, 80),
    Entitas = Color3.fromRGB(255, 230, 80),
}

local running = true
local conns = {}
local labelMap = {}
local lastReport = ""

local function connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(conns, c)
    return c
end

local function getRoot()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

-- ================= DATA OBJEK (ringan) =================

local sources = {}

local function isSource(o)
    return o:IsA("Humanoid") or o:IsA("AnimationController")
end

for _, o in ipairs(Workspace:GetDescendants()) do
    if isSource(o) then sources[o] = true end
end
connect(Workspace.DescendantAdded, function(o)
    if isSource(o) then sources[o] = true end
end)
connect(Workspace.DescendantRemoving, function(o)
    sources[o] = nil
end)

local function kindOf(model)
    if Players:GetPlayerFromCharacter(model) then return "Pemain" end
    if model:FindFirstChildOfClass("Humanoid") then return "Musuh" end
    return "Entitas"
end

local function pickPart(m)
    local p = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
    if p and p:IsA("BasePart") then return p end
    return m:FindFirstChildWhichIsA("BasePart", true)
end

local function collect()
    local root = getRoot()
    if not root then return nil end

    local found, seen = {}, {}
    for src in pairs(sources) do
        local m = src.Parent
        if m and m:IsA("Model") and m ~= LP.Character and not seen[m] and m:IsDescendantOf(Workspace) then
            seen[m] = true
            local kind = kindOf(m)
            if filters[kind] then
                local part = pickPart(m)
                if part then
                    local d = (part.Position - root.Position).Magnitude
                    if d <= radius then
                        table.insert(found, { model = m, part = part, d = d, kind = kind })
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    return found
end

-- ================= GUI =================

local guiParent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "NameCheck_Gui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
gui.Parent = guiParent

local GRAY = Color3.fromRGB(60, 60, 60)
local BLUE = Color3.fromRGB(40, 140, 220)

local function makeBtn(parent, x, y, w, h, text, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 12
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end

local function makeText(parent, x, y, w, h, text, size)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0, w, 0, h)
    t.Position = UDim2.new(0, x, 0, y)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = Color3.fromRGB(255, 255, 255)
    t.Font = Enum.Font.SourceSansBold
    t.TextSize = size or 12
    t.Parent = parent
    return t
end

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
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 320, 0, 250)
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0.0475, 40, 0.5, 0)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)

makeText(panel, 6, 0, 150, 22, "Name Check", 14).TextXAlignment = Enum.TextXAlignment.Left
local status = makeText(panel, 160, 0, 154, 22, "Siap", 11)
status.TextXAlignment = Enum.TextXAlignment.Right

-- Baris 1
local scanBtn = makeBtn(panel, 6, 24, 56, 24, "Scan", BLUE)
local minusBtn = makeBtn(panel, 66, 24, 26, 24, "-", GRAY)
local radiusLabel = makeText(panel, 94, 24, 50, 24, "R: " .. radius)
local plusBtn = makeBtn(panel, 146, 24, 26, 24, "+", GRAY)
local copyBtn = makeBtn(panel, 176, 24, 60, 24, "Copy", Color3.fromRGB(60, 140, 60))
local labelBtn = makeBtn(panel, 240, 24, 74, 24, "Label: OFF", GRAY)

-- Baris 2 (filter)
local kindBtns = {}
local function makeKindBtn(name, x)
    local b = makeBtn(panel, x, 52, 72, 24, name .. ": ON", COLORS[name])
    b.TextColor3 = Color3.fromRGB(0, 0, 0)
    kindBtns[name] = b
    return b
end
makeKindBtn("Pemain", 6)
makeKindBtn("Musuh", 82)
makeKindBtn("Entitas", 158)
local tapBtn = makeBtn(panel, 234, 52, 80, 24, "Tap: OFF", GRAY)

local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -12, 1, -86)
listFrame.Position = UDim2.new(0, 6, 0, 80)
listFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 4
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.Parent = panel

local listLabel = Instance.new("TextLabel")
listLabel.Size = UDim2.new(1, -8, 0, 0)
listLabel.Position = UDim2.new(0, 4, 0, 2)
listLabel.AutomaticSize = Enum.AutomaticSize.Y
listLabel.BackgroundTransparency = 1
listLabel.TextWrapped = true
listLabel.TextXAlignment = Enum.TextXAlignment.Left
listLabel.TextYAlignment = Enum.TextYAlignment.Top
listLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
listLabel.Font = Enum.Font.Code
listLabel.TextSize = 11
listLabel.Text = "Tekan Scan di dekat musuh / pemain."
listLabel.Parent = listFrame

-- ================= LABEL =================

local function clearLabels()
    for m, e in pairs(labelMap) do
        e.bb:Destroy()
        labelMap[m] = nil
    end
end

local function refreshLabels(found)
    if not labelsOn or not found then
        clearLabels()
        return
    end

    local desired = {}
    for i = 1, math.min(#found, MAXLABELS) do
        desired[found[i].model] = found[i]
    end

    for m, e in pairs(labelMap) do
        if not desired[m] then
            e.bb:Destroy()
            labelMap[m] = nil
        end
    end

    for m, f in pairs(desired) do
        local e = labelMap[m]
        if not e then
            local bb = Instance.new("BillboardGui")
            bb.Adornee = f.part
            bb.Size = UDim2.new(0, 180, 0, 22)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Parent = gui

            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, 0, 1, 0)
            t.BackgroundTransparency = 1
            t.TextColor3 = COLORS[f.kind]
            t.TextStrokeTransparency = 0
            t.Font = Enum.Font.SourceSansBold
            t.TextSize = 14
            t.Parent = bb

            e = { bb = bb, t = t }
            labelMap[m] = e
        end
        local plr = Players:GetPlayerFromCharacter(m)
        local nm = plr and (plr.DisplayName .. " @" .. plr.Name) or m.Name
        e.t.Text = string.format("%s [%d]", nm, math.floor(f.d))
    end
end

-- ================= SCAN =================

local function runScan()
    local found = collect()
    if not found then
        listLabel.Text = "Karakter belum siap."
        return
    end

    local lines = {
        string.format("R %d | ditemukan %d (tampil maks %d)", radius, #found, MAXLIST),
        "",
    }
    for i = 1, math.min(#found, MAXLIST) do
        local f = found[i]
        local plr = Players:GetPlayerFromCharacter(f.model)
        local extra = plr and (" | display: " .. plr.DisplayName) or ""
        table.insert(lines, string.format("[%d] %s (%s)%s\n    %s",
            math.floor(f.d), f.model.Name, f.kind, extra, f.model:GetFullName()))
    end

    lastReport = table.concat(lines, "\n")
    listLabel.Text = lastReport
    listFrame.CanvasPosition = Vector2.new(0, 0)
    status.Text = "Ketemu: " .. #found
    refreshLabels(found)
end

-- ================= TOMBOL =================

connect(toggleBtn.MouseButton1Click, function()
    panel.Visible = not panel.Visible
    if panel.Visible then runScan() end
end)

connect(scanBtn.MouseButton1Click, runScan)

connect(minusBtn.MouseButton1Click, function()
    radius = math.max(10, radius - 25)
    radiusLabel.Text = "R: " .. radius
end)

connect(plusBtn.MouseButton1Click, function()
    radius = math.min(1000, radius + 25)
    radiusLabel.Text = "R: " .. radius
end)

connect(labelBtn.MouseButton1Click, function()
    labelsOn = not labelsOn
    labelBtn.Text = "Label: " .. (labelsOn and "ON" or "OFF")
    labelBtn.BackgroundColor3 = labelsOn and BLUE or GRAY
    refreshLabels(collect())
end)

for name, btn in pairs(kindBtns) do
    connect(btn.MouseButton1Click, function()
        filters[name] = not filters[name]
        btn.Text = name .. (filters[name] and ": ON" or ": OFF")
        btn.BackgroundColor3 = filters[name] and COLORS[name] or GRAY
        btn.TextColor3 = filters[name] and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        runScan()
    end)
end

connect(tapBtn.MouseButton1Click, function()
    tapOn = not tapOn
    tapBtn.Text = "Tap: " .. (tapOn and "ON" or "OFF")
    tapBtn.BackgroundColor3 = tapOn and BLUE or GRAY
    if tapOn then
        listLabel.Text = "Mode Tap aktif. Sentuh objek di dunia game untuk melihat namanya."
    end
end)

connect(copyBtn.MouseButton1Click, function()
    local clip = setclipboard or toclipboard
    if clip and lastReport ~= "" then
        pcall(clip, lastReport)
        copyBtn.Text = "Copied!"
    else
        print(lastReport)
        copyBtn.Text = "Console"
    end
    task.delay(1.5, function()
        if copyBtn.Parent then copyBtn.Text = "Copy" end
    end)
end)

-- Tap: cek objek yang disentuh
connect(UIS.InputBegan, function(input, gp)
    if not tapOn or gp then return end
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    task.wait(0.05)
    local t = Mouse.Target
    if not t then
        listLabel.Text = "Tap: tidak kena objek."
        return
    end

    local model = t:FindFirstAncestorOfClass("Model")
    local lines = {
        "Part   : " .. t.Name .. " <" .. t.ClassName .. ">",
        "Path   : " .. t:GetFullName(),
    }
    if model then
        local plr = Players:GetPlayerFromCharacter(model)
        table.insert(lines, "Model  : " .. model.Name)
        table.insert(lines, "Path   : " .. model:GetFullName())
        table.insert(lines, "Tipe   : " .. kindOf(model))
        table.insert(lines, "Humanoid: " .. tostring(model:FindFirstChildOfClass("Humanoid") ~= nil))
        table.insert(lines, "AnimCtrl: " .. tostring(model:FindFirstChildWhichIsA("AnimationController", true) ~= nil))
        if plr then
            table.insert(lines, "Pemain : " .. plr.Name .. " (" .. plr.DisplayName .. ")")
        end
    end

    lastReport = table.concat(lines, "\n")
    listLabel.Text = lastReport
    panel.Visible = true
end)

-- Update label otomatis (ringan, data dari registry)
task.spawn(function()
    while running do
        task.wait(0.7)
        if running and labelsOn then
            refreshLabels(collect())
        end
    end
end)

-- Cleanup
env.__NAMECHECK_CLEANUP = function()
    running = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    clearLabels()
    if gui then gui:Destroy() end
end

print("[NameCheck] siap. Tekan tombol ≡ di kiri.")
