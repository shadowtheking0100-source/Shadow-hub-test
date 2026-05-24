--[[
    ╔══════════════════════════════════════════════════╗
    ║        SHADOW HUB  |  Fluent UI  |  v2.1.0      ║
    ║  Tabs: Home · Player · Fly · Combat · Fun        ║
    ║        Visual · Teleport · Utility · Info · Settings ║
    ╚══════════════════════════════════════════════════╝

    EXECUTOR: Paste entire script and Execute.
    STUDIO:   Put in StarterPlayerScripts as LocalScript.

    NOTE: All sliders pass their value through the Callback
    parameter — Fluent handles the UI widget itself.
    All toggles pass true/false through Callback.
    No custom UI is drawn on top of Fluent components.
]]

-- ╔══════════════════════╗
-- ║  Load Fluent Library  ║
-- ╚══════════════════════╝
local Fluent = loadstring(
    game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")
)()

local SaveManager = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua")
)()

local InterfaceManager = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua")
)()

-- ╔══════════════════════╗
-- ║       Services        ║
-- ╚══════════════════════╝
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")

local plr   = Players.LocalPlayer
local mouse = plr:GetMouse()

-- ╔══════════════════════╗
-- ║    Runtime State      ║
-- ╚══════════════════════╝
-- Player
local infJumpOn    = false
local noclipOn     = false
local immortalOn   = false
local antiAFKOn    = false
local noclipConn   = nil

-- Fly
local flyOn        = false
local flyBV        = nil
local flyBG        = nil
local flyMobGui    = nil
local flyMobUp     = false
local flyMobDn     = false
local flySpeed     = 56     -- updated by slider callback

-- Combat
local killAuraOn      = false
local killAuraRange   = 15     -- updated by slider callback
local killAuraConn    = nil
local autoClickOn     = false
local autoClickConn   = nil
local silentAimOn     = false
local antiKBOn        = false
local reachOn         = false
local reachRange      = 30     -- updated by slider callback
local reachConn       = nil
local triggerBotOn    = false
local speedHackOn     = false

-- Visual
local espObjs      = {}
local espColor     = Color3.fromRGB(130, 50, 255)
local chamsOn      = false
local xhairGui     = nil
local xhairColor   = Color3.fromRGB(130, 50, 255)

-- Fun / Baseplate
local baseplate        = workspace:FindFirstChild("Baseplate")
local origBPColor      = (baseplate and baseplate:IsA("BasePart")) and baseplate.Color or Color3.fromRGB(106,127,63)
local chosenBPColor    = origBPColor
local rainbowBPOn      = false

-- Lighting originals
local origBright = Lighting.Brightness
local origAmb    = Lighting.Ambient
local origOut    = Lighting.OutdoorAmbient
local origFogEnd = Lighting.FogEnd

-- Teleport to player
local selectedTPPlayer = "None"

-- FPS / Ping
local fpsVal   = 0
local pingVal  = 0
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

-- ╔══════════════════════╗
-- ║       Helpers         ║
-- ╚══════════════════════╝
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

-- ╔══════════════════════╗
-- ║     Create Window     ║
-- ╚══════════════════════╝
-- SecondMinimizeKey is our own custom second hotkey.
-- Fluent only supports one MinimizeKey natively, so we add a
-- second one via UIS.InputBegan further below (after ToggleUI is defined).
local _secondMinimizeKey = Enum.KeyCode.RightShift   -- default second key

local Window = Fluent:CreateWindow({
    Title       = "Shadow Hub - early access",
    SubTitle    = "Premium v2.1.0 - by Shadow",
    TabWidth    = 130,
    Size        = UDim2.fromOffset(620, 500),
    Acrylic     = false,
    Theme       = "Amethyst",
    MinimizeKey = Enum.KeyCode.RightControl,   -- first minimize key (Fluent built-in)
    -- Second minimize key: RightShift (our listener, defined below)
})

-- ═══════════════════════════════════════════════
--  TAB 1 — HOME
-- ═══════════════════════════════════════════════
local Home = Window:AddTab({ Title = "Home", Icon = "home" })

Home:AddParagraph({
    Title   = "Shadow Hub  v2.1.0",
    Content = "Welcome, " .. plr.Name .. "!\n\n"
        .. "Use the tabs on the left to access all features.\n"
        .. "Press RightControl to toggle the UI at any time.\n"
        .. "Settings are auto-saved and reloaded on next run."
})

-- Floating stat widgets (FPS, Ping, Position) --
-- Each widget is a small draggable label with an X close button.
-- Built directly in the ScreenGui so they appear over the game.

local _statWidgets = {}  -- track open widgets to avoid duplicates

local function MakeStatWidget(labelId, titleText, getValueFn, color)
    -- Only one widget per stat at a time
    if _statWidgets[labelId] then
        _statWidgets[labelId]:Destroy()
        _statWidgets[labelId] = nil
        return
    end

    -- Find the best parent: CoreGui > PlayerGui
    local sg
    pcall(function()
        sg = game:GetService("CoreGui")
    end)
    if not sg then
        sg = plr:WaitForChild("PlayerGui", 10)
    end

    -- Outer wrapper (ScreenGui per widget so they stack independently)
    local wGui = Instance.new("ScreenGui")
    wGui.Name = "SHStat_" .. labelId
    wGui.ResetOnSpawn = false
    wGui.DisplayOrder = 700
    wGui.IgnoreGuiInset = true
    wGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    wGui.Parent = sg
    _statWidgets[labelId] = wGui

    -- Main pill frame
    local frame = Instance.new("Frame", wGui)
    frame.Size = UDim2.new(0, 120, 0, 28)
    frame.Position = UDim2.new(0.02, 0, 0.12 + (#_statWidgets * 0.06), 0)
    frame.BackgroundColor3 = Color3.fromRGB(10, 5, 22)
    frame.BackgroundTransparency = 0.12
    frame.BorderSizePixel = 0
    frame.ZIndex = 10
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 20)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = color or Color3.fromRGB(130, 50, 255)
    stroke.Thickness = 1.5

    -- Title label (e.g. "FPS")
    local titleLbl = Instance.new("TextLabel", frame)
    titleLbl.Size = UDim2.new(0, 34, 1, 0)
    titleLbl.Position = UDim2.new(0, 6, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = titleText
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 11
    titleLbl.TextColor3 = color or Color3.fromRGB(160, 90, 255)
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.BorderSizePixel = 0
    titleLbl.ZIndex = 11

    -- Value label
    local valueLbl = Instance.new("TextLabel", frame)
    valueLbl.Size = UDim2.new(1, -60, 1, 0)
    valueLbl.Position = UDim2.new(0, 40, 0, 0)
    valueLbl.BackgroundTransparency = 1
    valueLbl.Text = "..."
    valueLbl.Font = Enum.Font.GothamBold
    valueLbl.TextSize = 11
    valueLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    valueLbl.TextXAlignment = Enum.TextXAlignment.Left
    valueLbl.BorderSizePixel = 0
    valueLbl.ZIndex = 11

    -- Close (X) button
    local closeBtn = Instance.new("TextButton", frame)
    closeBtn.Size = UDim2.new(0, 18, 0, 18)
    closeBtn.Position = UDim2.new(1, -20, 0.5, -9)
    closeBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    closeBtn.BackgroundTransparency = 0.25
    closeBtn.Text = "x"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 10
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.AutoButtonColor = false
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = 12
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 9)
    closeBtn.MouseButton1Click:Connect(function()
        _statWidgets[labelId] = nil
        wGui:Destroy()
    end)

    -- Drag support (PC + Mobile)
    local dragging = false
    local dragStart = Vector2.zero
    local frameStart = Vector2.zero
    frame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging   = true
            dragStart  = Vector2.new(inp.Position.X, inp.Position.Y)
            frameStart = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            local delta = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
            frame.Position = UDim2.new(
                frame.Position.X.Scale, frameStart.X + delta.X,
                frame.Position.Y.Scale, frameStart.Y + delta.Y)
        end
    end)
    game:GetService("UserInputService").InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Live update loop (Heartbeat, every 0.5 s)
    local updateTimer = 0
    local conn; conn = RunService.Heartbeat:Connect(function(dt)
        if not wGui.Parent then conn:Disconnect(); return end
        updateTimer = updateTimer + dt
        if updateTimer < 0.5 then return end
        updateTimer = 0
        local ok, val = pcall(getValueFn)
        if ok then valueLbl.Text = val end
    end)
end

-- Button: Show FPS Widget
Home:AddButton({ Title = "Show FPS Widget",
    Description = "Opens a small draggable FPS counter. Press again to close.",
    Callback = function()
        MakeStatWidget("fps", "FPS", function()
            local col
            if fpsVal >= 60 then col = Color3.fromRGB(34,197,94)
            elseif fpsVal >= 30 then col = Color3.fromRGB(234,179,8)
            else col = Color3.fromRGB(239,68,68) end
            return tostring(fpsVal)
        end, Color3.fromRGB(34,197,94))
    end
})

