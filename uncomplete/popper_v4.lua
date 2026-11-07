--[[
    POPPER UI v4 - Roblox Lua (tanpa log)
    Ukuran 500x330.
    Fitur : Reopener tengah atas, Minimize, Close (Destroy), Drag absolut,
            ESP (player + bot, jarak, HP, tracer), Auto Fire (tembak saat crosshair kena musuh),
            Auto Aim (kamera mengunci ke musuh terdekat dari crosshair).
    Anti-hilang: jika game menghapus GUI, UI dibangun ulang dengan state yang sama.
]]

-- ========== SERVICES ==========
local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local GuiService   = game:GetService("GuiService")
local CoreGui      = game:GetService("CoreGui")
local LocalPlayer  = Players.LocalPlayer

-- ========== CONFIG ==========
local CONFIG = {
    Title = "POPPER",
    Size  = UDim2.fromOffset(500, 330),
    Colors = {
        Bg       = Color3.fromRGB(24, 24, 30),
        Title    = Color3.fromRGB(34, 34, 44),
        Panel    = Color3.fromRGB(16, 16, 22),
        Accent   = Color3.fromRGB(88, 130, 255),
        Text     = Color3.fromRGB(235, 235, 240),
        SubText  = Color3.fromRGB(150, 150, 165),
        On       = Color3.fromRGB(70, 200, 120),
        Off      = Color3.fromRGB(80, 80, 95),
        Close    = Color3.fromRGB(235, 80, 80),
        Minimize = Color3.fromRGB(240, 190, 60),
    },
}
local C = CONFIG.Colors

local ESP = {
    PlayerColor = Color3.fromRGB(255, 70, 70),
    BotColor    = Color3.fromRGB(255, 170, 60),
    RefreshRate = 0.25,
    RescanEvery = 16,
    MaxTargets  = 30,   -- Roblox membatasi ~31 Highlight
}

local Trigger = {
    MaxDistance    = 500,
    ReactionDelay  = 0,
    ClickInterval  = 0.1,
    RepeatInterval = 0,   -- 0 = tembak SEKALI per target; mis. 0.3 = berulang
}

local Aim = {
    Range  = 200,    -- studs
    FOV    = 90,     -- derajat
    Smooth = 0.15,   -- 0.01 (halus/lambat) .. 1 (instan)
}

-- ========== STATE (bertahan walau UI dibangun ulang) ==========
local S = {
    esp = false, trigger = false, aim = false,
    tracer = true, team = true, wall = true, head = true,
    minimized = false, x = nil, y = nil, closed = false,
}
local ui
local uiConns, globalConns = {}, {}
local espCount = 0

local function onUI(signal, fn) table.insert(uiConns, signal:Connect(fn)) end
local function onGlobal(signal, fn) table.insert(globalConns, signal:Connect(fn)) end

-- ========== HELPERS ==========
local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, ch in ipairs(children or {}) do ch.Parent = inst end
    return inst
end
local function corner(r) return new("UICorner", {CornerRadius = UDim.new(0, r)}) end

local function hosts()
    local list = {}
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and typeof(hui) == "Instance" then table.insert(list, hui) end
    table.insert(list, CoreGui)
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(list, pg) end
    return list
end

local function mount(gui)
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
    for _, h in ipairs(hosts()) do
        local ok = pcall(function() gui.Parent = h end)
        if ok and gui.Parent == h then return true end
    end
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    return true
end

-- bersihkan instance lama bila script dijalankan ulang
pcall(function() if getgenv().Popper then getgenv().Popper.Close() end end)
for _, h in ipairs(hosts()) do
    for _, n in ipairs({"PopperUI", "PopperESP"}) do
        local o = h:FindFirstChild(n)
        if o then pcall(function() o:Destroy() end) end
    end
end

-- ========== STATUS ==========
local tFire, tAim = "-", "-"
local statusText, statusColor = "Fire: -   |   Aim: -", C.SubText
local errText, errUntil = nil, 0

