-- ========================================================
-- NAMECHECK — BAEX STYLE v3 (UI ringkas + GUI Inspector terintegrasi)
-- ========================================================

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local Workspace    = game:GetService("Workspace")
local GuiService   = game:GetService("GuiService")
local LP           = Players.LocalPlayer
local Mouse        = LP:GetMouse()

local env = (getgenv and getgenv()) or _G
if env.__NAMECHECK_CLEANUP then pcall(env.__NAMECHECK_CLEANUP) end

local radius        = 100
local labelsOn      = false
local tapOn         = false
local coordOn       = false
local guiInspectOn  = false
local previewOn     = false
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
local logs     = { scan = "", tap = "", gui = "" }

local refreshLabels, runScan, buildTapReport
local ScanLogLbl, TapLogLbl, GuiLogLbl

local function connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(conns, c)
    return c
end

local function getRoot()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

-- ========================= DATA DUNIA =========================
local sources, parts = {}, {}

local function register(o)
    if o:IsA("Humanoid") or o:IsA("AnimationController") then
        sources[o] = true
    elseif o:IsA("BasePart") and not o:IsA("Terrain") then
        parts[o] = true
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

-- ========================= UI DASAR =========================
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
    TopBar      = Color3.fromRGB(26, 26, 26),
    Sidebar     = Color3.fromRGB(14, 14, 14),
    SecHeader   = Color3.fromRGB(34, 34, 34),
    TabActive   = Color3.fromRGB(45, 45, 45),
    TabInactive = Color3.fromRGB(14, 14, 14),
    Text        = Color3.fromRGB(255, 255, 255),
    TextDim     = Color3.fromRGB(170, 170, 170),
    Accent      = Color3.fromRGB(40, 140, 220),
    Danger      = Color3.fromRGB(200, 70, 70),
    Success     = Color3.fromRGB(70, 180, 90),
    ButtonOff   = Color3.fromRGB(50, 50, 50),
}

local old = CoreGui:FindFirstChild("BaexTrials")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BaexTrials"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
pcall(function() ScreenGui.ScreenInsets = Enum.ScreenInsets.None end)
ScreenGui.Parent = CoreGui

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 34, 0, 34)
ToggleBtn.Position = UDim2.new(0.02, 0, 0.4, 0)
ToggleBtn.BackgroundColor3 = Colors.Background
ToggleBtn.Text = "≡"
ToggleBtn.TextColor3 = Colors.Text
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 20
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)

local TOP_H   = 24
local FULL_W, FULL_H = 500, 330

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, FULL_W, 0, FULL_H)
MainFrame.Position = UDim2.new(0.5, -FULL_W / 2, 0.5, -FULL_H / 2)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Visible = false
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

do
    local cam = Workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        FULL_W = math.min(FULL_W, vp.X - 20)
        FULL_H = math.min(FULL_H, vp.Y - 20)
        MainFrame.Size = UDim2.new(0, FULL_W, 0, FULL_H)
        MainFrame.Position = UDim2.new(0.5, -FULL_W / 2, 0.5, -FULL_H / 2)
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, TOP_H)
TopBar.BackgroundColor3 = Colors.TopBar
TopBar.BorderSizePixel = 0
TopBar.Active = true
TopBar.Parent = MainFrame

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -70, 1, 0)
TitleLbl.Position = UDim2.new(0, 8, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "NameCheck · Baex"
TitleLbl.TextColor3 = Colors.Text
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 11
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Parent = TopBar

local function topBtn(text, xOff, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 20, 0, 18)
    b.Position = UDim2.new(1, xOff, 0.5, -9)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Colors.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = TopBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end
local MinBtn   = topBtn("–", -48, Colors.ButtonOff)
local CloseBtn = topBtn("×", -26, Colors.Danger)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

-- drag lewat TopBar (mouse & sentuh)
do
    local dragging, dragStart, startPos = false, nil, nil
    TopBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = MainFrame.Position
        end
    end)
    connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 34, 1, -TOP_H)
