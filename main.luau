local libSource = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local InterfaceLib = loadstring(game:HttpGet(libSource .. 'Library.lua'))()
local ThemeController = loadstring(game:HttpGet(libSource .. 'addons/ThemeManager.lua'))()
local ConfigManager = loadstring(game:HttpGet(libSource .. 'addons/SaveManager.lua'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Events = {
    Melee1 = ReplicatedStorage.Events["XMHH.2"],
    Melee2 = ReplicatedStorage.Events["XMHH2.2"],
    Visualize = ReplicatedStorage.Events2.Visualize,
    Damage = ReplicatedStorage.Events["ZFKLF__H"],
    Ragdoll = ReplicatedStorage.Events["__RZDONL"],
    GNX_S = ReplicatedStorage.Events.GNX_S,
    GNX_R = ReplicatedStorage.Events["GNX_R"]
}

local Config = {
    SilentAim = { Enabled = false, TargetPart = "Head", TeamCheck = false },
    MeleeAura = { Enabled = false, Range = 12, TargetPart = "Head", TeamCheck = false, Prediction = true, PredictionMultiplier = 0.12 },
    AimLock = { Enabled = false, Smoothness = 0.1, TargetPart = "Head", TeamCheck = false, VelocityPrediction = false, AimKey = Enum.UserInputType.MouseButton2 },
    Visuals = {
        Enabled = false,
        Boxes = false,
        Names = false,
        Health = false,
        Tools = false,
        Tracers = false,
        TeamCheck = false,
        BoxColor = Color3.new(1, 1, 1),
        FovValue = 70,
        MaxESPDistance = 1000
    },
    Movement = {
        SpeedEnabled = false,
        SpeedValue = 16,
        SpeedKey = nil,
        FlyEnabled = false,
        FlySpeed = 50,
        RagdollInterval = 0.05,
        InfiniteStamina = false,
        FinishSpeedEnabled = false,
        FinishSpeedValue = 1,
        SpinBotEnabled = false,
        SpinBotSpeed = 100
    },
    Launchers = { Enabled = false, Speed = 200, TurnSensitivity = 1 },
    Misc = { WallbangEnabled = false, InstantReload = false, GravityValue = 196 },
    RageBot = { Enabled = false, TeamCheck = false, TargetPart = "Head", Cooldown = 0.05, PredictionMultiplier = 0.135 }
}

local ValidParts = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Random" }
local ValidMeleeTargetParts = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local AttachCD = {
    Fists = 0.05,
    Knuckledusters = 0.05,
    Nunchucks = 0.05,
    Shiv = 0.05,
    Bat = 1,
    ["Metal-Bat"] = 1,
    Chainsaw = 2.5,
    Balisong = 0.05,
    Rambo = 0.3,
    Shovel = 3,
    Sledgehammer = 2,
    Katana = 0.1,
    Wrench = 0.1
}

local RuntimeData = {
    Aiming = { IsActive = false, CurrentTarget = nil, TargetLocked = false },
    ESP = { Renderings = {}, Connections = {} },
    PlayerTracking = { Connections = {}, Stats = {} },
    Melee = { AttackCooldown = 0, Task = nil },
    Launchers = { Forward = 0, Sideways = 0, StopControl = false, CurrentVelocity = Vector3.new(), LastFireTime = 0, ExpectedProjectile = nil, Connections = {} },
    Movement = { LastRagdollTime = 0, SpinBotAngle = 0 },
    SilentAim = { Target = nil, Task = nil, Connections = {} },
    RageBot = { Task = nil, LastShotTime = 0, CurrentTarget = nil, Connections = {} },
    InstantReload = { Connections = {}, LastReloadTime = 0, ReloadCooldown = 0.05, CharacterConnection = nil, ToolConnection = nil },
    InfiniteStamina = { Connections = {}, Enabled = false }
}

local ProjectileTypes = {
    RPG_Rocket = { "RPG-7", "RPG-29" },
    GrenadeLauncherGrenade = { "M320-1", "SCAR-H-X" },
    SBL_Rocket = { "SBL-MK3" },
    Hallows_Rocket3 = { "HL-MK3" },
    Hallows_Rocket2 = { "HL-MK2" },
    FireworkLauncher_Rocket = { "FireworkLauncher" },
    Hallows_Rocket = { "HallowsLauncher" },
    AT4_Rocket = { "AT4" },
    Rpg18 = { "RPG-18" }
}

local FinishSpeedMulti = ReplicatedStorage.Values.FinishSpeedMulti

local function RandomString(length)
    local chars = {}
    for i = 1, length do
        chars[i] = string.char(math.random(97, 122))
    end
    return table.concat(chars)
end

local function PreloadWeapons()
    local validWeapons = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    for weaponName, cooldown in pairs(AttachCD) do
        local found = ReplicatedStorage:FindFirstChild(weaponName) or (backpack and backpack:FindFirstChild(weaponName))
        if not found then
            for _, folder in ipairs(ReplicatedStorage:GetDescendants()) do
                if folder:IsA("Tool") and folder.Name == weaponName then
                    found = true
                    break
                end
            end
        end
        if found then
            validWeapons[weaponName] = cooldown
        end
    end
    AttachCD = validWeapons
end

local function GetTargetPart(target)
    if Config.MeleeAura.TargetPart == "Random" then
        return target:FindFirstChild(ValidMeleeTargetParts[math.random(1, #ValidMeleeTargetParts)])
    else
        return target:FindFirstChild(Config.MeleeAura.TargetPart) or target:FindFirstChild("Head")
    end
end

local function IsValidMeleeTarget(enemy)
    if not enemy.Character or enemy == LocalPlayer or not enemy.Character.Parent then return false end
    local humanoid = enemy.Character:FindFirstChildOfClass("Humanoid")
    local root = enemy.Character:FindFirstChild("HumanoidRootPart")
    local head = enemy.Character:FindFirstChild("Head")
    if not humanoid or not root or not head or humanoid.Health <= 15 or enemy.Character:FindFirstChildOfClass("ForceField") then return false end
    if Config.MeleeAura.TeamCheck and enemy.Team == LocalPlayer.Team then return false end
    return humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

local function IsTargetValid(player, configSection)
    if not player or not player.Character or not player.Character.Parent then return false end
    if configSection.TeamCheck and player.Team == LocalPlayer.Team then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local part = player.Character:FindFirstChild(configSection.TargetPart)
    return humanoid and humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Dead and part ~= nil
end

local function FindClosestMeleeTarget()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local myRoot = char.HumanoidRootPart
    local closestEnemy, minDistance = nil, Config.MeleeAura.Range
    for _, enemy in ipairs(Players:GetPlayers()) do
        if IsValidMeleeTarget(enemy) then
            local distance = (myRoot.Position - enemy.Character.HumanoidRootPart.Position).Magnitude
            if distance <= minDistance then
                minDistance = distance
                closestEnemy = enemy
            end
        end
    end
    return closestEnemy
end

local function FindClosestRageBotEnemy()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local camPos = Camera.CFrame.Position
    local mousePos = UserInputService:GetMouseLocation()
    local ray = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
    local rayDir = ray.Direction * 1000
    local closestEnemy, minDistance = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsTargetValid(player, Config.RageBot) then
            local targetChar = player.Character
            local part = targetChar:FindFirstChild(Config.RageBot.TargetPart)
            if part and (part.Position - camPos).Magnitude <= Config.Visuals.MaxESPDistance then
                local predictedPos = part.Position
                local root = targetChar:FindFirstChild("HumanoidRootPart")
                if root and root.Velocity then
                    predictedPos += root.Velocity * Config.RageBot.PredictionMultiplier
                end
                local projection = (predictedPos - camPos):Dot(rayDir.Unit)
                local pointOnRay = camPos + rayDir.Unit * projection
                local distance = (predictedPos - pointOnRay).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestEnemy = player
                end
            end
        end
    end
    return closestEnemy
end

local function SmoothCameraLock()
    if not Config.AimLock.Enabled or not RuntimeData.Aiming.IsActive or not RuntimeData.Aiming.CurrentTarget or not RuntimeData.Aiming.CurrentTarget.Character then
        RuntimeData.Aiming.CurrentTarget = nil
        RuntimeData.Aiming.TargetLocked = false
        return
    end
    local humanoid = RuntimeData.Aiming.CurrentTarget.Character:FindFirstChildOfClass("Humanoid")
    local part = RuntimeData.Aiming.CurrentTarget.Character:FindFirstChild(Config.AimLock.TargetPart)
    if not humanoid or humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead or not part then
        RuntimeData.Aiming.CurrentTarget = nil
        RuntimeData.Aiming.TargetLocked = false
        return
    end
    local targetPos = part.Position
    if Config.AimLock.VelocityPrediction then
        local root = RuntimeData.Aiming.CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
        if root and root.Velocity then
            targetPos += root.Velocity * 0.1
        end
    end
    local camCFrame = Camera.CFrame
    local smooth = math.clamp(Config.AimLock.Smoothness, 0.1, 1)
    Camera.CFrame = CFrame.new(camCFrame.Position, camCFrame.Position + camCFrame.LookVector:Lerp((targetPos - camCFrame.Position).Unit, smooth))
end

local function Attack(target)
    if not target or not target:FindFirstChild("Head") then return end
    if not LocalPlayer.Character then return end
    local TOOL = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not TOOL then return end
    local attachcd = AttachCD[TOOL.Name] or 0.5
    if tick() - RuntimeData.Melee.AttackCooldown >= attachcd then
        local result = Events.Melee1:InvokeServer("🍞", tick(), TOOL, "43TRFWX", "Normal", tick(), true)
        task.wait(0.3)
        local Handle = TOOL:FindFirstChild("WeaponHandle") or TOOL:FindFirstChild("Handle") or LocalPlayer.Character:FindFirstChild("Left Arm")
        if TOOL then
            local targetPart = GetTargetPart(target)
            if not targetPart then return end
            local predictedPos = targetPart.Position
            local enemyRoot = target:FindFirstChild("HumanoidRootPart")
            if Config.MeleeAura.Prediction and enemyRoot and enemyRoot.Velocity then
                predictedPos = targetPart.Position + enemyRoot.Velocity * Config.MeleeAura.PredictionMultiplier
            end
            local arg2 = {
                "🍞",
                tick(),
                TOOL,
                "2389ZFX34",
                result,
                true,
                Handle,
                targetPart,
                target,
                LocalPlayer.Character.HumanoidRootPart.Position,
                predictedPos
            }
            if TOOL.Name == "Chainsaw" then
                for i = 1, 15 do
                    Events.Melee2:FireServer(unpack(arg2))
                end
            else
                Events.Melee2:FireServer(unpack(arg2))
            end
            RuntimeData.Melee.AttackCooldown = tick()
        end
    end
end

local function RunMeleeAura()
    if RuntimeData.Melee.Task then
        task.cancel(RuntimeData.Melee.Task)
        RuntimeData.Melee.Task = nil
    end
    if not Config.MeleeAura.Enabled then return end
    RuntimeData.Melee.AttackCooldown = tick()
    RuntimeData.Melee.Task = task.spawn(function()
        while Config.MeleeAura.Enabled do
            local mychar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            if mychar and mychar:FindFirstChild("HumanoidRootPart") then
                local myhrp = mychar.HumanoidRootPart
                for _, a in ipairs(Players:GetPlayers()) do
                    if a ~= LocalPlayer and a.Character and a.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = a.Character.HumanoidRootPart
                        local distance = (myhrp.Position - hrp.Position).Magnitude
                        local humanoid = a.Character:FindFirstChildOfClass("Humanoid")
                        if distance < Config.MeleeAura.Range and humanoid and humanoid.Health > 15 and humanoid:GetState() ~= Enum.HumanoidStateType.Dead and not a.Character:FindFirstChildOfClass("ForceField") then
                            if Config.MeleeAura.TeamCheck and a.Team == LocalPlayer.Team then continue end
                            Attack(a.Character)
                        end
                    end
                end
            end
            task.wait(0.01) -- Reduced frequency to improve performance
        end
    end)
end

local function FindSilentAimTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    local camPos = Camera.CFrame.Position
    local mousePos = UserInputService:GetMouseLocation()
    local ray = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
    local rayDir = ray.Direction * 1000
    local closestEnemy, minDistance = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not player.Character:FindFirstChildOfClass("ForceField") then
            if Config.SilentAim.TeamCheck and player.Team == LocalPlayer.Team then continue end
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local part = player.Character:FindFirstChild(Config.SilentAim.TargetPart)
            if humanoid and humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Dead and part then
                local distanceFromCamera = (part.Position - camPos).Magnitude
                if distanceFromCamera <= Config.Visuals.MaxESPDistance then
                    local projection = (part.Position - camPos):Dot(rayDir.Unit)
                    local pointOnRay = camPos + rayDir.Unit * projection
                    local distance = (part.Position - pointOnRay).Magnitude
                    if distance < minDistance then
                        minDistance = distance
                        closestEnemy = player
                    end
                end
            end
        end
    end
    return closestEnemy
end

local function SetupSilentAim()
    if RuntimeData.SilentAim.Task then
        task.cancel(RuntimeData.SilentAim.Task)
        RuntimeData.SilentAim.Task = nil
    end
    for _, conn in pairs(RuntimeData.SilentAim.Connections) do
        if conn then conn:Disconnect() end
    end
    RuntimeData.SilentAim.Connections = {}
    if not Config.SilentAim.Enabled then
        RuntimeData.SilentAim.Target = nil
        return
    end
    RuntimeData.SilentAim.Task = task.spawn(function()
        while Config.SilentAim.Enabled do
            RuntimeData.SilentAim.Target = FindSilentAimTarget()
            task.wait(0.01) -- Optimized frequency
        end
    end)
    local visualizeConn = Events.Visualize.Event:Connect(function(_, shotCode, _, weapon, _, startPos, bulletCount)
        if not Config.SilentAim.Enabled or not weapon or not RuntimeData.SilentAim.Target or not RuntimeData.SilentAim.Target.Character then return end
        local playerWeapon = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if not playerWeapon or weapon ~= playerWeapon or RuntimeData.SilentAim.Target.Character:FindFirstChildOfClass("ForceField") then return end
        local hitPart = RuntimeData.SilentAim.Target.Character:FindFirstChild(Config.SilentAim.TargetPart)
        if not hitPart then return end
        local hitPos = hitPart.Position
        local bullets = {}
        local numBullets = bulletCount and #bulletCount or 1
        for i = 1, math.clamp(numBullets, 1, 100) do
            if startPos and hitPos then
                bullets[i] = CFrame.new(startPos, hitPos).LookVector
            end
        end
        task.wait(0.005)
        for index, lookVector in ipairs(bullets) do
            Events.Damage:FireServer("🧈", weapon, shotCode, index, hitPart, hitPos, lookVector)
        end
        if weapon:FindFirstChild("Hitmarker") then
            weapon.Hitmarker:Fire(hitPart)
        end
    end)
    table.insert(RuntimeData.SilentAim.Connections, visualizeConn)
end

local function IsRageBotTargetValid(player)
    if not player or not player.Character or not player.Character.Parent then return false end
    if Config.RageBot.TeamCheck and player.Team == LocalPlayer.Team then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local part = player.Character:FindFirstChild(Config.RageBot.TargetPart)
    return humanoid and humanoid.Health > 9 and humanoid:GetState() ~= Enum.HumanoidStateType.Dead and part ~= nil
end

local function ShootRageBot(target)
    if not target or not target.Character then return end
    local part = target.Character:FindFirstChild(Config.RageBot.TargetPart)
    if not part then return end
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not tool or not tool:FindFirstChild("Values") or not tool:FindFirstChild("Hitmarker") then return end
    local values = tool:FindFirstChild("Values")
    local ammo = values and values:FindFirstChild("SERVER_Ammo")
    local storedAmmo = values and values:FindFirstChild("SERVER_StoredAmmo")
    local maxAmmo = values and values:FindFirstChild("MaxAmmo") or { Value = 30 }
    if not ammo or not storedAmmo then return end
    if ammo.Value <= 0 or ammo.Value < maxAmmo.Value then
        if Config.Misc.InstantReload and storedAmmo.Value > 0 and tick() - RuntimeData.InstantReload.LastReloadTime >= RuntimeData.InstantReload.ReloadCooldown then
            Events.GNX_R:FireServer(tick(), "KLWE89U0", tool)
            RuntimeData.InstantReload.LastReloadTime = tick()
            task.wait(0.05)
        end
    end
    if ammo.Value <= 0 then return end
    local hitPosition = part.Position
    local root = target.Character:FindFirstChild("HumanoidRootPart")
    if root and root.Velocity then
        hitPosition += root.Velocity * Config.RageBot.PredictionMultiplier
    end
    local hitDirection = (hitPosition - Camera.CFrame.Position).Unit
    local randomKey = RandomString(30) .. "0"
    Events.GNX_S:FireServer(tick(), randomKey, tool, "FDS9I83", Camera.CFrame.Position, { hitDirection }, false)
    Events.Damage:FireServer("🧈", tool, randomKey, 1, part, hitPosition, hitDirection)
    ammo.Value = math.max(ammo.Value - 1, 0)
    tool.Hitmarker:Fire(part)
end

local function RunRageBot()
    if RuntimeData.RageBot.Task then
        task.cancel(RuntimeData.RageBot.Task)
        RuntimeData.RageBot.Task = nil
    end
    for _, conn in pairs(RuntimeData.RageBot.Connections) do
        if conn then conn:Disconnect() end
    end
    RuntimeData.RageBot.Connections = {}
    if not Config.RageBot.Enabled then
        RuntimeData.RageBot.CurrentTarget = nil
        return
    end
    RuntimeData.RageBot.Task = task.spawn(function()
        while Config.RageBot.Enabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") do
            local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("Values") then
                Events.GNX_S:FireServer(tick(), RandomString(30) .. "0", tool, "FDS9I83", Camera.CFrame.Position, { Vector3.new(0, 0, 1) }, false)
            end
            local target = RuntimeData.RageBot.CurrentTarget
            if target and target.Character then
                local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
                if not humanoid or humanoid.Health <= 9 or not IsRageBotTargetValid(target) then
                    RuntimeData.RageBot.CurrentTarget = nil
                    target = nil
                end
            end
            if not target then
                target = FindClosestRageBotEnemy()
                RuntimeData.RageBot.CurrentTarget = target
            end
            if target and tick() - RuntimeData.RageBot.LastShotTime >= Config.RageBot.Cooldown then
                ShootRageBot(target)
                RuntimeData.RageBot.LastShotTime = tick()
            end
            task.wait(0.01)
        end
        RuntimeData.RageBot.CurrentTarget = nil
    end)
end

local function CreateESPVisuals()
    local visuals = {}
    visuals.box = Drawing.new("Square")
    visuals.box.Filled = false
    visuals.box.Thickness = 1
    visuals.box.Transparency = 1
    visuals.box.Color = Config.Visuals.BoxColor

    visuals.name = Drawing.new("Text")
    visuals.name.Size = 13
    visuals.name.Center = true
    visuals.name.Outline = true
    visuals.name.Transparency = 1
    visuals.name.Color = Color3.new(1, 1, 1)

    visuals.tool = Drawing.new("Text")
    visuals.tool.Size = 13
    visuals.tool.Center = true
    visuals.tool.Outline = true
    visuals.tool.Transparency = 1
    visuals.tool.Color = Color3.new(1, 1, 1)

    visuals.healthBarBg = Drawing.new("Square")
    visuals.healthBarBg.Filled = true
    visuals.healthBarBg.Thickness = 1
    visuals.healthBarBg.Transparency = 0.5
    visuals.healthBarBg.Color = Color3.new(0, 0, 0)

    visuals.healthBarFg = Drawing.new("Square")
    visuals.healthBarFg.Filled = true
    visuals.healthBarFg.Thickness = 1
    visuals.healthBarFg.Transparency = 1

    visuals.tracer = Drawing.new("Line")
    visuals.tracer.Thickness = 1
    visuals.tracer.Transparency = 1
    visuals.tracer.Color = Color3.new(1, 1, 1)

    return visuals
end

local function DestroyESPVisuals(visuals)
    if visuals then
        for _, visual in pairs(visuals) do
            if visual.Remove then visual:Remove() end
        end
    end
end

local function HideESPVisuals(visuals)
    if visuals then
        for _, visual in pairs(visuals) do
            visual.Visible = false
        end
    end
end

local function GetHealthColor(healthPct)
    return Color3.new(1 - healthPct, healthPct, 0)
end

local function UpdatePlayerESP(player)
    if not player or player == LocalPlayer then return end
    local visuals = RuntimeData.ESP.Renderings[player]
    if not Config.Visuals.Enabled then
        if visuals then
            DestroyESPVisuals(visuals)
            RuntimeData.ESP.Renderings[player] = nil
        end
        return
    end
    if not visuals then
        visuals = CreateESPVisuals()
        RuntimeData.ESP.Renderings[player] = visuals
    end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Head") or
       (Config.Visuals.TeamCheck and player.Team == LocalPlayer.Team) then
        HideESPVisuals(visuals)
        return
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
        HideESPVisuals(visuals)
        return
    end
    local root = char.HumanoidRootPart
    local distance = (root.Position - Camera.CFrame.Position).Magnitude
    if distance > Config.Visuals.MaxESPDistance then
        HideESPVisuals(visuals)
        return
    end
    local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
    if not onScreen then
        HideESPVisuals(visuals)
        return
    end
    local headPos = Camera:WorldToViewportPoint(char.Head.Position + Vector3.new(0, 0.5, 0))
    local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
    local topY = math.min(headPos.Y, legPos.Y)
    local bottomY = math.max(headPos.Y, legPos.Y)
    local height = bottomY - topY
    local width = height / 2
    local posX = (headPos.X + legPos.X) / 2 - width / 2
    local posY = topY
    local boxPos = Vector2.new(math.floor(posX), math.floor(posY))
    local boxSize = Vector2.new(math.floor(width), math.floor(height))

    if Config.Visuals.Boxes then
        visuals.box.Visible = true
        visuals.box.Position = boxPos
        visuals.box.Size = boxSize
    else
        visuals.box.Visible = false
    end

    if Config.Visuals.Names then
        visuals.name.Visible = true
        visuals.name.Position = boxPos + Vector2.new(boxSize.X / 2, -visuals.name.TextBounds.Y - 2)
        visuals.name.Text = player.Name .. " [" .. math.floor(distance) .. "m]"
    else
        visuals.name.Visible = false
    end

    if Config.Visuals.Tools then
        local equippedTool = char:FindFirstChildOfClass("Tool")
        if equippedTool then
            visuals.tool.Visible = true
            visuals.tool.Position = boxPos + Vector2.new(boxSize.X / 2, boxSize.Y + 2)
            visuals.tool.Text = equippedTool.Name
        else
            visuals.tool.Visible = false
        end
    else
        visuals.tool.Visible = false
    end

    if Config.Visuals.Health then
        local healthPct = humanoid.Health / humanoid.MaxHealth
        local healthHeight = boxSize.Y * healthPct
        visuals.healthBarBg.Visible = true
        visuals.healthBarBg.Position = boxPos + Vector2.new(-5, 0)
        visuals.healthBarBg.Size = Vector2.new(3, boxSize.Y)

        visuals.healthBarFg.Visible = true
        visuals.healthBarFg.Position = boxPos + Vector2.new(-5, boxSize.Y - healthHeight)
        visuals.healthBarFg.Size = Vector2.new(3, healthHeight)
        visuals.healthBarFg.Color = GetHealthColor(healthPct)
    else
        visuals.healthBarBg.Visible = false
        visuals.healthBarFg.Visible = false
    end

    if Config.Visuals.Tracers then
        visuals.tracer.Visible = true
        visuals.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        visuals.tracer.To = boxPos + Vector2.new(boxSize.X / 2, boxSize.Y)
    else
        visuals.tracer.Visible = false
    end
end

local function SetupPlayerTracking(player)
    if player == LocalPlayer then return end
    if RuntimeData.PlayerTracking.Connections[player] then
        for _, conn in pairs(RuntimeData.PlayerTracking.Connections[player]) do
            if conn then conn:Disconnect() end
        end
    end
    RuntimeData.PlayerTracking.Connections[player] = {}
    RuntimeData.PlayerTracking.Stats[player] = {
        Character = player.Character,
        Humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid"),
        Health = player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character:FindFirstChildOfClass("Humanoid").Health or 0,
        Team = player.Team
    }
    local function handleCharacterSpawn(char)
        RuntimeData.PlayerTracking.Stats[player].Character = char
        RuntimeData.PlayerTracking.Stats[player].Humanoid = char:WaitForChild("Humanoid", 5)
        RuntimeData.PlayerTracking.Stats[player].Health = RuntimeData.PlayerTracking.Stats[player].Humanoid and RuntimeData.PlayerTracking.Stats[player].Humanoid.Health or 0
        UpdatePlayerESP(player)
        if RuntimeData.PlayerTracking.Stats[player].Humanoid then
            local healthConn = RuntimeData.PlayerTracking.Stats[player].Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                RuntimeData.PlayerTracking.Stats[player].Health = RuntimeData.PlayerTracking.Stats[player].Humanoid.Health
                UpdatePlayerESP(player)
                if RuntimeData.Aiming.CurrentTarget == player and RuntimeData.PlayerTracking.Stats[player].Health <= 0 then
                    RuntimeData.Aiming.CurrentTarget = nil
                    RuntimeData.Aiming.TargetLocked = false
                end
                if RuntimeData.RageBot.CurrentTarget == player and RuntimeData.PlayerTracking.Stats[player].Health <= 9 then
                    RuntimeData.RageBot.CurrentTarget = nil
                end
                if RuntimeData.SilentAim.Target == player and RuntimeData.PlayerTracking.Stats[player].Health <= 0 then
                    RuntimeData.SilentAim.Target = nil
                end
            end)
            table.insert(RuntimeData.PlayerTracking.Connections[player], healthConn)
            local diedConn = RuntimeData.PlayerTracking.Stats[player].Humanoid.Died:Connect(function()
                RuntimeData.PlayerTracking.Stats[player].Health = 0
                UpdatePlayerESP(player)
                if RuntimeData.Aiming.CurrentTarget == player then
                    RuntimeData.Aiming.CurrentTarget = nil
                    RuntimeData.Aiming.TargetLocked = false
                end
                if RuntimeData.RageBot.CurrentTarget == player then
                    RuntimeData.RageBot.CurrentTarget = nil
                end
                if RuntimeData.SilentAim.Target == player then
                    RuntimeData.SilentAim.Target = nil
                end
            end)
            table.insert(RuntimeData.PlayerTracking.Connections[player], diedConn)
        end
    end
    if player.Character then
        handleCharacterSpawn(player.Character)
    end
    table.insert(RuntimeData.PlayerTracking.Connections[player], player.CharacterAdded:Connect(handleCharacterSpawn))
    table.insert(RuntimeData.PlayerTracking.Connections[player], player:GetPropertyChangedSignal("Team"):Connect(function()
        RuntimeData.PlayerTracking.Stats[player].Team = player.Team
        UpdatePlayerESP(player)
    end))
end

local function HandlePlayerLeave(player)
    if RuntimeData.ESP.Renderings[player] then
        DestroyESPVisuals(RuntimeData.ESP.Renderings[player])
        RuntimeData.ESP.Renderings[player] = nil
    end
    if RuntimeData.PlayerTracking.Connections[player] then
        for _, conn in pairs(RuntimeData.PlayerTracking.Connections[player]) do
            if conn then conn:Disconnect() end
        end
        RuntimeData.PlayerTracking.Connections[player] = nil
    end
    RuntimeData.PlayerTracking.Stats[player] = nil
    if RuntimeData.Aiming.CurrentTarget == player then
        RuntimeData.Aiming.CurrentTarget = nil
        RuntimeData.Aiming.TargetLocked = false
    end
    if RuntimeData.RageBot.CurrentTarget == player then
        RuntimeData.RageBot.CurrentTarget = nil
    end
    if RuntimeData.SilentAim.Target == player then
        RuntimeData.SilentAim.Target = nil
    end
end

local function UpdateMovementSpeed()
    if not Config.Movement.SpeedEnabled or not LocalPlayer.Character then return end
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if humanoid and rootPart and humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            rootPart.Velocity = Vector3.new(moveDir.X * Config.Movement.SpeedValue, rootPart.Velocity.Y, moveDir.Z * Config.Movement.SpeedValue)
        end
    end
end

local function UpdateFOV()
    if Camera then
        Camera.FieldOfView = Config.Visuals.FovValue
    end
end

local function IsLauncherWeapon(weaponName)
    for _, weapons in pairs(ProjectileTypes) do
        for _, w in ipairs(weapons) do
            if w == weaponName then
                return true
            end
        end
    end
    return false
end

local function GetProjectileTypeForWeapon(weaponName)
    for projType, weapons in pairs(ProjectileTypes) do
        for _, w in ipairs(weapons) do
            if w == weaponName then
                return projType
            end
        end
    end
    return nil
end

local function CheckWeaponEquipped(weapons)
    local char = LocalPlayer.Character
    if not char then return false end
    for _, weapon in ipairs(weapons) do
        if char:FindFirstChild(weapon) or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild(weapon)) then
            return true
        end
    end
    return false
end

local function SetupLauncherControl()
    for _, conn in pairs(RuntimeData.Launchers.Connections) do
        if conn then conn:Disconnect() end
    end
    RuntimeData.Launchers.Connections = {}
    RuntimeData.Launchers.LastFireTime = 0
    RuntimeData.Launchers.ExpectedProjectile = nil
    if not Config.Launchers.Enabled then return end

    local function setupTool(tool)
        if not tool or not IsLauncherWeapon(tool.Name) then return end
        local conn = tool.Activated:Connect(function()
            local ammo = tool:FindFirstChild("Values") and tool.Values:FindFirstChild("SERVER_Ammo")
            if ammo and ammo.Value > 0 then
                RuntimeData.Launchers.LastFireTime = tick()
                RuntimeData.Launchers.ExpectedProjectile = GetProjectileTypeForWeapon(tool.Name)
            end
        end)
        table.insert(RuntimeData.Launchers.Connections, conn)
    end

    local function setupCharacter(char)
        if not char then return end
        local equippedTool = char:FindFirstChildOfClass("Tool")
        if equippedTool and IsLauncherWeapon(equippedTool.Name) then
            setupTool(equippedTool)
        end
        local toolAddedConn = char.ChildAdded:Connect(function(obj)
            if obj:IsA("Tool") and IsLauncherWeapon(obj.Name) then
                setupTool(obj)
            end
        end)
        table.insert(RuntimeData.Launchers.Connections, toolAddedConn)
    end

    if LocalPlayer.Character then
        setupCharacter(LocalPlayer.Character)
    end
    local charAddedConn = LocalPlayer.CharacterAdded:Connect(setupCharacter)
    table.insert(RuntimeData.Launchers.Connections, charAddedConn)
end

local function ControlRocket(projectile)
    local char = LocalPlayer.Character
    if not Config.Launchers.Enabled or not char or not char:FindFirstChild("Humanoid") or not char:FindFirstChild("HumanoidRootPart") or not projectile or not projectile.Parent then return end
    task.wait(0.1)
    if not projectile or not projectile.Parent then
        if Camera.CameraSubject ~= char.Humanoid then
            Camera.CameraSubject = char.Humanoid
        end
        if char.HumanoidRootPart.Anchored then
            char.HumanoidRootPart.Anchored = false
        end
        return
    end
    if Camera.CameraSubject ~= char.Humanoid then return end
    Camera.CameraSubject = projectile
    char.HumanoidRootPart.Anchored = true
    for _, component in ipairs({ "BodyForce", "BodyAngularVelocity", "BodyVelocity", "Sound" }) do
        local instance = projectile:FindFirstChild(component)
        if instance then instance:Destroy() end
    end
    if projectile:FindFirstChild("RotPart") then
        local rotPart = projectile.RotPart
        for _, component in ipairs({ "BodyAngularVelocity", "BodyVelocity" }) do
            local instance = rotPart:FindFirstChild(component)
            if instance then instance:Destroy() end
        end
    end
    local velocity = Instance.new("BodyVelocity")
    velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    velocity.Velocity = Vector3.new(0, 0, 0)
    velocity.Parent = projectile
    local gyro = Instance.new("BodyGyro")
    gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    gyro.P = 10000 * Config.Launchers.TurnSensitivity
    gyro.D = 500
    gyro.Parent = projectile
    local lastParent = projectile.Parent
    RuntimeData.Launchers.CurrentVelocity = Vector3.new()
    while Config.Launchers.Enabled and projectile and projectile.Parent and char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") do
        RunService.RenderStepped:Wait()
        if not projectile or not projectile.Parent then break end
        local forwardInput = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
        local sidewaysInput = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
        RuntimeData.Launchers.Forward = forwardInput
        RuntimeData.Launchers.Sideways = sidewaysInput
        local targetVelocity = (Camera.CFrame.LookVector * forwardInput + Camera.CFrame.RightVector * sidewaysInput) * Config.Launchers.Speed
        RuntimeData.Launchers.CurrentVelocity = RuntimeData.Launchers.CurrentVelocity:Lerp(targetVelocity, 0.1)
        velocity.Velocity = RuntimeData.Launchers.CurrentVelocity
        gyro.CFrame = Camera.CFrame
        local targetCFrame = projectile.CFrame * CFrame.new(0, 2, 5)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 0.2)
        if RuntimeData.Launchers.StopControl or lastParent ~= projectile.Parent or not projectile.Parent then
            RuntimeData.Launchers.Forward = 0
            RuntimeData.Launchers.Sideways = 0
            RuntimeData.Launchers.StopControl = false
            break
        end
        lastParent = projectile.Parent
    end
    if velocity then velocity:Destroy() end
    if gyro then gyro:Destroy() end
    RuntimeData.Launchers.CurrentVelocity = Vector3.new(0, 0, 0)
    if char and char:FindFirstChild("Humanoid") then
        Camera.CameraSubject = char.Humanoid
        if char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.Anchored = false
        end
    end
    RuntimeData.Launchers.ExpectedProjectile = nil
end

local function SetupInfiniteStamina()
    for _, conn in pairs(RuntimeData.InfiniteStamina.Connections) do
        if conn then conn:Disconnect() end
    end
    RuntimeData.InfiniteStamina.Connections = {}
    if not Config.Movement.InfiniteStamina then
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:SetAttribute("ZSPRN_M", nil)
            end
        end
        return
    end
    local function setupCharacter(char)
        if not char then return end
        local humanoid = char:WaitForChild("Humanoid")
        if Config.Movement.InfiniteStamina then
            humanoid:SetAttribute("ZSPRN_M", true)
        end
        local conn = RunService.RenderStepped:Connect(function()
            if not Config.Movement.InfiniteStamina then conn:Disconnect() return end
            if humanoid:GetAttribute("ZSPRN_M") ~= true then
                humanoid:SetAttribute("ZSPRN_M", true)
            end
        end)
        table.insert(RuntimeData.InfiniteStamina.Connections, conn)
    end
    if LocalPlayer.Character then
        setupCharacter(LocalPlayer.Character)
    end
    local characterConn = LocalPlayer.CharacterAdded:Connect(setupCharacter)
    table.insert(RuntimeData.InfiniteStamina.Connections, characterConn)
end

local function SetupInstantReload()
    if RuntimeData.InstantReload.CharacterConnection then
        RuntimeData.InstantReload.CharacterConnection:Disconnect()
        RuntimeData.InstantReload.CharacterConnection = nil
    end
    for _, conn in pairs(RuntimeData.InstantReload.Connections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    RuntimeData.InstantReload.Connections = {}
    if RuntimeData.InstantReload.ToolConnection then
        RuntimeData.InstantReload.ToolConnection:Disconnect()
        RuntimeData.InstantReload.ToolConnection = nil
    end
    if not Config.Misc.InstantReload then return end
    local function setupTool(tool)
        if not tool or not tool:FindFirstChild("IsGun") then return end
        local values = tool:FindFirstChild("Values")
        if not values then return end
        local serverAmmo = values:FindFirstChild("SERVER_Ammo")
        local storedAmmo = values:FindFirstChild("SERVER_StoredAmmo")
        local maxAmmo = values:FindFirstChild("MaxAmmo") or { Value = 30 }
        if not serverAmmo or not storedAmmo then return end
        local function triggerReload()
            if Config.Misc.InstantReload and storedAmmo.Value > 0 and tick() - RuntimeData.InstantReload.LastReloadTime >= RuntimeData.InstantReload.ReloadCooldown then
                Events.GNX_R:FireServer(tick(), "KLWE89U0", tool)
                RuntimeData.InstantReload.LastReloadTime = tick()
            end
        end
        local conn1 = serverAmmo:GetPropertyChangedSignal("Value"):Connect(function()
            if serverAmmo.Value < maxAmmo.Value then
                triggerReload()
            end
        end)
        table.insert(RuntimeData.InstantReload.Connections, conn1)
        local conn2 = storedAmmo:GetPropertyChangedSignal("Value"):Connect(function()
            if serverAmmo.Value < maxAmmo.Value then
                triggerReload()
            end
        end)
        table.insert(RuntimeData.InstantReload.Connections, conn2)
        if storedAmmo.Value > 0 and serverAmmo.Value < maxAmmo.Value then
            triggerReload()
        end
    end
    local function setupCharacter(char)
        for i = #RuntimeData.InstantReload.Connections, 1, -1 do
            local conn = RuntimeData.InstantReload.Connections[i]
            if conn then conn:Disconnect() end
            table.remove(RuntimeData.InstantReload.Connections, i)
        end
        local equippedTool = char:FindFirstChildOfClass("Tool")
        if equippedTool then
            setupTool(equippedTool)
        end
        if RuntimeData.InstantReload.ToolConnection then
            RuntimeData.InstantReload.ToolConnection:Disconnect()
        end
        RuntimeData.InstantReload.ToolConnection = char.ChildAdded:Connect(function(obj)
            if obj:IsA("Tool") and obj:FindFirstChild("IsGun") then
                setupTool(obj)
            end
        end)
        local toolRemovedConn = char.ChildRemoved:Connect(function(obj)
            if obj:IsA("Tool") and obj:FindFirstChild("IsGun") then
                for i = #RuntimeData.InstantReload.Connections, 1, -1 do
                    local conn = RuntimeData.InstantReload.Connections[i]
                    if conn then conn:Disconnect() end
                    table.remove(RuntimeData.InstantReload.Connections, i)
                end
            end
        end)
        table.insert(RuntimeData.InstantReload.Connections, toolRemovedConn)
    end
    if LocalPlayer.Character then
        setupCharacter(LocalPlayer.Character)
    end
    RuntimeData.InstantReload.CharacterConnection = LocalPlayer.CharacterAdded:Connect(setupCharacter)
end

local function SetupFlight()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local rootPart = char.HumanoidRootPart
    if not Config.Movement.FlyEnabled then
        rootPart.Velocity = Vector3.new(0, 0, 0)
        return
    end
    local moveDirection = Vector3.new(0, 0, 0)
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveDirection = moveDirection + Camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveDirection = moveDirection - Camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveDirection = moveDirection + Camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveDirection = moveDirection - Camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveDirection = moveDirection + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        moveDirection = moveDirection - Vector3.new(0, 1, 0)
    end
    if moveDirection.Magnitude > 0 then
        moveDirection = moveDirection.Unit
    end
    rootPart.Velocity = moveDirection * Config.Movement.FlySpeed
    local look = Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
    if look.Magnitude > 0 then
        rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + look)
    end
    if tick() - RuntimeData.Movement.LastRagdollTime >= Config.Movement.RagdollInterval then
        if Events.Ragdoll then
            Events.Ragdoll:FireServer("__---r", Vector3.new(0, 0, 0), rootPart.CFrame, false)
        end
        RuntimeData.Movement.LastRagdollTime = tick()
    end
end

local function SetupFinishSpeed()
    if Config.Movement.FinishSpeedEnabled then
        FinishSpeedMulti.Value = Config.Movement.FinishSpeedValue
    else
        FinishSpeedMulti.Value = 1
    end
end

local function SetupSpinBot()
    if not Config.Movement.SpinBotEnabled or not LocalPlayer.Character then return end
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local delta = RunService.RenderStepped:Wait()
    RuntimeData.Movement.SpinBotAngle = RuntimeData.Movement.SpinBotAngle + (Config.Movement.SpinBotSpeed * 2 * delta)
    if RuntimeData.Movement.SpinBotAngle >= 360 then
        RuntimeData.Movement.SpinBotAngle = RuntimeData.Movement.SpinBotAngle - 360
    end
    rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, math.rad(RuntimeData.Movement.SpinBotAngle), 0)
end

local MainWindow = InterfaceLib:CreateWindow({
    Title = 'xvice \\ v1',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Combat = MainWindow:AddTab('Combat'),
    Visuals = MainWindow:AddTab('Visuals'),
    Movement = MainWindow:AddTab('Movement'),
    Misc = MainWindow:AddTab('Misc'),
    UISettings = MainWindow:AddTab('UI Settings')
}

local Groups = {
    Combat = {
        AimLock = Tabs.Combat:AddLeftGroupbox('AimLock'),
        MeleeAura = Tabs.Combat:AddLeftGroupbox('Melee Aura'),
        SilentAim = Tabs.Combat:AddRightGroupbox('Silent Aim'),
        Launchers = Tabs.Combat:AddLeftGroupbox('Launchers Control'),
        RageBot = Tabs.Combat:AddRightGroupbox('RageBot'),
        WeaponMods = Tabs.Combat:AddRightGroupbox('Weapon Mods')
    },
    Visuals = {
        ESP = Tabs.Visuals:AddLeftGroupbox('Visuals'),
        Camera = Tabs.Visuals:AddLeftGroupbox('Camera')
    },
    Movement = {
        Character = Tabs.Movement:AddLeftGroupbox('Character'),
        Other = Tabs.Movement:AddRightGroupbox('Other')
    },
    Misc = {
        General = Tabs.Misc:AddLeftGroupbox('General')
    },
    UISettings = {
        Menu = Tabs.UISettings:AddLeftGroupbox('Menu')
    }
}

Groups.Combat.AimLock:AddToggle('AimLock', {
    Text = 'AimLock',
    Default = false,
    Callback = function(value)
        Config.AimLock.Enabled = value
        if not value then
            RuntimeData.Aiming.IsActive = false
            RuntimeData.Aiming.CurrentTarget = nil
            RuntimeData.Aiming.TargetLocked = false
        end
    end
}):AddKeyPicker('AimlockKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'AimLock'
})

Groups.Combat.AimLock:AddToggle('TeamCheck', {
    Text = 'Team Check',
    Default = false,
    Callback = function(value)
        Config.AimLock.TeamCheck = value
    end
})

Groups.Combat.AimLock:AddToggle('VelocityToggle', {
    Text = 'Velocity',
    Default = false,
    Callback = function(value)
        Config.AimLock.VelocityPrediction = value
    end
})

Groups.Combat.AimLock:AddSlider('Smoothness', {
    Text = 'Smoothness',
    Default = 0.1,
    Min = 0.1,
    Max = 1,
    Rounding = 1,
    Callback = function(value)
        Config.AimLock.Smoothness = value
    end
})

Groups.Combat.AimLock:AddDropdown('TargetBody', {
    Text = 'Target',
    Values = ValidParts,
    Default = 1,
    Callback = function(value)
        Config.AimLock.TargetPart = value
    end
})

Groups.Combat.MeleeAura:AddToggle('MeleeAuraToggle', {
    Text = 'Melee Aura',
    Default = false,
    Callback = function(value)
        Config.MeleeAura.Enabled = value
        RunMeleeAura()
    end
}):AddKeyPicker('MeleeAuraKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Melee Aura'
})

