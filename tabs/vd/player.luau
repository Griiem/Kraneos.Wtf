local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Survivors = Teams:WaitForChild("Survivors")
local Killer = Teams:WaitForChild("Killer")

local Config = {
    Enabled = true,
    MaxDistance = 80,
    ProximityBoost = { Survivor = 0.25, Killer = 0.2 },
    HoldBoost = 0.2,
    HoldTime = 2,
    TotalCap = 0.4,
    Smoothness = 4,
    ForwardDot = 0.65,
}

local State = {
    Character = nil,
    Natural = nil,
    LastApplied = nil,
    Hold = 0,
}

local function getAlive(player)
    local character = player.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return nil end
    return character, humanoid, root
end

local function getRole()
    if LocalPlayer.Team == Survivors then return "Survivor", Killer end
    if LocalPlayer.Team == Killer then return "Killer", Survivors end
    return nil, nil
end

local function nearestDistance(root, team)
    local nearest = math.huge
    for _, other in Players:GetPlayers() do
        if other ~= LocalPlayer and other.Team == team then
            local _, _, otherRoot = getAlive(other)
            if otherRoot then
                local distance = (root.Position - otherRoot.Position).Magnitude
                if distance < nearest then
                    nearest = distance
                end
            end
        end
    end
    return nearest
end

local function restore(humanoid)
    if humanoid and State.LastApplied and State.Natural then
        humanoid.WalkSpeed = State.Natural
    end
    State.LastApplied = nil
    State.Hold = 0
end

RunService.Heartbeat:Connect(function(dt)
    local character, humanoid, root = getAlive(LocalPlayer)
    if not character then
        State.Character = nil
        State.Natural = nil
        State.LastApplied = nil
        State.Hold = 0
        return
    end

    if character ~= State.Character then
        State.Character = character
        State.Natural = humanoid.WalkSpeed
        State.LastApplied = nil
        State.Hold = 0
        return
    end

    if not Config.Enabled then
        restore(humanoid)
        return
    end

    local current = humanoid.WalkSpeed
    if State.LastApplied then
        if math.abs(current - State.LastApplied) > 0.05 then
            State.Natural = current
            State.LastApplied = nil
        end
    else
        State.Natural = current
    end

    local direction = humanoid.MoveDirection
    local forward = direction.Magnitude > 0.1 and direction:Dot(root.CFrame.LookVector) > Config.ForwardDot
    if forward then
        State.Hold = math.min(State.Hold + dt, Config.HoldTime)
    else
        State.Hold = math.max(State.Hold - dt * 3, 0)
    end

    local bonus = Config.HoldBoost * (State.Hold / Config.HoldTime)

    local role, otherTeam = getRole()
    if role then
        local distance = nearestDistance(root, otherTeam)
        if distance < Config.MaxDistance then
            bonus += (1 - distance / Config.MaxDistance) * Config.ProximityBoost[role]
        end
    end

    bonus = math.min(bonus, Config.TotalCap)

    local target = State.Natural * (1 + bonus)
    local alpha = 1 - math.exp(-Config.Smoothness * dt)
    local newSpeed = current + (target - current) * alpha

    humanoid.WalkSpeed = newSpeed
    State.LastApplied = newSpeed
end)
