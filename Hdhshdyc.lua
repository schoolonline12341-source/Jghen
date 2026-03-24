-- ============================================================
--         UNIVERSAL GUI EXPLORER v2.2
--         Debug, Inspect & Live Edit Tool for Roblox
--         Usage: paste into your executor and run
-- ============================================================

-- ============================================================
-- ENVIRONMENT DETECTION
-- ============================================================
local IS_EXECUTOR = (syn or KRNL_LOADED or FLUXUS_LOADED 
    or getgenv ~= nil or identifyexecutor ~= nil)

local EXECUTOR_NAME = "unknown"
pcall(function()
    if identifyexecutor then
        EXECUTOR_NAME = identifyexecutor()
    end
end)

-- ============================================================
-- CLONEREF FALLBACK (robusto)
-- ============================================================
if not cloneref then
    -- Metodo 1: getreg() registry scan (più affidabile)
    local success = pcall(function()
        local probe = Instance.new("Part")
        local list  = nil

        for _, v in pairs(getreg()) do
            if type(v) == "table" and rawget(v, "__mode") == "kvs" then
                for _, item in pairs(v) do
                    if item == probe then list = v; break end
                end
            end
            if list then break end
        end

        probe:Destroy()

        if list then
            getgenv().cloneref = function(inst)
                if typeof(inst) ~= "Instance" then return inst end
                for k, v in pairs(list) do
                    if v == inst then
                        list[k] = nil
                        return inst
                    end
                end
                return inst
            end
        end
    end)

    -- Metodo 2: fallback se getreg() non disponibile
    if not success or not cloneref then
        getgenv().cloneref = function(inst) return inst end
    end
end

-- ============================================================
-- SAFE SERVICE GETTER
-- ============================================================
-- Cache dei servizi già ottenuti (evita chiamate ripetute)
local serviceCache = {}

local function getSafeService(name)
    if serviceCache[name] then return serviceCache[name] end

    local svc
    -- Prova con cloneref
    local ok = pcall(function()
        svc = cloneref(game:GetService(name))
    end)
    -- Fallback senza cloneref
    if not ok or not svc then
        ok = pcall(function()
            svc = game:GetService(name)
        end)
    end

    if ok and svc then
        serviceCache[name] = svc
        return svc
    end

    return nil
end

local function createSafeGui(name, displayOrder)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.DisplayOrder = displayOrder or 999999
    gui.ResetOnSpawn = false
    
    local parent = getSafeParent(gui)
    if parent then
        gui.Parent = parent
    end
    
    return gui
end

-- ============================================================
-- SAFE PARENT GETTER
-- ============================================================
-- Priorità: gethui > syn.protect_gui > CoreGui > PlayerGui
local function getSafeParent(gui)
    -- gethui(): container invisibile ai GetDescendants() del gioco
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end

    -- syn.protect_gui: Synapse X, protegge la GUI dal gioco
    if syn and syn.protect_gui and gui then
        pcall(function() syn.protect_gui(gui) end)
        local ok, cg = pcall(function()
            return getSafeService("CoreGui")
        end)
        if ok and cg then return cg end
    end

    -- CoreGui standard
    local ok, cg = pcall(function()
        return getSafeService("CoreGui")
    end)
    if ok and cg then return cg end

    -- Ultimo fallback: PlayerGui
    local Players = getSafeService("Players")
    if Players and Players.LocalPlayer then
        return Players.LocalPlayer:WaitForChild("PlayerGui", 10)
    end

    return nil
end

-- ============================================================
-- SERVICES (con cache automatica)
-- ============================================================
local Players          = getSafeService("Players")
local CoreGui          = getSafeService("CoreGui")
local UserInputService = getSafeService("UserInputService")
local TweenService     = getSafeService("TweenService")
local RunService       = getSafeService("RunService")
local LocalPlayer      = Players and P

