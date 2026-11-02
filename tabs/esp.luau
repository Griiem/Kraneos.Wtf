local Layers = game:GetService("Players")
local Teams = game:GetService("Teams")
local Ws = game:GetService("Workspace")

local Surv = Teams:WaitForChild("Survivors")
local Killer = Teams:WaitForChild("Killer")
local Spectator = Teams:WaitForChild("Spectator")

local plr = Layers.LocalPlayer


return function (Window, WindUI)

local Esp = {}

Esp.Folder = Instance.new("Folder", Ws)
Esp.Folder.Name = "Esp"

Esp.Enabled = false
Esp.OtherPlrs = {}
Esp.Highlights = {}

function Esp:AddPlayer(player)
    if player == plr then return end

    Esp.OtherPlrs[player] = player

    player.CharacterAdded:Connect(function()
        if Esp.Enabled then Esp:Active() end
    end)

    player:GetPropertyChangedSignal("Team"):Connect(function()
        if Esp.Enabled then Esp:Active() end
    end)

    Esp.Highlights[player] = highlight
end


function Esp:Active ()

    if not Esp.Enabled or plr.Team == Spectator then
        for player, highlight in Esp.Highlights do
            highlight:Destroy()
            Esp.Highlights[player] = nil
        end
        return
    end

    for player, _ in Esp.OtherPlrs do

        if player.Team == plr.Team or player.Team == Spectator or not player.Character then
            if Esp.Highlights[player] then
                Esp.Highlights[player]:Destroy()
                Esp.Highlights[player] = nil
            end
            continue
        end

        local h = Esp.Highlights[player]

        if h and h.Adornee ~= player.Character then
            h:Destroy()
            Esp.Highlights[player] = nil
            h = nil
        end

        if not h then
            h = Instance.new("Highlight")
            h.Name = `{player.Name}'s Highlight`
            h.Enabled = true
            h.Adornee = player.Character
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.FillColor = Color3.fromRGB(255, 255, 125)
            h.OutlineColor = Color3.fromRGB(255, 255, 255)
            h.FillTransparency = 0
            h.OutlineTransparency = 0
            h.Parent = Esp.Folder

            Esp.Highlights[player] = h
        end
    end
end

for _, player in Layers:GetPlayers() do
    Esp:AddPlayer(player)

    player:GetPropertyChangedSignal("Team"):Connect(function()
        if Esp.Enabled then Esp:Active() end
    end)
end

Layers.PlayerAdded:Connect(function(player)
    Esp:AddPlayer(player)
end)

Layers.PlayerRemoving:Connect(function (player : Player)
    Esp.OtherPlrs[player] = nil
end)


local Tab = Window:Tab({
    Title = "ESP",
    Icon = "eye",
})

local HStack = Tab:HStack({AutoSpace = true})
 
local LeftVStack = HStack:VStack()
local RightVStack = HStack:VStack()
 
local ActiveEsp = LeftVStack:Toggle({
    Title = "Enable Esp",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        Esp.Enabled = state
        Esp:Active()
        
        
        
    end
})


end
