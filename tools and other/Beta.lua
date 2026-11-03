-- ========================================================
-- NAMECHECK — "baex trials" UI (v3)
-- Desc  : ESP / Scan / Tap Inspector dengan tampilan jendela hitam,
--         tab bulat ungu, dan dua kolom abu-abu (MENU 1 | MENU 2)
-- Tombol jendela: [—] minimize  [☐] maximize  [×] tutup
-- ========================================================

local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LP        = Players.LocalPlayer
local Mouse     = LP:GetMouse()

local env = (getgenv and getgenv()) or _G
if env.__NAMECHECK_CLEANUP then pcall(env.__NAMECHECK_CLEANUP) end

-- ===== Konfigurasi =====
local WINDOW_TITLE  = "baex trials"
local radius        = 100
local labelsOn      = false
local tapOn         = false
local MAXLIST       = 60
local MAXLABELS     = 25
local MAXSIZE       = 40
local MAX_DESC_SHOW = 80
local filters = { Pemain = true, Musuh = true, Entitas = true, Objek = false }
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

-- ===== Sumber objek (Humanoid / AnimationController) =====
local sources = {}

local function register(o)
    if o:IsA("Humanoid") or o:IsA("AnimationController") then
        sources[o] = true
    end
end

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
connect(Workspace.DescendantRemoving, function(o) sources[o] = nil end)

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

local overlap = OverlapParams.new()
pcall(function() overlap.FilterType = Enum.RaycastFilterType.Exclude end)
overlap.MaxParts = 1000

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
        overlap.FilterDescendantsInstances = char and { char } or {}
        local ok, hits = pcall(function()
            return Workspace:GetPartBoundsInRadius(root.Position, radius, overlap)
        end)
        if ok and hits then
            for _, p in ipairs(hits) do
                if p.Size.Magnitude <= MAXSIZE then
                    local m = p:FindFirstAncestorOfClass("Model")
                    local isChar = m and (Players:GetPlayerFromCharacter(m)
                        or m:FindFirstChildOfClass("Humanoid"))
                    if not isChar then
                        local item = m or p
                        if not seen[item] then
                            seen[item] = true
                            table.insert(found, {
                                model = item, part = p,
                                d = (p.Position - root.Position).Magnitude,
                                kind = "Objek",
                            })
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
-- UI FRAMEWORK  (gaya "baex trials")
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
    Window       = Color3.fromRGB(0, 0, 0),
    Panel        = Color3.fromRGB(140, 140, 140),
    PanelDark    = Color3.fromRGB(95, 95, 95),
    HeaderText   = Color3.fromRGB(15, 15, 15),
    Text         = Color3.fromRGB(255, 255, 255),
    TextDim      = Color3.fromRGB(230, 230, 230),
    Purple       = Color3.fromRGB(112, 52, 130),
    PurpleActive = Color3.fromRGB(165, 95, 190),
    Green        = Color3.fromRGB(168, 222, 168),
    Glyph        = Color3.fromRGB(0, 0, 0),
    Accent       = Color3.fromRGB(40, 140, 220),
    Danger       = Color3.fromRGB(200, 70, 70),
    Success      = Color3.fromRGB(70, 180, 90),
    ButtonOff    = Color3.fromRGB(60, 60, 60),
    LogBg        = Color3.fromRGB(28, 28, 28),
}

local old = CoreGui:FindFirstChild("VenyxFramework")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VenyxFramework"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.ScreenInsets = Enum.ScreenInsets.None end)
ScreenGui.Parent = CoreGui

-- Drag (mouse + touch)
local function makeDraggable(handle, target)
    local state = { moved = false }
    local dragging, startPos, startInputPos = false, nil, nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            state.moved = false
            startPos = target.Position
            startInputPos = input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    connect(UIS.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startInputPos
            if delta.Magnitude > 6 then state.moved = true end
            if state.moved then
                target.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)
    return state
end