Groups.Combat.MeleeAura:AddToggle('MeleeAuraCheckTeam', {
    Text = 'Team Check',
    Default = false,
    Callback = function(value)
        Config.MeleeAura.TeamCheck = value
    end
})

Groups.Combat.MeleeAura:AddSlider('MeleeAuraDistance', {
    Text = 'Distance',
    Default = 12,
    Min = 5,
    Max = 20,
    Rounding = 0,
    Callback = function(value)
        Config.MeleeAura.Range = value
    end
})

Groups.Combat.MeleeAura:AddDropdown('MeleeTargetPart', {
    Text = 'Target',
    Values = ValidParts,
    Default = 1,
    Callback = function(value)
        Config.MeleeAura.TargetPart = value
    end
})

Groups.Combat.SilentAim:AddToggle('SilentAimToggle', {
    Text = 'Silent Aim',
    Default = false,
    Callback = function(value)
        Config.SilentAim.Enabled = value
        SetupSilentAim()
    end
}):AddKeyPicker('SilentAimKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Silent Aim'
})

Groups.Combat.SilentAim:AddToggle('SilentAimCheckTeam', {
    Text = 'Team Check',
    Default = false,
    Callback = function(value)
        Config.SilentAim.TeamCheck = value
    end
})

Groups.Combat.SilentAim:AddDropdown('SilentTargetPart', {
    Text = 'Target Part',
    Values = ValidParts,
    Default = 1,
    Callback = function(value)
        Config.SilentAim.TargetPart = value
    end
})