-- Button: Show Ping Widget
Home:AddButton({ Title = "Show Ping Widget",
    Description = "Opens a small draggable Ping counter. Press again to close.",
    Callback = function()
        MakeStatWidget("ping", "PING", function()
            return tostring(pingVal) .. " ms"
        end, Color3.fromRGB(6,182,212))
    end
})

-- Button: Show Position Widget
Home:AddButton({ Title = "Show Position Widget",
    Description = "Opens a small draggable XYZ position tracker. Press again to close.",
    Callback = function()
        MakeStatWidget("pos", "POS", function()
            local r = Root()
            if not r then return "-- --  --" end
            local p = r.Position
            return math.floor(p.X)..","..math.floor(p.Y)..","..math.floor(p.Z)
        end, Color3.fromRGB(130,50,255))
    end
})

-- Button: Show Gravity Widget  
Home:AddButton({ Title = "Show Gravity Widget",
    Description = "Opens a small draggable gravity display. Press again to close.",
    Callback = function()
        MakeStatWidget("grav", "GRAV", function()
            return tostring(math.floor(workspace.Gravity))
        end, Color3.fromRGB(234,179,8))
    end
})

-- Button: Close all stat widgets
Home:AddButton({ Title = "Close All Stat Widgets",
    Description = "Closes every open stat widget",
    Callback = function()
        for key, gui in pairs(_statWidgets) do
            pcall(function() gui:Destroy() end)
            _statWidgets[key] = nil
        end
        Notify("Widgets","All stat widgets closed.",2)
    end
})

Home:AddButton({ Title = "Speed Boost  (WalkSpeed = 100)",
    Description = "Set your speed to 100 instantly",
    Callback = function()
        local h = Hum(); if h then h.WalkSpeed = 100 end
        Notify("Speed Boost", "WalkSpeed → 100", 2)
    end
})
Home:AddButton({ Title = "Reset Character",
    Description = "Kill and respawn your character",
    Callback = function()
        local h = Hum(); if h then h.Health = 0 end
        Notify("Reset", "Respawning…", 2)
    end
})
Home:AddButton({ Title = "Go to Spawn",
    Description = "Teleport to SpawnLocation",
    Callback = function()
        local sp = workspace:FindFirstChildOfClass("SpawnLocation"); local rt = Root()
        if sp and rt then rt.CFrame = sp.CFrame + Vector3.new(0,5,0); Notify("Teleport","At spawn.",2)
        else Notify("Teleport","No SpawnLocation found.",2) end
    end
})
Home:AddButton({ Title = "Max Health",
    Description = "Restore your character to full HP",
    Callback = function()
        local h = Hum(); if h then h.Health = h.MaxHealth end
        Notify("Health", "Full HP restored.", 2)
    end
})

-- ═══════════════════════════════════════════════
--  TAB 2 — PLAYER
-- ═══════════════════════════════════════════════
local Player = Window:AddTab({ Title = "Player", Icon = "user" })

-- ── Movement ──────────────────────────────────
Player:AddSlider("WalkSpeed", {
    Title       = "Walk Speed",
    Description = "Adjust your movement speed  (default: 16)",
    Min         = 16,
    Max         = 300,
    Default     = 16,
    Rounding    = 0,
    Callback    = function(v)
        local h = Hum(); if h then h.WalkSpeed = v end
    end,
})

Player:AddSlider("JumpPower", {
    Title       = "Jump Power",
    Description = "Adjust your jump height  (default: 50)",
    Min         = 50,
    Max         = 500,
    Default     = 50,
    Rounding    = 0,
    Callback    = function(v)
        local h = Hum(); if h then h.UseJumpPower = true; h.JumpPower = v end
    end,
})

Player:AddSlider("GravitySlider", {
    Title       = "Gravity",
    Description = "Adjust world gravity  (default: 196)",
    Min         = 0,
    Max         = 400,
    Default     = 196,
    Rounding    = 0,
    Callback    = function(v)
        workspace.Gravity = v
    end,
})

-- ── Abilities ─────────────────────────────────
Player:AddToggle("InfiniteJump", {
    Title       = "Infinite Jump",
    Description = "Jump again while in the air",
    Default     = false,
    Callback    = function(s) infJumpOn = s end,
})