local function pushStatus()
    local text, color
    if errText and os.clock() < errUntil then
        text, color = errText, C.Close
    else
        text = "Fire: " .. tFire .. "   |   Aim: " .. tAim
        color = (tFire ~= "-" or tAim ~= "-") and C.Close or C.SubText
    end
    if text == statusText and color == statusColor then return end
    statusText, statusColor = text, color
    if ui and ui.status and ui.status.Parent then
        ui.status.Text = text
        ui.status.TextColor3 = color
    end
end
local function setTarget(name) tFire = name pushStatus() end
local function setAimTarget(name) tAim = name pushStatus() end
local function setError(msg) errText, errUntil = msg, os.clock() + 4 pushStatus() end

-- ========== TOGGLE VISUAL ==========
local TW = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function paint(sw, knob, on)
    local first = sw:GetAttribute("on") == nil
    if sw:GetAttribute("on") == on then return end
    sw:SetAttribute("on", on)
    local bg  = on and C.On or C.Off
    local pos = on and UDim2.fromOffset(27, 3) or UDim2.fromOffset(3, 3)
    if first then
        sw.BackgroundColor3 = bg
        knob.Position = pos
    else
        TweenService:Create(sw, TW, {BackgroundColor3 = bg}):Play()
        TweenService:Create(knob, TW, {Position = pos}):Play()
    end
end

-- forward declarations
local setESP, setTrigger, setAim, closeAll
local refreshUI

-- definisi toggle: row, i (kolom ke-), n (jumlah kolom di baris)
local TOGGLES = {
    {key = "esp",     row = 1, i = 1, n = 2,
        text = function() return S.esp and ("ESP: ON (" .. espCount .. ")") or "ESP: OFF" end,
        click = function() setESP(not S.esp) end},
    {key = "trigger", row = 1, i = 2, n = 2,
        text = function() return "Auto Fire: " .. (S.trigger and "ON" or "OFF") end,
        click = function() setTrigger(not S.trigger) end},
    {key = "aim",     row = 2, i = 1, n = 2,
        text = function() return "Auto Aim: " .. (S.aim and "ON" or "OFF") end,
        click = function() setAim(not S.aim) end},
    {key = "tracer",  row = 2, i = 2, n = 2,
        text = function() return "ESP Tracer: " .. (S.tracer and "ON" or "OFF") end,
        click = function() S.tracer = not S.tracer refreshUI() end},
    {key = "team",    row = 4, i = 1, n = 3,
        text = function() return "Team Chk" end,
        click = function() S.team = not S.team refreshUI() end},
    {key = "wall",    row = 4, i = 2, n = 3,
        text = function() return "Wall Chk" end,
        click = function() S.wall = not S.wall refreshUI() end},
    {key = "head",    row = 4, i = 3, n = 3,
        text = function() return S.head and "Aim: Head" or "Aim: Body" end,
        click = function() S.head = not S.head refreshUI() end},
}

function refreshUI()
    if not (ui and ui.gui and ui.gui.Parent) then return end
    for _, def in ipairs(TOGGLES) do
        local w = ui.tg[def.key]
        w.lbl.Text = def.text()
        paint(w.sw, w.knob, S[def.key])
    end
    ui.status.Text = statusText
    ui.status.TextColor3 = statusColor
    ui.main.Visible = not S.minimized
    ui.reopener.Visible = S.minimized
end

-- ========== BUILD UI ==========
local ROW_Y = {44, 100, 156, 212}
local ROW_H = 46