Groups.Combat.Launchers:AddToggle('LaunchersToggle', {
    Text = 'Launchers Control',
    Default = false,
    Callback = function(value)
        Config.Launchers.Enabled = value
        SetupLauncherControl()
        if not value then
            RuntimeData.Launchers.Forward = 0
            RuntimeData.Launchers.Sideways = 0
            RuntimeData.Launchers.StopControl = false
            RuntimeData.Launchers.ExpectedProjectile = nil
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.Anchored = false
            end
            if char and char:FindFirstChild("Humanoid") then
                Camera.CameraSubject = char.Humanoid
            end
            for _, conn in pairs(RuntimeData.Launchers.Connections) do
                if conn then conn:Disconnect() end
            end
            RuntimeData.Launchers.Connections = {}
        end
    end
}):AddKeyPicker('LauncherKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Control'
})

Groups.Combat.Launchers:AddSlider('Speed', {
    Text = 'Speed',
    Default = 200,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(value)
        Config.Launchers.Speed = value
    end
})

Groups.Combat.Launchers:AddSlider('TurnSensitivity', {
    Text = 'Turn Sensitivity',
    Default = 1,
    Min = 0.5,
    Max = 2,
    Rounding = 1,
    Callback = function(value)
        Config.Launchers.TurnSensitivity = value
    end
})

