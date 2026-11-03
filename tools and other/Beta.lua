-- ========================================================
-- NAMECHECK — "baex trials" (v4 · Clean UI)
-- Tombol jendela:
--   [☐]  Besarkan  : normal <-> hampir layar penuh
--   [×]  Tutup     : muncul konfirmasi "Ya / Tidak"
-- ========================================================

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local LP           = Players.LocalPlayer
local Mouse        = LP:GetMouse()

local env = (getgenv and getgenv()) or _G
if env.__NAMECHECK_CLEANUP then pcall(env.__NAMECHECK_CLEANUP) end

-- ===== Konfigurasi =====
local WINDOW_TITLE  = "baex trials"
local WINDOW_SUB    = "NameCheck · ESP & Inspector"
local radius        = 100
local labelsOn      = false
local tapOn         = false
local MAXLIST       = 60
local MAXLABELS     = 25
local MAXSIZE       = 40
local MAX_DESC_SHOW = 80
local filters = { Pemain = true, Musuh = true, Entitas = true, Objek = false }

-- warna label di dunia game (sedikit diredam)
local COLORS = {
    Pemain  = Color3.fromRGB(120, 215, 150),
    Musuh   = Color3.fromRGB(235, 110, 110),
    Entitas = Color3.fromRGB(230, 200, 110),
    Objek   = Color3.fromRGB(120, 170, 230),
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
-- UI
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

-- Palet tenang: abu arang + biru baja
local C = {
    Window     = Color3.fromRGB(22, 23, 28),
    Stroke     = Color3.fromRGB(50, 53, 62),
    Panel      = Color3.fromRGB(31, 33, 40),
    PanelLine  = Color3.fromRGB(46, 49, 58),
    Control    = Color3.fromRGB(40, 43, 52),
    Text       = Color3.fromRGB(228, 230, 236),
    TextDim    = Color3.fromRGB(148, 154, 168),
    Accent     = Color3.fromRGB(84, 122, 170),
    Secondary  = Color3.fromRGB(46, 49, 58),
    Success    = Color3.fromRGB(62, 112, 90),
    Danger     = Color3.fromRGB(148, 66, 66),
    DangerSoft = Color3.fromRGB(214, 122, 122),
    TrackOff   = Color3.fromRGB(62, 65, 75),
    LogBg      = Color3.fromRGB(17, 18, 22),
    LogText    = Color3.fromRGB(190, 196, 208),
}

local function tween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function corner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r
    c.Parent = obj
    return c
end

local function stroke(obj, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thick or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

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

-- Tombol buka (bulat, gelap)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 46, 0, 46)
ToggleBtn.Position = UDim2.new(0.02, 0, 0.4, 0)
ToggleBtn.BackgroundColor3 = C.Window
ToggleBtn.Text = "≡"
ToggleBtn.TextColor3 = C.Text
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 24
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = ScreenGui
corner(ToggleBtn, UDim.new(1, 0))
stroke(ToggleBtn, C.Stroke, 1)

-- Ukuran jendela
local viewport = Vector2.new(800, 500)
do
    local cam = Workspace.CurrentCamera
    if cam then viewport = cam.ViewportSize end
end
local normalW = math.min(600, viewport.X - 20)
local normalH = math.min(400, viewport.Y - 20)
local normalPos = UDim2.new(0.5, -normalW / 2, 0.5, -normalH / 2)
local TITLE_H = 62

-- Frame utama
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, normalW, 0, normalH)
MainFrame.Position = normalPos
MainFrame.BackgroundColor3 = C.Window
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
corner(MainFrame, UDim.new(0, 16))
stroke(MainFrame, C.Stroke, 1)

local toggleDrag = makeDraggable(ToggleBtn, ToggleBtn)
ToggleBtn.MouseButton1Click:Connect(function()
    if toggleDrag.moved then return end
    MainFrame.Visible = not MainFrame.Visible
end)