UserInputService.JumpRequest:Connect(function()
    if infJumpOn then
        local h = Hum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

Player:AddToggle("NoClipToggle", {
    Title       = "NoClip",
    Description = "Walk through walls and objects",
    Default     = false,
    Callback    = function(s)
        noclipOn = s
        if s then
            noclipConn = RunService.Stepped:Connect(function()
                if plr.Character then
                    for _, p in pairs(plr.Character:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
            end)
            Notify("NoClip", "Collision disabled.", 2)
        else
            if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
            if plr.Character then
                for _, p in pairs(plr.Character:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
                end
            end
            Notify("NoClip", "Collision restored.", 2)
        end
    end,
})

Player:AddToggle("ImmortalToggle", {
    Title       = "Immortal Mode",
    Description = "Health is locked to maximum — you cannot die",
    Default     = false,
    Callback    = function(s)
        immortalOn = s
        RunService:UnbindFromRenderStep("SHImmortal")
        if s then
            RunService:BindToRenderStep("SHImmortal", 50, function()
                local h = Hum(); if h then h.Health = h.MaxHealth end
            end)
            Notify("Immortal Mode", "You cannot die.", 2)
        else
            Notify("Immortal Mode", "Disabled.", 2)
        end
    end,
})

Player:AddToggle("AntiAFKToggle", {
    Title       = "Anti-AFK",
    Description = "Prevents the idle-kick timer from triggering",
    Default     = false,
    Callback    = function(s)
        antiAFKOn = s
        if s then
            plr.Idled:Connect(function()
                if antiAFKOn then
                    pcall(function()
                        VirtualUser:Button2Down(Vector2.zero, CFrame.new())
                        task.wait(0.1)
                        VirtualUser:Button2Up(Vector2.zero, CFrame.new())
                    end)
                end
            end)
            Notify("Anti-AFK", "Active — you won't be kicked.", 3)
        end
    end,
})

-- ── Quick Actions ─────────────────────────────
-- Store original transparency values so we can restore perfectly
local _origTransparency = {}

Player:AddButton({ Title = "Make Invisible",
    Description = "Makes your character invisible (HumanoidRootPart stays hidden too)",
    Callback = function()
        local char = plr.Character; if not char then return end
        _origTransparency = {}
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then
                _origTransparency[p] = p.Transparency
                p.Transparency = 1
            end
        end
        -- Keep HumanoidRootPart collideable but invisible
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Transparency = 1; hrp.CanCollide = true end
        Notify("Invisible", "Character is now invisible.", 3)
    end
})

Player:AddButton({ Title = "Restore Visibility",
    Description = "Restores every part to its exact original transparency",
    Callback = function()
        local char = plr.Character; if not char then return end
        for _, p in pairs(char:GetDescendants()) do
            if (p:IsA("BasePart") or p:IsA("Decal")) then
                local orig = _origTransparency[p]
                p.Transparency = orig ~= nil and orig or 0
            end
        end
        -- Explicitly zero-out body parts that should be solid
        local solids = {"Head","Torso","UpperTorso","LowerTorso","LeftArm","RightArm",
                         "LeftLeg","RightLeg","LeftUpperArm","RightUpperArm",
                         "LeftLowerArm","RightLowerArm","LeftHand","RightHand",
                         "LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg",
                         "LeftFoot","RightFoot"}
        for _, name in ipairs(solids) do
            local part = char:FindFirstChild(name)
            if part and part:IsA("BasePart") then part.Transparency = 0 end
        end
        -- HumanoidRootPart should stay invisible (its default is 1)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Transparency = 1 end
        _origTransparency = {}
        Notify("Visible", "Visibility fully restored.", 2)
    end
})

Player:AddButton({ Title = "Sit Down",
    Description = "Force your character to sit",
    Callback = function()
        local h = Hum(); if h then h.Sit = true end
    end
})

Player:AddButton({ Title = "Low Gravity  (20)",
    Description = "Quick-set gravity to 20",
    Callback = function()
        workspace.Gravity = 20; Notify("Gravity","Low gravity (20).",2)
    end
})

Player:AddButton({ Title = "Zero Gravity  (0)",
    Description = "Quick-set gravity to 0",
    Callback = function()
        workspace.Gravity = 0; Notify("Gravity","Zero gravity.",2)
    end
})

Player:AddButton({ Title = "Reset Gravity  (196)",
    Description = "Restore gravity to 196",
    Callback = function()
        workspace.Gravity = 196; Notify("Gravity","Reset to 196.",2)
    end
})

-- ═══════════════════════════════════════════════
--  TAB 3 — FLY
-- ═══════════════════════════════════════════════
local FlyTab = Window:AddTab({ Title = "Fly", Icon = "send" })

FlyTab:AddParagraph({
    Title   = "How Fly Works",
    Content = "PC:  WASD to move, Space = go up, LCtrl = go down.\n\n"
        .. "Mobile:  Toggle fly on, then use your normal on-screen joystick to move in any direction. "
        .. "Two floating  ^  v  buttons will appear on screen for altitude control."
})

FlyTab:AddSlider("FlySpeedSlider", {
    Title       = "Fly Speed",
    Description = "How fast you travel while flying",
    Min         = 10,
    Max         = 250,
    Default     = 56,
    Rounding    = 0,
    Callback    = function(v)
        flySpeed = v
    end,
})

-- Build mobile up/down buttons
local function BuildMobileButtons()
    local sg = Instance.new("ScreenGui")
    sg.Name = "SHFlyMob"; sg.ResetOnSpawn = false
    sg.DisplayOrder = 800; sg.IgnoreGuiInset = true; sg.Enabled = true
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    sg.Parent = (ok and cg) and cg or plr:WaitForChild("PlayerGui", 10)

    local function Btn(label, anchorX, key)
        local b = Instance.new("TextButton", sg)
        b.Size = UDim2.new(0, 64, 0, 64)
        b.Position = UDim2.new(anchorX, anchorX > 0.5 and -70 or 0, 1, -88)
        b.AnchorPoint = Vector2.new(0, 1)
        b.BackgroundColor3 = Color3.fromRGB(16, 8, 36)
        b.BackgroundTransparency = 0.15
        b.Text = label
        b.Font = Enum.Font.GothamBlack
        b.TextSize = 28
        b.TextColor3 = Color3.fromRGB(160, 90, 255)
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.ZIndex = 801
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 14)
        local s = Instance.new("UIStroke", b); s.Color = Color3.fromRGB(130,50,255); s.Thickness = 2
        if key == "up" then
            b.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then flyMobUp = true  end end)
            b.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then flyMobUp = false end end)
        else
            b.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then flyMobDn = true  end end)
            b.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then flyMobDn = false end end)
        end
    end

    -- UP button right side, DOWN button left side (so thumbstick isn't blocked)
    Btn("^", 0.88, "up")
    Btn("v", 0.78, "dn")
    return sg
end

FlyTab:AddToggle("FlyToggle", {
    Title       = "Fly Mode",
    Description = "Mobile: joystick moves, ^ v for altitude  |  PC: WASD + Space / LCtrl",
    Default     = false,
    Callback    = function(s)
        flyOn = s
        local isMob = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

        -- Mobile altitude buttons
        if s and isMob then
            if flyMobGui then pcall(function() flyMobGui:Destroy() end) end
            flyMobGui = BuildMobileButtons()
        elseif not s then
            flyMobUp = false; flyMobDn = false
            if flyMobGui then pcall(function() flyMobGui:Destroy() end); flyMobGui = nil end
        end

        local char = plr.Character
        if s and char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then flyOn = false; return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = true end

            flyBG = Instance.new("BodyGyro", root)
            flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9); flyBG.D = 120
            flyBV = Instance.new("BodyVelocity", root)
            flyBV.MaxForce  = Vector3.new(1e9, 1e9, 1e9); flyBV.Velocity = Vector3.zero

            RunService:BindToRenderStep("SHFly", 200, function()
                if not flyOn then
                    RunService:UnbindFromRenderStep("SHFly")
                    pcall(function() flyBV:Destroy(); flyBG:Destroy() end)
                    local h2 = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                    if h2 then h2.PlatformStand = false end
                    return
                end
                local spd = flySpeed
                local vel = Vector3.zero
                local cam = workspace.CurrentCamera
                local ki  = UserInputService.KeyboardEnabled

                if ki then
                    if UserInputService:IsKeyDown(Enum.KeyCode.W)           then vel = vel + cam.CFrame.LookVector  * spd end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S)           then vel = vel - cam.CFrame.LookVector  * spd end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A)           then vel = vel - cam.CFrame.RightVector * spd end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D)           then vel = vel + cam.CFrame.RightVector * spd end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then vel = vel + Vector3.new(0, spd, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel = vel - Vector3.new(0, spd, 0) end
                else
                    -- Read the built-in thumbstick via MoveDirection
                    local hum2 = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum2 and hum2.MoveDirection.Magnitude > 0.05 then
                        local md = hum2.MoveDirection
                        vel = vel + Vector3.new(md.X, 0, md.Z) * spd
                    end
                    if flyMobUp then vel = vel + Vector3.new(0, spd, 0) end
                    if flyMobDn then vel = vel - Vector3.new(0, spd, 0) end
                end

                flyBV.Velocity = vel
                flyBG.CFrame   = cam.CFrame
            end)

            if isMob then
                Notify("Fly Active", "Use your joystick to move.  ^ = up   v = down.", 4)
            else
                Notify("Fly Active", "WASD to move  /  Space = up  /  LCtrl = down", 3)
            end
        else
            RunService:UnbindFromRenderStep("SHFly")
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    for _, c in pairs(root:GetChildren()) do
                        if c:IsA("BodyVelocity") or c:IsA("BodyGyro") then c:Destroy() end
                    end
                end
                local h2 = char:FindFirstChildOfClass("Humanoid")
                if h2 then h2.PlatformStand = false end
            end
        end
    end,
})

-- ═══════════════════════════════════════════════
--  TAB 4 — COMBAT
-- ═══════════════════════════════════════════════
local Combat = Window:AddTab({ Title = "Combat", Icon = "sword" })

Combat:AddParagraph({
    Title   = "Combat Features",
    Content = "Kill Aura, Silent Aim, Anti-Knockback, Reach, Trigger Bot, Auto Click.\n"
        .. "Adjust ranges with the sliders below each toggle.",
})

-- Kill Aura
Combat:AddToggle("KillAuraToggle", {
    Title       = "Kill Aura",
    Description = "Automatically deals lethal damage to nearby players",
    Default     = false,
    Callback    = function(s)
        killAuraOn = s
        if killAuraConn then killAuraConn:Disconnect(); killAuraConn = nil end
        if s then
            killAuraConn = RunService.Heartbeat:Connect(function()
                local root = Root(); if not root then return end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= plr and p.Character then
                        local pr = p.Character:FindFirstChild("HumanoidRootPart")
                        local ph = p.Character:FindFirstChildOfClass("Humanoid")
                        if pr and ph then
                            local dist = (root.Position - pr.Position).Magnitude
                            if dist <= killAuraRange then
                                ph:TakeDamage(ph.MaxHealth * 10)
                            end
                        end
                    end
                end
            end)
            Notify("Kill Aura", "Active — eliminating nearby players.", 3)
        else
            Notify("Kill Aura", "Disabled.", 2)
        end
    end,
})

Combat:AddSlider("KillAuraRangeSlider", {
    Title       = "Kill Aura Range",
    Description = "Distance in studs",
    Min         = 5,
    Max         = 100,
    Default     = 15,
    Rounding    = 0,
    Callback    = function(v) killAuraRange = v end,
})

-- Auto Click
Combat:AddToggle("AutoClickToggle", {
    Title       = "Auto Click",
    Description = "Rapidly fires clicks every frame (for combat games)",
    Default     = false,
    Callback    = function(s)
        autoClickOn = s
        if autoClickConn then autoClickConn:Disconnect(); autoClickConn = nil end
        if s then
            autoClickConn = RunService.Heartbeat:Connect(function()
                if not autoClickOn then return end
                pcall(function()
                    local vm = game:GetService("VirtualInputManager")
                    vm:SendMouseButtonEvent(mouse.X, mouse.Y, 0, true,  game, 1)
                    vm:SendMouseButtonEvent(mouse.X, mouse.Y, 0, false, game, 1)
                end)
            end)
            Notify("Auto Click", "Active.", 2)
        else
            Notify("Auto Click", "Disabled.", 2)
        end
    end,
})

-- Silent Aim
Combat:AddToggle("SilentAimToggle", {
    Title       = "Silent Aim",
    Description = "Redirects your mouse.Hit to the nearest player's head",
    Default     = false,
    Callback    = function(s)
        silentAimOn = s
        Notify(s and "Silent Aim" or "Silent Aim", s and "Active." or "Disabled.", 2)
    end,
})

RunService.RenderStepped:Connect(function()
    if not silentAimOn then return end
    local root = Root(); if not root then return end
    local closest, closestDist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= plr and p.Character then
            local head = p.Character:FindFirstChild("Head")
            if head then
                local d = (root.Position - head.Position).Magnitude
                if d < closestDist then closestDist = d; closest = head end
            end
        end
    end
    if closest then
        pcall(function() mouse.Hit = CFrame.new(closest.Position) end)
    end
end)

