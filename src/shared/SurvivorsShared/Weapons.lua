-- ReplicatedStorage/SurvivorsShared/Weapons  (ModuleScript)
local Defs = {}

Defs.WeaponOrder = { "Bolt", "Blades", "Nova", "Chain", "Meteor", "Inferno" }
Defs.AllWeapons = { "Bolt", "Blades", "Nova", "Chain", "Meteor", "Inferno", "Stormbolt", "Bladestorm", "Blizzard", "Thunder", "Starfall", "Hellfire" }
Defs.PassiveOrder = { "Might", "Haste", "Boots", "Recovery", "Wisdom", "Vitality" }

-- evoliucija: ginklas max lygio + turimas pasyvas (bent 1 lygio) -> galingesnė forma
Defs.Evolutions = {
	Bolt = { to = "Stormbolt", need = "Haste" },
	Blades = { to = "Bladestorm", need = "Might" },
	Nova = { to = "Blizzard", need = "Vitality" },
	Chain = { to = "Thunder", need = "Boots" },
	Meteor = { to = "Starfall", need = "Wisdom" },
	Inferno = { to = "Hellfire", need = "Recovery" },
}

-- kiekvienas lygis paveldi ankstesnio reikšmes, keičiami tik nurodyti laukai
local function build(first, steps)
	local levels = { first }
	for i, s in steps do
		local L = table.clone(levels[i])
		for k, v in s do
			L[k] = v
		end
		levels[i + 1] = L
	end
	return levels
end

local function evolved(name, color, level)
	return { name = name, color = color, evolved = true, levels = { level } }
end

