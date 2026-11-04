-- ========================================================
-- NAMECHECK — VENYX STYLE (fixed) + KOORDINAT
-- Desc  : ESP / Name Check / Tap Inspector dengan UI Venyx
-- Tambahan: toggle koordinat floating (tab ESP)
-- ========================================================

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local Workspace    = game:GetService("Workspace")
local LP           = Players.LocalPlayer
local Mouse        = LP:GetMouse()

local env = (getgenv and getgenv()) or _G
if env.__NAMECHECK_CLEANUP then pcall(env.__NAMECHECK_CLEANUP) end

-- ===== Konfigurasi =====
local radius        = 100
local labelsOn      = false
local tapOn         = false
local coordOn       = false
local MAXLIST       = 60
local MAXLABELS     = 25
local MAXSIZE       = 40
local MAX_DESC_SHOW = 80
local filters = { Pemain = true, Musuh = true, Entitas = true, Objek = true }
local COLORS = {
    Pemain  = Color3.fromRGB(80, 255, 120),
    Musuh   = Color3.fromRGB(255, 80, 80),
    Entitas = Color3.fromRGB(255, 230, 80),
    Objek   = Color3.fromRGB(80, 180, 255),
}

local running  = true
local conns    = {}
local labelMap = {}
local logs     = { scan = "", tap = "" }

local refreshLabels, runScan, buildTapReport
local ScanLogLbl, TapLogLbl

local function connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(conns, c)
    return c
end

local function getRoot()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

-- ===== Sumber objek =====
local sources, parts = {}, {}

local function register(o)
    if o:IsA("Humanoid") or o:IsA("AnimationController") then
        sources[o] = true
    elseif o:IsA("BasePart") and not o:IsA("Terrain") then
        parts[o] = true
    end
end

-- scan awal dibagi per batch supaya tidak membekukan game
task.spawn(function()
    local n = 0
    for _, o in ipairs(Workspace:GetDescendants()) do
        if not running then return end
        register(o)
        n = n + 1
        if n % 1500 == 0 then task.wait() end
    end
end)
connect(Workspace.DescendantAdded, register)
connect(Workspace.DescendantRemoving, function(o) sources[o] = nil; parts[o] = nil end)

local function kindOf(m)
    if Players:GetPlayerFromCharacter(m) then return "Pemain" end
    if m:FindFirstChildOfClass("Humanoid") then return "Musuh" end
    return "Entitas"
end

local function pickPart(m)
    local p = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
    if p and p:IsA("BasePart") then return p end
    return m:FindFirstChildWhichIsA("BasePart", true)
end

local function collect()
    local root = getRoot()
    if not root then return nil end
    local found, seen = {}, {}
    for src in pairs(sources) do
        local m = src.Parent
        if m and m:IsA("Model") and m ~= LP.Character and not seen[m] and m:IsDescendantOf(Workspace) then
            seen[m] = true
            local kind = kindOf(m)
            if filters[kind] then
                local part = pickPart(m)
                if part then
                    local d = (part.Position - root.Position).Magnitude
                    if d <= radius then
                        table.insert(found, { model = m, part = part, d = d, kind = kind })
                    end
                end
            end
        end
    end
    if filters.Objek then
        local char = LP.Character
        for p in pairs(parts) do
            if p.Parent and not (char and p:IsDescendantOf(char)) then
                local d = (p.Position - root.Position).Magnitude
                if d <= radius and p.Size.Magnitude <= MAXSIZE then
                    local m = p:FindFirstAncestorOfClass("Model")
                    local isChar = m and (Players:GetPlayerFromCharacter(m)
                        or m:FindFirstChildOfClass("Humanoid"))
                    if not isChar then
                        local item = m or p
                        if not seen[item] then
                            seen[item] = true
                            table.insert(found, { model = item, part = p, d = d, kind = "Objek" })
                        end
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    return found
end

-- =====================================================
-- UI FRAMEWORK
-- =====================================================
local function getGuiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end
local CoreGui = getGuiParent()

