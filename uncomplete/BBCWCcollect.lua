local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local player = Players.LocalPlayer

local enabled = false
local TIMEOUT = 1.5
local MAX_TRY = 2
local CP_WAIT = 0.5
local FINISH_OFFSET = 10   -- jarak (stud) sebelum Finish
local DANGER_MARGIN = 6    -- jarak aman (stud) dari part cahaya
local connections = {}

local initHidden = {}
local attempts = {}
local gaveUp = {}

-- ========== GUI ==========
local gui = Instance.new("ScreenGui")
gui.Name = "TPDefaultGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999

local function mountGui()
    local ok = pcall(function()
        if gethui then
            gui.Parent = gethui()
        else
            gui.Parent = game:GetService("CoreGui")
        end
    end)
    if not ok or not gui.Parent then
        gui.Parent = player:WaitForChild("PlayerGui")
    end
end
mountGui()

local FULL_H = 150

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 190, 0, FULL_H)
frame.Position = UDim2.new(0, 20, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextButton")
title.Size = UDim2.new(1, -70, 0, 28)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
title.AutoButtonColor = false
title.Active = true
title.Text = "Auto TP Default"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 22)
closeBtn.Position = UDim2.new(1, -32, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(190, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 28, 0, 22)
minBtn.Position = UDim2.new(1, -64, 0, 3)
minBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
minBtn.Text = "–"
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 14
minBtn.Parent = frame
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -30)
content.Position = UDim2.new(0, 0, 0, 30)
content.BackgroundTransparency = 1
content.Parent = frame

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -16, 0, 34)
btn.Position = UDim2.new(0, 8, 0, 2)
btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 15
btn.Text = "Auto TP: OFF"
btn.Parent = content
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 30)
status.Position = UDim2.new(0, 8, 0, 38)
status.BackgroundTransparency = 1
status.Text = "Siap"
status.TextColor3 = Color3.fromRGB(170, 170, 180)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = content

local finishBtn = Instance.new("TextButton")
finishBtn.Size = UDim2.new(1, -16, 0, 32)
finishBtn.Position = UDim2.new(0, 8, 0, 72)
finishBtn.BackgroundColor3 = Color3.fromRGB(60, 110, 200)
finishBtn.TextColor3 = Color3.new(1, 1, 1)
finishBtn.Font = Enum.Font.GothamBold
finishBtn.TextSize = 14
finishBtn.Text = "Finish"
finishBtn.Parent = content
Instance.new("UICorner", finishBtn).CornerRadius = UDim.new(0, 6)

local confirmFrame = Instance.new("Frame")
confirmFrame.Size = UDim2.new(1, -16, 0, 48)
confirmFrame.Position = UDim2.new(0, 8, 0, 70)
confirmFrame.BackgroundTransparency = 1
confirmFrame.Visible = false
confirmFrame.Parent = content

local confirmLabel = Instance.new("TextLabel")
confirmLabel.Size = UDim2.new(1, 0, 0, 16)
confirmLabel.BackgroundTransparency = 1
confirmLabel.Text = "Teleport ke Finish?"
confirmLabel.TextColor3 = Color3.new(1, 1, 1)
confirmLabel.Font = Enum.Font.GothamBold
confirmLabel.TextSize = 12
confirmLabel.Parent = confirmFrame

local yesBtn = Instance.new("TextButton")
yesBtn.Size = UDim2.new(0.5, -3, 0, 28)
yesBtn.Position = UDim2.new(0, 0, 0, 20)
yesBtn.BackgroundColor3 = Color3.fromRGB(50, 170, 70)
yesBtn.Text = "Ya"
yesBtn.TextColor3 = Color3.new(1, 1, 1)
yesBtn.Font = Enum.Font.GothamBold
yesBtn.TextSize = 14
yesBtn.Parent = confirmFrame
Instance.new("UICorner", yesBtn).CornerRadius = UDim.new(0, 6)