-- Anti-Knockback
Combat:AddToggle("AntiKBToggle", {
    Title       = "Anti-Knockback",
    Description = "Destroys BodyVelocity forces applied to you",
    Default     = false,
    Callback    = function(s)
        antiKBOn = s
        RunService:UnbindFromRenderStep("SHAntiKB")
        if s then
            RunService:BindToRenderStep("SHAntiKB", 300, function()
                local root = Root(); if not root then return end
                for _, c in pairs(root:GetChildren()) do
                    if c:IsA("BodyVelocity") or c:IsA("BodyForce") then c:Destroy() end
                end
            end)
            Notify("Anti-Knockback", "Active.", 2)
        else
            Notify("Anti-Knockback", "Disabled.", 2)
        end
    end,
})

-- Reach Extender
Combat:AddToggle("ReachToggle", {
    Title       = "Reach Extender",
    Description = "Extends melee range — damages players within reach",
    Default     = false,
    Callback    = function(s)
        reachOn = s
        if reachConn then reachConn:Disconnect(); reachConn = nil end
        if s then
            reachConn = RunService.Heartbeat:Connect(function()
                local root = Root(); if not root then return end
                local char = plr.Character; if not char then return end
                local tool = char:FindFirstChildOfClass("Tool"); if not tool then return end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= plr and p.Character then
                        local pr = p.Character:FindFirstChild("HumanoidRootPart")
                        local ph = p.Character:FindFirstChildOfClass("Humanoid")
                        if pr and ph then
                            local d = (root.Position - pr.Position).Magnitude
                            if d <= reachRange then ph:TakeDamage(10) end
                        end
                    end
                end
            end)
            Notify("Reach Extender", "Active.", 2)
        else
            Notify("Reach Extender", "Disabled.", 2)
        end
    end,
})

Combat:AddSlider("ReachRangeSlider", {
    Title       = "Reach Range",
    Description = "Extended range in studs",
    Min         = 5,
    Max         = 100,
    Default     = 30,
    Rounding    = 0,
    Callback    = function(v) reachRange = v end,
})

-- Trigger Bot
Combat:AddToggle("TriggerBotToggle", {
    Title       = "Trigger Bot",
    Description = "Automatically clicks when your crosshair is on an enemy",
    Default     = false,
    Callback    = function(s)
        triggerBotOn = s
        RunService:UnbindFromRenderStep("SHTrigger")
        if s then
            RunService:BindToRenderStep("SHTrigger", 250, function()
                if not triggerBotOn then RunService:UnbindFromRenderStep("SHTrigger"); return end
                local target = mouse.Target
                if target and target.Parent then
                    local tp = Players:GetPlayerFromCharacter(target.Parent)
                    if tp and tp ~= plr then
                        pcall(function()
                            local vm = game:GetService("VirtualInputManager")
                            vm:SendMouseButtonEvent(mouse.X, mouse.Y, 0, true,  game, 1)
                            vm:SendMouseButtonEvent(mouse.X, mouse.Y, 0, false, game, 1)
                        end)
                    end
                end
            end)
            Notify("Trigger Bot", "Active.", 2)
        else
            Notify("Trigger Bot", "Disabled.", 2)
        end
    end,
})

-- Speed Hack
Combat:AddToggle("SpeedHackToggle", {
    Title       = "Speed Hack",
    Description = "Locks WalkSpeed to 500 continuously",
    Default     = false,
    Callback    = function(s)
        speedHackOn = s
        RunService:UnbindFromRenderStep("SHSpeedH")
        if s then
            RunService:BindToRenderStep("SHSpeedH", 50, function()
                local h = Hum(); if h then h.WalkSpeed = 500 end
            end)
            Notify("Speed Hack", "WalkSpeed locked at 500.", 2)
        else
            Notify("Speed Hack", "Disabled.", 2)
        end
    end,
})

-- One-shot buttons
Combat:AddButton({ Title = "Snap Aim to Nearest",
    Description = "Instantly look at the closest player's head",
    Callback = function()
        local root = Root(); if not root then return end
        local closest, closestDist = nil, math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= plr and p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    local d = (root.Position - head.Position).Magnitude
                    if d < closestDist then closestDist = d; closest = head end
                end
            end
        end
        if closest then
            workspace.CurrentCamera.CFrame =
                CFrame.new(workspace.CurrentCamera.CFrame.Position, closest.Position)
            Notify("Snap Aim", "Aimed at nearest player.", 2)
        else Notify("Snap Aim", "No players nearby.", 2) end
    end
})

Combat:AddButton({ Title = "Kill Nearest Player",
    Description = "Deal lethal damage to the closest enemy",
    Callback = function()
        local root = Root(); if not root then return end
        local closest, closestDist = nil, math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= plr and p.Character then
                local pr = p.Character:FindFirstChild("HumanoidRootPart")
                local ph = p.Character:FindFirstChildOfClass("Humanoid")
                if pr and ph then
                    local d = (root.Position - pr.Position).Magnitude
                    if d < closestDist then closestDist = d; closest = ph end
                end
            end
        end
        if closest then
            closest:TakeDamage(closest.MaxHealth * 999)
            Notify("Kill", "Damage dealt to nearest player.", 2)
        else Notify("Kill", "No players nearby.", 2) end
    end
})

Combat:AddButton({ Title = "Teleport Behind Nearest",
    Description = "Silently appear behind the closest enemy",
    Callback = function()
        local root = Root(); if not root then return end
        local closest, closestDist = nil, math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= plr and p.Character then
                local pr = p.Character:FindFirstChild("HumanoidRootPart")
                if pr then
                    local d = (root.Position - pr.Position).Magnitude
                    if d < closestDist then closestDist = d; closest = pr end
                end
            end
        end
        if closest then
            root.CFrame = closest.CFrame * CFrame.new(0, 0, 2)
            Notify("Teleport Behind", "Behind nearest player.", 2)
        else Notify("Teleport Behind", "No players nearby.", 2) end
    end
})

Combat:AddButton({ Title = "Fling Nearest Player",
    Description = "Apply massive upward velocity to nearest enemy",
    Callback = function()
        local root = Root(); if not root then return end
        local closest, closestDist = nil, math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= plr and p.Character then
                local pr = p.Character:FindFirstChild("HumanoidRootPart")
                if pr then
                    local d = (root.Position - pr.Position).Magnitude
                    if d < closestDist then closestDist = d; closest = pr end
                end
            end
        end
        if closest then
            local bv = Instance.new("BodyVelocity", closest)
            bv.Velocity   = Vector3.new(math.random(-200,200), 600, math.random(-200,200))
            bv.MaxForce   = Vector3.new(1e9,1e9,1e9)
            task.delay(0.2, function() pcall(function() bv:Destroy() end) end)
            Notify("Fling", "Player flung!", 2)
        else Notify("Fling", "No players nearby.", 2) end
    end
})

-- ═══════════════════════════════════════════════
--  TAB 5 — FUN
-- ═══════════════════════════════════════════════
local Fun = Window:AddTab({ Title = "Fun", Icon = "flame" })

Fun:AddButton({ Title = "Fling Self Upward",
    Description = "Launch your character high into the air",
    Callback = function()
        local root = Root()
        if root then
            local bv = Instance.new("BodyVelocity", root)
            bv.Velocity = Vector3.new(0, 500, 0); bv.MaxForce = Vector3.new(1e9,1e9,1e9)
            task.delay(0.2, function() pcall(function() bv:Destroy() end) end)
            Notify("Fling", "Launched!", 2)
        end
    end
})

Fun:AddButton({ Title = "Super Jump  (once)",
    Description = "One massive single jump",
    Callback = function()
        local h = Hum(); local root = Root()
        if h and root then
            h.UseJumpPower = true; h.JumpPower = 500
            h:ChangeState(Enum.HumanoidStateType.Jumping)
            task.delay(0.5, function() h.JumpPower = 50 end)
            Notify("Super Jump", "Launched!", 2)
        end
    end
})

Fun:AddButton({ Title = "Spin for 3 seconds",
    Description = "Rapidly spins your character",
    Callback = function()
        local root = Root(); if not root then return end
        local bg = Instance.new("BodyAngularVelocity", root)
        bg.AngularVelocity = Vector3.new(0, 120, 0); bg.MaxTorque = Vector3.new(0, 1e9, 0)
        task.delay(3, function() pcall(function() bg:Destroy() end) end)
        Notify("Spin", "Spinning for 3 seconds.", 2)
    end
})

