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
    SilentAim = { Enabled = false, TargetPart = "Head", TeamCheck = false, PredictionMultiplier = 0.15 },
    MeleeAura = { Enabled = false, Range = 12, TargetPart = "Head", TeamCheck = false, Prediction = true, PredictionMultiplier = 0.14 },
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
        MaxESPDistance = 1000,
        RayShow = false,
        RayColor = Color3.new(1, 0, 0)
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
    Misc = { 
        WallbangEnabled = false, 
        InstantReload = false, 
        GravityValue = 196
    },
    RageBot = { Enabled = false, TeamCheck = false, TargetPart = "Head", Cooldown = 0.05, PredictionMultiplier = 0.145 }
}

local AttachCD = {
    ["Fists"] = 0.05,
    ["Knuckledusters"] = 0.05,
    ["Nunchucks"] = 0.05,
    ["Shiv"] = 0.05,
    ["Bat"] = 1,
    ["Metal-Bat"] = 1,
    ["Chainsaw"] = 2.5,
    ["Balisong"] = 0.05,
    ["Rambo"] = 0.3,
    ["Shovel"] = 3,
    ["Sledgehammer"] = 2,
    ["Katana"] = 0.1,
    ["Wrench"] = 0.1
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
    InfiniteStamina = { Connections = {}, Enabled = false },
    Material = { Connection = nil },
    RayRenderings = {}
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

local function ApplyCharacterMaterial()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            pcall(function()
                part.Material = Enum.Material[Config.Misc.CharacterMaterial]
            end)
        end
    end
end

local function SetupMaterialOnCharacter()
    if RuntimeData.Material.Connection then
        RuntimeData.Material.Connection:Disconnect()
        RuntimeData.Material.Connection = nil
    end
    local function setupCharacter(char)
        if not char then return end
        ApplyCharacterMaterial()
        local humanoid = char:WaitForChild("Humanoid", 5)
        if humanoid then
            local diedConn = humanoid.Died:Connect(ApplyCharacterMaterial)
            RuntimeData.Material.Connection = diedConn
        end
    end
    if LocalPlayer.Character then
        setupCharacter(LocalPlayer.Character)
    end
    RuntimeData.Material.Connection = LocalPlayer.CharacterAdded:Connect(setupCharacter)
end

local function GetTargetPart(target)
    return target:FindFirstChild(Config.MeleeAura.TargetPart) or target:FindFirstChild("Head")
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
    if not target or not target:FindFirstChild("Head") or not LocalPlayer.Character then return end
    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    local attachcd = AttachCD[tool.Name] or 0.5
    if tick() - RuntimeData.Melee.AttackCooldown < attachcd then return end
    local result = Events.Melee1:InvokeServer("🍞", tick(), tool, "43TRFWX", "Normal", tick(), true)
    task.wait(0.3)
    local handle = tool:FindFirstChild("WeaponHandle") or tool:FindFirstChild("Handle") or LocalPlayer.Character:FindFirstChild("Left Arm")
    if not tool then return end
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
        tool,
        "2389ZFX34",
        result,
        true,
        handle,
        targetPart,
        target,
        LocalPlayer.Character.HumanoidRootPart.Position,
        predictedPos
    }
    if tool.Name == "Chainsaw" then
        for _ = 1, 15 do
            Events.Melee2:FireServer(unpack(arg2))
        end
    else
        Events.Melee2:FireServer(unpack(arg2))
    end
    RuntimeData.Melee.AttackCooldown = tick()
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
            local myChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                local myHrp = myChar.HumanoidRootPart
                for _, enemy in ipairs(Players:GetPlayers()) do
                    if enemy ~= LocalPlayer and enemy.Character and enemy.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = enemy.Character.HumanoidRootPart
                        local distance = (myHrp.Position - hrp.Position).Magnitude
                        local humanoid = enemy.Character:FindFirstChildOfClass("Humanoid")
                        if distance < Config.MeleeAura.Range and humanoid and humanoid.Health > 15 and
                           humanoid:GetState() ~= Enum.HumanoidStateType.Dead and not enemy.Character:FindFirstChildOfClass("ForceField") then
                            if Config.MeleeAura.TeamCheck and enemy.Team == LocalPlayer.Team then continue end
                            Attack(enemy.Character)
                        end
                    end
                end
            end
            task.wait(0.01)
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
                local predictedPos = part.Position
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root and root.Velocity then
                    predictedPos += root.Velocity * Config.SilentAim.PredictionMultiplier
                end
                local distanceFromCamera = (predictedPos - camPos).Magnitude
                if distanceFromCamera <= Config.Visuals.MaxESPDistance then
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
            task.wait(0.01)
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

