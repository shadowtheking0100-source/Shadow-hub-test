--[[
    SHADOW HUB
    Made by Shadow
    Version: 2.1.0
]]

-- Load library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Services
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")

local plr   = Players.LocalPlayer
local mouse = plr:GetMouse()

-- State: Player
local infJumpOn   = false
local noclipOn    = false
local immortalOn  = false
local antiAFKOn   = false
local noclipConn  = nil

-- State: Fly
local flyOn      = false
local flyBV      = nil
local flyBG      = nil
local flyMobGui  = nil
local flyMobUp   = false
local flyMobDn   = false
local flySpeed   = 56

-- State: Combat
local killAuraOn    = false
local killAuraRange = 15
local killAuraConn  = nil
local autoClickOn   = false
local autoClickConn = nil
local silentAimOn   = false
local antiKBOn      = false
local reachOn       = false
local reachRange    = 30
local reachConn     = nil
local triggerBotOn  = false
local speedHackOn   = false

-- State: Visual
local espObjs    = {}
local espColor   = Color3.fromRGB(130, 50, 255)
local chamsOn    = false
local xhairGui   = nil
local xhairColor = Color3.fromRGB(130, 50, 255)

-- State: Baseplate
local baseplate     = workspace:FindFirstChild("Baseplate")
local origBPColor   = (baseplate and baseplate:IsA("BasePart")) and baseplate.Color or Color3.fromRGB(106,127,63)
local chosenBPColor = origBPColor
local rainbowBPOn   = false

-- State: Lighting originals
local origBright = Lighting.Brightness
local origAmb    = Lighting.Ambient
local origOut    = Lighting.OutdoorAmbient
local origFogEnd = Lighting.FogEnd

-- State: Teleport to player
local selectedTPPlayer = "None"

-- State: FPS / Ping
local fpsVal    = 0
local pingVal   = 0
local _fpsCount = 0
local _fpsTick  = tick()

RunService.RenderStepped:Connect(function()
    _fpsCount = _fpsCount + 1
    if tick() - _fpsTick >= 1 then
        fpsVal    = _fpsCount
        _fpsCount = 0
        _fpsTick  = tick()
    end
end)

RunService.Heartbeat:Connect(function()
    pcall(function() pingVal = math.floor(plr:GetNetworkPing() * 1000) end)
end)

-- Stat widgets
local _statWidgets = {}

-- Helpers
local function Hum()
    return plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
end
local function Root()
    return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
end
local function Notify(title, body, dur)
    Fluent:Notify({ Title = title, Content = body, Duration = dur or 3 })
end
local function SetBP(col)
    local bp = workspace:FindFirstChild("Baseplate")
    if bp and bp:IsA("BasePart") then bp.Color = col end
end
local function GetPlayerNames()
    local t = { "None" }
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then table.insert(t, p.Name) end
    end
    return t
end

