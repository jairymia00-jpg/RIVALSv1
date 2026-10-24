-- Arsenal: Nightfall v2 | client-side menu
-- F1 menu | F2 smooth head lock | F10 unload
-- The on-screen AIM button also toggles aim on mouse and touch.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer
assert(LP, "Run this on the client")
local PlayerGui = LP:WaitForChild("PlayerGui")
local ART_ASSET_ID = 0

if type(_G.ArsenalNightfallStop) == "function" then pcall(_G.ArsenalNightfallStop) end
local previous = PlayerGui:FindFirstChild("Arsenal_Nightfall")
if previous then previous:Destroy() end

local C = {
    ESP = true, Allies = false, Boxes = true, Health = true, Names = true,
    Distance = true, Outlines = true, Skeleton = false, Tracers = false,
    FOV = true, Indicator = true, Headshot = true, Aim = false,
    Sticky = true, NPCs = false,
    UnknownEnemy = false, CheckSight = true, Radius = 150, Range = 2500,
    AimSpeed = 11,
}
local COL = {
    bg = Color3.fromRGB(14, 9, 13), card = Color3.fromRGB(28, 18, 24),
    raised = Color3.fromRGB(57, 16, 23), accent = Color3.fromRGB(255, 45, 70),
    text = Color3.fromRGB(250, 241, 243), muted = Color3.fromRGB(172, 152, 158),
    good = Color3.fromRGB(110, 230, 170), enemy = Color3.fromRGB(255, 66, 80),
    ally = Color3.fromRGB(75, 170, 255),
}
local ACCENTS = {
    Color3.fromRGB(255, 45, 70), Color3.fromRGB(255, 90, 150),
    Color3.fromRGB(170, 110, 255), Color3.fromRGB(110, 190, 255),
    Color3.fromRGB(225, 225, 240), Color3.fromRGB(255, 170, 60),
}
local running, connections, overlays, npcHumanoids = true, {}, {}, {}
local bestTarget, bestName, bestDistance, bestPlayer = nil, nil, nil, nil
local aimReason, aimWrites, engineName = "OFF", 0, "CAMERA"
local aimCounts = {inside = 0, clear = 0, blocked = 0, unknown = 0, allies = 0}
local lockedHead, lockedPlayer = nil, nil
local renderName, aimName = "ArsenalNightfall_Render", "ArsenalNightfall_Aim"
local accentBinds, accentFns = {}, {}

local function make(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do obj[key] = value end
    obj.Parent = parent
    return obj
end
local function corner(obj, r)
    make("UICorner", {CornerRadius = UDim.new(0, r or 8)}, obj)
end
local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end
local function show(obj, on)
    if obj.Visible ~= on then obj.Visible = on end
end
local function tween(obj, props, duration)
    if obj and obj.Parent then
        TweenService:Create(obj, TweenInfo.new(duration or .18, Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out), props):Play()
    end
end
local function label(parent, value, pos, size, color, font, textSize, align)
    return make("TextLabel", {BackgroundTransparency = 1, Text = value,
        Position = pos, Size = size, TextColor3 = color or COL.text,
        Font = font or Enum.Font.GothamMedium, TextSize = textSize or 12,
        TextXAlignment = align or Enum.TextXAlignment.Left}, parent)
end
local function bindAccent(obj, prop)
    obj[prop] = COL.accent
    table.insert(accentBinds, {obj, prop})
end
local function line(parent, width, color)
    return make("Frame", {AnchorPoint = Vector2.new(.5, .5),
        Size = UDim2.fromOffset(width, 1), BorderSizePixel = 0,
        BackgroundColor3 = color, Visible = false}, parent)
end
local function placeLine(obj, a, b, width)
    local dx, dy = b.X - a.X, b.Y - a.Y
    obj.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    obj.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), width)
    obj.Rotation = math.deg(math.atan2(dy, dx))
    show(obj, true)
end

local gui = make("ScreenGui", {Name = "Arsenal_Nightfall", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 1000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, PlayerGui)
local menu = make("Frame", {Size = UDim2.fromOffset(752, 540),
    Position = UDim2.fromScale(.5, .5), AnchorPoint = Vector2.new(.5, .5),
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    Active = true, ClipsDescendants = true}, gui)
corner(menu, 18)
make("UIGradient", {Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(46, 10, 22)),
    ColorSequenceKeypoint.new(.55, Color3.fromRGB(22, 10, 18)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 8, 14)),
}), Rotation = 125}, menu)
local border = make("UIStroke", {Thickness = 1.4, Transparency = .35}, menu)
bindAccent(border, "Color")
TweenService:Create(border, TweenInfo.new(1.8, Enum.EasingStyle.Sine,
    Enum.EasingDirection.InOut, -1, true), {Transparency = .75}):Play()

-- Decorative petals use one tween per petal, and stop when the GUI is removed.
local function petal(delaySeconds)
    local p = make("Frame", {Size = UDim2.fromOffset(7, 11),
        BackgroundColor3 = Color3.fromRGB(255, 60, 85),
        BackgroundTransparency = .35, BorderSizePixel = 0}, menu)
    corner(p, 5)
    task.spawn(function()
        task.wait(delaySeconds)
        while running and p.Parent do
            local x, duration = math.random(20, 730), math.random(60, 100) / 10
            p.Position, p.Rotation = UDim2.fromOffset(x, -20), math.random(0, 180)
            local motion = TweenService:Create(p, TweenInfo.new(duration,
                Enum.EasingStyle.Linear), {Position = UDim2.fromOffset(
                    x + math.random(-80, 80), 560),
                    Rotation = p.Rotation + math.random(180, 400)})
            motion:Play()
            motion.Completed:Wait()
        end
    end)
end
for i = 1, 9 do petal(i * .9) end

local function fitScale()
    local camera = workspace.CurrentCamera
    if not camera then return 1 end
    local view = camera.ViewportSize
    return math.max(.2, math.min(1, (view.X - 24) / 752, (view.Y - 24) / 540))
end
local fit = fitScale()
local scale = make("UIScale", {Scale = fit * .9}, menu)
tween(scale, {Scale = fit}, .3)
local viewportConnection
local function watchCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
            fit = fitScale()
            tween(scale, {Scale = fit}, .2)
        end)
    end
    fit = fitScale()
    tween(scale, {Scale = fit}, .2)
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
watchCamera()

