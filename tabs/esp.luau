return function (Window, WindUI)
    local T = game:GetService("Teams")
    local Layers = game:GetService("Players")
    local plr = Layers.LocalPlayer
    local Ws = game:GetService("Workspace")

    local Flags = {}

    local Esp = {}
    Esp.Killer = T:WaitForChild("Killer")
    Esp.Spectator = T:WaitForChild("Spectator")
    Esp.Survivors = T:WaitForChild("Survivors")
    Esp.OtherTeam = nil
    Esp.Enabled = false
    Esp.Connections = {}

    local f = Instance.new("Folder")
    f.Name = ""
    f.Parent = Ws

    local function Create(p)
        if f:FindFirstChild(p.Name) then return end

        local h = Instance.new("Highlight")
        h.Name = p.Name
        h.FillColor = Color3.fromRGB(255, 0, 0)
        h.OutlineColor = Color3.fromRGB(255, 255, 255)
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = f

        local function attach(c) if c then h.Adornee = c end end
        if p.Character then attach(p.Character) end
        p.CharacterAdded:Connect(attach)
    end

    function Esp:go(enabled)
        if not enabled then
            Esp.Enabled = false
            f:ClearAllChildren()
            for _, conn in Esp.Connections do conn:Disconnect() end
            Esp.Connections = {}
            return
        end

        if Esp.Enabled then return end
        Esp.Enabled = true

        task.spawn(function()
            while plr.Team == Esp.Spectator and Esp.Enabled do task.wait(.67) end
            if not Esp.Enabled then return end

            local enemyTeam
            if plr.Team == Esp.Killer then enemyTeam = Esp.Survivors
            elseif plr.Team == Esp.Survivors then enemyTeam = Esp.Killer
            else warn("[ESP] Player team not recognized") return end

            for _, p in Layers:GetPlayers() do
                if p ~= plr and p.Team == enemyTeam then Create(p) end
            end

            table.insert(Esp.Connections, Layers.PlayerAdded:Connect(function(p)
                p.CharacterAdded:Connect(function()
                    task.wait()
                    if p.Team == enemyTeam then Create(p) end
                end)
            end))

            table.insert(Esp.Connections, Layers.PlayerRemoving:Connect(function(p)
                local h = f:FindFirstChild(p.Name)
                if h then h:Destroy() end
            end))
        end)
    end

    local EspTab = Window:Tab({
        Title = "",
        Icon = "eye",
    })

    local HStack = EspTab:HStack(true)

    local LeftVStack = HStack:VStack(true)
    local RightVStack = HStack:VStack(true)

    local EnableEsp = LeftVStack:Toggle({
        Title = "Enable Esp",
        Flag = "Toggle_Esp",
        Callback = function(state)
            Esp:go(state)
        end,
    })

    return Esp
end