-- Floating stat widget (small draggable pill with live value + X button)
local function MakeStatWidget(id, label, getFn, col)
    -- Second press closes it
    if _statWidgets[id] then
        pcall(function() _statWidgets[id]:Destroy() end)
        _statWidgets[id] = nil
        return
    end

    local guiParent
    pcall(function() guiParent = game:GetService("CoreGui") end)
    if not guiParent then guiParent = plr:WaitForChild("PlayerGui", 10) end

    local sg = Instance.new("ScreenGui")
    sg.Name = "SHStat_" .. id
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 700
    sg.IgnoreGuiInset = true
    sg.Parent         = guiParent
    _statWidgets[id]  = sg

    local frame = Instance.new("Frame", sg)
    frame.Size             = UDim2.new(0, 130, 0, 28)
    -- Stack widgets vertically based on how many are open
    local yOffset = 14
    for _ in pairs(_statWidgets) do yOffset = yOffset + 34 end
    yOffset = yOffset - 34  -- correct for just-added one
    frame.Position         = UDim2.new(0, 10, 0, yOffset)
    frame.BackgroundColor3 = Color3.fromRGB(10, 5, 22)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel  = 0
    frame.ZIndex           = 10
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 20)
    local sk = Instance.new("UIStroke", frame)
    sk.Color     = col or Color3.fromRGB(130, 50, 255)
    sk.Thickness = 1.5

    local titleLbl = Instance.new("TextLabel", frame)
    titleLbl.Size                 = UDim2.new(0, 38, 1, 0)
    titleLbl.Position             = UDim2.new(0, 7, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                 = label
    titleLbl.Font                 = Enum.Font.GothamBlack
    titleLbl.TextSize             = 10
    titleLbl.TextColor3           = col or Color3.fromRGB(160, 90, 255)
    titleLbl.TextXAlignment       = Enum.TextXAlignment.Left
    titleLbl.BorderSizePixel      = 0
    titleLbl.ZIndex               = 11

    local valLbl = Instance.new("TextLabel", frame)
    valLbl.Size                   = UDim2.new(1, -62, 1, 0)
    valLbl.Position               = UDim2.new(0, 46, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text                   = "..."
    valLbl.Font                   = Enum.Font.GothamBold
    valLbl.TextSize               = 10
    valLbl.TextColor3             = Color3.fromRGB(220, 220, 220)
    valLbl.TextXAlignment         = Enum.TextXAlignment.Left
    valLbl.BorderSizePixel        = 0
    valLbl.ZIndex                 = 11

    local closeBtn = Instance.new("TextButton", frame)
    closeBtn.Size              = UDim2.new(0, 18, 0, 18)
    closeBtn.Position          = UDim2.new(1, -21, 0.5, -9)
    closeBtn.BackgroundColor3  = Color3.fromRGB(220, 50, 50)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.Text              = "x"
    closeBtn.Font              = Enum.Font.GothamBold
    closeBtn.TextSize          = 9
    closeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
    closeBtn.AutoButtonColor   = false
    closeBtn.BorderSizePixel   = 0
    closeBtn.ZIndex            = 12
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 9)

    closeBtn.MouseButton1Click:Connect(function()
        _statWidgets[id] = nil
        sg:Destroy()
    end)

    -- Drag
    local dragging  = false
    local dragStart = Vector2.zero
    local frmStart  = Vector2.zero
    frame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = Vector2.new(inp.Position.X, inp.Position.Y)
            frmStart  = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            local d = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
            frame.Position = UDim2.new(0, frmStart.X + d.X, 0, frmStart.Y + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Live update every 0.5 s
    local timer = 0
    local conn; conn = RunService.Heartbeat:Connect(function(dt)
        if not sg.Parent then conn:Disconnect(); return end
        timer = timer + dt
        if timer < 0.5 then return end
        timer = 0
        local ok, v = pcall(getFn)
        if ok then valLbl.Text = tostring(v) end
    end)
end

-- ================================================================
-- CREATE WINDOW
-- ================================================================
local Window = Fluent:CreateWindow({
    Title       = "Shadow Hub",
    SubTitle    = "Premium  |  by Shadow",
    TabWidth    = 130,
    Size        = UDim2.fromOffset(620, 500),
    Acrylic     = false,
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
})

-- ================================================================
-- TAB: HOME
-- ================================================================
local Home = Window:AddTab({ Title = "Home", Icon = "home" })

Home:AddParagraph({
    Title   = "Shadow Hub  v2.1.0",
    Content = "Welcome, " .. plr.Name .. "!\n\nUse the tabs to navigate.\nPress RightControl or RightShift to toggle the UI.\nYour settings save automatically.",
})

Home:AddButton({ Title = "Show FPS Widget",      Description = "Opens a small draggable FPS counter. Press again to close.",
    Callback = function() MakeStatWidget("fps", "FPS", function() return tostring(fpsVal) end, Color3.fromRGB(34,197,94)) end })
Home:AddButton({ Title = "Show Ping Widget",     Description = "Opens a small draggable Ping counter. Press again to close.",
    Callback = function() MakeStatWidget("ping","PING",function() return tostring(pingVal).." ms" end, Color3.fromRGB(6,182,212)) end })
Home:AddButton({ Title = "Show Position Widget", Description = "Opens a small draggable XYZ tracker. Press again to close.",
    Callback = function()
        MakeStatWidget("pos","POS",function()
            local r = Root(); if not r then return "--" end
            local p = r.Position
            return math.floor(p.X)..","..math.floor(p.Y)..","..math.floor(p.Z)
        end, Color3.fromRGB(130,50,255))
    end })
Home:AddButton({ Title = "Show Gravity Widget",  Description = "Opens a small draggable gravity display. Press again to close.",
    Callback = function() MakeStatWidget("grav","GRAV",function() return tostring(math.floor(workspace.Gravity)) end, Color3.fromRGB(234,179,8)) end })
Home:AddButton({ Title = "Close All Widgets",    Description = "Closes every open stat widget",
    Callback = function()
        for k, g in pairs(_statWidgets) do pcall(function() g:Destroy() end); _statWidgets[k] = nil end
        Notify("Widgets","All closed.",2)
    end })

Home:AddButton({ Title = "Speed Boost  (WalkSpeed 100)", Description = "Set speed to 100 instantly",
    Callback = function() local h=Hum(); if h then h.WalkSpeed=100 end; Notify("Speed","WalkSpeed → 100",2) end })
Home:AddButton({ Title = "Reset Character", Description = "Kill and respawn",
    Callback = function() local h=Hum(); if h then h.Health=0 end; Notify("Reset","Respawning…",2) end })
Home:AddButton({ Title = "Go to Spawn", Description = "Teleport to SpawnLocation",
    Callback = function()
        local sp=workspace:FindFirstChildOfClass("SpawnLocation"); local rt=Root()
        if sp and rt then rt.CFrame=sp.CFrame+Vector3.new(0,5,0); Notify("Teleport","At spawn.",2)
        else Notify("Teleport","No SpawnLocation found.",2) end
    end })
Home:AddButton({ Title = "Max Health", Description = "Restore full HP",
    Callback = function() local h=Hum(); if h then h.Health=h.MaxHealth end; Notify("Health","Full HP.",2) end })

-- ================================================================
-- TAB: PLAYER
-- ================================================================
local Player = Window:AddTab({ Title = "Player", Icon = "user" })

Player:AddSlider("WalkSpeed", {
    Title="Walk Speed", Description="Adjust movement speed  (default 16)",
    Min=16, Max=300, Default=16, Rounding=0,
    Callback=function(v) local h=Hum(); if h then h.WalkSpeed=v end end,
})
Player:AddSlider("JumpPower", {
    Title="Jump Power", Description="Adjust jump height  (default 50)",
    Min=50, Max=500, Default=50, Rounding=0,
    Callback=function(v) local h=Hum(); if h then h.UseJumpPower=true; h.JumpPower=v end end,
})
Player:AddSlider("GravitySlider", {
    Title="Gravity", Description="Adjust world gravity  (default 196)",
    Min=0, Max=400, Default=196, Rounding=0,
    Callback=function(v) workspace.Gravity=v end,
})

Player:AddToggle("InfiniteJump", {
    Title="Infinite Jump", Description="Jump again while airborne",
    Default=false, Callback=function(s) infJumpOn=s end,
})
UserInputService.JumpRequest:Connect(function()
    if infJumpOn then local h=Hum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)

Player:AddToggle("NoClipToggle", {
    Title="NoClip", Description="Walk through walls",
    Default=false, Callback=function(s)
        noclipOn=s
        if s then
            noclipConn=RunService.Stepped:Connect(function()
                if plr.Character then
                    for _,p in pairs(plr.Character:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide=false end
                    end
                end
            end)
            Notify("NoClip","Collision disabled.",2)
        else
            if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
            if plr.Character then
                for _,p in pairs(plr.Character:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide=true end
                end
            end
            Notify("NoClip","Collision restored.",2)
        end
    end,
})

Player:AddToggle("ImmortalToggle", {
    Title="Immortal Mode", Description="Health locked to maximum",
    Default=false, Callback=function(s)
        immortalOn=s
        RunService:UnbindFromRenderStep("SHImmortal")
        if s then
            RunService:BindToRenderStep("SHImmortal",50,function()
                local h=Hum(); if h then h.Health=h.MaxHealth end
            end)
            Notify("Immortal Mode","You cannot die.",2)
        else Notify("Immortal Mode","Disabled.",2) end
    end,
})

Player:AddToggle("AntiAFKToggle", {
    Title="Anti-AFK", Description="Prevents idle kick",
    Default=false, Callback=function(s)
        antiAFKOn=s
        if s then
            plr.Idled:Connect(function()
                if antiAFKOn then
                    pcall(function()
                        VirtualUser:Button2Down(Vector2.zero,CFrame.new())
                        task.wait(0.1)
                        VirtualUser:Button2Up(Vector2.zero,CFrame.new())
                    end)
                end
            end)
            Notify("Anti-AFK","Active.",3)
        end
    end,
})

-- Store original transparencies for perfect restore
local _origTransparency = {}

Player:AddButton({ Title="Make Invisible", Description="Hides your character",
    Callback=function()
        local char=plr.Character; if not char then return end
        _origTransparency={}
        for _,p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then
                _origTransparency[p]=p.Transparency
                p.Transparency=1
            end
        end
        local hrp=char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Transparency=1; hrp.CanCollide=true end
        Notify("Invisible","Character is now invisible.",3)
    end
})
Player:AddButton({ Title="Restore Visibility", Description="Restores all parts to original transparency",
    Callback=function()
        local char=plr.Character; if not char then return end
        for _,p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then
                p.Transparency = _origTransparency[p] ~= nil and _origTransparency[p] or 0
            end
        end
        -- Explicitly fix body parts to 0
        local solid={"Head","Torso","UpperTorso","LowerTorso","LeftArm","RightArm","LeftLeg","RightLeg",
                     "LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftHand","RightHand",
                     "LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot"}
        for _,name in ipairs(solid) do
            local part=char:FindFirstChild(name)
            if part and part:IsA("BasePart") then part.Transparency=0 end
        end
        -- HumanoidRootPart stays at 1 (its natural state)
        local hrp=char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Transparency=1 end
        _origTransparency={}
        Notify("Visible","Visibility fully restored.",2)
    end
})
Player:AddButton({ Title="Sit Down", Description="Force your character to sit",
    Callback=function() local h=Hum(); if h then h.Sit=true end end })
Player:AddButton({ Title="Low Gravity  (20)",  Callback=function() workspace.Gravity=20;  Notify("Gravity","20.",2) end })
Player:AddButton({ Title="Zero Gravity  (0)",  Callback=function() workspace.Gravity=0;   Notify("Gravity","0.",2)  end })
Player:AddButton({ Title="Reset Gravity (196)", Callback=function() workspace.Gravity=196; Notify("Gravity","196.",2) end })

-- ================================================================
-- TAB: FLY
-- ================================================================
local FlyTab = Window:AddTab({ Title = "Fly", Icon = "send" })

FlyTab:AddSlider("FlySpeedSlider", {
    Title="Fly Speed", Description="How fast you travel",
    Min=10, Max=250, Default=56, Rounding=0,
    Callback=function(v) flySpeed=v end,
})

local function BuildMobileButtons()
    local guiParent
    pcall(function() guiParent=game:GetService("CoreGui") end)
    if not guiParent then guiParent=plr:WaitForChild("PlayerGui",10) end
    local sg=Instance.new("ScreenGui")
    sg.Name="SHFlyMob"; sg.ResetOnSpawn=false; sg.DisplayOrder=800; sg.IgnoreGuiInset=true; sg.Parent=guiParent
    local function Btn(lbl,anchorX,key)
        local b=Instance.new("TextButton",sg)
        b.Size=UDim2.new(0,64,0,64); b.Position=UDim2.new(anchorX,anchorX>0.5 and -70 or 0,1,-88)
        b.AnchorPoint=Vector2.new(0,1); b.BackgroundColor3=Color3.fromRGB(16,8,36)
        b.BackgroundTransparency=0.15; b.Text=lbl; b.Font=Enum.Font.GothamBlack; b.TextSize=28
        b.TextColor3=Color3.fromRGB(160,90,255); b.AutoButtonColor=false; b.BorderSizePixel=0; b.ZIndex=801
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,14)
        local s=Instance.new("UIStroke",b); s.Color=Color3.fromRGB(130,50,255); s.Thickness=2
        if key=="up" then
            b.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then flyMobUp=true  end end)
            b.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then flyMobUp=false end end)
        else
            b.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then flyMobDn=true  end end)
            b.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then flyMobDn=false end end)
        end
    end
    Btn("^",0.88,"up"); Btn("v",0.78,"dn")
    return sg
