--[[ Popper | Entity Collector v3
     Alur: gerak ke entitas (Tween / Run) -> tap sejumlah Taps -> gerak balik ke base
     Tanpa teleport instan.
     Cara pakai: pilih Entity (dropdown), berdiri di base lalu "Set Base", nyalakan "Auto".
]]

----------------------------------------------------------------
-- DATA ENTITAS
-- Paths = lokasi objek (kalau lebih dari satu, dipakai bergantian)
-- Taps  = jumlah tap per kunjungan
-- Bentuk lain (cari berdasarkan nama): {Label = "...", Match = "NamaDiGame", Taps = 1}
----------------------------------------------------------------
local ENTITY_LIST = {
    { Label = "Pedestal_2 (6x)", Taps = 6, Paths = { "Workspace.NorthPole.Pedestals.Pedestal_2" } },
    { Label = "Pedestal_1 (4x)", Taps = 4, Paths = { "Workspace.NorthPole.Pedestals.Pedestal_1" } },
    { Label = "CandyCane (3x)", Taps = 3, Paths = {
        "Workspace.NorthPole.Territory.CandyCane",
        "Workspace.NorthPole.Territory.Arch.CandyCane",
    } },
    { Label = "Lamp (3x)", Taps = 3, Paths = { "Workspace.NorthPole.Territory.Lamp" } },
    { Label = "ChristmasTree (3x)", Taps = 3, Paths = { "Workspace.NorthPole.Territory.ChristmasTree" } },
    { Label = "ToyBlock (2x)", Taps = 2, Paths = { "Workspace.NorthPole.Territory.ToyBlock" } },
    { Label = "Arch (1x)", Taps = 1, Paths = { "Workspace.NorthPole.Territory.Arch" } },
}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local function getParent()
    if gethui then
        local ok, r = pcall(gethui)
        if ok and r then return r end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

local host = getParent()
local old = host:FindFirstChild("PopperUI")
if old then old:Destroy() end

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local State = {
    Enabled = false,
    Busy = false,
    Base = nil,
    Entry = nil,     -- item terpilih dari dropdown
    Manual = "",     -- nama manual (menimpa dropdown jika tidak kosong)
    TapOverride = 0, -- 0 = pakai Taps dari data (manual = 1)
    Folder = "",     -- hanya untuk pencarian berdasarkan nama
    Mode = "Tween",  -- "Tween" / "Run"
    Speed = 30,      -- stud/detik (mode Tween)
    Delay = 0.5,
    Range = 0,       -- 0 = tanpa batas (hanya pencarian berdasarkan nama)
    Rot = 0,         -- giliran lokasi untuk entitas dengan banyak Path
}
local alive = true
local blacklist = {}
local conns = {}

----------------------------------------------------------------
-- UI HELPERS
----------------------------------------------------------------
local COL = {
    bg = Color3.fromRGB(24, 24, 30),
    panel = Color3.fromRGB(36, 36, 46),
    cell = Color3.fromRGB(46, 46, 58),
    acc = Color3.fromRGB(80, 110, 240),
    on = Color3.fromRGB(50, 160, 85),
    off = Color3.fromRGB(170, 55, 55),
    text = Color3.fromRGB(235, 235, 240),
}

local function new(cls, props, par)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = par
    return o
end

local function round(o, r)
    new("UICorner", { CornerRadius = UDim.new(0, r or 4) }, o)
end

local function label(props, par)
    props.BackgroundTransparency = 1
    props.Font = Enum.Font.Gotham
    props.TextSize = 12
    props.TextColor3 = COL.text
    return new("TextLabel", props, par)
end

----------------------------------------------------------------
-- ROOT GUI
----------------------------------------------------------------
local gui = new("ScreenGui", {
    Name = "PopperUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, host)

local main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(500, 330),
    Position = UDim2.new(0.5, -250, 0.5, -165),
    BackgroundColor3 = COL.bg,
    BorderSizePixel = 0,
    Active = true, -- sink input agar game/kamera tidak ikut bergeser
    ClipsDescendants = true,
}, gui)
round(main, 6)

local reopener = new("TextButton", {
    Name = "Reopener",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 6),
    Size = UDim2.fromOffset(110, 24),
    BackgroundColor3 = COL.acc,
    Text = "Popper  ▼",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = COL.text,
    BorderSizePixel = 0,
    Visible = false,
}, gui)
round(reopener, 6)

