-- Made By @FoundCount2
-- By ZAHER INFINITY
-- ស្គ្រីប Roblox: លួចស៊ុតស្វ័យប្រវត្តិ (Auto Egg Steal)
-- តួអង្គ: palofsc
-- ចំណាំ: ស្គ្រីបនេះសម្រាប់ហ្គេម "Steal an Egg" ប៉ុណ្ណោះ
-- ត្រូវការ Executor ដូចជា Delta, Fluxus, Solara, Krnl

-- // SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Root = Character:WaitForChild("HumanoidRootPart")

-- // CONFIG
local CONFIG = {
    AutoSteal = true,        -- បើក/បិទ លួចស្វ័យប្រវត្តិ
    AutoHatch = true,        -- បើក/បិទ បើកស៊ុតស្វ័យប្រវត្តិ
    StealDistance = 8,       -- ចម្ងាយដើម្បីលួច (studs)
    TeleportSpeed = 250,     -- ល្បឿន teleport
    LoopDelay = 0.1,         -- ការពន្យារ loop (វិនាទី)
}

-- // GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZaherEggSteal"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 220, 0, 140)
Frame.Position = UDim2.new(0, 20, 0, 100)
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Frame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
Title.BorderSizePixel = 0
Title.Text = "ZAHER INFINITY - EGG STEAL"
Title.TextColor3 = Color3.fromRGB(0, 255, 150)
Title.TextScaled = true
Title.Font = Enum.Font.GothamBold
Title.Parent = Frame

local ToggleSteal = Instance.new("TextButton")
ToggleSteal.Size = UDim2.new(0.9, 0, 0, 30)
ToggleSteal.Position = UDim2.new(0.05, 0, 0.28, 0)
ToggleSteal.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
ToggleSteal.Text = "Auto Steal: ON"
ToggleSteal.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleSteal.TextScaled = true
ToggleSteal.Font = Enum.Font.Gotham
ToggleSteal.Parent = Frame

local ToggleHatch = Instance.new("TextButton")
ToggleHatch.Size = UDim2.new(0.9, 0, 0, 30)
ToggleHatch.Position = UDim2.new(0.05, 0, 0.55, 0)
ToggleHatch.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
ToggleHatch.Text = "Auto Hatch: ON"
ToggleHatch.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleHatch.TextScaled = true
ToggleHatch.Font = Enum.Font.Gotham
ToggleHatch.Parent = Frame

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 20)
Status.Position = UDim2.new(0, 0, 0.85, 0)
Status.BackgroundTransparency = 1
Status.Text = "រង់ចាំ..."
Status.TextColor3 = Color3.fromRGB(200, 200, 200)
Status.TextScaled = true
Status.Font = Enum.Font.Gotham
Status.Parent = Frame

-- // TOGGLE LOGIC
ToggleSteal.MouseButton1Click:Connect(function()
    CONFIG.AutoSteal = not CONFIG.AutoSteal
    ToggleSteal.Text = "Auto Steal: " .. (CONFIG.AutoSteal and "ON" or "OFF")
    ToggleSteal.BackgroundColor3 = CONFIG.AutoSteal and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(150, 30, 30)
end)

ToggleHatch.MouseButton1Click:Connect(function()
    CONFIG.AutoHatch = not CONFIG.AutoHatch
    ToggleHatch.Text = "Auto Hatch: " .. (CONFIG.AutoHatch and "ON" or "OFF")
    ToggleHatch.BackgroundColor3 = CONFIG.AutoHatch and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(150, 30, 30)
end)

-- // FIND EGGS
local function GetEggs()
    local eggs = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = string.lower(obj.Name)
            if string.find(name, "egg") and not string.find(name, "hatch") then
                eggs[#eggs + 1] = obj
            end
        end
    end
    return eggs
end

-- // TELEPORT TO EGG
local function TeleportTo(target)
    if not target or not Root then return end
    local pos
    if target:IsA("BasePart") then
        pos = target.Position
    elseif target:IsA("Model") and target.PrimaryPart then
        pos = target.PrimaryPart.Position
    else
        local ok, pivot = pcall(function() return target:GetPivot().Position end)
        if ok then pos = pivot end
    end
    if pos then
        Root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end
end

-- // STEAL VIA PROXIMITYPROMPT
local function TrySteal(egg)
    local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        for _, d in ipairs(egg:GetDescendants()) do
            if d:IsA("ProximityPrompt") then prompt = d break end
        end
    end
    if prompt then
        pcall(function()
            fireproximityprompt(prompt)
        end)
        return true
    end
    return false
end

-- // STEAL VIA REMOTE
local function TryRemoteSteal(egg)
    local remotes = ReplicatedStorage:GetDescendants()
    for _, r in ipairs(remotes) do
        if r:IsA("RemoteEvent") then
            local n = string.lower(r.Name)
            if string.find(n, "steal") or string.find(n, "egg") or string.find(n, "collect") then
                pcall(function()
                    r:FireServer(egg)
                end)
            end
        end
    end
end

-- // MAIN LOOP
task.spawn(function()
    while task.wait(CONFIG.LoopDelay) do
        if not CONFIG.AutoSteal then
            Status.Text = "Steal OFF"
            continue
        end

        local eggs = GetEggs()
        if #eggs == 0 then
            Status.Text = "រកមិនឃើញស៊ុត"
            continue
        end

        table.sort(eggs, function(a, b)
            local pa = a:IsA("BasePart") and a.Position or (a.PrimaryPart and a.PrimaryPart.Position) or Vector3.zero
            local pb = b:IsA("BasePart") and b.Position or (b.PrimaryPart and b.PrimaryPart.Position) or Vector3.zero
            return (pa - Root.Position).Magnitude < (pb - Root.Position).Magnitude
        end)

        local target = eggs[1]
        TeleportTo(target)
        task.wait(0.05)
        local ok = TrySteal(target)
        if not ok then TryRemoteSteal(target) end
        Status.Text = "លួច: " .. target.Name .. " (" .. #eggs .. ")"
    end
end)

-- // AUTO HATCH
task.spawn(function()
    while task.wait(1) do
        if not CONFIG.AutoHatch then continue end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local n = string.lower(obj.Parent.Name .. " " .. obj.ActionText)
                if string.find(n, "hatch") or string.find(n, "open") then
                    pcall(function() fireproximityprompt(obj) end)
                end
            end
        end
    end
end)

-- // ANTI-AFK
LocalPlayer.Idled:Connect(function()
    local VU = game:GetService("VirtualUser")
    VU:CaptureController()
    VU:ClickButton2(Vector2.new())
end)

Status.Text = "ដំណើរការ ✓"