local Colors = {
    Background  = Color3.fromRGB(20, 20, 20),
    TopBar      = Color3.fromRGB(25, 25, 25),
    Sidebar     = Color3.fromRGB(15, 15, 15),
    TabActive   = Color3.fromRGB(45, 45, 45),
    TabInactive = Color3.fromRGB(15, 15, 15),
    Text        = Color3.fromRGB(255, 255, 255),
    TextDim     = Color3.fromRGB(180, 180, 180),
    Accent      = Color3.fromRGB(40, 140, 220),
    Danger      = Color3.fromRGB(200, 70, 70),
    Success     = Color3.fromRGB(70, 180, 90),
    ButtonOff   = Color3.fromRGB(50, 50, 50),
}

local old = CoreGui:FindFirstChild("VenyxFramework")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VenyxFramework"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
pcall(function() ScreenGui.ScreenInsets = Enum.ScreenInsets.None end)
ScreenGui.Parent = CoreGui

-- Tombol buka
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0.02, 0, 0.4, 0)
ToggleBtn.BackgroundColor3 = Colors.Background
ToggleBtn.Text = "≡"
ToggleBtn.TextColor3 = Colors.Text
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 26
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)

-- Frame utama
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Batasi ukuran di layar kecil (HP)
do
    local cam = Workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        local w = math.min(600, vp.X - 20)
        local h = math.min(400, vp.Y - 20)
        MainFrame.Size = UDim2.new(0, w, 0, h)
        MainFrame.Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2)
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Topbar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Colors.TopBar
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(0, 400, 1, 0)
TitleLbl.Position = UDim2.new(0, 15, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "NameCheck  ·  Venyx"
TitleLbl.TextColor3 = Colors.Text
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 14
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Colors.Danger
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Colors.Text
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 60, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = Colors.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
local SB = Instance.new("UIListLayout")
SB.SortOrder = Enum.SortOrder.LayoutOrder
SB.Padding = UDim.new(0, 10)
SB.HorizontalAlignment = Enum.HorizontalAlignment.Center
SB.VerticalAlignment = Enum.VerticalAlignment.Center
SB.Parent = Sidebar

-- Content
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -70, 1, -50)
ContentArea.Position = UDim2.new(0, 65, 0, 45)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- Tabs
local Pages, TabButtons = {}, {}

local function CreateTab(name, icon)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 40, 0, 40)
    Btn.BackgroundColor3 = Colors.TabInactive
    Btn.Text = icon
    Btn.TextColor3 = Colors.TextDim
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 18
    Btn.Parent = Sidebar
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)

    local Page = Instance.new("ScrollingFrame")
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 2
    Page.ScrollBarImageColor3 = Colors.Accent
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.Visible = false
    Page.Parent = ContentArea
    local Lay = Instance.new("UIListLayout")
    Lay.SortOrder = Enum.SortOrder.LayoutOrder
    Lay.Padding = UDim.new(0, 10)
    Lay.Parent = Page

    Pages[name] = Page
    TabButtons[name] = Btn

    Btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        for _, b in pairs(TabButtons) do
            b.BackgroundColor3 = Colors.TabInactive
            b.TextColor3 = Colors.TextDim
        end
        Page.Visible = true
        Btn.BackgroundColor3 = Colors.TabActive
        Btn.TextColor3 = Colors.Text
    end)
    return Page
end

-- Widget helper
local function CreateSection(parent, title)
    local Sec = Instance.new("Frame")
    Sec.Size = UDim2.new(1, -10, 0, 0)
    Sec.AutomaticSize = Enum.AutomaticSize.Y
    Sec.BackgroundColor3 = Colors.TopBar
    Sec.BorderSizePixel = 0
    Sec.Parent = parent
    Instance.new("UICorner", Sec).CornerRadius = UDim.new(0, 8)

    local Pad = Instance.new("UIPadding")
    Pad.PaddingTop = UDim.new(0, 8)
    Pad.PaddingBottom = UDim.new(0, 10)
    Pad.PaddingLeft = UDim.new(0, 12)
    Pad.PaddingRight = UDim.new(0, 12)
    Pad.Parent = Sec

    local Lay = Instance.new("UIListLayout")
    Lay.SortOrder = Enum.SortOrder.LayoutOrder
    Lay.Padding = UDim.new(0, 6)
    Lay.Parent = Sec

    local Tl = Instance.new("TextLabel")
    Tl.Size = UDim2.new(1, 0, 0, 20)
    Tl.BackgroundTransparency = 1
    Tl.Text = title
    Tl.TextColor3 = Colors.TextDim
    Tl.Font = Enum.Font.GothamBold
    Tl.TextSize = 12
    Tl.TextXAlignment = Enum.TextXAlignment.Left
    Tl.LayoutOrder = 0
    Tl.Parent = Sec
    return Sec
