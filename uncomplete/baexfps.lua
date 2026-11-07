--[[
    baexfps - Roblox Lua (tanpa log)
    Ukuran 500x330, menu dikelompokkan per blok:
      [ESP]            ESP, Highlight, Nama/HP, Tracer, Tampil Tim (musuh = merah, tim = biru)
      [AUTO AIM]       Auto Aim, Range, FOV, Smooth, FOV Circle, Team Check, Wall Check, Target Head/Body
      [FIRE & RELOAD]  Auto Fire, No Reload, Delay, Ulang (repeat), status target
    Reopener tengah atas, Minimize, Close (Destroy), Drag absolut.
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
    Title = "baexfps",
    Size  = UDim2.fromOffset(500, 330),
    Colors = {
        Bg       = Color3.fromRGB(24, 24, 30),
        Title    = Color3.fromRGB(34, 34, 44),
        Panel    = Color3.fromRGB(16, 16, 22),
        Row      = Color3.fromRGB(28, 28, 38),
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
    EnemyColor  = Color3.fromRGB(255, 60, 60),   -- musuh = merah
    TeamColor   = Color3.fromRGB(70, 140, 255),  -- tim   = biru
    RefreshRate = 0.25,
    RescanEvery = 16,
    MaxTargets  = 30,   -- Roblox membatasi ~31 Highlight
}

local Trigger = {
    MaxDistance    = 500,
    ReactionDelay  = 0,
    ClickInterval  = 0.1,
    RepeatInterval = 0.15, -- jeda tembak berulang selama masih kena target (0 = sekali saja)
}

local Aim = {
    Range  = 200,    -- studs
    FOV    = 60,     -- derajat (lebar kerucut bidik)
    Smooth = 0.15,   -- 0.01 (halus/lambat) .. 1 (instan)
}

-- ========== STATE (bertahan walau UI dibangun ulang) ==========
local S = {
    esp = false, box = true, info = true, tracer = true, showteam = true,
    aim = false, fovcircle = false, team = true, wall = true, head = true,
    trigger = false, noreload = false,
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
pcall(function() if getgenv().BaexFps then getgenv().BaexFps.Close() end end)
for _, h in ipairs(hosts()) do
    for _, n in ipairs({"PopperUI", "PopperESP", "PopperFOV", "BaexFpsUI", "BaexFpsESP", "BaexFpsFOV"}) do
        local o = h:FindFirstChild(n)
        if o then pcall(function() o:Destroy() end) end
    end
end

-- ========== STATUS (di blok Fire & Reload) ==========
local tFire, tAim = "-", "-"
local statusText, statusColor = "Fire: -\nAim: -", C.SubText
local errText, errUntil = nil, 0

local function pushStatus()
    local text, color
    if errText and os.clock() < errUntil then
        text, color = errText, C.Close
    else
        text = "Fire: " .. tFire .. "\nAim: " .. tAim
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
    local pos = on and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
    if first then
        sw.BackgroundColor3 = bg
        knob.Position = pos
    else
        TweenService:Create(sw, TW, {BackgroundColor3 = bg}):Play()
        TweenService:Create(knob, TW, {Position = pos}):Play()
    end
end

-- forward declarations
local setESP, setTrigger, setAim, setNoReload, setFovCircle, closeAll
local refreshUI

-- ========== LAYOUT BLOK ==========
local BLOCK_Y, BLOCK_H = 40, 282
local BLOCKS = {
    {id = "esp",  title = "ESP",            x = 10,  w = 140},
    {id = "aim",  title = "AUTO AIM",       x = 158, w = 184},
    {id = "fire", title = "FIRE & RELOAD",  x = 350, w = 140},
}
local ROW0, ROWSTEP, ROWH = 34, 30, 26
local function rowY(slot) return ROW0 + (slot - 1) * ROWSTEP end

-- blk = id blok, slot = urutan baris di blok
local TOGGLES = {
    -- ESP
    {key = "esp",    blk = "esp", slot = 1,
        text = function() return S.esp and ("ESP (" .. espCount .. ")") or "ESP" end,
        click = function() setESP(not S.esp) end},
    {key = "box",    blk = "esp", slot = 2,
        text = function() return "Highlight" end,
        click = function() S.box = not S.box refreshUI() end},
    {key = "info",   blk = "esp", slot = 3,
        text = function() return "Nama / HP" end,
        click = function() S.info = not S.info refreshUI() end},
    {key = "tracer", blk = "esp", slot = 4,
        text = function() return "Tracer" end,
        click = function() S.tracer = not S.tracer refreshUI() end},
    {key = "showteam", blk = "esp", slot = 5,
        text = function() return "Tampil Tim" end,
        click = function() S.showteam = not S.showteam refreshUI() end},
    -- AUTO AIM (slot 2-4 dipakai kotak angka: Range, FOV, Smooth)
    {key = "aim",    blk = "aim", slot = 1,
        text = function() return "Auto Aim" end,
        click = function() setAim(not S.aim) end},
    {key = "fovcircle", blk = "aim", slot = 5,
        text = function() return "FOV Circle" end,
        click = function() setFovCircle(not S.fovcircle) end},
    {key = "team",   blk = "aim", slot = 6,
        text = function() return "Team Check" end,
        click = function() S.team = not S.team refreshUI() end},
    {key = "wall",   blk = "aim", slot = 7,
        text = function() return "Wall Check" end,
        click = function() S.wall = not S.wall refreshUI() end},
    {key = "head",   blk = "aim", slot = 8,
        text = function() return S.head and "Target: Head" or "Target: Body" end,
        click = function() S.head = not S.head refreshUI() end},
    -- FIRE & RELOAD
    {key = "trigger",  blk = "fire", slot = 1,
        text = function() return "Auto Fire" end,
        click = function() setTrigger(not S.trigger) end},
    {key = "noreload", blk = "fire", slot = 2,
        text = function() return "No Reload" end,
        click = function() setNoReload(not S.noreload) end},
}

local NUMS = {
    {blk = "aim",  slot = 2, label = "Range",  tbl = Aim, key = "Range",  lo = 1,    hi = 2000},
    {blk = "aim",  slot = 3, label = "FOV",    tbl = Aim, key = "FOV",    lo = 1,    hi = 180},
    {blk = "aim",  slot = 4, label = "Smooth", tbl = Aim, key = "Smooth", lo = 0.01, hi = 1},
    {blk = "fire", slot = 3, label = "Delay",  tbl = Trigger, key = "ReactionDelay",  lo = 0, hi = 5},
    {blk = "fire", slot = 4, label = "Ulang",  tbl = Trigger, key = "RepeatInterval", lo = 0, hi = 5},
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
local function build()
    for _, c in ipairs(uiConns) do pcall(function() c:Disconnect() end) end
    table.clear(uiConns)
    if ui and ui.gui then pcall(function() ui.gui:Destroy() end) end

    local gui = new("ScreenGui", {
        Name = "BaexFpsUI", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    })
    mount(gui)
    local r = {gui = gui, tg = {}, blocks = {}}

    -- Reopener (tengah atas)
    r.reopener = new("TextButton", {
        Name = "Reopener", AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(110, 28),
        BackgroundColor3 = C.Title, Text = "▼  " .. CONFIG.Title,
        TextColor3 = C.Text, Font = Enum.Font.GothamBold, TextSize = 13,
        Active = true, Visible = false, Parent = gui,
    }, {corner(14), new("UIStroke", {Color = C.Accent, Thickness = 1.5})})

    -- Frame utama
    local startPos = S.x and UDim2.fromOffset(S.x, S.y) or UDim2.new(0.5, -250, 0, 20)
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

    -- Blok per fitur
    for _, b in ipairs(BLOCKS) do
        local f = new("Frame", {
            Position = UDim2.fromOffset(b.x, BLOCK_Y), Size = UDim2.fromOffset(b.w, BLOCK_H),
            BackgroundColor3 = C.Panel, BorderSizePixel = 0, Parent = r.main,
        }, {corner(8)})
        new("TextLabel", {
            Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18),
            BackgroundTransparency = 1, Text = b.title, TextColor3 = C.Accent,
            Font = Enum.Font.GothamBold, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
        })
        new("Frame", {
            Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -16, 0, 1),
            BackgroundColor3 = C.Off, BackgroundTransparency = 0.5,
            BorderSizePixel = 0, Parent = f,
        })
        r.blocks[b.id] = f
    end

    local function rowFrame(blk, slot)
        return new("Frame", {
            Position = UDim2.fromOffset(8, rowY(slot)), Size = UDim2.new(1, -16, 0, ROWH),
            BackgroundColor3 = C.Row, BorderSizePixel = 0, Parent = r.blocks[blk],
        }, {corner(6)})
    end

    -- Baris toggle
    for _, def in ipairs(TOGGLES) do
        local row = rowFrame(def.blk, def.slot)
        local lbl = new("TextLabel", {
            Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -52, 1, 0),
            BackgroundTransparency = 1, Text = def.text(), TextColor3 = C.Text,
            Font = Enum.Font.GothamMedium, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
        local sw = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.fromOffset(38, 20), BackgroundColor3 = C.Off,
            Text = "", AutoButtonColor = false, Parent = row,
        }, {corner(10)})
        local knob = new("Frame", {
            Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sw,
        }, {corner(7)})
        r.tg[def.key] = {lbl = lbl, sw = sw, knob = knob}
        onUI(sw.MouseButton1Click, def.click)
    end

    -- Baris angka (pengaturan Auto Aim)
    for _, n in ipairs(NUMS) do
        local row = rowFrame(n.blk, n.slot)
        new("TextLabel", {
            Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.5, -8, 1, 0),
            BackgroundTransparency = 1, Text = n.label, TextColor3 = C.SubText,
            Font = Enum.Font.GothamMedium, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
        })
        local box = new("TextBox", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.new(0.5, -8, 0, 20), BackgroundColor3 = C.Bg,
            Text = tostring(n.tbl[n.key]), TextColor3 = C.Text,
            Font = Enum.Font.GothamMedium, TextSize = 12,
            ClearTextOnFocus = false, Parent = row,
        }, {corner(5)})
        onUI(box.FocusLost, function()
            local v = tonumber(box.Text)
            if v then n.tbl[n.key] = math.clamp(v, n.lo, n.hi) end
            box.Text = tostring(n.tbl[n.key])
        end)
    end

    -- Status target (bawah blok Fire & Reload)
    r.status = new("TextLabel", {
        Position = UDim2.fromOffset(10, BLOCK_H - 70), Size = UDim2.new(1, -20, 0, 62),
        BackgroundTransparency = 1, Text = statusText, TextColor3 = statusColor,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Bottom, Parent = r.blocks.fire,
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

-- Deteksi tim: Roblox Team -> TeamColor -> attribute (Team/TeamName/team/TeamColor)
-- pada player atau karakter. Jika game tidak punya tim, semua dianggap musuh.
local TEAM_ATTRS = {"Team", "TeamName", "team", "TeamColor"}

local function teamKeyOf(player, model)
    if player then
        if player.Team ~= nil then return player.Team end
        if not player.Neutral then return player.TeamColor end
        for _, n in ipairs(TEAM_ATTRS) do
            local v = player:GetAttribute(n)
            if v ~= nil then return v end
        end
    end
    if model then
        for _, n in ipairs(TEAM_ATTRS) do
            local v = model:GetAttribute(n)
            if v ~= nil then return v end
        end
    end
    return nil
end

local function sameTeam(model)
    local mine = teamKeyOf(LocalPlayer, LocalPlayer.Character)
    if mine == nil then return false end
    local theirs = teamKeyOf(Players:GetPlayerFromCharacter(model), model)
    return theirs ~= nil and theirs == mine
end

local function isEnemy(model)
    if model == LocalPlayer.Character then return false end
    if S.team and sameTeam(model) then return false end
    return true -- bot/NPC tanpa tim dianggap musuh
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
        Name = "BaexFpsESP", ResetOnSpawn = false, IgnoreGuiInset = true,
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
    local color = sameTeam(model) and ESP.TeamColor or ESP.EnemyColor

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
        tracer = tracer, label = label, hidden = false,
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
            local ally = sameTeam(model)
            local col = ally and ESP.TeamColor or ESP.EnemyColor
            t.hidden = ally and not S.showteam
            t.label.TextColor3 = col
            t.highlight.FillColor = col
            t.highlight.OutlineColor = col
            t.tracer.BackgroundColor3 = col
            t.highlight.Enabled = S.box and not t.hidden
            t.billboard.Enabled = S.info and not t.hidden
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
                if S.tracer and not t.hidden and t.root.Parent then
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
    pcall(function() RunService:UnbindFromRenderStep("BaexFpsAim") end)
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
        RunService:BindToRenderStep("BaexFpsAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
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

-- Raycast yang melewati viewmodel kamera, badan sendiri, dan part transparan non-musuh
local function castRay(origin, dir, myChar, cam)
    local ignore = {myChar, cam}
    for _ = 1, 6 do
        rayParams.FilterDescendantsInstances = ignore
        local res = workspace:Raycast(origin, dir, rayParams)
        if not res then return nil end
        local inst = res.Instance
        if inst.Transparency >= 0.95 and not getModelFromPart(inst) then
            table.insert(ignore, inst)
        else
            return res
        end
    end
    return nil
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

    local ray = cam:ViewportPointToRay(pt.X, pt.Y)
    local result = castRay(ray.Origin, ray.Direction * Trigger.MaxDistance, myChar, cam)

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
    if state then triggerErrors = 0 end
    setTarget("-")
    refreshUI()
end

-- ========== FOV CIRCLE ==========
local fovGui, fovFrame, fovStroke

local function destroyFov()
    if fovGui then pcall(function() fovGui:Destroy() end) end
    fovGui, fovFrame, fovStroke = nil, nil, nil
end

local function ensureFov()
    if fovGui and fovGui.Parent then return end
    destroyFov()
    fovGui = new("ScreenGui", {
        Name = "BaexFpsFOV", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 997,
    })
    mount(fovGui)
    fovStroke = new("UIStroke", {Color = C.Accent, Thickness = 1.5, Transparency = 0.15})
    fovFrame = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = UDim2.fromOffset(0, 0), Parent = fovGui,
    }, {new("UICorner", {CornerRadius = UDim.new(0.5, 0)}), fovStroke})
end

-- kerucut bidik (sudut dari arah kamera) diproyeksikan ke layar = lingkaran di tengah
onGlobal(RunService.RenderStepped, function()
    if S.closed or not S.fovcircle then return end
    pcall(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        ensureFov()
        local vs = cam.ViewportSize
        local half = math.rad(math.min(Aim.FOV / 2, 89))
        local vfov = math.rad(math.clamp(cam.FieldOfView, 1, 120))
        local radius = math.min(math.tan(half) / math.tan(vfov / 2) * (vs.Y / 2), 3000)
        fovFrame.Position = UDim2.fromOffset(vs.X / 2, vs.Y / 2)
        fovFrame.Size = UDim2.fromOffset(radius * 2, radius * 2)
        fovStroke.Color = (S.aim and tAim ~= "-") and C.Close or C.Accent
    end)
end)

function setFovCircle(state)
    S.fovcircle = state
    if state then ensureFov() else destroyFov() end
    refreshUI()
end

-- ========== NO RELOAD ==========
-- Mencari field reload di Value/Attribute, ModuleScript (require), dan tabel memori (getgc),
-- lalu mengubah nilainya. Nilai asli disimpan dan dikembalikan saat OFF.
-- Berhasil tidaknya tergantung struktur senjata di game.
local nrRun = 0
local nrInst, nrTbl, nrMods = {}, {}, {}

local function isReloadKey(n)
    if type(n) ~= "string" then return false end
    n = n:lower()
    if not n:find("reload") then return false end
    return n == "reload" or n:find("time") or n:find("delay") or n:find("cooldown")
        or n:find("duration") or n:find("speed") or n:find("rate") or n:find("length")
end

local function nrTarget(k)
    k = k:lower()
    if k:find("speed") or k:find("rate") then return 1000 end
    return 0
end

local function patchTable(t, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if seen[t] or depth > 3 then return end
    seen[t] = true
    pcall(function()
        for k, v in pairs(t) do
            if type(v) == "number" and isReloadKey(k) then
                nrTbl[t] = nrTbl[t] or {}
                if nrTbl[t][k] == nil then nrTbl[t][k] = v end
                t[k] = nrTarget(k)
            elseif type(v) == "table" then
                patchTable(v, depth + 1, seen)
            end
        end
    end)
end

local function patchInstance(inst)
    if (inst:IsA("NumberValue") or inst:IsA("IntValue")) and isReloadKey(inst.Name) then
        nrInst[inst] = nrInst[inst] or {}
        if nrInst[inst].__value == nil then nrInst[inst].__value = inst.Value end
        inst.Value = nrTarget(inst.Name)
    end
    for name, val in pairs(inst:GetAttributes()) do
        if type(val) == "number" and isReloadKey(name) then
            nrInst[inst] = nrInst[inst] or {}
            if nrInst[inst][name] == nil then nrInst[inst][name] = val end
            inst:SetAttribute(name, nrTarget(name))
        end
    end
end

local function scanModule(m)
    if not m:IsA("ModuleScript") or nrMods[m] then return end
    nrMods[m] = true
    local ok, res = pcall(require, m)
    if ok and type(res) == "table" then patchTable(res) end
end

local function scanContainer(container)
    if not container then return end
    pcall(function()
        patchInstance(container)
        for _, d in ipairs(container:GetDescendants()) do
            patchInstance(d)
            scanModule(d)
        end
    end)
end

local function scanGC()
    if type(getgc) ~= "function" then return end
    pcall(function()
        for _, o in ipairs(getgc(true)) do
            if type(o) == "table" then patchTable(o, 3) end
        end
    end)
end

local function nrFullScan()
    scanContainer(LocalPlayer.Character)
    scanContainer(LocalPlayer:FindFirstChildOfClass("Backpack"))
    scanContainer(LocalPlayer)
    scanContainer(game:GetService("ReplicatedStorage"))
    scanGC()
end

local function nrRestore()
    for inst, data in pairs(nrInst) do
        if inst and inst.Parent then
            for k, v in pairs(data) do
                if k == "__value" then
                    pcall(function() inst.Value = v end)
                else
                    pcall(function() inst:SetAttribute(k, v) end)
                end
            end
        end
    end
    for t, data in pairs(nrTbl) do
        for k, v in pairs(data) do pcall(function() t[k] = v end) end
    end
    nrInst, nrTbl, nrMods = {}, {}, {}
end

-- scan ulang saat senjata di-equip
local function hookCharacter(char)
    onGlobal(char.ChildAdded, function(c)
        if S.noreload and c:IsA("Tool") then
            task.wait(0.3)
            scanContainer(c)
            scanGC()
        end
    end)
end
if LocalPlayer.Character then hookCharacter(LocalPlayer.Character) end
onGlobal(LocalPlayer.CharacterAdded, hookCharacter)

function setNoReload(state)
    S.noreload = state
    nrRun += 1
    local myRun = nrRun
    if state then
        task.spawn(nrFullScan)
        task.spawn(function()
            while S.noreload and not S.closed and nrRun == myRun do
                scanContainer(LocalPlayer.Character)
                scanContainer(LocalPlayer:FindFirstChildOfClass("Backpack"))
                task.wait(0.5)
            end
        end)
    else
        nrRestore()
    end
    refreshUI()
end

-- ========== CLOSE ==========
function closeAll()
    S.closed = true
    S.esp, S.trigger, S.noreload = false, false, false
    pcall(unbindAim)
    S.aim = false
    pcall(nrRestore)
    pcall(clearESP)
    pcall(destroyFov)
    for _, c in ipairs(globalConns) do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(uiConns) do pcall(function() c:Disconnect() end) end
    table.clear(globalConns)
    table.clear(uiConns)
    if ui and ui.gui then pcall(function() ui.gui:Destroy() end) end
    pcall(function() getgenv().BaexFps = nil end)
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
    getgenv().BaexFps = {
        SetESP = setESP,
        SetAutoFire = setTrigger,
        SetAutoClick = setTrigger,
        SetAutoAim = setAim,
        SetNoReload = setNoReload,
        SetFovCircle = setFovCircle,
        Close = closeAll,
    }
end)
