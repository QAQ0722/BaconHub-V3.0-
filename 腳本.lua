-- Bacon Hub V3 / Author: QAQ0722.
--     ____                         
--    / __ )____ __________  ____ 
--   / __  / __ `/ ___/ __ \/ __ \
--  / /_/ / /_/ / /__/ /_/ / / / /
-- /_____/\__,_/\___/\____/_/ /_/ 
--     ____           ____    ___    ____   ____  _____ ___  ___ 
--    / __ )__  __   / __ \  /   |  / __ \ / __ \/__  /|__ \|__ \
--   / __  / / / /  / / / / / /| | / / / // / / / / / __/ /__/ /
--  / /_/ / /_/ /  / /_/ / / ___ |/ /_/ // /_/ / / / / __// __/ 
-- /_____/\__, /   \___\_\/_/  |_|\___\_\\____/ /_/ /____/____/ 
--       /____/                                                 
local Players = game:GetService('Players')
local Run = game:GetService('RunService')
local Input = game:GetService('UserInputService')
local Lighting = game:GetService('Lighting')
local localPlayer = Players.LocalPlayer
if not localPlayer then warn('[Bacon V3] LocalPlayer unavailable'); return end
local env = type(getgenv) == 'function' and getgenv() or _G
if env.BaconHubV3 and env.BaconHubV3.Unload then env.BaconHubV3.Unload() end
local app = {alive=true, connections={}, objects={}, logs={}, records={}, window=nil}
env.BaconHubV3 = app
local S = {esp=false, tracer=false, rgb=false, color=Color3.fromRGB(255,0,0),
    aim=false, touchAim=false, part='Head', smooth=5, wall=false, team=false,
    fov=false, radius=100, fovColor=Color3.new(1,1,1), infinite=false,
    noclip=false, night=false, antiIdle=false, speed=nil, jump=nil}
local defaults = {gravity=workspace.Gravity, ambient=Lighting.Ambient,
    outdoor=Lighting.OutdoorAmbient, time=Lighting.ClockTime, mouse=Input.MouseIconEnabled}
local console, ring, gui, restoreHumanoid
local collision = setmetatable({}, {__mode='k'})
local humOriginal = setmetatable({}, {__mode='k'})
local function log(level, message)
    local line = string.format('[%s] %s', level, tostring(message))
    table.insert(app.logs, line)
    if #app.logs > 200 then table.remove(app.logs,1) end
    if console and app.alive then pcall(function() console:Append(line) end) end
    if level == 'ERROR' or level == 'WARN' then warn('[Bacon V3] '..line) end
end
local function safe(name, fn)
    local ok, result = pcall(fn)
    if not ok then log('ERROR', name..': '..tostring(result)) end
    return ok, result
end
local function connect(signal, fn, bucket)
    local c = signal:Connect(fn)
    table.insert(bucket or app.connections, c)
    return c
end
local function disconnect(bucket)
    for _, c in ipairs(bucket) do c:Disconnect() end
    table.clear(bucket)
end
local function destroy(object) if object then pcall(function() object:Destroy() end) end end
local function own(object) table.insert(app.objects, object); return object end
local function notify(message)
    log('INFO', message)
    if app.window and app.alive then
        safe('Notification', function() app.window:Notify({title='🥓 培根 V3',content=message}) end)
    end
end

local function bounded(name, seconds, fn)
    local done, ok, result = false, false, nil
    local worker = task.spawn(function()
        ok, result = pcall(fn)
        done = true
    end)
    local deadline = os.clock()+seconds
    while app.alive and not done and os.clock()<deadline do task.wait(0.05) end
    if not done then
        pcall(task.cancel,worker)
        return false, name..' timeout/cancelled'
    end
    return ok,result
end
local function restoreCollision()
    for part,value in pairs(collision) do
        if part.Parent then part.CanCollide=value end
    end
    table.clear(collision)
end
function app.Unload()
    if not app.alive then return end
    if app.ClosePlayerPicker then app.ClosePlayerPicker() end
    if app.StopPlayerAction then app.StopPlayerAction() end
    app.alive=false
    disconnect(app.connections)
    for _,r in pairs(app.records) do disconnect(r.connections); disconnect(r.charConnections) end
    restoreCollision()
    if restoreHumanoid then restoreHumanoid() end
    workspace.Gravity=defaults.gravity
    Lighting.Ambient=defaults.ambient; Lighting.OutdoorAmbient=defaults.outdoor
    Lighting.ClockTime=defaults.time; Input.MouseIconEnabled=defaults.mouse
    for _,r in pairs(app.records) do destroy(r.highlight); destroy(r.beam); destroy(r.attachment) end
    for _,object in ipairs(app.objects) do destroy(object) end
    if app.window then pcall(function() app.window:Unload() end) end
    if env.BaconHubV3 == app then env.BaconHubV3=nil end
end
local function make(class, props, parent)
    local obj=Instance.new(class)
    for key,value in pairs(props) do obj[key]=value end
    obj.Parent=parent
    return obj
end
local function createOverlay()
    local parent=localPlayer:FindFirstChildOfClass('PlayerGui')
    if type(gethui)=='function' then local ok,p=pcall(gethui); if ok and p then parent=p end end
    if not parent then error('No UI parent available') end
    gui=own(make('ScreenGui',{Name='BaconV3Overlay',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=100,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},parent))
    ring=make('Frame',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromOffset(200,200),BackgroundTransparency=1,Visible=false},gui)
    make('UICorner',{CornerRadius=UDim.new(1,0)},ring)
    make('UIStroke',{Thickness=1.5,Color=S.fovColor},ring)
end
safe('FOV overlay',createOverlay)
local ok,Rayfield=bounded('Gen2 download',12,function()
    local source=game:HttpGet('https://sirius.menu/gen2')
    local compiled,err=loadstring(source)
    if not compiled then error(err) end
    return compiled -- do not execute a late HTTP response
end)
if ok then ok,Rayfield=bounded('Gen2 initialization',12,Rayfield) end
if not ok or not Rayfield or not app.alive then
    log('ERROR',Rayfield or 'Gen2 unavailable')
    app.Unload(); return
end
local fileSupport=type(readfile)=='function' and type(writefile)=='function' and type(isfile)=='function'
ok,app.window=bounded('CreateWindow',12,function()
    return Rayfield:CreateWindow({name='🥓 培根腳本中心 V3',subtitle='Gen2 • by QAQ0722',
        sidebarLayout=true,showName='培根 V3',theme='default',
        configuration=fileSupport and {autoSave=true,autoLoad=true,
            customFolder='BaconScripts',fileName='BaconHubV3_Gen2'} or nil})
end)
if not ok or not app.window or not app.alive then
    if ok and type(app.window)=='table' then pcall(function() app.window:Unload() end) end
    log('ERROR',app.window or 'CreateWindow failed'); app.window=nil; app.Unload(); return
end
log('OK','Rayfield Gen2 window created')
if not fileSupport then log('WARN','Configuration saving disabled: file API unavailable') end
local W=app.window
local function humanoid()
    local r=app.records[localPlayer]; return r and r.humanoid
end
local function applyMovement()
    local h=humanoid()
    if not h then return end
    if not humOriginal[h] then humOriginal[h]={speed=h.WalkSpeed,jump=h.JumpPower,use=h.UseJumpPower} end
    if S.speed then h.WalkSpeed=S.speed end
    if S.jump then h.UseJumpPower=true; h.JumpPower=S.jump end
end
restoreHumanoid=function()
    for h,v in pairs(humOriginal) do if h.Parent then
        h.WalkSpeed=v.speed; h.JumpPower=v.jump; h.UseJumpPower=v.use
    end end
end
local function visualColor() return S.rgb and Color3.fromHSV((os.clock()%5)/5,1,1) or S.color end
local refreshAll
local function refresh(r)
    if r.player==localPlayer then return end
    local char,root=r.character,r.root
    if not char then return end
    if S.esp then
        if not r.highlight then r.highlight=make('Highlight',{Name='BaconV3Highlight',Adornee=char,
            FillTransparency=.5,OutlineColor=Color3.new(1,1,1),DepthMode=Enum.HighlightDepthMode.AlwaysOnTop},char) end
        r.highlight.FillColor=visualColor()
    else destroy(r.highlight); r.highlight=nil end
    local localRecord=app.records[localPlayer]
    local localRoot=localRecord and localRecord.root
    if S.tracer and root and localRoot then
        if not r.attachment then r.attachment=make('Attachment',{Name='BaconV3TracerEnd'},root) end
        if not localRecord.attachment then localRecord.attachment=make('Attachment',{Name='BaconV3TracerStart'},localRoot) end
        if not r.beam then r.beam=make('Beam',{Name='BaconV3Beam',Width0=.1,Width1=.1,FaceCamera=true},char) end
        r.beam.Attachment0=localRecord.attachment; r.beam.Attachment1=r.attachment
        r.beam.Color=ColorSequence.new(visualColor())
    else destroy(r.beam); destroy(r.attachment); r.beam=nil; r.attachment=nil end
end
refreshAll=function()
    for _,r in pairs(app.records) do refresh(r) end
    local r=app.records[localPlayer]
    if r and not S.tracer then destroy(r.attachment); r.attachment=nil end
end
local function clearCharacter(r)
    disconnect(r.charConnections)
    destroy(r.highlight); destroy(r.beam); destroy(r.attachment)
    r.highlight=nil; r.beam=nil; r.attachment=nil; r.character=nil
    r.root=nil; r.head=nil; r.humanoid=nil; r.parts={}
end
local function bindCharacter(r,char)
    clearCharacter(r); r.character=char
    local function rescan()
        local newRoot=char:FindFirstChild('HumanoidRootPart')
        if r.root~=newRoot then destroy(r.attachment); r.attachment=nil end
        r.root=newRoot; r.head=char:FindFirstChild('Head')
        r.humanoid=char:FindFirstChildOfClass('Humanoid')
        table.clear(r.parts)
        for _,obj in ipairs(char:GetDescendants()) do if obj:IsA('BasePart') then table.insert(r.parts,obj) end end
        if r.player==localPlayer then applyMovement() end
        refreshAll()
    end
    rescan()
    connect(char.DescendantAdded,function(obj)
        if obj:IsA('BasePart') or obj:IsA('Humanoid') then rescan() end
    end,r.charConnections)
    connect(char.DescendantRemoving,function(obj)
        if obj:IsA('BasePart') or obj:IsA('Humanoid') then task.defer(function()
            if app.alive and r.character==char then rescan() end
        end) end
    end,r.charConnections)
end
local function addPlayer(p)
    if app.records[p] then return end
    local r={player=p,connections={},charConnections={},parts={}}
    app.records[p]=r
    connect(p.CharacterAdded,function(char) bindCharacter(r,char) end,r.connections)
    connect(p.CharacterRemoving,function()
        if p==localPlayer then restoreCollision() end
        clearCharacter(r); refreshAll()
    end,r.connections)
    if p.Character then bindCharacter(r,p.Character) end
end
connect(Players.PlayerAdded,addPlayer)
connect(Players.PlayerRemoving,function(p)
    local r=app.records[p]
    if r then clearCharacter(r); disconnect(r.connections); app.records[p]=nil end
end)
for _,p in ipairs(Players:GetPlayers()) do addPlayer(p) end
log('OK','Player/character cache initialized')

local TweenService=game:GetService('TweenService')
local selectedPlayer,refreshPlayerList
local action
local function stopPlayerAction()
    local old=action; action=nil
    if not old then return end
    if old.tween then old.tween:Cancel() end
    if old.track then safe('Stop action animation',function() old.track:Stop(); old.track:Destroy() end) end
    destroy(old.animation); destroy(old.spin)
    for part,v in pairs(old.parts or {}) do
        if part.Parent then safe('Restore action part',function()
            if S.noclip then part.CanCollide=false else part.CanCollide=v.collide end
            part.AssemblyLinearVelocity=v.linear; part.AssemblyAngularVelocity=v.angular
        end) end
    end
    if old.fling and old.root and old.root.Parent and old.root==((app.records[localPlayer] or {}).root) then
        safe('Restore position',function() old.root.CFrame=old.origin end)
    end
end
app.StopPlayerAction=stopPlayerAction
local function validRoots(p)
    local me=app.records[localPlayer]; local other=app.records[p]
    if not me or not me.root or not me.root.Parent or not me.humanoid or me.humanoid.Health<=0 then return nil end
    if not other or not other.root or not other.root.Parent or not other.humanoid or other.humanoid.Health<=0 then return nil end
    return me.root,other.root,me.humanoid
end
local function playerNames()
    local names={}
    for p in pairs(app.records) do if p~=localPlayer then table.insert(names,p.Name) end end
    table.sort(names)
    return names
end
local function teleportSelected()
    local root,target=validRoots(selectedPlayer)
    if not root then notify('請選擇玩家，並等待雙方角色生成'); return end
    stopPlayerAction(); root.CFrame=target.CFrame*CFrame.new(0,0,3)
end
local offsets={
    ['操人']={y=0,a=1.2,b=2.2,flip=false},
    ['被操']={y=0,a=-2.5,b=-1.3,flip=false},
    ['口交']={y=3.5,a=1.2,b=2,flip=true},
    ['被口交']={y=-1.8,a=1.2,b=2,flip=true}}
local function startPlayerAction(mode)
    local all=mode=='甩飛全部人'
    local root,target,h=validRoots(selectedPlayer)
    if all then
        local r=app.records[localPlayer]
        root=r and r.root; h=r and r.humanoid
        if not h or h.Health<=0 then root=nil end
    end
    if not root or (not all and not target) then notify('請選擇玩家，並等待雙方角色生成'); return end
    stopPlayerAction()
    local a={mode=mode,root=root,character=localPlayer.Character,target=selectedPlayer,
        elapsed=0,phase=1,origin=root.CFrame,parts={},fling=mode=='甩飛玩家' or all}
    action=a
    local success=safe('Start '..mode,function()
        if a.fling then
            a.spin=make('BodyAngularVelocity',{Name='BaconV3PlayerSpin',
                MaxTorque=Vector3.new(1e9,1e9,1e9),P=1e9,
                AngularVelocity=Vector3.new(0,all and 8000 or 5000,0)},root)
            if all then
                a.targets={}
                for p in pairs(app.records) do if p~=localPlayer then table.insert(a.targets,p) end end
                table.sort(a.targets,function(p,q) return p.UserId<q.UserId end)
                a.index=1; a.target=a.targets[1]
                if not a.target then stopPlayerAction(); notify('目前沒有其他玩家'); return end
            end
        else

            safe('V2 action animation',function()
                a.animation=make('Animation',{AnimationId='rbxassetid://189854234'})
                local animator=h:FindFirstChildOfClass('Animator')
                a.track=animator and animator:LoadAnimation(a.animation) or h:LoadAnimation(a.animation)
                a.track:Play()
            end)
        end
    end)
    if not success then stopPlayerAction() end
end
local function updatePlayerAction(dt)
    local a=action
    if not a then return end
    local me=app.records[localPlayer]
    if not me or me.character~=a.character or me.root~=a.root or not me.humanoid or me.humanoid.Health<=0 then stopPlayerAction(); return end
    if a.mode=='甩飛全部人' then
        a.elapsed=a.elapsed+dt
        if a.elapsed>=1.5 then a.index=a.index+1; a.elapsed=0; a.target=a.targets[a.index] end
        while a.target and not validRoots(a.target) do
            a.index=a.index+1; a.elapsed=0; a.target=a.targets[a.index]
        end
        if not a.target then stopPlayerAction(); return end
    end
    local root,target=validRoots(a.target)
    if not root then stopPlayerAction(); return end
    if a.fling then
        for _,part in ipairs(me.parts) do if part.Parent then
            if not a.parts[part] then
                local originalCollide=collision[part]
                if originalCollide==nil then originalCollide=part.CanCollide end
                a.parts[part]={collide=originalCollide,
                    linear=part.AssemblyLinearVelocity,angular=part.AssemblyAngularVelocity}
                if S.noclip and collision[part]==nil then collision[part]=part.CanCollide end
            end
            part.CanCollide=false
            if a.mode=='甩飛全部人' then part.AssemblyLinearVelocity=Vector3.new(1000,1000,1000) end
        end end
        local speed=a.mode=='甩飛全部人' and 8000 or 5000
        root.CFrame=target.CFrame*CFrame.Angles(0,math.rad((os.clock()*speed)%360),0)
        if a.mode=='甩飛玩家' then root.AssemblyLinearVelocity=Vector3.new(500,500,500) end
    else
        a.elapsed=a.elapsed-dt
        if a.elapsed<=0 then
            local spec=offsets[a.mode]
            local base=target.CFrame
            if spec.flip then base=base*CFrame.Angles(0,math.pi,0) end
            local z=a.phase==1 and spec.a or spec.b
            if a.tween then a.tween:Cancel() end
            a.tween=TweenService:Create(root,TweenInfo.new(.15,Enum.EasingStyle.Linear),
                {CFrame=base*CFrame.new(0,spec.y,z)})
            a.tween:Play(); a.elapsed=.15; a.phase=a.phase==1 and 2 or 1
        end
    end
end
local function buildPlayerTools(tab)
    tab:CreateSection({name='目標選擇'})
    local selectedText=tab:CreateText({name='目前目標',text='尚未選擇玩家'})
    local rows={}
    local query=''

    app.ClosePlayerPicker=function() table.clear(rows) end
    refreshPlayerList=function()
        if not app.alive then return end
        if selectedPlayer and not app.records[selectedPlayer] then
            selectedPlayer=nil; stopPlayerAction(); selectedText:Set('尚未選擇玩家')
        end
        local live={}
        for p in pairs(app.records) do if p~=localPlayer then live[p.UserId]=p end end
        for id,entry in pairs(rows) do
            if not live[id] then
                if type(entry.handle.Remove)=='function' then entry.handle:Remove(); rows[id]=nil
                else entry.player=nil; entry.handle:Lock('玩家已離開') end
            end
        end
        for id,p in pairs(live) do
            local entry=rows[id]
            if not entry then
                entry={player=p}; rows[id]=entry
                entry.handle=tab:CreateButton({name=p.DisplayName..' (@'..p.Name..')',
                    icon='rbxthumb://type=AvatarHeadShot&id='..p.UserId..'&w=150&h=150',
                    callback=function()
                        local chosen=entry.player
                        if not app.alive or not chosen or not app.records[chosen] then return end
                        if selectedPlayer~=chosen then stopPlayerAction() end
                        selectedPlayer=chosen; selectedText:Set(chosen.DisplayName..' (@'..chosen.Name..')')
                    end})
            end
            entry.player=p
            if query=='' or p.Name:lower():find(query,1,true) or p.DisplayName:lower():find(query,1,true) then
                entry.handle:Unlock()
            else entry.handle:Lock('不符合搜尋') end
        end
        local ordered={}
        for _,entry in pairs(rows) do table.insert(ordered,entry) end
        table.sort(ordered,function(a,b)
            if (a.player~=nil)~=(b.player~=nil) then return a.player~=nil end
            local ap,bp=a.player,b.player
            if not ap or not bp then return false end
            return (ap.DisplayName..ap.Name):lower()<(bp.DisplayName..bp.Name):lower()
        end)
        for i,entry in ipairs(ordered) do entry.handle:MoveTo(3+i) end
    end
    tab:CreateInput({name='搜尋玩家',placeholder='顯示名稱或帳號名稱',value='',forgetState=true,
        callback=function(value) query=tostring(value):lower(); refreshPlayerList() end})
    refreshPlayerList()
    local function button(name,fn)
        tab:CreateButton({name=name,callback=function() if app.alive then safe(name,fn) end end})
    end
    button('傳送到目標玩家',teleportSelected)
    tab:CreateSection({name='玩家動作'})
    for _,name in ipairs({'操人','被操','口交','被口交','甩飛玩家','甩飛全部人'}) do
        local mode=name
        button(mode,function() startPlayerAction(mode) end)
    end
    button('停止動作 / 關閉動畫',stopPlayerAction)
    connect(Run.Heartbeat,function(dt)
        if action then
            local success=safe('Player action',function() updatePlayerAction(dt) end)
            if not success then stopPlayerAction() end
        end
    end)
    connect(Players.PlayerAdded,function() task.defer(function() if app.alive then refreshPlayerList() end end) end)
    connect(Players.PlayerRemoving,function(p)
        if selectedPlayer==p then selectedPlayer=nil; stopPlayerAction(); selectedText:Set('尚未選擇玩家') end
        refreshPlayerList()
    end)
    connect(localPlayer.CharacterRemoving,stopPlayerAction)
end

local remoteBusy={}
local function remote(name,url)
    if remoteBusy[name] then return end
    remoteBusy[name]=true
    task.spawn(function()
        local success,source=bounded(name..' download',10,function() return game:HttpGet(url) end)
        if success and app.alive then
            success,source=bounded(name..' execution',10,function()
                local fn,err=loadstring(source); if not fn then error(err) end; return fn()
            end)
        end
        remoteBusy[name]=nil
        if app.alive then if success then notify(name..' 已載入') else log('ERROR',source); notify(name..' 載入失敗，請看執行狀態') end end
    end)
end
local function buildUI()
    local home=W:CreateTab({name='培根中心',icon=4483362458})
    local info=W:CreateTab({name='使用者資訊',icon=4483362458})
    local client=W:CreateTab({name='客戶端',icon=4483362458})
    local playerTools=W:CreateTab({name='玩家',icon=4483362458})
    local visuals=W:CreateTab({name='視覺',icon=4483362458})
    local aim=W:CreateTab({name='自動瞄準',icon=4483362458})
    local settings=W:CreateTab({name='設定',icon=4483362458})
    local logs=W:CreateTab({name='執行狀態',icon=4483362458})
    buildPlayerTools(playerTools)
    console=logs:CreateConsole({name='Bacon V3 Console',height=230,follow=true,maxLines=200,text=table.concat(app.logs,'\n')})
    local function text(tab,name,body) return tab:CreateText({name=name,text=tostring(body)}) end
    local function button(tab,name,fn) return tab:CreateButton({name=name,callback=function() if app.alive then safe(name,fn) end end}) end
    local function toggle(tab,name,flag,value,fn,temporary)
        return tab:CreateToggle({name=name,flag=flag,value=value,forgetState=temporary or false,
            callback=function(v) if app.alive then safe(name,function() fn(v) end) end end})
    end
    local function slider(tab,name,flag,range,value,step,fn)
        return tab:CreateSlider({name=name,flag=flag,range=range,value=value,increment=step,
            callback=function(v) if app.alive then safe(name,function() fn(v) end) end end})
    end
    local function color(tab,name,flag,value,fn)
        return tab:CreateColorPicker({name=name,flag=flag,color=value,
            callback=function(v) if app.alive then safe(name,function() fn(v) end) end end})
    end
    text(home,'🥓 培根腳本中心 V3','作者：QAQ0722\n這次把培根重新整理了一遍，還是熟悉的 V3，希望大家用得順手。')
    text(home,'感謝每一個使用培根腳本中心的玩家','感謝每一位選擇培根腳本中心的玩家，從最初的嘗試到 V3 的重新出發，謝謝你們一路陪伴。每一份支持、建議與問題回報，都讓培根變得更好。🥓')
    text(home,'Discord','https://discord.gg/u3d6Eszk3s')
    button(home,'複製 Discord 群連結',function()
        if type(setclipboard)=='function' then setclipboard('https://discord.gg/u3d6Eszk3s'); notify('連結已複製') else notify('不支援剪貼簿，請手動複製首頁連結') end
    end)
    text(info,'顯示名稱',localPlayer.DisplayName); text(info,'帳號名稱',localPlayer.Name)
    text(info,'UserID',localPlayer.UserId); text(info,'帳號年齡',localPlayer.AccountAge..' 天')
    local executor='未知'
    safe('Executor detection',function()
        if type(identifyexecutor)=='function' then local n,v=identifyexecutor(); executor=tostring(n)..' '..tostring(v or '')
        elseif type(getexecutorname)=='function' then executor=tostring(getexecutorname()) end
    end)
    text(info,'執行器',executor); text(info,'PlaceID',game.PlaceId)
    text(info,'JobId',game.JobId~='' and game.JobId or '本地伺服器')
    local ping=text(info,'網路延遲','等待讀取…')
    local friends=text(info,'好友數量','點擊下方按鈕讀取')
    local friendsBusy=false
    button(info,'讀取完整好友數量',function()
        if friendsBusy then return end; friendsBusy=true
        task.spawn(function()
            local success,count=bounded('Friends pagination',10,function()
                local pages=Players:GetFriendsAsync(localPlayer.UserId); local total=0
                repeat
                    total=total+#pages:GetCurrentPage()
                    if pages.IsFinished then break end
                    pages:AdvanceToNextPageAsync()
                until not app.alive
                return total
            end)
            friendsBusy=false
            if app.alive then friends:Set(success and (tostring(count)..' 人') or '讀取失敗／超時'); if not success then log('WARN',count) end end
        end)
    end)
    task.spawn(function()
        while app.alive do
            if W.unloaded then app.Unload(); break end
            local success,value=pcall(function() return localPlayer:GetNetworkPing()*1000 end)
            if success then ping:Set(string.format('%.1f ms（API 回傳值）',value)) end
            task.wait(1)
        end
    end)
    slider(client,'玩家血量（客戶端）','HealthSlider',{0,100},100,1,function(v) local h=humanoid(); if h then h.Health=v end end)
    local movementInputs={}
    local function numberInput(name,flag,default,min,max,fn)
        local handle=client:CreateInput({name=name,flag=flag,numeric=true,value=tostring(default),placeholder=tostring(default),
            callback=function(v)
                if not app.alive then return end
                local n=tonumber(v)
                if not n or n~=n or math.abs(n)==math.huge or n<min or n>max then notify('請輸入 '..min..'～'..max..' 的有效數字'); return end
                safe(name,function() fn(n) end)
            end})
        movementInputs[flag]=handle
    end
    numberInput('自訂速度','WalkSpeed',16,0,1000,function(v) S.speed=v; applyMovement() end)
    numberInput('自訂跳躍力','JumpPower',50,0,1000,function(v) S.jump=v; applyMovement() end)
    numberInput('自訂重力','Gravity',defaults.gravity,0,2000,function(v) workspace.Gravity=v end)
    button(client,'恢復速度、跳躍力、重力',function()
        S.speed=nil; S.jump=nil; restoreHumanoid(); workspace.Gravity=defaults.gravity
        local h=humanoid(); local original=h and humOriginal[h]
        movementInputs.WalkSpeed:Set(tostring(original and original.speed or 16),true)
        movementInputs.JumpPower:Set(tostring(original and original.jump or 50),true)
        movementInputs.Gravity:Set(tostring(defaults.gravity),true)
        notify('已恢復原始數值')
    end)
    toggle(client,'無限跳','InfiniteJump',false,function(v) S.infinite=v end)
    toggle(client,'穿牆','MysteryFeatureToggle',false,function(v) S.noclip=v
        if v and action then
            for part,original in pairs(action.parts) do
                if collision[part]==nil then collision[part]=original.collide end
            end
        elseif not v then restoreCollision() end end)
    button(client,'飛行',function() remote('飛行','https://pastebin.com/raw/feYeCwiR') end)
    button(client,'自由相機',function() remote('自由相機','https://raw.githubusercontent.com/QAQ0722/BaconHub-V3.0-/refs/heads/main/%E8%87%AA%E7%94%B1%E7%9B%B8%E6%A9%9F.lua') end)
    toggle(visuals,'玩家 ESP','PlayerEspToggle',false,function(v) S.esp=v; refreshAll() end)
    toggle(visuals,'追蹤線','PlayerTracerToggle',false,function(v) S.tracer=v; refreshAll() end)
    color(visuals,'顏色設定','EspColorPicker',S.color,function(v) S.color=v; refreshAll() end)
    toggle(visuals,'RGB','RgbEspToggle',false,function(v) S.rgb=v; refreshAll() end)
    toggle(visuals,'夜視','NightVision',false,function(v)
        S.night=v; Lighting.Ambient=v and Color3.new(1,1,1) or defaults.ambient
        Lighting.OutdoorAmbient=v and Color3.new(1,1,1) or defaults.outdoor
        Lighting.ClockTime=v and 12 or defaults.time
    end)
    button(visuals,'培根光影',function() remote('培根光影','https://raw.githubusercontent.com/QAQ0722/BaconHub-V3.0-/refs/heads/main/%E5%9F%B9%E6%A0%B9%E5%85%89%E5%BD%B1.lua') end)
    text(aim,'注意：部分遊戲無法正常使用','自動瞄準可能因遊戲的角色、鏡頭或射擊機制而出現偏移，實際效果依遊戲而異。')
    toggle(aim,'啟用自動瞄準','AimbotToggle',false,function(v) S.aim=v end)
    toggle(aim,'手機持續瞄準（免右鍵）','TouchAim',false,function(v) S.touchAim=v end,true)
    text(aim,'操作方式','電腦：按住滑鼠右鍵。手機：啟用自動瞄準，再開啟持續瞄準。圓心固定為畫面中心。')
    aim:CreateDropdown({name='瞄準部位',flag='AimPartDropdown',options={'Head','HumanoidRootPart'},value='Head',
        callback=function(v) if v=='Head' or v=='HumanoidRootPart' then S.part=v end end})
    slider(aim,'平滑度（1 最快）','AimbotSmoothSlider',{1,10},5,.5,function(v) S.smooth=v end)
    toggle(aim,'顯示 FOV 範圍環','FovCircleToggle',false,function(v) S.fov=v; if ring then ring.Visible=v end end)
    slider(aim,'FOV 半徑（px）','FovRadiusSlider',{30,500},100,5,function(v) S.radius=v; if ring then ring.Size=UDim2.fromOffset(v*2,v*2) end end)
    color(aim,'FOV 環顏色','FovColorPicker',S.fovColor,function(v) S.fovColor=v end)
    toggle(aim,'牆壁檢測','WallCheckToggle',false,function(v) S.wall=v end)
    toggle(aim,'隊伍檢測','TeamCheckToggle',false,function(v) S.team=v end)
    settings:CreateDropdown({name='介面主題',flag='Theme',options={'default','cobalt','ember','amethyst','frost','rose'},value='default',
        callback=function(v) if app.alive then safe('Theme',function() W:ChangeTheme(v) end) end end})
    toggle(settings,'防閒置（不移除遊戲事件）','AntiIdle',false,function(v) S.antiIdle=v end)
    button(settings,'儲存設定',function() notify(W:Save() and '已儲存設定' or '儲存失敗／不支援檔案 API') end)
    button(settings,'載入設定',function() notify(W:Load() and '已載入設定' or '找不到設定／不支援檔案 API') end)
    button(settings,'收起介面',function() W:Hide() end)
    button(settings,'卸載培根 V3',app.Unload)
    button(logs,'複製日誌',function() if not console:Copy() then notify('不支援剪貼簿') end end)
    button(logs,'清空日誌',function() table.clear(app.logs); console:Clear() end)
end
ok=safe('Build Gen2 UI',buildUI)
if not ok then app.Unload(); return end
connect(Input.JumpRequest,function()
    local h=humanoid(); if S.infinite and h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
connect(localPlayer.Idled,function()
    if S.antiIdle then safe('AntiIdle',function()
        local virtual=game:GetService('VirtualUser'); virtual:CaptureController(); virtual:ClickButton2(Vector2.new())
    end) end
end)
connect(Run.Stepped,function()
    if not S.noclip then return end
    local r=app.records[localPlayer]
    if r then for _,part in ipairs(r.parts) do if part.Parent then
        if collision[part]==nil then collision[part]=part.CanCollide end
        part.CanCollide=false
    end end end
end)
local rayParams=RaycastParams.new()
rayParams.FilterType=Enum.RaycastFilterType.Exclude; rayParams.IgnoreWater=true
local target,targetRecord,aimElapsed,rgbElapsed=nil,nil,0,0
local mouseChanged=false
local function closest(camera)
    local best,bestRecord,distance=nil,nil,S.radius
    local center=camera.ViewportSize/2
    for p,r in pairs(app.records) do
        local part=r.root
        if S.part=='Head' then part=r.head end
        local teammate=S.team and not localPlayer.Neutral and not p.Neutral and localPlayer.Team and p.Team==localPlayer.Team
        if p~=localPlayer and not teammate and part and part.Parent and r.humanoid and r.humanoid.Health>0 then
            local point,visible=camera:WorldToViewportPoint(part.Position)
            if visible then
                local delta=(Vector2.new(point.X,point.Y)-center).Magnitude
                if delta<distance then
                    local clear=true
                    if S.wall then
                        rayParams.FilterDescendantsInstances={localPlayer.Character or localPlayer,r.character}
                        clear=workspace:Raycast(camera.CFrame.Position,part.Position-camera.CFrame.Position,rayParams)==nil
                    end
                    if clear then best=part; bestRecord=r; distance=delta end
                end
            end
        end
    end
    return best,bestRecord
end
connect(Run.RenderStepped,function(dt)
    if not app.alive then return end
    local camera=workspace.CurrentCamera
    if not camera then return end
    rgbElapsed=rgbElapsed+dt
    if rgbElapsed>=.1 then
        rgbElapsed=0
        if S.rgb and (S.esp or S.tracer) then
            local c=visualColor(); local sequence=ColorSequence.new(c)
            for _,r in pairs(app.records) do
                if r.highlight then r.highlight.FillColor=c end
                if r.beam then r.beam.Color=sequence end
            end
        end
        if ring and S.fov then ring.UIStroke.Color=S.rgb and visualColor() or S.fovColor end
    end
    local active=S.aim and (S.touchAim or Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
        and not Input:GetFocusedTextBox()
    if not active then
        target=nil; targetRecord=nil; aimElapsed=0
        if mouseChanged then Input.MouseIconEnabled=defaults.mouse; mouseChanged=false end
        return
    end
    if not mouseChanged then Input.MouseIconEnabled=false; mouseChanged=true end
    aimElapsed=aimElapsed+dt
    if aimElapsed>=1/20 then aimElapsed=0; target,targetRecord=closest(camera) end
    if target and target.Parent then
        local r=targetRecord
        if not r or not r.humanoid or r.humanoid.Health<=0 then target=nil; return end
        local position=camera.CFrame.Position
        if (target.Position-position).Magnitude>.001 then
            local alpha=S.smooth<=1 and 1 or (1-(1-1/S.smooth)^(math.min(dt,.1)*60))
            camera.CFrame=camera.CFrame:Lerp(CFrame.lookAt(position,target.Position),alpha)
        end
    end
end)
log('OK','Bacon Hub V3 ready')