-- Title bar
local titleBar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
    Active = true,
}, main)
label({
    Size = UDim2.new(1, -60, 1, 0),
    Position = UDim2.fromOffset(8, 0),
    Text = "Popper | Entity Collector",
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local minBtn = new("TextButton", {
    Size = UDim2.fromOffset(24, 24),
    Position = UDim2.new(1, -48, 0, 0),
    BackgroundTransparency = 1,
    Text = "–",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = COL.text,
}, titleBar)
local closeBtn = new("TextButton", {
    Size = UDim2.fromOffset(24, 24),
    Position = UDim2.new(1, -24, 0, 0),
    BackgroundTransparency = 1,
    Text = "X",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(255, 90, 90),
}, titleBar)

-- Status bar (1 baris, bukan log)
local statusLbl = label({
    Size = UDim2.new(1, -12, 0, 18),
    Position = UDim2.new(0, 6, 1, -18),
    Text = "Status: idle",
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, main)

local function setStatus(t)
    if alive then statusLbl.Text = "Status: " .. tostring(t) end
end

-- Tab kiri + holder halaman
local tabCol = new("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 24),
    Size = UDim2.new(0, 90, 1, -42),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, main)
new("UIListLayout", { Padding = UDim.new(0, 4) }, tabCol)
new("UIPadding", {
    PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
}, tabCol)

local pageHolder = new("Frame", {
    Position = UDim2.fromOffset(90, 24),
    Size = UDim2.new(1, -90, 1, -42),
    BackgroundTransparency = 1,
}, main)

-- Daftar dropdown (overlay, dipakai bersama)
local ddList = new("ScrollingFrame", {
    Size = UDim2.fromOffset(193, 150),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Visible = false,
    ZIndex = 5,
    Active = true,
}, main)
round(ddList)
new("UIListLayout", { Padding = UDim.new(0, 2) }, ddList)
new("UIPadding", {
    PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3),
}, ddList)
local ddOwner
local function closeDD()
    ddList.Visible = false
    ddOwner = nil
end

local tabs = {}
local function selectTab(name)
    closeDD()
    for n, t in pairs(tabs) do
        local sel = (n == name)
        t.page.Visible = sel
        t.btn.BackgroundColor3 = sel and COL.acc or COL.cell
    end
end

local function addTab(name)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = COL.cell,
        Text = name,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = COL.text,
        BorderSizePixel = 0,
    }, tabCol)
    round(btn)
    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, pageHolder)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
    }, page)
    new("UIGridLayout", {
        CellSize = UDim2.fromOffset(193, 24),
        CellPadding = UDim2.fromOffset(6, 6),
        FillDirectionMaxCells = 2,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    tabs[name] = { btn = btn, page = page }
    btn.MouseButton1Click:Connect(function() selectTab(name) end)
    return page
end

-- Cell helpers (2 kolom, tinggi 24, teks 12)
local function cellToggle(page, text, default, cb)
    local on = default
    local b = new("TextButton", {
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = COL.text, BorderSizePixel = 0,
    }, page)
    round(b)
    local function refresh()
        b.Text = text .. ": " .. (on and "ON" or "OFF")
        b.BackgroundColor3 = on and COL.on or COL.off
    end
    b.MouseButton1Click:Connect(function()
        on = not on
        refresh()
        cb(on)
    end)
    refresh()
    return b
end

local function cellButton(page, text, cb)
    local b = new("TextButton", {
        BackgroundColor3 = COL.acc, Text = text, Font = Enum.Font.GothamBold,
        TextSize = 12, TextColor3 = COL.text, BorderSizePixel = 0,
    }, page)
    round(b)
    b.MouseButton1Click:Connect(cb)
    return b
end

local function cellChoice(page, text, options, default, cb)
    local idx = table.find(options, default) or 1
    local b = new("TextButton", {
        BackgroundColor3 = COL.cell, Font = Enum.Font.GothamBold,
        TextSize = 12, TextColor3 = COL.text, BorderSizePixel = 0,
    }, page)
    round(b)
    local function refresh() b.Text = text .. ": " .. options[idx] end
    b.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        refresh()
        cb(options[idx])
    end)
    refresh()
    return b
end

local function cellInput(page, text, default, cb)
    local f = new("Frame", { BackgroundColor3 = COL.cell, BorderSizePixel = 0 }, page)
    round(f)
    label({
        Size = UDim2.new(0, 62, 1, 0), Position = UDim2.fromOffset(6, 0),
        Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    }, f)
    local tb = new("TextBox", {
        Size = UDim2.new(1, -72, 1, -6), Position = UDim2.fromOffset(66, 3),
        BackgroundColor3 = COL.bg, BorderSizePixel = 0,
        Text = tostring(default), PlaceholderText = "...",
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COL.text,
        ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
    round(tb, 3)
    tb.FocusLost:Connect(function() cb(tb) end)
    return f
end

-- item dropdown: string atau tabel -> (label, entry)
local function normItem(it)
    if type(it) == "table" then
        return tostring(it.Label or it.Match or "?"), it
    end
    local s = tostring(it)
    return s, { Label = s, Match = s, Taps = 1 }
end

local function cellDropdown(page, text, items, cb)
    local b = new("TextButton", {
        BackgroundColor3 = COL.cell, Font = Enum.Font.GothamBold,
        TextSize = 12, TextColor3 = COL.text, BorderSizePixel = 0,
        Text = text .. ": pilih ▾", TextTruncate = Enum.TextTruncate.AtEnd,
    }, page)
    round(b)

    local function addOption(lbl, entry, disabled)
        local o = new("TextButton", {
            Size = UDim2.new(1, -6, 0, 24),
            BackgroundColor3 = COL.cell, BorderSizePixel = 0,
            Text = lbl, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COL.text,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
        }, ddList)
        round(o, 3)
        o.MouseButton1Click:Connect(function()
            if disabled then return end
            b.Text = text .. ": " .. (entry and lbl or "pilih ▾")
            cb(entry)
            closeDD()
        end)
    end

    b.MouseButton1Click:Connect(function()
        if ddList.Visible and ddOwner == b then closeDD() return end
        for _, c in ipairs(ddList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        addOption("- kosong -", nil)
        if #items == 0 then
            addOption("(ENTITY_LIST masih kosong)", nil, true)
        else
            for _, it in ipairs(items) do
                local lbl, entry = normItem(it)
                addOption(lbl, entry)
            end
        end
        local count = math.max(#items, 1) + 1
        local h = math.min(count * 26 + 6, 150)
        local rel = b.AbsolutePosition - main.AbsolutePosition
        local y = rel.Y + 26
        if y + h > 312 then y = rel.Y - h - 2 end
        ddList.Position = UDim2.fromOffset(rel.X, y)
        ddList.Size = UDim2.fromOffset(193, h)
        ddList.CanvasPosition = Vector2.zero
        ddOwner = b
        ddList.Visible = true
    end)
    return b
end

----------------------------------------------------------------
-- LOGIKA: gerak ke entitas -> tap -> gerak balik base
----------------------------------------------------------------
local function root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- part acuan posisi dari sebuah objek (Part / Model / Folder)
local function partOf(inst)
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") and inst.PrimaryPart then return inst.PrimaryPart end
    return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function isPlayerStuff(inst)
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        if c and (inst == c or inst:IsDescendantOf(c)) then return true end
    end
    return false
end

-- "Workspace.NorthPole.Territory.Lamp" -> Instance
local function resolvePath(path)
    local cur = game
    for seg in path:gmatch("[^%.]+") do
        cur = cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end

-- pencarian berdasarkan nama (untuk Manual / item tanpa Paths)
local function searchByName(key)
    local r = root()
    if not r or key == "" then return end
    key = key:lower()

    local container = workspace
    if State.Folder ~= "" then
        container = workspace:FindFirstChild(State.Folder, true)
        if not container then return end
    end

    local best, bestD
    for _, inst in ipairs(container:GetDescendants()) do
        if (inst:IsA("Model") or inst:IsA("BasePart"))
            and inst.Name:lower():find(key, 1, true)
            and not isPlayerStuff(inst) then

            local par = inst.Parent
            local dupChild = par and par ~= container and par:IsA("Model")
                and par.Name:lower():find(key, 1, true)
            local bl = blacklist[inst]
            if not dupChild and (not bl or tick() > bl) then
                local p = partOf(inst)
                if p then
                    local d = (p.Position - r.Position).Magnitude
                    if (State.Range <= 0 or d <= State.Range) and (not bestD or d < bestD) then
                        best, bestD = inst, d
                    end
                end
            end
        end
    end
    return best
end

-- return inst, byPath
local function findEntity()
    if State.Manual ~= "" then
        return searchByName(State.Manual), false
    end
    local e = State.Entry
    if not e then return end
    if e.Paths then
        local list = {}
        for _, path in ipairs(e.Paths) do
            local inst = resolvePath(path)
            if inst then table.insert(list, inst) end
        end
        if #list == 0 then return end
        State.Rot = State.Rot + 1
        return list[(State.Rot - 1) % #list + 1], true
    end
    return searchByName(e.Match or e.Label or ""), false
end

-- Gerak halus ke posisi dest (tanpa teleport). return true jika sampai.
local function moveTo(dest)
    local r, hum = root(), humanoid()
    if not r then return false end

    if State.Mode == "Tween" then
        local target = dest + Vector3.new(0, 3, 0)
        local dist = (r.Position - target).Magnitude
        local dur = math.max(dist / math.max(State.Speed, 1), 0.05)
        local rot = r.CFrame - r.CFrame.Position
        local tw = TweenService:Create(
            r,
            TweenInfo.new(dur, Enum.EasingStyle.Linear),
            { CFrame = CFrame.new(target) * rot }
        )
        tw:Play()
        local t0 = tick()
        while alive and tick() - t0 < dur + 0.3
            and tw.PlaybackState ~= Enum.PlaybackState.Completed do
            local rr = root()
            if not rr then tw:Cancel() return false end
            rr.AssemblyLinearVelocity = Vector3.zero
            task.wait()
        end
        tw:Cancel()
        return true
    end

    -- Mode Run: jalan biasa pakai Humanoid
    if not hum then return false end
    local t0 = tick()
    local timeout = (r.Position - dest).Magnitude / math.max(hum.WalkSpeed, 1) + 6
    local lastPos, lastCheck = r.Position, tick()
    while alive and tick() - t0 < timeout do
        r = root()
        if not r then return false end
        local flat = Vector3.new(r.Position.X - dest.X, 0, r.Position.Z - dest.Z).Magnitude
        if flat < 4 then return true end
        hum:MoveTo(dest)
        if tick() - lastCheck > 1 then
            if (r.Position - lastPos).Magnitude < 1 then hum.Jump = true end
            lastPos, lastCheck = r.Position, tick()
        end
        task.wait(0.15)
    end
    return false
end

-- apakah objek punya interaksi bawaan (prompt / click / touch)
local function hasNative(inst)
    local list = inst:GetDescendants()
    table.insert(list, inst)
    for _, d in ipairs(list) do
        if d:IsA("ProximityPrompt") or d:IsA("ClickDetector")
            or (d:IsA("BasePart") and d:FindFirstChildOfClass("TouchInterest")) then
            return true
        end
    end
    return false
end

-- satu interaksi lewat prompt / click / touch
local function nativeTap(inst)
    local r = root()
    local list = inst:GetDescendants()
    table.insert(list, inst)
    for _, d in ipairs(list) do
        if d:IsA("ProximityPrompt") then
            if fireproximityprompt then
                pcall(fireproximityprompt, d)
            else
                pcall(function()
                    d:InputHoldBegin()
                    task.wait(d.HoldDuration + 0.05)
                    d:InputHoldEnd()
                end)
            end
        elseif d:IsA("ClickDetector") and fireclickdetector then
            pcall(fireclickdetector, d)
        elseif d:IsA("BasePart") and r and firetouchinterest
            and d:FindFirstChildOfClass("TouchInterest") then
            pcall(function()
                firetouchinterest(r, d, 0)
                task.wait()
                firetouchinterest(r, d, 1)
            end)
        end
    end
end

-- satu tap layar tepat di posisi objek (kamera diarahkan ke objek dulu)
local function screenTap(part)
    local cam = workspace.CurrentCamera
    if not (cam and VIM) then return false end
    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, part.Position)
    local v, onScreen = cam:WorldToViewportPoint(part.Position)
    if not onScreen then return false end
    VIM:SendMouseButtonEvent(v.X, v.Y, 0, true, game, 1)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(v.X, v.Y, 0, false, game, 1)
    return true
end

local function interact(inst, part, taps)
    local native = hasNative(inst)
    for _ = 1, taps do
        if not alive then break end
        if native then nativeTap(inst) else screenTap(part) end
        task.wait(0.25)
    end
end

-- return true jika satu siklus dijalankan
local function cycleBody()
    if not root() then setStatus("karakter belum ada"); return false end
    if not State.Base then setStatus("tekan Set Base dulu"); return false end
    if State.Manual == "" and not State.Entry then
        setStatus("pilih/isi Entity dulu")
        return false
    end

    local e, byPath = findEntity()
    if not e then setStatus("entitas tidak ditemukan"); return false end
    local p = partOf(e)
    if not p then setStatus("entitas tanpa part"); return false end

    local entryTaps = (State.Manual == "" and State.Entry and State.Entry.Taps) or 1
    local taps = State.TapOverride > 0 and State.TapOverride or entryTaps
    taps = math.max(1, math.floor(taps))

    setStatus(State.Mode .. " ke " .. e.Name)
    local reached = moveTo(p.Position)
    if not byPath then blacklist[e] = tick() + 5 end

    if reached then
        task.wait(State.Delay)
        setStatus("tap " .. e.Name .. " x" .. taps)
        interact(e, p, taps)
        task.wait(State.Delay)
    else
        setStatus("gagal sampai ke " .. e.Name)
    end

    setStatus(State.Mode .. " balik ke base")
    moveTo(State.Base.Position)
    task.wait(State.Delay)
    setStatus("selesai satu siklus")
    return true
end

local function cycle()
    if State.Busy then return false end
    State.Busy = true
    local ok, res = pcall(cycleBody)
    State.Busy = false
    if not ok then setStatus("error, coba lagi") return false end
    return res
end

task.spawn(function()
    while alive do
        if State.Enabled and not State.Busy then
            local did = cycle()
            task.wait(did and 0.2 or 1)
        else
            task.wait(0.2)
        end
    end
end)

----------------------------------------------------------------
-- TAB & FITUR
----------------------------------------------------------------
local pageMain = addTab("Utama")

cellToggle(pageMain, "Auto", false, function(v)
    State.Enabled = v
    setStatus(v and "auto berjalan" or "auto berhenti")
end)

cellButton(pageMain, "Set Base", function()
    local r = root()
    if r then
        State.Base = r.CFrame
        setStatus("base disimpan")
    else
        setStatus("karakter belum ada")
    end
end)

cellDropdown(pageMain, "Entity", ENTITY_LIST, function(entry)
    State.Entry = entry
    State.Rot = 0
end)

cellInput(pageMain, "Manual", "", function(tb)
    State.Manual = tb.Text
end)

cellChoice(pageMain, "Gerak", { "Tween", "Run" }, State.Mode, function(v)
    State.Mode = v
    setStatus("mode gerak: " .. v)
end)

cellInput(pageMain, "Speed", State.Speed, function(tb)
    local n = tonumber(tb.Text)
    if n and n > 0 then State.Speed = n else tb.Text = tostring(State.Speed) end
end)

cellInput(pageMain, "Tap", State.TapOverride, function(tb)
    local n = tonumber(tb.Text)
    if n and n >= 0 then State.TapOverride = n else tb.Text = tostring(State.TapOverride) end
end)

cellInput(pageMain, "Delay", State.Delay, function(tb)
    local n = tonumber(tb.Text)
    if n and n >= 0 then State.Delay = n else tb.Text = tostring(State.Delay) end
end)

cellInput(pageMain, "Range", State.Range, function(tb)
    local n = tonumber(tb.Text)
    if n and n >= 0 then State.Range = n else tb.Text = tostring(State.Range) end
end)

cellInput(pageMain, "Folder", "", function(tb)
    State.Folder = tb.Text
end)

cellButton(pageMain, "Run 1x", function()
    if State.Busy then return end
    task.spawn(cycle)
end)

cellButton(pageMain, "Ke Base", function()
    if State.Busy then return end
    if not State.Base then setStatus("base belum di-set") return end
    task.spawn(function()
        State.Busy = true
        pcall(function()
            setStatus(State.Mode .. " ke base")
            moveTo(State.Base.Position)
            setStatus("sampai di base")
        end)
        State.Busy = false
    end)
end)

selectTab("Utama")

----------------------------------------------------------------
-- DRAG (absolute), MINIMIZE, CLOSE
----------------------------------------------------------------
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        startPos = main.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

table.insert(conns, UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end))

minBtn.MouseButton1Click:Connect(function()
    closeDD()
    main.Visible = false
    reopener.Visible = true
end)

reopener.MouseButton1Click:Connect(function()
    main.Visible = true
    reopener.Visible = false
end)

closeBtn.MouseButton1Click:Connect(function()
    alive = false
    State.Enabled = false
    for _, c in ipairs(conns) do c:Disconnect() end
    gui:Destroy()
end)
