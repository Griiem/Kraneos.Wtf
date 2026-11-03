local Layers = game:GetService("Players")
local Teams = game:GetService("Teams")
local Ws = game:GetService("Workspace")

local Surv = Teams:WaitForChild("Survivors")
local Killer = Teams:WaitForChild("Killer")
local Spectator = Teams:WaitForChild("Spectator")

local plr = Layers.LocalPlayer


return function (Window, WindUI)

local Esp = {}

Esp.Folder = Instance.new("Folder")
Esp.Folder.Name = "Esp"
Esp.Folder.Parent = Ws

Esp.Enabled = false
Esp.OtherPlrs = {}
Esp.Highlights = {}
Esp.Settings = {}

Esp.Settings.FillColor = Color3.fromRGB(255, 120, 120)
Esp.Settings.OutlineColor = Color3.fromRGB(0, 0, 0)
Esp.Settings.FillTransparecny = .5
Esp.Settings.OutlineTransparency = .8

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

function Esp:UpdateSettings()
    for _, h in Esp.Highlights do
        h.FillColor = Esp.Settings.FillColor
        h.OutlineColor = Esp.Settings.OutlineColor
        h.FillTransparency = Esp.Settings.FillTransparecny
        h.OutlineTransparency = Esp.Settings.OutlineTransparency
    end
end

function Esp:Cleanup()
    if self.Connections then
        for _, connection in pairs(self.Connections) do
            if connection.Connected then
                connection:Disconnect()
            end
        end

        table.clear(self.Connections)
    end

    if self.Folder then
        self.Folder:Destroy()
        self.Folder = nil
    end

    if self.OtherPlrs then
        table.clear(self.OtherPlrs)
    end
end

function Esp:Active ()

    if not Esp.Enabled or plr.Team == Spectator then
        for player, high in Esp.Highlights do
            high:Destroy()
            Esp.Highlights[player] = nil
        end; return
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
            h.FillColor = Esp.Settings.FillColor
            h.OutlineColor = Esp.Settings.OutlineColor
            h.FillTransparency = Esp.Settings.FillTransparecny
            h.OutlineTransparency = Esp.Settings.OutlineTransparency
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

--< Left Stack
local ActiveEsp = LeftVStack:Toggle({
    Title = "Enable Esp",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        Esp.Enabled = state
        Esp:Active()
    end
})

--< Right Stack
local FillPicker = RightVStack:Colorpicker({
    Title = "Esp Fill Color",
    Default = Esp.Settings.FillColor,
    Callback = function(color)
        Esp.Settings.FillColor = color
        Esp:UpdateSettings()
    end
})

local FillTransparencySlider = RightVStack:Slider({
    Title = "Fill Transparecny",
    Value = {
        Min = 0,
        Max = 1,
        Default = .5
    },
    Step = .1,
    Callback = function(value)
        Esp.Settings.FillTransparecny = value
        Esp:UpdateSettings()
    end
})

local OutlinePicker = RightVStack:Colorpicker({
    Title = "Esp Outline Color",
    Default = Esp.Settings.OutlineColor,
    Callback = function(color)
        Esp.Settings.OutlineColor = color
        Esp:UpdateSettings()
    end
})

local OutlineTransparencySlider = RightVStack:Slider({
    Title = "Outline Transparecny",
    Value = {
        Min = 0,
        Max = 1,
        Default = .5
    },
    Step = .1,
    Callback = function(value)
        Esp.Settings.OutlineTransparency = value
        Esp:UpdateSettings()
    end
})

Window:OnDestroy(function()
    Esp:Cleanup()
end)

end
