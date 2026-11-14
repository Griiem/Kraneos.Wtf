local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Survivors = Teams:WaitForChild("Survivors")
local Killer = Teams:WaitForChild("Killer")

return function(Window, WindUI)
    local Player = {}

    Player.Alive = true
    Player.Connections = {}

    Player.CustomEnabled = false
    Player.LegitEnabled = false
    Player.SpeedForce = 16

    Player.Character = nil
    Player.Humanoid = nil
    Player.Root = nil

    Player.NormalSpeed = nil
    Player.NaturalSpeed = nil
    Player.LastApplied = nil

    Player.CurrentBonus = 0
    Player.Hold = 0

    Player.Config = {
        Survivor = {
            MaxDistance = 100,
            MaxBoost = 0.35,
            OcclusionBoost = 0.12,
            OcclusionDistance = 90,
        },
        Killer = {
            MaxDistance = 100,
            MaxBoost = 0.25,
        },
        Hold = {
            MaxBoost = 0.2,
            Time = 2,
            ForwardDot = 0.65,
            Decay = 3,
        },
        TotalCap = 0.4,
        Smoothness = 3,
        CrouchThreshold = 0.85,
    }

    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(Player.Connections, connection)
        return connection
    end

    local function getCharacter(player)
        local character = player.Character
        if not character then return nil, nil, nil end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then
            return nil, nil, nil
        end
        return character, humanoid, root
    end

    local function getRole()
        if LocalPlayer.Team == Survivors then return "Survivor" end
        if LocalPlayer.Team == Killer then return "Killer" end
        return nil
    end

    local function resetCharacter()
        local character, humanoid, root = getCharacter(LocalPlayer)
        Player.Character = character
        Player.Humanoid = humanoid
        Player.Root = root
        Player.NormalSpeed = humanoid and humanoid.WalkSpeed or nil
        Player.NaturalSpeed = Player.NormalSpeed
        Player.LastApplied = nil
        Player.CurrentBonus = 0
        Player.Hold = 0
    end

    local function restoreSpeed()
        local humanoid = Player.Humanoid
        if humanoid and humanoid.Parent and Player.LastApplied then
            humanoid.WalkSpeed = Player.NaturalSpeed or Player.NormalSpeed
        end
        Player.LastApplied = nil
        Player.CurrentBonus = 0
        Player.Hold = 0
    end

    local function getNearestOf(root, team)
        local nearest = nil
        local nearestDistance = math.huge
        for _, target in Players:GetPlayers() do
            if target ~= LocalPlayer and target.Team == team then
                local _, humanoid, targetRoot = getCharacter(target)
                if humanoid and targetRoot then
                    local distance = (root.Position - targetRoot.Position).Magnitude
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearest = targetRoot
                    end
                end
            end
        end
        return nearest, nearestDistance
    end

    local function hasLineOfSight(origin, target, ignoreCharacter)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { ignoreCharacter, origin.Parent }
        local direction = target.Position - origin.Position
        local result = Workspace:Raycast(origin.Position, direction, params)
        return result == nil
    end

    local function getSurvivorBoost(root)
        local killerRoot, distance = getNearestOf(root, Killer)
        if not killerRoot then return 0 end
        local config = Player.Config.Survivor
        if distance > config.MaxDistance then return 0 end
        local proximity = 1 - math.clamp(distance / config.MaxDistance, 0, 1)
        local boost = proximity * config.MaxBoost
        if distance <= config.OcclusionDistance
            and not hasLineOfSight(killerRoot, root, Player.Character) then
            boost += config.OcclusionBoost * proximity
        end
        return boost
    end

    local function getKillerBoost(root)
        local survivorRoot, distance = getNearestOf(root, Survivors)
        if not survivorRoot then return 0 end
        local config = Player.Config.Killer
        if distance > config.MaxDistance then return 0 end
        local proximity = 1 - math.clamp(distance / config.MaxDistance, 0, 1)
        return proximity * config.MaxBoost
    end

    local function getHoldBoost(root, dt)
        local config = Player.Config.Hold
        local direction = Player.Humanoid.MoveDirection
        local forward = direction.Magnitude > 0.1
            and direction:Dot(root.CFrame.LookVector) > config.ForwardDot
        if forward then
            Player.Hold = math.min(Player.Hold + dt, config.Time)
        else
            Player.Hold = math.max(Player.Hold - dt * config.Decay, 0)
        end
        return config.MaxBoost * (Player.Hold / config.Time)
    end

    local function updateSpeed(dt)
        if not Player.Alive then return end
        local character, humanoid, root = getCharacter(LocalPlayer)
        if not humanoid then
            if Player.Humanoid then restoreSpeed() end
            Player.Character = nil
            Player.Humanoid = nil
            Player.Root = nil
            Player.NormalSpeed = nil
            Player.NaturalSpeed = nil
            return
        end

        if character ~= Player.Character then
            resetCharacter()
            return
        end

        if not (Player.CustomEnabled or Player.LegitEnabled) then
            restoreSpeed()
            return
        end

        if character:GetAttribute("Crouching") then
            Player.LastApplied = nil
            Player.CurrentBonus = 0
            Player.Hold = 0
            return
        end

        local currentSpeed = humanoid.WalkSpeed
        if Player.LastApplied then
            if math.abs(currentSpeed - Player.LastApplied) > 0.05 then
                Player.NaturalSpeed = currentSpeed
                Player.LastApplied = nil
            end
        else
            Player.NaturalSpeed = currentSpeed
        end

        local normalSpeed = Player.NormalSpeed or currentSpeed
        local naturalSpeed = Player.NaturalSpeed or currentSpeed

        if naturalSpeed < normalSpeed * Player.Config.CrouchThreshold then
            Player.LastApplied = nil
            Player.CurrentBonus = 0
            Player.Hold = 0
            return
        end

        local targetSpeed
        if Player.LegitEnabled then
            local bonus = getHoldBoost(root, dt)
            local role = getRole()
            if role == "Survivor" then
                bonus += getSurvivorBoost(root)
            elseif role == "Killer" then
                bonus += getKillerBoost(root)
            end
            bonus = math.min(bonus, Player.Config.TotalCap)
            Player.CurrentBonus = bonus
            targetSpeed = naturalSpeed * (1 + bonus)
        else
            Player.CurrentBonus = 0
            targetSpeed = Player.SpeedForce
        end

        local alpha = 1 - math.exp(-Player.Config.Smoothness * dt)
        local newSpeed = currentSpeed + (targetSpeed - currentSpeed) * alpha
        humanoid.WalkSpeed = newSpeed
        Player.LastApplied = newSpeed
    end

    function Player:CleanUp()
        Player.Alive = false
        for _, connection in self.Connections do
            if connection.Connected then
                connection:Disconnect()
            end
        end
        table.clear(self.Connections)
        restoreSpeed()
        self.Character = nil
        self.Humanoid = nil
        self.Root = nil
        self.NormalSpeed = nil
        self.NaturalSpeed = nil
        self.LastApplied = nil
    end

    local Tab = Window:Tab({ Title = "Player", Icon = "user-cog" })
    local HStack = Tab:HStack({ AutoSpace = true })
    local LeftVStack = HStack:VStack()
    local RightVStack = HStack:VStack()

    LeftVStack:Toggle({
        Title = "Custom Speed",
        Type = "Checkbox",
        Value = false,
        Callback = function(state)
            Player.CustomEnabled = state
            if not state and not Player.LegitEnabled then restoreSpeed() end
        end,
    })

    LeftVStack:Toggle({
        Title = "Legit Speed",
        Type = "Checkbox",
        Value = false,
        Callback = function(state)
            Player.LegitEnabled = state
            if not state then
                Player.CurrentBonus = 0
                Player.Hold = 0
                if not Player.CustomEnabled then restoreSpeed() end
            end
        end,
    })

    RightVStack:Slider({
        Title = "Speed Force",
        Value = { Min = 0.1, Max = 100, Default = 16 },
        Step = 0.1,
        Callback = function(value)
            Player.SpeedForce = value
        end,
    })

    resetCharacter()

    connect(LocalPlayer.CharacterAdded, function()
        task.wait(0.2)
        if Player.Alive then resetCharacter() end
    end)

    connect(LocalPlayer:GetPropertyChangedSignal("Team"), function()
        Player.CurrentBonus = 0
        Player.Hold = 0
    end)

    connect(RunService.Heartbeat, updateSpeed)

    Window:OnDestroy(function()
        Player:CleanUp()
    end)
end
