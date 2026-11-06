--[[ Movement Menu v8 - Custom GUI
     Minimize = jadi teks transparan, Close = konfirmasi Yes/No
     v8: GUI posisi absolut (piksel) + input GUI tidak tembus ke game (kamera tidak ikut geser),
         Air Walk diperbaiki (lantai tidak turun sendiri saat melayang) ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ================= STATE =================
local flySpeed, walkSpeedValue, jumpPowerValue = 50, 16, 50
local flying, noclip, infJump, walkEnabled = false, false, false, false
local flyConn, noclipConn, bv, bg
local conns = {}

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ================= FEATURES =================
local upHeld, downHeld = false, false -- tombol naik/turun di layar (mobile)

local function stopFly()
    upHeld, downHeld = false, false
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if bv then bv:Destroy() bv = nil end
    if bg then bg:Destroy() bg = nil end
    local h = getHum()
    if h then h.PlatformStand = false end
end

local function startFly()
    stopFly()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = getHum()
    if not (hrp and humanoid) then return end

    humanoid.PlatformStand = true
    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp

    bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 9e4
    bg.Parent = hrp

    flyConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
        local moveDir = Vector3.zero

        local md = humanoid.MoveDirection
        if md.Magnitude > 0.05 then
            local flatLook = Vector3.new(look.X, 0, look.Z)
            local flatRight = Vector3.new(right.X, 0, right.Z)
            local f = flatLook.Magnitude > 0.01 and md:Dot(flatLook.Unit) or 0
            local s = flatRight.Magnitude > 0.01 and md:Dot(flatRight.Unit) or 0
            moveDir = moveDir + look * f + right * s
        end

        if UIS:IsKeyDown(Enum.KeyCode.Space) or upHeld then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or downHeld then moveDir = moveDir - Vector3.new(0, 1, 0) end

        bv.Velocity = moveDir * flySpeed
        bg.CFrame = cam.CFrame
    end)
end

local function setNoclip(state)
    noclip = state
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                end
            end
        end)
    end
end

local function applyStats()
    local h = getHum()
    if not h then return end
    h.WalkSpeed = walkEnabled and walkSpeedValue or 16
    h.UseJumpPower = true
    h.JumpPower = jumpPowerValue
end

-- Air Walk: lantai tak terlihat di bawah kaki, jadi kamu bisa berjalan di udara.
local airWalkOn = false
local airConn, airPart, airLevel
local AIR_SNAP = 4   -- hanya menempel ke pijakan asli kalau jaraknya dekat (tangga/lereng).
                    -- Sebelumnya 12: lantai ikut turun ke tanah sehingga Air Walk gagal melayang.
local AIR_STEP = 3
local AIR_VSPEED = 80   -- kecepatan naik/turun lantai udara (sebelumnya 20), bisa diatur lewat slider

local function feetOffset(h, hrp)
    if h.RigType == Enum.HumanoidRigType.R6 then return 3 end
    return h.HipHeight + hrp.Size.Y / 2
end

local function setAirWalk(state)
    airWalkOn = state
    if airConn then airConn:Disconnect() airConn = nil end
    if airPart then airPart:Destroy() airPart = nil end
    airLevel = nil
    if not state then return end

    airPart = Instance.new("Part")
    airPart.Name = "AirFloor"
    airPart.Size = Vector3.new(12, 1, 12)
    airPart.Anchored = true
    airPart.CanTouch = false
    airPart.Transparency = 1
    airPart.Parent = workspace

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true

    airConn = RunService.Heartbeat:Connect(function(dt)
        local h = getHum()
        local hrp = h and h.RootPart
        if not hrp or not airPart then return end
        local feetY = hrp.Position.Y - feetOffset(h, hrp)

        if flying then
            airPart.CanCollide = false
            airLevel = feetY
            return
        end
        airPart.CanCollide = true
        if not airLevel then airLevel = feetY end

        local up = UIS:IsKeyDown(Enum.KeyCode.E) or upHeld
        local down = UIS:IsKeyDown(Enum.KeyCode.Q) or downHeld
        if up or down then
            airLevel = airLevel + ((up and 1 or 0) - (down and 1 or 0)) * AIR_VSPEED * dt
        else
            params.FilterDescendantsInstances = { LocalPlayer.Character, airPart }
            local origin = Vector3.new(hrp.Position.X, airLevel + AIR_STEP, hrp.Position.Z)
            local hit = workspace:Raycast(origin, Vector3.new(0, -(AIR_SNAP + AIR_STEP), 0), params)
            if hit then
                airLevel = airLevel + (hit.Position.Y - airLevel) * math.clamp(dt * 12, 0, 1)
            end
        end
        airPart.CFrame = CFrame.new(hrp.Position.X, airLevel - 0.5, hrp.Position.Z)
    end)
