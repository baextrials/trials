print("[ESP] script dimulai")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

if RunService:IsServer() then
	warn("[ESP] Gunakan LocalScript, bukan Script")
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

for _, name in ipairs({"AimAssistGui", "AimLockGui", "ESPGui"}) do
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
end

-- ===== Konfigurasi ESP (semua otomatis tampil) =====
local espEnabled = true
local espName    = true
local espHealth  = true
local espBox     = true
local espLine    = true
local espColor   = Color3.fromRGB(255, 70, 70)

local autoTargets = {}
local espRegistry = {}

local function isValidNPC(model)
	if not model or not model.Parent or not model:IsDescendantOf(Workspace) then return false end
	if Players:GetPlayerFromCharacter(model) then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

-- ESP tetap tampil selama model NPC masih ada di Workspace (walau sudah mati)
local function isTracked(model)
	if not model or not model.Parent or not model:IsDescendantOf(Workspace) then return false end
	if Players:GetPlayerFromCharacter(model) then return false end
	return model:FindFirstChildOfClass("Humanoid") ~= nil
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

-- ===== Helper ESP =====
local function destroyESP(model)
	local data = espRegistry[model]
	if not data then return end
	if data.highlight then data.highlight:Destroy() end
	if data.billboard then data.billboard:Destroy() end
	if data.tracer then data.tracer:Destroy() end
	espRegistry[model] = nil
end

local function clearAllESP()
	for model in pairs(espRegistry) do
		destroyESP(model)
	end
end

-- ===== GUI Setup =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local MAIN_H_OPEN   = 330
local MAIN_H_CLOSED = 36

local container = Instance.new("Frame")
container.Position = UDim2.new(0, 12, 0, 60)
container.Size = UDim2.new(0, 300, 0, MAIN_H_OPEN)
container.BackgroundTransparency = 1
container.Parent = screenGui

local vLayout = Instance.new("UIListLayout")
vLayout.Padding = UDim.new(0, 8)
vLayout.SortOrder = Enum.SortOrder.LayoutOrder
vLayout.Parent = container

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
title.Text = "ESP"
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

local dragging, dragStart, startPos
local minimized = false