local topBar = make("Frame", {Size = UDim2.new(1, 0, 0, 3),
    BorderSizePixel = 0}, menu)
bindAccent(topBar, "BackgroundColor3")
local dragArea = make("Frame", {Size = UDim2.new(1, -70, 0, 72),
    BackgroundTransparency = 1, Active = true}, menu)
label(menu, "ARSENAL  /  NIGHTFALL V2", UDim2.fromOffset(18, 10),
    UDim2.fromOffset(480, 38), COL.text, Enum.Font.GothamBlack, 19)
label(menu, "F1 MENU   /   F2 AIM   /   F10 UNLOAD",
    UDim2.fromOffset(19, 48), UDim2.fromOffset(500, 20),
    COL.muted, Enum.Font.Gotham, 10)
local closeBtn = make("TextButton", {Text = "×",
    Position = UDim2.new(1, -49, 0, 13), Size = UDim2.fromOffset(32, 31),
    BackgroundColor3 = COL.card, BorderSizePixel = 0,
    TextColor3 = COL.text, Font = Enum.Font.GothamBold,
    TextSize = 20, AutoButtonColor = false, ZIndex = 3}, menu)
corner(closeBtn, 10)
connect(closeBtn.MouseEnter, function()
    tween(closeBtn, {BackgroundColor3 = COL.raised}, .12)
end)
connect(closeBtn.MouseLeave, function()
    tween(closeBtn, {BackgroundColor3 = COL.card}, .12)
end)

local rail = make("Frame", {Position = UDim2.fromOffset(12, 81),
    Size = UDim2.fromOffset(144, 405), BackgroundColor3 = COL.card,
    BackgroundTransparency = .35, BorderSizePixel = 0}, menu)
corner(rail, 14)
make("UIStroke", {Color = Color3.new(1, 1, 1), Transparency = .88}, rail)
local logo = label(rail, "AR", UDim2.fromOffset(14, 15),
    UDim2.fromOffset(45, 40), COL.text, Enum.Font.GothamBlack,
    22, Enum.TextXAlignment.Center)
logo.BackgroundTransparency = 0
logo.BorderSizePixel = 0
corner(logo, 12)
bindAccent(logo, "BackgroundColor3")
label(rail, "PRIVATE\nTOOLS", UDim2.fromOffset(67, 15),
    UDim2.fromOffset(65, 40), COL.muted, Enum.Font.GothamBold, 10)
local selectedBg = make("Frame", {Position = UDim2.fromOffset(8, 76),
    Size = UDim2.fromOffset(128, 41), BackgroundColor3 = COL.raised,
    BorderSizePixel = 0}, rail)
corner(selectedBg, 10)
local selectedBar = make("Frame", {Position = UDim2.fromOffset(8, 80),
    Size = UDim2.fromOffset(3, 33), BorderSizePixel = 0}, rail)
bindAccent(selectedBar, "BackgroundColor3")
local aimChip = label(rail, "AIM  OFF", UDim2.fromOffset(11, 371),
    UDim2.fromOffset(122, 23), COL.good, Enum.Font.GothamBold,
    10, Enum.TextXAlignment.Center)
aimChip.BackgroundTransparency = 0
aimChip.BackgroundColor3 = COL.raised
corner(aimChip, 11)

local card = make("Frame", {Position = UDim2.fromOffset(166, 81),
    Size = UDim2.fromOffset(347, 405), BackgroundColor3 = COL.card,
    BackgroundTransparency = .35, BorderSizePixel = 0}, menu)
corner(card, 14)
make("UIStroke", {Color = Color3.new(1, 1, 1), Transparency = .88}, card)
local pageTitle = label(card, "AIM", UDim2.fromOffset(14, 9),
    UDim2.fromOffset(300, 27), COL.text, Enum.Font.GothamBold, 18)
local pageInfo = label(card, "TARGET ACQUISITION", UDim2.fromOffset(14, 36),
    UDim2.fromOffset(300, 18), COL.muted, Enum.Font.Gotham, 10)

local art = make("Frame", {Position = UDim2.fromOffset(523, 81),
    Size = UDim2.fromOffset(217, 405), BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0, ClipsDescendants = true}, menu)
corner(art, 14)
make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(70, 12, 26),
    Color3.fromRGB(16, 9, 13)), Rotation = 70,
    Transparency = NumberSequence.new(.45, .2)}, art)
local artStroke = make("UIStroke", {Transparency = .5}, art)
bindAccent(artStroke, "Color")
local artImage = make("ImageLabel", {Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
    Visible = false}, art)
local artHint = label(art, "ARSENAL\nNIGHTFALL",
    UDim2.fromOffset(12, 155), UDim2.fromOffset(193, 45),
    COL.text, Enum.Font.GothamBold, 11, Enum.TextXAlignment.Center)
artHint.TextTransparency = .25
local artFooter = label(art, "ARSENAL  /  NIGHTFALL V2",
    UDim2.new(0, 0, 1, -33), UDim2.new(1, 0, 0, 33),
    COL.text, Enum.Font.GothamBold, 10, Enum.TextXAlignment.Center)
artFooter.BackgroundTransparency = .2
artFooter.BackgroundColor3 = COL.bg
local function setArt(id)
    if id and tonumber(id) and tonumber(id) > 0 then
        artImage.Image = "rbxassetid://" .. tostring(id)
        artImage.Visible, artHint.Visible = true, false
    else artImage.Visible, artHint.Visible = false, true end
end
setArt(ART_ASSET_ID)

local status = label(menu, "Starting...", UDim2.new(0, 16, 1, -45),
    UDim2.new(1, -32, 0, 36), COL.muted, Enum.Font.Gotham, 11)
status.TextWrapped = true
local circle = make("Frame", {AnchorPoint = Vector2.new(.5, .5),
    BackgroundTransparency = 1, Visible = true}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, circle)
local circleStroke = make("UIStroke", {Color = COL.accent,
    Thickness = 1.5, Transparency = .2}, circle)