end

-- LayoutOrder otomatis supaya urutan widget pasti sesuai urutan dibuat
local orderCounter = 0
local function nextOrder()
    orderCounter = orderCounter + 1
    return orderCounter
end

local function CreateToggle(parent, text, default, accent, callback)
    accent = accent or Colors.Accent
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 30)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -70, 1, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text
    Lbl.TextColor3 = Colors.Text
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 13
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Parent = Row

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 56, 0, 24)
    Btn.Position = UDim2.new(1, -56, 0.5, -12)
    Btn.BackgroundColor3 = default and accent or Colors.ButtonOff
    Btn.Text = default and "ON" or "OFF"
    Btn.TextColor3 = Colors.Text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.Parent = Row
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 4)

    local state = default
    Btn.MouseButton1Click:Connect(function()
        state = not state
        Btn.Text = state and "ON" or "OFF"
        Btn.BackgroundColor3 = state and accent or Colors.ButtonOff
        if callback then callback(state) end
    end)
    return Row
end

local function CreateButton(parent, text, color, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 30)
    Btn.BackgroundColor3 = color or Colors.Accent
    Btn.Text = text
    Btn.TextColor3 = Colors.Text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.LayoutOrder = nextOrder()
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    Btn.MouseButton1Click:Connect(callback)
    return Btn
end

-- cfg.callback menerima tombolnya sendiri sebagai argumen (menghindari bug scope)
local function CreateButtonRow(parent, cfg1, cfg2)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 30)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent

    local function make(cfg, xScale, xOffset)
        local B = Instance.new("TextButton")
        B.Size = UDim2.new(0.5, -3, 1, 0)
        B.Position = UDim2.new(xScale, xOffset, 0, 0)
        B.BackgroundColor3 = cfg.color or Colors.Accent
        B.Text = cfg.text
        B.TextColor3 = Colors.Text
        B.Font = Enum.Font.GothamBold
        B.TextSize = 12
        B.Parent = Row
        Instance.new("UICorner", B).CornerRadius = UDim.new(0, 6)
        if cfg.callback then
            B.MouseButton1Click:Connect(function() cfg.callback(B) end)
        end
        return B
    end

    local B1 = make(cfg1, 0, 0)
    local B2 = make(cfg2, 0.5, 3)
    return Row, B1, B2
end

local function CreateSlider(parent, text, min, max, default, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 44)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -70, 0, 20)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text
    Lbl.TextColor3 = Colors.Text
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 13
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Parent = Row

    local Val = Instance.new("TextLabel")
    Val.Size = UDim2.new(0, 60, 0, 20)
    Val.Position = UDim2.new(1, -60, 0, 0)
    Val.BackgroundTransparency = 1
    Val.Text = tostring(default)
    Val.TextColor3 = Colors.TextDim
    Val.Font = Enum.Font.GothamBold
    Val.TextSize = 12
    Val.TextXAlignment = Enum.TextXAlignment.Right
    Val.Parent = Row

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, 0, 0, 4)
    Bar.Position = UDim2.new(0, 0, 0, 32)
    Bar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Bar.BorderSizePixel = 0
    Bar.Parent = Row
    Instance.new("UICorner", Bar).CornerRadius = UDim.new(1, 0)

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Colors.Accent
    Fill.BorderSizePixel = 0
    Fill.Parent = Bar
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local Hit = Instance.new("TextButton")
    Hit.Size = UDim2.new(1, 0, 0, 24)
    Hit.Position = UDim2.new(0, 0, 0, 22)
    Hit.BackgroundTransparency = 1
    Hit.Text = ""
    Hit.Parent = Row

    local dragging = false
    local function update(x)
        local w = Bar.AbsoluteSize.X
        if w <= 0 then return end
        local rel = math.clamp((x - Bar.AbsolutePosition.X) / w, 0, 1)
        local v = math.floor(min + rel * (max - min) + 0.5)
        Val.Text = tostring(v)
        Fill.Size = UDim2.new(rel, 0, 1, 0)
        if callback then callback(v) end
    end

    Hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(i.Position.X)
        end
    end)
    connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return Row
end