local noBtn = Instance.new("TextButton")
noBtn.Size = UDim2.new(0.5, -3, 0, 28)
noBtn.Position = UDim2.new(0.5, 3, 0, 20)
noBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
noBtn.Text = "Tidak"
noBtn.TextColor3 = Color3.new(1, 1, 1)
noBtn.Font = Enum.Font.GothamBold
noBtn.TextSize = 14
noBtn.Parent = confirmFrame
Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 6)

local function setStatus(t)
    status.Text = t
end

-- ========== DRAG (tidak menggeser kamera game) ==========
local function unbindSink()
    pcall(function() CAS:UnbindAction("TPDragSink") end)
end

do
    local dragging, dragStart, startPos, dragInput = false, nil, nil, nil

    local function endDrag()
        dragging = false
        dragInput = nil
        unbindSink()
    end

    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = frame.Position
            pcall(function()
                CAS:BindActionAtPriority("TPDragSink", function()
                    return Enum.ContextActionResult.Sink
                end, false, Enum.ContextActionPriority.High.Value,
                    Enum.UserInputType.Touch, Enum.UserInputType.MouseButton1)
            end)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    endDrag()
                end
            end)
        end
    end)

    table.insert(connections, UIS.InputChanged:Connect(function(input)
        if dragging and (input == dragInput
            or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end))

    table.insert(connections, UIS.InputEnded:Connect(function(input)
        if input == dragInput then
            endDrag()
        end
    end))
end

-- ========== LOGIKA ==========
local function getPos(obj)
    if obj:IsA("PVInstance") then
        return obj:GetPivot().Position
    end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("BasePart") then
            return d.Position
        end
    end
    return nil
end

-- ===== FINISH: cari + cache posisi (anti streaming) =====
local finishCache = nil

local function findFinishInstance()
    return workspace:FindFirstChild("Finish") or workspace:FindFirstChild("Finish", true)
end

-- return: posisi (bisa dari cache), instance (bisa nil)
local function getFinishPos()
    local inst = findFinishInstance()
    if inst then
        local p = getPos(inst)
        if p then
            finishCache = p
            return p, inst
        end
    end
    return finishCache, inst
end

getFinishPos() -- cache awal kalau Finish sudah termuat

table.insert(connections, workspace.DescendantAdded:Connect(function(d)
    if d.Name == "Finish" then
        task.delay(0.5, function()
            getFinishPos()
        end)
    end
end))

local function requestStream(pos)
    pcall(function()
        player:RequestStreamingAround(pos)
    end)
end

local function isHidden(obj)
    if obj:IsA("BasePart") then
        return obj.Transparency >= 1 or not obj.CanTouch
    end
    local anyPart = false
    for _, p in ipairs(obj:GetDescendants()) do
        if p:IsA("BasePart") then
            anyPart = true
            if p.Transparency < 1 and p.CanTouch then
                return false
            end
        end
    end
    return anyPart
end

local function isCollected(obj)
    if not obj or not obj:IsDescendantOf(workspace) then
        return true
    end
    if initHidden[obj] then
        return false
    end
    return isHidden(obj)
end

local function collectItems()
    local list, total, remaining = {}, 0, 0
    local pickups = workspace:FindFirstChild("Pickups")
    if not pickups then return list, 0, 0 end
    for _, obj in ipairs(pickups:GetDescendants()) do
        if obj.Name == "Default" and getPos(obj) then
            total += 1
            if initHidden[obj] == nil then
                initHidden[obj] = isHidden(obj)
            end
            if not isCollected(obj) and not gaveUp[obj] then
                remaining += 1
                table.insert(list, obj)
            end
        end
    end
    return list, total, remaining
end

local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function setEnabled(state)
    enabled = state
    btn.Text = "Auto TP: " .. (enabled and "ON" or "OFF")
    btn.BackgroundColor3 = enabled and Color3.fromRGB(50, 170, 70) or Color3.fromRGB(200, 50, 50)
end

local function getCheckpoints()
    local result = {}
    local level = workspace:FindFirstChild("Level")
    local folder = level and level:FindFirstChild("Checkpoints")
    if not folder then return result end

    local finishPos = getFinishPos()

    for _, cp in ipairs(folder:GetChildren()) do
        local button = cp:FindFirstChild("Button", true)
        local pos = (button and getPos(button)) or getPos(cp)
        if pos then
            table.insert(result, {
                obj = cp,
                pos = pos,
                num = tonumber(cp.Name:match("(%d+)$")) or 0,
                dist = finishPos and (pos - finishPos).Magnitude or 0,
            })
        end
    end

    table.sort(result, function(a, b)
        if a.num ~= b.num then return a.num < b.num end
        return a.dist > b.dist
    end)
    return result
end

-- ========== TITIK AMAN DARI CAHAYA ==========
local function getDangerParts()
    local parts = {}
    local level = workspace:FindFirstChild("Level")
    local obstacles = level and level:FindFirstChild("Obstacles")
    local root = obstacles and obstacles:FindFirstChild("DeadlyLight")
    if root then
        if root:IsA("BasePart") then
            table.insert(parts, root)
        end
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("BasePart") then
                table.insert(parts, d)
            end
        end
    end
    return parts
end

local function isDangerous(point, dangers)
    local m = Vector3.new(DANGER_MARGIN, DANGER_MARGIN, DANGER_MARGIN)
    for _, part in ipairs(dangers) do
        local rel = part.CFrame:PointToObjectSpace(point)
        local h = part.Size / 2 + m
        if math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z then
            return true
        end
    end
    return false
end

local ANGLES = {0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180}

local function findSafeSpot(fpos, baseDir, dangers)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    if player.Character then table.insert(ignore, player.Character) end
    for _, p in ipairs(dangers) do table.insert(ignore, p) end
    params.FilterDescendantsInstances = ignore

    local radii = {FINISH_OFFSET, FINISH_OFFSET + 4, FINISH_OFFSET + 8, math.max(FINISH_OFFSET - 4, 3)}
    for _, r in ipairs(radii) do
        for _, a in ipairs(ANGLES) do
            local offset = CFrame.Angles(0, math.rad(a), 0) * (baseDir * r)
            local origin = Vector3.new(fpos.X + offset.X, fpos.Y + 4, fpos.Z + offset.Z)
            local hit = workspace:Raycast(origin, Vector3.new(0, -20, 0), params)
            if hit then
                local ground = hit.Position
                if not isDangerous(ground + Vector3.new(0, 1, 0), dangers)
                    and not isDangerous(ground + Vector3.new(0, 3, 0), dangers) then
                    return ground + Vector3.new(0, 3, 0)
                end
            end
        end
    end
    return nil
end

-- teleport ke dekat Finish, menghindari cahaya
local function goToFinish(hrp)
    local fpos, inst = getFinishPos()

    -- belum ketemu: tunggu sebentar kalau-kalau sedang dimuat
    if not fpos then
        setStatus("Mencari Finish...")
        local t0 = os.clock()
        while os.clock() - t0 < 3 and not fpos do
            task.wait(0.25)
            fpos, inst = getFinishPos()
        end
    end

    if not fpos then
        if inst then
            setStatus("Finish ada (" .. inst.ClassName .. ") tapi tidak punya part/posisi")
        elseif workspace.StreamingEnabled then
            setStatus("Finish belum dimuat (Streaming aktif). Dekati area Finish dulu, lalu coba lagi")
        else
            setStatus("Tidak ada objek bernama Finish di Workspace")
        end
        return false
    end

    -- pastikan area Finish sudah dimuat sebelum raycast
    requestStream(fpos)
    task.wait(0.6)

    local dir = hrp.Position - fpos
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 1 then
        dir = Vector3.new(0, 0, 1)
    end

    local dangers = getDangerParts()
    local spot = findSafeSpot(fpos, dir.Unit, dangers)
    if not spot then
        setStatus("Tidak ada titik aman dekat Finish (cahaya: " .. #dangers .. " part)")
        return false
    end
    hrp.CFrame = CFrame.new(spot)
    return true
end

local function run()
    local visited = {}

    while enabled do
        local hrp = getHRP()
        if not hrp then
            setStatus("Menunggu karakter...")
            task.wait(0.5)
            continue
        end

        local items, total, remaining = collectItems()
        local cps = getCheckpoints()
        local current = hrp.Position

        setStatus(("Default: %d total, %d sisa | CP: %d"):format(total, remaining, #cps))

        local best, bestDist, bestKind = nil, math.huge, nil
        for _, obj in ipairs(items) do
            local p = getPos(obj)
            if p then
                local d = (p - current).Magnitude
                if d < bestDist then
                    best, bestDist, bestKind = obj, d, "default"
                end
            end
        end
        for _, cp in ipairs(cps) do
            if not visited[cp.obj] then
                local d = (cp.pos - current).Magnitude
                if d < bestDist then
                    best, bestDist, bestKind = cp, d, "checkpoint"
                end
            end
        end

        if not best then
            local last = cps[#cps]
            if last then
                hrp.CFrame = CFrame.new(last.pos + Vector3.new(0, 3, 0))
                setStatus("Selesai di " .. last.obj.Name)
            else
                if goToFinish(hrp) then
                    setStatus("Checkpoint tidak ada, ke dekat Finish")
                end
            end
            setEnabled(false)
            return
        end

        if bestKind == "checkpoint" then
            visited[best.obj] = true
            hrp.CFrame = CFrame.new(best.pos + Vector3.new(0, 3, 0))
            setStatus("Checkpoint: " .. best.obj.Name)
            task.wait(CP_WAIT)
        else
            local target = best
            hrp.CFrame = CFrame.new(getPos(target) + Vector3.new(0, 3, 0))

            local t0 = os.clock()
            while enabled and not isCollected(target) and os.clock() - t0 < TIMEOUT do
                task.wait(0.05)
            end
            if not isCollected(target) then
                attempts[target] = (attempts[target] or 0) + 1
                if attempts[target] >= MAX_TRY then
                    gaveUp[target] = true
                end
            end
        end
    end
end

local function toggle()
    setEnabled(not enabled)
    if enabled then
        setStatus("Mulai...")
        task.spawn(function()
            local ok, err = pcall(run)
            if not ok then
                setStatus("Error: " .. tostring(err))
                setEnabled(false)
            end
        end)
    end
end

-- ========== TOMBOL FINISH + KONFIRMASI ==========
local function showConfirm(show)
    confirmFrame.Visible = show
    finishBtn.Visible = not show
end

finishBtn.MouseButton1Click:Connect(function()
    showConfirm(true)
end)

noBtn.MouseButton1Click:Connect(function()
    showConfirm(false)
end)

yesBtn.MouseButton1Click:Connect(function()
    showConfirm(false)
    setEnabled(false)
    local hrp = getHRP()
    if not hrp then
        setStatus("Karakter tidak ditemukan")
        return
    end
    task.spawn(function()
        local ok, err = pcall(function()
            if goToFinish(hrp) then
                setStatus("Teleport ke Finish (aman dari cahaya)")
            end
        end)
        if not ok then
            setStatus("Error: " .. tostring(err))
        end
    end)
end)

local function closeAll()
    enabled = false
    unbindSink()
    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    gui:Destroy()
end

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    frame.Size = minimized and UDim2.new(0, 190, 0, 28) or UDim2.new(0, 190, 0, FULL_H)
    minBtn.Text = minimized and "+" or "–"
end)

closeBtn.MouseButton1Click:Connect(closeAll)
btn.MouseButton1Click:Connect(toggle)