Sidebar.Position = UDim2.new(0, 0, 0, TOP_H)
Sidebar.BackgroundColor3 = Colors.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
local SB = Instance.new("UIListLayout")
SB.SortOrder = Enum.SortOrder.LayoutOrder
SB.Padding = UDim.new(0, 6)
SB.HorizontalAlignment = Enum.HorizontalAlignment.Center
SB.VerticalAlignment = Enum.VerticalAlignment.Top
SB.Parent = Sidebar
do
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, 6)
    p.Parent = Sidebar
end

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -40, 1, -(TOP_H + 6))
ContentArea.Position = UDim2.new(0, 37, 0, TOP_H + 3)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Sidebar.Visible = not minimized
    ContentArea.Visible = not minimized
    MainFrame.Size = minimized and UDim2.new(0, FULL_W, 0, TOP_H)
        or UDim2.new(0, FULL_W, 0, FULL_H)
    MinBtn.Text = minimized and "+" or "–"
end)

local Pages, TabButtons = {}, {}

local function selectTab(name)
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(TabButtons) do
        b.BackgroundColor3 = (n == name) and Colors.TabActive or Colors.TabInactive
        b.TextColor3 = (n == name) and Colors.Text or Colors.TextDim
    end
end

local tabOrder = 0
local function CreateTab(name, icon)
    tabOrder = tabOrder + 1
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 26, 0, 26)
    Btn.BackgroundColor3 = Colors.TabInactive
    Btn.Text = icon
    Btn.TextColor3 = Colors.TextDim
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 14
    Btn.LayoutOrder = tabOrder
    Btn.Parent = Sidebar
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

    local Page = Instance.new("ScrollingFrame")
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 3
    Page.ScrollBarImageColor3 = Colors.Accent
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.Visible = false
    Page.Parent = ContentArea
    local Lay = Instance.new("UIListLayout")
    Lay.SortOrder = Enum.SortOrder.LayoutOrder
    Lay.Padding = UDim.new(0, 4)
    Lay.Parent = Page

    Pages[name] = Page
    TabButtons[name] = Btn
    Btn.MouseButton1Click:Connect(function() selectTab(name) end)
    return Page
end

local orderCounter = 0
local function nextOrder()
    orderCounter = orderCounter + 1
    return orderCounter
end

-- Section bisa dilipat (klik judul). Mengembalikan frame isi.
-- Baris dua kolom: section di dalamnya mengisi ke samping dulu, lalu turun ke baris berikutnya.
local function CreateRow(parent)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -6, 0, 0)
    Row.AutomaticSize = Enum.AutomaticSize.Y
    Row.BackgroundTransparency = 1
    Row.BorderSizePixel = 0
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent
    local L = Instance.new("UIListLayout")
    L.FillDirection = Enum.FillDirection.Horizontal
    L.SortOrder = Enum.SortOrder.LayoutOrder
    L.VerticalAlignment = Enum.VerticalAlignment.Top
    L.Padding = UDim.new(0, 4)
    L.Parent = Row
    return Row
end