end

-- Infinite Jump
local lastJump = 0
local JUMP_COOLDOWN = 0.2

local function doInfJump()
    local h = getHum()
    local hrp = h and h.RootPart
    if not hrp then return end
    local now = os.clock()
    if now - lastJump < JUMP_COOLDOWN then return end
    lastJump = now
    local v = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(v.X, jumpPowerValue, v.Z)
end

table.insert(conns, UIS.JumpRequest:Connect(function()
    if infJump and not flying then doInfJump() end
end))

local AIR_SPEED_MULT = 1.25

table.insert(conns, RunService.Heartbeat:Connect(function()
    if not infJump or flying then return end
    local h = getHum()
    local hrp = h and h.RootPart
    if not hrp then return end

    local md = h.MoveDirection
    if md.Magnitude > 0.05 and h.FloorMaterial == Enum.Material.Air then
        local target = md * (h.WalkSpeed * AIR_SPEED_MULT)
        local v = hrp.AssemblyLinearVelocity
        hrp.AssemblyLinearVelocity = Vector3.new(target.X, v.Y, target.Z)
    end

    if h.Jump or UIS:IsKeyDown(Enum.KeyCode.Space) then doInfJump() end
end))

-- Spider Climb: menempel & memanjat tembok tanpa jatuh.
-- Dorong joystick/WASD ke arah tembok = naik. Lepas input = menempel di tembok (tidak jatuh).
local climbOn = false
local CLIMB_SPEED = 40   -- kecepatan memanjat (stud/detik), bisa diatur lewat slider
local CLIMB_DIST = 3     -- jarak deteksi tembok di depan karakter
local climbParams = RaycastParams.new()
climbParams.FilterType = Enum.RaycastFilterType.Exclude

table.insert(conns, RunService.Heartbeat:Connect(function()
    if not climbOn or flying then return end
    local h = getHum()
    local hrp = h and h.RootPart
    if not hrp then return end

    climbParams.FilterDescendantsInstances = { LocalPlayer.Character }
    local md = h.MoveDirection
    local pushing = md.Magnitude > 0.05
    local dir
    if pushing then
        dir = md.Unit
    else
        local lv = hrp.CFrame.LookVector
        dir = Vector3.new(lv.X, 0, lv.Z)
        if dir.Magnitude < 0.01 then return end
        dir = dir.Unit
    end

    -- cek tembok di tiga ketinggian (kaki, badan, kepala) supaya stabil saat menempel
    local hit
    for _, yOff in ipairs({ -1.5, 0, 1.5 }) do
        local r = workspace:Raycast(hrp.Position + Vector3.new(0, yOff, 0), dir * CLIMB_DIST, climbParams)
        if r and math.abs(r.Normal.Y) < 0.5 then hit = r break end
    end

    if hit then
        hrp.AssemblyLinearVelocity = Vector3.new(0, pushing and CLIMB_SPEED or 0, 0)
    end
end))

table.insert(conns, LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid")
    task.wait(0.5)
    airLevel = nil
    applyStats()
    if flying then startFly() end
end))

-- ================= GUI HELPERS =================
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local old = parentGui:FindFirstChild("MovementMenuGUI")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "MovementMenuGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true      -- koordinat absolut dari pojok kiri atas layar
gui.DisplayOrder = 999
gui.Parent = parentGui

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = o
end

