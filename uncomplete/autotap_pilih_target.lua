-- Auto Attack Spirit v3 (dropdown pilih target)
-- Dasar: autotapbanana.lua v2
-- Baru: dropdown "Target" untuk memilih jenis spirit yang diincar
--       (Semua / Bananya / Tinklet / Yukibun / Kinopin, jenis baru otomatis ditambah)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ===== PENGATURAN =====
local CONFIG = {
    DISTANCE = 6,
    HEIGHT = 3,
    TIMEOUT = 15,
    SKIP_TIME = 30,
    REPOSITION_DIST = 14,
    RANGE_MARGIN = 3,
    LOOP_DELAY = 0.25,
}

-- ===== MODUL GAME =====
local mods = {}
local loadErr = nil
do
    local ok, err = pcall(function()
        mods.Spawner = require(workspace.Src.Spirits.SpiritSpawner)
        mods.Combat = require(workspace.Src.Combat.CombatManager)
        mods.Pet = require(workspace.Src.Combat.PetCombatController)
        mods.Config = require(workspace.Src.Configs.SpiritCatchingConfig)
    end)
    if not ok then loadErr = tostring(err) end
    pcall(function()
        mods.Catcher = require(workspace.Src.Spirits.SpiritCatcher)
        mods.Inv = require(workspace.Src.PetInventory)
    end)
end

-- ===== STATE =====
local ALL = "Semua"
local options = { ALL, "Bananya", "Tinklet", "Yukibun", "Kinopin" }
local selectedType = ALL
local dropOpen = false

local alive = true
local enabled = false
local statusText = "berhenti"
local ticks = 0
local lastTick = os.clock()
local engagedNow = false
local skipped = {}
local current, since, lastTeleported = nil, 0, nil
local typeCache = setmetatable({}, { __mode = "k" })

local ui = {}
local conns = {}

local function setStatus(t)
    statusText = t
    if ui.status then ui.status.Text = "Status: " .. t end
end

local function refreshToggle()
    if not ui.toggleBtn then return end
    ui.toggleBtn.Text = enabled and "ON" or "OFF"
    ui.toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(60, 160, 90) or Color3.fromRGB(190, 60, 60)
end

local function setEnabled(v, reason)
    enabled = v
    warn("[AutoAttack] " .. (v and "ON" or "OFF") .. " <- " .. tostring(reason))
    if not v then
        current, lastTeleported = nil, nil
        setStatus("berhenti")
    else
        setStatus("mulai...")
    end
    refreshToggle()
end

-- ===== JENIS SPIRIT =====
local function spiritType(sp)
    local model = sp and sp.Model
    if not model then return "Unknown" end
    local cached = typeCache[model]
    if cached then return cached end

    local result
    if model:FindFirstChild("Banana") then
        result = "Bananya"
    else
        for _, c in ipairs(model:GetChildren()) do
            local n = c.Name:match("^(.+)Face$")
            if n then result = n break end
        end
    end
    if not result then
        local lbl = model:FindFirstChild("SpiritName", true)
        if lbl and lbl.Text ~= "" then result = lbl.Text end
    end

    if result then
        typeCache[model] = result
        return result
    end
    return "Unknown"
end

local function matchesSelected(sp)
    if selectedType == ALL then return true end
    return string.lower(spiritType(sp)) == string.lower(selectedType)
end

-- ===== LOGIKA =====
local function maxEngage()
    local d = mods.Config and mods.Config.MaxEngageDistance
    return (type(d) == "number") and d or 30
end

local function getTargetPart(sp)
    local model = sp and sp.Model
    if not model then return nil end
    return model:FindFirstChild("Banana", true)
        or model.PrimaryPart
        or model:FindFirstChild("HumanoidRootPart")
end

local function isValid(sp)
    if not sp or sp.IsCaught then return false end
    local model = sp.Model
    if not model or not model.Parent then return false end
    return getTargetPart(sp) ~= nil
end

local function nearestSpirit(hrp)
    local best, bestDist = nil, math.huge
    local now = os.clock()
    for _, sp in mods.Spawner.GetAllSpirits() do
        if isValid(sp) and matchesSelected(sp) and not (skipped[sp] and skipped[sp] > now) then
            local part = getTargetPart(sp)
            local d = (part.Position - hrp.Position).Magnitude
            if d < bestDist then best, bestDist = sp, d end
        end
    end
    return best
end

