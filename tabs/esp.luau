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
for _, player in Layers:GetPlayers() do
    if player == plr then continue end
    Esp.OtherPlrs[player] = player
end

function Esp:Active ()
    if not Esp.Enabled then
        for _, v in Esp.Folder:GetDescendants() do
            if v:IsA("Highlight") then
                v:Destroy()
            end
        end
    else
        for _, player in Esp.OtherPlrs do
            if player.Team == plr.Team or player.Team == Spectator or plr.Team == Spectator or not player.Character then continue end
            local h = Instance.new("Highlight", Esp.Folder)
            h.Name = `{player.Name}'s Highlight`
            h.Enabled = true
            h.Adornee = player.Character
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.FillColor = Color3.fromRGB(255, 255, 125)
            h.OutlineColor = Color3.fromRGB(255, 255, 255)
            h.FillTransparency = 0
            h.OutlineTransparency = 0
        end
    end
end

Layers.PlayerAdded:Connect(function (player : Player)
    Esp.OtherPlrs[player] = player
    player.CharacterAdded:Connect(function (char)
        Esp:Active()
    end)
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