local function UpdateFly()
    if not Config.Movement.FlyEnabled or not LocalPlayer.Character then return end
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local moveDirection = Vector3.new()
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection = moveDirection - Vector3.new(0, 1, 0) end
    if moveDirection.Magnitude > 0 then
        moveDirection = moveDirection.Unit * Config.Movement.FlySpeed
        rootPart.Velocity = moveDirection
    else
        rootPart.Velocity = Vector3.new(0, 0, 0)
    end
end

local function UpdateInfiniteStamina()
    if not Config.Movement.InfiniteStamina or not LocalPlayer.Character then return end
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = 50
    end
end

local function UpdateFinishSpeed()
    if not Config.Movement.FinishSpeedEnabled then
        FinishSpeedMulti.Value = 1
        return end
    FinishSpeedMulti.Value = Config.Movement.FinishSpeedValue
end

local function UpdateSpinBot()
    if not Config.Movement.SpinBotEnabled or not LocalPlayer.Character then return end
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(Config.Movement.SpinBotSpeed), 0)
end

local function UpdateFOV()
    Camera.FieldOfView = Config.Visuals.FovValue
end

local function SetupInstantReload()
    if RuntimeData.InstantReload.CharacterConnection then
        RuntimeData.InstantReload.CharacterConnection:Disconnect()
    end
    for _, conn in ipairs(RuntimeData.InstantReload.Connections) do
        conn:Disconnect()
    end
    RuntimeData.InstantReload.Connections = {}
    if RuntimeData.InstantReload.ToolConnection then
        RuntimeData.InstantReload.ToolConnection:Disconnect()
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
            if storedAmmo.Value > 0 and tick() - RuntimeData.InstantReload.LastReloadTime >= RuntimeData.InstantReload.ReloadCooldown then
                Events.GNX_R:FireServer(tick(), "KLWE89U0", tool)
                RuntimeData.InstantReload.LastReloadTime = tick()
            end
        end
        table.insert(RuntimeData.InstantReload.Connections, serverAmmo:GetPropertyChangedSignal("Value"):Connect(triggerReload))
        table.insert(RuntimeData.InstantReload.Connections, storedAmmo:GetPropertyChangedSignal("Value"):Connect(triggerReload))
    end
    local function setupCharacter(char)
        local equippedTool = char:FindFirstChildOfClass("Tool")
        if equippedTool then
            setupTool(equippedTool)
        end
        RuntimeData.InstantReload.ToolConnection = char.ChildAdded:Connect(function(obj)
            if obj:IsA("Tool") and obj:FindFirstChild("IsGun") then
                setupTool(obj)
            end
        end)
    end
    if LocalPlayer.Character then
        setupCharacter(LocalPlayer.Character)
    end
    RuntimeData.InstantReload.CharacterConnection = LocalPlayer.CharacterAdded:Connect(setupCharacter)
end

local function IsLauncherWeapon(toolName)
    for _, types in pairs(ProjectileTypes) do
        for _, name in ipairs(types) do
            if name == toolName then
                return true
            end
        end
    end
    return false
end

local function SetupLaunchers()
    for _, conn in ipairs(RuntimeData.Launchers.Connections) do
        conn:Disconnect()
    end
    RuntimeData.Launchers.Connections = {}
    if not Config.Launchers.Enabled then return end
    local function setupTool(tool)
        if not IsLauncherWeapon(tool.Name) then return end
        table.insert(RuntimeData.Launchers.Connections, tool.Activated:Connect(function()
            RuntimeData.Launchers.LastFireTime = tick()
            RuntimeData.Launchers.ExpectedProjectile = tool.Name
        end))
    end
    local function setupCharacter(char)
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            setupTool(tool)
        end
        table.insert(RuntimeData.Launchers.Connections, char.ChildAdded:Connect(function(obj)
            if obj:IsA("Tool") then
                setupTool(obj)
            end
        end))
    end
    if LocalPlayer.Character then
        setupCharacter(LocalPlayer.Character)
    end
    table.insert(RuntimeData.Launchers.Connections, LocalPlayer.CharacterAdded:Connect(setupCharacter))
