local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local LP = Players.LocalPlayer

-- Anti double execution
local env = (getgenv and getgenv()) or _G
if env.__PUMPKIN_ADAPT_CLEANUP then pcall(env.__PUMPKIN_ADAPT_CLEANUP) end

-- ===== SETTING =====
local START_HOP = 8            -- panjang loncatan awal (studs)
local MIN_HOP = 3              -- loncatan terpendek sebelum pindah ke jalan asli
local MAX_HOP = 25             -- loncatan terpanjang yang boleh dicoba
local HOP_INTERVAL = 0.12      -- jeda antar loncatan
local CHECK_DELAY = 0.3        -- tunggu sekian detik lalu cek apakah ditarik balik
local RUBBER_TOL = 3           -- selisih posisi (studs) yang dianggap ditarik balik
local WALK_FALLBACK_TIME = 8   -- lama jalan asli sebelum mencoba loncat lagi
local TRAVEL_TIME = 12         -- maks detik menuju satu labu
local COLLECT_TIME = 2.5       -- maks detik berjalan di dekat labu
local SKIP_TIME = 4            -- detik labu gagal diabaikan
local PLAYER_AVOID = 5         -- labu sedekat ini dari pemain lain dilewati dulu
local WALK_SPEED = nil         -- contoh: 20 (nil = tidak diubah)
local MONSTER_NAMES = {}       -- isi nama monster, contoh: {"Boogie", "Monster1"}
local MONSTER_SAFE_DIST = 45   -- labu dekat monster dilewati
local FLEE_DIST = 35           -- monster sedekat ini = kabur ke posisi aman

local running, isOn = true, false
local hopDist, rubberCount = START_HOP, 0
local mode, walkUntil = "hop", 0
local collected = 0
local safePos = nil
local ignore = {}
local monsters, lastMonsterScan = {}, 0
local conns = {}

local function connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(conns, c)
    return c
end

local function getRoot()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local ch = LP.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

local function pickPart(m)
    if m:IsA("BasePart") then return m end
    return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Part") or m:FindFirstChildWhichIsA("BasePart", true)
end

local function legLift()
    local root, hum = getRoot(), getHumanoid()
    return ((hum and hum.HipHeight) or 2) + (root and root.Size.Y / 2 or 1)
end

local function zeroVel(root)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function flatDist(a, b)
    return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- ================= GUI =================
local guiParent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "PumpkinAdapt_Gui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = guiParent

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 260, 0, 140)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.2, 0)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "🎃 Pumpkin Adaptive Hop"
title.TextColor3 = Color3.fromRGB(255, 165, 0)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 13
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 40)
statusLabel.Position = UDim2.new(0, 10, 0, 30)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: OFF"
statusLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.Parent = panel

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -20, 0, 35)
toggleBtn.Position = UDim2.new(0, 10, 0, 85)
toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
toggleBtn.Text = "Auto-Collect: OFF"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 13
toggleBtn.Parent = panel
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

local function setStatus(t)
    statusLabel.Text = string.format("%s\n%s %.1f | Diambil: %d", t, mode == "hop" and "Hop" or "Jalan", hopDist, collected)
end

-- ===== Monster =====
local function refreshMonsters()
    if #MONSTER_NAMES == 0 then return end
    local now = os.clock()
    if now - lastMonsterScan < 1 then return end
    lastMonsterScan = now
    monsters = {}
    local set = {}
    for _, n in ipairs(MONSTER_NAMES) do set[n] = true end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if set[d.Name] and (d:IsA("Model") or d:IsA("BasePart")) then
            local p = pickPart(d)
            if p then table.insert(monsters, p) end
        end
    end
end

local function monsterWithin(pos, dist)
    for _, p in ipairs(monsters) do
        if p.Parent and (p.Position - pos).Magnitude < dist then return true end
    end
    return false
end

local function playerNear(pos, dist)
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP and pl.Character then
            local r = pl.Character:FindFirstChild("HumanoidRootPart")
            if r and (r.Position - pos).Magnitude < dist then return true end
        end
    end
    return false
end

-- ===== Labu =====
local function isGone(obj, part)
    return (not obj) or (not obj.Parent) or (not part) or (not part.Parent)
        or (not part:IsDescendantOf(Workspace)) or part.Transparency >= 1
end

