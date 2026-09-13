# CLAUDE.md

Guidance for AI assistants and contributors working in this repository.

## What this is

**[Shine] VoteRandom v2** is Shine's shuffle plugin (`voterandom`, by Person8880,
<https://github.com/Person8880/Shine>) copied under a new plugin name, `voterandomv2`, with per-team
commander skill blending added. It exists to test that change on live servers, as a step towards getting
it merged into Shine's own `voterandom`. `README.md` is the server-operator doc; this file is for
development.

The blending change itself is the upstream proposal on branch `per-team-commander-skill-blending` in the
sibling `Shine` clone (also exported as `0001-Allow-configuring-commander-skill-blending-per-team.patch`
in the workspace root). This repo is that code plus only what's needed to run it as a separate plugin.

It replaced an earlier approach, Shuffle Mk II (sibling repo `Shuffle-Mk-II`), which patched voterandom
at runtime instead of copying it.

## Layout

Standard NS2 Launch Pad project layout, matching the author's other mods. Launch Pad wrote
`mod.settings` and `preview.jpg` on first publish. Both are committed: `publish_id = 3801049022` in
`mod.settings` is what makes a republish update the same Workshop item.

```
mod.settings                                       Launch Pad publish settings (publish_id)
preview.jpg                                        Workshop preview image
source/lua/shine/extensions/voterandomv2/*.lua     the plugin (7 files, from voterandom)
source/locale/shine/extensions/voterandomv2/*.json translations (7 files, verbatim from voterandom)
test/votemenu_hook.lua                             standalone test for the vote menu hook, not shipped
output/                                            Launch Pad build output, gitignored
```

The build is `rm -rf output && mkdir -p output && cp -r source/. output/`. `output/` is gitignored and
does not follow branch switches, so rebuild before publishing.

## Every difference from Shine's voterandom is marked

Search for `VoteRandom v2` to find every change against Shine's `voterandom`. Keep that convention: it's
what makes this reviewable, and what lets the blending change be separated back out for Shine.

The first commit is an unmodified import (Shine develop + the blending branch), so
`git diff <first commit> -- source` shows exactly what running it separately required:

- `shared.lua`: header note; `DefaultState = false` (without it Shine never records the plugin in
  `ActiveExtensions` and re-loads it every map change).
- `server.lua`:
  - Header note.
  - `ConfigName = "VoteRandomV2.json"`.
  - `Conflicts.DisableUs = { "voterandom" }`: refuses to enable while Shine's voterandom is enabled,
    since both bind the same commands. It deliberately doesn't use `DisableThem`, which would switch off
    the operator's plugin for them.
  - `ModeError` text names this plugin.
  - The `IsExpectedFunction` path points at `voterandomv2/team_balance.lua`, so another mod replacing the
    algorithm is still detected.
  - `HookVoteMenu` / `UnhookVoteMenu` / `Cleanup`, called from `Initialise` (see below).
  - Two lines at the top of `sh_teamstats` output disclosing that v2 is running.

Changes to the blending feature itself are **not** marked `VoteRandom v2`, because they belong to the
upstream proposal rather than to running separately. So far that's one: `sh_teamstats` describes the
blend settings in plain words (`CommanderSkillBlendDescriptions`, one line per team, plus a note when
commander skills are disabled) instead of printing the raw config values. The upstream patch branch in
the `Shine` clone still has the older one-line wording; bring it in line before proposing it.

Deliberately **not** changed, to keep the diff small: commands and chat aliases (drop-in for players),
`PrintName`, `Version` (`2.13`, matching the upstream change), `RandomEndTimer` (plugin timers are
namespaced per plugin already), all balancing code.

Renaming is otherwise safe because Shine derives names from the plugin folder: `LoadPluginFile` uses
`PluginName`; network messages are `SH_<plugin name>_<message>`; locale sources are
`locale/shine/extensions/<plugin name>`. Map vote's end-of-map shuffle check receives the plugin that
started the vote, so it works with v2.

## Integrations that look voterandom up by name

Checked 2026-09-13 against Shine Workshop `117887554` and every mod on NS2 Sudamerica 8v8:

