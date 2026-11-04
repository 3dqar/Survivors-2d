# Cosmetics backend handoff (implemented by ChatGPT; static review only)

**Scope split**
- ChatGPT: cosmetics catalog, persistent ownership, secure purchase/equip actions, local lightweight Trail/ParticleEmitter renderer, preserving Supporter perks.
- Claude: 5 Chaos Events, polished 3D visuals/assets and **all UI screens** (including cosmetics shop/inventory). Do not rewrite cosmetics backend without locating a concrete issue.

## Existing code (already implemented)
- `src/shared/SurvivorsShared/Cosmetics.lua`: eight cosmetic definitions `List`, `ById`; `id`, `name`, `rarity`, `price`, `colors`, `style`.
- `src/server/Survivors/Persistence.lua`: cosmetics saved under existing `SurvivorsV2` user profile key as `cosmetics = { owned = { [id] = true }, equipped = id | nil }`. Existing profiles without cosmetics migrate to empty cosmetic inventories. Ownership is validated against the catalog on load.
- `src/server/Survivors/Meta.server.lua`: existing RemoteFunction accepts `(action, cosmeticId)`.
- `src/client/Cosmetics.client.lua`: local-only renderer observing each player’s replicated `CosmeticTrail` attribute; uses uniquely named attachments and `Trail`/`ParticleEmitter`, cleans up after respawn/leaving/re-equip. Existing Supporter RGB is unaffected.
- `src/server/Survivors/Support.server.lua`: **intentionally untouched**. Supporter tiers and product receipts are separate.

## Exact UI integration API

Existing server RemoteFunction `ReplicatedStorage.SurvivorsRemotes.Meta`:

```lua
-- Client-side pseudocode; use a guarded pcall and debounce just like existing menu.
local rf = game.ReplicatedStorage.SurvivorsRemotes.Meta
local state = rf:InvokeServer("state")
-- state.cosmetics = { owned = { blue_fire = true, ... }, equipped = "blue_fire" or "" }
local result = rf:InvokeServer("cosmeticBuy", "blue_fire")
local result = rf:InvokeServer("cosmeticEquip", "blue_fire")
local result = rf:InvokeServer("cosmeticUnequip")
-- Check result.ok, result.msg, result.coins, result.cosmetics
```

These operations currently obey existing **menu-only (dead/not in active run)** Meta permission policy; if Claude needs equip during run, design a separately rate-limited/safe cosmetic-only exception (no chest actions allowed while alive). This code does NOT automatically put new cosmetic inventory buttons into the current menu.

Cosmetics are coin-based and have NO attack/health/speed benefits. Server validates ID against catalog, validates ownership, deducts coins in memory then queues a profile save. On load failure, cosmetic purchases are blocked. `Persistence.grantCosmetic(player, id)` is an internal server API intended for future chest rewards; it must only be called after durable reward reservation/idempotence handling. Repeating an existing grant returns false.

The current new cosmetics are **not integrated into chest reward rolls**. Claude will integrate them into Classic / Chaos / Mythic chests as part of its chest milestone. Keep batch transactions crash-safe and old pending-chest semantics.

## Visual distinction

- Chest `rgb_prism`: local client neon prism trail, its own attachments, no nametag, slower hue cycle.
- Paid VIP: `SurvivorsRGBTrail` and `SurvivorsSupporterTag` owned by the existing supporter script. Do not rename, overwrite, or delete these.

## Static checks and manual playtest checklist

1. New profile gets `cosmetics.owned = {}`, nothing equipped; old save loads normally.
2. Valid cosmetic purchase spends the exact price once; second purchase rejected; invalid IDs rejected; insufficient coins rejected.
3. Equip requires owned ID; unequip clears attribute; rejoin restores equipped ID and ownership.
4. Respawn and player leave remove local attachments; switching cosmetics has no accumulated particles.
5. Tier-3 supporter RGB still exists when a chest RGB Prism is equipped.
6. FX visuals work on phone, watch FPS and battery.
7. Cannot purchase/equip in active run under current Meta policy; menu-only behavior intentional.
8. Verify save after disconnect / DataStore failure. Static review does not prove this; no Roblox Studio runtime test done.
9. Verify all UI requests use `pcall`, debounce and show server-provided error messages.

**Remaining risk**: The existing profile store uses a per-server serialized SetAsync without cross-session locking. True cross-server save consistency is a separate pre-release concern; these cosmetics do not introduce a second competing DataStore key or writer.