end

FlyTab:AddToggle("FlyToggle", {
    Title="Fly Mode", Description="Mobile: joystick + ^ v  |  PC: WASD + Space / LCtrl",
    Default=false, Callback=function(s)
        flyOn=s
        local isMob=UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        if s and isMob then
            if flyMobGui then pcall(function() flyMobGui:Destroy() end) end
            flyMobGui=BuildMobileButtons()
        elseif not s then
            flyMobUp=false; flyMobDn=false
            if flyMobGui then pcall(function() flyMobGui:Destroy() end); flyMobGui=nil end
        end
        local char=plr.Character
        if s and char then
            local root=char:FindFirstChild("HumanoidRootPart"); if not root then flyOn=false; return end
            local hum=char:FindFirstChildOfClass("Humanoid"); if hum then hum.PlatformStand=true end
            flyBG=Instance.new("BodyGyro",root); flyBG.MaxTorque=Vector3.new(1e9,1e9,1e9); flyBG.D=120
            flyBV=Instance.new("BodyVelocity",root); flyBV.MaxForce=Vector3.new(1e9,1e9,1e9); flyBV.Velocity=Vector3.zero
            RunService:BindToRenderStep("SHFly",200,function()
                if not flyOn then
                    RunService:UnbindFromRenderStep("SHFly")
                    pcall(function() flyBV:Destroy(); flyBG:Destroy() end)
                    local h2=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                    if h2 then h2.PlatformStand=false end; return
                end
                local spd=flySpeed; local vel=Vector3.zero; local cam=workspace.CurrentCamera
                if UserInputService.KeyboardEnabled then
                    if UserInputService:IsKeyDown(Enum.KeyCode.W)           then vel=vel+cam.CFrame.LookVector*spd   end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S)           then vel=vel-cam.CFrame.LookVector*spd   end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A)           then vel=vel-cam.CFrame.RightVector*spd  end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D)           then vel=vel+cam.CFrame.RightVector*spd  end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then vel=vel+Vector3.new(0,spd,0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel=vel-Vector3.new(0,spd,0) end
                else
                    local hum2=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum2 and hum2.MoveDirection.Magnitude>0.05 then
                        local md=hum2.MoveDirection; vel=vel+Vector3.new(md.X,0,md.Z)*spd
                    end
                    if flyMobUp then vel=vel+Vector3.new(0,spd,0) end
                    if flyMobDn then vel=vel-Vector3.new(0,spd,0) end
                end
                flyBV.Velocity=vel; flyBG.CFrame=cam.CFrame
            end)
            if isMob then Notify("Fly","Use joystick to move. ^ = up, v = down.",4)
            else Notify("Fly","WASD + Space / LCtrl",3) end
        else
            RunService:UnbindFromRenderStep("SHFly")
            if char then
                local root=char:FindFirstChild("HumanoidRootPart")
                if root then for _,c in pairs(root:GetChildren()) do if c:IsA("BodyVelocity") or c:IsA("BodyGyro") then c:Destroy() end end end
                local h2=char:FindFirstChildOfClass("Humanoid"); if h2 then h2.PlatformStand=false end
            end
        end
    end,
})

-- ================================================================
-- TAB: COMBAT
-- ================================================================
local Combat = Window:AddTab({ Title = "Combat", Icon = "sword" })

Combat:AddToggle("KillAuraToggle", {
    Title="Kill Aura", Description="Deals damage to nearby players",
    Default=false, Callback=function(s)
        killAuraOn=s
        if killAuraConn then killAuraConn:Disconnect(); killAuraConn=nil end
        if s then
            killAuraConn=RunService.Heartbeat:Connect(function()
                local root=Root(); if not root then return end
                for _,p in pairs(Players:GetPlayers()) do
                    if p~=plr and p.Character then
                        local pr=p.Character:FindFirstChild("HumanoidRootPart")
                        local ph=p.Character:FindFirstChildOfClass("Humanoid")
                        if pr and ph and (root.Position-pr.Position).Magnitude<=killAuraRange then
                            ph:TakeDamage(ph.MaxHealth*10)
                        end
                    end
                end
            end)
            Notify("Kill Aura","Active.",2)
        else Notify("Kill Aura","Disabled.",2) end
    end,
})
Combat:AddSlider("KillAuraRangeSlider", {
    Title="Kill Aura Range", Description="Distance in studs",
    Min=5, Max=100, Default=15, Rounding=0,
    Callback=function(v) killAuraRange=v end,
})

Combat:AddToggle("AutoClickToggle", {
    Title="Auto Click", Description="Rapidly clicks every frame",
    Default=false, Callback=function(s)
        autoClickOn=s
        if autoClickConn then autoClickConn:Disconnect(); autoClickConn=nil end
        if s then
            autoClickConn=RunService.Heartbeat:Connect(function()
                if not autoClickOn then return end
                pcall(function()
                    local vm=game:GetService("VirtualInputManager")
                    vm:SendMouseButtonEvent(mouse.X,mouse.Y,0,true, game,1)
                    vm:SendMouseButtonEvent(mouse.X,mouse.Y,0,false,game,1)
                end)
            end)
            Notify("Auto Click","Active.",2)
        else Notify("Auto Click","Disabled.",2) end
    end,
})