local function build()
    for _, c in ipairs(uiConns) do pcall(function() c:Disconnect() end) end
    table.clear(uiConns)
    if ui and ui.gui then pcall(function() ui.gui:Destroy() end) end

    local gui = new("ScreenGui", {
        Name = "PopperUI", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    })
    mount(gui)
    local r = {gui = gui, tg = {}}

    -- Reopener (tengah atas)
    r.reopener = new("TextButton", {
        Name = "Reopener", AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(110, 28),
        BackgroundColor3 = C.Title, Text = "▼  " .. CONFIG.Title,
        TextColor3 = C.Text, Font = Enum.Font.GothamBold, TextSize = 13,
        Active = true, Visible = false, Parent = gui,
    }, {corner(14), new("UIStroke", {Color = C.Accent, Thickness = 1.5})})

    -- Frame utama
    local startPos = S.x and UDim2.fromOffset(S.x, S.y) or UDim2.new(0.5, -250, 0, 40)
    r.main = new("Frame", {
        Name = "Main", Position = startPos, Size = CONFIG.Size,
        BackgroundColor3 = C.Bg, BorderSizePixel = 0,
        Active = true, -- menyerap input agar game/kamera tidak ikut bergerak
        Parent = gui,
    }, {corner(10), new("UIStroke", {Color = C.Accent, Thickness = 1.2, Transparency = 0.3})})

    -- Title bar
    local titleBar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.Title,
        BorderSizePixel = 0, Active = true, Parent = r.main,
    }, {corner(10)})
    new("Frame", {
        Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = C.Title, BorderSizePixel = 0, Parent = titleBar,
    })
    new("TextLabel", {
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -90, 1, 0),
        BackgroundTransparency = 1, Text = CONFIG.Title, TextColor3 = C.Text,
        Font = Enum.Font.GothamBold, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar,
    })
    local function titleBtn(text, x, color)
        return new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0),
            Size = UDim2.fromOffset(26, 22), BackgroundColor3 = color, Text = text,
            TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
            TextSize = 14, Parent = titleBar,
        }, {corner(6)})
    end
    local btnClose = titleBtn("X", -8, C.Close)
    local btnMin   = titleBtn("–", -40, C.Minimize)

    local function cellRect(row, i, n)
        local gap = 8
        local w = (480 - gap * (n - 1)) / n
        return UDim2.fromOffset(10 + (i - 1) * (w + gap), ROW_Y[row]), UDim2.fromOffset(w, ROW_H)
    end
    local function panel(pos, size)
        return new("Frame", {
            Position = pos, Size = size, BackgroundColor3 = C.Panel,
            BorderSizePixel = 0, Parent = r.main,
        }, {corner(8)})
    end

    -- Toggle
    for _, def in ipairs(TOGGLES) do
        local pos, size = cellRect(def.row, def.i, def.n)
        local p = panel(pos, size)
        local lbl = new("TextLabel", {
            Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -68, 1, 0),
            BackgroundTransparency = 1, Text = def.text(), TextColor3 = C.Text,
            Font = Enum.Font.GothamMedium, TextSize = (def.n == 3) and 12 or 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = p,
        })
        local sw = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.fromOffset(46, 22), BackgroundColor3 = C.Off,
            Text = "", AutoButtonColor = false, Parent = p,
        }, {corner(11)})
        local knob = new("Frame", {
            Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sw,
        }, {corner(8)})
        r.tg[def.key] = {lbl = lbl, sw = sw, knob = knob}
        onUI(sw.MouseButton1Click, def.click)
    end

    -- Baris pengaturan Aim: Range | FOV | Smooth
    local function numCell(i, label, key, lo, hi)
        local pos, size = cellRect(3, i, 3)
        local p = panel(pos, size)
        new("TextLabel", {
            Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.5, -10, 1, 0),
            BackgroundTransparency = 1, Text = label, TextColor3 = C.SubText,
            Font = Enum.Font.GothamMedium, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = p,
        })
        local box = new("TextBox", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.new(0.5, -8, 0, 28), BackgroundColor3 = C.Bg,
            Text = tostring(Aim[key]), TextColor3 = C.Text,
            Font = Enum.Font.GothamMedium, TextSize = 13,
            ClearTextOnFocus = false, Parent = p,
        }, {corner(6)})
        onUI(box.FocusLost, function()
            local v = tonumber(box.Text)
            if v then Aim[key] = math.clamp(v, lo, hi) end
            box.Text = tostring(Aim[key])
        end)
    end
    numCell(1, "Range", "Range", 1, 2000)
    numCell(2, "FOV", "FOV", 1, 180)
    numCell(3, "Smooth", "Smooth", 0.01, 1)

    -- Status
    local pStat = new("Frame", {
        Position = UDim2.fromOffset(10, 268), Size = UDim2.fromOffset(480, 44),
        BackgroundColor3 = C.Panel, BorderSizePixel = 0, Parent = r.main,
    }, {corner(8)})
    r.status = new("TextLabel", {
        Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0),
        BackgroundTransparency = 1, Text = statusText, TextColor3 = statusColor,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = pStat,
    })

    ui = r

    onUI(btnMin.MouseButton1Click, function() S.minimized = true refreshUI() end)
    onUI(r.reopener.MouseButton1Click, function() S.minimized = false refreshUI() end)
    onUI(btnClose.MouseButton1Click, function() closeAll() end)

    -- Drag absolut
    local dragging, dragStart, startAbs = false, nil, nil
    onUI(titleBar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startAbs = true, input.Position, r.main.AbsolutePosition
            local ch
            ch = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    ch:Disconnect()
                end
            end)
        end
    end)
    onUI(UIS.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            local vp, sz = gui.AbsoluteSize, r.main.AbsoluteSize
            S.x = math.clamp(startAbs.X + d.X, 0, math.max(0, vp.X - sz.X))
            S.y = math.clamp(startAbs.Y + d.Y, 0, math.max(0, vp.Y - sz.Y))
            r.main.Position = UDim2.fromOffset(S.x, S.y)
        end
    end)

    refreshUI()