local function makeDraggable(handle, target)
    local dragging, startPos, startInput
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, target.Position, i.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            local vp = gui.AbsoluteSize
            local nx = math.clamp(startPos.X.Offset + d.X, 0, math.max(0, vp.X - target.AbsoluteSize.X))
            local ny = math.clamp(startPos.Y.Offset + d.Y, 0, math.max(0, vp.Y - target.AbsoluteSize.Y))
            target.Position = UDim2.fromOffset(nx, ny)
        end
    end)
end

local function button(parent, text, size, pos, color)
    local b = Instance.new("TextButton")
    b.Size, b.Position, b.Text = size, pos, text
    b.BackgroundColor3 = color or Color3.fromRGB(45, 45, 55)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font, b.TextSize = Enum.Font.GothamBold, 14
    b.AutoButtonColor = true
    b.Parent = parent
    corner(b, 6)
    return b
end

-- ================= TOMBOL NAIK/TURUN (MOBILE) =================
local flyPad = Instance.new("Frame")
flyPad.Size = UDim2.new(0, 70, 0, 150)
flyPad.AnchorPoint = Vector2.new(1, 0.5)
flyPad.Position = UDim2.new(1, -20, 0.5, 0)
flyPad.BackgroundTransparency = 1
flyPad.Visible = false
flyPad.Parent = gui

local function holdButton(text, yPos, setHeld)
    local b = button(flyPad, text, UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 0, yPos), Color3.fromRGB(35, 35, 45))
    b.BackgroundTransparency = 0.25
    b.TextSize = 28
    b.AutoButtonColor = false
    b.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            setHeld(true)
            b.BackgroundColor3 = Color3.fromRGB(90, 140, 255)
            local ch
            ch = i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    setHeld(false)
                    b.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                    ch:Disconnect()
                end
            end)
        end
    end)
    return b
end

holdButton("▲", 0, function(v) upHeld = v end)
holdButton("▼", 80, function(v) downHeld = v end)

-- ================= MAIN WINDOW =================
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 290, 0, 340)
do -- posisi awal absolut (piksel), di tengah layar
    local vp = gui.AbsoluteSize
    if vp.X == 0 then vp = workspace.CurrentCamera.ViewportSize end
    main.Position = UDim2.fromOffset(math.floor((vp.X - 290) / 2), math.floor((vp.Y - 340) / 2))
end
main.Active = true  -- sentuhan/klik di GUI tidak diteruskan ke game (kamera tidak ikut bergeser)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
main.Parent = gui
corner(main, 10)

local top = Instance.new("Frame")
top.Active = true
top.Size = UDim2.new(1, 0, 0, 36)
top.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
top.Parent = main
corner(top, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Movement Menu v8"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font, title.TextSize = Enum.Font.GothamBold, 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local minBtn = button(top, "–", UDim2.new(0, 30, 0, 26), UDim2.new(1, -70, 0, 5))
local closeBtn = button(top, "X", UDim2.new(0, 30, 0, 26), UDim2.new(1, -35, 0, 5), Color3.fromRGB(170, 50, 50))
makeDraggable(top, main)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -48)
list.Position = UDim2.new(0, 8, 0, 42)
list.BackgroundTransparency = 1
list.ScrollBarThickness = 3
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.BorderSizePixel = 0
list.Active = true
list.Parent = main
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local orderCount = 0
local function nextOrder()
    orderCount = orderCount + 1
    return orderCount
end

local function toggle(name, cb)
    local state = false
    local b = button(list, name .. ": OFF", UDim2.new(1, -6, 0, 34), UDim2.new())
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.LayoutOrder = nextOrder()
    local pad = Instance.new("UIPadding", b)
    pad.PaddingLeft = UDim.new(0, 10)
    b.MouseButton1Click:Connect(function()
        state = not state
        b.Text = name .. (state and ": ON" or ": OFF")
        b.BackgroundColor3 = state and Color3.fromRGB(40, 120, 70) or Color3.fromRGB(45, 45, 55)
        cb(state)
    end)
    return b
end

