local player = game:GetService("Players").LocalPlayer

while task.wait() do
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    local rootPart = humanoid and humanoid.RootPart

    if humanoid and rootPart and humanoid:GetState() == Enum.HumanoidStateType.Physics then
        rootPart.AssemblyLinearVelocity = Vector3.zero
    end
end