Groups.Combat.RageBot:AddToggle('RageBotToggle', {
    Text = 'RageBot',
    Default = false,
    Callback = function(value)
        Config.RageBot.Enabled = value
        RunRageBot()
    end
}):AddKeyPicker('RageBotKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'RageBot'
})

Groups.Combat.RageBot:AddToggle('RageBotTeamCheck', {
    Text = 'Team Check',
    Default = false,
    Callback = function(value)
        Config.RageBot.TeamCheck = value
    end
})

Groups.Combat.RageBot:AddDropdown('RageBotTargetPart', {
    Text = 'Target Part',
    Values = ValidParts,
    Default = 1,
    Callback = function(value)
        Config.RageBot.TargetPart = value
    end
})

Groups.Combat.RageBot:AddSlider('RageBotCooldown', {
    Text = 'Cooldown',
    Default = 0.05,
    Min = 0.01,
    Max = 1,
    Rounding = 2,
    Callback = function(value)
        Config.RageBot.Cooldown = value
    end
})

Groups.Combat.WeaponMods:AddToggle('WallbangToggle', {
    Text = 'Wallbang',
    Default = false,
    Callback = function(value)
        Config.Misc.WallbangEnabled = value
        local map = Workspace:FindFirstChild("Map")
        if map then
            local parts = map:FindFirstChild("Parts")
            if parts then
                local mParts = parts:FindFirstChild("M_Parts")
                if mParts then
                    mParts.Parent = value and Workspace:FindFirstChild("Characters") or parts
                end
            end
        end
    end
})

