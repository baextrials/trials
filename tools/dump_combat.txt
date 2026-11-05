-- Dump Combat: membaca (decompile) skrip combat game, tombol SALIN per skrip.
-- Hanya membaca, tidak mengubah apa pun.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function resolve(path)
    local cur
    for i, name in ipairs(path) do
        if i == 1 then
            if name == "Workspace" then cur = workspace
            elseif name == "Player" then cur = player
            end
        else
            cur = cur and cur:FindFirstChild(name)
        end
        if not cur then return nil end
    end
    return cur
end

local TARGETS = {
    { "ClickTargetSelector",      {"Workspace","Src","Combat","ClickTargetSelector"} },
    { "CombatManager",            {"Workspace","Src","Combat","CombatManager"} },
    { "ProximityTargetSelector",  {"Workspace","Src","Combat","ProximityTargetSelector"} },
    { "AutoCombatToggleController", {"Player","PlayerGui","HUD","AutoCombatToggleButton","AutoCombatToggleController"} },
    { "Spirit.Combat (state)",    {"Workspace","Src","StateMachines","Spirit","Combat"} },
    { "NpcBehaviors.Attack",      {"Workspace","Src","Spirits","NpcBehaviors","Attack"} },
    { "TargetIndicator",          {"Workspace","Src","Combat","TargetIndicator"} },
    { "TGSMisc.Input",            {"Workspace","Lib","TGSMisc","Input"} },
}

local function guiParent()
    local ok, ui = pcall(function() return gethui() end)
    if ok and ui then return ui end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then return core end
    return player:WaitForChild("PlayerGui")
end

local old = guiParent():FindFirstChild("DumpCombatGui")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "DumpCombatGui"
gui.ResetOnSpawn = false
gui.Parent = guiParent()

local frame = Instance.new("Frame")
local FULL_W, FULL_H, MIN_H = 250, 270, 30
frame.Size = UDim2.fromOffset(FULL_W, FULL_H)
frame.Position = UDim2.new(1, -FULL_W - 10, 0, 40)
frame.ClipsDescendants = true
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 26)
title.Position = UDim2.fromOffset(8, 2)
title.BackgroundTransparency = 1
title.Text = "Dump Combat"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextWrapped = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.Parent = frame

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -84)
list.Position = UDim2.fromOffset(8, 34)
list.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.Parent = frame
local layout = Instance.new("UIListLayout", list)
layout.Padding = UDim.new(0, 6)
Instance.new("UIPadding", list).PaddingTop = UDim.new(0, 6)

for _, t in ipairs(TARGETS) do
    local label, path = t[1], t[2]
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -12, 0, 34)
    b.BackgroundColor3 = Color3.fromRGB(60, 130, 90)
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.TextWrapped = true
    b.Text = "SALIN: " .. label
    b.Parent = list
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

    b.MouseButton1Click:Connect(function()
        local sc = resolve(path)
        if not sc then
            b.Text = label .. ": TIDAK DITEMUKAN"
            b.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
            return
        end
        local ok, src = pcall(decompile, sc)
        if not ok or type(src) ~= "string" or #src == 0 then
            b.Text = label .. ": decompile gagal"
            b.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
            return
        end
        local text = "-- " .. sc:GetFullName() .. "\n" .. src
        local copied = pcall(setclipboard, text)
        b.Text = (copied and "TERSALIN: " or "GAGAL SALIN: ") .. label .. " (" .. #text .. " karakter)"
    end)
end

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(1, -16, 0, 34)
closeBtn.Position = UDim2.new(0, 8, 1, -40)
closeBtn.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "TUTUP"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- tombol minimize: sembunyikan isi, sisakan judul kecil
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(28, 22)
minBtn.Position = UDim2.new(1, -34, 0, 4)
minBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
minBtn.BorderSizePixel = 0
minBtn.Text = "-"
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 14
minBtn.Parent = frame
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    list.Visible = not minimized
    closeBtn.Visible = not minimized
    frame.Size = UDim2.fromOffset(FULL_W, minimized and MIN_H or FULL_H)
    minBtn.Text = minimized and "+" or "-"
end)