-- Tombol buka (bulat ungu)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0.02, 0, 0.4, 0)
ToggleBtn.BackgroundColor3 = Colors.Purple
ToggleBtn.Text = "≡"
ToggleBtn.TextColor3 = Colors.Text
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 26
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)

-- Ukuran jendela
local viewport = Vector2.new(800, 500)
do
    local cam = Workspace.CurrentCamera
    if cam then viewport = cam.ViewportSize end
end
local normalW = math.min(600, viewport.X - 20)
local normalH = math.min(400, viewport.Y - 20)
local curW, curH = normalW, normalH
local normalPos = UDim2.new(0.5, -normalW / 2, 0.5, -normalH / 2)

-- Frame utama
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, curW, 0, curH)
MainFrame.Position = normalPos
MainFrame.BackgroundColor3 = Colors.Window
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 18)

local toggleDrag = makeDraggable(ToggleBtn, ToggleBtn)
ToggleBtn.MouseButton1Click:Connect(function()
    if toggleDrag.moved then return end
    MainFrame.Visible = not MainFrame.Visible
end)

-- Bilah judul (area drag)
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 62)
TopBar.BackgroundTransparency = 1
TopBar.Parent = MainFrame
makeDraggable(TopBar, MainFrame)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -170, 1, 0)
TitleLbl.Position = UDim2.new(0, 26, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = WINDOW_TITLE
TitleLbl.TextColor3 = Colors.Text
TitleLbl.Font = Enum.Font.GothamBlack
TitleLbl.TextSize = 20
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
TitleLbl.Parent = TopBar

-- Kotak hijau berisi tombol jendela
local WinBtns = Instance.new("Frame")
WinBtns.Size = UDim2.new(0, 120, 0, 40)
WinBtns.Position = UDim2.new(1, -136, 0, 11)
WinBtns.BackgroundColor3 = Colors.Green
WinBtns.BorderSizePixel = 0
WinBtns.Parent = TopBar
Instance.new("UICorner", WinBtns).CornerRadius = UDim.new(0, 3)

local function makeWinBtn(index)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(1 / 3, 0, 1, 0)
    B.Position = UDim2.new((index - 1) / 3, 0, 0, 0)
    B.BackgroundTransparency = 1
    B.Text = ""
    B.AutoButtonColor = false
    B.Parent = WinBtns
    return B
end

local MinBtn, MaxBtn, ClsBtn = makeWinBtn(1), makeWinBtn(2), makeWinBtn(3)

do -- glyph minimize: garis
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 16, 0, 3)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.BackgroundColor3 = Colors.Glyph
    f.BorderSizePixel = 0
    f.Parent = MinBtn
end
do -- glyph maximize: kotak
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 14, 0, 12)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.BackgroundTransparency = 1
    f.Parent = MaxBtn
    local s = Instance.new("UIStroke")
    s.Thickness = 3
    s.Color = Colors.Glyph
    s.Parent = f
end
do -- glyph tutup: X dari dua garis
    for _, rot in ipairs({ 45, -45 }) do
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 20, 0, 3)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.new(0.5, 0, 0.5, 0)
        f.Rotation = rot
        f.BackgroundColor3 = Colors.Glyph
        f.BorderSizePixel = 0
        f.Parent = ClsBtn
    end
end

-- Sidebar (tab bulat ungu)
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 48, 1, -76)
Sidebar.Position = UDim2.new(0, 8, 0, 62)
Sidebar.BackgroundTransparency = 1
Sidebar.Parent = MainFrame
local SB = Instance.new("UIListLayout")
SB.SortOrder = Enum.SortOrder.LayoutOrder
SB.Padding = UDim.new(0, 12)
SB.HorizontalAlignment = Enum.HorizontalAlignment.Center
SB.VerticalAlignment = Enum.VerticalAlignment.Top
SB.Parent = Sidebar

-- Area konten (2 kolom per tab)
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -76, 1, -76)
ContentArea.Position = UDim2.new(0, 64, 0, 62)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- Logika tombol jendela
local minimized, maximized = false, false