Combat:AddToggle("SilentAimToggle", {
    Title="Silent Aim", Description="Redirects shots to the nearest player's head",
    Default=false, Callback=function(s) silentAimOn=s; Notify(s and "Silent Aim" or "Silent Aim",s and "Active." or "Disabled.",2) end,
})
RunService.RenderStepped:Connect(function()
    if not silentAimOn then return end
    local root=Root(); if not root then return end
    local closest,closestDist=nil,math.huge
    for _,p in pairs(Players:GetPlayers()) do
        if p~=plr and p.Character then
            local head=p.Character:FindFirstChild("Head")
            if head then
                local d=(root.Position-head.Position).Magnitude
                if d<closestDist then closestDist=d; closest=head end
            end
        end
    end
    if closest then pcall(function() mouse.Hit=CFrame.new(closest.Position) end) end
end)

Combat:AddToggle("AntiKBToggle", {
    Title="Anti-Knockback", Description="Destroys BodyVelocity forces on you",
    Default=false, Callback=function(s)
        antiKBOn=s
        RunService:UnbindFromRenderStep("SHAntiKB")
        if s then
            RunService:BindToRenderStep("SHAntiKB",300,function()
                local root=Root(); if not root then return end
                for _,c in pairs(root:GetChildren()) do
                    if c:IsA("BodyVelocity") or c:IsA("BodyForce") then c:Destroy() end
                end
            end)
            Notify("Anti-Knockback","Active.",2)
        else Notify("Anti-Knockback","Disabled.",2) end
    end,
})

Combat:AddToggle("ReachToggle", {
    Title="Reach Extender", Description="Damages players within reach range",
    Default=false, Callback=function(s)
        reachOn=s
        if reachConn then reachConn:Disconnect(); reachConn=nil end
        if s then
            reachConn=RunService.Heartbeat:Connect(function()
                local root=Root(); if not root then return end
                local char=plr.Character; if not char then return end
                if not char:FindFirstChildOfClass("Tool") then return end
                for _,p in pairs(Players:GetPlayers()) do
                    if p~=plr and p.Character then
                        local pr=p.Character:FindFirstChild("HumanoidRootPart")
                        local ph=p.Character:FindFirstChildOfClass("Humanoid")
                        if pr and ph and (root.Position-pr.Position).Magnitude<=reachRange then
                            ph:TakeDamage(10)
                        end
                    end
                end
            end)
            Notify("Reach Extender","Active.",2)
        else Notify("Reach Extender","Disabled.",2) end
    end,
})
Combat:AddSlider("ReachRangeSlider", {
    Title="Reach Range", Description="Extended range in studs",
    Min=5, Max=100, Default=30, Rounding=0,
    Callback=function(v) reachRange=v end,
})

Combat:AddToggle("TriggerBotToggle", {
    Title="Trigger Bot", Description="Auto-clicks when crosshair is on an enemy",
    Default=false, Callback=function(s)
        triggerBotOn=s
        RunService:UnbindFromRenderStep("SHTrigger")
        if s then
            RunService:BindToRenderStep("SHTrigger",250,function()
                if not triggerBotOn then RunService:UnbindFromRenderStep("SHTrigger"); return end
                local target=mouse.Target
                if target and target.Parent then
                    local tp=Players:GetPlayerFromCharacter(target.Parent)
                    if tp and tp~=plr then
                        pcall(function()
                            local vm=game:GetService("VirtualInputManager")
                            vm:SendMouseButtonEvent(mouse.X,mouse.Y,0,true, game,1)
                            vm:SendMouseButtonEvent(mouse.X,mouse.Y,0,false,game,1)
                        end)
                    end
                end
            end)
            Notify("Trigger Bot","Active.",2)
        else Notify("Trigger Bot","Disabled.",2) end
    end,
})

Combat:AddToggle("SpeedHackToggle", {
    Title="Speed Hack", Description="Locks WalkSpeed to 500",
    Default=false, Callback=function(s)
        speedHackOn=s
        RunService:UnbindFromRenderStep("SHSpeedH")
        if s then
            RunService:BindToRenderStep("SHSpeedH",50,function()
                local h=Hum(); if h then h.WalkSpeed=500 end
            end)
            Notify("Speed Hack","Locked at 500.",2)
        else Notify("Speed Hack","Disabled.",2) end
    end,
})

Combat:AddButton({ Title="Snap Aim to Nearest", Description="Look at the closest player's head",
    Callback=function()
        local root=Root(); if not root then return end
        local closest,closestDist=nil,math.huge
        for _,p in pairs(Players:GetPlayers()) do
            if p~=plr and p.Character then
                local head=p.Character:FindFirstChild("Head")
                if head then local d=(root.Position-head.Position).Magnitude; if d<closestDist then closestDist=d; closest=head end end
            end
        end
        if closest then workspace.CurrentCamera.CFrame=CFrame.new(workspace.CurrentCamera.CFrame.Position,closest.Position); Notify("Snap Aim","Aimed.",2)
        else Notify("Snap Aim","No players nearby.",2) end
    end
})
Combat:AddButton({ Title="Kill Nearest Player", Description="Deal lethal damage to closest enemy",
    Callback=function()
        local root=Root(); if not root then return end
        local closest,closestDist=nil,math.huge
        for _,p in pairs(Players:GetPlayers()) do
            if p~=plr and p.Character then
                local pr=p.Character:FindFirstChild("HumanoidRootPart"); local ph=p.Character:FindFirstChildOfClass("Humanoid")
                if pr and ph then local d=(root.Position-pr.Position).Magnitude; if d<closestDist then closestDist=d; closest=ph end end
            end
        end
        if closest then closest:TakeDamage(closest.MaxHealth*999); Notify("Kill","Done.",2)
        else Notify("Kill","No players nearby.",2) end
    end
})
Combat:AddButton({ Title="Teleport Behind Nearest", Description="Appear behind closest enemy",
    Callback=function()
        local root=Root(); if not root then return end
        local closest,closestDist=nil,math.huge
        for _,p in pairs(Players:GetPlayers()) do
            if p~=plr and p.Character then
                local pr=p.Character:FindFirstChild("HumanoidRootPart")
                if pr then local d=(root.Position-pr.Position).Magnitude; if d<closestDist then closestDist=d; closest=pr end end
            end
        end
        if closest then root.CFrame=closest.CFrame*CFrame.new(0,0,2); Notify("Teleport","Behind nearest.",2)
        else Notify("Teleport","No players nearby.",2) end
    end
})
Combat:AddButton({ Title="Fling Nearest Player", Description="Launch closest enemy upward",
    Callback=function()
        local root=Root(); if not root then return end
        local closest,closestDist=nil,math.huge
        for _,p in pairs(Players:GetPlayers()) do
            if p~=plr and p.Character then
                local pr=p.Character:FindFirstChild("HumanoidRootPart")
                if pr then local d=(root.Position-pr.Position).Magnitude; if d<closestDist then closestDist=d; closest=pr end end
            end
        end
        if closest then
            local bv=Instance.new("BodyVelocity",closest)
            bv.Velocity=Vector3.new(math.random(-200,200),600,math.random(-200,200)); bv.MaxForce=Vector3.new(1e9,1e9,1e9)
            task.delay(0.2,function() pcall(function() bv:Destroy() end) end)
            Notify("Fling","Done.",2)
        else Notify("Fling","No players nearby.",2) end
    end
})

-- ================================================================
-- TAB: FUN
-- ================================================================
local Fun = Window:AddTab({ Title = "Fun", Icon = "flame" })

