-- RIVALS V2.3 | Visual diagnostics, target indicator, and steadier hold-to-aim lock
-- Experimental: standard Roblox player characters and teams; game-specific systems may differ.
-- Aim lock: enable in the menu, then hold Right Mouse (default). F1 shows/hides the menu.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then error('Client context required') end
local pg = LocalPlayer:WaitForChild('PlayerGui')
if type(_G.RivalsV2Stop) == 'function' then pcall(_G.RivalsV2Stop) end
if type(_G.RivalsV21Stop) == 'function' then pcall(_G.RivalsV21Stop) end
if type(_G.RivalsV22Stop) == 'function' then pcall(_G.RivalsV22Stop) end
if type(_G.RivalsV23Stop) == 'function' then pcall(_G.RivalsV23Stop) end
local old = pg:FindFirstChild('RivalsV21Visual')
if old then old:Destroy() end
local alive = true
local connections, visuals = {}, {}
local cfg = {ESP=true, Boxes=true, Skeleton=true, Health=true, Names=true, Distance=true, FOV=true, Target=true, TeamCheck=false, Radius=160, Range=1800, TargetBone='Head', VisibilityCheck=true, TargetHighlight=true}
cfg.AimLock=false
cfg.AimKey=Enum.UserInputType.MouseButton2
cfg.AimSmooth=36 -- Faster default response per second; 0 gives an instant lock.
cfg.LockRadiusScale=1.35 -- Acquisition uses the circle; held targets have a small release margin.
cfg.LockGrace=.15 -- Retain the target briefly while blocked/missing/outside, without aiming.
local aimHeld=false
local lockedPlayer,lockedCharacter=nil,nil
local lostFor=0
local lockTracking=false
local renderName='RivalsV22VisualAimLock'
local function clearLock()
    lockedPlayer=nil
    lockedCharacter=nil
    lostFor=0
    lockTracking=false
end
local function releaseAim()
    aimHeld=false
    clearLock()
end
local purple = Color3.fromRGB(170,105,255)
local red = Color3.fromRGB(255,90,115)
local white = Color3.fromRGB(244,241,255)
local function make(class, props, parent)
    local inst=Instance.new(class)
    for k,v in pairs(props or {}) do inst[k]=v end
    inst.Parent=parent
    return inst
end
local gui=make('ScreenGui',{Name='RivalsV21Visual',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=900},pg)
local menu=make('Frame',{Size=UDim2.fromOffset(320,485),Position=UDim2.fromOffset(25,90),BackgroundColor3=Color3.fromRGB(19,17,31),BorderSizePixel=0},gui)
make('UICorner',{CornerRadius=UDim.new(0,12)},menu)
make('UIStroke',{Color=purple,Thickness=2},menu)
local title=make('TextLabel',{Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,Text='RIVALS V2.3  |  F1',TextColor3=white,Font=Enum.Font.GothamBold,TextSize=17},menu)
local scroll=make('ScrollingFrame',{Position=UDim2.fromOffset(12,45),Size=UDim2.new(1,-24,1,-60),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},menu)
make('UIListLayout',{Padding=UDim.new(0,6)},scroll)
local function button(txt)
    local b=make('TextButton',{Size=UDim2.new(1,-6,0,30),BackgroundColor3=Color3.fromRGB(40,34,62),TextColor3=white,Text=txt,Font=Enum.Font.GothamMedium,TextSize=12,BorderSizePixel=0},scroll)
    make('UICorner',{CornerRadius=UDim.new(0,7)},b)
    return b
end
for _,entry in ipairs({{'Enemy ESP','ESP'},{'Boxes','Boxes'},{'Skeleton','Skeleton'},{'Health','Health'},{'Names','Names'},{'Distance','Distance'},{'FOV circle','FOV'},{'Aim assist indicator','Target'},{'Target highlight','TargetHighlight'},{'Visibility check','VisibilityCheck'},{'Team filter','TeamCheck'}}) do
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
local boneButton=button('')
local function boneText() boneButton.Text='Target bone: '..cfg.TargetBone..' (click)' end
boneText()
table.insert(connections,boneButton.MouseButton1Click:Connect(function()
    cfg.TargetBone=cfg.TargetBone=='Head' and 'Body' or 'Head'
    boneText()
end))
local range=button('')
local function rangeText() range.Text='ESP / aim range: '..cfg.Range..' studs (click)' end
rangeText()
table.insert(connections,range.MouseButton1Click:Connect(function() cfg.Range=cfg.Range+400;if cfg.Range>3000 then cfg.Range=600 end;rangeText() end))
-- Add aim controls after the existing controls; keep the original panel and visual settings.
local aimToggle=button('')
local function aimToggleText()
    aimToggle.Text='Aim lock: '..(cfg.AimLock and 'ON (hold key)' or 'OFF')
    aimToggle.TextColor3=cfg.AimLock and purple or white