local function applySize()
    MainFrame.Size = UDim2.new(0, curW, 0, minimized and 62 or curH)
    ContentArea.Visible = not minimized
    Sidebar.Visible = not minimized
end

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    applySize()
end)

MaxBtn.MouseButton1Click:Connect(function()
    minimized = false
    maximized = not maximized
    if maximized then
        normalPos = MainFrame.Position
        local cam = Workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or viewport
        curW, curH = vp.X - 20, vp.Y - 20
        MainFrame.Position = UDim2.new(0, 10, 0, 10)
    else
        curW, curH = normalW, normalH
        MainFrame.Position = normalPos
    end
    applySize()
end)

ClsBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

-- Tabs
local Pages, TabButtons = {}, {}

local function setActiveTab(name)
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(TabButtons) do
        local on = (n == name)
        b.BackgroundColor3 = on and Colors.PurpleActive or Colors.Purple
    end
end

local function CreateTab(name, icon)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 44, 0, 44)
    Btn.BackgroundColor3 = Colors.Purple
    Btn.Text = icon
    Btn.TextColor3 = Colors.Text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 18
    Btn.Parent = Sidebar
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(1, 0)

    local Page = Instance.new("Frame")
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.Parent = ContentArea

    Pages[name] = Page
    TabButtons[name] = Btn
    Btn.MouseButton1Click:Connect(function() setActiveTab(name) end)
    return Page
end

local orderCounter = 0
local function nextOrder()
    orderCounter = orderCounter + 1
    return orderCounter
end

-- Kolom abu-abu dengan judul ("MENU 1" / "MENU 2")
local function CreateColumn(page, title, side)
    local Col = Instance.new("ScrollingFrame")
    Col.Size = UDim2.new(0.5, -4, 1, 0)
    Col.Position = (side == "L") and UDim2.new(0, 0, 0, 0) or UDim2.new(0.5, 4, 0, 0)
    Col.BackgroundColor3 = Colors.Panel
    Col.BorderSizePixel = 0
    Col.ScrollBarThickness = 3
    Col.ScrollBarImageColor3 = Colors.PanelDark
    Col.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Col.CanvasSize = UDim2.new(0, 0, 0, 0)
    Col.Parent = page

    local Pad = Instance.new("UIPadding")
    Pad.PaddingTop = UDim.new(0, 8)
    Pad.PaddingBottom = UDim.new(0, 10)
    Pad.PaddingLeft = UDim.new(0, 10)
    Pad.PaddingRight = UDim.new(0, 10)
    Pad.Parent = Col

    local Lay = Instance.new("UIListLayout")
    Lay.SortOrder = Enum.SortOrder.LayoutOrder
    Lay.Padding = UDim.new(0, 8)
    Lay.Parent = Col

    local H = Instance.new("TextLabel")
    H.Size = UDim2.new(1, 0, 0, 32)
    H.BackgroundTransparency = 1
    H.Text = title
    H.TextColor3 = Colors.HeaderText
    H.Font = Enum.Font.GothamBlack
    H.TextSize = 18
    H.LayoutOrder = 0
    H.Parent = Col
    return Col
end

local function CreateText(parent, text, height)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, 0, 0, height or 60)
    L.BackgroundTransparency = 1
    L.Text = text
    L.TextColor3 = Colors.TextDim
    L.Font = Enum.Font.Gotham
    L.TextSize = 13
    L.TextWrapped = true
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.TextYAlignment = Enum.TextYAlignment.Top
    L.LayoutOrder = nextOrder()
    L.Parent = parent
    return L
end