end

-- ========== UTIL TARGET ==========
local function getRoot(model)
    return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Head")
end

local function isEnemy(model)
    if model == LocalPlayer.Character then return false end
    local player = Players:GetPlayerFromCharacter(model)
    if player and S.team and player.Team ~= nil and player.Team == LocalPlayer.Team then
        return false
    end
    return true -- bot/NPC dianggap musuh
end

-- ========== ESP ==========
local espRun = 0
local espTargets, espConns = {}, {}
local espGui
local espNeedScan = false

local function ensureEspGui()
    if espGui and espGui.Parent then return espGui end
    table.clear(espTargets)
    espCount = 0
    espNeedScan = true
    espGui = new("ScreenGui", {
        Name = "PopperESP", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 998,
    })
    mount(espGui)
    return espGui
end

local function removeTarget(model)
    local t = espTargets[model]
    if t then
        pcall(function() t.highlight:Destroy() end)
        pcall(function() t.billboard:Destroy() end)
        pcall(function() t.tracer:Destroy() end)
        espTargets[model] = nil
        espCount -= 1
    end
end

local function clearESP()
    for model in pairs(espTargets) do removeTarget(model) end
    for _, c in ipairs(espConns) do pcall(function() c:Disconnect() end) end
    table.clear(espConns)
    table.clear(espTargets)
    espCount = 0
    if espGui then pcall(function() espGui:Destroy() end) espGui = nil end
end

local function addTarget(model)
    if not model or espTargets[model] or not model:IsA("Model") then return end
    if model == LocalPlayer.Character or espCount >= ESP.MaxTargets then return end
    local hum, root = model:FindFirstChildOfClass("Humanoid"), getRoot(model)
    if not hum or not root or hum.Health <= 0 then return end

    local holder = ensureEspGui()
    local player = Players:GetPlayerFromCharacter(model)
    local color = player and ESP.PlayerColor or ESP.BotColor

    local highlight = new("Highlight", {
        Adornee = model, FillColor = color, FillTransparency = 0.6,
        OutlineColor = color, OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = holder,
    })
    local label = new("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = model.Name,
        TextColor3 = color, TextStrokeTransparency = 0.3,
        Font = Enum.Font.GothamBold, TextSize = 12,
    })
    local billboard = new("BillboardGui", {
        Adornee = root, AlwaysOnTop = true, Size = UDim2.fromOffset(150, 34),
        StudsOffset = Vector3.new(0, 3.2, 0), Parent = holder,
    }, {label})
    local tracer = new("Frame", {
        BackgroundColor3 = color, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 0),
        Visible = false, Parent = holder,
    })

    espCount += 1
    espTargets[model] = {
        humanoid = hum, root = root, highlight = highlight, billboard = billboard,
        tracer = tracer, label = label,
        name = player and player.Name or model.Name, isPlayer = player ~= nil,
    }
