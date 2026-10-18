-- RIVALS V2 | Visual diagnostics and target indicator (no automatic aiming or firing)
-- Experimental: standard Roblox player characters and teams; game-specific systems may differ.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then error('Client context required') end
local pg = LocalPlayer:WaitForChild('PlayerGui')
if type(_G.RivalsV2Stop) == 'function' then pcall(_G.RivalsV2Stop) end
local old = pg:FindFirstChild('RivalsV2Visual')
if old then old:Destroy() end
local alive = true
local connections, visuals = {}, {}
local cfg = {ESP=true, Boxes=true, Skeleton=true, Health=true, Names=true, Distance=true, FOV=true, Target=true, Radius=160, Range=1800}
local purple = Color3.fromRGB(170,105,255)
local red = Color3.fromRGB(255,90,115)
local white = Color3.fromRGB(244,241,255)
local function make(class, props, parent)
    local inst=Instance.new(class)
    for k,v in pairs(props or {}) do inst[k]=v end
    inst.Parent=parent
    return inst
end
local gui=make('ScreenGui',{Name='RivalsV2Visual',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=900},pg)
local menu=make('Frame',{Size=UDim2.fromOffset(300,440),Position=UDim2.fromOffset(25,90),BackgroundColor3=Color3.fromRGB(19,17,31),BorderSizePixel=0},gui)
make('UICorner',{CornerRadius=UDim.new(0,12)},menu)
make('UIStroke',{Color=purple,Thickness=2},menu)
local title=make('TextLabel',{Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,Text='RIVALS V2  |  F1',TextColor3=white,Font=Enum.Font.GothamBold,TextSize=17},menu)
local scroll=make('ScrollingFrame',{Position=UDim2.fromOffset(12,45),Size=UDim2.new(1,-24,1,-60),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},menu)
make('UIListLayout',{Padding=UDim.new(0,6)},scroll)
local function button(txt)
    local b=make('TextButton',{Size=UDim2.new(1,-6,0,30),BackgroundColor3=Color3.fromRGB(40,34,62),TextColor3=white,Text=txt,Font=Enum.Font.GothamMedium,TextSize=12,BorderSizePixel=0},scroll)
    make('UICorner',{CornerRadius=UDim.new(0,7)},b)
    return b
end
for _,entry in ipairs({{'Enemy ESP','ESP'},{'Boxes','Boxes'},{'Skeleton','Skeleton'},{'Health','Health'},{'Names','Names'},{'Distance','Distance'},{'FOV circle','FOV'},{'Visible target','Target'}}) do
    local label,key=entry[1],entry[2]
    local b=button('')
    local function refresh() b.Text=label..': '..(cfg[key] and 'ON' or 'OFF'); b.TextColor3=cfg[key] and purple or white end
    refresh()
    table.insert(connections,b.MouseButton1Click:Connect(function() cfg[key]=not cfg[key];refresh() end))
end
local radius=button('')
local function radiusText() radius.Text='FOV radius: '..cfg.Radius..' px (click)' end
radiusText()
table.insert(connections,radius.MouseButton1Click:Connect(function() cfg.Radius=cfg.Radius+25; if cfg.Radius>350 then cfg.Radius=75 end;radiusText() end))
local range=button('')
local function rangeText() range.Text='ESP range: '..cfg.Range..' studs (click)' end
rangeText()
table.insert(connections,range.MouseButton1Click:Connect(function() cfg.Range=cfg.Range+400;if cfg.Range>3000 then cfg.Range=600 end;rangeText() end))
local status=make('TextLabel',{Size=UDim2.new(1,-6,0,55),BackgroundTransparency=1,Text='Waiting for players...',TextWrapped=true,TextColor3=white,TextSize=11},scroll)
-- Drag the menu by its title.
local dragging=false;local startInput;local startPos
local function dragStart(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true;startInput=input.Position;startPos=menu.Position
    end
end
table.insert(connections,title.InputBegan:Connect(dragStart))
table.insert(connections,UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end))
table.insert(connections,UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local delta=input.Position-startInput
        menu.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end
end))
table.insert(connections,UIS.InputBegan:Connect(function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.F1 then menu.Visible=not menu.Visible end
end))
local circle=make('Frame',{AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1},gui)
make('UICorner',{CornerRadius=UDim.new(1,0)},circle)
make('UIStroke',{Color=purple,Thickness=1.5},circle)
local target=make('TextLabel',{AnchorPoint=Vector2.new(.5,0),Size=UDim2.fromOffset(290,26),BackgroundColor3=Color3.fromRGB(30,24,47),TextColor3=white,Font=Enum.Font.GothamBold,TextSize=12,Visible=false},gui)
make('UICorner',{CornerRadius=UDim.new(0,7)},target)
local BONE_PAIRS={
    {'Head','UpperTorso'},{'UpperTorso','LowerTorso'},
    {'UpperTorso','LeftUpperArm'},{'LeftUpperArm','LeftLowerArm'},{'LeftLowerArm','LeftHand'},
    {'UpperTorso','RightUpperArm'},{'RightUpperArm','RightLowerArm'},{'RightLowerArm','RightHand'},
    {'LowerTorso','LeftUpperLeg'},{'LeftUpperLeg','LeftLowerLeg'},{'LeftLowerLeg','LeftFoot'},
    {'LowerTorso','RightUpperLeg'},{'RightUpperLeg','RightLowerLeg'},{'RightLowerLeg','RightFoot'},
    {'Head','Torso'},{'Torso','Left Arm'},{'Torso','Right Arm'},{'Torso','Left Leg'},{'Torso','Right Leg'}
}
local function line(parent,thickness)
    return make('Frame',{AnchorPoint=Vector2.new(.5,.5),BorderSizePixel=0,BackgroundColor3=red,Size=UDim2.fromOffset(0,thickness or 1),Visible=false},parent)