local function CreateToggle(parent, text, default, accent, callback)
    accent = accent or Colors.Accent
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 32)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -62, 1, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text
    Lbl.TextColor3 = Colors.Text
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 14
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.TextTruncate = Enum.TextTruncate.AtEnd
    Lbl.Parent = Row

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 52, 0, 24)
    Btn.Position = UDim2.new(1, -52, 0.5, -12)
    Btn.BackgroundColor3 = default and accent or Colors.ButtonOff
    Btn.Text = default and "ON" or "OFF"
    Btn.TextColor3 = Colors.Text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.Parent = Row
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(1, 0)

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
    Btn.Size = UDim2.new(1, 0, 0, 32)
    Btn.BackgroundColor3 = color or Colors.Accent
    Btn.Text = text
    Btn.TextColor3 = Colors.Text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.LayoutOrder = nextOrder()
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    Btn.MouseButton1Click:Connect(function() callback(Btn) end)
    return Btn
end

local function CreateButtonRow(parent, cfg1, cfg2)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 32)
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

    make(cfg1, 0, 0)
    make(cfg2, 0.5, 3)
    return Row
end

-- Slider; mengembalikan fungsi setter (untuk sinkronisasi antar-slider)
local function CreateSlider(parent, text, min, max, default, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 46)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -60, 0, 20)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text
    Lbl.TextColor3 = Colors.Text
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 14
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Parent = Row

    local Val = Instance.new("TextLabel")
    Val.Size = UDim2.new(0, 56, 0, 20)
    Val.Position = UDim2.new(1, -56, 0, 0)
    Val.BackgroundTransparency = 1
    Val.Text = tostring(default)
    Val.TextColor3 = Colors.Text
    Val.Font = Enum.Font.GothamBold
    Val.TextSize = 13
    Val.TextXAlignment = Enum.TextXAlignment.Right
    Val.Parent = Row

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, 0, 0, 6)
    Bar.Position = UDim2.new(0, 0, 0, 32)
    Bar.BackgroundColor3 = Colors.PanelDark
    Bar.BorderSizePixel = 0
    Bar.Parent = Row
    Instance.new("UICorner", Bar).CornerRadius = UDim.new(1, 0)

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Colors.PurpleActive
    Fill.BorderSizePixel = 0
    Fill.Parent = Bar
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local Hit = Instance.new("TextButton")
    Hit.Size = UDim2.new(1, 0, 0, 26)
    Hit.Position = UDim2.new(0, 0, 0, 22)
    Hit.BackgroundTransparency = 1
    Hit.Text = ""
    Hit.Parent = Row

    local function setValue(v)
        local rel = math.clamp((v - min) / (max - min), 0, 1)
        Val.Text = tostring(v)
        Fill.Size = UDim2.new(rel, 0, 1, 0)
    end

    local dragging = false
    local function update(x)
        local w = Bar.AbsoluteSize.X
        if w <= 0 then return end
        local rel = math.clamp((x - Bar.AbsolutePosition.X) / w, 0, 1)
        local v = math.floor(min + rel * (max - min) + 0.5)
        setValue(v)
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
    return Row, setValue
end

local function CreateLogBox(parent, height)
    local Box = Instance.new("ScrollingFrame")
    Box.Size = UDim2.new(1, 0, 0, height or 190)
    Box.BackgroundColor3 = Colors.LogBg
    Box.BorderSizePixel = 0
    Box.ScrollBarThickness = 3
    Box.ScrollBarImageColor3 = Colors.PurpleActive
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
    Lbl.TextColor3 = Color3.fromRGB(225, 225, 225)
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
    local original = btn.Text
    btn.Text = "Copied!"
    task.delay(1.5, function()
        if btn.Parent then btn.Text = original end
    end)
end

-- =====================================================
-- TABS & ISI (MENU 1 | MENU 2 di setiap tab)
-- =====================================================
local ESPPage      = CreateTab("ESP", "👁")
local ScanPage     = CreateTab("Scan", "🔍")
local TapPage      = CreateTab("Tap", "👆")
local SettingsPage = CreateTab("Settings", "⚙")

setActiveTab("ESP")

-- Slider radius dipakai di ESP dan Scan, nilainya disinkronkan
local radiusSetters = {}
local function onRadius(v)
    radius = v
    for _, s in ipairs(radiusSetters) do s(v) end
