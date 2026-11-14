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
    Player.MovementController = nil

    Player.Config = {
        Survivor = {
            MaxDistance = 100,
            MaxBoost = 0.35,
            OcclusionBoost = 0.12,
            OcclusionDistance = 90,
        },
        Killer = {
            MaxBoost = 0.25,
            Acceleration = 0.8,
        },
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

    -- Tenta encontrar o controlador de movimento interno do jogo
    local function findMovementController(character)
        if not getgc then return nil end
        for _, obj in getgc(true) do
            if type(obj) == "table" and rawget(obj, "character") == character then
                if rawget(obj, "normalWalkSpeed") and rawget(obj, "_movement") then
                    return obj
                end
            end
        end
        return nil
    end

    local function resetCharacter()
        local character, humanoid, root = getCharacter(LocalPlayer)
        Player.Character = character
        Player.Humanoid = humanoid
        Player.Root = root
        Player.MovementController = character and findMovementController(character) or nil
        Player.NormalSpeed = humanoid and humanoid.WalkSpeed or nil
        Player.NaturalSpeed = Player.NormalSpeed
        Player.LastApplied = nil
        Player.CurrentBonus = 0
    end

    local function restoreSpeed()
        local humanoid = Player.Humanoid
        if humanoid and humanoid.Parent and Player.LastApplied then
            humanoid.WalkSpeed = Player.NaturalSpeed or Player.NormalSpeed
        end
        if Player.MovementController then
            pcall(function()
                Player.MovementController.normalWalkSpeed = Player.NaturalSpeed or Player.NormalSpeed
            end)
        end
        Player.LastApplied = nil
        Player.CurrentBonus = 0
    end

    local function getNearestKiller(root)
        local nearest = nil
        local nearestDistance = math.huge
        for _, target in Players:GetPlayers() do
            if target ~= LocalPlayer and target.Team == Killer then
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
        params.FilterDescendantsInstances = { ignoreCharacter }
        local direction = target.Position - origin.Position
        local result = Workspace:Raycast(origin.Position, direction, params)
        if not result then return true end
        return result.Instance:IsDescendantOf(target.Parent)
    end

    local function getSurvivorBoost(root)
        local killerRoot, distance = getNearestKiller(root)
        if not killerRoot then return 0 end
        local config = Player.Config.Survivor
        if distance > config.MaxDistance then return 0 end
        local proximity = 1 - math.clamp(distance / config.MaxDistance, 0, 1)
        local boost = proximity * config.MaxBoost
        local killerCharacter = killerRoot.Parent
        if killerCharacter then
            local visible = hasLineOfSight(killerRoot, root, Player.Character)
            if not visible and distance <= config.OcclusionDistance then
                boost += config.OcclusionBoost * proximity
            end
        end
        return boost
    end

    local function getKillerBoost(root, dt)
        local config = Player.Config.Killer
        local direction = Player.Humanoid.MoveDirection
        local movingForward = direction.Magnitude > 0.1
            and direction:Dot(root.CFrame.LookVector) > 0.65
        local targetBonus = movingForward and config.MaxBoost or 0
        local alpha = 1 - math.exp(-config.Acceleration * dt)
        Player.CurrentBonus += (targetBonus - Player.CurrentBonus) * alpha
        return Player.CurrentBonus
    end

    local function applySpeed(speed)
        local humanoid = Player.Humanoid
        if not humanoid then return end
        if Player.MovementController then
            local success = pcall(function()
                Player.MovementController.normalWalkSpeed = speed
            end)
            if success then
                humanoid.WalkSpeed = speed
                return
            end
        end
        humanoid.WalkSpeed = speed
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
            Player.MovementController = nil
            return
        end

        if character ~= Player.Character then
            resetCharacter()
            return
        end

        if not Player.CustomEnabled then
            restoreSpeed()
            return
        end

        -- Respeita o estado de agachamento
        if character:GetAttribute("Crouching") then
            Player.LastApplied = nil
            Player.CurrentBonus = 0
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
            return
        end

        local targetSpeed
        if Player.LegitEnabled then
            local role = getRole()
            local bonus = 0
            if role == "Survivor" then
                bonus = getSurvivorBoost(root)
                Player.CurrentBonus = bonus
            elseif role == "Killer" then
                bonus = getKillerBoost(root, dt)
            else
                Player.CurrentBonus = 0
            end
            targetSpeed = naturalSpeed * (1 + bonus)
        else
            Player.CurrentBonus = 0
            targetSpeed = Player.SpeedForce
        end

        local alpha = 1 - math.exp(-Player.Config.Smoothness * dt)
        local newSpeed = currentSpeed + (targetSpeed - currentSpeed) * alpha
        applySpeed(newSpeed)
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
        self.MovementController = nil
    end

    -- Interface WindUI (mantida conforme sua estrutura)
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
            if not state then restoreSpeed() end
        end,
    })

    LeftVStack:Toggle({
        Title = "Legit Speed",
        Type = "Checkbox",
        Value = false,
        Callback = function(state)
            Player.LegitEnabled = state
            if not state then Player.CurrentBonus = 0 end
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
    end)

    connect(RunService.Heartbeat, updateSpeed)

    Window:OnDestroy(function()
        Player:CleanUp()
    end)
end