Fun:AddButton({ Title="Fling Self", Description="Launch yourself upward",
    Callback=function()
        local root=Root(); if not root then return end
        local bv=Instance.new("BodyVelocity",root); bv.Velocity=Vector3.new(0,500,0); bv.MaxForce=Vector3.new(1e9,1e9,1e9)
        task.delay(0.2,function() pcall(function() bv:Destroy() end) end); Notify("Fling","Launched!",2)
    end })
Fun:AddButton({ Title="Super Jump", Description="One massive jump",
    Callback=function()
        local h=Hum(); if not h then return end
        h.UseJumpPower=true; h.JumpPower=500; h:ChangeState(Enum.HumanoidStateType.Jumping)
        task.delay(0.5,function() h.JumpPower=50 end); Notify("Super Jump","Done!",2)
    end })
Fun:AddButton({ Title="Spin (3 sec)", Description="Spin your character",
    Callback=function()
        local root=Root(); if not root then return end
        local bg=Instance.new("BodyAngularVelocity",root)
        bg.AngularVelocity=Vector3.new(0,120,0); bg.MaxTorque=Vector3.new(0,1e9,0)
        task.delay(3,function() pcall(function() bg:Destroy() end) end); Notify("Spin","3 seconds.",2)
    end })
Fun:AddButton({ Title="Speed x2", Description="Double current WalkSpeed",
    Callback=function() local h=Hum(); if h then h.WalkSpeed=math.min(h.WalkSpeed*2,500); Notify("Speed","→ "..h.WalkSpeed,2) end end })

Fun:AddToggle("RainbowBPToggle", {
    Title="Rainbow Baseplate", Description="Cycles the baseplate colour",
    Default=false, Callback=function(s)
        rainbowBPOn=s
        if s then
            RunService:BindToRenderStep("SHRB",50,function()
                local bp=workspace:FindFirstChild("Baseplate")
                if bp and bp:IsA("BasePart") then bp.Color=Color3.fromHSV(tick()%6/6,0.9,1) end
            end)
            Notify("Rainbow BP","Active.",2)
        else
            RunService:UnbindFromRenderStep("SHRB")
            SetBP(chosenBPColor)
            Notify("Rainbow BP","Stopped — colour restored.",2)
        end
    end,
})

local bpColours = {
    ["Original"]=origBPColor,  ["Purple"]=Color3.fromRGB(130,50,255), ["Red"]=Color3.fromRGB(220,50,50),
    ["Blue"]=Color3.fromRGB(30,100,220), ["Green"]=Color3.fromRGB(34,197,94), ["Yellow"]=Color3.fromRGB(234,179,8),
    ["Orange"]=Color3.fromRGB(234,120,10), ["Pink"]=Color3.fromRGB(236,72,153), ["Cyan"]=Color3.fromRGB(6,182,212),
    ["White"]=Color3.fromRGB(255,255,255), ["Black"]=Color3.fromRGB(10,10,10), ["Gold"]=Color3.fromRGB(212,175,55),
    ["Neon Green"]=Color3.fromRGB(57,255,20), ["Neon Pink"]=Color3.fromRGB(255,20,147),
    ["Sky Blue"]=Color3.fromRGB(135,206,235), ["Dark Red"]=Color3.fromRGB(139,0,0),
}
local bpNames={}; for k in pairs(bpColours) do table.insert(bpNames,k) end; table.sort(bpNames)

Fun:AddDropdown("BPColorDrop", {
    Title="Baseplate Colour", Description="Applied when Rainbow is off",
    Values=bpNames, Default="Original",
    Callback=function(v)
        local col=bpColours[v]; if col then chosenBPColor=col; if not rainbowBPOn then SetBP(col) end; Notify("Baseplate",v,2) end
    end,
})
Fun:AddButton({ Title="Apply Colour Now", Callback=function()
    RunService:UnbindFromRenderStep("SHRB"); rainbowBPOn=false; SetBP(chosenBPColor); Notify("Baseplate","Applied.",2)
end })
Fun:AddButton({ Title="Restore Original Colour", Callback=function()
    RunService:UnbindFromRenderStep("SHRB"); rainbowBPOn=false; chosenBPColor=origBPColor; SetBP(origBPColor); Notify("Baseplate","Original restored.",2)
end })

-- ================================================================
-- TAB: VISUAL
-- ================================================================
local Visual = Window:AddTab({ Title = "Visual", Icon = "eye" })

Visual:AddToggle("FullbrightToggle", {
    Title="Fullbright", Description="Removes all shadow and ambient darkness",
    Default=false, Callback=function(s)
        if s then Lighting.Brightness=2; Lighting.Ambient=Color3.fromRGB(178,178,178); Lighting.OutdoorAmbient=Color3.fromRGB(178,178,178)
        else Lighting.Brightness=origBright; Lighting.Ambient=origAmb; Lighting.OutdoorAmbient=origOut end
        Notify("Fullbright",s and "Enabled." or "Restored.",2)
    end,
})
Visual:AddToggle("NoFogToggle", {
    Title="No Fog", Description="Removes world fog",
    Default=false, Callback=function(s) Lighting.FogEnd=s and 1e9 or origFogEnd end,
})
Visual:AddSlider("TimeSlider", {
    Title="Time of Day", Description="0=midnight  14=day  24=midnight",
    Min=0, Max=24, Default=14, Rounding=0,
    Callback=function(v) Lighting.ClockTime=v end,
})
Visual:AddSlider("BrightSlider", {
    Title="Scene Brightness", Min=0, Max=5, Default=1, Rounding=1,
    Callback=function(v) Lighting.Brightness=v end,
})
Visual:AddButton({ Title="Preset: Day",     Callback=function() Lighting.ClockTime=14;  Notify("Time","Day.",2)     end })
Visual:AddButton({ Title="Preset: Night",   Callback=function() Lighting.ClockTime=0;   Notify("Time","Night.",2)   end })
Visual:AddButton({ Title="Preset: Sunrise", Callback=function() Lighting.ClockTime=6;   Notify("Time","Sunrise.",2) end })
Visual:AddButton({ Title="Preset: Sunset",  Callback=function() Lighting.ClockTime=19;  Notify("Time","Sunset.",2)  end })

Visual:AddSlider("FOVSlider", {
    Title="Camera FOV", Description="Field of view  (default 70)",
    Min=60, Max=120, Default=70, Rounding=0,
    Callback=function(v) workspace.CurrentCamera.FieldOfView=v end,
})
Visual:AddSlider("ZoomSlider", {
    Title="Max Zoom Distance", Min=5, Max=1000, Default=400, Rounding=0,
    Callback=function(v) plr.CameraMaxZoomDistance=v end,
})
Visual:AddButton({ Title="Reset FOV", Callback=function() workspace.CurrentCamera.FieldOfView=70; Notify("FOV","Reset.",2) end })

Visual:AddToggle("ESPToggle", {
    Title="Player Highlights (ESP)", Description="Glowing outline on all players",
    Default=false, Callback=function(s)
        if s then
            for _,p in pairs(Players:GetPlayers()) do
                if p~=plr and p.Character then
                    local hl=Instance.new("Highlight",p.Character)
                    hl.FillColor=espColor; hl.OutlineColor=Color3.fromRGB(255,255,255); hl.FillTransparency=0.55
                    espObjs[p.UserId]=hl
                end
            end
            Notify("ESP","Active.",2)
        else
            for _,hl in pairs(espObjs) do pcall(function() hl:Destroy() end) end; espObjs={}
        end
    end,
})