Groups.Combat.WeaponMods:AddToggle('InstantReloadToggle', {
    Text = 'Instant Reload',
    Default = false,
    Callback = function(value)
        Config.Misc.InstantReload = value
        SetupInstantReload()
    end
})

Groups.Visuals.ESP:AddToggle('ESP', {
    Text = 'ESP',
    Default = false,
    Callback = function(value)
        Config.Visuals.Enabled = value
        if not value then
            for player, visuals in pairs(RuntimeData.ESP.Renderings) do
                DestroyESPVisuals(visuals)
                RuntimeData.ESP.Renderings[player] = nil
            end
        else
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    task.spawn(function() UpdatePlayerESP(player) end) -- Async update to reduce lag
                end
            end
        end
    end
}):AddKeyPicker('ESPToggleKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'ESP'
})

Groups.Visuals.ESP:AddToggle('BoxesToggle', {
    Text = 'Boxes',
    Default = false,
    Callback = function(value)
        Config.Visuals.Boxes = value
        if Config.Visuals.Enabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    task.spawn(function() UpdatePlayerESP(player) end)
                end
            end
        end
    end
})

Groups.Visuals.ESP:AddToggle('NamesToggle', {
    Text = 'Names',
    Default = false,
    Callback = function(value)
        Config.Visuals.Names = value
        if Config.Visuals.Enabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    task.spawn(function() UpdatePlayerESP(player) end)
                end
            end
        end
    end
})

