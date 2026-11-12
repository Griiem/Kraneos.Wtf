local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Ws = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Surv = Teams:WaitForChild("Survivors")
local Killer = Teams:WaitForChild("Killer")

local plr = Players.LocalPlayer

return function(Window, WindUI)

local Esp = {}

--=====================================================================
-- CONFIG (ajuste aqui conforme o seu jogo)
--=====================================================================

-- Nomes (em minúsculo ou não, tanto faz) dos objetos do mapa.
-- O script procura Models/Parts no Workspace com esses nomes.
Esp.Names = {
    Generator = { "Generator" },
    Hook      = { "Hook" },
    ExitGate  = { "ExitGate", "Exit Gate" },
}

-- Ordem e rótulos que aparecem na UI
local CATEGORIES = {
    { Key = "Killer",    Label = "Killer",     Fill = Color3.fromRGB(255, 60, 60)   },
    { Key = "Survivor",  Label = "Survivors",  Fill = Color3.fromRGB(80, 255, 120)  },
    { Key = "Generator", Label = "Generators", Fill = Color3.fromRGB(255, 220, 80)  },
    { Key = "Hook",      Label = "Hooks",      Fill = Color3.fromRGB(255, 140, 40)  },
    { Key = "ExitGate",  Label = "Exit Gates", Fill = Color3.fromRGB(80, 200, 255)  },
}

local SKELETONS = {
    { Key = "Killer",   Label = "Killer Skeleton",    Color = Color3.fromRGB(255, 60, 60)  },
    { Key = "Survivor", Label = "Survivor Skeleton",  Color = Color3.fromRGB(80, 255, 120) },
}

--=====================================================================
-- ESTADO
--=====================================================================

Esp.Alive = true
Esp.Connections = {}
Esp.Entries = {}     -- [Instance] = { Highlight = Highlight, Category = string }
Esp.Skeletons = {}   -- [Character] = { Category = string, Lines = {Drawing} }
Esp.Tracked = { Generator = {}, Hook = {}, ExitGate = {} } -- [Category][Instance] = true

Esp.Folder = Instance.new("Folder")
Esp.Folder.Name = "Esp"
Esp.Folder.Parent = Ws

Esp.Style = {
    FillTransparency = 0.5,
    OutlineTransparency = 0.8,
}

Esp.Settings = {}
for _, c in CATEGORIES do
    Esp.Settings[c.Key] = {
        Enabled = false,
        FillColor = c.Fill,
        OutlineColor = Color3.fromRGB(0, 0, 0),
    }
end

Esp.Skeleton = {}
for _, s in SKELETONS do
    Esp.Skeleton[s.Key] = { Enabled = false, Color = s.Color }
end

local HasDrawing = (Drawing ~= nil and Drawing.new ~= nil)

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Esp.Connections, c)
    return c
end

--=====================================================================
-- DETECÇÃO DE OBJETOS ESTÁTICOS (geradores, ganchos, exit gate)
--=====================================================================

local NameToCategory = {}
for cat, names in Esp.Names do
    for _, n in names do
        NameToCategory[string.lower(n)] = cat
    end
end

local function hasTrackedAncestor(inst, set)
    local p = inst.Parent
    while p and p ~= Ws do
        if set[p] then return true end
        p = p.Parent
    end
    return false
end

local function consider(inst)
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    local cat = NameToCategory[string.lower(inst.Name)]
    if not cat then return end

    local set = Esp.Tracked[cat]
    if set[inst] or hasTrackedAncestor(inst, set) then return end
    set[inst] = true
end

connect(Ws.DescendantAdded, consider)

task.spawn(function()
    local n = 0
    for _, d in Ws:GetDescendants() do
        if not Esp.Alive then return end
        consider(d)
        n += 1
        if n % 2000 == 0 then task.wait() end
    end
end)

--=====================================================================
-- HIGHLIGHTS
--=====================================================================

function Esp:UpdateStyle()
    for _, entry in Esp.Entries do
        local s = Esp.Settings[entry.Category]
        local h = entry.Highlight
        h.FillColor = s.FillColor
        h.OutlineColor = s.OutlineColor
        h.FillTransparency = Esp.Style.FillTransparency
        h.OutlineTransparency = Esp.Style.OutlineTransparency
    end
end

local function createHighlight(inst, cat)
    local h = Instance.new("Highlight")
    h.Name = inst.Name .. " Highlight"
    h.Enabled = true
    h.Adornee = inst
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = Esp.Folder
    Esp.Entries[inst] = { Highlight = h, Category = cat }
end

local function playerCategory(player)
    if player.Team == Killer then return "Killer" end
    if player.Team == Surv then return "Survivor" end
    return nil
end

function Esp:Sync()
    if not Esp.Alive then return end

    -- 1) o que deveria estar com ESP agora
    local desired = {}

    for _, player in Players:GetPlayers() do
        if player ~= plr and player.Character then
            local cat = playerCategory(player)
            if cat and Esp.Settings[cat].Enabled then
                desired[player.Character] = cat
            end
        end
    end

    for cat, set in Esp.Tracked do
        for inst in set do
            if not inst:IsDescendantOf(Ws) then
                set[inst] = nil
            elseif Esp.Settings[cat].Enabled then
                desired[inst] = cat
            end
        end
    end

    -- 2) remove o que sobrou / mudou de categoria
    for inst, entry in Esp.Entries do
        if desired[inst] ~= entry.Category then
            entry.Highlight:Destroy()
            Esp.Entries[inst] = nil
        end
    end

    -- 3) cria o que falta
    for inst, cat in desired do
        if not Esp.Entries[inst] then
            createHighlight(inst, cat)
        end
    end

    Esp:UpdateStyle()

    -- 4) skeletons
    for char, sk in Esp.Skeletons do
        local cat = desired[char]
        if not cat or cat ~= sk.Category or not Esp.Skeleton[cat] or not Esp.Skeleton[cat].Enabled then
            for _, line in sk.Lines do line:Remove() end
            Esp.Skeletons[char] = nil
        end
    end

    if HasDrawing then
        for inst, cat in desired do
            local cfg = Esp.Skeleton[cat]
            if cfg and cfg.Enabled and not Esp.Skeletons[inst] and inst:IsA("Model") then
                Esp.Skeletons[inst] = { Category = cat, Lines = {} }
            end
        end
    end