end

local function ControlLauncher(projectile)
    if not Config.Launchers.Enabled or not projectile then return end
    -- Implementation for controlling launcher projectile
end

local function UpdateRayShow(player)
    if not Config.Visuals.RayShow or player == LocalPlayer or not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    local ray = RuntimeData.RayRenderings[player]
    if not ray then
        ray = Instance.new("CylinderPart")
        ray.Anchored = true
        ray.CanCollide = false
        ray.Transparency = 0.5
        ray.Material = Enum.Material.Neon
        ray.Size = Vector3.new(0.5, 0.5, 5)
        ray.Parent = Workspace
        RuntimeData.RayRenderings[player] = ray
    end
    ray.CFrame = CFrame.new(head.Position, head.Position + head.CFrame.LookVector * 5) * CFrame.Angles(math.pi/2, 0, 0)
    ray.Color = Config.Visuals.RayColor
end

local function DestroyRayShow(player)
    if RuntimeData.RayRenderings[player] then
        RuntimeData.RayRenderings[player]:Destroy()
        RuntimeData.RayRenderings[player] = nil
    end
end

local Window = InterfaceLib:CreateWindow({
    Title = 'xvc',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local tabs = {
    Combat = Window:AddTab('Combat'),
    Visuals = Window:AddTab('Visuals'),
    Movement = Window:AddTab('Movement'),
    Misc = Window:AddTab('Misc'),
    UISettings = Window:AddTab('UI Settings')
}

tabs.Combat:AddLeftGroupbox('AimLock'):AddToggle('AimLock', {
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

tabs.Combat:AddLeftGroupbox('AimLock'):AddToggle('TeamCheck', {
    Text = 'Team Check',
    Default = false,
    Callback = function(value)
        Config.AimLock.TeamCheck = value
    end
})

tabs.Combat:AddLeftGroupbox('AimLock'):AddToggle('VelocityToggle', {
    Text = 'Velocity',
    Default = false,
    Callback = function(value)
        Config.AimLock.VelocityPrediction = value
    end
})

tabs.Combat:AddLeftGroupbox('AimLock'):AddSlider('Smoothness', {
    Text = 'Smoothness',
    Default = 0.1,
    Min = 0.1,
    Max = 1,
    Rounding = 1,
    Callback = function(value)
        Config.AimLock.Smoothness = value
    end
})

tabs.Combat:AddLeftGroupbox('AimLock'):AddDropdown('TargetBody', {
    Text = 'Target',
    Values = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
    Default = 1,
    Callback = function(value)
        Config.AimLock.TargetPart = value
    end
})

tabs.Combat:AddLeftGroupbox('Melee Aura'):AddToggle('MeleeAuraToggle', {
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

tabs.Combat:AddLeftGroupbox('Melee Aura'):AddToggle('MeleeAuraCheckTeam', {
    Text = 'Team Check',
    Default = false,
    Callback = function(value)
        Config.MeleeAura.TeamCheck = value
    end
})

tabs.Combat:AddLeftGroupbox('Melee Aura'):AddSlider('MeleeAuraDistance', {
    Text = 'Distance',
    Default = 12,
    Min = 5,
    Max = 20,
    Rounding = 0,
    Callback = function(value)
        Config.MeleeAura.Range = value
    end
})

tabs.Combat:AddLeftGroupbox('Melee Aura'):AddDropdown('MeleeTargetPart', {
    Text = 'Target',
    Values = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
    Default = 1,
    Callback = function(value)
        Config.MeleeAura.TargetPart = value
    end
})

tabs.Combat:AddRightGroupbox('Silent Aim'):AddToggle('SilentAimToggle', {
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

tabs.Combat:AddRightGroupbox('Silent Aim'):AddToggle('SilentAimCheckTeam', {
    Text = 'Team Check',
    Default = false,
    Callback = function(value)
        Config.SilentAim.TeamCheck = value
    end
})

tabs.Combat:AddRightGroupbox('Silent Aim'):AddDropdown('SilentTargetPart', {
    Text = 'Target Part',
    Values = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
    Default = 1,
    Callback = function(value)
        Config.SilentAim.TargetPart = value
    end
})

tabs.Combat:AddLeftGroupbox('Launchers Control'):AddToggle('LaunchersToggle', {
    Text = 'Launchers Control',
    Default = false,
    Callback = function(value)
        Config.Launchers.Enabled = value
        SetupLaunchers()
    end
}):AddKeyPicker('LauncherKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Control'
})

tabs.Combat:AddLeftGroupbox('Launchers Control'):AddSlider('Speed', {
    Text = 'Speed',
    Default = 200,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(value)
        Config.Launchers.Speed = value
    end
})

tabs.Combat:AddLeftGroupbox('Launchers Control'):AddSlider('TurnSensitivity', {
    Text = 'Turn Sensitivity',
    Default = 1,
    Min = 0.5,
    Max = 2,
    Rounding = 1,
    Callback = function(value)
        Config.Launchers.TurnSensitivity = value
    end
})

tabs.Combat:AddRightGroupbox('RageBot'):AddToggle('RageBotToggle', {
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

tabs.Combat:AddRightGroupbox('RageBot'):AddToggle('RageBotTeamCheck', {
    Text = 'Team Check',
    Default = false,
    Callback = function(value)
        Config.RageBot.TeamCheck = value
    end
})

tabs.Combat:AddRightGroupbox('RageBot'):AddDropdown('RageBotTargetPart', {
    Text = 'Target Part',
    Values = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
    Default = 1,
    Callback = function(value)
        Config.RageBot.TargetPart = value
    end
})

tabs.Combat:AddRightGroupbox('RageBot'):AddSlider('RageBotCooldown', {
    Text = 'Cooldown',
    Default = 0.05,
    Min = 0.01,
    Max = 1,
    Rounding = 2,
    Callback = function(value)
        Config.RageBot.Cooldown = value
    end
})

tabs.Combat:AddRightGroupbox('Weapon Mods'):AddToggle('WallbangToggle', {
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

tabs.Combat:AddRightGroupbox('Weapon Mods'):AddToggle('InstantReloadToggle', {
    Text = 'Instant Reload',
    Default = false,
    Callback = function(value)
        Config.Misc.InstantReload = value
        SetupInstantReload()
    end
})

tabs.Visuals:AddLeftGroupbox('Visuals'):AddToggle('ESP', {
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
                    task.spawn(function() UpdatePlayerESP(player) end)
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

tabs.Visuals:AddLeftGroupbox('Visuals'):AddToggle('BoxesToggle', {
    Text = 'Boxes',
    Default = false,
    Callback = function(value)
        Config.Visuals.Boxes = value
    end
})

tabs.Visuals:AddLeftGroupbox('Visuals'):AddToggle('NamesToggle', {
    Text = 'Names',
    Default = false,
    Callback = function(value)
        Config.Visuals.Names = value
    end
})

tabs.Visuals:AddLeftGroupbox('Visuals'):AddToggle('HealthToggle', {
    Text = 'Health',
    Default = false,
    Callback = function(value)
        Config.Visuals.Health = value
    end
})

tabs.Visuals:AddLeftGroupbox('Visuals'):AddToggle('ToolsToggle', {
    Text = 'Tools',
    Default = false,
    Callback = function(value)
        Config.Visuals.Tools = value
    end
})

tabs.Visuals:AddLeftGroupbox('Visuals'):AddToggle('TracersToggle', {
    Text = 'Tracers',
    Default = false,
    Callback = function(value)
        Config.Visuals.Tracers = value
    end
})

tabs.Visuals:AddLeftGroupbox('Visuals'):AddToggle('TeamCheckESP', {
    Text = 'Team Check',
    Default = false,
    Callback = function(value)
        Config.Visuals.TeamCheck = value
    end
})

tabs.Visuals:AddLeftGroupbox('Camera'):AddSlider('FovSlider', {
    Text = 'Field Of View',
    Default = 70,
    Min = 70,
    Max = 120,
    Rounding = 1,
    Callback = function(value)
        Config.Visuals.FovValue = value
    end
})

tabs.Visuals:AddRightGroupbox('Other'):AddDropdown('CharacterMaterial', {
    Text = 'Character Material',
    Default = "SmoothPlastic",
    Values = {"SmoothPlastic", "Neon", "Metal", "Wood", "Concrete", "Brick", "Glass", "ForceField", "Plastic", "Foil", "Grass", "Ice", "Marble", "Sand", "Slate", "WoodPlanks"},
    Callback = function(value)
        Config.Misc.CharacterMaterial = value
        ApplyCharacterMaterial()
    end
})

tabs.Visuals:AddRightGroupbox('Other'):AddToggle('RayShowToggle', {
    Text = 'Ray Show',
    Default = false,
    Callback = function(value)
        Config.Visuals.RayShow = value
        if not value then
            for player in pairs(RuntimeData.RayRenderings) do
                DestroyRayShow(player)
            end
        end
    end
})

tabs.Movement:AddLeftGroupbox('Character'):AddToggle('SpeedToggle', {
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

tabs.Movement:AddLeftGroupbox('Character'):AddSlider('SpeedSlider', {
    Text = 'Speed Value',
    Default = 16,
    Min = 16,
    Max = 42,
    Rounding = 1,
    Callback = function(value)
        Config.Movement.SpeedValue = value
    end
})

tabs.Movement:AddLeftGroupbox('Character'):AddToggle('FlyToggle', {
    Text = 'Fly',
    Default = false,
    Callback = function(value)
        Config.Movement.FlyEnabled = value
    end
}):AddKeyPicker('FlyKey', {
    Default = 'None',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Fly'
})

tabs.Movement:AddLeftGroupbox('Character'):AddSlider('FlySpeed', {
    Text = 'Fly Speed',
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 1,
    Callback = function(value)
        Config.Movement.FlySpeed = value
    end
})

tabs.Movement:AddLeftGroupbox('Character'):AddToggle('SpinBotToggle', {
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

tabs.Movement:AddLeftGroupbox('Character'):AddSlider('SpinBotSpeed', {
    Text = 'Spin Speed',
    Default = 100,
    Min = 1,
    Max = 1500,
    Rounding = 0,
    Callback = function(value)
        Config.Movement.SpinBotSpeed = value
    end
})

tabs.Movement:AddRightGroupbox('Other'):AddToggle('InfiniteStaminaToggle', {
    Text = 'Infinite Stamina',
    Default = false,
    Callback = function(value)
        Config.Movement.InfiniteStamina = value
    end
})

tabs.Movement:AddRightGroupbox('Other'):AddToggle('FinishSpeedToggle', {
    Text = 'Finish Speed',
    Default = false,
    Callback = function(value)
        Config.Movement.FinishSpeedEnabled = value
    end
})

tabs.Movement:AddRightGroupbox('Other'):AddSlider('FinishSpeedSlider', {
    Text = 'Finish Speed Multiplier',
    Default = 1,
    Min = 0.2,
    Max = 1.6,
    Rounding = 1,
    Callback = function(value)
        Config.Movement.FinishSpeedValue = value
    end
})

tabs.Misc:AddLeftGroupbox('General'):AddButton({
    Text = 'Fast Interact',
    Func = function()
        game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt)
            prompt.HoldDuration = 0
        end)
    end,
    DoubleClick = false
})

tabs.Misc:AddLeftGroupbox('General'):AddSlider('GravitySlider', {
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

tabs.UISettings:AddLeftGroupbox('Menu'):AddButton('Unload', function()
    InterfaceLib:Unload()
end)

tabs.UISettings:AddLeftGroupbox('Menu'):AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
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
ConfigManager:BuildConfigSection(tabs.UISettings)
ThemeController:ApplyToTab(tabs.UISettings)
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
    UpdateFly()
    UpdateInfiniteStamina()
    UpdateFinishSpeed()
    UpdateSpinBot()
    if Config.Visuals.RayShow then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                UpdateRayShow(player)
            end
        end
    end
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
    task.spawn(ControlLauncher, projectile)
end)

PreloadWeapons()
SetupMaterialOnCharacter()