local function findNearest()
    local root = getRoot()
    if not root then return nil end
    refreshMonsters()
    local now = os.clock()

    local function search(avoidPlayers)
        local best, bestPart, bestDist = nil, nil, math.huge
        local function check(obj)
            local part = pickPart(obj)
            if not part or not part.Parent then return end
            if ignore[obj] and ignore[obj] > now then return end
            if monsterWithin(part.Position, MONSTER_SAFE_DIST) then return end
            if avoidPlayers and playerNear(part.Position, PLAYER_AVOID) then return end
            local d = (part.Position - root.Position).Magnitude
            if d < bestDist then best, bestPart, bestDist = obj, part, d end
        end
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj.Name == "TreatPumpkinLocal" then check(obj) end
        end
        local folder = Workspace:FindFirstChild("LocalPumpkins")
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do check(obj) end
        end
        return best, bestPart
    end

    local o, p = search(true)
    if o then return o, p end
    return search(false)
end

local function triggerPickup(obj, part, root)
    if fireproximityprompt then
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("ProximityPrompt") then pcall(fireproximityprompt, d) end
        end
    end
    if firetouchinterest then
        pcall(function()
            firetouchinterest(root, part, 0)
            firetouchinterest(root, part, 1)
        end)
    end
end

-- ===== Path & ray =====
local rayParams, rayAt = nil, 0
local function getRayParams()
    local now = os.clock()
    if rayParams and now - rayAt < 1 then return rayParams end
    rayAt = now
    local list = { LP.Character }
    local folder = Workspace:FindFirstChild("LocalPumpkins")
    if folder then table.insert(list, folder) end
    for _, o in ipairs(Workspace:GetChildren()) do
        if o.Name == "TreatPumpkinLocal" then table.insert(list, o) end
    end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP and pl.Character then table.insert(list, pl.Character) end
    end
    rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = list
    return rayParams
end

local function computePath(from, to)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6,
    })
    local ok = pcall(function() path:ComputeAsync(from, to) end)
    if ok and path.Status == Enum.PathStatus.Success then
        local list = {}
        for i, w in ipairs(path:GetWaypoints()) do
            if i > 1 then table.insert(list, w.Position) end
        end
        return list
    end
    return nil
end

-- ===== Gerak adaptif =====
-- Loncat pendek lewat waypoint; kalau ditarik balik server, loncatan dipendekkan,
-- dan kalau tetap ditolak, pindah ke jalan asli.
local function travel(target, stopDist, maxTime, abortFn)
    local t0 = os.clock()
    local wps, lastCompute = nil, 0
    local lastPos, lastMoveT = nil, os.clock()

    while running and isOn do
        local root, hum = getRoot(), getHumanoid()
        if not root or not hum or hum.Health <= 0 then return false end
        local now = os.clock()

        if flatDist(root.Position, target) <= stopDist then return true end
        if now - t0 > maxTime then return false end
        if abortFn and abortFn() then return false end

        if not wps or now - lastCompute > 2.5 then
            wps = computePath(root.Position, target) or { target }
            lastCompute = now
        end
        while wps[1] and flatDist(root.Position, wps[1]) < 2.5 do table.remove(wps, 1) end
        local nextp = wps[1] or target

        if mode == "walk" and now > walkUntil then
            mode = "hop"
            hopDist = MIN_HOP * 1.5
            rubberCount = 0
        end

        if mode == "hop" then
            local stand = nextp + Vector3.new(0, legLift(), 0)
            local delta = stand - root.Position
            local total = delta.Magnitude
            local step = math.min(hopDist, total)

            -- jangan menembus dinding: pendekkan kalau ada penghalang
            local hit = Workspace:Raycast(root.Position, delta.Unit * step, getRayParams())
            if hit then step = math.max(0, hit.Distance - 1.5) end

            if step > 0.3 then
                local newPos = root.Position + delta.Unit * step
                local flat = Vector3.new(delta.X, 0, delta.Z)
                local look = flat.Magnitude > 0.1 and (newPos + flat) or (newPos + root.CFrame.LookVector)
                root.CFrame = CFrame.lookAt(newPos, Vector3.new(look.X, newPos.Y, look.Z))
                zeroVel(root)
                hum:MoveTo(nextp)

                task.wait(CHECK_DELAY)
                local r2 = getRoot()
                if not r2 then return false end
                if (r2.Position - newPos).Magnitude > RUBBER_TOL then
                    -- ditarik balik server
                    rubberCount += 1
                    hopDist = math.max(MIN_HOP, hopDist * 0.6)
                    if hopDist <= MIN_HOP and rubberCount >= 3 then
                        mode = "walk"
                        walkUntil = os.clock() + WALK_FALLBACK_TIME
                    end
                else
                    rubberCount = math.max(0, rubberCount - 1)
                    hopDist = math.min(MAX_HOP, hopDist * 1.15)
                end
                setStatus("Menuju labu")
                task.wait(HOP_INTERVAL)
            else
                -- terhalang: pakai jalan asli sebentar
                hum:MoveTo(nextp)
                hum.Jump = true
                task.wait(0.2)
            end
        else
            hum:MoveTo(nextp)
            task.wait(0.15)
            if not lastPos or now - lastMoveT > 0.6 then
                if lastPos and (root.Position - lastPos).Magnitude < 0.3 then
                    hum.Jump = true
                    wps = nil -- hitung ulang jalur
                end
                lastPos, lastMoveT = root.Position, now
            end
            setStatus("Berjalan ke labu")
        end
    end
    return false
