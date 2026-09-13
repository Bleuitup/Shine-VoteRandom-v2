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

1. Subscribe to the mod on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3801049022)
   and add its Workshop ID, `3801049022`, to the `mods` list in your `MapCycle.json`.
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

## Shuffle skill log

Every Hive skill shuffle writes the numbers it used to the server log, since the scoreboard doesn't show
them. For each team it logs the average skill, the standard deviation and every player's skill value.
For commanders it also logs their commander skill, field skill and blend. It ends with the difference
between the two team averages:

```
[Info] Shuffle skill log. Team skills are enabled. Commander skills are enabled.
[Info] Marines: 3 players, 2 counted. Average skill 1800, standard deviation 200.
[Info]     MarineComm[1001]: 2000 (commander: commander skill 2000, field skill 1300, blend: average of commander and field skill, only when field skill is higher)
[Info]     MarineA[1002]: 1600
[Info]     Bot[1003]: no skill value (bot), not counted.
[Info] Aliens: 2 players, 2 counted. Average skill 1500, standard deviation 550.
[Info]     AlienComm[1004]: 2050 (commander: commander skill 1600, field skill 2500, blend: average of commander and field skill)
[Info]     AlienB[1005]: 950
[Info] Difference between team averages: 300.
```

The values are the exact numbers the shuffle compared, including each team's skill adjustment when team
skills are enabled. Bots have no skill value and don't count toward the averages.

To turn the log off, run `sh_setloglevel voterandomv2 WARN` in the server console, or set `"LogLevel"` to
`"WARN"` in `VoteRandomV2.json`. That also hides this plugin's other informational messages.

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

Experimental. v0.9 is published to the Steam Workshop as `3801049022`, and its first live test is
still to come.

## Credits

VoteRandom v2 is Shine's shuffle plugin (`voterandom`), by Person8880, from
[Shine](https://github.com/Person8880/Shine), with per-team commander skill blending added. The team
balancing is entirely Person8880's work.