-- half = true: lebar setengah baris (dipakai di dalam CreateRow)
local function CreateSection(parent, title, startOpen, half)
    if startOpen == nil then startOpen = true end

    local Sec = Instance.new("Frame")
    Sec.Size = half and UDim2.new(0.5, -2, 0, 0) or UDim2.new(1, -6, 0, 0)
    Sec.AutomaticSize = Enum.AutomaticSize.Y
    Sec.BackgroundColor3 = Colors.TopBar
    Sec.BorderSizePixel = 0
    Sec.LayoutOrder = nextOrder()
    Sec.Parent = parent
    Instance.new("UICorner", Sec).CornerRadius = UDim.new(0, 6)

    local SecLay = Instance.new("UIListLayout")
    SecLay.SortOrder = Enum.SortOrder.LayoutOrder
    SecLay.Padding = UDim.new(0, 0)
    SecLay.Parent = Sec

    local Header = Instance.new("TextButton")
    Header.Size = UDim2.new(1, 0, 0, 18)
    Header.BackgroundColor3 = Colors.SecHeader
    Header.BorderSizePixel = 0
    Header.TextColor3 = Colors.TextDim
    Header.Font = Enum.Font.GothamBold
    Header.TextSize = 10
    Header.TextXAlignment = Enum.TextXAlignment.Left
    Header.LayoutOrder = 0
    Header.Parent = Sec
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 6)
    do
        local hp = Instance.new("UIPadding")
        hp.PaddingLeft = UDim.new(0, 8)
        hp.Parent = Header
    end

    local Body = Instance.new("Frame")
    Body.Size = UDim2.new(1, 0, 0, 0)
    Body.AutomaticSize = Enum.AutomaticSize.Y
    Body.BackgroundTransparency = 1
    Body.LayoutOrder = 1
    Body.Visible = startOpen
    Body.Parent = Sec
    local Pad = Instance.new("UIPadding")
    Pad.PaddingTop = UDim.new(0, 4)
    Pad.PaddingBottom = UDim.new(0, 5)
    Pad.PaddingLeft = UDim.new(0, 8)
    Pad.PaddingRight = UDim.new(0, 8)
    Pad.Parent = Body
    local Lay = Instance.new("UIListLayout")
    Lay.SortOrder = Enum.SortOrder.LayoutOrder
    Lay.Padding = UDim.new(0, 3)
    Lay.Parent = Body

    local function setHeader()
        Header.Text = (Body.Visible and "▾  " or "▸  ") .. title
    end
    setHeader()
    Header.MouseButton1Click:Connect(function()
        Body.Visible = not Body.Visible
        setHeader()
    end)
    return Body
end

local function CreateToggle(parent, text, default, accent, callback)
    accent = accent or Colors.Accent
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 20)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -46, 1, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text
    Lbl.TextColor3 = Colors.Text
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 11
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.TextTruncate = Enum.TextTruncate.AtEnd
    Lbl.Parent = Row

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 40, 0, 16)
    Btn.Position = UDim2.new(1, -40, 0.5, -8)
    Btn.BackgroundColor3 = default and accent or Colors.ButtonOff
    Btn.Text = default and "ON" or "OFF"
    Btn.TextColor3 = Colors.Text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 9
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
    Btn.Size = UDim2.new(1, 0, 0, 22)
    Btn.BackgroundColor3 = color or Colors.Accent
    Btn.Text = text
    Btn.TextColor3 = Colors.Text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.LayoutOrder = nextOrder()
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 5)
    Btn.MouseButton1Click:Connect(function() callback(Btn) end)
    return Btn
end

-- baris berisi beberapa tombol sejajar; cfgs = { {text,color,callback}, ... }
local function CreateButtonRow(parent, cfgs)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 22)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent
    local L = Instance.new("UIListLayout")
    L.FillDirection = Enum.FillDirection.Horizontal
    L.SortOrder = Enum.SortOrder.LayoutOrder
    L.Padding = UDim.new(0, 4)
    L.Parent = Row

    local n = #cfgs
    local btns = {}
    for i, cfg in ipairs(cfgs) do
        local B = Instance.new("TextButton")
        B.Size = UDim2.new(1 / n, -(4 * (n - 1)) / n, 1, 0)
        B.BackgroundColor3 = cfg.color or Colors.Accent
        B.Text = cfg.text
        B.TextColor3 = Colors.Text
        B.Font = Enum.Font.GothamBold
        B.TextSize = 10
        B.LayoutOrder = i
        B.Parent = Row
        Instance.new("UICorner", B).CornerRadius = UDim.new(0, 5)
        if cfg.callback then
            B.MouseButton1Click:Connect(function() cfg.callback(B) end)
        end
        btns[i] = B
    end
    return Row, btns
end