Fun:AddButton({ Title = "Speed x2",
    Description = "Double your current WalkSpeed",
    Callback = function()
        local h = Hum()
        if h then
            h.WalkSpeed = math.min(h.WalkSpeed * 2, 500)
            Notify("Speed x2", "WalkSpeed → " .. h.WalkSpeed, 2)
        end
    end
})

-- ── Rainbow Baseplate ─────────────────────────
Fun:AddToggle("RainbowBPToggle", {
    Title       = "Rainbow Baseplate",
    Description = "Cycles the baseplate through all colours",
    Default     = false,
    Callback    = function(s)
        rainbowBPOn = s
        if s then
            RunService:BindToRenderStep("SHRB", 50, function()
                local bp = workspace:FindFirstChild("Baseplate")
                if bp and bp:IsA("BasePart") then
                    bp.Color = Color3.fromHSV(tick() % 6 / 6, 0.9, 1)
                end
            end)
            Notify("Rainbow BP", "Active.", 2)
        else
            RunService:UnbindFromRenderStep("SHRB")
            -- Restore to the last chosen colour
            SetBP(chosenBPColor)
            Notify("Rainbow BP", "Stopped — colour restored.", 2)
        end
    end,
})

-- Custom colour chooser
local bpColours = {
    ["Original"]    = origBPColor,
    ["Purple"]      = Color3.fromRGB(130, 50, 255),
    ["Red"]         = Color3.fromRGB(220, 50, 50),
    ["Blue"]        = Color3.fromRGB(30, 100, 220),
    ["Green"]       = Color3.fromRGB(34, 197, 94),
    ["Yellow"]      = Color3.fromRGB(234, 179, 8),
    ["Orange"]      = Color3.fromRGB(234, 120, 10),
    ["Pink"]        = Color3.fromRGB(236, 72, 153),
    ["Cyan"]        = Color3.fromRGB(6, 182, 212),
    ["White"]       = Color3.fromRGB(255, 255, 255),
    ["Black"]       = Color3.fromRGB(10, 10, 10),
    ["Gold"]        = Color3.fromRGB(212, 175, 55),
    ["Neon Green"]  = Color3.fromRGB(57, 255, 20),
    ["Neon Pink"]   = Color3.fromRGB(255, 20, 147),
    ["Sky Blue"]    = Color3.fromRGB(135, 206, 235),
    ["Dark Red"]    = Color3.fromRGB(139, 0, 0),
}
local bpNames = {}
for k in pairs(bpColours) do table.insert(bpNames, k) end
table.sort(bpNames)

Fun:AddDropdown("BPColorDrop", {
    Title       = "Baseplate Colour",
    Description = "Colour applied when Rainbow is off, and stored for when you stop rainbow",
    Values      = bpNames,
    Default     = "Original",
    Callback    = function(v)
        local col = bpColours[v]
        if col then
            chosenBPColor = col
            if not rainbowBPOn then SetBP(col) end
            Notify("Baseplate", "Colour set to " .. v .. ".", 2)
        end
    end,
})

Fun:AddButton({ Title = "Apply Chosen Colour Now",
    Description = "Force-apply the selected colour and stop rainbow",
    Callback = function()
        RunService:UnbindFromRenderStep("SHRB"); rainbowBPOn = false
        SetBP(chosenBPColor); Notify("Baseplate", "Colour applied.", 2)
    end
})
Fun:AddButton({ Title = "Restore Original Colour",
    Description = "Reset baseplate to the colour it had on script load",
    Callback = function()
        RunService:UnbindFromRenderStep("SHRB"); rainbowBPOn = false
        chosenBPColor = origBPColor; SetBP(origBPColor)
        Notify("Baseplate", "Original colour restored.", 2)
    end
})

-- ═══════════════════════════════════════════════
--  TAB 6 — VISUAL
-- ═══════════════════════════════════════════════
local Visual = Window:AddTab({ Title = "Visual", Icon = "eye" })

