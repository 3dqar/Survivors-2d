# NEON HORDE SURVIVORS — CLAUDE MAJOR UPDATE TASK

> **READ THIS FILE FIRST.** You are working on the existing Roblox Rojo project. This is an implementation brief, NOT a request to start a new game.
>
> Repo: `3dqar/Survivors-2d` (main)
> Existing experience: Neon Horde Survivors
> Preserve working save data, premium supporter privileges, hero choice, weapons, existing chest inventory, existing game-over flow, and current gameplay.

## Mission

Make the game significantly more fun to play over multiple days. Ship five **random temporary Chaos Events**, dramatically better chest opening / cosmetics, and meaningful return-to-game progression. Focus on tight gameplay and beautiful **procedural VFX/UI**, not low-quality decorative block models. Target Windows and mobile (including iPhone).

**Implement real changes in source files. Do not respond with a plan only.** Work in stable milestones; do not leave half-finished systems connected to the live game.

## Source architecture to inspect before editing

- `src/server/Survivors/Game.server.lua`: joined/run lifecycle, enemy AI, damage, combat, bosses, death/restart.
- `src/server/Survivors/Persistence.lua`: profiles, chest purchases, unresolved pending rewards, DataStores.
- `src/server/Survivors/Meta.server.lua`: chest state/open/keep/sell/buy server actions.
- `src/server/Survivors/Support.server.lua`: supporter product receipts and VIP RGB nametag/trail.
- `src/server/Survivors/Music.server.lua`: music playback; preserve.
- `src/client/HUD.client.lua`: game HUD, hero/weapon selection, end-of-run.
- `src/client/Menu.client.lua`: chest roulette, inventory, Support, Settings.
- `src/client/World.client.lua`: world camera, effects, SFX.
- `src/shared/SurvivorsShared/{Config,Weapons,Meta,SupportProducts,AudioSettings}.lua`.
- `default.project.json`: Rojo mappings.

Use actual code signatures and game state; do not guess. Consult other modules only as needed.

## Critical invariants — do not break

1. Player joins the run explicitly with JOIN/PLAY, and after death sees end-of-run UI and can return to MENU. No forced automatic restart.
2. Rewards/chest operations involving an unresolved `pending` result block gameplay entry until KEEP/SELL resolves. Maintain migration compatibility with existing saved profiles.
3. Existing Supporter developer products and receipt handling are **permanent paid entitlements**. Keep the existing IDs and the single authoritative `MarketplaceService.ProcessReceipt` owner. Never invent new product IDs.
4. Avoid old bugs: only players who actually joined are recorded for the run; late joiners have correct survival time; save operations are serialized and loaded before run starts.
5. The server decides damage, item grants, chest contents, spending, and kills. Client controls visual representation only. No duplicate payments or awards on spam/reconnection.
6. Bosses, enemies, normal weapons, level-ups, stats, gold, DataStore, supporter effects, phone controls, music/settings must remain functional.
7. No real Roblox Studio execution is available unless you actually run it. Say `implemented (untested)`, not `fully working`, until verified.

---

# MILESTONE 1 — FIVE RANDOM CHAOS EVENTS (FIRST PRIORITY)

Build a cohesive data-driven `ChaosEventService` server module and matching lightweight client VFX/controller (module names are suggestions, honor repository conventions).

**Scheduling**
- Runs only for players actively in a run, not in MENU, choosing chest results, or dead.
- First event after a randomized 120–180 seconds **of that player's active play**.
- Subsequent events every randomized 180–300 seconds **after the prior event finishes**.
- One transformation per player at a time. Favor a different event than the previous one.
- Telegraph for 5 seconds with clear UI, then transform for 25–30 seconds.
- Event scheduling must survive player joins/leaves and cancellation. Each participant can receive their own events; do not forcibly pause an entire multiplayer server.
- Implement clean cancellation for death, player leaves, character resets, and round transitions. Do not leave buffs, invulnerability, damage reductions, visuals, or attack loops behind.
- Suspend **normal automatic weapon damage and normal weapon VFX** while active, but preserve all levels/cooldowns/upgrades and restore precisely afterwards.
- Do not destroy or overwrite any owned weapons to create event visuals.
- Provide one event banner, clock, and simple readable mobile HUD; use 5 unique color themes.
- Keep boss rewards/kill counts fair. Avoid denying kills or XP unnecessarily.

