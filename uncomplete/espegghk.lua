local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer

local function getParent()
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	if pcall(function() return CoreGui.Name end) then return CoreGui end
	return lp:WaitForChild("PlayerGui")
end

local parent = getParent()
local old = parent:FindFirstChild("EggESP")
if old then old:Destroy() end

-- ===== nama hewan dari PetConfig =====
local names = {}
local function scanTable(t, depth, seen)
	if depth > 4 or seen[t] then return end
	seen[t] = true
	for k, v in pairs(t) do
		if type(v) == "table" then
			if type(k) == "string" then
				local n = v.DisplayName or v.displayName or v.Name or v.name
				if type(n) == "string" and n ~= "" then names[k] = n end
			end
			scanTable(v, depth + 1, seen)
		end
	end
end

task.spawn(function()
	local shared = RS:FindFirstChild("Shared")
	local cfg = shared and shared:FindFirstChild("PetConfig")
	if cfg and cfg:IsA("ModuleScript") then
		local ok, res = pcall(require, cfg)
		if ok and type(res) == "table" then scanTable(res, 0, {}) end
	end
end)

-- ===== setting =====
local S = {esp = false, name = true, rarity = true, income = true, weight = true, size = true, hl = true}
local RED, GREEN = Color3.fromRGB(170, 40, 40), Color3.fromRGB(40, 150, 60)
local DARK = Color3.fromRGB(25, 25, 25)

-- pengaturan tag di dalam telur
local TAG_W, TAG_H = 0.9, 0.6   -- lebar & tinggi tag relatif ke ukuran Shell
local TAG_OFFSET = Vector3.new(0, 0, 0)
local MAX_DIST = 150

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "EggESP"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = parent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(170, 30)
main.Position = UDim2.new(0, 10, 0.3, 0)
main.BackgroundColor3 = DARK
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 6)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -34, 0, 30)
title.Position = UDim2.fromOffset(8, 0)
title.BackgroundTransparency = 1
title.Text = "Egg ESP"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(26, 22)
minBtn.Position = UDim2.new(1, -30, 0, 4)
minBtn.Text = "-"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
minBtn.Parent = main
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 4)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -30)
body.Position = UDim2.fromOffset(0, 30)
body.BackgroundTransparency = 1
body.Parent = main

local function mkRow(label, key, y)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -12, 0, 26)
	b.Position = UDim2.fromOffset(6, y)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = body
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
	local function paint()
		b.Text = label .. ": " .. (S[key] and "ON" or "OFF")
		b.BackgroundColor3 = S[key] and GREEN or RED
	end
	paint()
	b.MouseButton1Click:Connect(function()
		S[key] = not S[key]
		paint()
	end)
end

local items = {
	{"ESP", "esp"}, {"Nama", "name"}, {"Rarity", "rarity"}, {"Income", "income"},
	{"Berat", "weight"}, {"Ukuran", "size"}, {"Highlight", "hl"},
}
for i, it in ipairs(items) do
	mkRow(it[1], it[2], 4 + (i - 1) * 30)
end
local FULL_H = 30 + 4 + #items * 30 + 4

local minimized = false
local function layout()
	main.Size = UDim2.fromOffset(170, minimized and 30 or FULL_H)
	body.Visible = not minimized
	minBtn.Text = minimized and "+" or "-"
end
layout()
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	layout()
end)

-- ===== data telur =====
local function getZones()
	local m = workspace:FindFirstChild("Map")
	local g = m and m:FindFirstChild("GamePlay")
	return g and g:FindFirstChild("Zones")
end

local function getPetId(egg)
	for k, v in pairs(egg:GetAttributes()) do
		if tostring(k):lower():find("petid") then return tostring(v) end
	end
	return nil
end

local BASE_SIZE = 2.1926
local function getSize(egg, shell)
	for _, k in ipairs({"Size", "Scale", "SizeMultiplier", "SizeMult"}) do
		local v = egg:GetAttribute(k)
		if type(v) == "number" then return v end
	end
	return shell.Size.Y / BASE_SIZE
end

local tags = {}

local function add(egg)
	local shell = egg:FindFirstChild("Shell")
	if not shell or tags[egg] then return end

	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.6
	hl.Adornee = egg
	hl.Parent = egg

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(shell.Size.X * TAG_W, shell.Size.Y * TAG_H)
	bb.StudsOffset = TAG_OFFSET
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = MAX_DIST
	bb.Adornee = shell
	bb.Parent = shell

	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextStrokeTransparency = 0
	t.Parent = bb

	tags[egg] = {hl = hl, bb = bb, label = t}
end

local function remove(egg)
	local tag = tags[egg]
	if not tag then return end
	pcall(function() tag.hl:Destroy() end)
	pcall(function() tag.bb:Destroy() end)
	tags[egg] = nil
end

local function update(egg, tag)
	local shell = egg:FindFirstChild("Shell")
	if not shell then return end
	tag.bb.Size = UDim2.fromScale(shell.Size.X * TAG_W, shell.Size.Y * TAG_H)

	local info = shell:FindFirstChild("EggInfo")
	local r = info and info:FindFirstChild("Rarity")
	local i = info and info:FindFirstChild("Income")

	local l1, l2 = {}, {}
	if S.name then
		local id = getPetId(egg)
		l1[#l1 + 1] = id and (names[id] or id) or "?"
	end
	if S.rarity and r then l1[#l1 + 1] = r.Text end
	if S.income and i then l2[#l2 + 1] = i.Text end
	if S.weight then
		local w = egg:GetAttribute("WeightKg")
		if w then l2[#l2 + 1] = w .. "kg" end
	end
	if S.size then
		l2[#l2 + 1] = string.format("%.1fx", getSize(egg, shell))
	end

	local text = table.concat(l1, " | ")
	if #l2 > 0 then
		text = text .. (text ~= "" and "\n" or "") .. table.concat(l2, " | ")
	end
	tag.label.Text = text
	tag.bb.Enabled = text ~= ""

	local col = r and r.TextColor3 or Color3.new(1, 1, 1)
	tag.label.TextColor3 = col
	tag.hl.FillColor = col
	tag.hl.Enabled = S.hl
end

local tick = 0
task.spawn(function()
	while gui.Parent do
		if S.esp then
			pcall(function()
				if tick % 4 == 0 then
					local zones = getZones()
					if zones then
						for _, d in ipairs(zones:GetDescendants()) do
							if d.Name == "Egg" and d:IsA("Model") then add(d) end
						end
					end
				end
				for egg, tag in pairs(tags) do
					if egg.Parent then update(egg, tag) else remove(egg) end
				end
			end)
		elseif next(tags) then
			for egg in pairs(tags) do remove(egg) end
		end
		tick += 1
		task.wait(0.5)
	end
end)