end

local function scanESP()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Humanoid") and d.Health > 0 then addTarget(d.Parent) end
    end
end

local function updateESP()
    local myChar = LocalPlayer.Character
    local myRoot = myChar and getRoot(myChar)
    for model, t in pairs(espTargets) do
        if not model.Parent or not t.humanoid.Parent or not t.root.Parent or t.humanoid.Health <= 0 then
            removeTarget(model)
        else
            local dist = myRoot and math.floor((t.root.Position - myRoot.Position).Magnitude) or 0
            local hp = math.floor(math.clamp(t.humanoid.Health / math.max(t.humanoid.MaxHealth, 1), 0, 1) * 100)
            t.label.Text = string.format("%s%s\n[%dm]  HP %d%%", t.isPlayer and "" or "[BOT] ", t.name, dist, hp)
        end
    end
end

-- Tracer: garis dari bawah-tengah layar ke target (per frame)
onGlobal(RunService.RenderStepped, function()
    if S.closed or not S.esp then return end
    pcall(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vs = cam.ViewportSize
        local origin = Vector2.new(vs.X / 2, vs.Y)
        for _, t in pairs(espTargets) do
            local tr = t.tracer
            if tr and tr.Parent then
                local shown = false
                if S.tracer and t.root.Parent then
                    local sp, onScreen = cam:WorldToViewportPoint(t.root.Position)
                    if onScreen and sp.Z > 0 then
                        local tgt = Vector2.new(sp.X, sp.Y)
                        local diff = tgt - origin
                        tr.Size = UDim2.fromOffset(2, diff.Magnitude)
                        tr.Position = UDim2.fromOffset((origin.X + tgt.X) / 2, (origin.Y + tgt.Y) / 2)
                        tr.Rotation = math.deg(math.atan2(diff.Y, diff.X)) - 90
                        shown = true
                    end
                end
                tr.Visible = shown
            end
        end
    end)
end)

function setESP(state)
    S.esp = state
    espRun += 1
    local myRun = espRun
    if not state then
        clearESP()
        refreshUI()
        return
    end

    ensureEspGui()
    scanESP()
    espNeedScan = false
    table.insert(espConns, workspace.DescendantAdded:Connect(function(d)
        if d:IsA("Humanoid") then task.defer(addTarget, d.Parent) end
    end))

    task.spawn(function()
        local tick, errors = 0, 0
        while S.esp and not S.closed and espRun == myRun do
            tick += 1
            local ok, err = pcall(function()
                ensureEspGui()
                if tick % ESP.RescanEvery == 0 or espNeedScan then
                    espNeedScan = false
                    scanESP()
                end
                updateESP()
                refreshUI()
            end)
            if not ok then
                errors += 1
                setError("ESP error: " .. tostring(err))
                if errors >= 3 then setESP(false) break end
            end
            task.wait(ESP.RefreshRate)
        end
    end)
    refreshUI()
end

-- ========== AUTO FIRE ==========
local aimedModel, aimSince, lastClick, aimedFired = nil, 0, 0, false
local triggerErrors = 0
local shootBtn, lastBtnScan, touchSeq = nil, 0, 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getModelFromPart(part)
    local m = part:FindFirstAncestorOfClass("Model")
    while m do
        if m:FindFirstChildOfClass("Humanoid") then return m end
        local p = m.Parent
        if p and p:IsA("Model") then m = p
        else m = p and p:FindFirstAncestorOfClass("Model") or nil end
    end
    return nil
end

-- cari tombol "Shoot" di layar (game mobile)
local function findShootButton()
    if shootBtn and shootBtn:IsDescendantOf(game) then return shootBtn end
    shootBtn = nil
    if os.clock() - lastBtnScan < 1.5 then return nil end
    lastBtnScan = os.clock()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.AbsoluteSize.X > 0 and not (ui and d:IsDescendantOf(ui.gui)) then
            local hit = d.Name:lower():find("shoot") ~= nil
                or (d:IsA("TextButton") and d.Text:lower() == "shoot")
            if not hit then
                for _, ch in ipairs(d:GetDescendants()) do
                    if ch:IsA("TextLabel") and ch.Text:lower() == "shoot" then hit = true break end
                end
            end
            if hit then shootBtn = d return d end
        end
    end
    return nil