-- Bilah judul (area drag)
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, TITLE_H)
TopBar.BackgroundTransparency = 1
TopBar.Parent = MainFrame
makeDraggable(TopBar, MainFrame)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -130, 0, 22)
TitleLbl.Position = UDim2.new(0, 22, 0, 12)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = WINDOW_TITLE
TitleLbl.TextColor3 = C.Text
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 16
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
TitleLbl.Parent = TopBar

local SubLbl = Instance.new("TextLabel")
SubLbl.Size = UDim2.new(1, -130, 0, 16)
SubLbl.Position = UDim2.new(0, 22, 0, 33)
SubLbl.BackgroundTransparency = 1
SubLbl.Text = WINDOW_SUB
SubLbl.TextColor3 = C.TextDim
SubLbl.Font = Enum.Font.Gotham
SubLbl.TextSize = 11
SubLbl.TextXAlignment = Enum.TextXAlignment.Left
SubLbl.TextTruncate = Enum.TextTruncate.AtEnd
SubLbl.Parent = TopBar

-- Tombol jendela
local WinBtns = Instance.new("Frame")
WinBtns.Size = UDim2.new(0, 74, 0, 30)
WinBtns.Position = UDim2.new(1, -88, 0, 16)
WinBtns.BackgroundTransparency = 1
WinBtns.Parent = TopBar

local function makeWinBtn(index)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(0, 34, 0, 30)
    B.Position = UDim2.new(0, (index - 1) * 40, 0, 0)
    B.BackgroundColor3 = C.Control
    B.Text = ""
    B.AutoButtonColor = false
    B.Parent = WinBtns
    corner(B, UDim.new(0, 8))
    return B
end

local MaxBtn, ClsBtn = makeWinBtn(1), makeWinBtn(2)

do -- glyph besarkan: kotak
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 11, 0, 11)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.BackgroundTransparency = 1
    f.Parent = MaxBtn
    stroke(f, C.TextDim, 2)
end
do -- glyph tutup: X
    for _, rot in ipairs({ 45, -45 }) do
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 15, 0, 2)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.new(0.5, 0, 0.5, 0)
        f.Rotation = rot
        f.BackgroundColor3 = C.DangerSoft
        f.BorderSizePixel = 0
        f.Parent = ClsBtn
    end
end

-- Sidebar (tab bulat)
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 48, 1, -(TITLE_H + 14))
Sidebar.Position = UDim2.new(0, 10, 0, TITLE_H)
Sidebar.BackgroundTransparency = 1
Sidebar.Parent = MainFrame
do
    local L = Instance.new("UIListLayout")
    L.SortOrder = Enum.SortOrder.LayoutOrder
    L.Padding = UDim.new(0, 10)
    L.HorizontalAlignment = Enum.HorizontalAlignment.Center
    L.VerticalAlignment = Enum.VerticalAlignment.Top
    L.Parent = Sidebar
end

-- Area konten
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -76, 1, -(TITLE_H + 14))
ContentArea.Position = UDim2.new(0, 66, 0, TITLE_H)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- Tinggi kotak log mengikuti ukuran jendela
local logBoxes = {}
local function setLogHeight(windowH)
    local h = math.max(120, windowH - 196)
    for _, b in ipairs(logBoxes) do b.Size = UDim2.new(1, 0, 0, h) end
end

-- State jendela: "normal" | "maximized"
local winState = "normal"