Groups.Visuals.ESP:AddToggle('HealthToggle', {
    Text = 'Health',
    Default = false,
    Callback = function(value)
        Config.Visuals.Health = value
        if Config.Visuals.Enabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    task.spawn(function() UpdatePlayerESP(player) end)
                end
            end
        end
    end
})

Groups.Visuals.ESP:AddToggle('ToolsToggle', {
    Text = 'Tools',
    Default = false,
    Callback = function(value)
        Config.Visuals.Tools = value
        if Config.Visuals.Enabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    task.spawn(function() UpdatePlayerESP(player) end)
                end
            end
        end
    end
})

Groups.Visuals.ESP:AddToggle('TracersToggle', {
    Text = 'Tracers',
    Default = false,
    Callback = function(value)
        Config.Visuals.Tracers = value
        if Config.Visuals.Enabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    task.spawn(function() UpdatePlayerESP(player) end)
                end
            end
        end
    end
})

Groups.Visuals.ESP:AddToggle('TeamCheckESP', {
    Text = 'Team Check',
    Default = false,
    Callback = function(value)
        Config.Visuals.TeamCheck = value
        if Config.Visuals.Enabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    task.spawn(function() UpdatePlayerESP(player) end)
                end
            end
        end
    end
})

Groups.Visuals.Camera:AddSlider('FovSlider', {
    Text = 'Field Of View',
    Default = 70,
    Min = 70,
    Max = 120,
    Rounding = 1,
    Callback = function(value)
        Config.Visuals.FovValue = value
    end
})