local function CreateLogBox(parent, height)
    local Box = Instance.new("ScrollingFrame")
    Box.Size = UDim2.new(1, 0, 0, height or 240)
    Box.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    Box.BorderSizePixel = 0
    Box.ScrollBarThickness = 3
    Box.ScrollBarImageColor3 = Colors.Accent
    Box.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Box.CanvasSize = UDim2.new(0, 0, 0, 0)
    Box.LayoutOrder = nextOrder()
    Box.Parent = parent
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 6)

    local Pad = Instance.new("UIPadding")
    Pad.PaddingLeft = UDim.new(0, 6)
    Pad.PaddingRight = UDim.new(0, 6)
    Pad.PaddingTop = UDim.new(0, 6)
    Pad.PaddingBottom = UDim.new(0, 6)
    Pad.Parent = Box

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, 0, 0, 0)
    Lbl.AutomaticSize = Enum.AutomaticSize.Y
    Lbl.BackgroundTransparency = 1
    Lbl.TextWrapped = true
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.TextYAlignment = Enum.TextYAlignment.Top
    Lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    Lbl.Font = Enum.Font.Code
    Lbl.TextSize = 11
    Lbl.Text = ""
    Lbl.Parent = Box
    return Box, Lbl
end

local function copyText(str, btn)
    if str == "" then return end
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, str) else print(str) end
    btn.Text = "Copied!"
    task.delay(1.5, function()
        if btn.Parent then btn.Text = "📋 Copy" end
    end)
end

-- =====================================================
-- KOORDINAT FLOATING (BARU)
-- =====================================================
-- Terkunci di bawah tombol menu Roblox (kiri atas), tidak bisa digeser.
-- Tap kotaknya untuk menyalin koordinat ("X, Y, Z") ke clipboard.
local CoordFrame = Instance.new("TextButton")
CoordFrame.Name = "CoordFrame"
CoordFrame.AutoButtonColor = false
CoordFrame.Text = ""
CoordFrame.Size = UDim2.new(0.253, 0, 0.078, 0)
CoordFrame.Position = UDim2.new(0.035, 0, 0.163, 0)
CoordFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
CoordFrame.BackgroundTransparency = 0.15
CoordFrame.BorderSizePixel = 0
CoordFrame.Visible = false
CoordFrame.ZIndex = 100
CoordFrame.Parent = ScreenGui
Instance.new("UICorner", CoordFrame).CornerRadius = UDim.new(0, 8)

local CoordLbl = Instance.new("TextLabel")
CoordLbl.Size = UDim2.new(1, -10, 1, -6)
CoordLbl.Position = UDim2.new(0, 5, 0, 3)
CoordLbl.BackgroundTransparency = 1
CoordLbl.Text = "X: 0  Y: 0  Z: 0"
CoordLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
CoordLbl.Font = Enum.Font.Code
CoordLbl.TextScaled = true
CoordLbl.ZIndex = 101
CoordLbl.Parent = CoordFrame
do
    local c = Instance.new("UITextSizeConstraint")
    c.MaxTextSize = 18
    c.MinTextSize = 8
    c.Parent = CoordLbl
end

local coordCopy = ""
local copiedUntil = 0

CoordFrame.MouseButton1Click:Connect(function()
    if coordCopy == "" then return end
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, coordCopy) else print(coordCopy) end
    CoordLbl.Text = "Tersalin: " .. coordCopy
    copiedUntil = os.clock() + 1.2
end)

task.spawn(function()
    while running do
        task.wait(0.1)
        if coordOn then
            local root = getRoot()
            if root then
                local p = root.Position
                coordCopy = string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
                if os.clock() >= copiedUntil then
                    CoordLbl.Text = string.format("X: %.1f  Y: %.1f  Z: %.1f", p.X, p.Y, p.Z)
                end
            else
                coordCopy = ""
                CoordLbl.Text = "Karakter belum siap"
            end
        end
    end
end)

-- =====================================================
-- TABS
-- =====================================================
local ESPPage      = CreateTab("ESP", "👁")
local ScanPage     = CreateTab("Scan", "🔍")
local TapPage      = CreateTab("Tap", "👆")
local SettingsPage = CreateTab("Settings", "⚙")

Pages["ESP"].Visible = true
TabButtons["ESP"].BackgroundColor3 = Colors.TabActive
TabButtons["ESP"].TextColor3 = Colors.Text

