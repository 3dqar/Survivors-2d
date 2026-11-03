# Survivors 2D — Rojo v5

Roblox 2D / top-down multiplayer survivors prototype. **10 players maximum** (set in Roblox Creator Hub / experience place settings: **Max Players = 10**; this limit is not set by Rojo scripts).

## Setup (Windows PowerShell)

1. Install **Rojo CLI** and the matching **Rojo Studio plugin**. Open or publish a Roblox Studio place. Save/backup the original place before connecting.
2. Extract this folder and run:
   ```powershell
   cd "C:\path\to\Survivors_Rojo_v5"
   rojo serve default.project.json
   ```
3. In Roblox Studio choose **Rojo > Connect** and localhost port **34872**, then **Sync**. Check that the Scripts/ModuleScripts are in the services listed below.
4. In Studio run **Test > Start Server** with multiple clients. Inspect **View > Output** for errors.
5. Publish the place, enable **Game Settings > Security > Enable Studio Access to API Services** only for Studio DataStore testing (avoid testing against production DataStores), and configure Max Players = 10 in Creator Hub.

## Rojo mapping

- `src/shared/SurvivorsShared/*.lua` → `ReplicatedStorage/SurvivorsShared/*` (ModuleScript)
- `src/server/Survivors/*.server.lua` → `ServerScriptService/Survivors/*` (Script)
- `src/server/Survivors/*.lua` → `ServerScriptService/Survivors/*` (ModuleScript)
- `src/client/*.client.lua` → `StarterPlayer/StarterPlayerScripts/*` (LocalScript)

In v4, `Game_server` / `Arena_server` / `Meta_server` are now named `Game` / `Arena` / `Meta` instances in Studio. They reference their siblings only by names `Grid`, `Fx`, `Persistence`, `Goals`, so renaming the script instances is safe. Delete the **old** manual v4 scripts before syncing to avoid double server loops and duplicate GUIs; do not delete the whole place unless intentional.

## Changes since v4

- Converted all scripts to Rojo-friendly `.server.lua`, `.client.lua` and module `.lua` file types.
- Added complete `default.project.json` and Git-ready folder layout.
- Added the last selected character preference to existing `SurvivorsV2` DataStore. On subsequent rounds/joins after a successful load, the saved hero is automatically selected; new players still select Mage / Knight / Rogue. If loading fails, hero choice is shown and data is not overwritten.
- Preserved enemy scaling, skills, Elite Hunt, chests, Goals, and mobile layouts from supplied v4.

## Constraints / not yet verified

- Roblox Studio/real phone/10 connected clients **not executed here**. Review Output and test touch controls, latency, DataStore save/load, chests and events before release.
- 3D model assets, animations, asset IDs and sounds were not replaced. Characters/enemies are simple parts and some sound IDs may not play.
- The current place has no in-game way to change a **saved** hero. To support hero switching, a character-selection menu setting would need to be added. The saved preference is intentionally automatic.
- No repository was created automatically; connect an existing or new GitHub repository and push these files.

## Upload to GitHub (first commit)

```powershell
git init
git add .
git commit -m "Set up Survivors v5 Rojo project"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git
git push -u origin main
```

If repository already exists, clone it first and copy the project files into that clone instead of running `git init` in an unrelated working folder.

## V6: lifetime records and death-only menu
- Local leaderstats: Total kills, Best kills (one run), Best level, Best (survival seconds), Coins.
- Global OrderedDataStores: SurvivorsBestV1 (survival), SurvivorsBestKillsV1, SurvivorsBestLevelV1, SurvivorsTotalKillsV1.
- The menu opens only after death and automatically closes on revival. Server validates menu actions.
- Publish the experience; for Studio testing enable Game Settings > Security > Enable Studio Access to API Services.
- These records start from the first run after v6 is installed; older unrecorded best-run kills cannot be reconstructed.
- Test the DataStore behavior in a published test experience before release.

## Support donations + VIP (50 / 100 / 1000 Robux)