end

local function tapButton(btn)
    local vim = game:GetService("VirtualInputManager")
    local sg = btn:FindFirstAncestorOfClass("ScreenGui")
    local inset = (sg and not sg.IgnoreGuiInset) and GuiService:GetGuiInset() or Vector2.zero
    local c = btn.AbsolutePosition + btn.AbsoluteSize / 2 + inset
    touchSeq += 1
    local id = 100 + touchSeq % 50
    vim:SendTouchEvent(id, 0, c.X, c.Y)
    task.delay(0.04, function()
        pcall(function() vim:SendTouchEvent(id, 2, c.X, c.Y) end)
    end)
end

local function doClick(pt)
    if UIS.TouchEnabled then
        local btn = findShootButton()
        if btn and pcall(tapButton, btn) then return true end
    end
    if mouse1click then return (pcall(mouse1click)) end
    return (pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(pt.X, pt.Y, 0, true, game, 0)
        vim:SendMouseButtonEvent(pt.X, pt.Y, 0, false, game, 0)
    end))
end

local function triggerStep()
    if not S.trigger then return end
    local cam = workspace.CurrentCamera
    if not cam or UIS:GetFocusedTextBox() then return end

    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHum or myHum.Health <= 0 then
        aimedModel = nil
        setTarget("-")
        return
    end

    local pt
    if UIS.TouchEnabled or UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
        pt = cam.ViewportSize / 2
    else
        pt = UIS:GetMouseLocation()
        if ui and ui.gui.Parent then
            for _, w in ipairs({ui.main, ui.reopener}) do
                if w.Visible then
                    local p, s = w.AbsolutePosition, w.AbsoluteSize
                    if pt.X >= p.X and pt.X <= p.X + s.X and pt.Y >= p.Y and pt.Y <= p.Y + s.Y then
                        aimedModel = nil
                        setTarget("-")
                        return
                    end
                end
            end
        end
    end

    rayParams.FilterDescendantsInstances = {myChar}
    local ray = cam:ViewportPointToRay(pt.X, pt.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * Trigger.MaxDistance, rayParams)

    local model = result and getModelFromPart(result.Instance) or nil
    if model and not isEnemy(model) then model = nil end
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then model = nil end

    local now = os.clock()
    if model ~= aimedModel then
        aimedModel, aimSince, aimedFired = model, now, false
    end

    if model then
        local player = Players:GetPlayerFromCharacter(model)
        setTarget(player and player.Name or model.Name)
        if not aimedFired then
            if now - aimSince >= Trigger.ReactionDelay and now - lastClick >= Trigger.ClickInterval then
                aimedFired, lastClick = true, now
                doClick(pt)
            end
        elseif Trigger.RepeatInterval > 0 and now - lastClick >= Trigger.RepeatInterval then
            lastClick = now
            doClick(pt)
        end
    else
        setTarget("-")
    end
end

onGlobal(RunService.Heartbeat, function()
    if S.closed or not S.trigger then return end
    local ok, err = pcall(triggerStep)
    if not ok then
        triggerErrors += 1
        setError("Auto Fire error: " .. tostring(err))
        if triggerErrors >= 3 then setTrigger(false) end
    end
end)

function setTrigger(state)
    S.trigger = state
    aimedModel, aimedFired = nil, false
    if state then
        triggerErrors = 0
    end
    setTarget("-")
    refreshUI()
end

-- ========== AUTO AIM ==========
local aimTargets, aimConns = {}, {}
local aimErrors = 0
local aimRay = RaycastParams.new()
aimRay.FilterType = Enum.RaycastFilterType.Exclude

local PART_HEAD = {"Head", "UpperTorso", "HumanoidRootPart", "Torso"}
local PART_BODY = {"UpperTorso", "Torso", "HumanoidRootPart", "Head"}

