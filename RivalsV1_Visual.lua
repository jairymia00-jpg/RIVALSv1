-- RIVALS V1 | Visual overlay only: no aim control, firing or shot redirection.
-- Experimental client script; game-specific character/team systems may differ.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local localPlayer = Players.LocalPlayer
assert(localPlayer, 'Requires a client')
local pg = localPlayer:WaitForChild('PlayerGui')
if type(_G.RivalsV1Stop) == 'function' then pcall(_G.RivalsV1Stop) end
local old = pg:FindFirstChild('RivalsV1Visual')
if old then old:Destroy() end
local gui = Instance.new('ScreenGui')
gui.Name = 'RivalsV1Visual'
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 900
gui.Parent = pg
local purple = Color3.fromRGB(175,105,255)
local white = Color3.fromRGB(245,240,255)
local dark = Color3.fromRGB(22,18,34)
local cfg = {ESP=true, Boxes=true, HP=true, Names=true, Distance=true, FOV=true, Tracker=true, Radius=160, Range=1200}
local alive = true
local connections = {}
local entries = {}
local function make(class, props, parent)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent
    return o
end
local menu=make('Frame',{Name='Menu',Position=UDim2.fromOffset(24,100),Size=UDim2.fromOffset(305,430),BackgroundColor3=dark,BorderSizePixel=0},gui)
make('UICorner',{CornerRadius=UDim.new(0,12)},menu)
make('UIStroke',{Color=purple,Thickness=2},menu)
make('TextLabel',{Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,Text='RIVALS V1  |  F1',TextColor3=white,Font=Enum.Font.GothamBold,TextSize=17},menu)
local scroll=make('ScrollingFrame',{Position=UDim2.fromOffset(12,44),Size=UDim2.new(1,-24,1,-58),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},menu)
make('UIListLayout',{Padding=UDim.new(0,6)},scroll)
local function button(label, fn)
    local b=make('TextButton',{Size=UDim2.new(1,-6,0,31),BackgroundColor3=Color3.fromRGB(42,35,62),TextColor3=white,Font=Enum.Font.GothamMedium,TextSize=12,Text=label,BorderSizePixel=0},scroll)
    make('UICorner',{CornerRadius=UDim.new(0,6)},b)
    table.insert(connections,b.MouseButton1Click:Connect(function() fn(b) end))
    return b
end
for _,item in ipairs({{'Enemy visuals','ESP'},{'2D boxes','Boxes'},{'Health bars','HP'},{'Names','Names'},{'Distances','Distance'},{'FOV circle','FOV'},{'Visible head tracker','Tracker'}}) do
    local label,key=item[1],item[2]
    local b
    b=button('',function() cfg[key]=not cfg[key]; b.Text=label..': '..(cfg[key] and 'ON' or 'OFF'); b.TextColor3=cfg[key] and purple or white end)
    b.Text=label..': '..(cfg[key] and 'ON' or 'OFF')
    b.TextColor3=cfg[key] and purple or white
end
local radiusButton
radiusButton=button('',function() cfg.Radius=cfg.Radius+25; if cfg.Radius>375 then cfg.Radius=75 end; radiusButton.Text='FOV radius: '..cfg.Radius..' px' end)
radiusButton.Text='FOV radius: '..cfg.Radius..' px'
local rangeButton
rangeButton=button('',function() cfg.Range=cfg.Range+300; if cfg.Range>2400 then cfg.Range=300 end; rangeButton.Text='ESP range: '..cfg.Range..' studs' end)
rangeButton.Text='ESP range: '..cfg.Range..' studs'
local status=make('TextLabel',{Size=UDim2.new(1,-6,0,60),BackgroundTransparency=1,TextColor3=white,TextSize=11,TextWrapped=true,Text='Waiting for players...'},scroll)
local circle=make('Frame',{AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,BorderSizePixel=0},gui)
make('UICorner',{CornerRadius=UDim.new(1,0)},circle)
make('UIStroke',{Color=purple,Thickness=1.5},circle)
local tracker=make('TextLabel',{AnchorPoint=Vector2.new(.5,1),Size=UDim2.fromOffset(190,25),BackgroundColor3=dark,TextColor3=white,Font=Enum.Font.GothamBold,TextSize=12,Visible=false,ZIndex=20},gui)
make('UICorner',{CornerRadius=UDim.new(0,6)},tracker)
local function clear(p)
    local e=entries[p]
    if not e then return end
    e.box:Destroy(); e.hpBack:Destroy(); e.name:Destroy()
    entries[p]=nil
end
local function entry(p)
    if entries[p] then return entries[p] end
    local box=make('Frame',{BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=10},gui)
    make('UIStroke',{Color=purple,Thickness=1.5},box)
    local hpBack=make('Frame',{BackgroundColor3=Color3.fromRGB(55,35,40),BorderSizePixel=0,Visible=false,ZIndex=11},gui)
    local fill=make('Frame',{BackgroundColor3=Color3.fromRGB(70,230,110),BorderSizePixel=0,ZIndex=12},hpBack)
    local name=make('TextLabel',{BackgroundTransparency=1,TextColor3=white,TextStrokeTransparency=.3,TextSize=12,Font=Enum.Font.GothamBold,Visible=false,ZIndex=12},gui)
    local e={box=box,hpBack=hpBack,fill=fill,name=name}
    entries[p]=e
    return e