local function setState(s)
    local vp = (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or viewport
    if s == "maximized" then
        normalPos = MainFrame.Position
        tween(MainFrame, {
            Size = UDim2.new(0, vp.X - 20, 0, vp.Y - 20),
            Position = UDim2.new(0, 10, 0, 10),
        }, 0.2)
        setLogHeight(vp.Y - 20)
    else
        tween(MainFrame, { Size = UDim2.new(0, normalW, 0, normalH), Position = normalPos }, 0.2)
        setLogHeight(normalH)
    end
    winState = s
end

MaxBtn.MouseButton1Click:Connect(function()
    if winState == "maximized" then setState("normal") else setState("maximized") end
end)

-- Dialog konfirmasi tutup (Ya / Tidak)
local Confirm = Instance.new("TextButton")
Confirm.Size = UDim2.new(1, 0, 1, 0)
Confirm.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Confirm.BackgroundTransparency = 0.5
Confirm.BorderSizePixel = 0
Confirm.Text = ""
Confirm.AutoButtonColor = false
Confirm.Visible = false
Confirm.ZIndex = 50
Confirm.Parent = ScreenGui

do
    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(0, 300, 0, 156)
    Card.AnchorPoint = Vector2.new(0.5, 0.5)
    Card.Position = UDim2.new(0.5, 0, 0.5, 0)
    Card.BackgroundColor3 = C.Window
    Card.BorderSizePixel = 0
    Card.Parent = Confirm
    corner(Card, UDim.new(0, 14))
    stroke(Card, C.Stroke, 1)

    local T = Instance.new("TextLabel")
    T.Size = UDim2.new(1, -40, 0, 24)
    T.Position = UDim2.new(0, 20, 0, 16)
    T.BackgroundTransparency = 1
    T.Text = "Tutup NameCheck?"
    T.TextColor3 = C.Text
    T.Font = Enum.Font.GothamBold
    T.TextSize = 16
    T.TextXAlignment = Enum.TextXAlignment.Left
    T.Parent = Card

    local M = Instance.new("TextLabel")
    M.Size = UDim2.new(1, -40, 0, 50)
    M.Position = UDim2.new(0, 20, 0, 44)
    M.BackgroundTransparency = 1
    M.Text = "UI dan semua label ESP akan dihapus. Jalankan skrip lagi untuk membukanya kembali."
    M.TextColor3 = C.TextDim
    M.Font = Enum.Font.Gotham
    M.TextSize = 12
    M.TextWrapped = true
    M.TextXAlignment = Enum.TextXAlignment.Left
    M.TextYAlignment = Enum.TextYAlignment.Top
    M.Parent = Card

    local function dlgBtn(text, color, xScale, xOff, cb)
        local B = Instance.new("TextButton")
        B.Size = UDim2.new(0.5, -26, 0, 34)
        B.Position = UDim2.new(xScale, xOff, 1, -50)
        B.BackgroundColor3 = color
        B.Text = text
        B.TextColor3 = C.Text
        B.Font = Enum.Font.GothamBold
        B.TextSize = 13
        B.AutoButtonColor = false
        B.Parent = Card
        corner(B, UDim.new(0, 8))
        B.MouseButton1Click:Connect(cb)
        return B
    end

    dlgBtn("Tidak", C.Secondary, 0, 20, function() Confirm.Visible = false end)
    dlgBtn("Ya, tutup", C.Danger, 0.5, 6, function()
        if env.__NAMECHECK_CLEANUP then env.__NAMECHECK_CLEANUP() end
    end)
end

local function askClose() Confirm.Visible = true end
ClsBtn.MouseButton1Click:Connect(askClose)

-- Tabs
local Pages, TabButtons = {}, {}

local function setActiveTab(name)
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(TabButtons) do
        local on = (n == name)
        tween(b, {
            BackgroundColor3 = on and C.Accent or C.Control,
            TextColor3 = on and Color3.fromRGB(255, 255, 255) or C.TextDim,
        })
    end
end

local function CreateTab(name, label)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 44, 0, 44)
    Btn.BackgroundColor3 = C.Control
    Btn.Text = label
    Btn.TextColor3 = C.TextDim
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.AutoButtonColor = false
    Btn.Parent = Sidebar
    corner(Btn, UDim.new(1, 0))

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

-- LayoutOrder 0 = judul, 1 = garis, widget mulai dari 2
local orderCounter = 1
local function nextOrder()
    orderCounter = orderCounter + 1
    return orderCounter