local activeDrag = nil
local function slider(name, min, max, default, cb, step)
    step = step or 10
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -6, 0, 58)
    f.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    f.LayoutOrder = nextOrder()
    f.Active = true
    f.Parent = list
    corner(f, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -140, 0, 24)
    l.Position = UDim2.new(0, 10, 0, 5)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.new(1, 1, 1)
    l.Font, l.TextSize = Enum.Font.Gotham, 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Parent = f

    local minus = button(f, "-", UDim2.new(0, 26, 0, 24), UDim2.new(1, -126, 0, 5), Color3.fromRGB(60, 60, 75))
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 56, 0, 24)
    box.Position = UDim2.new(1, -96, 0, 5)
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Font, box.TextSize = Enum.Font.GothamBold, 13
    box.Text = tostring(default)
    box.ClearTextOnFocus = true
    box.Parent = f
    corner(box, 6)
    local plus = button(f, "+", UDim2.new(0, 26, 0, 24), UDim2.new(1, -36, 0, 5), Color3.fromRGB(60, 60, 75))

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 8)
    bar.Position = UDim2.new(0, 10, 0, 42)
    bar.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    bar.Active = true
    bar.Parent = f
    corner(bar, 4)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(90, 140, 255)
    fill.Parent = bar
    corner(fill, 4)

    local value = default
    local function setValue(v)
        v = math.clamp(math.floor(v + 0.5), min, max)
        value = v
        fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
        box.Text = tostring(v)
        cb(v)
    end

    minus.MouseButton1Click:Connect(function() setValue(value - step) end)
    plus.MouseButton1Click:Connect(function() setValue(value + step) end)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then setValue(n) else box.Text = tostring(value) end
    end)

    local dragInput = nil
    local function update(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        setValue(min + (max - min) * a)
    end
    local function stopDrag(inp)
        if inp and dragInput ~= inp then return end
        if activeDrag == f then activeDrag = nil end
        dragInput = nil
        list.ScrollingEnabled = true
    end

    bar.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
        activeDrag = f
        dragInput = i
        list.ScrollingEnabled = false
        update(i.Position.X)

        local conns2 = {}
        if i.UserInputType == Enum.UserInputType.Touch then
            table.insert(conns2, i:GetPropertyChangedSignal("Position"):Connect(function()
                if dragInput == i and activeDrag == f then update(i.Position.X) end
            end))
        end
        table.insert(conns2, i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then
                stopDrag(i)
                for _, c in ipairs(conns2) do c:Disconnect() end
            end
        end))
    end)

    UIS.InputChanged:Connect(function(i)
        if activeDrag ~= f or not dragInput then return end
        if dragInput.UserInputType == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseMovement then
            update(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and i.UserInputType == Enum.UserInputType.MouseButton1 then
            stopDrag()
        end
    end)
end

-- ================= CONTROLS =================
toggle("Fly", function(s)
    flying = s
    flyPad.Visible = s or airWalkOn
    if s then startFly() else stopFly() end
end)
slider("Fly Speed", 10, 500, 50, function(v) flySpeed = v end)
toggle("NoClip", setNoclip)
toggle("Air Walk", function(s) setAirWalk(s) flyPad.Visible = s or flying end)
slider("Air Walk Up/Down", 10, 300, 80, function(v) AIR_VSPEED = v end, 10)
toggle("Spider Climb", function(s) climbOn = s end)
slider("Climb Speed", 10, 200, 40, function(v) CLIMB_SPEED = v end, 10)
toggle("Walk Speed", function(s) walkEnabled = s applyStats() end)
slider("Walk Speed Value", 16, 500, 16, function(v) walkSpeedValue = v applyStats() end)
toggle("Infinite Jump", function(s) infJump = s end)
slider("Jump Power", 50, 500, 50, function(v) jumpPowerValue = v applyStats() end)
slider("Infinite Jump Air Speed %", 100, 300, 125, function(v) AIR_SPEED_MULT = v / 100 end, 10)

-- ================= MINIMIZE (fade transparan + pill) =================
local TweenService = game:GetService("TweenService")
local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local originals, busy, minimized = nil, false, false

local function collect()
    originals = {}
    local list = main:GetDescendants()
    table.insert(list, main)
    for _, o in ipairs(list) do
        if o:IsA("GuiObject") then
            local d = { o = o, bg = o.BackgroundTransparency }
            if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
                d.tx, d.st = o.TextTransparency, o.TextStrokeTransparency
            end
            table.insert(originals, d)
        end
    end
end

local pill = Instance.new("TextButton")
pill.Size = UDim2.new(0, 190, 0, 28)
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Position = UDim2.new(0.5, 0, 0, 6)
pill.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
pill.BackgroundTransparency = 1
pill.Text = "Show Movement Menu"
pill.TextColor3 = Color3.new(1, 1, 1)
pill.TextTransparency = 1
pill.Font, pill.TextSize = Enum.Font.GothamBold, 12
pill.AutoButtonColor = false
pill.Visible = false
pill.Parent = gui
corner(pill, 14)

local function setMinimized(hide)
    if busy or hide == minimized then return end
    busy = true
    if not originals then collect() end
    if hide then
        for _, d in ipairs(originals) do
            local g = { BackgroundTransparency = 1 }
            if d.tx then g.TextTransparency, g.TextStrokeTransparency = 1, 1 end
            TweenService:Create(d.o, FADE, g):Play()
        end
        task.wait(0.35)
        main.Visible = false
        pill.Visible = true
        TweenService:Create(pill, FADE, { BackgroundTransparency = 0.3, TextTransparency = 0 }):Play()
    else
        TweenService:Create(pill, FADE, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
        for _, d in ipairs(originals) do
            d.o.BackgroundTransparency = 1
            if d.tx then d.o.TextTransparency, d.o.TextStrokeTransparency = 1, 1 end
        end
        main.Visible = true
        for _, d in ipairs(originals) do
            local g = { BackgroundTransparency = d.bg }
            if d.tx then g.TextTransparency, g.TextStrokeTransparency = d.tx, d.st end
            TweenService:Create(d.o, FADE, g):Play()
        end
        task.wait(0.35)
        pill.Visible = false
    end
    minimized = hide
    busy = false
end

minBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
pill.MouseButton1Click:Connect(function() setMinimized(false) end)

-- ================= CLOSE (konfirmasi Yes/No) =================
local confirm = Instance.new("Frame")
confirm.Size = UDim2.new(0, 250, 0, 120)
confirm.Position = UDim2.new(0.5, -125, 0.5, -60)
confirm.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
confirm.Visible = false
confirm.ZIndex = 10
confirm.Active = true
confirm.Parent = gui
corner(confirm, 10)

local msg = Instance.new("TextLabel")
msg.Size = UDim2.new(1, -20, 0, 60)
msg.Position = UDim2.new(0, 10, 0, 8)
msg.BackgroundTransparency = 1
msg.Text = "Yakin ingin menutup Movement Menu?\nSemua fitur akan dimatikan."
msg.TextWrapped = true
msg.TextColor3 = Color3.new(1, 1, 1)
msg.Font, msg.TextSize = Enum.Font.Gotham, 14
msg.ZIndex = 10
msg.Parent = confirm

local yes = button(confirm, "Yes", UDim2.new(0, 100, 0, 34), UDim2.new(0, 15, 1, -44), Color3.fromRGB(170, 50, 50))
local no = button(confirm, "No", UDim2.new(0, 100, 0, 34), UDim2.new(1, -115, 1, -44), Color3.fromRGB(60, 60, 75))
yes.ZIndex, no.ZIndex = 11, 11

closeBtn.MouseButton1Click:Connect(function() confirm.Visible = true end)
no.MouseButton1Click:Connect(function() confirm.Visible = false end)

yes.MouseButton1Click:Connect(function()
    flying, infJump, walkEnabled, climbOn = false, false, false, false
    stopFly()
    setAirWalk(false)
    setNoclip(false)
    local c = LocalPlayer.Character
    if c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
        end
    end
    local h = getHum()
    if h then h.WalkSpeed = 16 h.JumpPower = 50 end
    for _, cn in ipairs(conns) do cn:Disconnect() end
    gui:Destroy()
end)