end
aimToggleText()
table.insert(connections,aimToggle.MouseButton1Click:Connect(function()
    cfg.AimLock=not cfg.AimLock
    releaseAim()
    aimToggleText()
end))
local aimKeys={
    {value=Enum.UserInputType.MouseButton2,label='Right Mouse'},
    {value=Enum.KeyCode.Q,label='Q'},
    {value=Enum.KeyCode.E,label='E'},
    {value=Enum.KeyCode.LeftAlt,label='Left Alt'}
}
local aimKeyIndex=1
local aimKeyButton=button('')
local function aimKeyText() aimKeyButton.Text='Hold key: '..aimKeys[aimKeyIndex].label..' (click)' end
aimKeyText()
table.insert(connections,aimKeyButton.MouseButton1Click:Connect(function()
    aimKeyIndex=aimKeyIndex%#aimKeys+1
    cfg.AimKey=aimKeys[aimKeyIndex].value
    releaseAim()
    aimKeyText()
end))
local aimSpeeds={{value=6,label='Smooth'},{value=18,label='Medium'},{value=36,label='Fast'},{value=0,label='Instant'}}
local aimSpeedIndex=3
local aimSpeedButton=button('')
local function aimSpeedText() aimSpeedButton.Text='Lock response: '..aimSpeeds[aimSpeedIndex].label..' (click)' end
aimSpeedText()
table.insert(connections,aimSpeedButton.MouseButton1Click:Connect(function()
    aimSpeedIndex=aimSpeedIndex%#aimSpeeds+1
    cfg.AimSmooth=aimSpeeds[aimSpeedIndex].value
    aimSpeedText()
end))
local function isAimInput(input)
    return input.UserInputType==cfg.AimKey or input.KeyCode==cfg.AimKey
end
table.insert(connections,UIS.InputBegan:Connect(function(input,processed)
    if not alive or processed or UIS:GetFocusedTextBox() then return end
    if cfg.AimLock and isAimInput(input) then aimHeld=true end
end))
table.insert(connections,UIS.InputEnded:Connect(function(input)
    if isAimInput(input) then releaseAim() end
end))
table.insert(connections,UIS.WindowFocusReleased:Connect(releaseAim))
table.insert(connections,UIS.TextBoxFocused:Connect(releaseAim))
table.insert(connections,LocalPlayer.CharacterRemoving:Connect(releaseAim))
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
local marker=make('Frame',{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(14,14),BackgroundTransparency=1,Visible=false},gui)
make('UICorner',{CornerRadius=UDim.new(1,0)},marker)
make('UIStroke',{Color=purple,Thickness=2},marker)
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
    if not cfg.TeamCheck then return true end
    if LocalPlayer.Team and p.Team then return LocalPlayer.Team~=p.Team end
    if not LocalPlayer.Neutral and not p.Neutral then return LocalPlayer.TeamColor~=p.TeamColor end
    return true -- RIVALS may manage teams outside Player.Team; allow unknowns.
end
local function lineOfSight(cam,char,head)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=LocalPlayer.Character and {LocalPlayer.Character,cam} or {cam}
    params.IgnoreWater=true
    local origin=cam.CFrame.Position
    local hit=workspace:Raycast(origin,head.Position-origin,params)
    return not hit or hit.Instance:IsDescendantOf(char)
end
-- New targets must be inside the circle. Held targets have a separate release boundary.
local function aimCandidate(p,cam,center,localRoot,radiusLimit)
    if p.Parent~=Players or not isEnemy(p) then return nil,nil,nil,'invalid' end
    local char=p.Character
    if not char then return nil,nil,nil,'invalid' end
    local hum=char and char:FindFirstChildOfClass('Humanoid')
    local root=char and char:FindFirstChild('HumanoidRootPart')
    local part=char and char:FindFirstChild(cfg.TargetBone=='Body' and 'HumanoidRootPart' or 'Head')
    if hum and hum.Health<=0 then return nil,nil,char,'invalid' end
    if not hum or not root or not root:IsA('BasePart') or not part or not part:IsA('BasePart') then return nil,nil,char,'missing' end
    if (root.Position-localRoot.Position).Magnitude>cfg.Range then return nil,nil,char,'invalid' end
    local pos,screen=cam:WorldToViewportPoint(part.Position)
    if not screen or pos.Z<=0 then return nil,nil,char,'outside' end
    local distance=(Vector2.new(pos.X,pos.Y)-center).Magnitude
    if distance>(radiusLimit or cfg.Radius) then return nil,nil,char,'outside' end
    if cfg.VisibilityCheck and not lineOfSight(cam,char,part) then return nil,nil,char,'blocked' end
    return part,distance,char