end

-- Kartu kolom
local function CreateColumn(page, title, side)
    local Col = Instance.new("ScrollingFrame")
    Col.Size = UDim2.new(0.5, -5, 1, 0)
    Col.Position = (side == "L") and UDim2.new(0, 0, 0, 0) or UDim2.new(0.5, 5, 0, 0)
    Col.BackgroundColor3 = C.Panel
    Col.BorderSizePixel = 0
    Col.ScrollBarThickness = 2
    Col.ScrollBarImageColor3 = C.TrackOff
    Col.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Col.CanvasSize = UDim2.new(0, 0, 0, 0)
    Col.Parent = page
    corner(Col, UDim.new(0, 12))
    stroke(Col, C.PanelLine, 1)

    local Pad = Instance.new("UIPadding")
    Pad.PaddingTop = UDim.new(0, 12)
    Pad.PaddingBottom = UDim.new(0, 12)
    Pad.PaddingLeft = UDim.new(0, 14)
    Pad.PaddingRight = UDim.new(0, 14)
    Pad.Parent = Col

    local Lay = Instance.new("UIListLayout")
    Lay.SortOrder = Enum.SortOrder.LayoutOrder
    Lay.Padding = UDim.new(0, 8)
    Lay.Parent = Col

    local H = Instance.new("TextLabel")
    H.Size = UDim2.new(1, 0, 0, 16)
    H.BackgroundTransparency = 1
    H.Text = title
    H.TextColor3 = C.TextDim
    H.Font = Enum.Font.GothamBold
    H.TextSize = 11
    H.TextXAlignment = Enum.TextXAlignment.Left
    H.LayoutOrder = 0
    H.Parent = Col

    local Line = Instance.new("Frame")
    Line.Size = UDim2.new(1, 0, 0, 1)
    Line.BackgroundColor3 = C.PanelLine
    Line.BorderSizePixel = 0
    Line.LayoutOrder = 1
    Line.Parent = Col
    return Col
end

local function CreateText(parent, text, height)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, 0, 0, height or 60)
    L.BackgroundTransparency = 1
    L.Text = text
    L.TextColor3 = C.TextDim
    L.Font = Enum.Font.Gotham
    L.TextSize = 12
    L.TextWrapped = true
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.TextYAlignment = Enum.TextYAlignment.Top
    L.LayoutOrder = nextOrder()
    L.Parent = parent
    return L
end