end
local function enemy(p)
    if p==localPlayer then return false end
    if localPlayer.Team and p.Team then return localPlayer.Team~=p.Team end
    if not localPlayer.Neutral and not p.Neutral then return localPlayer.TeamColor~=p.TeamColor end
    return false -- don't guess custom teams
end
local function sight(cam,character,head)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=localPlayer.Character and {localPlayer.Character} or {}
    local origin=cam.CFrame.Position
    local hit=workspace:Raycast(origin,head.Position-origin,params)
    return not hit or hit.Instance:IsDescendantOf(character)
end
local function update()
    local cam=workspace.CurrentCamera
    if not cam then return end
    local size=cam.ViewportSize
    local center=Vector2.new(size.X/2,size.Y/2)
    circle.Position=UDim2.fromOffset(center.X,center.Y)
    circle.Size=UDim2.fromOffset(cfg.Radius*2,cfg.Radius*2)
    circle.Visible=cfg.FOV
    tracker.Visible=false
    local count,unknown,missing=0,0,0
    local best,bestD,bestPoint=nil,cfg.Radius,nil
    local ownRoot=localPlayer.Character and localPlayer.Character:FindFirstChild('HumanoidRootPart')
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=localPlayer then
            local ch=p.Character
            local head=ch and ch:FindFirstChild('Head')
            local root=ch and ch:FindFirstChild('HumanoidRootPart')
            local hum=ch and ch:FindFirstChildOfClass('Humanoid')
            if not localPlayer.Team or not p.Team then unknown=unknown+1 end
            if not head or not root or not hum then missing=missing+1 end
            local e=entries[p]
            local valid=cfg.ESP and enemy(p) and head and root and hum and hum.Health>0
            if valid then
                local dist=ownRoot and (root.Position-ownRoot.Position).Magnitude or math.huge
                local foot=cam:WorldToViewportPoint(root.Position-Vector3.new(0,3,0))
                local top=cam:WorldToViewportPoint(head.Position+Vector3.new(0,1,0))
                local height=foot.Y-top.Y
                local width=height*.48
                local x=(foot.X+top.X)/2-width/2
                local y=top.Y
                local inView=top.Z>0 and foot.Z>0 and height>4 and height<2*size.Y and x+width>=0 and x<=size.X and y+height>=0 and y<=size.Y and dist<=cfg.Range
                if not e then e=entry(p) end
                e.box.Visible=inView and cfg.Boxes
                e.hpBack.Visible=inView and cfg.HP
                e.name.Visible=inView and (cfg.Names or cfg.Distance)
                if inView then
                    count=count+1
                    e.box.Position=UDim2.fromOffset(x,y)
                    e.box.Size=UDim2.fromOffset(width,height)
                    local barX=x-9
                    e.hpBack.Position=UDim2.fromOffset(barX,y)
                    e.hpBack.Size=UDim2.fromOffset(5,height)
                    local fraction=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                    e.fill.Position=UDim2.fromScale(0,1-fraction)
                    e.fill.Size=UDim2.fromScale(1,fraction)
                    e.fill.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-fraction)),math.floor(255*fraction),60)
                    e.name.Position=UDim2.fromOffset(x-45,y-35)
                    e.name.Size=UDim2.fromOffset(width+90,30)
                    local parts={}
                    if cfg.Names then table.insert(parts,p.DisplayName) end
                    if cfg.Distance then table.insert(parts,math.floor(dist)..' studs') end
                    e.name.Text=table.concat(parts,' | ')
                end
                if cfg.Tracker and cfg.FOV then
                    local h,onScreen=cam:WorldToViewportPoint(head.Position)
                    if onScreen and h.Z>0 then
                        local d=(Vector2.new(h.X,h.Y)-center).Magnitude
                        if d<bestD and sight(cam,ch,head) then bestD=d;best=p;bestPoint=h end
                    end
                end
            elseif e then
                e.box.Visible=false;e.hpBack.Visible=false;e.name.Visible=false
            end
        end
    end
    if best and bestPoint then
        tracker.Position=UDim2.fromOffset(bestPoint.X,bestPoint.Y-8)
        tracker.Text='VISIBLE: '..best.DisplayName
        tracker.Visible=true
    end
    status.Text='Visible markers: '..count..' | Missing team values: '..unknown..' | Missing parts: '..missing..'\nNote: custom RIVALS teams/HP may need game-specific support.'
end
local dragging=false
local dragStart,menuStart
local titleBar=make('TextButton',{Position=UDim2.new(),Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,Text=''},menu)
table.insert(connections,titleBar.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;dragStart=input.Position;menuStart=menu.Position end
end))
table.insert(connections,UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end))
table.insert(connections,UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=input.Position-dragStart
        menu.Position=UDim2.fromOffset(menuStart.X.Offset+delta.X,menuStart.Y.Offset+delta.Y)
    end
end))
table.insert(connections,UIS.InputBegan:Connect(function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.F1 then menu.Visible=not menu.Visible end
end))
table.insert(connections,Players.PlayerRemoving:Connect(clear))
table.insert(connections,RunService.RenderStepped:Connect(function()
    if not alive then return end
    local ok,err=pcall(update)
    if not ok then status.Text='Update error: '..tostring(err) end
end))
_G.RivalsV1Stop=function()
    if not alive then return end
    alive=false
    for _,c in ipairs(connections) do c:Disconnect() end
    for p in pairs(entries) do clear(p) end
    gui:Destroy()
end
print('RIVALS V1 visual overlay loaded. F1 to toggle menu.')
