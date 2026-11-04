local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
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
local old = parent:FindFirstChild("IndexViewer")
if old then old:Destroy() end

-- ===== semua hewan dari PetConfig =====
local names, rar, nameToIds = {}, {}, {}
local function scanTable(t, depth, seen)
	if depth > 4 or seen[t] then return end
	seen[t] = true
	for k, v in pairs(t) do
		if type(v) == "table" then
			if type(k) == "string" then
				local n = v.DisplayName or v.displayName or v.Name or v.name
				if type(n) == "string" and n ~= "" then
					names[k] = n
					if type(v.Rarity) == "string" then rar[k] = v.Rarity end
					local l = n:lower()
					nameToIds[l] = nameToIds[l] or {}
					table.insert(nameToIds[l], k)
				end
			end
			scanTable(v, depth + 1, seen)
		end
	end
end

local function loadConfig()
	names, rar, nameToIds = {}, {}, {}
	local shared = RS:FindFirstChild("Shared")
	local cfg = shared and shared:FindFirstChild("PetConfig")
	if cfg and cfg:IsA("ModuleScript") then
		local ok, res = pcall(require, cfg)
		if ok and type(res) == "table" then scanTable(res, 0, {}) end
	end
end

-- ===== deteksi hewan yang dimiliki =====
local owned = {}   -- id -> sumber
local srcCount = {}

local function mark(token, src)
	if type(token) ~= "string" or token == "" then return end
	local id
	if names[token] then
		id = token
	else
		local clean = token:gsub("^%b[]%s*", ""):gsub("%s*%b[]$", ""):lower()
		local ids = nameToIds[clean]
		if ids then
			for _, i in ipairs(ids) do
				if not owned[i] then owned[i] = src; srcCount[src] = (srcCount[src] or 0) + 1 end
			end
			return
		end
	end
	if id and not owned[id] then
		owned[id] = src
		srcCount[src] = (srcCount[src] or 0) + 1
	end
end

local function walkJson(v, src, depth)
	if depth > 6 then return end
	if type(v) == "table" then
		for k, x in pairs(v) do
			mark(k, src)
			walkJson(x, src, depth + 1)
		end
	else
		mark(v, src)
	end
end

local function markInst(d, src)
	mark(d.Name, src)
	for k, v in pairs(d:GetAttributes()) do
		mark(k, src)
		if type(v) == "string" then
			mark(v, src)
			local c = v:sub(1, 1)
			if c == "{" or c == "[" then
				local ok, res = pcall(HttpService.JSONDecode, HttpService, v)
				if ok then walkJson(res, src, 0) end
			end
		end
	end
	if d:IsA("StringValue") then
		mark(d.Value, src)
		local c = d.Value:sub(1, 1)
		if c == "{" or c == "[" then
			local ok, res = pcall(HttpService.JSONDecode, HttpService, d.Value)
			if ok then walkJson(res, src, 0) end
		end
	end
end

local function detect()
	owned, srcCount = {}, {}
	-- Backpack & tangan
	for _, c in ipairs({lp:FindFirstChild("Backpack"), lp.Character}) do
		if c then
			for _, t in ipairs(c:GetChildren()) do
				if t:IsA("Tool") then markInst(t, "Backpack") end
			end
		end
	end
	-- Player (data & folder)
	markInst(lp, "Player")
	for _, c in ipairs(lp:GetChildren()) do
		if c.Name ~= "PlayerGui" and c.Name ~= "PlayerScripts" and c.Name ~= "Backpack" then
			markInst(c, "Player")
			for _, d in ipairs(c:GetDescendants()) do markInst(d, "Player") end
		end
	end
	-- ReplicatedStorage (folder pemain)
	for _, d in ipairs(RS:GetDescendants()) do
		if d.Name == lp.Name or d.Name == tostring(lp.UserId) then
			markInst(d, "RS")
			for _, c in ipairs(d:GetDescendants()) do markInst(c, "RS") end
		end
	end
	-- UI Index: nama yang tampil (yang terkunci biasanya "???")
	for _, g in ipairs(lp.PlayerGui:GetDescendants()) do
		if g:IsA("TextLabel") and g.Text ~= "" then
			local path = g:GetFullName():lower()
			if path:find("index") or path:find("collection") or path:find("book") then
				mark(g.Text, "UI")
			end
		end
	end
end

-- ===== UI =====
local GREEN, RED = Color3.fromRGB(40, 150, 60), Color3.fromRGB(170, 40, 40)
local BLUE, GRAY, DARK = Color3.fromRGB(40, 110, 170), Color3.fromRGB(60, 60, 60), Color3.fromRGB(25, 25, 25)
local W, H = 250, 330

