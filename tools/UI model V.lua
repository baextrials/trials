-- ========================================================
-- VENYX STYLE UI FRAMEWORK (EMPTY)
-- Dibuat untuk kerangka UI, silakan tambahkan fitur sendiri
-- ========================================================

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Variabel Warna (Bisa diubah sesuai selera)
local Colors = {
    Background = Color3.fromRGB(20, 20, 20),
    TopBar = Color3.fromRGB(25, 25, 25),
    Sidebar = Color3.fromRGB(15, 15, 15),
    TabActive = Color3.fromRGB(45, 45, 45),
    TabInactive = Color3.fromRGB(15, 15, 15),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(180, 180, 180),
    Accent = Color3.fromRGB(255, 255, 255)
}

-- Hapus GUI lama jika ada
if CoreGui:FindFirstChild("VenyxFramework") then
    CoreGui:FindFirstChild("VenyxFramework"):Destroy()
end

-- 1. ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VenyxFramework"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

-- 2. Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

-- 3. Topbar
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Colors.TopBar
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 10)
TopCorner.Parent = TopBar

-- Judul
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 200, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Venyx / Script Base"
Title.TextColor3 = Colors.Text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

-- 4. Sidebar (Kiri)
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 60, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = Colors.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Padding = UDim.new(0, 10)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
SidebarLayout.Parent = Sidebar

-- 5. Content Area (Kanan)
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -70, 1, -50)
ContentArea.Position = UDim2.new(0, 65, 0, 45)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- Tabel untuk menyimpan halaman (tab)
local Pages = {}
local ActiveButton = nil

-- Fungsi untuk membuat Tab/Page
local function CreateTab(name, iconText)
    -- Buat Tombol Sidebar
    local Btn = Instance.new("TextButton")
    Btn.Name = name .. "Btn"
    Btn.Size = UDim2.new(0, 40, 0, 40)
    Btn.BackgroundColor3 = Colors.TabInactive
    Btn.Text = iconText
    Btn.TextColor3 = Colors.TextDim
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 18
    Btn.Parent = Sidebar
    
    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 8)
    BtnCorner.Parent = Btn

    -- Buat Frame Halaman
    local Page = Instance.new("ScrollingFrame")
    Page.Name = name .. "Page"
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 2
    Page.ScrollBarImageColor3 = Colors.Accent
    Page.Visible = false
    Page.Parent = ContentArea

    local PageLayout = Instance.new("UIListLayout")
    PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PageLayout.Padding = UDim.new(0, 10)
    PageLayout.Parent = Page

    -- Simpan ke tabel
    Pages[name] = Page

    -- Fungsi Klik Tab
    Btn.MouseButton1Click:Connect(function()
        -- Reset semua tab
        for _, p in pairs(Pages) do p.Visible = false end
        for _, b in pairs(Sidebar:GetChildren()) do
            if b:IsA("TextButton") then
                b.BackgroundColor3 = Colors.TabInactive
                b.TextColor3 = Colors.TextDim
            end
        end
        
        -- Aktifkan tab yang diklik
        Page.Visible = true
        Btn.BackgroundColor3 = Colors.TabActive
        Btn.TextColor3 = Colors.Text
    end)
    
    return Page
end

-- ========================================================
-- BUAT TAB DI SINI
-- ========================================================
local ESPPage = CreateTab("ESP", "👁")
local CombatPage = CreateTab("Combat", "⚔")
local MovePage = CreateTab("Movement", "🏃")
local TpPage = CreateTab("Teleport", "📍")
local SettingsPage = CreateTab("Settings", "⚙")

-- Set Default Tab (ESP terbuka pertama kali)
Pages["ESP"].Visible = true
Sidebar:FindFirstChild("ESPBtn").BackgroundColor3 = Colors.TabActive
Sidebar:FindFirstChild("ESPBtn").TextColor3 = Colors.Text

-- ========================================================
-- HELPER: CONTOH CARA MEMBUAT SECTION / KOTAK (Seperti di Gambar)
-- ========================================================
-- Fungsi ini akan membuat kotak gelap dengan judul, 
-- tempat Anda meletakkan fitur (Toggle, Slider, dll) nanti.
local function CreateSection(parentPage, sectionTitle)
    local SectionFrame = Instance.new("Frame")
    SectionFrame.Name = sectionTitle .. "Section"
    SectionFrame.Size = UDim2.new(1, -10, 0, 100) -- Tinggi menyesuaikan fitur di dalamnya nanti
    SectionFrame.BackgroundColor3 = Colors.TopBar
    SectionFrame.BorderSizePixel = 0
    SectionFrame.Parent = parentPage
    
    local SecCorner = Instance.new("UICorner")
    SecCorner.CornerRadius = UDim.new(0, 8)
    SecCorner.Parent = SectionFrame
    
    local SecTitle = Instance.new("TextLabel")
    SecTitle.Size = UDim2.new(1, -20, 0, 30)
    SecTitle.Position = UDim2.new(0, 10, 0, 5)
    SecTitle.BackgroundTransparency = 1
    SecTitle.Text = sectionTitle
    SecTitle.TextColor3 = Colors.TextDim
    SecTitle.Font = Enum.Font.GothamBold
    SecTitle.TextSize = 12
    SecTitle.TextXAlignment = Enum.TextXAlignment.Left
    SecTitle.Parent = SectionFrame

    return SectionFrame -- Kembalikan frame ini agar Anda bisa menambahkan Button/Toggle di dalamnya
end

-- CONTOH PENGGUNAAN SECTION (Bisa Anda hapus/edit)
local ESP_Section = CreateSection(ESPPage, "PLAYER ESP")
local Combat_Section = CreateSection(CombatPage, "COMBAT OPTIONS")
local Move_Section = CreateSection(MovePage, "MOVEMENT OPTIONS")

-- ========================================================
-- SILAKAN TAMBAHKAN FITUR ANDA DI BAWAH INI
-- ========================================================
-- Contoh: 
-- local Toggle = Instance.new("TextButton")
-- Toggle.Parent = ESP_Section
-- dst...