- **Shine's vote menu** (`core/server/votemenu.lua` `BuildPluginData`, client `votemenu_gui.lua`
  `PluginNames`) only shows Shuffle when a plugin named `voterandom` is enabled. **Server side fixed:**
  `HookVoteMenu` wraps `Shine.SendPluginData` and answers `IsExtensionEnabled( "voterandom" )` with this
  plugin *only for the duration of that call*. **Client side not yet fixed:** when building the Main page
  the client calls `IsExtensionEnabled( "voterandom" )` to get `GetVoteButtonText` /
  `OnVoteButtonCreated`, so on first draw the button lacks the team-preference label and, when
  `IsVoteForAutoShuffle`, reads the core "Shuffle" phrase instead of "Enable/Disable Shuffle" (the click
  is unaffected: it runs `sh_voterandom` either way). Later changes are fine: `NetworkUpdate` finds the
  button by label via `GetButtonByPlugin( "Shuffle" )` and rewrites text and tooltip itself. A global
  client alias was rejected: Shine's client config menu and plugin dependency checks ask the same
  question and would be misled. The clean fix, offered to the author on 2026-09-13 but not built, is
  Shine's own `Shine.VoteMenu:EditPage( "Main", ExtraPopulate )` from `client.lua`, applying v2's text,
  tooltip and `OnVoteButtonCreated` to the Shuffle side button. Note `GetButtonByPlugin` returns nil
  unless `ActivePage == "Main"`, so check that during populate or walk `Buttons.Side` directly.
- **Devnull - [Shine] Extras / enhancedscoreboard** (`2608952840`) reads
  `Shine.Plugins.voterandom:GetTeamStats()` when voterandom is enabled. With v2 it shows nothing. **Never
  make `IsExtensionEnabled( "voterandom" )` return true globally:** the scoreboard would then call
  Shine's *disabled* voterandom, which has no config loaded, and throw.
- **Shine-Lockteams / lockteamsv2** (the author's own): the *published* version (`3730361484`) doesn't
  reference voterandom at all. The unpublished auto-adjusting version in the repo uses
  `Shine.Plugins.voterandom` for skill when enabled, else its own calculation. The author decided not to
  change it for v2 for now, so it isn't listed as a limitation in `README.md`.
- Shine-Epsilon's `botmanager`, `disablevanillavotes`, `enforceteamsizes`, `hiveteamrestriction` only
  mention voterandom in comments / vanilla vote names.

## Keeping in step with Shine

The copy freezes Shine's voterandom as of the Workshop release `117887554`, which was identical to
Shine's `develop` on 2026-09-13. When Shine updates voterandom, merge those changes in, keeping the
`VoteRandom v2` markers. If Shine merges the blending change, this plugin is no longer needed.

## Testing

`luac -p` every file with a standalone Lua interpreter (Lua 5.4 locally, while NS2 runs LuaJIT/5.1, so
it's a syntax check only).

`lua test/votemenu_hook.lua` extracts `HookVoteMenu` / `UnhookVoteMenu` / `Cleanup` from the shipped
`server.lua` and runs them against a stubbed Shine: 14 checks, including that the `voterandom`
substitution never leaks outside the vote menu call, survives an error inside Shine's send, and is fully
undone by `Cleanup`. If you rename or restructure those functions, keep the harness's extraction working.

There is no standalone harness for the rest of the plugin: it needs Shine's runtime. The blending
arithmetic is the same code verified 12/12 in `Shuffle-Mk-II/test/blend.lua`.

A live test must cover: the conflict refusal while `voterandom` is enabled; the Shuffle button present in
the vote menu; `sh_teamstats` showing the v2 lines and blend modes; a real shuffle; disabling v2
mid-map (`sh_unloadplugin voterandomv2`) removing the button again.

## Client disconnects while not whitelisted

Until UWE fixes `core/lua/ConsistencyConfig.lua` (reported 2026-09-11, see
`UWE-Consistency-Report` in the workspace), mounting any non-whitelisted mod turns off consistency
checking. Players running a client mod that registers network messages (e.g. Devnull - Enhanced Hud) are
then kicked with "Invalid data". It isn't caused by this plugin's code, and the author chose not to work
around it in the mod or with server settings. Testers can disable such client mods.

## Credits wording

The Credits section of `README.md` was approved by the author on 2026-09-13. Don't change attribution
wording without asking.
