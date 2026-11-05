local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local ok, err = pcall(function()
    local LocalPlayer = Players.LocalPlayer
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    local old = playerGui:FindFirstChild("InspectorGui")
    if old then old:Destroy() end
    local oldHL = playerGui:FindFirstChild("InspectorHL")
    if oldHL then oldHL:Destroy() end
    for _, d in ipairs(playerGui:GetDescendants()) do
        if d.Name == "InspectorHighlight" then d:Destroy() end
    end

    local connections = {}
    local function track(c) table.insert(connections, c) return c end
    local hl, hlGui, ov -- diisi di bagian preview di bawah

    local gui = Instance.new("ScreenGui")
    gui.Name = "InspectorGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    local FULL = UDim2.new(0, 300, 0, 280)
    local MINI = UDim2.new(0, 190, 0, 28)

    local panel = Instance.new("Frame")
    panel.Size = FULL
    panel.Position = UDim2.new(1, -310, 0, 60)
    panel.BackgroundColor3 = Color3.new(0, 0, 0)
    panel.BackgroundTransparency = 0.25
    panel.ClipsDescendants = true
    panel.Active = true
    panel.Parent = gui

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    header.BorderSizePixel = 0
    header.Active = true
    header.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -120, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "GUI Inspector"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.Code
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Active = true
    title.Parent = header

    local function headerBtn(text, xOff, w, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, w, 0, 28)
        b.Position = UDim2.new(1, xOff, 0, 0)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.Code
        b.TextSize = 14
        b.Parent = header
        return b
    end

    local copyBtn = headerBtn("Salin", -112, 56, Color3.fromRGB(50, 100, 170))
    local minBtn = headerBtn("-", -56, 28, Color3.fromRGB(60, 60, 60))
    local closeBtn = headerBtn("X", -28, 28, Color3.fromRGB(170, 50, 50))

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 1, -28)
    body.Position = UDim2.new(0, 0, 0, 28)
    body.BackgroundTransparency = 1
    body.Active = true
    body.Parent = panel

    local function bodyBtn(text, i)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.25, -3, 0, 28)
        b.Position = UDim2.new(0.25 * i, 2, 0, 4)
        b.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.Code
        b.TextScaled = true
        b.Text = text
        b.Parent = body
        return b
    end

    local toggleBtn = bodyBtn("Inspect: ON", 0)
    local prevBtn = bodyBtn("Prev", 1)
    local nextBtn = bodyBtn("Next", 2)
    local previewBtn = bodyBtn("Preview: OFF", 3)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Position = UDim2.new(0, 4, 0, 36)
    scroll.Size = UDim2.new(1, -8, 1, -40)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new()
    scroll.Active = true
    scroll.Parent = body

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Text = "Tap GUI mana saja untuk melihat infonya."
    label.Active = true
    label.Parent = scroll

    -- Cek apakah tap berada di area panel
    -- panel ada di ScreenGui IgnoreGuiInset (titik nol di atas layar),
    -- sedangkan input.Position titik nolnya di bawah topbar
    local function insidePanel(pos)
        local inset = GuiService:GetGuiInset()
        local x, y = pos.X + inset.X, pos.Y + inset.Y
        local p, s = panel.AbsolutePosition, panel.AbsoluteSize
        return x >= p.X - 4 and x <= p.X + s.X + 4
            and y >= p.Y - 4 and y <= p.Y + s.Y + 4
    end

    -- Minimize
    local minimized = false
    track(minBtn.Activated:Connect(function()
        minimized = not minimized
        body.Visible = not minimized
        panel.Size = minimized and MINI or FULL
        minBtn.Text = minimized and "+" or "-"
    end))

    -- Close
    track(closeBtn.Activated:Connect(function()
        for _, c in ipairs(connections) do c:Disconnect() end
        table.clear(connections)
        if hl then pcall(function() hl:Destroy() end) end
        if hlGui then hlGui:Destroy() end
        gui:Destroy()
    end))

    -- Drag lewat judul
    local dragging, dragStart, startPos
    track(title.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))

    local function describe(obj, idx, total)
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
                dcount += 1
            end
        end
        add("Descendants", dcount)
        return table.concat(lines, "\n")
    end

    local enabled = true
    local stack, index, lastInfo = {}, 1, ""
    local previewOn = false

    -- Kotak penanda preview.
    -- Dipasang sebagai ANAK dari objek yang dipilih, jadi posisinya selalu pas
    -- dan ikut bergerak (tidak tergantung inset topbar atau skala layar).
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

    -- Cadangan untuk objek yang punya UIListLayout/UIGridLayout
    -- (anak baru akan ikut ditata layout, jadi tidak bisa dipasang di dalamnya)
    hlGui = Instance.new("ScreenGui")
    hlGui.Name = "InspectorHL"
    hlGui.ResetOnSpawn = false
    hlGui.DisplayOrder = 1000
    hlGui.IgnoreGuiInset = true
    hlGui.Parent = playerGui

    ov = makeHL()
    ov.Visible = false
    ov.Parent = hlGui

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
        -- objek game bisa saja dihapus game (ikut menghapus kotak), jadi buat baru tiap kali
        if hl then pcall(function() hl:Destroy() end) hl = nil end
        ov.Visible = false

        local obj = stack[index]
        if not previewOn or not obj or not obj:IsA("GuiObject") then return end

        if not hasLayout(obj) then
            hl = makeHL()
            hl.Size = UDim2.new(1, 0, 1, 0)
            hl.Parent = obj
        else
            local sg = obj:FindFirstAncestorWhichIsA("ScreenGui")
            local off = (sg and not sg.IgnoreGuiInset) and topInset() or 0
            local p, s = obj.AbsolutePosition, obj.AbsoluteSize
            ov.Position = UDim2.fromOffset(p.X, p.Y + off)
            ov.Size = UDim2.fromOffset(s.X, s.Y)
            ov.Visible = true
        end
    end

    local function show()
        local obj = stack[index]
        if not obj then return end
        lastInfo = describe(obj, index, #stack)
        label.Text = lastInfo
        scroll.CanvasPosition = Vector2.new(0, 0)
        updatePreview()
        print("========== GUI INFO ==========\n" .. lastInfo)
    end

    -- Salin
    track(copyBtn.Activated:Connect(function()
        local clip = setclipboard or toclipboard
        if lastInfo == "" then
            copyBtn.Text = "Kosong"
        elseif clip then
            copyBtn.Text = pcall(clip, lastInfo) and "OK!" or "Gagal"
        else
            copyBtn.Text = "N/A"
        end
        task.delay(1.2, function()
            if copyBtn.Parent then copyBtn.Text = "Salin" end
        end)
    end))

    track(toggleBtn.Activated:Connect(function()
        enabled = not enabled
        toggleBtn.Text = enabled and "Inspect: ON" or "Inspect: OFF"
    end))

    track(nextBtn.Activated:Connect(function()
        if #stack == 0 then return end
        index = index % #stack + 1
        show()
    end))

    track(prevBtn.Activated:Connect(function()
        if #stack == 0 then return end
        index = (index - 2) % #stack + 1
        show()
    end))

    track(previewBtn.Activated:Connect(function()
        previewOn = not previewOn
        previewBtn.Text = previewOn and "Preview: ON" or "Preview: OFF"
        updatePreview()
    end))

    -- Deteksi tap pada GUI
    track(UserInputService.InputBegan:Connect(function(input)
        if not enabled then return end
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end

        if insidePanel(input.Position) then return end

        -- input.Position sudah satu ruang dengan GetGuiObjectsAtPosition
        local hits = playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)

        local filtered = {}
        for _, o in ipairs(hits) do
            if not o:IsDescendantOf(gui) and o.Name ~= "InspectorHighlight" then
                table.insert(filtered, o)
            end
        end

        if #filtered == 0 then
            label.Text = "Tidak ada GUI di titik tap ("
                .. math.floor(input.Position.X) .. ", " .. math.floor(input.Position.Y) .. ")"
            return
        end

        stack, index = filtered, 1
        show()
    end))
end)

if not ok then
    warn("[Inspector] Error: " .. tostring(err))
end