end
local function drawLine(frame,a,b,thickness)
    local diff=b-a
    frame.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    frame.Size=UDim2.fromOffset(diff.Magnitude,thickness or 1)
    frame.Rotation=math.deg(math.atan2(diff.Y,diff.X))
    frame.Visible=true
end
local function clear(p)
    local v=visuals[p]
    if not v then return end
    for _,obj in ipairs(v.instances) do pcall(function() obj:Destroy() end) end
    visuals[p]=nil
end
local function create(p,char)
    local inst={}
    local function own(obj) table.insert(inst,obj);return obj end
    local box=own(make('Frame',{BackgroundTransparency=1,BorderSizePixel=0,Visible=false},gui))
    make('UIStroke',{Color=red,Thickness=1.3},box)
    local hpBack=own(make('Frame',{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(60,30,35),Visible=false},gui))
    local hpFill=make('Frame',{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(75,230,110)},hpBack)
    local label=own(make('TextLabel',{BackgroundTransparency=1,TextColor3=white,TextStrokeTransparency=.2,Font=Enum.Font.GothamBold,TextSize=12,Visible=false},gui))
    local bones={}
    for i=1,#BONE_PAIRS do bones[i]=own(line(gui,1.4)) end
    local v={char=char,box=box,hpBack=hpBack,hpFill=hpFill,label=label,bones=bones,instances=inst}
    visuals[p]=v
    return v
end
local function hide(v)
    v.box.Visible=false;v.hpBack.Visible=false;v.label.Visible=false
    for _,b in ipairs(v.bones) do b.Visible=false end
end
local function isEnemy(p)
    if p==LocalPlayer then return false end
    if LocalPlayer.Team and p.Team then return LocalPlayer.Team~=p.Team end
    if not LocalPlayer.Neutral and not p.Neutral then return LocalPlayer.TeamColor~=p.TeamColor end
    return false -- Unknown team: don't mark teammates as enemies.
end
local function lineOfSight(cam,char,head)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=LocalPlayer.Character and {LocalPlayer.Character} or {}
    params.IgnoreWater=true
    local origin=cam.CFrame.Position
    local hit=workspace:Raycast(origin,head.Position-origin,params)
    return not hit or hit.Instance:IsDescendantOf(char)
