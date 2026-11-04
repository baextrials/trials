local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

local enabled = false
local TIMEOUT = 1.5
local SKIP_COOLDOWN = 5
local FINISH_OFFSET = 10 -- jarak (stud) sebelum Finish, ubah sesuai selera
local skipped = {}
local connections = {}

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

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 170, 0, 76)
frame.Position = UDim2.new(0, 20, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 28)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
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
btn.Size = UDim2.new(1, -16, 0, 36)
btn.Position = UDim2.new(0, 8, 0, 4)
btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 15
btn.Text = "Auto TP: OFF"
btn.Parent = content
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

-- ========== DRAG (lewat judul, support sentuhan) ==========
do
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    table.insert(connections, UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end))
    table.insert(connections, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

-- ========== LOGIKA ==========
local function getPos(obj)
    return obj:GetPivot().Position
end

local function isCollected(obj)
    if not obj or not obj:IsDescendantOf(workspace) then
        return true
    end
    if obj:IsA("BasePart") then
        return obj.Transparency >= 1 or not obj.CanTouch
    end
    if obj:IsA("Model") then
        for _, p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 1 then
                return false
            end
        end
        return true
    end
    return false
end

-- return: daftar item siap diambil, jumlah item belum terambil yang sedang di-skip
local function collectItems()
    local list = {}
    local pending = 0
    local pickups = workspace:FindFirstChild("Pickups")
    if not pickups then return list, pending end
    local now = os.clock()
    for _, obj in ipairs(pickups:GetDescendants()) do
        if obj.Name == "Default"
            and (obj:IsA("BasePart") or obj:IsA("Model"))
            and not isCollected(obj) then
            if skipped[obj] and now - skipped[obj] < SKIP_COOLDOWN then
                pending += 1
            else
                table.insert(list, obj)
            end
        end
    end
    return list, pending
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

-- teleport ke beberapa stud sebelum Finish
local function goToFinish(hrp)
    local finish = workspace:FindFirstChild("Finish")
    if not finish then
        warn("Workspace.Finish tidak ditemukan")
        return false
    end
    local fpos = finish:GetPivot().Position
    local dir = hrp.Position - fpos
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 1 then
        dir = Vector3.new(0, 0, 1)
    end
    local target = fpos + dir.Unit * FINISH_OFFSET + Vector3.new(0, 3, 0)
    hrp.CFrame = CFrame.new(target)
    return true
end

local function run()
    while enabled do
        local hrp = getHRP()
        if not hrp then
            task.wait(0.5)
            continue
        end

        local items, pending = collectItems()

        if #items == 0 then
            if pending > 0 then
                task.wait(1) -- masih ada yang gagal diambil, tunggu dicoba ulang
                continue
            end
            -- semua Default sudah terambil -> ke Finish lalu berhenti
            if goToFinish(hrp) then
                setEnabled(false)
                btn.Text = "Selesai (OFF)"
            else
                task.wait(1)
            end
            return
        end

        local current = hrp.Position
        while enabled and #items > 0 do
            local idx, dist = nil, math.huge
            for i, obj in ipairs(items) do
                if not isCollected(obj) then
                    local d = (getPos(obj) - current).Magnitude
                    if d < dist then
                        idx, dist = i, d
                    end
                end
            end
            if not idx then break end

            local target = table.remove(items, idx)
            hrp = getHRP()
            if not hrp then break end

            local pos = getPos(target)
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
            current = pos

            local t0 = os.clock()
            while enabled and not isCollected(target) and os.clock() - t0 < TIMEOUT do
                task.wait(0.05)
            end
            if not isCollected(target) then
                skipped[target] = os.clock()
            end
        end
        task.wait(0.2)
    end
end

local function toggle()
    setEnabled(not enabled)
    if enabled then
        task.spawn(run)
    end
end

local function closeAll()
    enabled = false
    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    gui:Destroy()
end

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    frame.Size = minimized and UDim2.new(0, 170, 0, 28) or UDim2.new(0, 170, 0, 76)
    minBtn.Text = minimized and "+" or "–"
end)

closeBtn.MouseButton1Click:Connect(closeAll)
btn.MouseButton1Click:Connect(toggle)
