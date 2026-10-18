-- RIVALS Task Diagnostics v1
-- Read-only snapshot of task/key UI text and standard Tool names available to the client.
-- Run with the Tasks panel open. Capture before and after manually completing a task.
-- Select report -> Ctrl+C, then paste the report into chat for inspection.
-- This does not retrieve script source, invoke remotes, perform tasks, or award currency.

local Players=game:GetService('Players')
local player=Players.LocalPlayer
if not player then error('Run this in a client context.') end
local pg=player:WaitForChild('PlayerGui',10)
if not pg then error('PlayerGui is not available yet. Retry after joining.') end
local GUI_NAME='RivalsTaskDiagnostics'
local previous=pg:FindFirstChild(GUI_NAME)
if previous then previous:Destroy() end

local function make(class,props,parent)
    local instance=Instance.new(class)
    for key,value in pairs(props or {}) do instance[key]=value end
    instance.Parent=parent
    return instance
end
local gui=make('ScreenGui',{Name=GUI_NAME,ResetOnSpawn=false,DisplayOrder=1100},pg)
local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600)
local width=math.min(680,math.max(280,viewport.X-30))
local height=math.min(480,math.max(280,viewport.Y-70))
local purple=Color3.fromRGB(170,105,255)
local white=Color3.fromRGB(244,241,255)
local panel=make('Frame',{
    AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,24),
    Size=UDim2.fromOffset(width,height),BackgroundColor3=Color3.fromRGB(19,17,31),BorderSizePixel=0
},gui)
make('UICorner',{CornerRadius=UDim.new(0,10)},panel)
make('UIStroke',{Color=purple,Thickness=2},panel)
make('TextLabel',{
    Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-135,0,44),BackgroundTransparency=1,
    Text='TASK DIAGNOSTICS',TextColor3=white,Font=Enum.Font.GothamBold,TextSize=16,
    TextXAlignment=Enum.TextXAlignment.Left
},panel)
local body=make('Frame',{Position=UDim2.fromOffset(12,44),Size=UDim2.new(1,-24,1,-54),BackgroundTransparency=1},panel)
make('TextLabel',{
    Size=UDim2.new(1,0,0,44),BackgroundTransparency=1,TextWrapped=true,
    Text='Open Tasks, then Capture. Hide this panel, complete one task, Show, then Capture again.',
    TextColor3=white,TextSize=13,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left
},body)
local function button(text,parent,position,size)
    local b=make('TextButton',{
        Text=text,Position=position,Size=size,BackgroundColor3=Color3.fromRGB(51,39,76),
        BorderSizePixel=0,TextColor3=white,TextSize=12,Font=Enum.Font.GothamMedium
    },parent)
    make('UICorner',{CornerRadius=UDim.new(0,6)},b)
    return b
end
local hide=button('Hide',panel,UDim2.new(1,-110,0,9),UDim2.fromOffset(62,28))
local close=button('X',panel,UDim2.new(1,-40,0,9),UDim2.fromOffset(28,28))
local capture=button('Capture',body,UDim2.fromOffset(0,50),UDim2.new(.33,-5,0,30))
local selectReport=button('Select report',body,UDim2.new(.33,0,0,50),UDim2.new(.34,-5,0,30))
local clear=button('Clear',body,UDim2.new(.67,0,0,50),UDim2.new(.33,0,0,30))
local scroll=make('ScrollingFrame',{
    Position=UDim2.fromOffset(0,90),Size=UDim2.new(1,0,1,-120),BackgroundColor3=Color3.fromRGB(12,11,20),
    BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y
},body)
local output=make('TextBox',{
    Position=UDim2.fromOffset(7,7),Size=UDim2.new(1,-22,0,24),AutomaticSize=Enum.AutomaticSize.Y,
    BackgroundTransparency=1,ClearTextOnFocus=false,MultiLine=true,TextWrapped=true,RichText=false,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    Font=Enum.Font.Code,TextSize=13,TextColor3=white,Text='Open your Tasks panel, then press Capture.'
},scroll)
local status=make('TextLabel',{
    AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,25),
    BackgroundTransparency=1,Text='Keeps your last two captures.',TextColor3=white,
    Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true
},body)

local function clean(text)
    return tostring(text):gsub('<[^>]*>',''):gsub('[%c]',' '):gsub('%s+',' '):sub(1,400)