Defs.Weapons = {
	Bolt = {
		name = "Arcane Bolt", color = Color3.fromRGB(120, 200, 255),
		levels = build(
			{ cd = 0.7, dmg = 12, count = 1, speed = 65, pierce = 0, range = 55, note = "Fires a bolt at the nearest enemy." },
			{
				{ count = 2, note = "+1 bolt." },
				{ cd = 0.55, note = "Fires faster." },
				{ pierce = 1, dmg = 15, note = "Pierces 1 enemy, more damage." },
				{ count = 3, note = "+1 bolt." },
				{ pierce = 2, dmg = 20, cd = 0.42, note = "Pierces 2, more damage, faster." },
			}
		),
	},
	Blades = {
		name = "Orbit Blades", color = Color3.fromRGB(255, 120, 150),
		levels = build(
			{ count = 2, radius = 7, speed = 3.2, dmg = 8, note = "2 blades orbit around you." },
			{
				{ count = 3, note = "+1 blade." },
				{ dmg = 11, radius = 8, note = "More damage, wider orbit." },
				{ count = 4, note = "+1 blade." },
				{ speed = 4.2, dmg = 14, note = "Spins faster, more damage." },
				{ count = 5, radius = 9, dmg = 18, note = "+1 blade, wider, stronger." },
			}
		),
	},
	Nova = {
		name = "Frost Nova", color = Color3.fromRGB(150, 235, 255),
		levels = build(
			{ cd = 3, radius = 12, dmg = 18, note = "Shockwave around you that knocks enemies back." },
			{
				{ radius = 14, note = "Larger radius." },
				{ cd = 2.5, dmg = 24, note = "Faster and stronger." },
				{ radius = 17, note = "Even larger radius." },
				{ cd = 2, dmg = 32, note = "Faster and much stronger." },
				{ cd = 1.6, radius = 20, dmg = 42, note = "Maximum power." },
			}
		),
	},
	Chain = {
		name = "Chain Lightning", color = Color3.fromRGB(190, 150, 255),
		levels = build(
			{ cd = 1.6, range = 40, jumps = 3, dmg = 22, note = "Lightning arcs between 3 enemies." },
			{
				{ jumps = 4, note = "+1 jump." },
				{ dmg = 28, cd = 1.4, note = "More damage, faster." },
				{ jumps = 6, note = "+2 jumps." },
				{ dmg = 36, range = 48, note = "More damage and range." },
				{ jumps = 8, cd = 1.1, dmg = 42, note = "8 jumps, strongest bolt." },
			}
		),
	},
	Meteor = {
		name = "Meteor Strike", color = Color3.fromRGB(255, 150, 60),
		levels = build(
			{ cd = 3.2, count = 1, radius = 7, dmg = 40, range = 45, note = "Calls a meteor down on a nearby enemy." },
			{
				{ count = 2, note = "+1 meteor." },
				{ dmg = 55, radius = 8, note = "Bigger and stronger." },
				{ cd = 2.6, count = 3, note = "+1 meteor, faster." },
				{ dmg = 75, radius = 9, note = "Bigger and stronger." },
				{ count = 4, cd = 2.2, dmg = 90, note = "4 meteors, massive damage." },
			}
		),
	},
	Inferno = {
		name = "Inferno Aura", color = Color3.fromRGB(255, 90, 40),
		levels = build(
			{ cd = 0.5, radius = 9, dmg = 6, note = "Burning aura hurts nearby enemies." },
			{
				{ radius = 10.5, note = "Larger aura." },
				{ dmg = 9, note = "Burns harder." },
				{ radius = 12, note = "Larger aura." },
				{ dmg = 13, cd = 0.4, note = "Burns much harder, faster." },
				{ radius = 14, dmg = 18, note = "Maximum heat." },
			}
		),
	},
	Stormbolt = evolved("Storm Bolt", Color3.fromRGB(90, 160, 255), { cd = 0.35, dmg = 26, count = 5, speed = 80, pierce = 3, range = 60, note = "EVOLVED: a storm of piercing bolts." }),
	Bladestorm = evolved("Blade Storm", Color3.fromRGB(255, 80, 120), { count = 8, radius = 11, speed = 5, dmg = 26, note = "EVOLVED: a whirlwind of blades." }),
	Blizzard = evolved("Blizzard", Color3.fromRGB(190, 245, 255), { cd = 1.1, radius = 26, dmg = 65, note = "EVOLVED: a huge freezing wave." }),
	Thunder = evolved("Thunderstorm", Color3.fromRGB(220, 180, 255), { cd = 0.8, range = 60, jumps = 12, dmg = 60, note = "EVOLVED: lightning chains through the horde." }),
	Starfall = evolved("Starfall", Color3.fromRGB(255, 190, 90), { cd = 1.6, count = 6, radius = 11, dmg = 110, range = 55, note = "EVOLVED: a rain of meteors." }),
	Hellfire = evolved("Hellfire", Color3.fromRGB(255, 60, 30), { cd = 0.35, radius = 17, dmg = 24, note = "EVOLVED: a raging firestorm around you." }),
}

for _, d in Defs.Weapons do
	d.max = #d.levels
	d.notes = {}
	for i, L in d.levels do
		d.notes[i] = L.note
	end
end

Defs.Passives = {
	Might    = { name = "Might",       color = Color3.fromRGB(255, 140, 80),  max = 5, per = 0.15, blurb = "+15% damage per level." },
	Haste    = { name = "Haste",       color = Color3.fromRGB(255, 220, 90),  max = 5, per = 0.08, blurb = "-8% weapon cooldowns per level." },
	Boots    = { name = "Swift Boots", color = Color3.fromRGB(110, 220, 160), max = 5, per = 0.08, blurb = "+8% move speed per level." },
	Recovery = { name = "Recovery",    color = Color3.fromRGB(235, 90, 110),  max = 5, per = 0.5,  blurb = "+0.5 HP regen per second per level." },
	Wisdom   = { name = "Wisdom",      color = Color3.fromRGB(100, 170, 255), max = 5, per = 0.15, blurb = "+15% XP gained per level." },
	Vitality = { name = "Vitality",    color = Color3.fromRGB(240, 120, 200), max = 5, per = 20,   blurb = "+20 max HP per level." },
}

return Defs
