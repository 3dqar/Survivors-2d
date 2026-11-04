-- Shared immutable catalog. Do not grant cosmetics from a client-supplied result.
-- Coin prices are initial tuning values; cosmetic purchases never alter gameplay stats.
local Cosmetics = {}
Cosmetics.List = {
    { id = "blue_fire", name = "Blue Fire", rarity = "Rare", price = 450, colors = { Color3.fromRGB(36, 185, 255), Color3.fromRGB(10, 72, 255) }, style = "flame" },
    { id = "shadow_smoke", name = "Shadow Smoke", rarity = "Epic", price = 900, colors = { Color3.fromRGB(125, 40, 215), Color3.fromRGB(38, 20, 60) }, style = "smoke" },
    { id = "golden_lightning", name = "Golden Lightning", rarity = "Legendary", price = 2200, colors = { Color3.fromRGB(255, 225, 70), Color3.fromRGB(255, 125, 20) }, style = "spark" },
    { id = "ice_crystal", name = "Ice Crystal", rarity = "Rare", price = 600, colors = { Color3.fromRGB(175, 245, 255), Color3.fromRGB(70, 165, 255) }, style = "crystal" },
    { id = "toxic_slime", name = "Toxic Slime", rarity = "Rare", price = 650, colors = { Color3.fromRGB(135, 255, 55), Color3.fromRGB(25, 175, 100) }, style = "droplet" },
    { id = "sakura_petals", name = "Sakura Petals", rarity = "Epic", price = 1300, colors = { Color3.fromRGB(255, 177, 219), Color3.fromRGB(246, 92, 161) }, style = "petal" },
    { id = "void_rift", name = "Void Rift", rarity = "Legendary", price = 2800, colors = { Color3.fromRGB(150, 75, 255), Color3.fromRGB(39, 11, 92) }, style = "void" },
    { id = "rgb_prism", name = "RGB Prism", rarity = "Mythic", price = 6500, colors = { Color3.fromRGB(255, 65, 180), Color3.fromRGB(45, 225, 255) }, style = "prism" },
}
Cosmetics.ById = {}
for _, def in ipairs(Cosmetics.List) do
    Cosmetics.ById[def.id] = def
end
return Cosmetics
