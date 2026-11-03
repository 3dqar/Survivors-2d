# Survivors 2D — Rojo v5

Roblox top-down multiplayer survivors prototype. **Max players: 10** (configure in Roblox Creator Hub).

## Setup

1. Download and extract the prepared `Survivors_Rojo_v5.zip` folder.
2. Copy all contents of the extracted folder into this repository clone.
3. From the project root, start `rojo serve default.project.json`.
4. In Roblox Studio, install the Rojo plugin and connect to localhost port 34872.
5. Check Output and test with multiple clients before publishing.

## Mapping
- `src/shared/SurvivorsShared` → `ReplicatedStorage/SurvivorsShared`
- `src/server/Survivors` → `ServerScriptService/Survivors`
- `src/client` → `StarterPlayer/StarterPlayerScripts`

**Important:** Existing manually inserted v4 scripts must be removed before syncing to avoid duplicated gameplay scripts. Keep your original Studio place backup. The actual gameplay scripts are distributed in the v5 ZIP and must be added to this repo before Rojo sync.

## Included in the ZIP
- Mage/Knight/Rogue, saved hero preference
- Weapons, chests, elite enemies, Elite Hunt
- Goals, daily challenges, HUD, mobile layouts
- Adaptive enemy counts for multiplayer

DataStore and sounds, animations and real 10-player performance have not been verified in Roblox Studio.