local function teleportTo(hrp, part)
    local tp = part.Position
    local standPos = tp + Vector3.new(0, CONFIG.HEIGHT, CONFIG.DISTANCE)
    hrp.CFrame = CFrame.lookAt(standPos, Vector3.new(tp.X, standPos.Y, tp.Z))
end

local function step()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then setStatus("menunggu karakter") return end

    engagedNow = mods.Combat.IsEngaged() and true or false

    if engagedNow then
        local t = mods.Combat.GetTarget()
        local part = t and getTargetPart(t)
        if part and (hrp.Position - part.Position).Magnitude > (maxEngage() - CONFIG.RANGE_MARGIN) then
            teleportTo(hrp, part)
        end
        setStatus("melawan " .. tostring(t and t.Model and t.Model.Name or "?"))
        since = os.clock()
        return
    end

    if not mods.Pet.HasAnyAlivePet() then
        setStatus("pet mati/tidak ada")
        return
    end

    if not isValid(current) or not matchesSelected(current) then
        current = nearestSpirit(hrp)
        since = os.clock()
    elseif os.clock() - since > CONFIG.TIMEOUT then
        skipped[current] = os.clock() + CONFIG.SKIP_TIME
        current = nearestSpirit(hrp)
        since = os.clock()
    end

    if not current then
        setStatus("mencari " .. (selectedType == ALL and "spirit" or selectedType) .. "...")
        return
    end

    local part = getTargetPart(current)
    if not part then current = nil return end

    local dist = (hrp.Position - part.Position).Magnitude
    if current ~= lastTeleported
        or dist > CONFIG.REPOSITION_DIST
        or dist > (maxEngage() - CONFIG.RANGE_MARGIN) then
        teleportTo(hrp, part)
        lastTeleported = current
        task.wait(0.1)
    end

    if mods.Catcher and mods.Inv then
        pcall(function()
            if mods.Catcher.CatchNeedsInventorySpace(current) and mods.Inv.IsInventoryFull(player) then
                mods.Catcher.InventoryFullEvent:Fire()
            end
        end)
    end

    mods.Combat.EngageTarget(current)
    setStatus("mengunci " .. spiritType(current) .. " (" .. tostring(current.Model.Name) .. ")")
    task.wait(0.2)
end

-- ===== GUI =====
local function guiParent()
    local ok, ui2 = pcall(function() return gethui() end)
    if ok and ui2 then return ui2 end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then return core end
    return player:WaitForChild("PlayerGui")
end

local W = 210
local MIN_H = 28
local FULL_H = 146
local OPEN_H = 214
local minimized = false

local function applySize()
    if not ui.frame then return end
    local h = FULL_H
    if minimized then h = MIN_H elseif dropOpen then h = OPEN_H end
    ui.frame.Size = UDim2.fromOffset(W, h)
end

local function clearConns()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
end

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
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local function makeLabel(parent, pos, color, textSize)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 18)
    l.Position = pos
    l.BackgroundTransparency = 1
    l.TextColor3 = color
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.Gotham
    l.TextSize = textSize
    l.Parent = parent
    return l
end

local function refreshDropText()
    if ui.dropBtn then
        ui.dropBtn.Text = "Target: " .. selectedType .. (dropOpen and "  ^" or "  v")
    end
end

local function selectType(name)
    selectedType = name
    current, lastTeleported = nil, nil
    dropOpen = false
    if ui.list then ui.list.Visible = false end
    refreshDropText()
    applySize()
    warn("[AutoAttack] target dipilih: " .. name)
    if enabled then setStatus("mencari " .. (name == ALL and "spirit" or name) .. "...") end
end