end

--=====================================================================
-- SKELETON (usa a Drawing API do executor)
--=====================================================================

local R15_PAIRS = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

local R6_PAIRS = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
    { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

if HasDrawing then
    connect(RunService.RenderStepped, function()
        if next(Esp.Skeletons) == nil then return end

        local cam = Ws.CurrentCamera
        if not cam then return end

        for char, sk in Esp.Skeletons do
            local pairsList = char:FindFirstChild("UpperTorso") and R15_PAIRS or R6_PAIRS
            local color = Esp.Skeleton[sk.Category].Color

            for i, pair in pairsList do
                local line = sk.Lines[i]
                if not line then
                    line = Drawing.new("Line")
                    line.Thickness = 1.5
                    line.Transparency = 1
                    sk.Lines[i] = line
                end

                local a = char:FindFirstChild(pair[1])
                local b = char:FindFirstChild(pair[2])

                if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                    local pa, onA = cam:WorldToViewportPoint(a.Position)
                    local pb, onB = cam:WorldToViewportPoint(b.Position)
                    if onA and onB and pa.Z > 0 and pb.Z > 0 then
                        line.From = Vector2.new(pa.X, pa.Y)
                        line.To = Vector2.new(pb.X, pb.Y)
                        line.Color = color
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end

            -- esconde linhas sobrando (troca de rig)
            for i = #pairsList + 1, #sk.Lines do
                sk.Lines[i].Visible = false
            end
        end
    end)
end

--=====================================================================
-- LOOP DE SINCRONIZAÇÃO (garante que tudo se ajusta a respawn, troca
-- de time, rounds novos, etc.)
--=====================================================================

task.spawn(function()
    while Esp.Alive do
        Esp:Sync()
        task.wait(0.25)
    end
end)

--=====================================================================
-- CLEANUP
--=====================================================================

function Esp:Cleanup()
    Esp.Alive = false

    for _, c in Esp.Connections do
        if c.Connected then c:Disconnect() end
    end
    table.clear(Esp.Connections)

    for _, sk in Esp.Skeletons do
        for _, line in sk.Lines do line:Remove() end
    end
    table.clear(Esp.Skeletons)

    for _, entry in Esp.Entries do
        entry.Highlight:Destroy()
    end
    table.clear(Esp.Entries)

    for _, set in Esp.Tracked do table.clear(set) end

    if Esp.Folder then
        Esp.Folder:Destroy()
        Esp.Folder = nil
    end
end

--=====================================================================
-- UI
--=====================================================================

local Tab = Window:Tab({
    Title = "ESP",
    Icon = "eye",
})

local HStack = Tab:HStack({ AutoSpace = true })

local LeftVStack = HStack:VStack()
local RightVStack = HStack:VStack()

--< Esquerda: ativar / desativar
for _, c in CATEGORIES do
    LeftVStack:Toggle({
        Title = "Esp " .. c.Label,
        Type = "Checkbox",
        Value = false,
        Callback = function(state)
            Esp.Settings[c.Key].Enabled = state
            Esp:Sync()
        end,
    })
end

for _, s in SKELETONS do
    LeftVStack:Toggle({
        Title = s.Label,
        Type = "Checkbox",
        Value = false,
        Callback = function(state)
            if state and not HasDrawing then
                warn("[ESP] Drawing API indisponível neste executor, skeleton não vai aparecer.")
            end
            Esp.Skeleton[s.Key].Enabled = state
            Esp:Sync()
        end,
    })
end

--< Direita: customização
for _, c in CATEGORIES do
    RightVStack:Colorpicker({
        Title = c.Label .. " Fill Color",
        Default = Esp.Settings[c.Key].FillColor,
        Callback = function(color)
            Esp.Settings[c.Key].FillColor = color
            Esp:UpdateStyle()
        end,
    })

    RightVStack:Colorpicker({
        Title = c.Label .. " Outline Color",
        Default = Esp.Settings[c.Key].OutlineColor,
        Callback = function(color)
            Esp.Settings[c.Key].OutlineColor = color
            Esp:UpdateStyle()
        end,
    })
end

for _, s in SKELETONS do
    RightVStack:Colorpicker({
        Title = s.Label .. " Color",
        Default = Esp.Skeleton[s.Key].Color,
        Callback = function(color)
            Esp.Skeleton[s.Key].Color = color
        end,
    })
end

RightVStack:Slider({
    Title = "Fill Transparency",
    Value = { Min = 0, Max = 1, Default = Esp.Style.FillTransparency },
    Step = 0.1,
    Callback = function(value)
        Esp.Style.FillTransparency = value
        Esp:UpdateStyle()
    end,
})

RightVStack:Slider({
    Title = "Outline Transparency",
    Value = { Min = 0, Max = 1, Default = Esp.Style.OutlineTransparency },
    Step = 0.1,
    Callback = function(value)
        Esp.Style.OutlineTransparency = value
        Esp:UpdateStyle()
    end,
})

Window:OnDestroy(function()
    Esp:Cleanup()
end)

end
