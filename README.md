# [Shine] VoteRandom v2

A version of Shine's shuffle plugin (`voterandom`) with more control over how a **commander's skill** is
counted when teams are shuffled. It's a test version of a change intended for Shine itself: once the
change has been proven on live servers, the goal is for Shine's own shuffle plugin to include it.

It replaces Shine's shuffle rather than adding to it. Players use the same commands as before
(`!shuffle`, `!voterandom` and so on), and everything else about the shuffle works the same.

## What's different

Shine's shuffle has one commander option, `BlendAlienCommanderAndFieldSkills`. It averages an **alien**
commander's commander skill with their field skill, to account for commanders who leave the hive to
fight. It has two limits:

- It only works for aliens, though marine commanders leave the chair too.
- An average cuts both ways. A player who commands well but rarely leaves the chair gets rated *below*
  their commander skill, because their weaker field skill drags the average down.

VoteRandom v2 replaces that option with one setting per team, each with three choices:

| Choice | What it does |
| --- | --- |
| `COMMANDER_ONLY` | Uses the commander skill as-is. The same as Shine with blending off. |
| `AVERAGE` | The midpoint of commander and field skill. Shine's existing alien blending, now for marines too. |
| `AVERAGE_IF_FIELD_SKILL_HIGHER` | The midpoint only when the field skill is higher. Otherwise the commander skill as-is, so a strong commander is never dragged down. |

## Installing

1. Subscribe to the mod and add its Workshop ID to the `mods` list in your `MapCycle.json`.
2. In Shine's `BaseConfig.json`, under `ActiveExtensions`, **disable Shine's shuffle and enable this one**:
   ```json
   "voterandom": false,
   "voterandomv2": true
   ```
   VoteRandom v2 refuses to start while `voterandom` is enabled, because both use the same commands.
3. Optional: to keep your current shuffle settings, copy `config://shine/plugins/VoteRandom.json` to
   `VoteRandomV2.json` in the same folder before the next map change. Your old alien blending setting
   is converted automatically.
4. Change map.

To go back to Shine's shuffle, reverse step 2.

## Settings

Settings live in `config://shine/plugins/VoteRandomV2.json`. Everything Shine's shuffle offers is still
there. The new settings are under `BalanceModeConfig` → `HIVE`:

```json
"MarineCommanderSkillBlend": "COMMANDER_ONLY",
"AlienCommanderSkillBlend": "COMMANDER_ONLY"
```

Both default to `COMMANDER_ONLY`, so with default settings the shuffle behaves like Shine's. They only
matter when `BalanceMode` is `HIVE` and `UseCommanderSkill` is on.

## Transparency

`sh_teamstats` says that VoteRandom v2 is running instead of Shine's shuffle, and shows which blending
choice each team uses. Please don't remove that: players should be able to tell that the shuffle differs
from Shine's own, and where to report problems.

## Known limitations

- **Vote menu button.** The Shuffle button in the vote menu works exactly as with Shine's shuffle, but
  when the menu opens it doesn't show the player's team preference next to it. On servers that
  auto-shuffle every round, it also first reads "Shuffle" instead of "Enable Shuffle" or "Disable
  Shuffle", even though clicking it votes to turn automatic shuffling on or off for the next round.
- **Devnull's Enhanced Scoreboard** reads team skill from Shine's shuffle plugin by name, so its team
  skill figures won't show while VoteRandom v2 is running.
- **Not yet whitelisted.** While any non-whitelisted mod is mounted, NS2 stops checking players' client
  mods, and players running a client mod that registers network messages (for example Devnull's Enhanced
  Hud) get disconnected with "Invalid data". This is an NS2 bug, reported to UWE, and affects any
  non-whitelisted mod. Until it's fixed, affected players can disable that client mod.

## Status

Experimental, and not yet tested in a live round.

## Credits

VoteRandom v2 is Shine's shuffle plugin (`voterandom`), by Person8880, from
[Shine](https://github.com/Person8880/Shine), with per-team commander skill blending added. The team
balancing is entirely Person8880's work.