Groups.Movement.Character:AddToggle('SpeedToggle', {
    Text = 'WalkSpeed',
    Default = false,
    Callback = function(value)
        Config.Movement.SpeedEnabled = value
    end
}):AddKeyPicker('SpeedKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'WalkSpeed'
})

Groups.Movement.Character:AddSlider('SpeedSlider', {
    Text = 'Speed Value',
    Default = 16,
    Min = 16,
    Max = 42,
    Rounding = 1,
    Callback = function(value)
        Config.Movement.SpeedValue = value
    end
})

Groups.Movement.Character:AddToggle('FlyToggle', {
    Text = 'Fly',
    Default = false,
    Callback = function(value)
        Config.Movement.FlyEnabled = value
        SetupFlight()
    end
}):AddKeyPicker('FlyKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Fly'
})

Groups.Movement.Character:AddSlider('FlySpeed', {
    Text = 'Fly Speed',
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 1,
    Callback = function(value)
        Config.Movement.FlySpeed = value
    end
})

Groups.Movement.Character:AddToggle('SpinBotToggle', {
    Text = 'SpinBot',
    Default = false,
    Callback = function(value)
        Config.Movement.SpinBotEnabled = value
    end
}):AddKeyPicker('SpinBotKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'SpinBot'
})

Groups.Movement.Character:AddSlider('SpinBotSpeed', {
    Text = 'Spin Speed',
    Default = 100,
    Min = 1,
    Max = 1500,
    Rounding = 0,
    Callback = function(value)
        Config.Movement.SpinBotSpeed = value
    end
})