-- ESP Page
local FilterSection = CreateSection(ESPPage, "FILTER")
FilterSection.LayoutOrder = nextOrder()
CreateToggle(FilterSection, "Pemain", filters.Pemain, COLORS.Pemain,
    function(v) filters.Pemain = v end)
CreateToggle(FilterSection, "Musuh (Humanoid)", filters.Musuh, COLORS.Musuh,
    function(v) filters.Musuh = v end)
CreateToggle(FilterSection, "Entitas (AnimController)", filters.Entitas, COLORS.Entitas,
    function(v) filters.Entitas = v end)
CreateToggle(FilterSection, "Objek (BasePart)", filters.Objek, COLORS.Objek,
    function(v) filters.Objek = v end)

local LabelSection = CreateSection(ESPPage, "LABEL")
LabelSection.LayoutOrder = nextOrder()
CreateToggle(LabelSection, "Tampilkan label di atas objek", labelsOn, Colors.Accent,
    function(v) labelsOn = v; refreshLabels(collect()) end)
CreateToggle(LabelSection, "Tampilkan koordinat saya", coordOn, Colors.Accent,
    function(v)
        coordOn = v
        CoordFrame.Visible = v
    end)

-- Scan Page
local ScanControls = CreateSection(ScanPage, "KONTROL")
ScanControls.LayoutOrder = nextOrder()
CreateSlider(ScanControls, "Radius", 10, 500, radius,
    function(v) radius = v end)
CreateButton(ScanControls, "🔍  Scan Sekarang", Colors.Accent,
    function() runScan() end)

local ScanLogSection = CreateSection(ScanPage, "LOG SCAN")
ScanLogSection.LayoutOrder = nextOrder()
local _scanBox
_scanBox, ScanLogLbl = CreateLogBox(ScanLogSection, 280)
ScanLogLbl.Text = "Tekan tombol Scan untuk memindai sekitar."
CreateButtonRow(ScanLogSection,
    { text = "📋 Copy", color = Colors.Success, callback = function(btn)
        copyText(logs.scan, btn)
    end },
    { text = "🗑 Clear", color = Colors.Danger, callback = function()
        logs.scan = ""
        ScanLogLbl.Text = ""
    end })

-- Tap Page
local TapControls = CreateSection(TapPage, "KONTROL")
TapControls.LayoutOrder = nextOrder()
CreateToggle(TapControls, "Aktifkan Mode Tap", tapOn, Colors.Accent,
    function(v) tapOn = v end)

local TapLogSection = CreateSection(TapPage, "LOG TAP")
TapLogSection.LayoutOrder = nextOrder()
local _tapBox
_tapBox, TapLogLbl = CreateLogBox(TapLogSection, 280)
TapLogLbl.Text = "Aktifkan Mode Tap, lalu sentuh objek di dunia."
CreateButtonRow(TapLogSection,
    { text = "📋 Copy", color = Colors.Success, callback = function(btn)
        copyText(logs.tap, btn)
    end },
    { text = "🗑 Clear", color = Colors.Danger, callback = function()
        logs.tap = ""
        TapLogLbl.Text = ""
    end })

-- Settings
local InfoSection = CreateSection(SettingsPage, "INFO")
InfoSection.LayoutOrder = nextOrder()
local InfoLbl = Instance.new("TextLabel")
InfoLbl.Size = UDim2.new(1, 0, 0, 80)
InfoLbl.BackgroundTransparency = 1
InfoLbl.Text = "NameCheck — Venyx Style\n\n• ESP: filter, label & koordinat\n• Scan: radius + scan + log\n• Tap: mode tap + log lengkap\n• Settings: cleanup"
InfoLbl.TextColor3 = Colors.TextDim
InfoLbl.Font = Enum.Font.Gotham
InfoLbl.TextSize = 12
InfoLbl.TextXAlignment = Enum.TextXAlignment.Left
InfoLbl.TextYAlignment = Enum.TextYAlignment.Top
InfoLbl.TextWrapped = true
InfoLbl.LayoutOrder = nextOrder()
InfoLbl.Parent = InfoSection

local ActionSection = CreateSection(SettingsPage, "AKSI")
ActionSection.LayoutOrder = nextOrder()
CreateButton(ActionSection, "🗑 Destroy UI", Colors.Danger,
    function() if env.__NAMECHECK_CLEANUP then env.__NAMECHECK_CLEANUP() end end)