-- Lighting
Visual:AddToggle("FullbrightToggle", {
    Title       = "Fullbright",
    Description = "Removes all shadow and ambient darkness",
    Default     = false,
    Callback    = function(s)
        if s then
            Lighting.Brightness     = 2
            Lighting.Ambient        = Color3.fromRGB(178, 178, 178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        else
            Lighting.Brightness     = origBright
            Lighting.Ambient        = origAmb
            Lighting.OutdoorAmbient = origOut
        end
        Notify("Fullbright", s and "Enabled." or "Restored.", 2)
    end,
})

Visual:AddToggle("NoFogToggle", {
    Title       = "No Fog",
    Description = "Removes world fog entirely",
    Default     = false,
    Callback    = function(s)
        Lighting.FogEnd = s and 1e9 or origFogEnd
    end,
})

Visual:AddSlider("TimeSlider", {
    Title       = "Time of Day",
    Description = "0 = midnight  |  14 = daytime  |  24 = midnight",
    Min         = 0,
    Max         = 24,
    Default     = 14,
    Rounding    = 0,
    Callback    = function(v) Lighting.ClockTime = v end,
})

Visual:AddSlider("BrightSlider", {
    Title       = "Scene Brightness",
    Description = "Increases global light brightness",
    Min         = 0,
    Max         = 5,
    Default     = 1,
    Rounding    = 1,
    Callback    = function(v) Lighting.Brightness = v end,
})

Visual:AddButton({ Title = "Preset: Day",     Description = "ClockTime = 14", Callback = function() Lighting.ClockTime = 14;  Notify("Time","Day.",2)     end })
Visual:AddButton({ Title = "Preset: Sunrise", Description = "ClockTime = 6",  Callback = function() Lighting.ClockTime = 6;   Notify("Time","Sunrise.",2)  end })
Visual:AddButton({ Title = "Preset: Sunset",  Description = "ClockTime = 19", Callback = function() Lighting.ClockTime = 19;  Notify("Time","Sunset.",2)   end })
Visual:AddButton({ Title = "Preset: Night",   Description = "ClockTime = 0",  Callback = function() Lighting.ClockTime = 0;   Notify("Time","Night.",2)    end })

-- Camera
Visual:AddSlider("FOVSlider", {
    Title       = "Camera FOV",
    Description = "Field of view  (default: 70)",
    Min         = 60,
    Max         = 120,
    Default     = 70,
    Rounding    = 0,
    Callback    = function(v) workspace.CurrentCamera.FieldOfView = v end,
})

Visual:AddSlider("ZoomSlider", {
    Title       = "Max Zoom Distance",
    Description = "How far back the camera can pull",
    Min         = 5,
    Max         = 1000,
    Default     = 400,
    Rounding    = 0,
    Callback    = function(v) plr.CameraMaxZoomDistance = v end,
})

Visual:AddButton({ Title = "Reset FOV", Description = "Restore to 70",
    Callback = function() workspace.CurrentCamera.FieldOfView = 70; Notify("FOV","Reset.",2) end
})

-- ESP
Visual:AddToggle("ESPToggle", {
    Title       = "Player Highlights  (ESP)",
    Description = "Adds a glowing outline around all other players",
    Default     = false,
    Callback    = function(s)
        if s then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= plr and p.Character then
                    local hl = Instance.new("Highlight", p.Character)
                    hl.FillColor        = espColor
                    hl.OutlineColor     = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.55
                    espObjs[p.UserId]   = hl
                end
            end
            Notify("ESP", "Highlights enabled.", 2)
        else
            for _, hl in pairs(espObjs) do pcall(function() hl:Destroy() end) end
            espObjs = {}
        end
    end,
})

local espCols = { "Purple","Red","Green","Blue","Yellow","White","Cyan","Pink","Orange" }
local espColMap = {
    Purple=Color3.fromRGB(130,50,255), Red=Color3.fromRGB(220,50,50),
    Green=Color3.fromRGB(34,197,94),   Blue=Color3.fromRGB(30,100,220),
    Yellow=Color3.fromRGB(234,179,8),  White=Color3.fromRGB(255,255,255),
    Cyan=Color3.fromRGB(6,182,212),    Pink=Color3.fromRGB(236,72,153),
    Orange=Color3.fromRGB(234,120,10),
}

Visual:AddDropdown("ESPColorDrop", {
    Title       = "ESP Colour",
    Description = "Changes the fill colour of the highlight",
    Values      = espCols,
    Default     = "Purple",
    Callback    = function(v)
        local col = espColMap[v]
        if col then
            espColor = col
            for _, hl in pairs(espObjs) do pcall(function() hl.FillColor = col end) end
            Notify("ESP Colour", "Set to " .. v .. ".", 2)
        end
    end,
})

Visual:AddToggle("NameTagsToggle", {
    Title       = "Name Tags",
    Description = "Show floating names above every player's head",
    Default     = false,
    Callback    = function(s)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= plr and p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    if s then
                        local bg = Instance.new("BillboardGui", head)
                        bg.Name="SHTag"; bg.Size=UDim2.new(0,100,0,22)
                        bg.StudsOffset=Vector3.new(0,3,0); bg.AlwaysOnTop=true
                        local tl = Instance.new("TextLabel", bg)
                        tl.Size=UDim2.new(1,0,1,0); tl.BackgroundTransparency=1
                        tl.Text=p.Name; tl.Font=Enum.Font.GothamBold; tl.TextSize=13
                        tl.TextColor3=Color3.fromRGB(130,50,255)
                    else
                        for _, c in pairs(head:GetChildren()) do
                            if c.Name=="SHTag" then c:Destroy() end
                        end
                    end
                end
            end
        end
        Notify("Name Tags", s and "Enabled." or "Disabled.", 2)
    end,
})

Visual:AddToggle("ChamsToggle", {
    Title       = "Chams  (Neon enemies)",
    Description = "Makes all enemy characters emit neon glow",
    Default     = false,
    Callback    = function(s)
        chamsOn = s
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= plr and p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Material = s and Enum.Material.Neon or Enum.Material.SmoothPlastic
                    end
                end
            end
        end
        Notify("Chams", s and "Neon chams active." or "Disabled.", 2)
    end,
})

Visual:AddToggle("CrosshairToggle", {
    Title       = "Dot Crosshair",
    Description = "Draws a small dot at the centre of your screen",
    Default     = false,
    Callback    = function(s)
        if s then
            xhairGui = Instance.new("ScreenGui")
            xhairGui.Name="SHCrosshair"; xhairGui.ResetOnSpawn=false
            xhairGui.DisplayOrder=999; xhairGui.IgnoreGuiInset=true
            local ok, cg = pcall(function() return game:GetService("CoreGui") end)
            xhairGui.Parent = (ok and cg) and cg or plr:WaitForChild("PlayerGui",10)
            local f = Instance.new("Frame", xhairGui)
            f.Size=UDim2.new(0,7,0,7); f.Position=UDim2.fromScale(0.5,0.5)
            f.AnchorPoint=Vector2.new(0.5,0.5); f.BackgroundColor3=xhairColor
            f.BorderSizePixel=0; f.ZIndex=999
            Instance.new("UICorner",f).CornerRadius=UDim.new(0,4)
        else
            if xhairGui then xhairGui:Destroy(); xhairGui=nil end
        end
    end,
})

Visual:AddDropdown("CrosshairColorDrop", {
    Title       = "Crosshair Colour",
    Values      = espCols,
    Default     = "Purple",
    Callback    = function(v)
        local col = espColMap[v]
        if col then
            xhairColor = col
            if xhairGui then
                for _, f in pairs(xhairGui:GetDescendants()) do
                    if f:IsA("Frame") then f.BackgroundColor3 = col end
                end
            end
        end
    end,
})

-- ═══════════════════════════════════════════════
--  TAB 7 — TELEPORT
-- ═══════════════════════════════════════════════
local Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin" })

Teleport:AddButton({ Title = "Go to Spawn",     Description = "Teleport to SpawnLocation",  Callback = function()
    local sp=workspace:FindFirstChildOfClass("SpawnLocation"); local rt=Root()
    if sp and rt then rt.CFrame=sp.CFrame+Vector3.new(0,5,0); Notify("Teleport","At spawn.",2)
    else Notify("Teleport","No SpawnLocation found.",2) end
end })
Teleport:AddButton({ Title = "Origin  (0,0,0)", Description = "Teleport to world centre", Callback = function()
    local rt=Root(); if rt then rt.CFrame=CFrame.new(0,10,0); Notify("Teleport","At origin.",2) end
end })
Teleport:AddButton({ Title = "Teleport to Cursor", Description = "PC — teleports to mouse hit position", Callback = function()
    local hit=mouse.Hit; local rt=Root()
    if hit and rt then rt.CFrame=CFrame.new(hit.Position+Vector3.new(0,4,0)); Notify("Teleport","Done.",2) end
end })

-- XYZ inputs
Teleport:AddInput("TpX", { Title="X", Default="0",  Placeholder="X coordinate", Numeric=true, Finished=false, Callback=function() end })
Teleport:AddInput("TpY", { Title="Y", Default="50", Placeholder="Y coordinate", Numeric=true, Finished=false, Callback=function() end })
Teleport:AddInput("TpZ", { Title="Z", Default="0",  Placeholder="Z coordinate", Numeric=true, Finished=false, Callback=function() end })
Teleport:AddButton({ Title="Teleport to XYZ", Description="Use the values entered above", Callback=function()
    local x=tonumber(Fluent.Options.TpX.Value)
    local y=tonumber(Fluent.Options.TpY.Value)
    local z=tonumber(Fluent.Options.TpZ.Value)
    local rt=Root()
    if x and y and z and rt then
        rt.CFrame=CFrame.new(x,y,z); Notify("Teleport","("..x..", "..y..", "..z..")",2)
    else Notify("Teleport","Enter valid numbers.",3) end
end })

-- ── Teleport to Player ────────────────────────
Teleport:AddParagraph({ Title="Teleport to Player",
    Content="Pick a player from the dropdown, then press the button.\n"
        .. "Hit Refresh if the list is outdated.\n"
        .. "Press Select None to cancel your selection."
})

local tpDropdown = Teleport:AddDropdown("TpPlayerDrop", {
    Title       = "Select Player",
    Description = "Choose who to jump to",
    Values      = GetPlayerNames(),
    Default     = "None",
    Callback    = function(v)
        selectedTPPlayer = v
        if v ~= "None" then
            Notify("Player Selected", v .. " — press the button to teleport.", 2)
        end
    end,
})

Teleport:AddButton({ Title = "Refresh Player List",
    Description = "Update the dropdown with current server players",
    Callback = function()
        local names = GetPlayerNames()
        tpDropdown:SetValues(names)
        selectedTPPlayer = "None"
        Notify("Refreshed", tostring(#names - 1) .. " players found.", 3)
    end
})

Teleport:AddButton({ Title = "Teleport to Selected Player",
    Description = "Jump to the player chosen in the dropdown",
    Callback = function()
        if selectedTPPlayer == "None" or selectedTPPlayer == "" then
            Notify("Teleport", "No player selected.", 3); return
        end
        local target = Players:FindFirstChild(selectedTPPlayer)
        local rt = Root()
        if target and target.Character and rt then
            local tr = target.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                rt.CFrame = tr.CFrame + Vector3.new(3, 3, 0)
                Notify("Teleport", "Jumped to " .. selectedTPPlayer .. "!", 2)
            else Notify("Teleport", "Root part not found.", 2) end
        else Notify("Teleport", "Player not found.", 2) end
    end
})

Teleport:AddButton({ Title = "Select None  (Cancel)",
    Description = "Clear the current player selection",
    Callback = function()
        selectedTPPlayer = "None"
        pcall(function() tpDropdown:SetValue("None") end)
        Notify("Cancelled", "Selection cleared.", 2)
    end
})

Teleport:AddButton({ Title = "Server Hop", Description = "Rejoin a different server", Callback = function()
    Notify("Server Hop","Finding new server…",2)
    task.delay(1.5, function() pcall(function() TeleportService:Teleport(game.PlaceId,plr) end) end)
end })
Teleport:AddButton({ Title = "Rejoin Game",  Description = "Reconnect to this same server", Callback = function()
    Notify("Rejoin","Reconnecting…",2)
    pcall(function() TeleportService:Teleport(game.PlaceId,plr) end)
end })

-- ═══════════════════════════════════════════════
--  TAB 8 — UTILITY
-- ═══════════════════════════════════════════════
local Utility = Window:AddTab({ Title = "Utility", Icon = "settings-2" })

-- Stat widgets are created by MakeStatWidget() defined in Home tab.
-- These buttons are shortcuts to the same widgets.
Utility:AddButton({ Title = "Show FPS Widget",
    Description = "Small draggable FPS counter. Press again to close.",
    Callback = function()
        MakeStatWidget("fps","FPS",function() return tostring(fpsVal) end, Color3.fromRGB(34,197,94))
    end
})
Utility:AddButton({ Title = "Show Ping Widget",
    Description = "Small draggable Ping counter. Press again to close.",
    Callback = function()
        MakeStatWidget("ping","PING",function() return tostring(pingVal).." ms" end, Color3.fromRGB(6,182,212))
    end
})
Utility:AddButton({ Title = "Show Position Widget",
    Description = "Small draggable XYZ tracker. Press again to close.",
    Callback = function()
        MakeStatWidget("pos","POS",function()
            local r=Root(); if not r then return "--,--,--" end
            local p=r.Position; return math.floor(p.X)..","..math.floor(p.Y)..","..math.floor(p.Z)
        end, Color3.fromRGB(130,50,255))
    end
})
Utility:AddButton({ Title = "Show Gravity Widget",
    Description = "Small draggable gravity display. Press again to close.",
    Callback = function()
        MakeStatWidget("grav","GRAV",function() return tostring(math.floor(workspace.Gravity)) end, Color3.fromRGB(234,179,8))
    end
})
Utility:AddButton({ Title = "Close All Stat Widgets",
    Description = "Closes every open stat widget at once",
    Callback = function()
        for key,gui in pairs(_statWidgets) do
            pcall(function() gui:Destroy() end); _statWidgets[key]=nil
        end
        Notify("Widgets","All widgets closed.",2)
    end
})

Utility:AddButton({ Title="Copy Game ID",    Description="Copy PlaceId to clipboard",         Callback=function() pcall(function() setclipboard(tostring(game.PlaceId)) end); Notify("Copied","Game ID: "..game.PlaceId,3) end })
Utility:AddButton({ Title="Copy Username",   Description="Copy your username to clipboard",    Callback=function() pcall(function() setclipboard(plr.Name) end);             Notify("Copied",plr.Name,2)                 end })
Utility:AddButton({ Title="Copy User ID",    Description="Copy your UserId",                  Callback=function() pcall(function() setclipboard(tostring(plr.UserId)) end); Notify("Copied","UserId: "..plr.UserId,2)   end })
Utility:AddButton({ Title="Copy Job ID",     Description="Copy this server's JobId",          Callback=function() pcall(function() setclipboard(game.JobId) end);            Notify("Copied","Job ID copied.",3)         end })
Utility:AddButton({ Title="Copy Position",   Description="Copy your XYZ coordinates",
    Callback=function()
        local rt = Root()
        if rt then
            local p = rt.Position
            local s2 = math.floor(p.X)..","..math.floor(p.Y)..","..math.floor(p.Z)
            pcall(function() setclipboard(s2) end)
            Notify("Copied","Position: "..s2,3)
        end
    end
})

Utility:AddButton({ Title="Refresh Player List", Description="Re-scan players in this server",
    Callback=function()
        local names={}; for _,p in pairs(Players:GetPlayers()) do table.insert(names,p.Name) end
        Notify("Players ("..#names..")", table.concat(names,", "),5)
    end
})

Utility:AddButton({ Title="Destroy GUI", Description="Permanently remove Shadow Hub",
    Callback=function()
        Notify("Goodbye","Shadow Hub removed.",2); task.wait(2.2); Window:Destroy()
    end
})

-- ═══════════════════════════════════════════════
--  TAB 9 — INFO
-- ═══════════════════════════════════════════════
local Info = Window:AddTab({ Title = "Info", Icon = "info" })

Info:AddParagraph({ Title="About Shadow Hub",
    Content="Shadow Hub v2.1.0 is a premium Roblox script hub built for PC and Mobile.\n\n"
        .."Tabs: Home · Player · Fly · Combat · Fun · Visual · Teleport · Utility · Info · Settings\n\n"
        .."Built with smooth and powerful UI.\n"
        .."All settings auto-save via SaveManager."
})
Info:AddParagraph({ Title="Author",
    Content="Created by Shadow.\n"
        .."Join our Discord for keys, updates and support."
})
Info:AddParagraph({ Title="PC Controls",
    Content="RightControl  —  Toggle UI on / off\n"
        .."Fly: WASD to move, Space = up, LCtrl = down\n"
        .."Combat > Snap Aim — instantly look at nearest player"
})
Info:AddParagraph({ Title="Mobile Controls",
    Content="Use the Fluent minimize button to show/hide the UI.\n"
        .."Fly: Enable the toggle, then use the on-screen joystick.\n"
        .."Two floating  ^  v  buttons appear for altitude.\n"
        .."All sliders and toggles are fully touch-compatible."
})
Info:AddParagraph({ Title="Tabs Guide",
    Content="Home       —  Quick stats and fast actions\n"
        .."Player     —  Speed, jump, gravity, NoClip, Immortal\n"
        .."Fly        —  Fly toggle and speed (PC + Mobile)\n"
        .."Combat     —  Kill Aura, Silent Aim, Anti-KB, Reach…\n"
        .."Fun        —  Fling, spin, rainbow baseplate, colours\n"
        .."Visual     —  ESP, Fullbright, FOV, Chams, Crosshair\n"
        .."Teleport   —  Spawn, XYZ, player list, server hop\n"
        .."Utility    —  FPS/Ping, copy tools, player list\n"
        .."Info       —  This page\n"
        .."Settings   —  Config save/load, theme, keybind"
})
Info:AddParagraph({ Title="Baseplate Colours",
    Content="Fun tab → pick a colour from the Baseplate Colour dropdown.\n"
        .."When you turn Rainbow off, the baseplate auto-restores to your chosen colour.\n"
        .."Press Restore Original Colour to go back to the game's default."
})
Info:AddParagraph({ Title="Teleport to Player",
    Content="Teleport tab → Select Player dropdown → choose a name → Teleport button.\n"
        .."Press Refresh if the list is outdated.\n"
        .."Press Select None to cancel."
})
Info:AddParagraph({ Title="Executor Compatibility",
    Content="Tested working on:\n"
        .."Codex  ·  Fluxus  ·  Delta  ·  Solara  ·  Synapse-style\n"
        .."If something happened try executing the script again or contact support."
})
Info:AddParagraph({ Title="Disclaimer",
    Content="For educational and personal use only.\n"
        .."Shadow Hub is not responsible for bans or actions by Roblox.\n"
        .."Use features responsibly."
})

-- ═══════════════════════════════════════════════
--  TAB 10 — SETTINGS  (always last)
-- ═══════════════════════════════════════════════
local Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })

SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "TpX","TpY","TpZ","TpPlayerDrop" })
SaveManager:SetFolder("ShadowHub")
SaveManager:BuildConfigSection(Settings)

InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("ShadowHub")
InterfaceManager:BuildInterfaceSection(Settings)

Settings:AddButton({ Title="Save Config",
    Description="Write all current settings to file",
    Callback=function() SaveManager:Save(); Notify("Config","Saved.",3) end
})
Settings:AddButton({ Title="Load Config",
    Description="Restore settings from last saved file",
    Callback=function() SaveManager:Load(); Notify("Config","Loaded.",3) end
})
Settings:AddButton({ Title="Reset All to Defaults",
    Description="Restore WalkSpeed, JumpPower, Gravity and Lighting",
    Callback=function()
        local h=Hum()
        if h then h.WalkSpeed=16; h.UseJumpPower=true; h.JumpPower=50 end
        workspace.Gravity=196
        Lighting.Brightness=origBright; Lighting.Ambient=origAmb; Lighting.OutdoorAmbient=origOut
        Notify("Reset","All defaults restored.",3)
    end
})

-- ═══════════════════════════════════════════════
--  Auto-load saved config + select Home tab
-- ═══════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════════════
--  FLOATING TOGGLE BUTTON
--  Works by finding the Fluent ScreenGui and toggling .Enabled.
--  No VirtualInputManager needed — 100% executor safe.
--  Draggable, customisable label, size controlled from Settings.
-- ═══════════════════════════════════════════════════════════════

-- Track whether the Fluent UI is currently visible
local _uiVisible     = true
local _toggleBtnGui  = nil
local _toggleBtnSize = "Medium"
local _toggleBtnText = "S"   -- default icon text, user can change

-- Size table: {width, height, textSize, cornerRadius}
local _btnSizes = {
    Small  = { w = 42,  h = 42,  ts = 16, cr = 13 },
    Medium = { w = 56,  h = 56,  ts = 22, cr = 17 },
    Large  = { w = 72,  h = 72,  ts = 28, cr = 22 },
}