-- Toggle bergaya switch; dotColor = penanda warna kategori (opsional)
local function CreateToggle(parent, text, default, dotColor, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 30)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent

    local textX = 0
    if dotColor then
        local Dot = Instance.new("Frame")
        Dot.Size = UDim2.new(0, 8, 0, 8)
        Dot.Position = UDim2.new(0, 0, 0.5, -4)
        Dot.BackgroundColor3 = dotColor
        Dot.BorderSizePixel = 0
        Dot.Parent = Row
        corner(Dot, UDim.new(1, 0))
        textX = 16
    end

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -(50 + textX), 1, 0)
    Lbl.Position = UDim2.new(0, textX, 0, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text
    Lbl.TextColor3 = C.Text
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 13
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.TextTruncate = Enum.TextTruncate.AtEnd
    Lbl.Parent = Row

    local Track = Instance.new("TextButton")
    Track.Size = UDim2.new(0, 40, 0, 22)
    Track.Position = UDim2.new(1, -40, 0.5, -11)
    Track.BackgroundColor3 = default and C.Accent or C.TrackOff
    Track.Text = ""
    Track.AutoButtonColor = false
    Track.Parent = Row
    corner(Track, UDim.new(1, 0))

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.AnchorPoint = Vector2.new(0, 0.5)
    Knob.Position = default and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    Knob.BackgroundColor3 = Color3.fromRGB(240, 242, 246)
    Knob.BorderSizePixel = 0
    Knob.Parent = Track
    corner(Knob, UDim.new(1, 0))

    local state = default
    Track.MouseButton1Click:Connect(function()
        state = not state
        tween(Track, { BackgroundColor3 = state and C.Accent or C.TrackOff })
        tween(Knob, { Position = state and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
        if callback then callback(state) end
    end)
    return Row
end

local function CreateButton(parent, text, color, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 34)
    Btn.BackgroundColor3 = color or C.Accent
    Btn.Text = text
    Btn.TextColor3 = C.Text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    Btn.AutoButtonColor = false
    Btn.LayoutOrder = nextOrder()
    Btn.Parent = parent
    corner(Btn, UDim.new(0, 8))
    Btn.MouseButton1Click:Connect(function() callback(Btn) end)
    return Btn
end

local function CreateButtonRow(parent, cfg1, cfg2)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 34)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent

    local function make(cfg, xScale, xOffset)
        local B = Instance.new("TextButton")
        B.Size = UDim2.new(0.5, -3, 1, 0)
        B.Position = UDim2.new(xScale, xOffset, 0, 0)
        B.BackgroundColor3 = cfg.color or C.Accent
        B.Text = cfg.text
        B.TextColor3 = C.Text
        B.Font = Enum.Font.GothamBold
        B.TextSize = 12
        B.AutoButtonColor = false
        B.Parent = Row
        corner(B, UDim.new(0, 8))
        if cfg.callback then
            B.MouseButton1Click:Connect(function() cfg.callback(B) end)
        end
        return B
    end

    make(cfg1, 0, 0)
    make(cfg2, 0.5, 3)
    return Row
end

-- Slider; mengembalikan setter agar bisa disinkronkan
local function CreateSlider(parent, text, min, max, default, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 44)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = nextOrder()
    Row.Parent = parent

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -56, 0, 18)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text
    Lbl.TextColor3 = C.Text
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 13
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Parent = Row

    local Val = Instance.new("TextLabel")
    Val.Size = UDim2.new(0, 52, 0, 18)
    Val.Position = UDim2.new(1, -52, 0, 0)
    Val.BackgroundTransparency = 1
    Val.Text = tostring(default)
    Val.TextColor3 = C.TextDim
    Val.Font = Enum.Font.GothamBold
    Val.TextSize = 12
    Val.TextXAlignment = Enum.TextXAlignment.Right
    Val.Parent = Row

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, 0, 0, 4)
    Bar.Position = UDim2.new(0, 0, 0, 31)
    Bar.BackgroundColor3 = C.TrackOff
    Bar.BorderSizePixel = 0
    Bar.Parent = Row
    corner(Bar, UDim.new(1, 0))

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = C.Accent
    Fill.BorderSizePixel = 0
    Fill.Parent = Bar
    corner(Fill, UDim.new(1, 0))

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 12, 0, 12)
    Knob.AnchorPoint = Vector2.new(0.5, 0.5)
    Knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
    Knob.BackgroundColor3 = Color3.fromRGB(240, 242, 246)
    Knob.BorderSizePixel = 0
    Knob.Parent = Bar
    corner(Knob, UDim.new(1, 0))

    local Hit = Instance.new("TextButton")
    Hit.Size = UDim2.new(1, 0, 0, 24)
    Hit.Position = UDim2.new(0, 0, 0, 21)
    Hit.BackgroundTransparency = 1
    Hit.Text = ""
    Hit.Parent = Row

    local function setValue(v)
        local rel = math.clamp((v - min) / (max - min), 0, 1)
        Val.Text = tostring(v)
        Fill.Size = UDim2.new(rel, 0, 1, 0)
        Knob.Position = UDim2.new(rel, 0, 0.5, 0)
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