local espCols={"Purple","Red","Green","Blue","Yellow","White","Cyan","Pink","Orange"}
local espColMap={Purple=Color3.fromRGB(130,50,255),Red=Color3.fromRGB(220,50,50),Green=Color3.fromRGB(34,197,94),
    Blue=Color3.fromRGB(30,100,220),Yellow=Color3.fromRGB(234,179,8),White=Color3.fromRGB(255,255,255),
    Cyan=Color3.fromRGB(6,182,212),Pink=Color3.fromRGB(236,72,153),Orange=Color3.fromRGB(234,120,10)}

Visual:AddDropdown("ESPColorDrop", {
    Title="ESP Colour", Values=espCols, Default="Purple",
    Callback=function(v)
        local col=espColMap[v]; if col then espColor=col; for _,hl in pairs(espObjs) do pcall(function() hl.FillColor=col end) end; Notify("ESP Colour",v,2) end
    end,
})

Visual:AddToggle("NameTagsToggle", {
    Title="Name Tags", Description="Floating names above every player's head",
    Default=false, Callback=function(s)
        for _,p in pairs(Players:GetPlayers()) do
            if p~=plr and p.Character then
                local head=p.Character:FindFirstChild("Head")
                if head then
                    if s then
                        local bg=Instance.new("BillboardGui",head); bg.Name="SHTag"; bg.Size=UDim2.new(0,100,0,22); bg.StudsOffset=Vector3.new(0,3,0); bg.AlwaysOnTop=true
                        local tl=Instance.new("TextLabel",bg); tl.Size=UDim2.new(1,0,1,0); tl.BackgroundTransparency=1; tl.Text=p.Name; tl.Font=Enum.Font.GothamBold; tl.TextSize=13; tl.TextColor3=Color3.fromRGB(130,50,255)
                    else
                        for _,c in pairs(head:GetChildren()) do if c.Name=="SHTag" then c:Destroy() end end
                    end
                end
            end
        end
        Notify("Name Tags",s and "On." or "Off.",2)
    end,
})

Visual:AddToggle("ChamsToggle", {
    Title="Chams (Neon enemies)", Description="Makes enemy characters emit neon glow",
    Default=false, Callback=function(s)
        chamsOn=s
        for _,p in pairs(Players:GetPlayers()) do
            if p~=plr and p.Character then
                for _,part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then part.Material=s and Enum.Material.Neon or Enum.Material.SmoothPlastic end
                end
            end
        end
        Notify("Chams",s and "Active." or "Disabled.",2)
    end,
})

Visual:AddToggle("CrosshairToggle", {
    Title="Dot Crosshair", Description="Small dot at screen centre",
    Default=false, Callback=function(s)
        if s then
            xhairGui=Instance.new("ScreenGui")
            xhairGui.Name="SHCrosshair"; xhairGui.ResetOnSpawn=false; xhairGui.DisplayOrder=999; xhairGui.IgnoreGuiInset=true
            local ok,cg=pcall(function() return game:GetService("CoreGui") end)
            xhairGui.Parent=(ok and cg) and cg or plr:WaitForChild("PlayerGui",10)
            local f=Instance.new("Frame",xhairGui); f.Size=UDim2.new(0,7,0,7); f.Position=UDim2.fromScale(0.5,0.5); f.AnchorPoint=Vector2.new(0.5,0.5); f.BackgroundColor3=xhairColor; f.BorderSizePixel=0; f.ZIndex=999; Instance.new("UICorner",f).CornerRadius=UDim.new(0,4)
        else
            if xhairGui then xhairGui:Destroy(); xhairGui=nil end
        end
    end,
})
Visual:AddDropdown("CrosshairColorDrop", {
    Title="Crosshair Colour", Values=espCols, Default="Purple",
    Callback=function(v)
        local col=espColMap[v]; if col then xhairColor=col; if xhairGui then for _,f in pairs(xhairGui:GetDescendants()) do if f:IsA("Frame") then f.BackgroundColor3=col end end end end
    end,
})

-- ================================================================
-- TAB: TELEPORT
-- ================================================================
local Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin" })

Teleport:AddButton({ Title="Go to Spawn",     Callback=function()
    local sp=workspace:FindFirstChildOfClass("SpawnLocation"); local rt=Root()
    if sp and rt then rt.CFrame=sp.CFrame+Vector3.new(0,5,0); Notify("Teleport","At spawn.",2)
    else Notify("Teleport","No SpawnLocation found.",2) end
end })
Teleport:AddButton({ Title="Origin (0,0,0)",  Callback=function()
    local rt=Root(); if rt then rt.CFrame=CFrame.new(0,10,0); Notify("Teleport","At origin.",2) end
end })
Teleport:AddButton({ Title="Teleport to Cursor", Description="PC only",Callback=function()
    local hit=mouse.Hit; local rt=Root()
    if hit and rt then rt.CFrame=CFrame.new(hit.Position+Vector3.new(0,4,0)); Notify("Teleport","Done.",2) end
end })

Teleport:AddInput("TpX", { Title="X", Default="0",  Placeholder="X position", Numeric=true, Finished=false, Callback=function() end })
Teleport:AddInput("TpY", { Title="Y", Default="50", Placeholder="Y position", Numeric=true, Finished=false, Callback=function() end })
Teleport:AddInput("TpZ", { Title="Z", Default="0",  Placeholder="Z position", Numeric=true, Finished=false, Callback=function() end })
Teleport:AddButton({ Title="Teleport to XYZ", Callback=function()
    local x=tonumber(Fluent.Options.TpX.Value); local y=tonumber(Fluent.Options.TpY.Value); local z=tonumber(Fluent.Options.TpZ.Value); local rt=Root()
    if x and y and z and rt then rt.CFrame=CFrame.new(x,y,z); Notify("Teleport","Done.",2)
    else Notify("Teleport","Enter valid numbers.",3) end
end })