local function CreateSlider(parent, text, min, max, default, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 30)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -50, 0, 14)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text
    Lbl.TextColor3 = Colors.Text
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 11
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Parent = Row

    local Val = Instance.new("TextLabel")
    Val.Size = UDim2.new(0, 46, 0, 14)
    Val.Position = UDim2.new(1, -46, 0, 0)
    Val.BackgroundTransparency = 1
    Val.Text = tostring(default)
    Val.TextColor3 = Colors.TextDim
    Val.Font = Enum.Font.GothamBold
    Val.TextSize = 10
    Val.TextXAlignment = Enum.TextXAlignment.Right
    Val.Parent = Row

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, 0, 0, 4)
    Bar.Position = UDim2.new(0, 0, 0, 21)
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
    Hit.Size = UDim2.new(1, 0, 0, 18)
    Hit.Position = UDim2.new(0, 0, 0, 14)
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
    Box.Size = UDim2.new(1, 0, 0, height or 110)
    Box.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    Box.BorderSizePixel = 0
    Box.ScrollBarThickness = 3
    Box.ScrollBarImageColor3 = Colors.Accent
    Box.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Box.CanvasSize = UDim2.new(0, 0, 0, 0)
    Box.LayoutOrder = nextOrder()
    Box.Parent = parent
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 5)

    local Pad = Instance.new("UIPadding")
    Pad.PaddingLeft = UDim.new(0, 5)
    Pad.PaddingRight = UDim.new(0, 5)
    Pad.PaddingTop = UDim.new(0, 4)
    Pad.PaddingBottom = UDim.new(0, 4)
    Pad.Parent = Box

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, 0, 0, 0)
    Lbl.AutomaticSize = Enum.AutomaticSize.Y
    Lbl.BackgroundTransparency = 1
    Lbl.TextWrapped = true
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.TextYAlignment = Enum.TextYAlignment.Top
    Lbl.TextColor3 = Color3.fromRGB(215, 215, 215)
    Lbl.Font = Enum.Font.Code
    Lbl.TextSize = 10
    Lbl.Text = ""
    Lbl.Parent = Box
    return Box, Lbl
end

local function copyText(str, btn)
    if str == "" then return end
    local clip = setclipboard or toclipboard
    local old = btn.Text
    if clip then pcall(clip, str) else print(str) end
    btn.Text = "Tersalin!"
    task.delay(1.2, function()
        if btn.Parent then btn.Text = old end
    end)
end

-- ========================= KOORDINAT =========================
local CoordFrame = Instance.new("TextButton")
CoordFrame.Name = "CoordFrame"
CoordFrame.AutoButtonColor = false
CoordFrame.Text = ""
CoordFrame.Size = UDim2.new(0, 190, 0, 22)
CoordFrame.Position = UDim2.new(0.035, 0, 0.163, 0)
CoordFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
CoordFrame.BackgroundTransparency = 0.15
CoordFrame.BorderSizePixel = 0
CoordFrame.Visible = false
CoordFrame.ZIndex = 100
CoordFrame.Parent = ScreenGui
Instance.new("UICorner", CoordFrame).CornerRadius = UDim.new(0, 6)

local CoordLbl = Instance.new("TextLabel")
CoordLbl.Size = UDim2.new(1, -8, 1, -4)
CoordLbl.Position = UDim2.new(0, 4, 0, 2)
CoordLbl.BackgroundTransparency = 1
CoordLbl.Text = "X: 0  Y: 0  Z: 0"
CoordLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
CoordLbl.Font = Enum.Font.Code
CoordLbl.TextSize = 12
CoordLbl.ZIndex = 101
CoordLbl.Parent = CoordFrame

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

-- ========================= GUI INSPECTOR (terintegrasi) =========================
local guiStack, guiIndex = {}, 1
local hlObj, hlOverlay, hlGui

local function clearHighlight()
    if hlObj then pcall(function() hlObj:Destroy() end); hlObj = nil end
    if hlOverlay then hlOverlay.Visible = false end
end

local function makeHL()
    local f = Instance.new("Frame")
    f.Name = "InspectorHighlight"
    f.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    f.BackgroundTransparency = 0.8
    f.BorderSizePixel = 0
    f.Active = false
    f.ZIndex = 9999
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(255, 200, 0)
    s.Thickness = 3
    s.Parent = f
    return f
end