end
local function render()
    local cam=workspace.CurrentCamera
    if not cam then return end
    local vp=cam.ViewportSize;local center=Vector2.new(vp.X/2,vp.Y/2)
    circle.Position=UDim2.fromOffset(center.X,center.Y)
    circle.Size=UDim2.fromOffset(cfg.Radius*2,cfg.Radius*2)
    circle.Visible=cfg.FOV
    target.Position=UDim2.fromOffset(center.X,center.Y+cfg.Radius+12)
    target.Visible=false
    local localRoot=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
    local shown,unknown,missing=0,0,0
    local best,bestD=nil,cfg.Radius
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then
            local char=p.Character
            local head=char and char:FindFirstChild('Head')
            local root=char and char:FindFirstChild('HumanoidRootPart')
            local hum=char and char:FindFirstChildOfClass('Humanoid')
            local valid=isEnemy(p) and head and root and hum and hum.Health>0
            if not LocalPlayer.Team or not p.Team then unknown=unknown+1 end
            if not head or not root or not hum then missing=missing+1 end
            local v=visuals[p]
            if v and (v.char~=char or not valid) then clear(p);v=nil end
            if valid then
                if not v then v=create(p,char) end
                hide(v)
                local dist=localRoot and (root.Position-localRoot.Position).Magnitude or math.huge
                if cfg.ESP and dist<=cfg.Range then
                    -- Use head and root anchors rather than animated weapon/accessory bounding boxes.
                    local headTop=cam:WorldToViewportPoint(head.Position+Vector3.new(0,1.15,0))
                    local feet=cam:WorldToViewportPoint(root.Position-Vector3.new(0,3.1,0))
                    if headTop.Z>.05 and feet.Z>.05 then
                        local height=math.abs(feet.Y-headTop.Y)
                        local width=height*.48
                        local x=(headTop.X+feet.X)/2-width/2
                        local y=math.min(headTop.Y,feet.Y)
                        local onScreen=x+width>=0 and x<=vp.X and y+height>=0 and y<=vp.Y
                        if onScreen and height>=3 and height<vp.Y*2 then
                            shown=shown+1
                            if cfg.Boxes then
                                v.box.Position=UDim2.fromOffset(x,y)
                                v.box.Size=UDim2.fromOffset(width,height)
                                v.box.Visible=true
                            end
                            if cfg.Health then
                                local ratio=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                                v.hpBack.Position=UDim2.fromOffset(x-9,y)
                                v.hpBack.Size=UDim2.fromOffset(5,height)
                                v.hpFill.AnchorPoint=Vector2.new(0,1)
                                v.hpFill.Position=UDim2.fromScale(0,1)
                                v.hpFill.Size=UDim2.fromScale(1,ratio)
                                v.hpFill.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-ratio)),math.floor(255*ratio),55)
                                v.hpBack.Visible=true
                            end
                            if cfg.Names or cfg.Distance or cfg.Health then
                                local pieces={}
                                if cfg.Names then table.insert(pieces,p.DisplayName) end
                                if cfg.Distance and dist<math.huge then table.insert(pieces,math.floor(dist)..' studs') end
                                if cfg.Health then table.insert(pieces,math.ceil(hum.Health)..' HP') end
                                v.label.Text=table.concat(pieces,' | ')
                                v.label.Position=UDim2.fromOffset(x-45,y-22)
                                v.label.Size=UDim2.fromOffset(width+90,20)
                                v.label.Visible=true
                            end
                            if cfg.Skeleton then
                                for i,pair in ipairs(BONE_PAIRS) do
                                    local a=char:FindFirstChild(pair[1]);local b=char:FindFirstChild(pair[2])
                                    if a and b then
                                        local sa=cam:WorldToViewportPoint(a.Position)
                                        local sb=cam:WorldToViewportPoint(b.Position)
                                        if sa.Z>.05 and sb.Z>.05 then
                                            drawLine(v.bones[i],Vector2.new(sa.X,sa.Y),Vector2.new(sb.X,sb.Y),1.4)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if cfg.Target and cfg.FOV then
                    local pos,screen=cam:WorldToViewportPoint(head.Position)
                    if screen and pos.Z>0 then
                        local d=(Vector2.new(pos.X,pos.Y)-center).Magnitude
                        if d<bestD and lineOfSight(cam,char,head) then bestD=d;best=p end
                    end
                end
            end
        end
    end
    if best then target.Text='VISIBLE TARGET: '..best.DisplayName;target.Visible=true end
    status.Text='ESP visible: '..shown..' | Unknown teams: '..unknown..' | Missing parts: '..missing..'\nVisual targeting only. No aim movement or firing.'
end
local function stop()
    if not alive then return end
    alive=false
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for p in pairs(visuals) do clear(p) end
    gui:Destroy()
end
_G.RivalsV2Stop=stop
table.insert(connections,Players.PlayerRemoving:Connect(clear))
table.insert(connections,RunService.RenderStepped:Connect(function()
    if not alive then return end
    local ok,err=pcall(render)
    if not ok and status.Parent then status.Text='Render error: '..tostring(err) end
end))
print('RIVALS V2 visual script loaded | F1 menu')