end

-- ---- ESP ----
local EspL = CreateColumn(ESPPage, "FILTER", "L")
CreateToggle(EspL, "Pemain", filters.Pemain, COLORS.Pemain,
    function(v) filters.Pemain = v end)
CreateToggle(EspL, "Musuh (Humanoid)", filters.Musuh, COLORS.Musuh,
    function(v) filters.Musuh = v end)
CreateToggle(EspL, "Entitas (AnimCtrl)", filters.Entitas, COLORS.Entitas,
    function(v) filters.Entitas = v end)
CreateToggle(EspL, "Objek (BasePart)", filters.Objek, COLORS.Objek,
    function(v) filters.Objek = v end)

local EspR = CreateColumn(ESPPage, "LABEL", "R")
CreateToggle(EspR, "Label di atas objek", labelsOn, Colors.PurpleActive,
    function(v) labelsOn = v; refreshLabels(collect()) end)
do
    local _, set = CreateSlider(EspR, "Radius", 10, 500, radius, onRadius)
    table.insert(radiusSetters, set)
end

-- ---- Scan ----
local ScanL = CreateColumn(ScanPage, "KONTROL", "L")
do
    local _, set = CreateSlider(ScanL, "Radius", 10, 500, radius, onRadius)
    table.insert(radiusSetters, set)
end
CreateButton(ScanL, "🔍  Scan Sekarang", Colors.PurpleActive, function() runScan() end)
CreateText(ScanL, "Hasil scan tampil di kolom kanan. Atur filter di tab ESP.", 50)

local ScanR = CreateColumn(ScanPage, "LOG SCAN", "R")
local _scanBox
_scanBox, ScanLogLbl = CreateLogBox(ScanR, 190)
ScanLogLbl.Text = "Tekan tombol Scan untuk memindai sekitar."
CreateButtonRow(ScanR,
    { text = "📋 Copy", color = Colors.Success, callback = function(btn)
        copyText(logs.scan, btn)
    end },
    { text = "🗑 Clear", color = Colors.Danger, callback = function()
        logs.scan = ""
        ScanLogLbl.Text = ""
    end })

-- ---- Tap ----
local TapL = CreateColumn(TapPage, "KONTROL", "L")
CreateToggle(TapL, "Mode Tap", tapOn, Colors.PurpleActive,
    function(v) tapOn = v end)
CreateText(TapL, "Aktifkan Mode Tap, lalu sentuh objek di dunia. Laporan tampil di kolom kanan.", 70)

local TapR = CreateColumn(TapPage, "LOG TAP", "R")
local _tapBox
_tapBox, TapLogLbl = CreateLogBox(TapR, 190)
TapLogLbl.Text = "Belum ada tap."
CreateButtonRow(TapR,
    { text = "📋 Copy", color = Colors.Success, callback = function(btn)
        copyText(logs.tap, btn)
    end },
    { text = "🗑 Clear", color = Colors.Danger, callback = function()
        logs.tap = ""
        TapLogLbl.Text = ""
    end })

-- ---- Settings ----
local SetL = CreateColumn(SettingsPage, "INFO", "L")
CreateText(SetL,
    "NameCheck v3\n\n• ESP: filter & label\n• Scan: radius + log\n• Tap: info lengkap objek\n• Geser jendela lewat bilah judul\n• [—] kecilkan  [☐] besarkan  [×] tutup",
    130)

local SetR = CreateColumn(SettingsPage, "AKSI", "R")
CreateButton(SetR, "🗑 Destroy UI", Colors.Danger, function()
    if env.__NAMECHECK_CLEANUP then env.__NAMECHECK_CLEANUP() end
end)

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
    setActiveTab("Tap")
end)

-- Label auto-update
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

print("[NameCheck v3] siap. Tombol ≡ di kiri layar.")

-- ========================================================
-- END OF FILE
-- ========================================================
