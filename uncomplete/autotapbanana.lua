-- Auto Attack Spirit v2
-- Serang: CombatManager.EngageTarget (tanpa klik layar, inventory aman)
-- Teleport: ke part "Banana", target terkunci, timeout & skip
-- v2: loop dijaga watchdog (restart otomatis kalau macet), GUI dibuat ulang kalau
--     dihapus game, dan setiap kali ON/OFF berubah dicatat di console beserta alasannya.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ===== PENGATURAN =====
local CONFIG = {
    DISTANCE = 6,         -- jarak berdiri dari spirit (stud)
    HEIGHT = 3,           -- tinggi di atas spirit (stud)
    TIMEOUT = 15,         -- detik maksimal per target sebelum pindah
    SKIP_TIME = 30,       -- detik target yang menyerah dilewati
    REPOSITION_DIST = 14, -- teleport ulang kalau jarak ke spirit lebih dari ini
    RANGE_MARGIN = 3,     -- juga teleport kalau jarak > MaxEngageDistance - margin
    LOOP_DELAY = 0.25,    -- jeda pengecekan (detik)
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
local alive = true
local enabled = false
local statusText = "berhenti"
local ticks = 0
local lastTick = os.clock()
local engagedNow = false
local skipped = {} -- [spirit] = waktu kedaluwarsa
local current, since, lastTeleported = nil, 0, nil

local ui = {}      -- referensi elemen GUI (diisi saat build)
local conns = {}   -- koneksi drag

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
        if isValid(sp) and not (skipped[sp] and skipped[sp] > now) then
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

-- satu putaran logika
local function step()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then setStatus("menunggu karakter") return end

    engagedNow = mods.Combat.IsEngaged() and true or false

    -- sedang bertarung: biarkan, tapi tarik balik kalau terlalu jauh
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

    -- kunci target; pilih baru kalau mati/hilang atau timeout
    if not isValid(current) then
        current = nearestSpirit(hrp)
        since = os.clock()
    elseif os.clock() - since > CONFIG.TIMEOUT then
        skipped[current] = os.clock() + CONFIG.SKIP_TIME
        current = nearestSpirit(hrp)
        since = os.clock()
    end

    if not current then setStatus("mencari spirit...") return end

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
    setStatus("mengunci " .. tostring(current.Model.Name))
    task.wait(0.2) -- beri waktu server mengonfirmasi engage
end

-- ===== GUI =====
local function guiParent()
    local ok, ui2 = pcall(function() return gethui() end)
    if ok and ui2 then return ui2 end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then return core end
    return player:WaitForChild("PlayerGui")
end

local FULL_H, MIN_H = 118, 28
local minimized = false

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

local function makeLabel(parent, pos, size, color, textSize)
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

local function build()
    clearConns()
    local parent = guiParent()
    local old = parent:FindFirstChild("AutoAttackGui")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoAttackGui"
    gui.ResetOnSpawn = false
    gui.Parent = parent
    ui.gui = gui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(210, minimized and MIN_H or FULL_H)
    frame.Position = ui.framePos or UDim2.new(0, 20, 0.4, 0)
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
    title.Text = "Auto Attack Spirit v2"
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
    ui.status = makeLabel(body, UDim2.fromOffset(10, 46), nil, Color3.fromRGB(200, 200, 210), 12)
    ui.debug = makeLabel(body, UDim2.fromOffset(10, 66), nil, Color3.fromRGB(130, 130, 145), 11)

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
        body.Visible = not minimized
        frame.Size = UDim2.fromOffset(210, minimized and MIN_H or FULL_H)
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

-- ===== LOOP UTAMA =====
local gen = 0
local function startLoop()
    gen += 1
    local my = gen
    task.spawn(function()
        while alive and my == gen do
            lastTick = os.clock()
            ticks += 1
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

    -- GUI dihapus game? bangun ulang, status ON/OFF tetap dipertahankan
    if not ui.gui or not ui.gui.Parent then
        warn("[AutoAttack] GUI hilang, dibuat ulang")
        build()
    end

    -- loop macet lebih dari 5 detik? jalankan ulang
    if os.clock() - lastTick > 5 then
        warn("[AutoAttack] loop macet, dijalankan ulang")
        startLoop()
    end
end)