-- =====================================================
-- FUNGSI CORE
-- =====================================================

refreshLabels = function(found)
    if not labelsOn or not found then
        for m, e in pairs(labelMap) do
            e.bb:Destroy(); labelMap[m] = nil
        end
        return
    end
    local desired = {}
    for i = 1, math.min(#found, MAXLABELS) do
        desired[found[i].model] = found[i]
    end
    for m, e in pairs(labelMap) do
        if not desired[m] then e.bb:Destroy(); labelMap[m] = nil end
    end
    for m, f in pairs(desired) do
        local e = labelMap[m]
        if not e then
            local bb = Instance.new("BillboardGui")
            bb.Adornee = f.part
            bb.Size = UDim2.new(0, 180, 0, 22)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Parent = ScreenGui
            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, 0, 1, 0)
            t.BackgroundTransparency = 1
            t.TextStrokeTransparency = 0
            t.Font = Enum.Font.GothamBold
            t.TextSize = 14
            t.Parent = bb
            e = { bb = bb, t = t, part = f.part }
            labelMap[m] = e
        elseif e.part ~= f.part then
            e.bb.Adornee = f.part
            e.part = f.part
        end
        e.t.TextColor3 = COLORS[f.kind]
        local plr = m:IsA("Model") and Players:GetPlayerFromCharacter(m)
        local nm = plr and (plr.DisplayName .. " @" .. plr.Name) or m.Name
        e.t.Text = string.format("%s [%d]", nm, math.floor(f.d))
    end
end