local tpDropdown = Teleport:AddDropdown("TpPlayerDrop", {
    Title="Select Player", Description="Choose who to jump to",
    Values=GetPlayerNames(), Default="None",
    Callback=function(v) selectedTPPlayer=v; if v~="None" then Notify("Selected",v,2) end end,
})
Teleport:AddButton({ Title="Refresh Player List", Callback=function()
    local names=GetPlayerNames(); tpDropdown:SetValues(names); selectedTPPlayer="None"; Notify("Refreshed",#names-1 .." players found.",3)
end })
Teleport:AddButton({ Title="Teleport to Selected", Callback=function()
    if selectedTPPlayer=="None" or selectedTPPlayer=="" then Notify("Teleport","Select a player first.",3); return end
    local target=Players:FindFirstChild(selectedTPPlayer); local rt=Root()
    if target and target.Character and rt then
        local tr=target.Character:FindFirstChild("HumanoidRootPart")
        if tr then rt.CFrame=tr.CFrame+Vector3.new(3,3,0); Notify("Teleport","→ "..selectedTPPlayer,2)
        else Notify("Teleport","Target has no root.",2) end
    else Notify("Teleport","Player not found.",2) end
end })
Teleport:AddButton({ Title="Select None (Cancel)", Callback=function()
    selectedTPPlayer="None"; pcall(function() tpDropdown:SetValue("None") end); Notify("Cancelled","Selection cleared.",2)
end })
Teleport:AddButton({ Title="Server Hop", Callback=function()
    Notify("Server Hop","Finding new server…",2); task.delay(1.5,function() pcall(function() TeleportService:Teleport(game.PlaceId,plr) end) end)
end })
Teleport:AddButton({ Title="Rejoin Game", Callback=function()
    Notify("Rejoin","Reconnecting…",2); pcall(function() TeleportService:Teleport(game.PlaceId,plr) end)
end })

-- ================================================================
-- TAB: UTILITY
-- ================================================================
local Utility = Window:AddTab({ Title = "Utility", Icon = "settings-2" })

Utility:AddButton({ Title="Show FPS Widget",      Description="Draggable FPS counter. Press again to close.",      Callback=function() MakeStatWidget("fps","FPS",function() return tostring(fpsVal) end,Color3.fromRGB(34,197,94))    end })
Utility:AddButton({ Title="Show Ping Widget",     Description="Draggable Ping counter. Press again to close.",     Callback=function() MakeStatWidget("ping","PING",function() return tostring(pingVal).." ms" end,Color3.fromRGB(6,182,212)) end })
Utility:AddButton({ Title="Show Position Widget", Description="Draggable XYZ tracker. Press again to close.",
    Callback=function() MakeStatWidget("pos","POS",function() local r=Root(); if not r then return "--" end; local p=r.Position; return math.floor(p.X)..","..math.floor(p.Y)..","..math.floor(p.Z) end,Color3.fromRGB(130,50,255)) end })
Utility:AddButton({ Title="Show Gravity Widget",  Description="Draggable gravity display. Press again to close.",  Callback=function() MakeStatWidget("grav","GRAV",function() return tostring(math.floor(workspace.Gravity)) end,Color3.fromRGB(234,179,8)) end })
Utility:AddButton({ Title="Close All Widgets",    Description="Close every open stat widget",
    Callback=function() for k,g in pairs(_statWidgets) do pcall(function() g:Destroy() end); _statWidgets[k]=nil end; Notify("Widgets","All closed.",2) end })

Utility:AddButton({ Title="Copy Game ID",   Callback=function() pcall(function() setclipboard(tostring(game.PlaceId)) end); Notify("Copied","Game ID: "..game.PlaceId,3) end })
Utility:AddButton({ Title="Copy Username",  Callback=function() pcall(function() setclipboard(plr.Name) end); Notify("Copied",plr.Name,2) end })
Utility:AddButton({ Title="Copy User ID",   Callback=function() pcall(function() setclipboard(tostring(plr.UserId)) end); Notify("Copied","UserId: "..plr.UserId,2) end })
Utility:AddButton({ Title="Copy Job ID",    Callback=function() pcall(function() setclipboard(game.JobId) end); Notify("Copied","Job ID copied.",3) end })
Utility:AddButton({ Title="Copy Position",
    Callback=function() local rt=Root(); if rt then local p=rt.Position; local s=math.floor(p.X)..","..math.floor(p.Y)..","..math.floor(p.Z); pcall(function() setclipboard(s) end); Notify("Copied",s,3) end end })
Utility:AddButton({ Title="List All Players",
    Callback=function() local n={}; for _,p in pairs(Players:GetPlayers()) do table.insert(n,p.Name) end; Notify("Players ("..#n..")",table.concat(n,", "),6) end })
Utility:AddButton({ Title="Destroy GUI", Description="Permanently remove this hub",
    Callback=function() Notify("Goodbye","Removing…",2); task.wait(2.2); Window:Destroy() end })

-- ================================================================
-- TAB: INFO
-- ================================================================
local Info = Window:AddTab({ Title = "Info", Icon = "info" })

Info:AddParagraph({ Title="About",
    Content="Shadow Hub v2.1.0\n\nA premium Roblox hub with 80+ features across Player, Fly, Combat, Visual, Teleport and Utility.\n\nAll settings save automatically on close and reload on next run."
})
Info:AddParagraph({ Title="Author", Content="Made by Shadow.\nVersion: 2.1.0" })
Info:AddParagraph({ Title="Controls",
    Content="Toggle UI: RightControl  |  RightShift  |  Floating button\nFly (PC): WASD + Space / LCtrl\nFly (Mobile): on-screen joystick + ^ v buttons\nFloating button is draggable — move it anywhere."
})
Info:AddParagraph({ Title="Tabs",
    Content="Home      —  Quick stats, fast actions\nPlayer    —  Speed, jump, gravity, NoClip, Immortal\nFly       —  Fly toggle and speed\nCombat    —  Kill Aura, Silent Aim, Anti-KB, Reach\nFun       —  Fling, spin, rainbow + custom baseplate\nVisual    —  ESP, Fullbright, FOV, Chams, Crosshair\nTeleport  —  Spawn, XYZ, player list, server hop\nUtility   —  Stat widgets, copy tools, player list\nInfo      —  This page\nSettings  —  Config, theme, toggle button options"
})
Info:AddParagraph({ Title="Baseplate Colours",
    Content="Fun tab → pick a colour from the dropdown.\nWhen you stop Rainbow mode the baseplate restores to your chosen colour automatically."
})
Info:AddParagraph({ Title="Teleport to Player",
    Content="Teleport tab → Select Player → choose a name → Teleport to Selected.\nPress Refresh to update the list.\nPress Select None to cancel."
})
Info:AddParagraph({ Title="Stat Widgets",
    Content="Home or Utility tab → press any Show Widget button.\nA small draggable pill appears showing the live value.\nPress the same button again to close it, or use the X on the widget."
})
Info:AddParagraph({ Title="Compatibility",
    Content="Compatible with Codex, Fluxus, Delta, Solara and similar executors."
})

-- ================================================================
-- TAB: SETTINGS  (always last)
-- ================================================================
local Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })

SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "TpX","TpY","TpZ","TpPlayerDrop" })
SaveManager:SetFolder("ShadowHub")
SaveManager:BuildConfigSection(Settings)

InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("ShadowHub")
InterfaceManager:BuildInterfaceSection(Settings)

Settings:AddButton({ Title="Save Config",      Callback=function() SaveManager:Save();  Notify("Config","Saved.",3)  end })
Settings:AddButton({ Title="Load Config",      Callback=function() SaveManager:Load();  Notify("Config","Loaded.",3) end })
Settings:AddButton({ Title="Reset Defaults",   Callback=function()
    local h=Hum(); if h then h.WalkSpeed=16; h.UseJumpPower=true; h.JumpPower=50 end
    workspace.Gravity=196; Lighting.Brightness=origBright; Lighting.Ambient=origAmb; Lighting.OutdoorAmbient=origOut
    Notify("Reset","Defaults restored.",3)
end })

-- ================================================================
-- FLOATING TOGGLE BUTTON
-- Tapping it simulates RightControl which triggers Fluent's
-- built-in MinimizeKey handler. No custom logic needed.
-- ================================================================
local _toggleBtnGui  = nil
local _toggleBtnSize = "Medium"
local _toggleBtnText = "^"

local _btnSizes = {
    Small  = { w=42,  h=42,  ts=16, cr=13 },
    Medium = { w=56,  h=56,  ts=22, cr=17 },
    Large  = { w=72,  h=72,  ts=28, cr=22 },
}

local function SimulateRightControl()
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true,  Enum.KeyCode.RightControl, false, game)
        task.wait(0.02)
        vim:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
    end)
end

-- Also allow RightShift as second key
UserInputService.InputBegan:Connect(function(inp, gp)
    if not gp and inp.KeyCode == Enum.KeyCode.RightShift then
        SimulateRightControl()
    end
end)