## 1. SENSEI MODE (30 seconds)
- Character receives a visually distinct katana (use reusable procedural blade/VFX, not a crude pile of Parts); rapid close-range slashes, occasional 360-degree area slash and final cinematic slash.
- White/cyan arcs via Beams/Trails/Tween/Particles, sensible mobile budgets.
- Bosses become *afraid* and temporarily move away from the Sensei, while remaining killable, and return to normal AI afterwards.
- Server-side hit detection and bounded damage. Avoid permanent enemy path or AI corruption.

## 2. BOXING TORNADO (30 seconds)
- Two boxing gloves or stylized fists, smoothly spinning aura with radial wind.
- Invulnerable to enemy damage during the event (and only during it).
- Frequent close-range damage to enemies; ordinary mobs can be knocked back; bosses have capped knockback.
- Increase visual spin intensity with hits (without frantic camera spin).
- Finish with a strong radial slam and clear all invulnerability flags.

## 3. AWP GOD MODE (30 seconds)
- Temporary sniper weapon, cool muzzle flashes and precise piercing bullet tracers.
- Shoot roughly once per second, 30 shots across 30 seconds.
- Fire along aim/target direction; server confirms enemy intersections, **pierces every regular enemy in a straight line**, with strong but capped boss damage. Avoid expensive unlimited ray scanning.
- Player takes 50% less enemy damage during event.
- Camera/FX should not block the mobile view. Restore all normal weapons at the end.
- Do not damage players.

## 4. THUNDER GOD (25 seconds)
- Electric aura, chain-lightning with limited short-lived beams.
- Approximately one main strike per second, chaining up to 5–10 enemies.
- +40% movement speed; radial pulse every 5 sec; final lightning burst.
- Use caps and efficient target searches; no per-enemy particle spam.

## 5. GIANT RAMPAGE (25 seconds)
- Visibly larger player, dramatic footsteps, stomp AoE, controlled damage and knockback.
- Temporary protection/HP, reduced walk speed. Do not permanently modify maximum health.
- Ensure top-down camera, collisions, R6/R15 handling, player hitbox, and revert are safe.
- If scaling actual avatar is unsafe, implement a polished reversible **visual-only giant** illusion while leaving authoritative hitbox consistent; explain this choice.

**Event balancing**
- Do not trivialize late-game bosses, XP, health or economy. Configure event damage multipliers centrally.
- Ensure it remains fun and fair for early-game and late-game runs.
- Add server-driven event summary and event participation tracking suitable for later mastery.

# MILESTONE 2 — CHEST SYSTEM (PRESERVE DATA)

Introduce:
- `Classic Chest`: current baseline rewards, basic cosmetic trails.
- `Chaos Chest`: event-inspired cosmetic trails, aura/kill effect items.
- `Mythic Chest`: rare animated cosmetics, including exclusive RGB Prism (NOT the supporter RGB).
- Clear prices/probabilities displayed before buy/open; non-pay-to-win by default.
- Inventory/cosmetic reward definitions have stable IDs and versioned persistence.
- Preserve and migrate existing chest ownership, pending rewards, KEEP/SELL, purchases, and balances. DO NOT reset old data.
- Open ×1 or ×5. With ×5, five **independent synchronized horizontal roulette tracks**, each landing on the exact preselected server result. Mobile-friendly layout.
- Spend five chests atomically, or define a precise all-or-nothing protocol, then reserve five rewards durably; disconnect/close UI cannot consume the items without granting rewards.
- Prevent repeat credits/reopening/duplicate requests; maintain idempotency, including retry/reconnect/failed saves. Never assume DataStore transactions across multiple keys are atomic.
- Existing `pending` behavior must not allow entering gameplay while outstanding rewards need resolution.
- If safe ×5 cannot be guaranteed in one milestone, ship safe ×1 + persistent batch state first; do not fake it with five insecure API calls.