runScan = function()
    local found = collect()
    if not found then
        logs.scan = "Karakter belum siap."
        ScanLogLbl.Text = logs.scan
        return
    end
    local lines = {
        string.format("R %d | ditemukan %d (tampil maks %d)", radius, #found, MAXLIST),
        "",
    }
    for i = 1, math.min(#found, MAXLIST) do
        local f = found[i]
        local plr = f.model:IsA("Model") and Players:GetPlayerFromCharacter(f.model)
        local extra = plr and (" | display: " .. plr.DisplayName) or ""
        table.insert(lines, string.format("[%d] %s (%s)%s\n    %s",
            math.floor(f.d), f.model.Name, f.kind, extra, f.model:GetFullName()))
    end
    logs.scan = table.concat(lines, "\n")
    ScanLogLbl.Text = logs.scan
    refreshLabels(found)
end

-- Tap helpers
local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

local function getTags(inst)
    return safeCall(function() return inst:GetTags() end) or {}
end

local function getAttributes(inst)
    return safeCall(function() return inst:GetAttributes() end) or {}
end

local function describePart(part, lines)
    table.insert(lines, "=== PART ===")
    table.insert(lines, "Nama    : " .. part.Name)
    table.insert(lines, "Kelas   : " .. part.ClassName)
    table.insert(lines, "Path    : " .. part:GetFullName())
    if part:IsA("BasePart") then
        table.insert(lines, "Pos     : " .. tostring(part.Position))
        table.insert(lines, "Size    : " .. tostring(part.Size))
        table.insert(lines, "Material: " .. tostring(part.Material))
        table.insert(lines, "Transpar: " .. tostring(part.Transparency))
        table.insert(lines, "Reflect : " .. tostring(part.Reflectance))
        table.insert(lines, "Anchored: " .. tostring(part.Anchored))
        table.insert(lines, "CanCollide: " .. tostring(part.CanCollide))
        table.insert(lines, "CanTouch: " .. tostring(part.CanTouch))
        table.insert(lines, "Massless: " .. tostring(part.Massless))
    end
    local tags = getTags(part)
    if #tags > 0 then
        table.insert(lines, "Tags    : " .. table.concat(tags, ", "))
    end
    local attrs = getAttributes(part)
    local names = {}
    for k in pairs(attrs) do table.insert(names, k) end
    if #names > 0 then
        table.sort(names)
        table.insert(lines, "Attributes:")
        for _, k in ipairs(names) do
            table.insert(lines, "  " .. k .. " = " .. tostring(attrs[k]))
        end
    end
end

local function describeChildren(inst, lines, header)
    local ch = inst:GetChildren()
    table.insert(lines, header .. " (" .. #ch .. "):")
    if #ch == 0 then
        table.insert(lines, "  (kosong)")
        return
    end
    for _, c in ipairs(ch) do
        table.insert(lines, "  " .. c.Name .. " <" .. c.ClassName .. ">")
    end
end

local function describeModel(model, lines)
    table.insert(lines, "")
    table.insert(lines, "=== MODEL ===")
    local plr = Players:GetPlayerFromCharacter(model)
    table.insert(lines, "Nama     : " .. model.Name)
    table.insert(lines, "Path     : " .. model:GetFullName())
    table.insert(lines, "Tipe     : " .. kindOf(model))
    table.insert(lines, "Primary  : " .. tostring(model.PrimaryPart and model.PrimaryPart.Name))
    table.insert(lines, "Humanoid : " .. tostring(model:FindFirstChildOfClass("Humanoid") ~= nil))
    table.insert(lines, "AnimCtrl : " .. tostring(model:FindFirstChildWhichIsA("AnimationController", true) ~= nil))
    if plr then
        table.insert(lines, "Pemain   : " .. plr.Name .. " (" .. plr.DisplayName .. ")")
        table.insert(lines, "UserId   : " .. tostring(plr.UserId))
        table.insert(lines, "Team     : " .. tostring(plr.Team and plr.Team.Name))
    end
    local tags = getTags(model)
    if #tags > 0 then
        table.insert(lines, "Tags     : " .. table.concat(tags, ", "))
    end
    describeChildren(model, lines, "Children")
    local desc = model:GetDescendants()
    table.insert(lines, "Descendants (" .. #desc .. "):")
    local shown = math.min(#desc, MAX_DESC_SHOW)
    for i = 1, shown do
        local d = desc[i]
        table.insert(lines, "  " .. d.Name .. " <" .. d.ClassName .. ">")
    end
    if #desc > shown then
        table.insert(lines, "  ... +" .. (#desc - shown) .. " lagi (dipotong)")
    end
end

buildTapReport = function(part)
    local lines = {}
    table.insert(lines, "===== TAP REPORT =====")
    table.insert(lines, os.date("Waktu: %Y-%m-%d %H:%M:%S"))
    describePart(part, lines)
    describeChildren(part, lines, "Children Part")
    local model = part:FindFirstAncestorOfClass("Model")
    if model then describeModel(model, lines) end
    table.insert(lines, "")
    table.insert(lines, "=== PARENT CHAIN ===")
    local cur = part.Parent
    local depth = 0
    while cur and depth < 12 do
        table.insert(lines, "  " .. string.rep("> ", depth + 1) .. cur.Name .. " <" .. cur.ClassName .. ">")
        cur = cur.Parent
        depth = depth + 1
    end
    if cur then
        table.insert(lines, "  ... (lebih dalam lagi)")
    end
    return table.concat(lines, "\n")
end

-- =====================================================
-- INPUT TAP
-- =====================================================
connect(UIS.InputBegan, function(input, gp)
    if not tapOn or gp then return end
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    local t
    local cam = Workspace.CurrentCamera
    if cam then
        -- input.Position sudah dikoreksi inset GUI -> pakai ScreenPointToRay
        local ray = cam:ScreenPointToRay(input.Position.X, input.Position.Y)
        local params = RaycastParams.new()
        pcall(function() params.FilterType = Enum.RaycastFilterType.Exclude end)
        local ch = LP.Character
        if ch then params.FilterDescendantsInstances = { ch } end
        local res = Workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
        t = res and res.Instance
    end
    if not t then t = Mouse.Target end

    if not t then
        logs.tap = "Tap: tidak kena objek."
        TapLogLbl.Text = logs.tap
        return
    end
    logs.tap = buildTapReport(t)
    TapLogLbl.Text = logs.tap
    MainFrame.Visible = true
end)

-- Label auto-update (dibungkus pcall supaya error tidak mematikan loop)
task.spawn(function()
    while running do
        task.wait(0.7)
        if running and labelsOn then
            pcall(function() refreshLabels(collect()) end)
        end
    end
end)

-- Cleanup
env.__NAMECHECK_CLEANUP = function()
    running = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for m, e in pairs(labelMap) do
        pcall(function() e.bb:Destroy() end)
        labelMap[m] = nil
    end
    if ScreenGui then ScreenGui:Destroy() end
    env.__NAMECHECK_CLEANUP = nil
end

print("[NameCheck-Venyx] siap. Tombol ≡ di kiri layar.")

-- ========================================================
-- END OF FILE
-- ========================================================