local function CreateLogBox(parent)
    local Box = Instance.new("ScrollingFrame")
    Box.Size = UDim2.new(1, 0, 0, math.max(120, normalH - 196))
    Box.BackgroundColor3 = C.LogBg
    Box.BorderSizePixel = 0
    Box.ScrollBarThickness = 2
    Box.ScrollBarImageColor3 = C.TrackOff
    Box.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Box.CanvasSize = UDim2.new(0, 0, 0, 0)
    Box.LayoutOrder = nextOrder()
    Box.Parent = parent
    corner(Box, UDim.new(0, 8))
    table.insert(logBoxes, Box)

    local Pad = Instance.new("UIPadding")
    Pad.PaddingLeft = UDim.new(0, 8)
    Pad.PaddingRight = UDim.new(0, 8)
    Pad.PaddingTop = UDim.new(0, 8)
    Pad.PaddingBottom = UDim.new(0, 8)
    Pad.Parent = Box

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, 0, 0, 0)
    Lbl.AutomaticSize = Enum.AutomaticSize.Y
    Lbl.BackgroundTransparency = 1
    Lbl.TextWrapped = true
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.TextYAlignment = Enum.TextYAlignment.Top
    Lbl.TextColor3 = C.LogText
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
    btn.Text = "Tersalin"
    task.delay(1.5, function()
        if btn.Parent then btn.Text = original end
    end)
end

-- =====================================================
-- TABS & ISI
-- =====================================================
local ESPPage      = CreateTab("ESP", "ESP")
local ScanPage     = CreateTab("Scan", "Scan")
local TapPage      = CreateTab("Tap", "Tap")
local SettingsPage = CreateTab("Settings", "Set")

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
CreateToggle(EspR, "Label di atas objek", labelsOn, nil,
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
CreateButton(ScanL, "Scan Sekarang", C.Accent, function() runScan() end)
CreateText(ScanL, "Hasil tampil di kolom kanan. Atur filter di tab ESP.", 40)

local ScanR = CreateColumn(ScanPage, "LOG SCAN", "R")
local _scanBox
_scanBox, ScanLogLbl = CreateLogBox(ScanR)
ScanLogLbl.Text = "Tekan Scan untuk memindai sekitar."
CreateButtonRow(ScanR,
    { text = "Copy", color = C.Success, callback = function(btn)
        copyText(logs.scan, btn)
    end },
    { text = "Clear", color = C.Secondary, callback = function()
        logs.scan = ""
        ScanLogLbl.Text = ""
    end })

-- ---- Tap ----
local TapL = CreateColumn(TapPage, "KONTROL", "L")
CreateToggle(TapL, "Mode Tap", tapOn, nil, function(v) tapOn = v end)
CreateText(TapL, "Aktifkan, lalu sentuh objek di dunia. Buka menu (≡) untuk melihat laporan di kolom kanan.", 64)

local TapR = CreateColumn(TapPage, "LOG TAP", "R")
local _tapBox
_tapBox, TapLogLbl = CreateLogBox(TapR)
TapLogLbl.Text = "Belum ada tap."
CreateButtonRow(TapR,
    { text = "Copy", color = C.Success, callback = function(btn)
        copyText(logs.tap, btn)
    end },
    { text = "Clear", color = C.Secondary, callback = function()
        logs.tap = ""
        TapLogLbl.Text = ""
    end })

-- ---- Settings ----
local SetL = CreateColumn(SettingsPage, "INFO", "L")
CreateText(SetL,
    "NameCheck v4\n\n• ESP: filter & label\n• Scan: radius + log\n• Tap: info lengkap objek\n\n[☐] besarkan / kecilkan\n[×] tutup (dengan konfirmasi)\nGeser jendela lewat bilah judul.",
    170)

local SetR = CreateColumn(SettingsPage, "AKSI", "R")
CreateButton(SetR, "Tutup & Hapus UI", C.Danger, function() askClose() end)

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
            t.TextStrokeTransparency = 0.3
            t.Font = Enum.Font.GothamBold
            t.TextSize = 13
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

print("[NameCheck v4] siap. Tombol ≡ di kiri layar.")

-- ========================================================
-- END OF FILE
-- ========================================================