local function DestroyToggleButton()
    if _toggleBtnGui then pcall(function() _toggleBtnGui:Destroy() end); _toggleBtnGui=nil end
end

local function CreateToggleButton(sizeName, labelText)
    DestroyToggleButton()
    local sz = _btnSizes[sizeName]
    if not sz then return end
    labelText = labelText or _toggleBtnText

    local guiParent
    pcall(function() guiParent=game:GetService("CoreGui") end)
    if not guiParent then guiParent=plr:WaitForChild("PlayerGui",10) end

    local sg=Instance.new("ScreenGui")
    sg.Name="SHToggleBtn"; sg.ResetOnSpawn=false; sg.DisplayOrder=850; sg.IgnoreGuiInset=true; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=guiParent
    _toggleBtnGui=sg

    -- Glow ring
    local glow=Instance.new("Frame",sg)
    glow.Size=UDim2.new(0,sz.w+12,0,sz.h+12); glow.Position=UDim2.new(0,9,0.5,-(sz.h+12)/2)
    glow.BackgroundColor3=Color3.fromRGB(130,50,255); glow.BackgroundTransparency=0.70; glow.BorderSizePixel=0; glow.ZIndex=1
    Instance.new("UICorner",glow).CornerRadius=UDim.new(0,sz.cr+6)

    local function PulseGlow()
        if not glow.Parent then return end
        TweenService:Create(glow,TweenInfo.new(1.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=0.46}):Play()
        task.delay(1.3,function()
            if not glow.Parent then return end
            TweenService:Create(glow,TweenInfo.new(1.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=0.72}):Play()
            task.delay(1.3,PulseGlow)
        end)
    end
    PulseGlow()

    -- Button frame
    local btn=Instance.new("Frame",sg)
    btn.Name="ToggleFrame"; btn.Size=UDim2.new(0,sz.w,0,sz.h); btn.Position=UDim2.new(0,15,0.5,-sz.h/2)
    btn.BackgroundColor3=Color3.fromRGB(12,6,28); btn.BorderSizePixel=0; btn.ZIndex=2
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,sz.cr)
    local stroke=Instance.new("UIStroke",btn); stroke.Color=Color3.fromRGB(130,50,255); stroke.Thickness=2.2

    -- Keep glow aligned to btn as it drags
    btn:GetPropertyChangedSignal("Position"):Connect(function()
        glow.Position=UDim2.new(btn.Position.X.Scale,btn.Position.X.Offset-6,btn.Position.Y.Scale,btn.Position.Y.Offset-6)
    end)

    -- Icon label
    local ico=Instance.new("TextLabel",btn)
    ico.Size=UDim2.new(1,0,1,0); ico.BackgroundTransparency=1; ico.Text=labelText; ico.Font=Enum.Font.GothamBlack
    ico.TextSize=sz.ts; ico.TextColor3=Color3.fromRGB(160,90,255); ico.TextXAlignment=Enum.TextXAlignment.Center
    ico.TextYAlignment=Enum.TextYAlignment.Center; ico.BorderSizePixel=0; ico.ZIndex=3

    local function PulseIcon()
        if not ico.Parent then return end
        TweenService:Create(ico,TweenInfo.new(1.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{TextColor3=Color3.fromRGB(210,150,255)}):Play()
        task.delay(1.4,function()
            if not ico.Parent then return end
            TweenService:Create(ico,TweenInfo.new(1.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{TextColor3=Color3.fromRGB(130,50,255)}):Play()
            task.delay(1.4,PulseIcon)
        end)
    end
    PulseIcon()

    -- Hit button
    local hit=Instance.new("TextButton",btn)
    hit.Size=UDim2.new(1,0,1,0); hit.BackgroundTransparency=1; hit.Text=""; hit.AutoButtonColor=false; hit.BorderSizePixel=0; hit.ZIndex=4

    -- Hover (PC)
    hit.MouseEnter:Connect(function() TweenService:Create(stroke,TweenInfo.new(0.12),{Color=Color3.fromRGB(210,150,255),Thickness=3}):Play(); TweenService:Create(btn,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(22,11,50)}):Play() end)
    hit.MouseLeave:Connect(function() TweenService:Create(stroke,TweenInfo.new(0.12),{Color=Color3.fromRGB(130,50,255),Thickness=2.2}):Play(); TweenService:Create(btn,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(12,6,28)}):Play() end)

    -- Drag + click
    local dragging=false; local dragMoved=false; local dragStart=Vector2.zero; local btnStartPos=Vector2.zero

    hit.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragMoved=false
            dragStart=Vector2.new(inp.Position.X,inp.Position.Y)
            btnStartPos=Vector2.new(btn.Position.X.Offset,btn.Position.Y.Offset)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then
            local d=Vector2.new(inp.Position.X,inp.Position.Y)-dragStart
            if d.Magnitude>8 then dragMoved=true end
            if dragMoved then btn.Position=UDim2.new(btn.Position.X.Scale,btnStartPos.X+d.X,btn.Position.Y.Scale,btnStartPos.Y+d.Y) end
        end
    end)
    hit.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=false
            if not dragMoved then
                -- Tap = simulate RightControl to trigger Fluent's minimize
                SimulateRightControl()
                -- Press feedback
                TweenService:Create(btn,TweenInfo.new(0.08),{BackgroundColor3=Color3.fromRGB(40,18,80)}):Play()
                task.delay(0.12,function() if btn.Parent then TweenService:Create(btn,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(12,6,28)}):Play() end end)
            end
        end
    end)
end

-- Spawn immediately
CreateToggleButton(_toggleBtnSize, _toggleBtnText)

-- Settings controls
Settings:AddDropdown("ToggleBtnSize", {
    Title="Toggle Button Size", Description="Controls the floating button size",
    Values={"Small","Medium","Large","Hidden"}, Default="Medium",
    Callback=function(v)
        _toggleBtnSize=v
        if v=="Hidden" then DestroyToggleButton(); Notify("Toggle Button","Hidden. Use RightControl or RightShift.",4)
        else CreateToggleButton(v,_toggleBtnText); Notify("Toggle Button","Size → "..v,2) end
    end,
})
Settings:AddInput("ToggleBtnLabel", {
    Title="Toggle Button Text", Description="Custom text shown on the button (press Enter to apply)",
    Default="^", Placeholder="Any text or symbol",
    Numeric=false, Finished=true,
    Callback=function(v)
        if not v or v=="" then v="^" end
        _toggleBtnText=v
        if _toggleBtnSize~="Hidden" then CreateToggleButton(_toggleBtnSize,_toggleBtnText) end
        Notify("Toggle Button","Label → "..v,2)
    end,
})
Settings:AddButton({ Title="Show Toggle Button", Description="Re-add if hidden",
    Callback=function()
        if _toggleBtnSize=="Hidden" then _toggleBtnSize="Medium" end
        CreateToggleButton(_toggleBtnSize,_toggleBtnText); Notify("Toggle Button","Restored.",2)
    end
})
Settings:AddButton({ Title="Hide Toggle Button", Description="Remove from screen",
    Callback=function() DestroyToggleButton(); Notify("Toggle Button","Hidden.",3) end
})

-- ================================================================
-- STARTUP
-- ================================================================
SaveManager:LoadAutoloadConfig()
Window:SelectTab(1)

Fluent:Notify({
    Title    = "Shadow Hub",
    Content  = "Welcome, " .. plr.Name .. "   |   v2.1.0",
    Duration = 5,
})
