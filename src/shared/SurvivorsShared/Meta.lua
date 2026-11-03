-- ReplicatedStorage/SurvivorsShared/Meta  (ModuleScript)
-- Nuolatiniai patobulinimai (skrynios) ir jų retumai.
local Meta = {}

Meta.ChestPrice = 120
Meta.MaxLevel = 10
Meta.Order = { "Vigor", "Power", "Swift", "Insight", "Mending", "Precision" }

Meta.Stats = {
	Vigor     = { key = "hp",    name = "Vigor",     per = 6,    text = "+6 max HP per level",       color = Color3.fromRGB(240, 120, 200) },
	Power     = { key = "dmg",   name = "Power",     per = 0.04, text = "+4% damage per level",      color = Color3.fromRGB(255, 140, 80) },
	Swift     = { key = "speed", name = "Swiftness", per = 0.03, text = "+3% move speed per level",  color = Color3.fromRGB(110, 220, 160) },
	Insight   = { key = "xp",    name = "Insight",   per = 0.05, text = "+5% XP per level",          color = Color3.fromRGB(100, 170, 255) },
	Mending   = { key = "regen", name = "Mending",   per = 0.2,  text = "+0.2 HP/s regen per level", color = Color3.fromRGB(235, 90, 110) },
	Precision = { key = "crit",  name = "Precision", per = 0.02, text = "+2% crit chance per level", color = Color3.fromRGB(255, 220, 90) },
}

-- w = svoris, lv = kiek lygių duoda, sell = kaina parduodant
Meta.Rarities = {
	{ name = "Common", w = 70, lv = 1, sell = 15, color = Color3.fromRGB(200, 205, 220) },
	{ name = "Rare", w = 25, lv = 1, sell = 40, color = Color3.fromRGB(90, 170, 255) },
	{ name = "Epic", w = 5, lv = 2, sell = 100, color = Color3.fromRGB(200, 120, 255) },
}

function Meta.roll(rng)
	local stat = Meta.Order[rng:NextInteger(1, #Meta.Order)]
	local total = 0
	for _, r in Meta.Rarities do
		total += r.w
	end
	local x = rng:NextNumber(0, total)
	for i, r in Meta.Rarities do
		x -= r.w
		if x <= 0 then
			return stat, i
		end
	end
	return stat, 1
end

return Meta