local function ensureHlGui()
    if hlGui and hlGui.Parent then return end
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    hlGui = Instance.new("ScreenGui")
    hlGui.Name = "InspectorHL"
    hlGui.ResetOnSpawn = false
    hlGui.DisplayOrder = 1000
    hlGui.IgnoreGuiInset = true
    hlGui.Parent = pg
    hlOverlay = makeHL()
    hlOverlay.Visible = false
    hlOverlay.Parent = hlGui
end

local function hasLayout(obj)
    for _, c in ipairs(obj:GetChildren()) do
        if c:IsA("UIGridStyleLayout") then return true end
    end
    return false
end

local function topInset()
    local v = GuiService:GetGuiInset().Y
    local ok2, r = pcall(function() return GuiService.TopbarInset.Height end)
    if ok2 and r and r > v then v = r end
    return v
end

local function updatePreview()
    clearHighlight()
    local obj = guiStack[guiIndex]
    if not previewOn or not obj or not obj:IsA("GuiObject") then return end
    ensureHlGui()
    if not hlOverlay then return end
    if not hasLayout(obj) then
        hlObj = makeHL()
        hlObj.Size = UDim2.new(1, 0, 1, 0)
        hlObj.Parent = obj
    else
        local sg = obj:FindFirstAncestorWhichIsA("ScreenGui")
        local off = (sg and not sg.IgnoreGuiInset) and topInset() or 0
        local p, s = obj.AbsolutePosition, obj.AbsoluteSize
        hlOverlay.Position = UDim2.fromOffset(p.X, p.Y + off)
        hlOverlay.Size = UDim2.fromOffset(s.X, s.Y)
        hlOverlay.Visible = true
    end
end

