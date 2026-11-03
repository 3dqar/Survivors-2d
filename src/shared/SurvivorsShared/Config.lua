-- ReplicatedStorage/SurvivorsShared/Config  (ModuleScript)
local Config = {}

Config.ArenaSize = 760   -- arenos kraštinė (studs), 10 žaidėjų
Config.Step = 1 / 30     -- serverio simuliacijos žingsnis

Config.BasePlayerHP = 100
Config.BaseWalkSpeed = 18
Config.ReviveSeconds = 12
Config.RestartDelay = 12
Config.OfferSeconds = 15

Config.CritChance = 0.1
Config.CritMult = 2
Config.XPShareOthers = 0.6
Config.BladeHitInterval = 0.35

Config.MaxEnemiesBase = 110      -- priešų limitas = Base + PerPlayer * žaidėjų, iki Cap
Config.MaxEnemiesPerPlayer = 16
Config.MaxEnemiesCap = 260
Config.MaxProjectiles = 100
Config.SpawnRingMin = 50
Config.SpawnRingMax = 64
Config.RecycleDistance = 120
Config.BossEvery = 120
Config.SwarmEvery = 75

local Block, Ball, Cyl = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local Neon, Smooth, Metal, Slate = Enum.Material.Neon, Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Slate
local V, C = Vector3.new, Color3.fromRGB

-- decos: papildomos dalys (dydis/pozicija kaip dalis nuo priešo size, rot laipsniais, spin rad/s)
Config.Enemies = {
	Grunt = { -- žalias gličas su švytinčiu "vizoriumi"
		hp = 12, speed = 7, dmg = 6, xp = 1, knock = 1, size = 2.4,
		shape = Block, material = Smooth, color = C(90, 190, 100), mesh = Enum.MeshType.Sphere,
		decos = {
			{ shape = Block, size = V(0.62, 0.16, 0.1), pos = V(0, 0.14, -0.46), rot = V(0, 0, 0), color = C(255, 245, 130), material = Neon },
		},
	},
	Runner = { -- švytintis kamuolys su besisukančia spygliuota šerdimi
		hp = 6, speed = 11, dmg = 4, xp = 1, knock = 1.3, size = 1.7,
		shape = Ball, material = Neon, color = C(255, 150, 50),
		decos = {
			{ shape = Block, size = V(0.8, 0.8, 0.8), pos = V(0, 0, 0), rot = V(45, 0, 45), color = C(255, 235, 140), material = Neon, spin = 9 },
		},
	},
	Brute = { -- violetinis šarvuotis su žiedu, raudonomis akimis ir sukamu krištolu
		hp = 55, speed = 5, dmg = 14, xp = 4, knock = 0.5, size = 3.8,
		shape = Block, material = Smooth, color = C(140, 80, 205), mesh = Enum.MeshType.Sphere,
		decos = {
			{ shape = Block, size = V(0.7, 0.16, 0.1), pos = V(0, 0.16, -0.47), rot = V(0, 0, 0), color = C(255, 70, 70), material = Neon },
			{ shape = Cyl, size = V(0.14, 1.35, 1.35), pos = V(0, 0, 0), rot = V(0, 0, 90), color = C(70, 45, 110), material = Metal },
			{ shape = Block, size = V(0.3, 0.3, 0.3), pos = V(0, 0.55, 0), rot = V(45, 45, 0), color = C(255, 120, 230), material = Neon, spin = 3 },
		},
	},
	Titan = { -- bosas: ragai, akys, du besisukantys žiedai
		hp = 500, speed = 6, dmg = 28, xp = 40, knock = 0.1, size = 10, boss = true,
		shape = Ball, material = Slate, color = C(120, 35, 45),
		decos = {
			{ shape = Block, size = V(0.7, 0.14, 0.1), pos = V(0, 0.15, -0.48), rot = V(0, 0, 0), color = C(255, 230, 90), material = Neon },
			{ shape = Cyl, size = V(0.05, 1.5, 1.5), pos = V(0, 0, 0), rot = V(0, 0, 90), color = C(255, 70, 70), material = Neon, spin = 1.5 },
			{ shape = Cyl, size = V(0.05, 1.3, 1.3), pos = V(0, 0, 0), rot = V(0, 0, 0), color = C(255, 150, 70), material = Neon, spin = 2.5 },
			{ shape = Block, size = V(0.14, 0.5, 0.14), pos = V(0.28, 0.52, 0), rot = V(0, 0, -25), color = C(235, 230, 215), material = Smooth },
			{ shape = Block, size = V(0.14, 0.5, 0.14), pos = V(-0.28, 0.52, 0), rot = V(0, 0, 25), color = C(235, 230, 215), material = Smooth },
		},
	},
}

