local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

return function (Window, WindUI)

local LocalPlayer = Players.LocalPlayer

local JumpAim = {
    Enabled = false,
    Connection = nil,
}

local function isShiftLockOn()
    return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
end

local function faceCamera()
    if not JumpAim.Enabled then
        return
    end

    if isShiftLockOn() then
        return
    end

    local character = LocalPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not humanoid or not root or not camera then
        return
    end

    if humanoid.FloorMaterial == Enum.Material.Air then
        return
    end

    local look = camera.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.001 then
        return
    end

    root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
end

local function setJumpAim(state)
    JumpAim.Enabled = state

    if state then
        if not JumpAim.Connection then
            JumpAim.Connection = UserInputService.JumpRequest:Connect(faceCamera)
        end
    else
        if JumpAim.Connection then
            JumpAim.Connection:Disconnect()
            JumpAim.Connection = nil
        end
    end
end

local PlayerTab = Window:Tab({
    Title = "Player",
    Icon = "user-cog",
})

local JumpAimbot = PlayerTab:Toggle({
    Title = "Accept Terms",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        setJumpAim(state)
    end
})

Window:SetToggleKey(Enum.KeyCode.M)

Window:OnDestroy(function()
    JumpAim.Connection = nil
    JumpAim.Enabled = false
end)

end