local indicator = make("TextLabel", {AnchorPoint = Vector2.new(.5, 0),
    Size = UDim2.fromOffset(250, 25), BackgroundColor3 = COL.card,
    BorderSizePixel = 0, TextColor3 = COL.text,
    Font = Enum.Font.GothamBold, TextSize = 11, Visible = false}, gui)
corner(indicator, 6)
local quickToggle = make("TextButton", {
    Name = "AimToggle", Text = "AIM OFF  •  F2",
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 72),
    Size = UDim2.fromOffset(124, 34), BackgroundColor3 = COL.card,
    BorderSizePixel = 0, TextColor3 = COL.muted,
    Font = Enum.Font.GothamBold, TextSize = 11,
    AutoButtonColor = false,
}, gui)
corner(quickToggle, 9)
make("UIStroke", {Color = COL.accent, Transparency = .55, Thickness = 1}, quickToggle)
local menuToggle = make("TextButton", {
    Name = "MenuToggle", Text = "MENU",
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -148, 0, 72),
    Size = UDim2.fromOffset(58, 34), BackgroundColor3 = COL.card,
    BorderSizePixel = 0, TextColor3 = COL.text,
    Font = Enum.Font.GothamBold, TextSize = 11,
    AutoButtonColor = false,
}, gui)
corner(menuToggle, 9)

local noticeHolder = make("Frame", {Size = UDim2.fromOffset(280, 400),
    Position = UDim2.new(1, -16, 0, 16), AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1}, gui)
make("UIListLayout", {Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    SortOrder = Enum.SortOrder.LayoutOrder}, noticeHolder)

local Window = {}
local tabs, keybinds = {}, {}
local active = true
local listening = nil
local function setAccent(color)
    COL.accent = color
    COL.raised = color:Lerp(COL.bg, .82)
    for _, binding in ipairs(accentBinds) do
        if binding[1]:IsDescendantOf(gui) then
            tween(binding[1], {[binding[2]] = color}, .25)
        end
    end
    selectedBg.BackgroundColor3 = COL.raised
    aimChip.BackgroundColor3 = COL.raised
    for _, fn in ipairs(accentFns) do fn() end
end
function Window:SetAccent(color) setAccent(color) end
function Window:SetArt(id) setArt(id) end
function Window:SetStatus(value) status.Text = value end
function Window:SetChip(value, color)
    aimChip.Text, aimChip.TextColor3 = value, color or COL.good
end
function Window:Notify(title, body, duration)
    if not running then return end
    local wrapper = make("Frame", {Size = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1}, noticeHolder)
    local item = make("Frame", {Size = UDim2.fromScale(1, 1),
        Position = UDim2.new(1, 40, 0, 0), BackgroundColor3 = COL.card,
        BorderSizePixel = 0}, wrapper)
    corner(item, 10)
    local stroke = make("UIStroke", {Color = COL.accent, Transparency = .5}, item)
    bindAccent(stroke, "Color")
    label(item, title, UDim2.fromOffset(14, 8),
        UDim2.new(1, -25, 0, 19), COL.text, Enum.Font.GothamBold, 13)
    label(item, body or "", UDim2.fromOffset(14, 29),
        UDim2.new(1, -25, 0, 18), COL.muted, Enum.Font.Gotham, 11)
    tween(item, {Position = UDim2.fromOffset(0, 0)}, .35)
    task.delay(duration or 3, function()
        if not wrapper.Parent then return end
        tween(item, {Position = UDim2.new(1, 40, 0, 0)}, .25)
        task.wait(.3)
        if wrapper.Parent then wrapper:Destroy() end
    end)
end
function Window:SetVisible(on)
    active = on
    if on then
        menu.Visible = true
        scale.Scale = fit * .94
        tween(scale, {Scale = fit}, .22)
    else
        tween(scale, {Scale = fit * .94}, .15)
        task.delay(.16, function()
            if not active and menu.Parent then menu.Visible = false end
        end)
    end
end
function Window:Toggle() self:SetVisible(not active) end
function Window:Destroy()
    if type(_G.ArsenalNightfallStop) == "function" then _G.ArsenalNightfallStop()
    else gui:Destroy() end
end
connect(closeBtn.MouseButton1Click, function() Window:SetVisible(false) end)
connect(menuToggle.MouseButton1Click, function() Window:Toggle() end)

-- Mouse and touch drag use the same input object until it ends.
local dragInput, dragStart, menuStart
connect(dragArea.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput, dragStart, menuStart = input, input.Position, menu.Position
    end
end)
connect(UIS.InputChanged, function(input)
    if not dragInput then return end
    if input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = input.Position - dragStart
        menu.Position = UDim2.new(menuStart.X.Scale, menuStart.X.Offset + d.X,
            menuStart.Y.Scale, menuStart.Y.Offset + d.Y)
    end
end)
connect(UIS.InputEnded, function(input)
    if input == dragInput then dragInput = nil end
end)

local TAB_Y, TAB_STEP = 76, 49
local function selectTab(tab, immediate)
    pageTitle.Text, pageInfo.Text = string.upper(tab.name), string.upper(tab.info)
    for _, other in ipairs(tabs) do
        local selected = other == tab
        other.page.Visible = selected
        tween(other.button, {TextColor3 = selected and COL.text or COL.muted},
            immediate and 0 or .18)
    end
    local y = TAB_Y + (tab.index - 1) * TAB_STEP
    if immediate then
        selectedBg.Position = UDim2.fromOffset(8, y)
        selectedBar.Position = UDim2.fromOffset(8, y + 4)
    else
        tween(selectedBg, {Position = UDim2.fromOffset(8, y)}, .25)
        tween(selectedBar, {Position = UDim2.fromOffset(8, y + 4)}, .25)
    end
