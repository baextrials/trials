local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local LP = Players.LocalPlayer

-- Anti double execution
local env = (getgenv and getgenv()) or _G
if env.__PUMPKIN_ADAPT_CLEANUP then pcall(env.__PUMPKIN_ADAPT_CLEANUP) end

-- ===== SETTING =====
local WALK_SPEED = 32          -- turunkan (28/24/20) kalau masih ditarik balik
local REACH_DIST = 2.5         -- jarak dianggap sampai di waypoint
local REPATH_TIME = 1.0        -- hitung ulang jalur tiap sekian detik
local STUCK_TIME = 0.5         -- cek macet tiap sekian detik
local STUCK_DIST = 1.0         -- bergerak kurang dari ini = macet
local AGENT_RADIUS = 4         -- makin besar makin menjauh dari tembok
local RAY_LEN = 8              -- panjang sinar deteksi tembok (studs)
local SIDE_ANGLE = 40          -- sudut sinar kiri/kanan (derajat)
local STEER_DIST = 10          -- seberapa jauh titik belok saat menghindar
local STEER_HOLD = 0.5         -- tahan arah belok sekian detik (anti goyang)
local TRAVEL_TIME = 12         -- maks detik menuju satu labu
local COLLECT_TIME = 2.5       -- maks detik berjalan di dekat labu
local SKIP_TIME = 4            -- detik labu gagal diabaikan
local PLAYER_AVOID = 5         -- labu sedekat ini dari pemain lain dilewati dulu
local MONSTER_NAMES = {}       -- diisi nanti kalau sudah tahu namanya
local MONSTER_SAFE_DIST = 60   -- labu dekat monster dilewati
local FLEE_DIST = 50           -- monster sedekat ini = kabur ke posisi aman
local DEBUG_PATH = false       -- true = print status jalur di console

local running, isOn = true, false
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

local function flatDist(a, b)
    return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function applySpeed(hum)
    if WALK_SPEED and hum.WalkSpeed ~= WALK_SPEED then
        hum.WalkSpeed = WALK_SPEED
    end
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
title.Text = "🎃 Pumpkin Fast Walk v2"
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
    statusLabel.Text = string.format("%s\nSpeed %s | Diambil: %d", t, tostring(WALK_SPEED or "normal"), collected)
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

-- ===== Raycast (deteksi tembok/dekorasi) =====
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
    rayParams.RespectCanCollide = true -- hanya objek solid yang dianggap penghalang
    return rayParams
end

local function rotateY(dir, deg)
    return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(dir)
end

-- Jarak bebas ke arah dir (cek setinggi lutut dan badan). RAY_LEN = bebas.
local HEIGHTS = { -1.5, 0.5 }
local function clearance(origin, dir)
    local params = getRayParams()
    local best = RAY_LEN
    for _, h in ipairs(HEIGHTS) do
        local hit = Workspace:Raycast(origin + Vector3.new(0, h, 0), dir * RAY_LEN, params)
        if hit and hit.Distance < best then best = hit.Distance end
    end
    return best
end

-- ===== Pathfinding =====
local function computePath(from, to)
    local path = PathfindingService:CreatePath({
        AgentRadius = AGENT_RADIUS,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 8,
    })
    local ok = pcall(function() path:ComputeAsync(from, to) end)
    if DEBUG_PATH then print("[Path]", ok and path.Status or "error") end
    if ok and path.Status == Enum.PathStatus.Success then
        local list = {}
        for i, w in ipairs(path:GetWaypoints()) do
            if i > 1 then table.insert(list, w) end
        end
        return list
    end
    return nil
end

-- ===== Jalan cepat + hindari tembok =====
local function travel(target, stopDist, maxTime, abortFn)
    local t0 = os.clock()
    local wps, lastCompute = nil, 0
    local lastPos, lastCheck = nil, os.clock()
    local steerAngle, steerUntil = 0, 0

    while running and isOn do
        local root, hum = getRoot(), getHumanoid()
        if not root or not hum or hum.Health <= 0 then return false end
        local now = os.clock()

        applySpeed(hum)

        if flatDist(root.Position, target) <= stopDist then return true end
        if now - t0 > maxTime then return false end
        if abortFn and abortFn() then return false end

        if not wps or now - lastCompute > REPATH_TIME then
            local list = computePath(root.Position, target)
            if list then
                wps = list
            elseif not wps then
                return false -- tidak ada jalur: labu dilewati, bukan ditabrak lurus
            end
            lastCompute = now
        end

        while wps[1] and flatDist(root.Position, wps[1].Position) < REACH_DIST do
            table.remove(wps, 1)
        end

        local wp = wps[1]
        local nextp = wp and wp.Position or target
        if wp and wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end

        -- Lapisan penghindar tembok (raycast)
        local flat = Vector3.new(nextp.X - root.Position.X, 0, nextp.Z - root.Position.Z)
        if flat.Magnitude > 0.5 then
            local dir = flat.Unit
            local origin = root.Position

            if now < steerUntil then
                -- tetap di arah belok sebentar supaya tidak goyang kiri-kanan
                nextp = origin + rotateY(dir, steerAngle) * STEER_DIST
            else
                local front = clearance(origin, dir)
                if front < RAY_LEN then
                    local left = clearance(origin, rotateY(dir, SIDE_ANGLE))
                    local right = clearance(origin, rotateY(dir, -SIDE_ANGLE))
                    local bestSide = math.max(left, right)

                    if bestSide < 3 then
                        -- buntu: loncat dan hitung ulang jalur
                        hum.Jump = true
                        wps = nil
                    else
                        steerAngle = (left >= right) and (SIDE_ANGLE + 15) or -(SIDE_ANGLE + 15)
                        steerUntil = now + STEER_HOLD
                        nextp = origin + rotateY(dir, steerAngle) * STEER_DIST
                    end
                end
            end
        end

        hum:MoveTo(nextp)

        -- deteksi macet
        if now - lastCheck > STUCK_TIME then
            if lastPos and (root.Position - lastPos).Magnitude < STUCK_DIST then
                hum.Jump = true
                wps = nil
            end
            lastPos, lastCheck = root.Position, now
        end

        setStatus("Menuju labu")
        task.wait(0.05)
    end
    return false
end

-- Berjalan di sekitar labu sampai labunya hilang
local function collectPhase(obj, part)
    local t0, k, lastK, lastTrig = os.clock(), 0, os.clock(), 0
    while running and isOn and os.clock() - t0 < COLLECT_TIME do
        if isGone(obj, part) then return true end
        local root, hum = getRoot(), getHumanoid()
        if not root or not hum then return false end
        applySpeed(hum)
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
        applySpeed(hum)
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

-- Tombol ON/OFF
connect(toggleBtn.MouseButton1Click, function()
    isOn = not isOn
    local root, hum = getRoot(), getHumanoid()
    if isOn then
        if root then safePos = root.Position; root.Anchored = false end
        collected = 0
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

print("[PumpkinFastWalk v2] Script aktif!")
