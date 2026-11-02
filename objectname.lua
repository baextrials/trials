local Players = game:GetService("Players")
local root = Players.LocalPlayer.Character.HumanoidRootPart

for _, m in ipairs(workspace:GetDescendants()) do
    if m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then
        local p = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
        if p and (p.Position - root.Position).Magnitude < 60 then
            print(m:GetFullName(), "| Humanoid:", m:FindFirstChildOfClass("Humanoid") ~= nil)
        end
    end
end