end
local function pathOf(instance)
    local names={}
    while instance and instance~=pg do
        table.insert(names,1,clean(instance.Name))
        instance=instance.Parent
    end
    return table.concat(names,'/')
end
local function shown(instance)
    local current=instance
    while current and current~=pg do
        if current:IsA('GuiObject') and not current.Visible then return false end
        if current:IsA('ScreenGui') and not current.Enabled then return false end
        if current:IsA('CanvasGroup') and current.GroupTransparency>=1 then return false end
        local name=current.Name:lower()
        if current==gui or name=='rivalsv21visual' or name=='rivalsv22visual' or name:find('chat',1,true) then return false end
        current=current.Parent
    end
    return current==pg
end
local function relevant(text)
    text=text:lower()
    for _,word in ipairs({'task','quest','keys','scythe','dash','grenade'}) do
        if text:find(word,1,true) then return true end
    end
    return false
end
local function toolNames(container)
    local names={}
    if container then
        for _,child in ipairs(container:GetChildren()) do
            if child:IsA('Tool') then table.insert(names,clean(child.Name)) end
        end
    end
    table.sort(names)
    return #names>0 and table.concat(names,', ') or '(no standard Tool objects found)'
end
local captures={}
local sequence=0
local function snapshot()
    local rows,seen={},{}
    local function add(instance)
        if not (instance:IsA('TextLabel') or instance:IsA('TextButton')) or not shown(instance) then return end
        if instance.TextTransparency>=1 then return end
        local text=clean(instance.Text)
        if text=='' then return end
        local row=pathOf(instance)..' = '..text
        if not seen[row] then seen[row]=true;table.insert(rows,row) end
    end
    for _,instance in ipairs(pg:GetDescendants()) do
        if (instance:IsA('TextLabel') or instance:IsA('TextButton')) and shown(instance) then
            if relevant(pathOf(instance)..' '..clean(instance.Text)) then
                add(instance)
                -- Include nearby progress/reward labels, such as 0/3 and x2.
                if instance.Parent then
                    for _,sibling in ipairs(instance.Parent:GetChildren()) do add(sibling) end
                end
            end
        end
    end
    table.sort(rows)
    local count=#rows
    local lines={
        '=== CAPTURE '..sequence..' | '..os.date('!%Y-%m-%d %H:%M:%S UTC')..' ===',
        'PlaceId: '..tostring(game.PlaceId),
        'Equipped Tool names: '..toolNames(player.Character),
        'Backpack Tool names: '..toolNames(player:FindFirstChildOfClass('Backpack')),
        '',
        'Task/key text (visibility flags checked; screen overlap/clipping not checked):'
    }
    for index=1,math.min(count,180) do table.insert(lines,rows[index]) end
    if count==0 then table.insert(lines,'No matching text found. Open Tasks and Capture again; otherwise send a screenshot.') end
    if count>180 then table.insert(lines,'[Report truncated: '..count..' matching rows, first 180 shown.]') end
    table.insert(lines,'\nNo standard Tools does not mean no weapons; custom item systems may use other objects.')
    return table.concat(lines,'\n'),count
end
capture.Activated:Connect(function()
    sequence=sequence+1
    local ok,report,count=pcall(snapshot)
    if not ok then status.Text='Capture failed: '..tostring(report);return end
    table.insert(captures,report)
    if #captures>2 then table.remove(captures,1) end
    output.Text=table.concat(captures,'\n\n')
    scroll.CanvasPosition=Vector2.new(0,0)
    status.Text='Capture '..sequence..': '..count..' matching rows. Select report, then Ctrl+C.'
end)
selectReport.Activated:Connect(function()
    local ok=pcall(function()
        output:CaptureFocus()
        output.SelectionStart=1
        output.CursorPosition=#output.Text+1
    end)
    status.Text=ok and 'Press Ctrl+C, then paste the report into chat.' or 'Click the report, press Ctrl+A, then Ctrl+C.'
end)
clear.Activated:Connect(function()
    captures={};sequence=0
    output.Text='Open your Tasks panel, then press Capture.'
    status.Text='Captures cleared.'
end)
local folded=false
hide.Activated:Connect(function()
    folded=not folded
    body.Visible=not folded
    panel.Size=UDim2.fromOffset(width,folded and 46 or height)
    hide.Text=folded and 'Show' or 'Hide'
end)
close.Activated:Connect(function() gui:Destroy() end)