Config.Enemies.Spitter = { -- šaulys: laikosi atstumu ir spjauna
	hp = 26, speed = 6, dmg = 6, xp = 3, knock = 0.8, size = 2.4,
	shape = Block, material = Smooth, color = C(60, 200, 190), mesh = Enum.MeshType.Sphere,
	ai = "ranged", range = 22, shotCd = 2.4, shotSpeed = 24, shotDmg = 9,
	decos = {
		{ shape = Block, size = V(0.62, 0.16, 0.1), pos = V(0, 0.14, -0.46), rot = V(0, 0, 0), color = C(255, 90, 200), material = Neon },
		{ shape = Block, size = V(0.22, 0.22, 0.5), pos = V(0, -0.1, -0.6), rot = V(0, 0, 0), color = C(40, 120, 120), material = Metal },
	},
}
Config.Enemies.Bomber = { -- sprogdintojas: bėga ir sprogsta šalia žaidėjo
	hp = 16, speed = 10, dmg = 4, xp = 2, knock = 1, size = 2,
	shape = Ball, material = Neon, color = C(255, 70, 40),
	ai = "bomber", boom = 8, boomDmg = 28,
	decos = {
		{ shape = Block, size = V(0.6, 0.6, 0.6), pos = V(0, 0, 0), rot = V(45, 0, 45), color = C(255, 230, 80), material = Neon, spin = 6 },
	},
}
Config.Enemies.Splitter = { -- skyla į du mažus
	hp = 70, speed = 5, dmg = 9, xp = 3, knock = 0.6, size = 3.2, split = true,
	shape = Block, material = Smooth, color = C(235, 120, 170), mesh = Enum.MeshType.Sphere,
	decos = {
		{ shape = Block, size = V(0.6, 0.16, 0.1), pos = V(0, 0.15, -0.47), rot = V(0, 0, 0), color = C(255, 240, 120), material = Neon },
		{ shape = Cyl, size = V(0.12, 1.25, 1.25), pos = V(0, 0, 0), rot = V(0, 0, 90), color = C(150, 60, 110), material = Metal },
	},
}
Config.Enemies.Mini = {
	hp = 8, speed = 9, dmg = 4, xp = 0.5, knock = 1.4, size = 1.3,
	shape = Ball, material = Neon, color = C(255, 160, 200),
}

-- veikėjai: parenkami žaidimo pradžioje (po to renkamas ginklas, o veikėjo firminis ginklas visada pasiūlomas)
Config.HeroOrder = { "Mage", "Knight", "Rogue" }
Config.Heroes = {
	Mage = { name = "Arcane Mage", weapon = "Bolt", color = C(120, 200, 255), dmg = 0.15, hp = -10, text = "+15% damage, -10 max HP. Signature weapon: Arcane Bolt." },
	Knight = { name = "Iron Knight", weapon = "Blades", color = C(255, 120, 150), hp = 40, regen = 0.5, speed = -0.05, text = "+40 max HP, +0.5 HP/s regen, -5% speed. Signature weapon: Orbit Blades." },
	Rogue = { name = "Shadow Rogue", weapon = "Chain", color = C(190, 150, 255), speed = 0.15, crit = 0.1, hp = -15, text = "+15% speed, +10% crit, -15 max HP. Signature weapon: Chain Lightning." },
}

-- skrynių kritimas: tikimybė nužudžius priešą (elitiniai krenta dažniau)
Config.ChestDropNormal = 0.0008
Config.ChestDropElite = 0.3
Config.ChestLife = 90         -- sekundės, kiek skrynia guli arenoje
Config.MaxChestDrops = 10
Config.ChestPickupRadius = 5

-- elitiniai priešai: didesni, stipresni, didesnis XP ir skrynios šansas
Config.EliteFirst = 150
Config.EliteEvery = 55
Config.MaxElites = 8
Config.EliteHpMult = 6
Config.EliteSize = 1.5

-- ikonos kortelėse (nebūtina): Config.Icons.Bolt = "rbxassetid://..." ; tuščia = spalvotas ženkliukas su raidėmis
Config.Icons = {}

-- žemėlapio įvykiai
Config.Events = { { name = "Meteor Shower", dur = 25 }, { name = "Blood Moon", dur = 30 }, { name = "XP Frenzy", dur = 25 }, { name = "Elite Hunt", dur = 30 } }
Config.EventFirst = 90
Config.EventGapMin = 100
Config.EventGapMax = 140

-- garsai (galite pakeisti į savo rbxassetid://...; tuščias = be garso)
Config.Sounds = {
	kill = "rbxasset://sounds/snap.mp3",
	crit = "rbxasset://sounds/electronicpingshort.wav",
	nova = "rbxasset://sounds/impact_water.mp3",
	chain = "rbxasset://sounds/electronicpingshort.wav",
	levelup = "rbxasset://sounds/victory.wav",
	alert = "rbxasset://sounds/bass.mp3",
	warn = "rbxasset://sounds/switch.wav",
	hurt = "rbxasset://sounds/uuhhh.mp3",
	chest = "rbxasset://sounds/victory.wav",
	click = "rbxasset://sounds/button.wav",
	shot = "rbxasset://sounds/electronicpingshort.wav", -- bolt'ų šūvis
	blade = "rbxasset://sounds/snap.mp3",                 -- peilių smūgis
	drop = "rbxasset://sounds/switch.wav",                -- skrynia nukrito
	pickup = "rbxasset://sounds/victory.wav",             -- skrynia pasiimta
}

-- XP, reikalingas pasiekti kitą lygį
function Config.xpNeeded(level)
	return math.floor(6 + 4 * level + 0.35 * level * level)
end

return Config
