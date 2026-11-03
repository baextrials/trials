print("[AimLock] script dimulai")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

if RunService:IsServer() then
	warn("[AimLock] Gunakan LocalScript, bukan Script")
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

for _, name in ipairs({"AimAssistGui", "AimLockGui"}) do
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
end

-- ===== Konfigurasi =====
local aimEnabled = false
local range      = 200
local fovDegrees = 90
local smoothness = 0.15
local autoDetect = true

-- ===== Cache target =====
local autoTargets = {}

local function isValidNPC(model)
	if not model or not model.Parent or not model:IsDescendantOf(Workspace) then return false end
	if Players:GetPlayerFromCharacter(model) then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function registerAuto(inst)
	if inst:IsA("Humanoid") then
		local model = inst.Parent
		if model and model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
			autoTargets[model] = true
		end
	end
end
for _, d in ipairs(Workspace:GetDescendants()) do registerAuto(d) end
Workspace.DescendantAdded:Connect(registerAuto)

local function getAimPart(obj)
	return obj:FindFirstChild("Head")
		or obj.PrimaryPart
		or obj:FindFirstChild("HumanoidRootPart")
		or obj:FindFirstChildWhichIsA("BasePart", true)
end

local function pickBest(cam)
	if not autoDetect then return nil, nil end
	local camPos, look = cam.CFrame.Position, cam.CFrame.LookVector
	local bestPos, bestScore, bestModel = nil, math.huge, nil

	for model in pairs(autoTargets) do
		if isValidNPC(model) then
			local part = getAimPart(model)
			if part then
				local delta = part.Position - camPos
				local dist = delta.Magnitude
				if dist > 0 and dist <= range then
					local angle = math.deg(math.acos(math.clamp(look:Dot(delta.Unit), -1, 1)))
					if angle <= fovDegrees / 2 then
						local score = dist + angle * 0.5
						if score < bestScore then
							bestScore, bestPos, bestModel = score, part.Position, model
						end
					end
				end
			end
		end
	end
	return bestPos, bestModel
end

-- ===== GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimLockGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local MAIN_H_OPEN = 250
local MINI_SIZE   = 40
local LOCK_H      = 44
local GAP         = 8

local container = Instance.new("Frame")
container.Position = UDim2.new(0, 12, 0, 60)
container.Size = UDim2.new(0, 300, 0, MAIN_H_OPEN + GAP + LOCK_H)
container.BackgroundTransparency = 1
container.Parent = screenGui

local vLayout = Instance.new("UIListLayout")
vLayout.Padding = UDim.new(0, GAP)
vLayout.SortOrder = Enum.SortOrder.LayoutOrder
vLayout.Parent = container

-- Menu utama
local main = Instance.new("Frame")
main.LayoutOrder = 1
main.Size = UDim2.new(1, 0, 0, MAIN_H_OPEN)
main.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = container
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
titleBar.BorderSizePixel = 0
titleBar.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Aim Assist"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = titleBar

local function titleButton(text, x, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 32, 0, 26)
	b.Position = UDim2.new(1, x, 0, 5)
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.BorderSizePixel = 0
	b.Parent = titleBar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end
local minBtn   = titleButton("-", -74, Color3.fromRGB(80, 80, 95))
local closeBtn = titleButton("X", -38, Color3.fromRGB(180, 60, 60))

-- ===== Drag (nonaktif saat minimize) =====
local dragging, dragStart, startPos
local minimized = false

titleBar.InputBegan:Connect(function(input)
	if minimized then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = container.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

local dragConn = UserInputService.InputChanged:Connect(function(input)
	if dragging and not minimized and (input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -16, 0, MAIN_H_OPEN - 44)
content.Position = UDim2.new(0, 8, 0, 44)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local order = 0
local function nextOrder() order += 1 return order end

local function setToggle(btn, label, on)
	btn.Text = label .. ": " .. (on and "ON" or "OFF")
	btn.BackgroundColor3 = on and Color3.fromRGB(60, 140, 80) or Color3.fromRGB(70, 70, 80)
end

local function makeToggle(label, initial)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -8, 0, 34)
	btn.LayoutOrder = nextOrder()
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.BorderSizePixel = 0
	btn.Parent = content
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	setToggle(btn, label, initial)
	return btn
end

local function makeRow(label, default)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 30)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder()
	row.Parent = content

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0.55, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Text = label
	l.TextColor3 = Color3.fromRGB(200, 200, 200)
	l.Font = Enum.Font.Gotham
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = row

	local b = Instance.new("TextBox")
	b.Size = UDim2.new(0.45, 0, 1, 0)
	b.Position = UDim2.new(0.55, 0, 0, 0)
	b.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 14
	b.Text = tostring(default)
	b.ClearTextOnFocus = false
	b.Parent = row
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local rangeBox   = makeRow("Range", range)
local fovBox     = makeRow("FOV (derajat)", fovDegrees)
local smoothBox  = makeRow("Smoothness", smoothness)
local autoToggle = makeToggle("Auto-deteksi NPC", true)