local function describeGui(obj, idx, total)
    local lines = {}
    local function add(k, v) table.insert(lines, k .. ": " .. tostring(v)) end
    add("Lapisan", idx .. " / " .. total)
    add("Name", obj.Name)
    add("ClassName", obj.ClassName)
    add("Path", obj:GetFullName())
    add("Parent", obj.Parent and (obj.Parent.Name .. " (" .. obj.Parent.ClassName .. ")") or "nil")
    if obj:IsA("GuiObject") then
        add("Visible", obj.Visible)
        add("ZIndex", obj.ZIndex)
        add("Active", obj.Active)
        add("Position", obj.Position)
        add("Size", obj.Size)
        add("AbsolutePosition", obj.AbsolutePosition)
        add("AbsoluteSize", obj.AbsoluteSize)
        add("BackgroundColor3", obj.BackgroundColor3)
        add("BackgroundTransparency", obj.BackgroundTransparency)
    end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        add("Text", obj.Text)
        add("TextSize", obj.TextSize)
    end
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        add("Image", obj.Image)
    end
    local children = {}
    for _, c in ipairs(obj:GetChildren()) do
        if c.Name ~= "InspectorHighlight" then table.insert(children, c) end
    end
    add("Children", #children)
    for i, c in ipairs(children) do
        if i > 30 then
            table.insert(lines, "  ... (" .. (#children - 30) .. " lagi)")
            break
        end
        table.insert(lines, "  [" .. i .. "] " .. c.Name .. " (" .. c.ClassName .. ")")
    end
    local dcount = 0
    for _, d in ipairs(obj:GetDescendants()) do
        if d.Name ~= "InspectorHighlight" and not d:FindFirstAncestor("InspectorHighlight") then
            dcount = dcount + 1
        end
    end
    add("Descendants", dcount)
    return table.concat(lines, "\n")
end

local function showGuiInfo()
    local obj = guiStack[guiIndex]
    if not obj then return end
    logs.gui = describeGui(obj, guiIndex, #guiStack)
    GuiLogLbl.Text = logs.gui
    updatePreview()
end

local function insideOwnUI(pos)
    local inset = GuiService:GetGuiInset()
    local x, y = pos.X + inset.X, pos.Y + inset.Y
    local function inside(f)
        if not f.Visible then return false end
        local p, s = f.AbsolutePosition, f.AbsoluteSize
        return x >= p.X - 2 and x <= p.X + s.X + 2 and y >= p.Y - 2 and y <= p.Y + s.Y + 2
    end
    return inside(MainFrame) or inside(ToggleBtn) or inside(CoordFrame)
end

connect(UIS.InputBegan, function(input)
    if not guiInspectOn then return end
    local t = input.UserInputType
    if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
    if insideOwnUI(input.Position) then return end

    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local hits = pg:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
    local filtered = {}
    for _, o in ipairs(hits) do
        if o.Name ~= "InspectorHighlight"
            and not o:IsDescendantOf(ScreenGui)
            and not (hlGui and o:IsDescendantOf(hlGui)) then
            table.insert(filtered, o)
        end
    end

    if #filtered == 0 then
        GuiLogLbl.Text = string.format("Tidak ada GUI di titik tap (%d, %d)",
            math.floor(input.Position.X), math.floor(input.Position.Y))
        return
    end
    guiStack, guiIndex = filtered, 1
    showGuiInfo()
end)

-- ========================= LAPORAN TAP DUNIA =========================
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

-- ========================= SUSUN TAB =========================
local DuniaPage   = CreateTab("Dunia", "👁")
local InspekPage  = CreateTab("Inspek", "👆")
local SetelanPage = CreateTab("Setelan", "⚙")
selectTab("Dunia")

-- ---- Tab Dunia: filter + label + scan, semua dalam satu halaman scroll ----
local DuniaRow1 = CreateRow(DuniaPage)
local FilterSec = CreateSection(DuniaRow1, "FILTER ESP", true, true)
CreateToggle(FilterSec, "Pemain", filters.Pemain, COLORS.Pemain,
    function(v) filters.Pemain = v end)
CreateToggle(FilterSec, "Musuh (Humanoid)", filters.Musuh, COLORS.Musuh,
    function(v) filters.Musuh = v end)
CreateToggle(FilterSec, "Entitas (AnimCtrl)", filters.Entitas, COLORS.Entitas,
    function(v) filters.Entitas = v end)
CreateToggle(FilterSec, "Objek (BasePart)", filters.Objek, COLORS.Objek,
    function(v) filters.Objek = v end)

local LabelSec = CreateSection(DuniaRow1, "LABEL & KOORDINAT", true, true)
CreateToggle(LabelSec, "Label di atas objek", labelsOn, Colors.Accent,
    function(v) labelsOn = v; refreshLabels(collect()) end)
CreateToggle(LabelSec, "Koordinat saya", coordOn, Colors.Accent,
    function(v)
        coordOn = v
        CoordFrame.Visible = v
    end)

local ScanSec = CreateSection(DuniaPage, "SCAN SEKITAR", true)
CreateSlider(ScanSec, "Radius", 10, 500, radius, function(v) radius = v end)
CreateButtonRow(ScanSec, {
    { text = "🔍 Scan", color = Colors.Accent, callback = function() runScan() end },
    { text = "📋 Salin", color = Colors.Success, callback = function(btn)
        copyText(logs.scan, btn)
    end },
    { text = "🗑 Hapus", color = Colors.Danger, callback = function()
        logs.scan = ""
        ScanLogLbl.Text = ""
    end },
})
local _scanBox
_scanBox, ScanLogLbl = CreateLogBox(ScanSec, 120)
ScanLogLbl.Text = "Tekan Scan untuk memindai sekitar."

-- ---- Tab Inspek: tap dunia + GUI inspector dalam satu halaman ----
local InspekRow1 = CreateRow(InspekPage)
local TapSec = CreateSection(InspekRow1, "TAP OBJEK DUNIA", true, true)
CreateToggle(TapSec, "Mode Tap (3D)", tapOn, Colors.Accent,
    function(v) tapOn = v end)
CreateButtonRow(TapSec, {
    { text = "📋 Salin", color = Colors.Success, callback = function(btn)
        copyText(logs.tap, btn)
    end },
    { text = "🗑 Hapus", color = Colors.Danger, callback = function()
        logs.tap = ""
        TapLogLbl.Text = ""
    end },
})
local _tapBox
_tapBox, TapLogLbl = CreateLogBox(TapSec, 110)
TapLogLbl.Text = "Aktifkan Mode Tap, lalu sentuh objek di dunia."

local GuiSec = CreateSection(InspekRow1, "GUI INSPECTOR", true, true)
CreateToggle(GuiSec, "Inspect GUI", guiInspectOn, Colors.Accent,
    function(v)
        guiInspectOn = v
        if not v then clearHighlight() end
    end)
CreateToggle(GuiSec, "Highlight elemen", previewOn, Colors.Accent,
    function(v)
        previewOn = v
        updatePreview()
    end)
CreateButtonRow(GuiSec, {
    { text = "◀", color = Colors.ButtonOff, callback = function()
        if #guiStack == 0 then return end
        guiIndex = (guiIndex - 2) % #guiStack + 1
        showGuiInfo()
    end },
    { text = "▶", color = Colors.ButtonOff, callback = function()
        if #guiStack == 0 then return end
        guiIndex = guiIndex % #guiStack + 1
        showGuiInfo()
    end },
    { text = "Salin", color = Colors.Success, callback = function(btn)
        copyText(logs.gui, btn)
    end },
    { text = "Hapus", color = Colors.Danger, callback = function()
        logs.gui = ""
        guiStack, guiIndex = {}, 1
        GuiLogLbl.Text = ""
        clearHighlight()
    end },
})
local _guiBox
_guiBox, GuiLogLbl = CreateLogBox(GuiSec, 130)
GuiLogLbl.Text = "Aktifkan Inspect GUI, lalu tap elemen GUI game di luar panel (geser/minimize panel bila menutupi)."

-- ---- Tab Setelan ----
local SetelanRow1 = CreateRow(SetelanPage)
local InfoSec = CreateSection(SetelanRow1, "INFO", true, true)
local InfoLbl = Instance.new("TextLabel")
InfoLbl.Size = UDim2.new(1, 0, 0, 0)
InfoLbl.AutomaticSize = Enum.AutomaticSize.Y
InfoLbl.BackgroundTransparency = 1
InfoLbl.Text = "NameCheck — Baex v3\n"
    .. "• Dunia: ESP, label, koordinat, scan\n"
    .. "• Inspek: tap 3D + GUI Inspector\n"
    .. "• Klik judul section untuk melipat\n"
    .. "• Tombol – untuk minimize panel"
InfoLbl.TextColor3 = Colors.TextDim
InfoLbl.Font = Enum.Font.Gotham
InfoLbl.TextSize = 10
InfoLbl.TextXAlignment = Enum.TextXAlignment.Left
InfoLbl.TextYAlignment = Enum.TextYAlignment.Top
InfoLbl.TextWrapped = true
InfoLbl.LayoutOrder = nextOrder()
InfoLbl.Parent = InfoSec

local ActionSec = CreateSection(SetelanRow1, "AKSI", true, true)
CreateButton(ActionSec, "🗑 Destroy UI", Colors.Danger, function()
    if env.__NAMECHECK_CLEANUP then env.__NAMECHECK_CLEANUP() end
end)

-- ========================= LOGIKA ESP / SCAN / TAP =========================
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
            bb.Size = UDim2.new(0, 160, 0, 18)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Parent = ScreenGui
            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, 0, 1, 0)
            t.BackgroundTransparency = 1
            t.TextStrokeTransparency = 0
            t.Font = Enum.Font.GothamBold
            t.TextSize = 12
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
    selectTab("Inspek")
    MainFrame.Visible = true
end)

task.spawn(function()
    while running do
        task.wait(0.7)
        if running and labelsOn then
            pcall(function() refreshLabels(collect()) end)
        end
    end
end)

env.__NAMECHECK_CLEANUP = function()
    running = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for m, e in pairs(labelMap) do
        pcall(function() e.bb:Destroy() end)
        labelMap[m] = nil
    end
    clearHighlight()
    if hlGui then pcall(function() hlGui:Destroy() end); hlGui = nil end
    if ScreenGui then ScreenGui:Destroy() end
    env.__NAMECHECK_CLEANUP = nil
end

print("[NameCheck-Baex v3] siap. Tombol ≡ di kiri layar.")