# MILESTONE 3 — COSMETICS / TRAILS

Create an inventory, preview, equip, unequip, and save system for:
- Blue Fire (Rare)
- Shadow Smoke (Epic)
- Golden Lightning (Legendary)
- Ice Crystal (Rare/Epic)
- Toxic Slime (Rare)
- Sakura Petals (Epic)
- Void Rift (Legendary)
- RGB Prism (Mythic)

Use attachments + built-in `Trail`, `ParticleEmitter`, `Beam` and other native effects. Avoid unapproved external asset IDs; no heavy 3D mesh requirements. Keep effect budget low on weak iPhones, avoid GPU overload. Support R6/R15, clean up on death/respawn, honor Settings FX slider.

**Do not override or copy paid supporter effects.** Existing VIP tiers, supporter RGB name and legendary RGB trail remain unique and functional. Chest RGB Prism must use its own geometry/colors and a separate optional attachment. Supporter players can equip a cosmetic simultaneously with VIP perks without collisions/overwriting effects.

No movement, attack, health or XP advantage from cosmetic rewards.

# MILESTONE 4 — RETURNING PLAYERS

- Three UTC daily quests with clear claim flow, one-time grants and persistent resets.
- Event Mastery per event: participation and goals, cosmetic-only rewards.
- Five-event collection tracker and a distinctive completion reward.
- Lifetime achievements: 1k/10k/100k kills; 15/30 min survival; boss kills; 100 chests.
- All rewards must have duplicate-claim protection; update existing DataStore safely, not replace old profile.
- Add at least one interesting long-term goal achievable without paying Robux.
- Avoid intrusive daily login pressure, autoplay claims, or pay-to-win.

# MILESTONE 5 — VISUAL POLISH, MOBILE, TESTING

- Polished neon arcade effects and UI (smooth tweens, readable color/rarity, well spaced); avoid spammy screen shake.
- Mobile portrait/landscape scaling, iPhone safe areas, touch size, proper navigation and close/back actions.
- FPS-friendly configurable particle counts, pooled short effects, rate-limited spatial searches, no unbounded Heartbeat scanning or runaway coroutines.
- Audio hooks with user-provided approved IDs only; don't invent Roblox asset IDs.
- Test plan: joined/not joined, death during each event, reconnect mid-reward, batch open, concurrent clients, boss fear restore, invulnerability end, VIP purchases, old save migration, mobile HUD, 10-player performance.
- Add a `docs/IMPLEMENTATION_STATUS.md` that tracks `implemented / static-checked / Roblox-tested / blocked`.

---

## Strict engineering and token rules

- **Quality first.** Don't skip validation or safeguards to save tokens. Save tokens on verbose status messages, redundant summaries, and rereading unrelated files.
- Read the *actual* current GitHub files once, plan the smallest safe related changes, edit incrementally.
- Finish one coherent milestone before starting the next. If near free-plan limit, save stable code and document next steps.
- Make minimal diffs and avoid needless rewrites. Keep existing scripts, paths and naming where possible.
- If you have GitHub access, commit changed files to the existing repository; otherwise provide complete updated Rojo ZIP. Do not claim changes exist unless actually saved.
- Document any asset / Studio-only dependencies honestly. No fabricated IDs, no fabricated runtime validation.
- Give short progress reports: what files changed, known issues, which milestone is next.
- Make sure Luau syntax and remote signatures align with the actual project.

## FIRST ACTION NOW

1. Inspect the existing `Game.server.lua`, `HUD.client.lua`, `World.client.lua`, `Persistence.lua`, `Meta.server.lua`, `Menu.client.lua` and shared config.
2. Identify the exact points to suspend normal weapons and apply / remove temporary combat damage modifiers.
3. Implement milestone 1 **five Chaos Events** with nice reusable VFX and mobile-friendly timing UI.
4. Add `docs/IMPLEMENTATION_STATUS.md`, preserving a clear list of future milestones.
5. Save actual changed source files and finish milestone 1 as far as safely possible before the free-plan limit.