local gui = Instance.new("ScreenGui")
gui.Name = "IndexViewer"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = parent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(W, H)
main.Position = UDim2.new(0, 10, 0.2, 0)
main.BackgroundColor3 = DARK
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 6)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -66, 0, 30)
title.Position = UDim2.fromOffset(8, 0)
title.BackgroundTransparency = 1
title.Text = "Index Viewer"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local function btn(parent_, text, x, y, w, h, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, h)
	b.Position = UDim2.new(0, x, 0, y)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.Parent = parent_
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
	return b
end

local minBtn = btn(main, "-", W - 58, 4, 26, 22, GRAY)
local closeBtn = btn(main, "X", W - 30, 4, 26, 22, RED)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -30)
body.Position = UDim2.fromOffset(0, 30)
body.BackgroundTransparency = 1
body.Parent = main

local tabHave = btn(body, "PUNYA", 6, 0, 76, 26, GREEN)
local tabMiss = btn(body, "BELUM", 86, 0, 76, 26, GRAY)
local refBtn = btn(body, "REFRESH", 166, 0, 78, 26, BLUE)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, -12, 0, 30)
info.Position = UDim2.fromOffset(6, 30)
info.BackgroundTransparency = 1
info.Font = Enum.Font.Gotham
info.TextSize = 11
info.TextColor3 = Color3.fromRGB(200, 200, 200)
info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Text = ""
info.Parent = body

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -12, 1, -94)
scroll.Position = UDim2.fromOffset(6, 62)
scroll.BackgroundColor3 = Color3.new(0, 0, 0)
scroll.BackgroundTransparency = 0.3
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = body

local list = Instance.new("TextLabel")
list.Size = UDim2.new(1, -8, 0, 0)
list.Position = UDim2.fromOffset(4, 2)
list.AutomaticSize = Enum.AutomaticSize.Y
list.BackgroundTransparency = 1
list.Font = Enum.Font.Code
list.TextSize = 11
list.TextColor3 = Color3.new(1, 1, 1)
list.TextWrapped = true
list.TextXAlignment = Enum.TextXAlignment.Left
list.TextYAlignment = Enum.TextYAlignment.Top
list.Text = ""
list.Parent = scroll

local copyBtn = btn(body, "SALIN", 6, H - 30 - 30, W - 12, 26, BLUE)

-- ===== tampilan =====
local tab = "have"
local function build()
	local have, miss = {}, {}
	for id, n in pairs(names) do
		local line = n .. (rar[id] and (" [" .. rar[id] .. "]") or "")
		if owned[id] then
			have[#have + 1] = line
		else
			miss[#miss + 1] = line
		end
	end
	table.sort(have)
	table.sort(miss)
	return have, miss
end

local function render()
	local have, miss = build()
	local total = #have + #miss
	local src = {}
	for k, v in pairs(srcCount) do src[#src + 1] = k .. ":" .. v end
	info.Text = string.format("Punya %d / %d | Belum %d\nSumber: %s",
		#have, total, #miss, #src > 0 and table.concat(src, ", ") or "tidak ada")
	tabHave.BackgroundColor3 = tab == "have" and GREEN or GRAY
	tabMiss.BackgroundColor3 = tab == "miss" and GREEN or GRAY
	local lst = tab == "have" and have or miss
	list.Text = #lst > 0 and table.concat(lst, "\n") or "(kosong)"
end

local function reload()
	loadConfig()
	detect()
	render()
end

tabHave.MouseButton1Click:Connect(function() tab = "have"; render() end)
tabMiss.MouseButton1Click:Connect(function() tab = "miss"; render() end)
refBtn.MouseButton1Click:Connect(function()
	refBtn.Text = "..."
	task.spawn(function()
		pcall(reload)
		refBtn.Text = "REFRESH"
	end)
end)

copyBtn.MouseButton1Click:Connect(function()
	local have, miss = build()
	local text = "PUNYA (" .. #have .. "):\n" .. table.concat(have, "\n") ..
		"\n\nBELUM (" .. #miss .. "):\n" .. table.concat(miss, "\n")
	local ok = false
	if setclipboard then ok = pcall(setclipboard, text)
	elseif toclipboard then ok = pcall(toclipboard, text) end
	if not ok then print(text) end
	copyBtn.Text = ok and "TERSALIN!" or "DICETAK KE F9"
	task.delay(1.5, function() copyBtn.Text = "SALIN" end)
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	main.Size = UDim2.fromOffset(W, minimized and 30 or H)
	body.Visible = not minimized
	minBtn.Text = minimized and "+" or "-"
end)

closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

pcall(reload)