end
local function updateAim(dt)
    local cam=workspace.CurrentCamera
    local char=LocalPlayer.Character
    local hum=char and char:FindFirstChildOfClass('Humanoid')
    local localRoot=char and char:FindFirstChild('HumanoidRootPart')
    if not cfg.AimLock or not aimHeld or UIS:GetFocusedTextBox() or not cam or not hum or hum.Health<=0 or not localRoot then
        releaseAim()
        return
    end
    local center=cam.ViewportSize/2
    local part
    if lockedPlayer and lockedPlayer.Character==lockedCharacter then
        local candidate,distance,candidateChar,reason=aimCandidate(lockedPlayer,cam,center,localRoot,cfg.Radius*cfg.LockRadiusScale)
        part=candidate
        if not part and (reason=='blocked' or reason=='outside' or reason=='missing') then
            lostFor=lostFor+math.max(dt,0)
            lockTracking=false
            -- Wait for this target instead of jumping to another player on a one-frame miss.
            -- No camera adjustment occurs while the visibility/FOV/parts check is failing.
            if lostFor<=cfg.LockGrace then return end
        end
    end
    if not part then
        clearLock()
        local closest=cfg.Radius+1
        for _,p in ipairs(Players:GetPlayers()) do
            local candidate,distance,candidateChar=aimCandidate(p,cam,center,localRoot)
            if candidate and distance<closest then
                part=candidate
                closest=distance
                lockedPlayer=p
                lockedCharacter=candidateChar
            end
        end
    end
    if not part then return end
    lostFor=0
    lockTracking=true
    local origin=cam.CFrame.Position
    local direction=part.Position-origin
    if direction.Magnitude<.001 then return end
    local up=Vector3.new(0,1,0)
    if math.abs(direction.Unit:Dot(up))>.999 then up=cam.CFrame.RightVector end
    local desired=CFrame.lookAt(origin,part.Position,up)
    local alpha=cfg.AimSmooth==0 and 1 or 1-math.exp(-cfg.AimSmooth*math.max(dt,0))
    cam.CFrame=cam.CFrame:Lerp(desired,alpha)
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
    marker.Visible=false
    local localRoot=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
    local shown,unknown,missing=0,0,0
    local best,bestD,bestPos=nil,cfg.Radius,nil
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
                    local headTop=cam:WorldToViewportPoint(head.Position+Vector3.new(0,head.Size.Y*0.65,0))
                    local feet=cam:WorldToViewportPoint(root.Position-Vector3.new(0,hum.HipHeight+2.2,0))
                    if headTop.Z>.05 and feet.Z>.05 then
                        local height=feet.Y-headTop.Y
                        local width=height*.48
                        local x=(headTop.X+feet.X)/2-width/2
                        local y=math.min(headTop.Y,feet.Y)
                        local onScreen=x+width>=0 and x<=vp.X and y+height>=0 and y<=vp.Y and height>0
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
                                    if a and b and a:IsA('BasePart') and b:IsA('BasePart') then
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
                if cfg.Target then
                    local aimPart=(cfg.TargetBone=='Body' and root or head)
                    local pos,screen=cam:WorldToViewportPoint(aimPart.Position)
                    if screen and pos.Z>0 then
                        local d=(Vector2.new(pos.X,pos.Y)-center).Magnitude
                        if d<bestD and (not cfg.VisibilityCheck or lineOfSight(cam,char,aimPart)) then bestD=d;best=p;bestPos=Vector2.new(pos.X,pos.Y) end
                    end
                end
            end
        end
    end
    if cfg.Target and lockedPlayer then
        best=nil;bestPos=nil
        if lockTracking and lockedPlayer.Character==lockedCharacter then
            local part=lockedCharacter:FindFirstChild(cfg.TargetBone=='Body' and 'HumanoidRootPart' or 'Head')
            if part then
                local pos=cam:WorldToViewportPoint(part.Position)
                best=lockedPlayer
                bestPos=Vector2.new(pos.X,pos.Y)
            end
        end
    end
    if best then
        target.Text=(best==lockedPlayer and 'LOCKED: ' or 'TARGET: ')..best.DisplayName..' | '..cfg.TargetBone
        target.Visible=true
        if cfg.TargetHighlight and bestPos then
            marker.Position=UDim2.fromOffset(bestPos.X,bestPos.Y)
            marker.Visible=true
        end
    end
    local aimState='Aim lock: OFF'
    if cfg.AimLock then
        aimState=lockedPlayer and ((lockTracking and 'Locked: ' or 'Waiting: ')..lockedPlayer.DisplayName) or (aimHeld and 'Aim lock: searching inside FOV' or ('Hold '..aimKeys[aimKeyIndex].label..' to lock'))
    end
    status.Text='ESP visible: '..shown..' | Unknown teams: '..unknown..' | Missing parts: '..missing..'\n'..aimState
end
local function stop()
    if not alive then return end
    alive=false
    releaseAim()
    RunService:UnbindFromRenderStep(renderName)
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for p in pairs(visuals) do clear(p) end
    gui:Destroy()
end
_G.RivalsV21Stop=stop
_G.RivalsV22Stop=stop
_G.RivalsV23Stop=stop
table.insert(connections,Players.PlayerRemoving:Connect(function(p)
    if p==lockedPlayer then clearLock() end
    clear(p)
end))
-- Run late in the frame to reduce conflicts with custom camera updates; project visuals afterward.
RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value-1,function(dt)
    if not alive then return end
    local ok,err=pcall(function() updateAim(dt);render() end)
    if not ok then
        releaseAim()
        if status.Parent then status.Text='Render error: '..tostring(err) end
        warn('[RIVALS V2.3]',err)
    end
end)
print('RIVALS V2.3 loaded | F1 menu | Enable Aim lock, then hold Right Mouse | Fast response default')