local function registerAim(inst)
    if inst:IsA("Humanoid") then
        local m = inst.Parent
        if m and m:IsA("Model") then aimTargets[m] = true end
    end
end

local function aimPartOf(model)
    local names = S.head and PART_HEAD or PART_BODY
    for _, n in ipairs(names) do
        local p = model:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function pickBest(cam, myChar)
    local camPos, look = cam.CFrame.Position, cam.CFrame.LookVector
    local bestPart, bestModel, bestScore = nil, nil, math.huge

    for model in pairs(aimTargets) do
        if not model.Parent or not model:IsDescendantOf(workspace) then
            aimTargets[model] = nil
        else
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and isEnemy(model) then
                local part = aimPartOf(model)
                if part then
                    local delta = part.Position - camPos
                    local dist = delta.Magnitude
                    if dist > 0 and dist <= Aim.Range then
                        local angle = math.deg(math.acos(math.clamp(look:Dot(delta.Unit), -1, 1)))
                        if angle <= Aim.FOV / 2 then
                            local score = angle + dist * 0.02
                            if score < bestScore then
                                local visible = true
                                if S.wall then
                                    aimRay.FilterDescendantsInstances = {myChar}
                                    local hit = workspace:Raycast(camPos, delta, aimRay)
                                    if hit and not hit.Instance:IsDescendantOf(model) then
                                        visible = false
                                    end
                                end
                                if visible then
                                    bestScore, bestPart, bestModel = score, part, model
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestPart, bestModel
end

local function aimStep(dt)
    if not S.aim then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHum or myHum.Health <= 0 then
        setAimTarget("-")
        return
    end

    local part, model = pickBest(cam, myChar)
    if part then
        local goal = CFrame.lookAt(cam.CFrame.Position, part.Position)
        local alpha = math.clamp(1 - math.exp(-Aim.Smooth * dt * 60), 0, 1)
        cam.CFrame = cam.CFrame:Lerp(goal, alpha)
        local player = Players:GetPlayerFromCharacter(model)
        setAimTarget(player and player.Name or model.Name)
    else
        setAimTarget("-")
    end
end

local function unbindAim()
    pcall(function() RunService:UnbindFromRenderStep("PopperAim") end)
    for _, c in ipairs(aimConns) do pcall(function() c:Disconnect() end) end
    table.clear(aimConns)
    table.clear(aimTargets)
end

function setAim(state)
    S.aim = state
    unbindAim()
    if state then
        aimErrors = 0
        for _, d in ipairs(workspace:GetDescendants()) do registerAim(d) end
        table.insert(aimConns, workspace.DescendantAdded:Connect(registerAim))
        RunService:BindToRenderStep("PopperAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
            if S.closed or not S.aim then return end
            local ok, err = pcall(aimStep, dt)
            if not ok then
                aimErrors += 1
                setError("Auto Aim error: " .. tostring(err))
                if aimErrors >= 3 then
                    task.defer(setAim, false)
                end
            end
        end)
    end
    setAimTarget("-")
    refreshUI()
end

-- ========== CLOSE ==========
function closeAll()
    S.closed = true
    S.esp, S.trigger = false, false
    pcall(unbindAim)
    S.aim = false
    pcall(clearESP)
    for _, c in ipairs(globalConns) do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(uiConns) do pcall(function() c:Disconnect() end) end
    table.clear(globalConns)
    table.clear(uiConns)
    if ui and ui.gui then pcall(function() ui.gui:Destroy() end) end
    pcall(function() getgenv().Popper = nil end)
end

-- ========== START + WATCHDOG ==========
build()

task.spawn(function()
    while not S.closed do
        if not (ui and ui.gui and ui.gui.Parent) then
            pcall(build)
        end
        pushStatus()
        task.wait(0.5)
    end
end)

pcall(function()
    getgenv().Popper = {
        SetESP = setESP,
        SetAutoFire = setTrigger,
        SetAutoClick = setTrigger,
        SetAutoAim = setAim,
        Close = closeAll,
    }
end)