**Use Developer Products, not Game Passes** (support can be purchased more than once).

1. Publish your Roblox experience.
2. Open [Creator Dashboard](https://create.roblox.com/dashboard/creations) → your experience → **Monetization → Developer Products**.
3. Create three products: Small Support (50 R$), Big Support (100 R$), Legend Support (1000 R$). Use a name, description, image, category and set the Robux price.
4. From each product's **⋯** menu click **Copy Asset ID**.
5. Paste those IDs in `src/shared/SurvivorsShared/SupportProducts.lua` by replacing each `id = 0`. Product ID is **not** its Robux price!
6. Run `rojo serve default.project.json` and connect Roblox Studio's Rojo plugin. Publish updates.
7. For Studio DataStore verification, enable **Game Settings → Security → Enable Studio Access to API Services** (do not use production data for destructive tests).

After any of the three confirmed purchases, `Support.server.lua` records permanent Supporter tier in `SurvivorsVIPV1` DataStore, shows an overhead VIP tag and animated RGB Trail. Robux are settled by Roblox; this script must be the **only** `MarketplaceService.ProcessReceipt` handler in the experience.

Menu Support tab appears only after death. Purchases use the official Roblox confirmation UI and must be tested in a published experience before release. Supporter tiers are cosmetic only, not pay-to-win.

## Supporter tiers (configured)

| Product | Product ID | Perk |
|---|---:|---|
| Small Support — 50 R$ | `3727986151` | Yellow **★ SUPPORTER ★** overhead title |
| Big Support — 100 R$ | `3727986181` | Animated RGB **★ SUPPORTER ★** overhead title |
| Legend Support — 1000 R$ | `3727986218` | Animated RGB **★ SUPPORTER ★** overhead title and RGB trail |

The player's highest purchased tier persists in `SurvivorsVIPV1` DataStore (`tier` key, with migration of prior `vip=true` records). Buying a lower tier never downgrades cosmetics. The Roblox experience must be published; verify purchases and data saving with test accounts.

## Pre-launch audit (2026-11-03)

Static GitHub code review completed; **Roblox Studio / public server runtime has NOT been tested by the reviewer**.

### Fixed in code
- Only players who pressed JOIN are included in end-of-run lifetime and global leaderboard records.
- Chest KEEP/SELL cannot be skipped by teammate revival or a new run; pending rewards survive until resolved.
- JOIN and restart wait for profile loading before spawning, so persisted pending rewards cannot be bypassed by the first frame.
- JOIN's in-flight loading counts as spawning, preventing multiplayer round-end races.
- Profile DataStore writes for a single player are serialized to reduce stale-write losses.
- No automatic game-over countdown; PLAY triggers a server-validated restart.
- Supporter Developer Products use IDs 3727986151, 3727986181, 3727986218.

### Required before advertising
1. In a **separate test experience** published to Roblox, enable Studio API Services only if you want live DataStore tests. Do not let destructive Studio tests write production records.
2. Test on desktop + mobile, at least 2 players: first JOIN, selecting hero and weapon, death, revive, GAME OVER -> MENU -> CS-style chest roulette -> KEEP and SELL, then PLAY.
3. Test that best kills, best level, total kills, best survival and coins survive rejoining, and global leaderboards refresh.
4. Run authorized purchase tests for all three Developer Products. Roblox receipt failures return NotProcessedYet and must be retried; verify Supporter tier 1 / 2 / 3 and rejoin.
5. Replace any invalid/inaccessible audio IDs. Previous Studio output reported `rbxassetid://203785492` (asset type mismatch) and `rbxassetid://1603813` (permission denied). Verify sequential music and separate FX volume on each device.
6. Confirm all linked product IDs belong to the **same Roblox experience** and check public experience permissions, title, thumbnail, genre, age/maturity settings and monetization policies.

Limitations: Volume settings persist for the current client session only. Direct runtime/monetization tests are still required for release confidence.