-- Find the Fluent ScreenGui by looking through CoreGui / PlayerGui
local function FindFluentGui()
    local function scanParent(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name ~= "SHToggleBtn"
            and not child.Name:find("^SHStat_")
            and not child.Name:find("^SHFlyMob")
            and not child.Name:find("^SHCrosshair") then
                -- Fluent window has at least one Frame child
                for _, sub in pairs(child:GetChildren()) do
                    if sub:IsA("Frame") then return child end
                end
            end
        end
        return nil
    end
    local result
    pcall(function() result = scanParent(game:GetService("CoreGui")) end)
    if not result then
        pcall(function() result = scanParent(plr.PlayerGui) end)
    end
    return result
end

-- Toggle the Fluent window visibility
local function ToggleUI()
    _uiVisible = not _uiVisible
    local fluentGui = FindFluentGui()
    if fluentGui then
        fluentGui.Enabled = _uiVisible
    end
end

-- RightControl listener (mirrors Fluent's built-in MinimizeKey)
game:GetService("UserInputService").InputBegan:Connect(function(inp, gp)
    if not gp and inp.KeyCode == Enum.KeyCode.RightControl then
        ToggleUI()
    end
end)

-- Second minimize key listener (default: RightShift, changeable from Settings)
game:GetService("UserInputService").InputBegan:Connect(function(inp, gp)
    if not gp and inp.KeyCode == _secondMinimizeKey then
        ToggleUI()
    end
end)

-- Destroy existing button if any
local function DestroyToggleButton()
    if _toggleBtnGui then
        pcall(function() _toggleBtnGui:Destroy() end)
        _toggleBtnGui = nil
    end
end

-- Create the floating toggle button
local function CreateToggleButton(sizeName, labelText)
    DestroyToggleButton()
    local sz = _btnSizes[sizeName]
    if not sz then return end   -- "Hidden" → don't create

    labelText = labelText or _toggleBtnText

    -- Safe parent
    local guiParent
    pcall(function() guiParent = game:GetService("CoreGui") end)
    if not guiParent then
        guiParent = plr:WaitForChild("PlayerGui", 10)
    end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "SHToggleBtn"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 850
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = guiParent
    _toggleBtnGui     = sg

    -- Glow ring (behind button)
    local glow = Instance.new("Frame", sg)
    glow.Size                  = UDim2.new(0, sz.w + 12, 0, sz.h + 12)
    glow.Position              = UDim2.new(0, 9, 0.5, -(sz.h + 12)/2)
    glow.BackgroundColor3      = Color3.fromRGB(130, 50, 255)
    glow.BackgroundTransparency = 0.70
    glow.BorderSizePixel       = 0
    glow.ZIndex                = 1
    Instance.new("UICorner", glow).CornerRadius = UDim.new(0, sz.cr + 6)

    -- Pulse glow
    local function PulseGlow()
        if not glow.Parent then return end
        TweenService:Create(glow,
            TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {BackgroundTransparency = 0.48}):Play()
        task.delay(1.3, function()
            if not glow.Parent then return end
            TweenService:Create(glow,
                TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {BackgroundTransparency = 0.72}):Play()
            task.delay(1.3, PulseGlow)
        end)
    end
    PulseGlow()

    -- Main button frame
    local btn = Instance.new("Frame", sg)
    btn.Name                  = "ToggleFrame"
    btn.Size                  = UDim2.new(0, sz.w, 0, sz.h)
    btn.Position              = UDim2.new(0, 15, 0.5, -sz.h/2)
    btn.BackgroundColor3      = Color3.fromRGB(12, 6, 28)
    btn.BorderSizePixel       = 0
    btn.ZIndex                = 2
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, sz.cr)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color     = Color3.fromRGB(130, 50, 255)
    stroke.Thickness = 2.2

    -- Keep glow centred on btn as it is dragged
    btn:GetPropertyChangedSignal("Position"):Connect(function()
        glow.Position = UDim2.new(
            btn.Position.X.Scale, btn.Position.X.Offset - 6,
            btn.Position.Y.Scale, btn.Position.Y.Offset - 6)
    end)

    -- Icon / text label
    local ico = Instance.new("TextLabel", btn)
    ico.Size                   = UDim2.new(1, 0, 1, 0)
    ico.BackgroundTransparency = 1
    ico.Text                   = labelText
    ico.Font                   = Enum.Font.GothamBlack
    ico.TextSize               = sz.ts
    ico.TextColor3             = Color3.fromRGB(160, 90, 255)
    ico.TextXAlignment         = Enum.TextXAlignment.Center
    ico.TextYAlignment         = Enum.TextYAlignment.Center
    ico.BorderSizePixel        = 0
    ico.ZIndex                 = 3

    -- Pulse icon colour
    local function PulseIcon()
        if not ico.Parent then return end
        TweenService:Create(ico,
            TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {TextColor3 = Color3.fromRGB(210, 150, 255)}):Play()
        task.delay(1.4, function()
            if not ico.Parent then return end
            TweenService:Create(ico,
                TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {TextColor3 = Color3.fromRGB(130, 50, 255)}):Play()
            task.delay(1.4, PulseIcon)
        end)
    end
    PulseIcon()

    -- Invisible hit button covering the whole frame
    local hit = Instance.new("TextButton", btn)
    hit.Size                   = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text                   = ""
    hit.AutoButtonColor        = false
    hit.BorderSizePixel        = 0
    hit.ZIndex                 = 4

    -- Hover glow effect (PC)
    hit.MouseEnter:Connect(function()
        TweenService:Create(stroke,
            TweenInfo.new(0.12), {Color = Color3.fromRGB(210,150,255), Thickness = 3}):Play()
        TweenService:Create(btn,
            TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(22,11,50)}):Play()
    end)
    hit.MouseLeave:Connect(function()
        TweenService:Create(stroke,
            TweenInfo.new(0.12), {Color = Color3.fromRGB(130,50,255), Thickness = 2.2}):Play()
        TweenService:Create(btn,
            TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(12,6,28)}):Play()
    end)

    -- Drag + click detection
    local dragging    = false
    local dragMoved   = false
    local dragStart   = Vector2.zero
    local btnStartPos = Vector2.zero

    hit.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging    = true
            dragMoved   = false
            dragStart   = Vector2.new(inp.Position.X, inp.Position.Y)
            btnStartPos = Vector2.new(btn.Position.X.Offset, btn.Position.Y.Offset)
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            local d = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
            if d.Magnitude > 8 then dragMoved = true end
            if dragMoved then
                btn.Position = UDim2.new(
                    btn.Position.X.Scale, btnStartPos.X + d.X,
                    btn.Position.Y.Scale, btnStartPos.Y + d.Y)
            end
        end
    end)

    hit.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if not dragMoved then
                -- Pure tap/click → toggle the UI
                ToggleUI()
                -- Animate button press feedback
                TweenService:Create(btn,
                    TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(40,18,80)}):Play()
                task.delay(0.12, function()
                    if btn.Parent then
                        TweenService:Create(btn,
                            TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(12,6,28)}):Play()
                    end
                end)
            end
        end
    end)
end

-- Auto-create at script load
CreateToggleButton(_toggleBtnSize, _toggleBtnText)

-- ── Settings controls for the toggle button ──────────────────
Settings:AddDropdown("ToggleBtnSize", {
    Title       = "Toggle Button Size",
    Description = "Resize or hide the floating toggle button",
    Values      = { "Small", "Medium", "Large", "Hidden" },
    Default     = "Medium",
    Callback    = function(v)
        _toggleBtnSize = v
        if v == "Hidden" then
            DestroyToggleButton()
            Notify("Toggle Button", "Hidden. Use RightControl to toggle.", 4)
        else
            CreateToggleButton(v, _toggleBtnText)
            Notify("Toggle Button", "Size → " .. v, 2)
        end
    end,
})

Settings:AddInput("ToggleBtnLabel", {
    Title       = "Toggle Button Text",
    Description = "Custom text/icon shown on the button (press Enter to apply)",
    Default     = "^",
    Placeholder = "Type any text or symbol",
    Numeric     = false,
    Finished    = true,
    Callback    = function(v)
        if v == nil or v == "" then v = "^" end
        _toggleBtnText = v
        -- Refresh button with new label
        if _toggleBtnSize ~= "Hidden" then
            CreateToggleButton(_toggleBtnSize, _toggleBtnText)
        end
        Notify("Toggle Button", "Label set to: " .. v, 2)
    end,
})

-- Second minimize key selector
Settings:AddKeybind("SecondMinimizeKey", {
    Title       = "Second Minimize Key",
    Description = "An extra hotkey to show/hide the UI (in addition to RightControl)",
    Mode        = "Hold",
    Default     = "RightShift",
    Callback    = function()
        -- Called when key is pressed in keybind mode
    end,
    ChangedCallback = function(new)
        pcall(function()
            _secondMinimizeKey = Enum.KeyCode[new]
            Notify("Minimize Key", "Second key set to " .. new, 3)
        end)
    end,
})

Settings:AddButton({ Title = "Show Toggle Button",
    Description = "Re-add the button if it was hidden",
    Callback = function()
        if _toggleBtnSize == "Hidden" then _toggleBtnSize = "Medium" end
        CreateToggleButton(_toggleBtnSize, _toggleBtnText)
        Notify("Toggle Button", "Restored.", 2)
    end
})

Settings:AddButton({ Title = "Hide Toggle Button",
    Description = "Remove the floating button from screen",
    Callback = function()
        DestroyToggleButton()
        Notify("Toggle Button", "Hidden. Use RightControl or restore from Settings.", 4)
    end
})

SaveManager:LoadAutoloadConfig()
Window:SelectTab(1)

Fluent:Notify({
    Title    = "Shadow Hub",
    Content  = "Loaded!  Welcome, " .. plr.Name .. "   |   v2.1.0",
    Duration = 5,
})

print("[Shadow Hub] v2.1.0 ready.")