local function rebuildList()
    if not ui.list then return end
    for _, c in ipairs(ui.list:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for i, name in ipairs(options) do
        local b = makeButton(ui.list, name, UDim2.new(1, -6, 0, 22), UDim2.new(), Color3.fromRGB(55, 55, 70))
        b.LayoutOrder = i
        b.TextSize = 12
        if name == selectedType then b.BackgroundColor3 = Color3.fromRGB(70, 110, 190) end
        b.MouseButton1Click:Connect(function() selectType(name) end)
    end
end

local function addOption(name)
    for _, o in ipairs(options) do
        if string.lower(o) == string.lower(name) then return end
    end
    table.insert(options, name)
    rebuildList()
end

local function build()
    clearConns()
    dropOpen = false
    local parent = guiParent()
    local old = parent:FindFirstChild("AutoAttackGui")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoAttackGui"
    gui.ResetOnSpawn = false
    gui.Parent = parent
    ui.gui = gui

    local frame = Instance.new("Frame")
    frame.Position = ui.framePos or UDim2.new(0, 20, 0.4, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    ui.frame = frame

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, MIN_H)
    titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -64, 1, 0)
    title.Position = UDim2.fromOffset(8, 0)
    title.BackgroundTransparency = 1
    title.Text = "Auto Attack Spirit v3"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.Parent = titleBar

    local minBtn = makeButton(titleBar, minimized and "+" or "-", UDim2.fromOffset(24, 20), UDim2.new(1, -54, 0, 4), Color3.fromRGB(90, 90, 110))
    local closeBtn = makeButton(titleBar, "X", UDim2.fromOffset(24, 20), UDim2.new(1, -28, 0, 4), Color3.fromRGB(190, 60, 60))

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 1, -MIN_H)
    body.Position = UDim2.fromOffset(0, MIN_H)
    body.BackgroundTransparency = 1
    body.Visible = not minimized
    body.Parent = frame

    ui.toggleBtn = makeButton(body, "OFF", UDim2.new(1, -20, 0, 32), UDim2.fromOffset(10, 8), Color3.fromRGB(190, 60, 60))
    ui.dropBtn = makeButton(body, "", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 46), Color3.fromRGB(55, 55, 70))
    ui.status = makeLabel(body, UDim2.fromOffset(10, 76), Color3.fromRGB(200, 200, 210), 12)
    ui.debug = makeLabel(body, UDim2.fromOffset(10, 96), Color3.fromRGB(130, 130, 145), 11)

    -- daftar dropdown (menimpa status saat terbuka)
    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, -20, 0, 110)
    list.Position = UDim2.fromOffset(10, 72)
    list.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 4
    list.CanvasSize = UDim2.new()
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 5
    list.Visible = false
    list.Parent = body
    Instance.new("UICorner", list).CornerRadius = UDim.new(0, 5)
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = list
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 3)
    pad.PaddingLeft = UDim.new(0, 3)
    pad.Parent = list
    ui.list = list

    rebuildList()
    refreshDropText()
    applySize()

    ui.dropBtn.MouseButton1Click:Connect(function()
        dropOpen = not dropOpen
        list.Visible = dropOpen
        refreshDropText()
        applySize()
    end)

    -- drag lewat title bar
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    table.insert(conns, UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
            ui.framePos = frame.Position
        end
    end))
    table.insert(conns, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    ui.toggleBtn.MouseButton1Click:Connect(function()
        if loadErr then return end
        setEnabled(not enabled, "tombol toggle ditekan")
    end)

    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then dropOpen = false list.Visible = false refreshDropText() end
        body.Visible = not minimized
        applySize()
        minBtn.Text = minimized and "+" or "-"
    end)

    closeBtn.MouseButton1Click:Connect(function()
        alive = false
        enabled = false
        clearConns()
        if ui.watchdog then ui.watchdog:Disconnect() end
        gui:Destroy()
    end)

    setStatus(loadErr and "modul gagal dimuat" or statusText)
    refreshToggle()
end

build()
if loadErr then warn("[AutoAttack] " .. loadErr) end

-- tambah jenis spirit baru ke dropdown secara otomatis
local function discoverTypes()
    if not mods.Spawner then return end
    for _, sp in mods.Spawner.GetAllSpirits() do
        if sp and sp.Model then
            local t = spiritType(sp)
            if t ~= "Unknown" then addOption(t) end
        end
    end
end

-- ===== LOOP UTAMA =====
local gen = 0
local function startLoop()
    gen += 1
    local my = gen
    task.spawn(function()
        while alive and my == gen do
            lastTick = os.clock()
            ticks += 1
            if not loadErr then pcall(discoverTypes) end
            if enabled and not loadErr then
                local ok, err = pcall(step)
                if not ok then
                    setStatus("error, lihat console")
                    warn("[AutoAttack] " .. tostring(err))
                end
            end
            if ui.debug then
                ui.debug.Text = "loop #" .. ticks .. " | engaged: " .. tostring(engagedNow)
            end
            task.wait(CONFIG.LOOP_DELAY)
        end
    end)
end
startLoop()

-- ===== WATCHDOG =====
local acc = 0
ui.watchdog = RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < 1 then return end
    acc = 0
    if not alive then return end

    if not ui.gui or not ui.gui.Parent then
        warn("[AutoAttack] GUI hilang, dibuat ulang")
        build()
    end

    if os.clock() - lastTick > 5 then
        warn("[AutoAttack] loop macet, dijalankan ulang")
        startLoop()
    end
end)