end

-- Berjalan asli di sekitar labu sampai labunya hilang
local function collectPhase(obj, part)
    local t0, k, lastK, lastTrig = os.clock(), 0, os.clock(), 0
    while running and isOn and os.clock() - t0 < COLLECT_TIME do
        if isGone(obj, part) then return true end
        local root, hum = getRoot(), getHumanoid()
        if not root or not hum then return false end
        local now = os.clock()
        if now - lastK > 0.5 then lastK = now; k += 1 end
        local a = k * math.pi / 2
        local p = part.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 1.5
        hum:MoveTo(p)
        if now - lastTrig > 0.5 then lastTrig = now; triggerPickup(obj, part, root) end
        setStatus("Mengambil labu")
        task.wait(0.1)
    end
    return isGone(obj, part)
end

-- ================= LOOP UTAMA =================
task.spawn(function()
    while running do
        task.wait(0.1)
        if not isOn then continue end

        local root, hum = getRoot(), getHumanoid()
        if not root or not hum or hum.Health <= 0 then
            statusLabel.Text = "Karakter tidak siap!"
            continue
        end
        if root.Anchored then root.Anchored = false end
        if WALK_SPEED and hum.WalkSpeed ~= WALK_SPEED then hum.WalkSpeed = WALK_SPEED end
        refreshMonsters()

        -- Kabur kalau monster mendekat
        if safePos and monsterWithin(root.Position, FLEE_DIST) then
            setStatus("Monster dekat, kabur")
            travel(safePos, 4, 10, nil)
            while running and isOn do
                local r = getRoot()
                if not r or not monsterWithin(r.Position, FLEE_DIST + 15) then break end
                task.wait(0.3)
            end
            continue
        end

        local obj, part = findNearest()
        if not obj then
            setStatus("Tidak ada labu")
            task.wait(0.3)
            continue
        end

        local arrived = travel(part.Position, 3.5, TRAVEL_TIME, function()
            local r = getRoot()
            return isGone(obj, part) or (r and monsterWithin(r.Position, FLEE_DIST))
        end)

        if isGone(obj, part) then
            collected += 1
        elseif arrived then
            if collectPhase(obj, part) then
                collected += 1
            else
                ignore[obj] = os.clock() + SKIP_TIME
            end
        elseif not (getRoot() and monsterWithin(getRoot().Position, FLEE_DIST)) then
            ignore[obj] = os.clock() + SKIP_TIME
        end
    end
end)

-- Tombol: satu-satunya yang bisa ON/OFF
connect(toggleBtn.MouseButton1Click, function()
    isOn = not isOn
    local root, hum = getRoot(), getHumanoid()
    if isOn then
        if root then safePos = root.Position; root.Anchored = false end
        collected = 0
        mode, hopDist, rubberCount = "hop", START_HOP, 0
        toggleBtn.Text = "Auto-Collect: ON"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        statusLabel.Text = "Aktif!"
    else
        if root then root.Anchored = false end
        if hum and root then hum:MoveTo(root.Position) end
        toggleBtn.Text = "Auto-Collect: OFF"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
        statusLabel.Text = "Dimatikan manual."
    end
end)

-- Cleanup
env.__PUMPKIN_ADAPT_CLEANUP = function()
    running, isOn = false, false
    local root = getRoot()
    if root then root.Anchored = false end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if gui then gui:Destroy() end
end

print("[PumpkinAdaptive] Script aktif!")