-- ===== Tombol LOCK =====
local lockBtn = Instance.new("TextButton")
lockBtn.LayoutOrder = 2
lockBtn.Size = UDim2.new(1, 0, 0, LOCK_H)
lockBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
lockBtn.TextColor3 = Color3.new(1, 1, 1)
lockBtn.Font = Enum.Font.GothamBold
lockBtn.TextSize = 15
lockBtn.Text = "LOCK TARGET: OFF"
lockBtn.TextTruncate = Enum.TextTruncate.AtEnd
lockBtn.BorderSizePixel = 0
lockBtn.Parent = container
Instance.new("UICorner", lockBtn).CornerRadius = UDim.new(0, 8)

-- ===== Logika aim =====
local currentTarget = nil

local function updateLockBtn()
	if aimEnabled then
		local name = currentTarget and currentTarget.Name or "mencari..."
		lockBtn.Text = "LOCK TARGET: ON - " .. name
		lockBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	else
		lockBtn.Text = "LOCK TARGET: OFF"
		lockBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	end
end

local function startAim()
	if aimEnabled then return end
	aimEnabled = true
	RunService:BindToRenderStep("AimLockCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not aimEnabled then return end
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local bestPos, bestModel = pickBest(cam)
		currentTarget = bestModel
		if bestPos then
			local goal = CFrame.lookAt(cam.CFrame.Position, bestPos)
			local alpha = 1 - math.exp(-smoothness * dt * 60)
			cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(alpha, 0, 1))
		end
	end)
	updateLockBtn()
end

local function stopAim()
	if not aimEnabled then return end
	aimEnabled = false
	currentTarget = nil
	pcall(function() RunService:UnbindFromRenderStep("AimLockCam") end)
	updateLockBtn()
end

lockBtn.MouseButton1Click:Connect(function()
	if aimEnabled then stopAim() else startAim() end
end)

autoToggle.MouseButton1Click:Connect(function()
	autoDetect = not autoDetect
	setToggle(autoToggle, "Auto-deteksi NPC", autoDetect)
end)

rangeBox.FocusLost:Connect(function()
	local v = tonumber(rangeBox.Text)
	if v then range = math.clamp(v, 1, 2000) end
	rangeBox.Text = tostring(range)
end)
fovBox.FocusLost:Connect(function()
	local v = tonumber(fovBox.Text)
	if v then fovDegrees = math.clamp(v, 1, 180) end
	fovBox.Text = tostring(fovDegrees)
end)
smoothBox.FocusLost:Connect(function()
	local v = tonumber(smoothBox.Text)
	if v then smoothness = math.clamp(v, 0.01, 1) end
	smoothBox.Text = tostring(smoothness)
end)

-- ===== Loop maintenance =====
task.spawn(function()
	while lockBtn.Parent do
		for model in pairs(autoTargets) do
			if not isValidNPC(model) then autoTargets[model] = nil end
		end
		updateLockBtn()
		task.wait(0.5)
	end
end)

-- ===== Minimize / Close / Hide =====
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized

	if minimized then
		dragging = false
		content.Visible = false
		title.Visible = false
		closeBtn.Visible = false
		lockBtn.Visible = true

		container.Size = UDim2.new(0, 240, 0, MINI_SIZE + GAP + LOCK_H)
		main.Size = UDim2.new(0, MINI_SIZE, 0, MINI_SIZE)
		main.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

		titleBar.Size = UDim2.new(1, 0, 1, 0)
		titleBar.BackgroundTransparency = 1

		minBtn.Text = "+"
		minBtn.Position = UDim2.new(0, 4, 0, 4)
		minBtn.Size = UDim2.new(0, 32, 0, 32)
	else
		content.Visible = true
		title.Visible = true
		closeBtn.Visible = true
		lockBtn.Visible = true

		container.Size = UDim2.new(0, 300, 0, MAIN_H_OPEN + GAP + LOCK_H)
		main.Size = UDim2.new(1, 0, 0, MAIN_H_OPEN)
		main.BackgroundColor3 = Color3.fromRGB(30, 30, 35)

		titleBar.Size = UDim2.new(1, 0, 0, 36)
		titleBar.BackgroundTransparency = 0

		minBtn.Text = "-"
		minBtn.Position = UDim2.new(1, -74, 0, 5)
		minBtn.Size = UDim2.new(0, 32, 0, 26)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	stopAim()
	if dragConn then dragConn:Disconnect() end
	screenGui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		container.Visible = not container.Visible
	end
end)