end
function Window:AddTab(name, info)
    local index = #tabs + 1
    local button = make("TextButton", {Text = "  " .. string.upper(name),
        Position = UDim2.fromOffset(8, TAB_Y + (index - 1) * TAB_STEP),
        Size = UDim2.fromOffset(128, 41), TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, TextColor3 = COL.muted,
        Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
        ZIndex = 2}, rail)
    local page = make("ScrollingFrame", {Position = UDim2.fromOffset(13, 61),
        Size = UDim2.new(1, -25, 1, -73), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 5,
        CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollingEnabled = true, Visible = false}, card)
    bindAccent(page, "ScrollBarImageColor3")
    local layout = make("UIListLayout", {Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder}, page)
    make("UIPadding", {PaddingRight = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8)}, page)
    connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
    end)
    local tab = {button = button, page = page, index = index,
        name = name, info = info or ""}
    table.insert(tabs, tab)
    connect(button.MouseButton1Click, function() selectTab(tab) end)
    if index == 1 then selectTab(tab, true) end

    local function row(height)
        local frame = make("Frame", {Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = COL.bg, BackgroundTransparency = .3,
            BorderSizePixel = 0}, page)
        corner(frame, 10)
        return frame
    end
    function tab:AddLabel(value)
        local frame = row(28)
        label(frame, value, UDim2.fromOffset(10, 0),
            UDim2.new(1, -20, 1, 0), COL.muted, Enum.Font.Gotham, 11)
    end
    function tab:AddButton(value, callback)
        local frame = row(35)
        local hit = make("TextButton", {Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, Text = value,
            TextColor3 = COL.text, Font = Enum.Font.GothamMedium,
            TextSize = 12}, frame)
        connect(hit.MouseButton1Click, function()
            frame.BackgroundColor3 = COL.accent
            tween(frame, {BackgroundColor3 = COL.bg}, .35)
            if callback then task.spawn(callback) end
        end)
    end
    function tab:AddToggle(value, initial, callback)
        local state = initial == true
        local frame = row(35)
        local txt = label(frame, value, UDim2.fromOffset(10, 0),
            UDim2.new(1, -70, 1, 0), COL.text)
        local flag = make("TextLabel", {Position = UDim2.new(1, -51, .5, -11),
            Size = UDim2.fromOffset(42, 22), BorderSizePixel = 0,
            Font = Enum.Font.GothamBold, TextSize = 10}, frame)
        corner(flag, 11)
        local function paint(animate)
            local speed = animate and .18 or 0
            tween(frame, {BackgroundColor3 = state and COL.raised or COL.bg}, speed)
            tween(txt, {TextColor3 = state and COL.text or COL.muted}, speed)
            tween(flag, {BackgroundColor3 = state and COL.accent or COL.card,
                TextColor3 = state and COL.text or COL.muted}, speed)
            flag.Text = state and "ON" or "OFF"
        end
        paint(false)
        table.insert(accentFns, function() paint(true) end)
        local hit = make("TextButton", {Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, Text = ""}, frame)
        connect(hit.MouseButton1Click, function()
            state = not state
            paint(true)
            if callback then callback(state) end
        end)
        return {Set = function(_, on)
            state = on == true
            paint(true)
            if callback then callback(state) end
        end}
    end
    function tab:AddSlider(value, low, high, initial, callback, step)
        step = step or 1
        local current = initial or low
        local frame = row(52)
        label(frame, value, UDim2.fromOffset(10, 6),
            UDim2.new(1, -90, 0, 20), COL.text)
        local valueLabel = label(frame, tostring(current),
            UDim2.new(1, -72, 0, 6), UDim2.fromOffset(62, 20),
            COL.muted, Enum.Font.Gotham, 11, Enum.TextXAlignment.Right)
        local bar = make("Frame", {Size = UDim2.new(1, -20, 0, 6),
            Position = UDim2.fromOffset(10, 34), BackgroundColor3 = COL.card,
            BorderSizePixel = 0, Active = true}, frame)
        corner(bar, 3)
        local fill = make("Frame", {Size = UDim2.fromScale((current - low) / (high - low), 1),
            BorderSizePixel = 0}, bar)
        corner(fill, 3)
        bindAccent(fill, "BackgroundColor3")
        local knob = make("Frame", {Size = UDim2.fromOffset(12, 12),
            AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(1, .5),
            BackgroundColor3 = COL.text, BorderSizePixel = 0}, fill)
        corner(knob, 6)
        local dragging, touchInput = false, nil
        local function update(x)
            if bar.AbsoluteSize.X <= 0 then return end
            local amount = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            current = math.clamp(low + math.floor((high - low) * amount / step + .5) * step,
                low, high)
            tween(fill, {Size = UDim2.fromScale((current - low) / (high - low), 1)}, .08)
            valueLabel.Text = step < 1 and string.format("%.2f", current) or tostring(current)
            if callback then callback(current) end
        end
        connect(bar.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging, touchInput = true, input.UserInputType == Enum.UserInputType.Touch
                    and input or nil
                update(input.Position.X)
            end
        end)
        connect(UIS.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input == touchInput then dragging, touchInput = false, nil end
        end)
        connect(UIS.InputChanged, function(input)
            if dragging and (input == touchInput
                or (not touchInput and input.UserInputType == Enum.UserInputType.MouseMovement)) then
                update(input.Position.X)
            end
        end)
    end
    function tab:AddDropdown(value, options, initial, callback)
        local current = initial or options[1]
        local frame = row(35)
        frame.ClipsDescendants = true
        label(frame, value, UDim2.fromOffset(10, 0),
            UDim2.new(.48, 0, 0, 35), COL.text)
        local choice = label(frame, tostring(current) .. "  ▾",
            UDim2.new(.42, 0, 0, 0), UDim2.new(.58, -10, 0, 35),
            COL.muted, Enum.Font.Gotham, 11, Enum.TextXAlignment.Right)
        local opened = false
        local function setOpen(on)
            opened = on
            tween(frame, {Size = UDim2.new(1, 0, 0,
                on and (41 + #options * 28) or 35)}, .22)
        end
        local header = make("TextButton", {Size = UDim2.new(1, 0, 0, 35),
            BackgroundTransparency = 1, Text = ""}, frame)
        connect(header.MouseButton1Click, function() setOpen(not opened) end)
        for i, option in ipairs(options) do
            local selected = option
            local item = make("TextButton", {Size = UDim2.new(1, -16, 0, 26),
                Position = UDim2.fromOffset(8, 35 + (i - 1) * 28),
                BackgroundColor3 = COL.card, Text = option, TextColor3 = COL.text,
                Font = Enum.Font.Gotham, TextSize = 11, AutoButtonColor = false}, frame)
            corner(item, 8)
            connect(item.MouseButton1Click, function()
                current, choice.Text = selected, selected .. "  ▾"
                setOpen(false)
                if callback then callback(selected) end
            end)
        end
    end
    function tab:AddKeybind(value, key, callback)
        local entry = {key = key, callback = callback}
        table.insert(keybinds, entry)
        local frame = row(35)
        label(frame, value, UDim2.fromOffset(10, 0),
            UDim2.new(1, -120, 1, 0), COL.text)
        local button = make("TextButton", {Size = UDim2.fromOffset(96, 23),
            Position = UDim2.new(1, -106, .5, -11),
            BackgroundColor3 = COL.card, Text = key.Name,
            TextColor3 = COL.muted, Font = Enum.Font.GothamBold,
            TextSize = 10, AutoButtonColor = false}, frame)
        corner(button, 11)
        connect(button.MouseButton1Click, function()
            listening = entry
            button.Text = "PRESS A KEY..."
            tween(button, {BackgroundColor3 = COL.accent, TextColor3 = COL.text})
        end)
        entry.paint = function()
            button.Text = entry.key.Name
            tween(button, {BackgroundColor3 = COL.card, TextColor3 = COL.muted})
        end
        return entry
    end
    function tab:AddAccentPicker(value)
        local frame = row(64)
        label(frame, value or "Accent color", UDim2.fromOffset(10, 6),
            UDim2.new(1, -20, 0, 20), COL.text)
        for i, color in ipairs(ACCENTS) do
            local x = 10 + (i - 1) * 36
            local swatch = make("TextButton", {Size = UDim2.fromOffset(28, 28),
                Position = UDim2.fromOffset(x, 28), BackgroundColor3 = color,
                Text = "", AutoButtonColor = false}, frame)
            corner(swatch, 14)
            connect(swatch.MouseButton1Click, function() setAccent(color) end)
        end
    end
    return tab
end

local aimTab = Window:AddTab("Aim", "Target acquisition")
local aimToggle = aimTab:AddToggle("Smooth head lock", C.Aim, function(v)
    C.Aim = v
    quickToggle.Text = v and "AIM ON  •  F2" or "AIM OFF  •  F2"
    quickToggle.TextColor3 = v and COL.good or COL.muted
    quickToggle.BackgroundColor3 = v and COL.raised or COL.card
end)
connect(quickToggle.MouseButton1Click, function()
    aimToggle:Set(not C.Aim)
end)
aimTab:AddToggle("Require visible head", C.CheckSight,
    function(v) C.CheckSight = v end)
aimTab:AddSlider("FOV radius", 75, 400, C.Radius,
    function(v) C.Radius = v end, 5)
aimTab:AddSlider("Tracking speed", 4, 24, C.AimSpeed,
    function(v) C.AimSpeed = v end, 1)

local relativeMouse = type(mousemoverel) == "function" and mousemoverel or nil
if not relativeMouse and type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" and type(env.mousemoverel) == "function" then
        relativeMouse = env.mousemoverel
    end
end
local visualsTab = Window:AddTab("Visuals", "Player overlays")
for _, option in ipairs({
    {"Enemy ESP", "ESP"}, {"Show allies", "Allies"},
    {"2D boxes", "Boxes"}, {"Health bars", "Health"},
    {"Names", "Names"}, {"Distance", "Distance"},
    {"Character outlines", "Outlines"}, {"Skeleton", "Skeleton"},
    {"Tracers", "Tracers"}, {"FOV circle", "FOV"},
    {"Target indicator", "Indicator"}, {"Head aligned hint", "Headshot"},
}) do
    local key = option[2]
    visualsTab:AddToggle(option[1], C[key], function(v) C[key] = v end)
end

local worldTab = Window:AddTab("World", "World and team filters")
local function scanNPCs()
    task.spawn(function()
        for i, obj in ipairs(workspace:GetDescendants()) do
            if not running or not C.NPCs then return end
            if obj:IsA("Humanoid") and obj.Parent:IsA("Model") then
                npcHumanoids[obj] = true
            end
            if i % 400 == 0 then task.wait() end
        end
    end)
end
worldTab:AddToggle("Include NPC humanoids", C.NPCs, function(v)
    C.NPCs = v
    if v then scanNPCs() end
end)
worldTab:AddToggle("Unknown teams as enemies", C.UnknownEnemy,
    function(v) C.UnknownEnemy = v end)
worldTab:AddSlider("ESP range", 500, 5000, C.Range,
    function(v) C.Range = v end, 100)

local bindsTab = Window:AddTab("Binds", "Hotkey configuration")
bindsTab:AddKeybind("Hide / show menu", Enum.KeyCode.F1,
    function() Window:Toggle() end)
bindsTab:AddKeybind("Smooth head lock", Enum.KeyCode.F2,
    function() aimToggle:Set(not C.Aim) end)
bindsTab:AddAccentPicker("Accent color")
bindsTab:AddLabel("F10 unloads this script. Click a key box to rebind.")
bindsTab:AddButton("Unload Arsenal Nightfall", function() Window:Destroy() end)

local function inputButton(input)
    if input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode end
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2
        or t == Enum.UserInputType.MouseButton3 then return t end
    return nil
end
connect(UIS.InputBegan, function(input, processed)
    local pressed = inputButton(input)
    if listening then
        if pressed and pressed ~= Enum.KeyCode.F10
            and pressed ~= Enum.KeyCode.Escape then
            local old = listening.key
            for _, other in ipairs(keybinds) do
                if other ~= listening and other.key == pressed then
                    other.key = old
                    other.paint()
                end
            end
            listening.key = pressed
            listening.paint()
            listening = nil
        elseif pressed == Enum.KeyCode.Escape then
            listening.paint()
            listening = nil
        end
        return
    end
    if UIS:GetFocusedTextBox() or processed then return end
    if pressed == Enum.KeyCode.F10 then Window:Destroy(); return end
    for _, binding in ipairs(keybinds) do
        if pressed == binding.key then binding.callback(); return end
    end
end)

-- Optional: upload artwork to Roblox and set ART_ASSET_ID above.

-- Backend begins below: player/NPC filtering, ESP, and head acquisition.
local bonesR15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
}
local bonesR6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local function removeOverlay(model)
    local o = overlays[model]
    if not o then return end
    o.box:Destroy()
    o.name:Destroy()
    o.distance:Destroy()
    o.barBG:Destroy()
    o.tracer:Destroy()
    for _, segment in ipairs(o.bones) do segment:Destroy() end
    if o.highlight then o.highlight:Destroy() end
    overlays[model] = nil
end

local function createOverlay(model)
    local box = make("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
    }, gui)
    local stroke = make("UIStroke", {Color = COL.enemy, Thickness = 1.5}, box)
    local name = make("TextLabel", {
        BackgroundTransparency = 1, TextColor3 = COL.text, TextStrokeTransparency = .25,
        Font = Enum.Font.GothamBold, TextSize = 12, Visible = false,
    }, gui)
    local distance = make("TextLabel", {
        BackgroundTransparency = 1, TextColor3 = COL.muted, TextStrokeTransparency = .2,
        Font = Enum.Font.Gotham, TextSize = 10, Visible = false,
    }, gui)
    local barBG = make("Frame", {
        BackgroundColor3 = COL.card, BorderSizePixel = 0, Visible = false,
    }, gui)
    local fill = make("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
        BackgroundColor3 = COL.good,
    }, barBG)
    local tracer = line(gui, 1, COL.enemy)
    local bones = {}
    for i = 1, #bonesR15 do bones[i] = line(gui, 1, COL.enemy) end
    local o = {box = box, stroke = stroke, name = name, distance = distance,
        barBG = barBG, fill = fill, tracer = tracer, bones = bones, highlight = nil}
    overlays[model] = o
    return o
end
local function hideOverlay(o)
    show(o.box, false); show(o.name, false); show(o.distance, false)
    show(o.barBG, false); show(o.tracer, false)
    for _, segment in ipairs(o.bones) do show(segment, false) end
    if o.highlight then o.highlight.Enabled = false end
end

local function relation(player, model)
    if player then
        if player == LP then return "self" end
        if LP.Team and player.Team then
            return LP.Team == player.Team and "ally" or "enemy"
        end
        local ours, theirs = LP:GetAttribute("Team"), player:GetAttribute("Team")
        if ours ~= nil and theirs ~= nil then
            return tostring(ours) == tostring(theirs) and "ally" or "enemy"
        end
        -- TeamColor defaults can match in free-for-all games even though
        -- players are opponents. Only use that fallback when teams exist.
        if #Teams:GetTeams() == 0 then return "enemy" end
        if not LP.Neutral and not player.Neutral then
            return LP.TeamColor == player.TeamColor and "ally" or "enemy"
        end
        if C.UnknownEnemy then return "enemy" end
        return "unknown"
    end
    local team = model:GetAttribute("Team")
    if team and LP.Team then
        return tostring(team) == LP.Team.Name and "ally" or "enemy"
    end
    return "enemy" -- NPCs are opt-in; unknown NPC allegiance cannot be inferred.
end

local function screenPoint(camera, world)
    local v, visible = camera:WorldToViewportPoint(world)
    return Vector2.new(v.X, v.Y), visible and v.Z > 0
end
local function visibleHead(camera, model, head)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignored = {camera}
    if LP.Character then table.insert(ignored, LP.Character) end
    params.FilterDescendantsInstances = ignored
    params.IgnoreWater = true
    params.RespectCanCollide = true
    local delta = head.Position - camera.CFrame.Position
    local result = workspace:Raycast(camera.CFrame.Position, delta, params)
    return result == nil or result.Instance:IsDescendantOf(model)
end
local function feetPoint(model, root, hum)
    local left = model:FindFirstChild("LeftFoot") or model:FindFirstChild("Left Leg")
    local right = model:FindFirstChild("RightFoot") or model:FindFirstChild("Right Leg")
    if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
        local lowest = math.min(left.Position.Y - left.Size.Y / 2,
            right.Position.Y - right.Size.Y / 2)
        return Vector3.new(root.Position.X, lowest, root.Position.Z)
    end
    return root.Position - Vector3.new(0, root.Size.Y / 2 + hum.HipHeight, 0)
end

local function targetList()
    local result, present = {}, {}
    for _, player in ipairs(Players:GetPlayers()) do
        local model = player.Character
        if player ~= LP and model then
            present[model] = true
            table.insert(result, {player = player, model = model, name = player.DisplayName})
        end
    end
    if C.NPCs then
        for hum in pairs(npcHumanoids) do
            local model = hum.Parent
            if not hum:IsDescendantOf(workspace) then
                npcHumanoids[hum] = nil
            elseif model and model:IsA("Model") and not present[model]
                and not Players:GetPlayerFromCharacter(model) then
                present[model] = true
                table.insert(result, {model = model, name = model.Name})
            end
        end
    end
    return result, present
end

-- Run this at aim priority, using the latest camera pose. ESP is updated
-- separately and can be disabled without affecting head acquisition.
local function acquireHead(camera)
    local center = camera.ViewportSize / 2
    local candidate, name, distance, player, score
    local counts = {inside = 0, clear = 0, blocked = 0, unknown = 0, allies = 0}
    for _, item in ipairs(targetList()) do
        local model = item.model
        local hum = model:FindFirstChildOfClass("Humanoid")
        local head = model:FindFirstChild("Head")
        if hum and hum.Health > 0 and head and head:IsA("BasePart") then
            local kind = relation(item.player, model)
            local point, projected = screenPoint(camera, head.Position)
            local dist = (head.Position - camera.CFrame.Position).Magnitude
            if projected and dist <= C.Range and (point - center).Magnitude <= C.Radius then
                counts.inside += 1
                if kind == "ally" then counts.allies += 1
                elseif kind == "unknown" then counts.unknown += 1
                elseif kind == "enemy" then
                    if not C.CheckSight or visibleHead(camera, model, head) then
                        counts.clear += 1
                        local rank = (point - center).Magnitude + dist * .025
                        if C.Sticky and head == lockedHead and item.player == lockedPlayer then
                            rank -= 60
                        end
                        if not score or rank < score then
                            candidate, name, distance, player, score =
                                head, item.name, dist, item.player, rank
                        end
                    else counts.blocked += 1 end
                end
            end
        end
    end
    return candidate, name, distance, player, counts
end

local function updateOverlay(item, camera, viewport, center, origin, stats)
    local model, player = item.model, item.player
    local relationship = relation(player, model)
    if relationship == "ally" then stats.allies += 1 end
    if relationship == "unknown" then stats.unknown += 1 end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local head, root = model:FindFirstChild("Head"), model:FindFirstChild("HumanoidRootPart")
    local o = overlays[model]
    if (relationship ~= "enemy" and not (relationship == "ally" and C.Allies))
        or not hum or hum.Health <= 0 or not head or not root
        or not head:IsA("BasePart") or not root:IsA("BasePart") then
        if o then hideOverlay(o) end
        return
    end
    local dist = (root.Position - origin).Magnitude
    if dist > C.Range then if o then hideOverlay(o) end return end
    local head2, onScreen = screenPoint(camera, head.Position)
    if not onScreen or head2.X < 0 or head2.X > viewport.X
        or head2.Y < 0 or head2.Y > viewport.Y then
        if o then hideOverlay(o) end
        return
    end
    if relationship == "enemy" then stats.enemies += 1 end
    local fovDist = (head2 - center).Magnitude
    if relationship == "enemy" and fovDist <= C.Radius then
        stats.inside += 1
        if visibleHead(camera, model, head) then
            stats.clear += 1
            if fovDist < stats.score then
                stats.score, stats.target, stats.name, stats.dist, stats.player =
                    fovDist, head, item.name, dist, player
            end
        else
            stats.blocked += 1
        end
    end

    if not C.ESP then if o then hideOverlay(o) end return end
    local top2 = screenPoint(camera, head.Position + Vector3.new(0, head.Size.Y / 2 + .35, 0))
    local foot2 = screenPoint(camera, feetPoint(model, root, hum))
    local h = math.max(16, math.abs(foot2.Y - top2.Y))
    local w = math.clamp(h * .52, 8, viewport.X)
    local x, y = head2.X - w / 2, top2.Y
    if y > viewport.Y or y + h < 0 then if o then hideOverlay(o) end return end
    if not o then o = createOverlay(model) end
    local color = relationship == "ally" and COL.ally or COL.enemy
    o.stroke.Color = color
    o.tracer.BackgroundColor3 = color
    o.box.Position = UDim2.fromOffset(x, y)
    o.box.Size = UDim2.fromOffset(w, h)
    show(o.box, C.Boxes)
    o.name.Text = item.name
    o.name.Position = UDim2.fromOffset(x - 25, y - 20)
    o.name.Size = UDim2.fromOffset(w + 50, 18)
    show(o.name, C.Names)
    o.distance.Text = tostring(math.floor(dist + .5)) .. " studs"
    o.distance.Position = UDim2.fromOffset(x - 20, y + h + 2)
    o.distance.Size = UDim2.fromOffset(w + 40, 16)
    show(o.distance, C.Distance)
    o.barBG.Position = UDim2.fromOffset(x - 7, y)
    o.barBG.Size = UDim2.fromOffset(4, h)
    local fraction = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    o.fill.Size = UDim2.fromScale(1, fraction)
    o.fill.BackgroundColor3 = COL.enemy:Lerp(COL.good, fraction)
    show(o.barBG, C.Health)
    if C.Tracers then
        placeLine(o.tracer, Vector2.new(center.X, viewport.Y - 12), Vector2.new(head2.X, y + h), 1)
    else show(o.tracer, false) end
    if C.Outlines then
        if not o.highlight or o.highlight.Parent ~= model then
            if o.highlight then o.highlight:Destroy() end
            o.highlight = make("Highlight", {
                Adornee = model, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                FillColor = color, FillTransparency = .82,
                OutlineColor = color, OutlineTransparency = .05,
            }, model)
        end
        o.highlight.FillColor = color
        o.highlight.OutlineColor = color
        o.highlight.Enabled = true
    elseif o.highlight then o.highlight.Enabled = false end

    local pairsForRig = hum.RigType == Enum.HumanoidRigType.R6 and bonesR6 or bonesR15
    for i, segment in ipairs(o.bones) do
        segment.BackgroundColor3 = color
        local pair = C.Skeleton and pairsForRig[i]
        local a = pair and model:FindFirstChild(pair[1])
        local b = pair and model:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local p1, v1 = screenPoint(camera, a.Position)
            local p2, v2 = screenPoint(camera, b.Position)
            if v1 and v2 then placeLine(segment, p1, p2, 1.5)
            else show(segment, false) end
        else show(segment, false) end
    end
end

connect(workspace.DescendantAdded, function(obj)
    if C.NPCs and obj:IsA("Humanoid") and obj.Parent:IsA("Model") then
        npcHumanoids[obj] = true
    end
end)
connect(Players.PlayerRemoving, function(player)
    if player.Character then removeOverlay(player.Character) end
end)

local elapsed, statusElapsed = 0, 0
local function onRender(dt)
    if not running then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local center = viewport / 2
    circle.Position = UDim2.fromOffset(center.X, center.Y)
    circle.Size = UDim2.fromOffset(C.Radius * 2, C.Radius * 2)
    show(circle, C.FOV)
    indicator.Position = UDim2.fromOffset(center.X, center.Y + C.Radius + 12)

    elapsed += dt
    if elapsed < 1 / 30 then return end
    elapsed = math.min(elapsed - 1 / 30, 1 / 30)
    local localRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local list, present = targetList()
    for model in pairs(overlays) do
        if not model:IsDescendantOf(workspace) or not present[model] then
            removeOverlay(model)
        end
    end
    local stats = {enemies = 0, allies = 0, unknown = 0,
        inside = 0, clear = 0, blocked = 0,
        score = math.huge, target = nil, name = nil, dist = nil, player = nil}
    for _, item in ipairs(list) do
        updateOverlay(item, camera, viewport, center, origin, stats)
    end
    local head = bestTarget
    circleStroke.Color = head and COL.good or COL.accent
    if C.Indicator and head and head.Parent and head:IsDescendantOf(workspace) then
        local label = C.Aim and "TRACKING" or "IN FOV"
        local headScreen = screenPoint(camera, head.Position)
        if C.Headshot and (headScreen - center).Magnitude <= 12 then
            label = "HEAD ALIGNED"
        end
        indicator.Text = string.format("%s  %s  •  %d studs", label, bestName or "target",
            math.floor((bestDistance or 0) + .5))
        indicator.TextColor3 = C.Aim and COL.good or COL.text
        show(indicator, true)
    else show(indicator, false) end
    statusElapsed += 1 / 30
    if statusElapsed >= .25 then
        statusElapsed = 0
        aimChip.Text = C.Aim and "AIM  ON" or "AIM  OFF"
        aimChip.TextColor3 = C.Aim and COL.good or COL.muted
        aimChip.BackgroundColor3 = C.Aim and COL.raised or COL.card
        status.Text = string.format("AIM  %s    |    ENGINE  %s    |    INPUTS  %d\nIN FOV  %d    CLEAR  %d    ALLIES  %d    UNKNOWN  %d    BLOCKED  %d",
            aimReason, engineName, aimWrites, aimCounts.inside, aimCounts.clear,
            aimCounts.allies, aimCounts.unknown, aimCounts.blocked)
    end
end

local lastAppliedLook, lastHeadPosition, lastAimError = nil, nil, nil
local trackedHead, resetFrames, useMouse, mouseUnavailable = nil, 0, false, false
local previousError, mouseGain, mouseStall = nil, .65, 0
local function angleDegrees(a, b)
    return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end
local function clearLock()
    lockedHead, lockedPlayer = nil, nil
    trackedHead, lastAppliedLook, lastHeadPosition = nil, nil, nil
    resetFrames, useMouse, previousError, mouseGain, mouseStall = 0, false, nil, .65, 0
    engineName = "CAMERA"
end
local function onAimStep(dt)
    if not running then return end
    local camera = workspace.CurrentCamera
    if not camera then aimReason = "NO CAMERA" return end
    local head, name, distance, player, counts = acquireHead(camera)
    aimCounts = counts
    bestTarget, bestName, bestDistance, bestPlayer = head, name, distance, player
    if not C.Aim then
        clearLock()
        mouseUnavailable = false
        aimReason = "OFF"
        return
    end
    if UIS:GetFocusedTextBox() then
        clearLock()
        aimReason = "TEXT INPUT"
        return
    end
    local ownHumanoid = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if ownHumanoid and ownHumanoid.Health <= 0 then
        clearLock()
        aimReason = "RESPAWNING"
        return
    end
    if not head then
        clearLock()
        aimReason = counts.unknown > 0 and "TEAM UNKNOWN"
            or counts.blocked > 0 and "HEAD BLOCKED"
            or counts.allies > 0 and "ONLY TEAMMATES"
            or "NO HEAD IN CIRCLE"
        return
    end
    if head ~= trackedHead then
        trackedHead, lastAppliedLook, lastHeadPosition = head, nil, nil
        resetFrames, useMouse, previousError, mouseGain, mouseStall = 0, false, nil, .65, 0
    end
    lockedHead, lockedPlayer = head, player
    local alpha = 1 - math.exp(-C.AimSpeed * math.clamp(dt, 0, .05))

    -- If the game repeatedly replaces camera rotation, switch to small mouse
    -- steps. The player still has a single aim toggle, with no mode to select.
    if not useMouse and lastAppliedLook and lastHeadPosition
        and (head.Position - lastHeadPosition).Magnitude < .75
        and angleDegrees(camera.CFrame.LookVector, lastAppliedLook) > 3 then
        resetFrames += 1
    else
        resetFrames = math.max(0, resetFrames - 1)
    end
    if resetFrames >= 5 and relativeMouse and not mouseUnavailable then
        useMouse = true
        previousError = nil
    end

    if useMouse and relativeMouse then
        engineName = "MOUSE"
        local point = screenPoint(camera, head.Position)
        local error = point - camera.ViewportSize / 2
        if previousError then
            if error:Dot(previousError) < 0 then
                mouseGain = math.max(.22, mouseGain * .72)
            elseif error.Magnitude > previousError.Magnitude * .95 then
                mouseGain = math.min(.95, mouseGain * 1.015)
                mouseStall += 1
            else
                mouseStall = math.max(0, mouseStall - 2)
            end
        end
        previousError = error
        if error.Magnitude < 2.5 then
            aimReason = "ALIGNED"
            return
        end
        if mouseStall < 25 then
            local step = error * alpha * mouseGain
            local dx = math.round(math.clamp(step.X, -24, 24))
            local dy = math.round(math.clamp(step.Y, -24, 24))
            local ok = pcall(relativeMouse, dx, dy)
            if ok then
                aimWrites += 1
                aimReason = "TRACKING HEAD"
                return
            end
        end
        -- A rejected or ineffective mouse move should not trap aim in this path.
        mouseUnavailable, useMouse, resetFrames, previousError = true, false, 0, nil
    end

    engineName = "CAMERA"
    local desired = CFrame.lookAt(camera.CFrame.Position, head.Position)
    camera.CFrame = camera.CFrame:Lerp(desired, alpha)
    lastAppliedLook, lastHeadPosition = camera.CFrame.LookVector, head.Position
    aimWrites += 1
    aimReason = angleDegrees(camera.CFrame.LookVector, desired.LookVector) < .5
        and "ALIGNED" or "TRACKING HEAD"
end
local function onAim(dt)
    local ok, err = pcall(onAimStep, dt)
    if not ok then
        local message = tostring(err)
        aimReason = "AIM ERROR: " .. message:sub(-65)
        if message ~= lastAimError then warn("Arsenal Nightfall aim error: " .. message) end
        lastAimError = message
    end
end

local function stop()
    if not running then return end
    running = false
    RunService:UnbindFromRenderStep(renderName)
    RunService:UnbindFromRenderStep(aimName)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for model in pairs(overlays) do removeOverlay(model) end
    gui:Destroy()
    table.clear(npcHumanoids)
    if _G.ArsenalNightfallStop == stop then _G.ArsenalNightfallStop = nil end
end
_G.ArsenalNightfallStop = stop
RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, onRender)
RunService:BindToRenderStep(aimName, Enum.RenderPriority.Last.Value, onAim)
Window:Notify("Arsenal Nightfall v2 ready", "F2 or on-screen button toggles aim", 3)