titleBar.InputBegan:Connect(function(input)
	if minimized then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = container.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

local dragConn = UserInputService.InputChanged:Connect(function(input)
	if dragging and not minimized and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
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

local function makeToggle(label, initial, parent, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -8, 0, 34)
	btn.LayoutOrder = nextOrder()
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.BorderSizePixel = 0
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	local function updateBtn(on)
		btn.Text = label .. ": " .. (on and "ON" or "OFF")
		btn.BackgroundColor3 = on and Color3.fromRGB(60, 140, 80) or Color3.fromRGB(70, 70, 80)
	end
	updateBtn(initial)

	btn.MouseButton1Click:Connect(function()
		initial = not initial
		updateBtn(initial)
		if callback then callback(initial) end
	end)
	return btn
end

local function makeRow(label, default, parent)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 30)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder()
	row.Parent = parent

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

-- ===== ESP MENU =====
local sep = Instance.new("Frame")
sep.Size = UDim2.new(1, -8, 0, 2)
sep.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
sep.BorderSizePixel = 0
sep.LayoutOrder = nextOrder()
sep.Parent = content

makeToggle("ESP", espEnabled, content, function(val)
	espEnabled = val
	if not val then clearAllESP() end
end)

makeToggle("Name", espName, content, function(val) espName = val end)
makeToggle("Health Bar", espHealth, content, function(val) espHealth = val end)
makeToggle("Box", espBox, content, function(val) espBox = val end)
makeToggle("Line (Tracer)", espLine, content, function(val) espLine = val end)

-- Warna ESP
local colorRow = Instance.new("Frame")
colorRow.Size = UDim2.new(1, -8, 0, 30)
colorRow.BackgroundTransparency = 1
colorRow.LayoutOrder = nextOrder()
colorRow.Parent = content

local cLabel = Instance.new("TextLabel")
cLabel.Size = UDim2.new(0.4, 0, 1, 0)
cLabel.BackgroundTransparency = 1
cLabel.Text = "Warna ESP"
cLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
cLabel.Font = Enum.Font.Gotham
cLabel.TextSize = 14
cLabel.TextXAlignment = Enum.TextXAlignment.Left
cLabel.Parent = colorRow

local colorLayout = Instance.new("UIListLayout")
colorLayout.FillDirection = Enum.FillDirection.Horizontal
colorLayout.VerticalAlignment = Enum.VerticalAlignment.Center
colorLayout.Padding = UDim.new(0, 4)
colorLayout.SortOrder = Enum.SortOrder.LayoutOrder
colorLayout.Parent = colorRow

local colors = {
	{Color3.fromRGB(255, 70, 70), "Merah"},
	{Color3.fromRGB(70, 255, 70), "Hijau"},
	{Color3.fromRGB(70, 150, 255), "Biru"},
	{Color3.fromRGB(255, 255, 70), "Kuning"},
	{Color3.fromRGB(70, 255, 255), "Cyan"},
	{Color3.fromRGB(255, 70, 255), "Ungu"}
}

for i, cData in ipairs(colors) do
	local cBtn = Instance.new("TextButton")
	cBtn.Size = UDim2.new(0, 30, 0, 24)
	cBtn.BackgroundColor3 = cData[1]
	cBtn.Text = ""
	cBtn.BorderSizePixel = 2
	cBtn.BorderColor3 = (i == 1) and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
	cBtn.LayoutOrder = i
	cBtn.Parent = colorRow
	Instance.new("UICorner", cBtn).CornerRadius = UDim.new(0, 4)

	cBtn.MouseButton1Click:Connect(function()
		espColor = cData[1]
		for _, child in ipairs(colorRow:GetChildren()) do
			if child:IsA("TextButton") then
				child.BorderColor3 = Color3.new(0, 0, 0)
			end
		end
		cBtn.BorderColor3 = Color3.new(1, 1, 1)
	end)
end

-- ===== ESP RENDER LOOP =====
local renderConn = RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	if not cam then return end

	-- ESP (semua NPC otomatis)
	if espEnabled then
		local activeTargets = {}

		-- buang model yang sudah benar-benar hilang dari Workspace
		for model in pairs(autoTargets) do
			if not model.Parent or not model:IsDescendantOf(Workspace) then
				autoTargets[model] = nil
			end
		end

		for model in pairs(autoTargets) do
			if isTracked(model) then
				activeTargets[model] = true

				-- Kalau bagian NPC diganti (Head baru, Highlight terhapus, dll), ESP lama dibuang & dibuat ulang
				local existing = espRegistry[model]
				if existing then
					local curPart = getAimPart(model)
					local broken = (not existing.highlight)
						or existing.highlight.Parent ~= model
						or existing.part ~= curPart
						or (existing.billboard ~= nil and (existing.billboard.Parent == nil or existing.billboard.Adornee == nil))
						or (existing.tracer ~= nil and existing.tracer.Parent == nil)
					if broken then destroyESP(model) end
				end

				if not espRegistry[model] then
					local hl = Instance.new("Highlight")
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Parent = model

					local head = getAimPart(model)
					local bb, healthBar, nameLabel

					if head then
						bb = Instance.new("BillboardGui")
						bb.Size = UDim2.new(0, 100, 0, 40)
						bb.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
						bb.AlwaysOnTop = true
						bb.Adornee = head
						bb.Parent = head

						nameLabel = Instance.new("TextLabel")
						nameLabel.Size = UDim2.new(1, 0, 0, 20)
						nameLabel.BackgroundTransparency = 1
						nameLabel.Text = model.Name
						nameLabel.TextStrokeTransparency = 0.5
						nameLabel.Font = Enum.Font.GothamBold
						nameLabel.TextSize = 14
						nameLabel.Parent = bb

						healthBar = Instance.new("Frame")
						healthBar.Size = UDim2.new(1, 0, 0, 6)
						healthBar.Position = UDim2.new(0, 0, 0, 22)
						healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
						healthBar.BorderSizePixel = 0
						healthBar.Parent = bb
					end

					local tracer = Instance.new("Frame")
					tracer.BackgroundColor3 = espColor
					tracer.BorderSizePixel = 0
					tracer.AnchorPoint = Vector2.new(0.5, 0)
					tracer.Visible = false
					tracer.Parent = screenGui

					espRegistry[model] = {
						highlight = hl,
						billboard = bb,
						healthBar = healthBar,
						nameLabel = nameLabel,
						tracer = tracer,
						part = head,
					}
				end

				local data = espRegistry[model]
				local hl = data.highlight

				local hum = model:FindFirstChildOfClass("Humanoid")
				local alive = hum ~= nil and hum.Health > 0
				local col = alive and espColor or Color3.fromRGB(150, 150, 150)

				hl.FillColor = col
				hl.OutlineColor = col
				hl.FillTransparency = alive and 0.5 or 0.8
				hl.Enabled = espBox

				if data.billboard then
					data.billboard.Enabled = (espName or espHealth)
					if data.nameLabel then
						data.nameLabel.Visible = espName
						data.nameLabel.TextColor3 = col
						data.nameLabel.Text = alive and model.Name or (model.Name .. " (mati)")
					end
					if data.healthBar then
						data.healthBar.Visible = espHealth
						if hum and hum.MaxHealth > 0 then
							local r = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
							data.healthBar.Size = UDim2.new(r, 0, 0, 6)
							data.healthBar.BackgroundColor3 = r < 0.3 and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
						end
					end
				end

				-- Tracer (garis dari bawah tengah layar ke target)
				local tracer = data.tracer
				local part = getAimPart(model)
				if espLine and part then
					local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
					if onScreen then
						local bottomCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
						local targetPos = Vector2.new(screenPos.X, screenPos.Y)
						local diff = targetPos - bottomCenter
						local dist = diff.Magnitude
						local angle = math.deg(math.atan2(diff.Y, diff.X)) - 90

						tracer.Visible = true
						tracer.BackgroundColor3 = col
						-- Rotation di Roblox berputar di tengah frame, jadi taruh frame di titik tengah garis
						tracer.AnchorPoint = Vector2.new(0.5, 0.5)
						tracer.Size = UDim2.new(0, 2, 0, dist)
						tracer.Position = UDim2.new(0, (bottomCenter.X + targetPos.X) / 2, 0, (bottomCenter.Y + targetPos.Y) / 2)
						tracer.Rotation = angle
					else
						tracer.Visible = false
					end
				else
					tracer.Visible = false
				end
			end
		end

		-- Bersihkan ESP untuk NPC yang mati / hilang
		for obj in pairs(espRegistry) do
			if not activeTargets[obj] then
				destroyESP(obj)
			end
		end
	end
end)

-- ===== Minimize / Close / Hide =====
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized

	if minimized then
		dragging = false
		content.Visible = false

		container.Size = UDim2.new(0, 140, 0, MAIN_H_CLOSED)
		main.Size = UDim2.new(1, 0, 1, 0)

		title.Size = UDim2.new(1, -40, 1, 0)
		minBtn.Text = "+"
		closeBtn.Visible = false
	else
		content.Visible = true

		container.Size = UDim2.new(0, 300, 0, MAIN_H_OPEN)
		main.Size = UDim2.new(1, 0, 0, MAIN_H_OPEN)

		title.Size = UDim2.new(1, -90, 1, 0)
		minBtn.Text = "-"
		closeBtn.Visible = true
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	clearAllESP()
	if dragConn then dragConn:Disconnect() end
	if renderConn then renderConn:Disconnect() end
	screenGui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		container.Visible = not container.Visible
	end
end)

-- Scan ulang berkala: jaga-jaga ada NPC (respawn / model baru) yang terlewat oleh DescendantAdded
task.spawn(function()
	while screenGui.Parent do
		task.wait(2)
		for _, d in ipairs(Workspace:GetDescendants()) do
			registerAuto(d)
		end
	end
end)