Groups.Movement.Other:AddToggle('InfiniteStaminaToggle', {
    Text = 'Infinite Stamina',
    Default = false,
    Callback = function(value)
        Config.Movement.InfiniteStamina = value
        SetupInfiniteStamina()
    end
})

Groups.Movement.Other:AddToggle('FinishSpeedToggle', {
    Text = 'Finish Speed',
    Default = false,
    Callback = function(value)
        Config.Movement.FinishSpeedEnabled = value
        SetupFinishSpeed()
    end
})

Groups.Movement.Other:AddSlider('FinishSpeedSlider', {
    Text = 'Finish Speed Multiplier',
    Default = 1,
    Min = 0.2,
    Max = 1.6,
    Rounding = 1,
    Callback = function(value)
        Config.Movement.FinishSpeedValue = value
        if Config.Movement.FinishSpeedEnabled then
            FinishSpeedMulti.Value = value
        end
    end
})

Groups.Misc.General:AddButton({
    Text = 'Fast Interact',
    Func = function()
        game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt)
            prompt.HoldDuration = 0
        end)
    end,
    DoubleClick = false
})

Groups.Misc.General:AddSlider('GravitySlider', {
    Text = 'Gravity',
    Default = 196,
    Min = 75,
    Max = 196,
    Rounding = 1,
    Callback = function(value)
        Config.Misc.GravityValue = value
        Workspace.Gravity = value
    end
})

Groups.UISettings.Menu:AddButton('Unload', function()
    InterfaceLib:Unload()
end)

Groups.UISettings.Menu:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'K',
    NoUI = true,
    Text = 'Menu keybind'
})

InterfaceLib.ToggleKeybind = Options.MenuKeybind
ThemeController:SetLibrary(InterfaceLib)
ConfigManager:SetLibrary(InterfaceLib)
ConfigManager:IgnoreThemeSettings()
ConfigManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeController:SetFolder('xvc')
ConfigManager:SetFolder('xvc/configs')
ConfigManager:BuildConfigSection(Tabs.UISettings)
ThemeController:ApplyToTab(Tabs.UISettings)
ConfigManager:LoadAutoloadConfig()

local InputConnections = {}
InputConnections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Config.AimLock.AimKey and Config.AimLock.Enabled then
        RuntimeData.Aiming.IsActive = true
        if not RuntimeData.Aiming.TargetLocked then
            RuntimeData.Aiming.CurrentTarget = FindClosestRageBotEnemy()
            if RuntimeData.Aiming.CurrentTarget then
                RuntimeData.Aiming.TargetLocked = true
            end
        end
    elseif input.KeyCode == Config.Movement.SpeedKey then
        Config.Movement.SpeedEnabled = not Config.Movement.SpeedEnabled
    end
end)

InputConnections.InputEnded = UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Config.AimLock.AimKey then
        RuntimeData.Aiming.IsActive = false
        RuntimeData.Aiming.TargetLocked = false
    end
end)

local RenderConnection = RunService.RenderStepped:Connect(function()
    if Config.AimLock.Enabled and RuntimeData.Aiming.IsActive then
        SmoothCameraLock()
    end
    UpdateFOV()
    if Config.Visuals.Enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                task.spawn(function() UpdatePlayerESP(player) end)
            end
        end
    end
    UpdateMovementSpeed()
    if Config.Movement.FlyEnabled then
        SetupFlight()
    end
    if Config.Movement.SpinBotEnabled then
        SetupSpinBot()
    end
    SetupFinishSpeed()
end)

for _, player in ipairs(Players:GetPlayers()) do
    SetupPlayerTracking(player)
end

local PlayerConnections = {}
PlayerConnections.PlayerAdded = Players.PlayerAdded:Connect(SetupPlayerTracking)
PlayerConnections.PlayerRemoving = Players.PlayerRemoving:Connect(HandlePlayerLeave)

local Debris = Workspace:WaitForChild("Debris")
local VParts = Debris:WaitForChild("VParts")
local ProjectileConnection = VParts.ChildAdded:Connect(function(projectile)
    if not Config.Launchers.Enabled or not LocalPlayer.Character or not RuntimeData.Launchers.ExpectedProjectile then return end
    if projectile.Name ~= RuntimeData.Launchers.ExpectedProjectile then return end
    if tick() - RuntimeData.Launchers.LastFireTime > 0.2 then return end
    local weapons = ProjectileTypes[projectile.Name]
    if weapons and CheckWeaponEquipped(weapons) then
        task.spawn(function()
            ControlRocket(projectile)
        end)
    end
end)

PreloadWeapons()