-- ============================================================
-- SERVICES (all cloneref'd for executor safety)
-- ============================================================
local Players          = cloneref(game:GetService("Players"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService     = cloneref(game:GetService("TweenService"))
local RunService       = cloneref(game:GetService("RunService"))
local CoreGui          = cloneref(game:GetService("CoreGui"))
local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    Width = 480, Height = 580,
    BG          = Color3.fromRGB(15, 15, 22),
    SecBG       = Color3.fromRGB(22, 22, 32),
    TerBG       = Color3.fromRGB(30, 30, 44),
    Accent      = Color3.fromRGB(110, 85, 230),
    AccentHover = Color3.fromRGB(130, 105, 255),
    Success     = Color3.fromRGB(60, 200, 120),
    Warning     = Color3.fromRGB(230, 180, 50),
    Danger      = Color3.fromRGB(220, 60, 60),
    Text        = Color3.fromRGB(225, 225, 240),
    SubText     = Color3.fromRGB(130, 130, 155),
    Hover       = Color3.fromRGB(38, 38, 55),
    Selected    = Color3.fromRGB(55, 42, 100),
    Indent      = 16,
}

-- ============================================================
-- UTILITY
-- ============================================================
local function corner(p, r)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end
local function pad(p, t, r, b, l)
    local u = Instance.new("UIPadding", p)
    u.PaddingTop    = UDim.new(0, t or 4)
    u.PaddingRight  = UDim.new(0, r or 4)
    u.PaddingBottom = UDim.new(0, b or 4)
    u.PaddingLeft   = UDim.new(0, l or 4)
end
local function tween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end
local function truncate(s, n)
    return #s > n and s:sub(1, n) .. "..." or s
end

local ICONS = {
    ScreenGui="[SG]", BillboardGui="[BG]", SurfaceGui="[SUG]",
    Frame="[F]", ScrollingFrame="[SF]", ViewportFrame="[VF]",
    TextLabel="[TL]", TextButton="[TB]", TextBox="[TBX]",
    ImageLabel="[IL]", ImageButton="[IB]",
    LocalScript="[LS]", Script="[S]", ModuleScript="[MS]",
    UIListLayout="[LL]", UIGridLayout="[GL]", UITableLayout="[TBL]",
    UICorner="[UC]", UIStroke="[US]", UIPadding="[UP]",
    UIAspectRatioConstraint="[AR]", UISizeConstraint="[SC]",
    SelectionBox="[SB]", SelectionSphere="[SS]",
    DEFAULT="[?]"
}
local function icon(inst)
    return ICONS[inst.ClassName] or ICONS.DEFAULT
end
local function getColor(inst)
    if inst:IsA("ScreenGui") then return Color3.fromRGB(110,85,230)
    elseif inst:IsA("LocalScript") or inst:IsA("Script") then return Color3.fromRGB(230,180,50)
    elseif inst:IsA("UIBase") then return Color3.fromRGB(60,200,120)
    elseif inst:IsA("GuiButton") then return Color3.fromRGB(200,100,100)
    elseif inst:IsA("TextLabel") then return Color3.fromRGB(100,180,230)
    elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then return Color3.fromRGB(230,150,80)
    else return Color3.fromRGB(130,130,155) end
end

-- Safe cloneref wrapper: returns cloneref'd service or raw if cloneref fails
local function safeGetService(name)
    local ok, svc = pcall(function() return cloneref(game:GetService(name)) end)
    if ok then return svc end
    return game:GetService(name)
end

local function getRoots(includeCoreGui)
    local roots = {}
    for _, g in ipairs(PlayerGui:GetChildren()) do
        if g:IsA("ScreenGui") or g:IsA("BillboardGui") or g:IsA("SurfaceGui") then
            table.insert(roots, g)
        end
    end
    if includeCoreGui then
        pcall(function()
            for _, g in ipairs(CoreGui:GetChildren()) do
                table.insert(roots, g)
            end
        end)
    end
    return roots
end

local function flattenTree(root, indent, filter, rows, expanded)
    for _, child in ipairs(root:GetChildren()) do
        local name  = child.Name:lower()
        local cls   = child.ClassName:lower()
        local match = (filter == "") or name:find(filter,1,true) or cls:find(filter,1,true)
        if match then
            table.insert(rows, {inst=child, indent=indent})
        end
        if expanded[child] or filter ~= "" then
            flattenTree(child, indent+1, filter, rows, expanded)
        end
    end
end

-- ============================================================
-- PROPERTY READER
-- ============================================================
local function readProps(inst)
    local p = {}
    local function try(fn) pcall(fn) end

    try(function() table.insert(p, {k="Class",      v=inst.ClassName,                       t="string", e=false}) end)
    try(function() table.insert(p, {k="Name",        v=inst.Name,                            t="string", e=true,  prop="Name"}) end)

    try(function() if inst:IsA("GuiObject") then
        table.insert(p, {k="Visible",       v=tostring(inst.Visible),                        t="bool",   e=true,  prop="Visible"})
        table.insert(p, {k="ZIndex",        v=tostring(inst.ZIndex),                         t="number", e=true,  prop="ZIndex"})
        table.insert(p, {k="Rotation",      v=tostring(inst.Rotation),                       t="number", e=true,  prop="Rotation"})
        table.insert(p, {k="Transparency",  v=tostring(inst.BackgroundTransparency),         t="number", e=true,  prop="BackgroundTransparency"})
        table.insert(p, {k="BgColor",       v=tostring(inst.BackgroundColor3),               t="color",  e=true,  prop="BackgroundColor3"})
        table.insert(p, {k="AnchorPoint",   v=tostring(inst.AnchorPoint),                    t="vector2",e=true,  prop="AnchorPoint"})
        table.insert(p, {k="ClipsDesc",     v=tostring(inst.ClipsDescendants),               t="bool",   e=true,  prop="ClipsDescendants"})
        table.insert(p, {k="AbsSize",       v=tostring(inst.AbsoluteSize),                   t="string", e=false})
        table.insert(p, {k="AbsPos",        v=tostring(inst.AbsolutePosition),               t="string", e=false})
    end end)

    try(function() if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        table.insert(p, {k="Text",          v=inst.Text,                                     t="string", e=true,  prop="Text"})
        table.insert(p, {k="TextSize",      v=tostring(inst.TextSize),                       t="number", e=true,  prop="TextSize"})
        table.insert(p, {k="TextColor",     v=tostring(inst.TextColor3),                     t="color",  e=true,  prop="TextColor3"})
        table.insert(p, {k="RichText",      v=tostring(inst.RichText),                       t="bool",   e=true,  prop="RichText"})
        table.insert(p, {k="TextScaled",    v=tostring(inst.TextScaled),                     t="bool",   e=true,  prop="TextScaled"})
        table.insert(p, {k="Font",          v=tostring(inst.Font),                           t="string", e=false})
        table.insert(p, {k="TextFits",      v=tostring(inst.TextFits),                       t="string", e=false})
    end end)

    try(function() if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
        table.insert(p, {k="Image",         v=inst.Image,                                    t="string", e=true,  prop="Image"})
        table.insert(p, {k="ImageColor",    v=tostring(inst.ImageColor3),                    t="color",  e=true,  prop="ImageColor3"})
        table.insert(p, {k="ImageTransp",   v=tostring(inst.ImageTransparency),              t="number", e=true,  prop="ImageTransparency"})
        table.insert(p, {k="ScaleType",     v=tostring(inst.ScaleType),                      t="string", e=false})
    end end)

    try(function() if inst:IsA("ScreenGui") then
        table.insert(p, {k="Enabled",       v=tostring(inst.Enabled),                        t="bool",   e=true,  prop="Enabled"})
        table.insert(p, {k="DisplayOrder",  v=tostring(inst.DisplayOrder),                   t="number", e=true,  prop="DisplayOrder"})
        table.insert(p, {k="ResetOnSpawn",  v=tostring(inst.ResetOnSpawn),                   t="bool",   e=true,  prop="ResetOnSpawn"})
        table.insert(p, {k="ZIndexBehavior",v=tostring(inst.ZIndexBehavior),                 t="string", e=false})
    end end)

    try(function() if inst:IsA("ScrollingFrame") then
        table.insert(p, {k="ScrollBarThick",v=tostring(inst.ScrollBarThickness),             t="number", e=true,  prop="ScrollBarThickness"})
        table.insert(p, {k="CanvasSize",    v=tostring(inst.CanvasSize),                     t="string", e=false})
    end end)

    try(function() if inst:IsA("UICorner") then
        table.insert(p, {k="CornerRadius",  v=tostring(inst.CornerRadius),                   t="string", e=false})
    end end)

    try(function() if inst:IsA("UIStroke") then
        table.insert(p, {k="Color",         v=tostring(inst.Color),                          t="color",  e=true,  prop="Color"})
        table.insert(p, {k="Thickness",     v=tostring(inst.Thickness),                      t="number", e=true,  prop="Thickness"})
    end end)

    try(function() table.insert(p, {k="Children", v=tostring(#inst:GetChildren()), t="string", e=false}) end)
    return p
end

-- ============================================================
-- APPLY PROPERTY
-- ============================================================
local function applyProp(inst, prop, rawVal, propType)
    local ok, err = pcall(function()
        if propType == "bool" then
            local v = rawVal:lower()
            inst[prop] = (v == "true" or v == "1" or v == "yes")
        elseif propType == "number" then
            local n = tonumber(rawVal)
            if n then inst[prop] = n end
        elseif propType == "string" then
            inst[prop] = rawVal
        elseif propType == "color" then
            local raw = rawVal:gsub(",", " ")
            local r,g,b = raw:match("(%d+%.?%d*)%s+(%d+%.?%d*)%s+(%d+%.?%d*)")
            if r then
                local ri,gi,bi = tonumber(r),tonumber(g),tonumber(b)
                if ri > 1 or gi > 1 or bi > 1 then
                    inst[prop] = Color3.fromRGB(ri, gi, bi)
                else
                    inst[prop] = Color3.new(ri, gi, bi)
                end
            end
        elseif propType == "vector2" then
            local raw = rawVal:gsub(",", " ")
            local x,y = raw:match("(%d+%.?%d*)%s+(%d+%.?%d*)")
            if x then inst[prop] = Vector2.new(tonumber(x), tonumber(y)) end
        end
    end)
    return ok, err
end

-- ============================================================
-- BUILD MAIN GUI
-- ============================================================
local SG = createSafeGui("UniversalGUIExplorer", 999999)

local MF = Instance.new("Frame")
MF.Name = "Main"
MF.Size = UDim2.new(0, CFG.Width, 0, CFG.Height)
MF.Position = UDim2.new(0.5, -CFG.Width/2, 0.5, -CFG.Height/2)
MF.BackgroundColor3 = CFG.BG
MF.BorderSizePixel = 0
MF.Parent = SG
corner(MF, 12)

local Glow = Instance.new("ImageLabel")
Glow.Size = UDim2.new(1, 60, 1, 60)
Glow.Position = UDim2.new(0,-30,0,-30)
Glow.BackgroundTransparency = 1
Glow.Image = "rbxassetid://5028857084"
Glow.ImageColor3 = CFG.Accent
Glow.ImageTransparency = 0.7
Glow.ScaleType = Enum.ScaleType.Slice
Glow.SliceCenter = Rect.new(24,24,276,276)
Glow.ZIndex = MF.ZIndex - 1
Glow.Parent = MF

-- ============================================================
-- TITLEBAR
-- ============================================================
local TB = Instance.new("Frame")
TB.Size = UDim2.new(1,0,0,38)
TB.BackgroundColor3 = CFG.Accent
TB.BorderSizePixel = 0
TB.ZIndex = 2
TB.Parent = MF
corner(TB, 12)

local TBFix = Instance.new("Frame")
TBFix.Size = UDim2.new(1,0,0.5,0)
TBFix.Position = UDim2.new(0,0,0.5,0)
TBFix.BackgroundColor3 = CFG.Accent
TBFix.BorderSizePixel = 0
TBFix.ZIndex = 2
TBFix.Parent = TB

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = "  [*] Universal GUI Explorer  v2.2"
TitleLabel.Size = UDim2.new(1,-100,1,0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.new(1,1,1)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 3
TitleLabel.Parent = TB

local function mkBtn(txt, xOff, col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,26,0,26)
    b.Position = UDim2.new(1,xOff,0,6)
    b.BackgroundColor3 = col
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = txt
    b.BorderSizePixel = 0
    b.ZIndex = 4
    b.Parent = TB
    corner(b, 6)
    return b
end
local CloseBtn = mkBtn("X", -32, CFG.Danger)
local MinBtn   = mkBtn("-", -62, Color3.fromRGB(50,50,70))

CloseBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

do
    local drag, ds, sp = false, nil, nil
    TB.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag=true; ds=i.Position; sp=MF.Position
        end
    end)
    TB.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            MF.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
        end
    end)
end

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    tween(MF, {Size = UDim2.new(0, CFG.Width, 0, minimized and 38 or CFG.Height)}, 0.2)
    MinBtn.Text = minimized and "[]" or "-"
end)

-- ============================================================
-- TAB SYSTEM
-- ============================================================
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1,-16,0,30)
TabBar.Position = UDim2.new(0,8,0,46)
TabBar.BackgroundColor3 = CFG.SecBG
TabBar.BorderSizePixel = 0
TabBar.Parent = MF
corner(TabBar, 8)

local TabList = Instance.new("UIListLayout")
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Padding = UDim.new(0,3)
TabList.Parent = TabBar
pad(TabBar,3,4,3,4)

local TABS = {"Explorer","Properties","Edit","Spy","Overlay","Settings"}
local tabBtns   = {}
local tabPanels = {}

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1,-16,0,CFG.Height-140)
ContentArea.Position = UDim2.new(0,8,0,84)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants = true
ContentArea.Parent = MF

local function makePanel()
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,1,0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = ContentArea
    return f
end

local activeTab = nil
local function switchTab(name)
    for _, t in pairs(TABS) do
        if tabBtns[t] then
            local isActive = (t == name)
            tween(tabBtns[t], {BackgroundColor3 = isActive and CFG.Accent or CFG.TerBG}, 0.15)
            tabBtns[t].TextColor3 = isActive and Color3.new(1,1,1) or CFG.SubText
        end
        if tabPanels[t] then tabPanels[t].Visible = (t==name) end
    end
    activeTab = name
end

for i, tname in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 68, 1, 0)
    btn.BackgroundColor3 = CFG.TerBG
    btn.TextColor3 = CFG.SubText
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 10
    btn.Text = tname
    btn.BorderSizePixel = 0
    btn.LayoutOrder = i
    btn.Parent = TabBar
    corner(btn, 6)
    tabBtns[tname]   = btn
    tabPanels[tname] = makePanel()
    btn.MouseButton1Click:Connect(function() switchTab(tname) end)
end

-- ============================================================
-- STATUS BAR
-- ============================================================
local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1,-16,0,24)
StatusBar.Position = UDim2.new(0,8,1,-30)
StatusBar.BackgroundColor3 = CFG.SecBG
StatusBar.BorderSizePixel = 0
StatusBar.Parent = MF
corner(StatusBar, 6)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1,-8,1,0)
StatusLabel.Position = UDim2.new(0,8,0,0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = CFG.SubText
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Text = "Ready."
StatusLabel.Parent = StatusBar

local function setStatus(txt, col)
    StatusLabel.Text = txt
    StatusLabel.TextColor3 = col or CFG.SubText
    task.delay(4, function()
        if StatusLabel.Text == txt then
            StatusLabel.Text = "Ready."
            StatusLabel.TextColor3 = CFG.SubText
        end
    end)
end

-- ============================================================
-- TAB 1: EXPLORER
-- ============================================================
local ExpPanel  = tabPanels["Explorer"]
local expanded  = {}
local selectedInst = nil

local ExpToolbar = Instance.new("Frame")
ExpToolbar.Size = UDim2.new(1,0,0,30)
ExpToolbar.BackgroundColor3 = CFG.SecBG
ExpToolbar.BorderSizePixel = 0
ExpToolbar.Parent = ExpPanel
corner(ExpToolbar, 7)

local SearchBox = Instance.new("TextBox")
SearchBox.PlaceholderText = "Search instance..."
SearchBox.Size = UDim2.new(1,-100,1,-8)
SearchBox.Position = UDim2.new(0,8,0,4)
SearchBox.BackgroundTransparency = 1
SearchBox.TextColor3 = CFG.Text
SearchBox.PlaceholderColor3 = CFG.SubText
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = ExpToolbar

local CoreToggle = Instance.new("TextButton")
CoreToggle.Text = "Core: OFF"
CoreToggle.Size = UDim2.new(0,78,1,-8)
CoreToggle.Position = UDim2.new(1,-86,0,4)
CoreToggle.BackgroundColor3 = CFG.TerBG
CoreToggle.TextColor3 = CFG.SubText
CoreToggle.Font = Enum.Font.GothamSemibold
CoreToggle.TextSize = 10
CoreToggle.BorderSizePixel = 0
CoreToggle.Parent = ExpToolbar
corner(CoreToggle, 5)

local includeCoreGui = false
CoreToggle.MouseButton1Click:Connect(function()
    includeCoreGui = not includeCoreGui
    CoreToggle.Text = includeCoreGui and "Core: ON" or "Core: OFF"
    CoreToggle.BackgroundColor3 = includeCoreGui and CFG.Success or CFG.TerBG
    CoreToggle.TextColor3 = includeCoreGui and Color3.new(1,1,1) or CFG.SubText
    refreshExplorer()
end)

local TreeScroll = Instance.new("ScrollingFrame")
TreeScroll.Size = UDim2.new(1,0,1,-36)
TreeScroll.Position = UDim2.new(0,0,0,36)
TreeScroll.BackgroundColor3 = CFG.SecBG
TreeScroll.BorderSizePixel = 0
TreeScroll.ScrollBarThickness = 4
TreeScroll.ScrollBarImageColor3 = CFG.Accent
TreeScroll.CanvasSize = UDim2.new(0,0,0,0)
TreeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
TreeScroll.Parent = ExpPanel
corner(TreeScroll, 7)
pad(TreeScroll, 4, 2, 4, 2)

local TreeLayout = Instance.new("UIListLayout")
TreeLayout.SortOrder = Enum.SortOrder.LayoutOrder
TreeLayout.Padding = UDim.new(0,1)
TreeLayout.Parent = TreeScroll

function refreshExplorer()
    for _, c in ipairs(TreeScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end

    local filter = SearchBox.Text:lower()
    local roots  = getRoots(includeCoreGui)
    local rows   = {}

    for _, root in ipairs(roots) do
        local matchRoot = (filter=="") or root.Name:lower():find(filter,1,true) or root.ClassName:lower():find(filter,1,true)
        if matchRoot then table.insert(rows, {inst=root, indent=0}) end
        if expanded[root] or filter~="" then
            flattenTree(root, 1, filter, rows, expanded)
        end
    end

    local count = 0
    for _, row in ipairs(rows) do
        count = count + 1
        local inst    = row.inst
        local ind     = row.indent
        local hasKids = #inst:GetChildren() > 0
        local isExp   = expanded[inst]

        local Row = Instance.new("TextButton")
        Row.Size = UDim2.new(1,0,0,22)
        Row.BackgroundColor3 = (selectedInst==inst) and CFG.Selected or CFG.SecBG
        Row.BackgroundTransparency = (selectedInst==inst) and 0 or 1
        Row.BorderSizePixel = 0
        Row.AutoButtonColor = false
        Row.LayoutOrder = count
        Row.Parent = TreeScroll

        Row.MouseEnter:Connect(function()
            if selectedInst~=inst then tween(Row,{BackgroundColor3=CFG.Hover,BackgroundTransparency=0},0.08) end
        end)
        Row.MouseLeave:Connect(function()
            if selectedInst~=inst then tween(Row,{BackgroundTransparency=1},0.08) end
        end)

        for i = 1, ind-1 do
            local line = Instance.new("Frame")
            line.Size = UDim2.new(0,1,1,0)
            line.Position = UDim2.new(0, i*CFG.Indent+7, 0, 0)
            line.BackgroundColor3 = Color3.fromRGB(50,50,70)
            line.BorderSizePixel = 0
            line.Parent = Row
        end

        local Arr = Instance.new("TextLabel")
        Arr.Size = UDim2.new(0,14,1,0)
        Arr.Position = UDim2.new(0, ind*CFG.Indent, 0, 0)
        Arr.BackgroundTransparency = 1
        Arr.Text = hasKids and (isExp and "v" or ">") or ""
        Arr.TextColor3 = CFG.Accent
        Arr.Font = Enum.Font.GothamBold
        Arr.TextSize = 11
        Arr.Parent = Row

        local Ico = Instance.new("TextLabel")
        Ico.Size = UDim2.new(0,28,1,0)
        Ico.Position = UDim2.new(0, ind*CFG.Indent+14, 0, 0)
        Ico.BackgroundTransparency = 1
        Ico.Text = icon(inst)
        Ico.TextColor3 = getColor(inst)
        Ico.Font = Enum.Font.GothamBold
        Ico.TextSize = 9
        Ico.Parent = Row

        local NameL = Instance.new("TextLabel")
        NameL.Size = UDim2.new(1,-(ind*CFG.Indent+44),1,0)
        NameL.Position = UDim2.new(0, ind*CFG.Indent+44, 0, 0)
        NameL.BackgroundTransparency = 1
        NameL.Text = truncate(inst.Name,24)
        NameL.TextColor3 = CFG.Text
        NameL.Font = Enum.Font.Gotham
        NameL.TextSize = 12
        NameL.TextXAlignment = Enum.TextXAlignment.Left
        NameL.Parent = Row

        local ClsBadge = Instance.new("TextLabel")
        ClsBadge.Size = UDim2.new(0,0,0,16)
        ClsBadge.AutomaticSize = Enum.AutomaticSize.X
        ClsBadge.Position = UDim2.new(1,-2,0.5,-8)
        ClsBadge.AnchorPoint = Vector2.new(1,0)
        ClsBadge.BackgroundColor3 = CFG.TerBG
        ClsBadge.TextColor3 = CFG.SubText
        ClsBadge.Font = Enum.Font.Gotham
        ClsBadge.TextSize = 9
        ClsBadge.Text = inst.ClassName .. " "
        ClsBadge.BorderSizePixel = 0
        ClsBadge.Parent = Row
        corner(ClsBadge, 4)
        pad(ClsBadge, 0, 4, 0, 4)

        Row.MouseButton1Click:Connect(function()
            if hasKids then expanded[inst] = not expanded[inst] end
            selectedInst = inst
            refreshExplorer()
            showProperties(inst)
            refreshEditPanel(inst)
            setStatus("Selected: " .. inst.Name .. " (" .. inst.ClassName .. ")", CFG.Accent)
        end)
    end
    setStatus(count .. " instances found", CFG.SubText)
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(refreshExplorer)

-- ============================================================
-- TAB 2: PROPERTIES
-- ============================================================
local PropPanel = tabPanels["Properties"]

local PropTitle = Instance.new("TextLabel")
PropTitle.Size = UDim2.new(1,0,0,24)
PropTitle.BackgroundTransparency = 1
PropTitle.TextColor3 = CFG.SubText
PropTitle.Font = Enum.Font.GothamSemibold
PropTitle.TextSize = 12
PropTitle.Text = "No instance selected"
PropTitle.TextXAlignment = Enum.TextXAlignment.Left
PropTitle.Parent = PropPanel

local PropScroll = Instance.new("ScrollingFrame")
PropScroll.Size = UDim2.new(1,0,1,-28)
PropScroll.Position = UDim2.new(0,0,0,28)
PropScroll.BackgroundColor3 = CFG.SecBG
PropScroll.BorderSizePixel = 0
PropScroll.ScrollBarThickness = 4
PropScroll.ScrollBarImageColor3 = CFG.Accent
PropScroll.CanvasSize = UDim2.new(0,0,0,0)
PropScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PropScroll.Parent = PropPanel
corner(PropScroll, 7)

local PropLayout = Instance.new("UIListLayout")
PropLayout.SortOrder = Enum.SortOrder.LayoutOrder
PropLayout.Padding = UDim.new(0,2)
PropLayout.Parent = PropScroll
pad(PropScroll, 4, 4, 4, 4)

function showProperties(inst)
    for _, c in ipairs(PropScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    PropTitle.Text = icon(inst) .. "  " .. inst.Name .. "  *  " .. inst.ClassName
    PropTitle.TextColor3 = getColor(inst)

    local props = readProps(inst)
    for i, kv in ipairs(props) do
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1,0,0,22)
        Row.BackgroundColor3 = (i%2==0) and CFG.TerBG or CFG.SecBG
        Row.BorderSizePixel = 0
        Row.LayoutOrder = i
        Row.Parent = PropScroll
        corner(Row, 4)

        if kv.e then
            local badge = Instance.new("Frame")
            badge.Size = UDim2.new(0,4,1,0)
            badge.BackgroundColor3 = CFG.Success
            badge.BorderSizePixel = 0
            badge.Parent = Row
            corner(badge, 2)
        end

        local KL = Instance.new("TextLabel")
        KL.Size = UDim2.new(0.38,0,1,0)
        KL.Position = UDim2.new(0,6,0,0)
        KL.BackgroundTransparency = 1
        KL.TextColor3 = kv.e and CFG.Accent or CFG.SubText
        KL.Font = Enum.Font.GothamSemibold
        KL.TextSize = 11
        KL.Text = "  " .. kv.k
        KL.TextXAlignment = Enum.TextXAlignment.Left
        KL.Parent = Row

        local VL = Instance.new("TextLabel")
        VL.Size = UDim2.new(0.62,-4,1,0)
        VL.Position = UDim2.new(0.38,0,0,0)
        VL.BackgroundTransparency = 1
        VL.TextColor3 = CFG.Text
        VL.Font = Enum.Font.Gotham
        VL.TextSize = 11
        VL.Text = tostring(kv.v)
        VL.TextXAlignment = Enum.TextXAlignment.Left
        VL.TextTruncate = Enum.TextTruncate.AtEnd
        VL.Parent = Row
    end

    local legend = Instance.new("TextLabel")
    legend.Size = UDim2.new(1,0,0,16)
    legend.BackgroundTransparency = 1
    legend.TextColor3 = CFG.Success
    legend.Font = Enum.Font.Gotham
    legend.TextSize = 9
    legend.Text = "  | Green bar = editable in the Edit tab"
    legend.TextXAlignment = Enum.TextXAlignment.Left
    legend.LayoutOrder = 999
    legend.Parent = PropScroll
end

-- ============================================================
-- TAB 3: LIVE EDIT
-- ============================================================
local EditPanel = tabPanels["Edit"]

local EditHeader = Instance.new("TextLabel")
EditHeader.Size = UDim2.new(1,0,0,22)
EditHeader.BackgroundTransparency = 1
EditHeader.TextColor3 = CFG.SubText
EditHeader.Font = Enum.Font.GothamSemibold
EditHeader.TextSize = 11
EditHeader.Text = "No instance selected  —  select one from Explorer"
EditHeader.TextXAlignment = Enum.TextXAlignment.Left
EditHeader.Parent = EditPanel

local EditScroll = Instance.new("ScrollingFrame")
EditScroll.Size = UDim2.new(1,0,1,-26)
EditScroll.Position = UDim2.new(0,0,0,26)
EditScroll.BackgroundColor3 = CFG.SecBG
EditScroll.BorderSizePixel = 0
EditScroll.ScrollBarThickness = 4
EditScroll.ScrollBarImageColor3 = CFG.Accent
EditScroll.CanvasSize = UDim2.new(0,0,0,0)
EditScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
EditScroll.Parent = EditPanel
corner(EditScroll, 7)

local EditLayout = Instance.new("UIListLayout")
EditLayout.SortOrder = Enum.SortOrder.LayoutOrder
EditLayout.Padding = UDim.new(0,3)
EditLayout.Parent = EditScroll
pad(EditScroll, 4, 4, 4, 4)

function refreshEditPanel(inst)
    for _, c in ipairs(EditScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    if not inst then
        EditHeader.Text = "No instance selected  —  select one from Explorer"
        EditHeader.TextColor3 = CFG.SubText
        return
    end

    EditHeader.Text = icon(inst) .. "  Editing: " .. inst.Name .. "  (" .. inst.ClassName .. ")"
    EditHeader.TextColor3 = getColor(inst)

    local props = readProps(inst)
    local order = 0

    for _, kv in ipairs(props) do
        if not kv.e then continue end

        order = order + 1
        local propType = kv.t
        local propKey  = kv.prop

        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1,0,0,48)
        Row.BackgroundColor3 = CFG.TerBG
        Row.BorderSizePixel = 0
        Row.LayoutOrder = order
        Row.Parent = EditScroll
        corner(Row, 7)

        local KL = Instance.new("TextLabel")
        KL.Size = UDim2.new(1,0,0,18)
        KL.Position = UDim2.new(0,8,0,2)
        KL.BackgroundTransparency = 1
        KL.TextColor3 = CFG.Accent
        KL.Font = Enum.Font.GothamSemibold
        KL.TextSize = 10
        KL.TextXAlignment = Enum.TextXAlignment.Left
        KL.Parent = Row

        local typeBadge = Instance.new("TextLabel")
        typeBadge.Size = UDim2.new(0,0,0,14)
        typeBadge.AutomaticSize = Enum.AutomaticSize.X
        typeBadge.Position = UDim2.new(1,-4,0,4)
        typeBadge.AnchorPoint = Vector2.new(1,0)
        typeBadge.BackgroundColor3 = Color3.fromRGB(40,40,60)
        typeBadge.BorderSizePixel = 0
        typeBadge.TextColor3 = CFG.SubText
        typeBadge.Font = Enum.Font.Gotham
        typeBadge.TextSize = 9
        typeBadge.Text = " " .. propType .. " "
        typeBadge.Parent = Row
        corner(typeBadge, 3)

        local Feedback = Instance.new("TextLabel")
        Feedback.Size = UDim2.new(0,60,0,18)
        Feedback.Position = UDim2.new(1,-64,0,28)
        Feedback.BackgroundTransparency = 1
        Feedback.TextColor3 = CFG.SubText
        Feedback.Font = Enum.Font.GothamBold
        Feedback.TextSize = 10
        Feedback.Text = ""
        Feedback.TextXAlignment = Enum.TextXAlignment.Right
        Feedback.Parent = Row

        local function flash(ok)
            Feedback.Text = ok and "OK" or "ERR"
            Feedback.TextColor3 = ok and CFG.Success or CFG.Danger
            task.delay(1.5, function() Feedback.Text = "" end)
        end

        -- BOOL
        if propType == "bool" then
            KL.Text = kv.k .. ":  " .. tostring(kv.v)
            local TogBtn = Instance.new("TextButton")
            TogBtn.Size = UDim2.new(0.5,-12,0,22)
            TogBtn.Position = UDim2.new(0,8,0,22)
            TogBtn.BorderSizePixel = 0
            TogBtn.Font = Enum.Font.GothamBold
            TogBtn.TextSize = 11
            TogBtn.TextColor3 = Color3.new(1,1,1)
            TogBtn.Parent = Row
            corner(TogBtn, 5)
            local function updateTogBtn()
                local cur = false
                pcall(function() cur = inst[propKey] end)
                TogBtn.Text = cur and "TRUE" or "FALSE"
                TogBtn.BackgroundColor3 = cur and CFG.Success or CFG.Danger
                KL.Text = kv.k .. ":  " .. tostring(cur)
            end
            updateTogBtn()
            TogBtn.MouseButton1Click:Connect(function()
                local ok = pcall(function() inst[propKey] = not inst[propKey] end)
                updateTogBtn(); flash(ok)
                showProperties(inst)
                setStatus("Edited " .. kv.k .. " on " .. inst.Name, CFG.Success)
            end)

        -- NUMBER
        elseif propType == "number" then
            KL.Text = kv.k
            local InputBox = Instance.new("TextBox")
            InputBox.Size = UDim2.new(1,-80,0,22)
            InputBox.Position = UDim2.new(0,8,0,22)
            InputBox.BackgroundColor3 = CFG.SecBG
            InputBox.BorderSizePixel = 0
            InputBox.TextColor3 = CFG.Text
            InputBox.PlaceholderColor3 = CFG.SubText
            InputBox.Font = Enum.Font.Code
            InputBox.TextSize = 11
            InputBox.TextXAlignment = Enum.TextXAlignment.Left
            InputBox.ClearTextOnFocus = false
            InputBox.Text = tostring(kv.v)
            InputBox.PlaceholderText = "number..."
            InputBox.Parent = Row
            corner(InputBox, 5); pad(InputBox, 0, 4, 0, 6)

            local BtnMinus = Instance.new("TextButton")
            BtnMinus.Size = UDim2.new(0,28,0,22)
            BtnMinus.Position = UDim2.new(1,-64,0,22)
            BtnMinus.BackgroundColor3 = CFG.SecBG
            BtnMinus.TextColor3 = CFG.Text
            BtnMinus.Font = Enum.Font.GothamBold
            BtnMinus.TextSize = 14
            BtnMinus.Text = "-"
            BtnMinus.BorderSizePixel = 0
            BtnMinus.Parent = Row
            corner(BtnMinus, 5)

            local BtnPlus = Instance.new("TextButton")
            BtnPlus.Size = UDim2.new(0,28,0,22)
            BtnPlus.Position = UDim2.new(1,-34,0,22)
            BtnPlus.BackgroundColor3 = CFG.SecBG
            BtnPlus.TextColor3 = CFG.Text
            BtnPlus.Font = Enum.Font.GothamBold
            BtnPlus.TextSize = 14
            BtnPlus.Text = "+"
            BtnPlus.BorderSizePixel = 0
            BtnPlus.Parent = Row
            corner(BtnPlus, 5)

            local function applyNum(v)
                local ok = pcall(function() inst[propKey] = v end)
                InputBox.Text = tostring(v); flash(ok)
                if ok then showProperties(inst); setStatus("Edited " .. kv.k .. " -> " .. v, CFG.Success) end
            end
            InputBox.FocusLost:Connect(function(enter)
                if enter then local n = tonumber(InputBox.Text); if n then applyNum(n) else flash(false) end end
            end)
            BtnMinus.MouseButton1Click:Connect(function() applyNum((tonumber(InputBox.Text) or 0) - 1) end)
            BtnPlus.MouseButton1Click:Connect(function()  applyNum((tonumber(InputBox.Text) or 0) + 1) end)

        -- STRING
        elseif propType == "string" then
            KL.Text = kv.k
            local InputBox = Instance.new("TextBox")
            InputBox.Size = UDim2.new(1,-16,0,22)
            InputBox.Position = UDim2.new(0,8,0,22)
            InputBox.BackgroundColor3 = CFG.SecBG
            InputBox.BorderSizePixel = 0
            InputBox.TextColor3 = CFG.Text
            InputBox.PlaceholderColor3 = CFG.SubText
            InputBox.Font = Enum.Font.Code
            InputBox.TextSize = 11
            InputBox.TextXAlignment = Enum.TextXAlignment.Left
            InputBox.ClearTextOnFocus = false
            InputBox.Text = tostring(kv.v)
            InputBox.PlaceholderText = "string..."
            InputBox.Parent = Row
            corner(InputBox, 5); pad(InputBox, 0, 4, 0, 6)
            InputBox.FocusLost:Connect(function(enter)
                if enter then
                    local ok = pcall(function() inst[propKey] = InputBox.Text end)
                    flash(ok)
                    if ok then showProperties(inst); setStatus("Edited " .. kv.k .. " on " .. inst.Name, CFG.Success) end
                end
            end)

        -- COLOR
        elseif propType == "color" then
            KL.Text = kv.k .. "  (R G B  0-255)"
            local Swatch = Instance.new("Frame")
            Swatch.Size = UDim2.new(0,20,0,20)
            Swatch.Position = UDim2.new(1,-28,0,24)
            Swatch.BorderSizePixel = 0
            Swatch.Parent = Row
            corner(Swatch, 4)
            local function updateSwatch()
                pcall(function() Swatch.BackgroundColor3 = inst[propKey] end)
            end
            updateSwatch()
            local InputBox = Instance.new("TextBox")
            InputBox.Size = UDim2.new(1,-36,0,22)
            InputBox.Position = UDim2.new(0,8,0,22)
            InputBox.BackgroundColor3 = CFG.SecBG
            InputBox.BorderSizePixel = 0
            InputBox.TextColor3 = CFG.Text
            InputBox.PlaceholderColor3 = CFG.SubText
            InputBox.Font = Enum.Font.Code
            InputBox.TextSize = 10
            InputBox.TextXAlignment = Enum.TextXAlignment.Left
            InputBox.ClearTextOnFocus = false
            pcall(function()
                local c = inst[propKey]
                InputBox.Text = math.floor(c.R*255).." "..math.floor(c.G*255).." "..math.floor(c.B*255)
            end)
            InputBox.PlaceholderText = "R G B (e.g. 255 0 128)"
            InputBox.Parent = Row
            corner(InputBox, 5); pad(InputBox, 0, 4, 0, 6)
            InputBox.FocusLost:Connect(function(enter)
                if enter then
                    local ok = applyProp(inst, propKey, InputBox.Text, "color")
                    flash(ok)
                    if ok then updateSwatch(); showProperties(inst); setStatus("Edited " .. kv.k .. " on " .. inst.Name, CFG.Success) end
                end
            end)

        -- VECTOR2
        elseif propType == "vector2" then
            KL.Text = kv.k .. "  (X Y)"
            local InputBox = Instance.new("TextBox")
            InputBox.Size = UDim2.new(1,-16,0,22)
            InputBox.Position = UDim2.new(0,8,0,22)
            InputBox.BackgroundColor3 = CFG.SecBG
            InputBox.BorderSizePixel = 0
            InputBox.TextColor3 = CFG.Text
            InputBox.PlaceholderColor3 = CFG.SubText
            InputBox.Font = Enum.Font.Code
            InputBox.TextSize = 11
            InputBox.TextXAlignment = Enum.TextXAlignment.Left
            InputBox.ClearTextOnFocus = false
            pcall(function() local v2 = inst[propKey]; InputBox.Text = v2.X .. " " .. v2.Y end)
            InputBox.PlaceholderText = "X Y (e.g. 0.5 0.5)"
            InputBox.Parent = Row
            corner(InputBox, 5); pad(InputBox, 0, 4, 0, 6)
            InputBox.FocusLost:Connect(function(enter)
                if enter then
                    local ok = applyProp(inst, propKey, InputBox.Text, "vector2")
                    flash(ok)
                    if ok then showProperties(inst); setStatus("Edited " .. kv.k .. " on " .. inst.Name, CFG.Success) end
                end
            end)
        end
    end

    if order == 0 then
        local msg = Instance.new("TextLabel")
        msg.Size = UDim2.new(1,0,0,40)
        msg.BackgroundTransparency = 1
        msg.TextColor3 = CFG.SubText
        msg.Font = Enum.Font.Gotham
        msg.TextSize = 11
        msg.Text = "No editable properties for this instance type."
        msg.Parent = EditScroll
    end
end

-- ============================================================
-- TAB 4: EVENT SPY
-- ============================================================
local SpyPanel = tabPanels["Spy"]
local spyActive = false
local spyConnections = {}

local SpyToolbar = Instance.new("Frame")
SpyToolbar.Size = UDim2.new(1,0,0,30)
SpyToolbar.BackgroundColor3 = CFG.SecBG
SpyToolbar.BorderSizePixel = 0
SpyToolbar.Parent = SpyPanel
corner(SpyToolbar, 7)

local SpyToggleBtn = Instance.new("TextButton")
SpyToggleBtn.Text = "> Start Spy"
SpyToggleBtn.Size = UDim2.new(0,130,1,-8)
SpyToggleBtn.Position = UDim2.new(0,4,0,4)
SpyToggleBtn.BackgroundColor3 = CFG.Success
SpyToggleBtn.TextColor3 = Color3.new(1,1,1)
SpyToggleBtn.Font = Enum.Font.GothamBold
SpyToggleBtn.TextSize = 11
SpyToggleBtn.BorderSizePixel = 0
SpyToggleBtn.Parent = SpyToolbar
corner(SpyToggleBtn, 5)

local SpyClearBtn = Instance.new("TextButton")
SpyClearBtn.Text = "Clear Log"
SpyClearBtn.Size = UDim2.new(0,90,1,-8)
SpyClearBtn.Position = UDim2.new(0,138,0,4)
SpyClearBtn.BackgroundColor3 = CFG.Danger
SpyClearBtn.TextColor3 = Color3.new(1,1,1)
SpyClearBtn.Font = Enum.Font.GothamSemibold
SpyClearBtn.TextSize = 11
SpyClearBtn.BorderSizePixel = 0
SpyClearBtn.Parent = SpyToolbar
corner(SpyClearBtn, 5)

local SpyScroll = Instance.new("ScrollingFrame")
SpyScroll.Size = UDim2.new(1,0,1,-36)
SpyScroll.Position = UDim2.new(0,0,0,36)
SpyScroll.BackgroundColor3 = CFG.SecBG
SpyScroll.BorderSizePixel = 0
SpyScroll.ScrollBarThickness = 4
SpyScroll.ScrollBarImageColor3 = CFG.Accent
SpyScroll.CanvasSize = UDim2.new(0,0,0,0)
SpyScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
SpyScroll.Parent = SpyPanel
corner(SpyScroll, 7)

local SpyLayout = Instance.new("UIListLayout")
SpyLayout.SortOrder = Enum.SortOrder.LayoutOrder
SpyLayout.Padding = UDim.new(0,1)
SpyLayout.Parent = SpyScroll
pad(SpyScroll, 4, 4, 4, 4)

local spyOrder = 0
local function logSpy(msg, col)
    spyOrder = spyOrder + 1
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1,0,0,18)
    L.BackgroundTransparency = 1
    L.TextColor3 = col or CFG.Text
    L.Font = Enum.Font.Code
    L.TextSize = 10
    L.Text = msg
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.LayoutOrder = spyOrder
    L.Parent = SpyScroll
    task.defer(function()
        SpyScroll.CanvasPosition = Vector2.new(0, SpyScroll.AbsoluteCanvasSize.Y)
    end)
end

local function startSpy()
    for _, c in ipairs(spyConnections) do c:Disconnect() end
    spyConnections = {}
    local function watchGui(gui)
        for _, desc in ipairs(gui:GetDescendants()) do
            if desc:IsA("GuiButton") then
                table.insert(spyConnections, desc.MouseButton1Click:Connect(function()
                    logSpy("[CLICK]  " .. desc:GetFullName(), CFG.Success)
                end))
                table.insert(spyConnections, desc.MouseEnter:Connect(function()
                    logSpy("[HOVER]  " .. desc:GetFullName(), CFG.Warning)
                end))
            end
            if desc:IsA("TextBox") then
                table.insert(spyConnections, desc.FocusLost:Connect(function()
                    logSpy('[TEXTBOX] ' .. desc:GetFullName() .. ' -> "' .. truncate(desc.Text,20) .. '"', Color3.fromRGB(100,180,230))
                end))
            end
        end
    end
    for _, root in ipairs(getRoots(includeCoreGui)) do watchGui(root) end
    logSpy("--- Spy started ---", CFG.Accent)
end

SpyToggleBtn.MouseButton1Click:Connect(function()
    spyActive = not spyActive
    if spyActive then
        startSpy()
        SpyToggleBtn.Text = "[] Stop Spy"
        SpyToggleBtn.BackgroundColor3 = CFG.Danger
        setStatus("Event Spy active", CFG.Success)
    else
        for _, c in ipairs(spyConnections) do c:Disconnect() end
        spyConnections = {}
        logSpy("--- Spy stopped ---", CFG.Danger)
        SpyToggleBtn.Text = "> Start Spy"
        SpyToggleBtn.BackgroundColor3 = CFG.Success
        setStatus("Event Spy stopped", CFG.SubText)
    end
end)
SpyClearBtn.MouseButton1Click:Connect(function()
    for _, c in ipairs(SpyScroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    spyOrder = 0
end)

-- ============================================================
-- TAB 5: OVERLAY
-- ============================================================
local OvPanel = tabPanels["Overlay"]
local overlayActive = false
local overlayBox    = nil
local overlayConn   = nil

local OvToolbar = Instance.new("Frame")
OvToolbar.Size = UDim2.new(1,0,0,30)
OvToolbar.BackgroundColor3 = CFG.SecBG
OvToolbar.BorderSizePixel = 0
OvToolbar.Parent = OvPanel
corner(OvToolbar, 7)

local OvToggleBtn = Instance.new("TextButton")
OvToggleBtn.Text = "[+] Enable Overlay"
OvToggleBtn.Size = UDim2.new(0,150,1,-8)
OvToggleBtn.Position = UDim2.new(0,4,0,4)
OvToggleBtn.BackgroundColor3 = CFG.Accent
OvToggleBtn.TextColor3 = Color3.new(1,1,1)
OvToggleBtn.Font = Enum.Font.GothamBold
OvToggleBtn.TextSize = 11
OvToggleBtn.BorderSizePixel = 0
OvToggleBtn.Parent = OvToolbar
corner(OvToggleBtn, 5)

local OvInfo = Instance.new("TextLabel")
OvInfo.Size = UDim2.new(1,0,1,-36)
OvInfo.Position = UDim2.new(0,0,0,36)
OvInfo.BackgroundTransparency = 1
OvInfo.TextColor3 = CFG.SubText
OvInfo.Font = Enum.Font.Gotham
OvInfo.TextSize = 11
OvInfo.TextXAlignment = Enum.TextXAlignment.Left
OvInfo.TextWrapped = true
OvInfo.Text = "  Select an instance in the Explorer,\n  then enable the overlay to visualize\n  its position and size live on screen."
OvInfo.Parent = OvPanel

local function removeOverlay()
    if overlayBox  then overlayBox:Destroy();    overlayBox  = nil end
    if overlayConn then overlayConn:Disconnect(); overlayConn = nil end
end

local function activateOverlay(inst)
    removeOverlay()
    if not inst or not inst:IsA("GuiObject") then
        OvInfo.Text = "  WARNING: Select a valid GuiObject first."
        OvInfo.TextColor3 = CFG.Warning
        return
    end
    overlayBox = Instance.new("Frame")
    overlayBox.BackgroundColor3 = CFG.Accent
    overlayBox.BackgroundTransparency = 0.7
    overlayBox.BorderSizePixel = 0
    overlayBox.ZIndex = 999
    overlayBox.Parent = SG
    Instance.new("UIStroke", overlayBox).Color = CFG.Accent

    local OvLabel = Instance.new("TextLabel")
    OvLabel.BackgroundTransparency = 1
    OvLabel.TextColor3 = Color3.new(1,1,1)
    OvLabel.Font = Enum.Font.GothamBold
    OvLabel.TextSize = 10
    OvLabel.Size = UDim2.new(1,0,1,0)
    OvLabel.Parent = overlayBox

    overlayConn = RunService.RenderStepped:Connect(function()
        pcall(function()
            local abs = inst.AbsolutePosition
            local siz = inst.AbsoluteSize
            overlayBox.Position = UDim2.new(0,abs.X,0,abs.Y)
            overlayBox.Size     = UDim2.new(0,siz.X,0,siz.Y)
            OvLabel.Text = inst.Name.."\n"..math.floor(siz.X).."x"..math.floor(siz.Y)
            OvInfo.Text  = "  Pos: ("..math.floor(abs.X)..","..math.floor(abs.Y)..")\n"
                .."  Size: "..math.floor(siz.X).."x"..math.floor(siz.Y).."\n"
                .."  ZIndex: "..tostring(inst.ZIndex)
            OvInfo.TextColor3 = CFG.Text
        end)
    end)
end

OvToggleBtn.MouseButton1Click:Connect(function()
    overlayActive = not overlayActive
    if overlayActive then
        activateOverlay(selectedInst)
        OvToggleBtn.Text = "[-] Disable Overlay"
        OvToggleBtn.BackgroundColor3 = CFG.Danger
        setStatus("Overlay active", CFG.Success)
    else
        removeOverlay()
        OvToggleBtn.Text = "[+] Enable Overlay"
        OvToggleBtn.BackgroundColor3 = CFG.Accent
        OvInfo.Text = "  Overlay disabled."
        OvInfo.TextColor3 = CFG.SubText
        setStatus("Overlay disabled", CFG.SubText)
    end
end)

-- ============================================================
-- TAB 6: SETTINGS
-- ============================================================
local SetPanel = tabPanels["Settings"]

local function mkSettingRow(parent, label, desc, order)
    local R = Instance.new("Frame")
    R.Size = UDim2.new(1,0,0,46)
    R.BackgroundColor3 = CFG.TerBG
    R.BorderSizePixel = 0
    R.LayoutOrder = order
    R.Parent = parent
    corner(R, 7)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(0.6,0,0.5,0)
    L.BackgroundTransparency = 1
    L.TextColor3 = CFG.Text
    L.Font = Enum.Font.GothamSemibold
    L.TextSize = 12
    L.Text = "  "..label
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Parent = R
    local D = Instance.new("TextLabel")
    D.Size = UDim2.new(0.6,0,0.5,0)
    D.Position = UDim2.new(0,0,0.5,0)
    D.BackgroundTransparency = 1
    D.TextColor3 = CFG.SubText
    D.Font = Enum.Font.Gotham
    D.TextSize = 10
    D.Text = "  "..desc
    D.TextXAlignment = Enum.TextXAlignment.Left
    D.Parent = R
    return R
end

local SetScroll = Instance.new("ScrollingFrame")
SetScroll.Size = UDim2.new(1,0,1,0)
SetScroll.BackgroundTransparency = 1
SetScroll.BorderSizePixel = 0
SetScroll.ScrollBarThickness = 4
SetScroll.ScrollBarImageColor3 = CFG.Accent
SetScroll.CanvasSize = UDim2.new(0,0,0,0)
SetScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
SetScroll.Parent = SetPanel

local SetLayout = Instance.new("UIListLayout")
SetLayout.SortOrder = Enum.SortOrder.LayoutOrder
SetLayout.Padding = UDim.new(0,4)
SetLayout.Parent = SetScroll
pad(SetScroll,4,4,4,4)

local function mkActionBtn(parent, label, col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.35,0,0.6,0)
    b.Position = UDim2.new(0.63,0,0.2,0)
    b.BackgroundColor3 = col
    b.TextColor3 = col == CFG.Warning and Color3.fromRGB(20,20,20) or Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Text = label
    b.BorderSizePixel = 0
    b.Parent = parent
    corner(b, 6)
    return b
end

-- Auto-Refresh
do
    local autoRefresh = false
    local R = mkSettingRow(SetScroll, "Auto-Refresh Explorer", "Refreshes the tree every 2 seconds", 1)
    local Btn = mkActionBtn(R, "OFF", CFG.TerBG)
    Btn.TextColor3 = CFG.SubText
    Btn.MouseButton1Click:Connect(function()
        autoRefresh = not autoRefresh
        if autoRefresh then
            Btn.Text = "ON"; Btn.BackgroundColor3 = CFG.Success; Btn.TextColor3 = Color3.new(1,1,1)
            task.spawn(function()
                while autoRefresh do task.wait(2); if activeTab=="Explorer" then refreshExplorer() end end
            end)
        else
            Btn.Text = "OFF"; Btn.BackgroundColor3 = CFG.TerBG; Btn.TextColor3 = CFG.SubText
        end
    end)
end

-- Toggle Visibility
do
    local R = mkSettingRow(SetScroll, "Toggle Visibility", "Show/hide selected instance", 2)
    local Btn = mkActionBtn(R, "Toggle", CFG.Accent)
    Btn.MouseButton1Click:Connect(function()
        if selectedInst and selectedInst:IsA("GuiObject") then
            pcall(function()
                selectedInst.Visible = not selectedInst.Visible
                setStatus("Visible -> " .. tostring(selectedInst.Visible), CFG.Warning)
                showProperties(selectedInst); refreshEditPanel(selectedInst)
            end)
        elseif selectedInst and selectedInst:IsA("ScreenGui") then
            pcall(function()
                selectedInst.Enabled = not selectedInst.Enabled
                setStatus("Enabled -> " .. tostring(selectedInst.Enabled), CFG.Warning)
            end)
        else
            setStatus("Select an instance first!", CFG.Danger)
        end
    end)
end

-- Print Full Path
do
    local R = mkSettingRow(SetScroll, "Print Full Path", "Prints full path to output console", 3)
    local Btn = mkActionBtn(R, "Print", CFG.Warning)
    Btn.MouseButton1Click:Connect(function()
        if selectedInst then
            local path = selectedInst:GetFullName()
            print("[GUI Explorer] " .. path)
            setStatus("Path: " .. truncate(path,40), CFG.Success)
        else
            setStatus("Select an instance first!", CFG.Danger)
        end
    end)
end

-- Count Descendants
do
    local R = mkSettingRow(SetScroll, "Count Descendants", "Counts all recursive children", 4)
    local Btn = mkActionBtn(R, "Count", Color3.fromRGB(60,130,200))
    Btn.MouseButton1Click:Connect(function()
        if selectedInst then
            local n = #selectedInst:GetDescendants()
            setStatus(selectedInst.Name .. " has " .. n .. " descendants", CFG.Success)
            print("[GUI Explorer] Descendants of " .. selectedInst.Name .. ": " .. n)
        else
            setStatus("Select an instance first!", CFG.Danger)
        end
    end)
end

-- Highlight Flash
do
    local R = mkSettingRow(SetScroll, "Highlight Flash", "Flashes the selected element on screen", 5)
    local Btn = mkActionBtn(R, "Flash", Color3.fromRGB(200,80,160))
    Btn.MouseButton1Click:Connect(function()
        if selectedInst and selectedInst:IsA("GuiObject") then
            pcall(function()
                local orig  = selectedInst.BackgroundColor3
                local origT = selectedInst.BackgroundTransparency
                for _ = 1, 4 do
                    task.wait(0.1)
                    selectedInst.BackgroundColor3 = Color3.fromRGB(200,80,160)
                    selectedInst.BackgroundTransparency = 0.3
                    task.wait(0.1)
                    selectedInst.BackgroundColor3 = orig
                    selectedInst.BackgroundTransparency = origT
                end
            end)
            setStatus("Flash: " .. selectedInst.Name, Color3.fromRGB(200,80,160))
        else
            setStatus("Select a GuiObject first!", CFG.Danger)
        end
    end)
end

-- ============================================================
-- INIT
-- ============================================================
switchTab("Explorer")
refreshExplorer()
setStatus("Universal GUI Explorer v2.2 loaded!", CFG.Success)
print("[Universal GUI Explorer v2.2] Loaded successfully.")
print("  cloneref: " .. (cloneref and "available" or "fallback used"))
print("  Tabs: Explorer | Properties | Edit | Spy | Overlay | Settings")
