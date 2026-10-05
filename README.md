# lmao.tcl

**Channel management for eggdrop, built for UnderNet.**

[![Version](https://img.shields.io/badge/version-6.6.0-orange.svg)](https://github.com/lmao-tcl/lmao)
[![Eggdrop](https://img.shields.io/badge/eggdrop-1.8%2B-green.svg)](https://www.eggheads.org/)
[![Tcl](https://img.shields.io/badge/tcl-8.5%2B-blue.svg)](https://www.tcl.tk/)
[![License](https://img.shields.io/badge/license-GPLv3-lightgrey.svg)](LICENSE)

📖 **Full documentation: [lmao-tcl.github.io](https://lmao-tcl.github.io/)**

One script that gives your eggdrop the public commands people actually expect in a
channel — ops, bans, topic, user management — plus an auto-voice system for regulars
and idle cleanup for ops and voices. Every reply comes back as a **notice**, so the
bot never floods your channel.

---

## Highlights

- **No channel spam.** Every command reply is a notice to the user who asked. The bot
  only speaks in the channel when you explicitly tell it to (`!say`, `!act`, `!global`)
  — and in the ops channel, where the audit trail is a normal message everyone can read.
- **One help table.** `!help` and `/msg <bot> help` share a single source of truth, so
  documentation can't drift away from the commands.
- **Per-channel modules.** Turn features on and off per channel with `!enable` /
  `!disable`, without touching the config or reloading anything.
- **Real access levels.** Voice, Mod, Op, Master, Owner — one rung at a time, modes follow
  the level, and you can only reach below yourself.
- **Self-registration.** `/msg <bot> register` adds someone to the userfile behind a
  typed-back confirmation code, re-checks every condition before saving, and tells them to
  auth with X and set `+x` first so a hidden host gets stored instead of an ISP one.
- **One audit trail.** The `chanlog` module sends access changes, sanctions, registrations,
  denied attempts and bot control to an ops channel of your choosing, per channel.
- **ActiveVoice.** Voices people who actually talk, and takes it back when they go idle.
  Registered regulars (`+n`, `+m`, `+M`, `+v`) are never touched.
- **Flag protection.** `+n` and `+m` users and service bots (`X`, `W`) can't be
  deopped, devoiced, kicked or banned by the bot. A named exempt list covers the
  people who run the channel even when they aren't in the userfile.
- **No colour codes.** Plain text reads the same in every client and on every theme.
- **UnderNet aware.** Written against ircu behaviour and the `X` service.

---

## Install

```sh
cd ~/eggdrop/scripts
wget https://raw.githubusercontent.com/lmao-tcl/lmao/master/lmao.tcl
```

Add it to your `eggdrop.conf`:

```tcl
source scripts/lmao.tcl
```

Then `.rehash` on the partyline. You should see:

```
[lmao.tcl 6.6.0] - Complete production ready version
Loaded successfully - ready to serve!
```

---

## Configure

Everything lives in the `CONFIGURATION SECTION` at the top of the script.

| Setting | Default | What it does |
| --- | --- | --- |
| `cc(cmdchar)` | `!` | Command trigger character |
| `cc(mainchan)` | `#mainchan` | Main public channel |
| `cc(backchan)` | `#secretchan` | Ops channel that `!ops` alerts |
| `cc(backmode)` | `+snt` | Modes for the back channel |
| `cc(away_enabled)` | `0` | Set the bot away with `cc(away_message)` on connect and rehash |
| `cc(away_message)` | text | The default away message |
| `cc(away_file)` | `lmao-away.txt` | Where `!away` / `!back` are saved so they survive reboots |
| `cc(idledeop_enabled)` | `1` | Master switch for idle deop (the module still starts off per channel) |
| `cc(idledeop_default_minutes)` | `180` | Minutes before an idle op is deopped |
| `cc(idledeop_check_interval)` | `5` | Seconds between idle-deop sweeps |
| `cc(activevoice_idle_minutes)` | `180` | Minutes before an idle voice is removed |
| `cc(activevoice_check_interval)` | `10` | Seconds between devoice sweeps |
| `cc(access_welcome_delay)` | `3` | Seconds between queued welcome notices |
| `cc(activevoice_exempt_flags)` | `n m M v` | Flags that make a user invisible to ActiveVoice |
| `cc(protected_bots)` | `X W` | Nicks the bot will never deop |
| `cc(protected_flags)` | `n m` | Flags that protect a user from deop/devoice |
| `cc(deop_exempt)` | `Secoupe Seb offline` | Nicks or handles the idle-deop sweep never touches |

---

## Modules

Modules are per channel. Three start **on**; `idledeop` and `idledevoice` start **off**.

| Module | Default | What it does |
| --- | --- | --- |
| `topic` | on | `!topic` / `!topicsync` — stores the topic and re-applies it when it drifts |
| `activevoice` | on | Auto-voices non-registered users when they talk, and tracks their activity |
| `idledevoice` | **off** | Removes voice from non-registered users who have gone idle |
| `idledeop` | **off** | Deops ops who have been idle past the channel's limit |
| `chanlog` | on | Sends the channel's audit trail to the ops channel |

```
!module list                          show every module and its state here
!enable idledeop                      turn one on for this channel
!disable idledevoice                  turn one off for this channel
/msg <bot> disable #chan idledevoice  same thing, privately
```

> **Note:** module states and chanlog destinations are held in memory. A `.rehash` or
> `.restart` puts every module back to its default and every log back to `cc(backchan)`.

---

## Access levels

Access is a **position**, not a pile of flags. Every user sits on exactly one rung:

| Level | Flag | What it gets |
| --- | --- | --- |
| Owner | `+n` | Everything. Granted on DCC with `.chattr`, never by command |
| Master | `+m` | `!addop`, modes, blacklist, modules, chanlog, adduser/deluser |
| Op | `+o` | Channel `+o`, topic, `!addmod`, plus everything a mod can do |
| Mod | `+M` | Kick, ban, unban, bans, invite, voice, devoice — **no channel `+o`** |
| Voice | `+v` | Autovoice, and exemption from ActiveVoice's idle devoicer |

| Command | Who can use it |
| --- | --- |
| `!addvoice <nick\|handle>` | Mod and up |
| `!addmod <nick\|handle>` | Op and up |
| `!addop <nick\|handle>` | Master and up |
| `!addmaster <nick\|handle>` | Owner |
| `!delvoice` / `!delmod` / `!delop` / `!delmaster` | Same as the matching `add` |
| `!delaccess <nick\|handle>` | Op and up — removes whichever level they hold |
| `!access [level]` | Mod and up — lists everyone with access here |

- **One level at a time.** Granting a level strips every other level first, so `!addop` on
  someone who was only voiced *moves* them up, and `!addvoice` on an op moves them down.
- **Modes follow access.** `!addop` / `!addmaster` op the user, `!addvoice` / `!addmod` voice
  them, and the `!del…` commands take those modes back.
- **You can only reach below yourself.** Never at or above your own level, never your own access.
- **A welcome notice.** The person who got access is told who gave it, queued one line every
  `cc(access_welcome_delay)` seconds so a burst of grants can't flood the network.

```
<chanop> !addvoice dave
-bot- [OK] dave is now Voice on #mainchan (flags: -|v)
<chanop> !addmod dave
-bot- [OK] dave moves up from Voice to Mod on #mainchan (flags: -|Mv)
```

---

## Commands

Help is always a notice. `!help` lists the categories; `!help <command>` gives usage,
description and an example. The [documentation site](https://lmao-tcl.github.io/)
has every command with its syntax.

| Who | Commands |
| --- | --- |
| Everyone | `!help` `!showcommands` `!verify` `!version` · `/msg <bot> register` |
| Registered | `!bot` `!info` `!whois` `!ops` |
| Voice+ | `!voice` `!devoice` |
| Mod+ | `!kick` `!ban` `!unban` `!bans` `!invite` `!addvoice` `!access` |
| Op+ | `!op` `!deop` `!topic` `!topicsync` `!addmod` `!delaccess` |
| Master+ | `!mode` `!blacklist` `!whitelist` `!chattr` `!adduser` `!deluser` `!say` `!act` `!idledeop` `!module` `!enable` `!disable` `!chanlog` `!addop` |
| Owner | `!addchan` `!delchan` `!suschan` `!unsuschan` `!join` `!part` `!comeback` `!botnick` `!away` `!back` `!global` `!rehash` `!restart` `!jump` `!save` `!addmaster` |
| Anyone (bound `n\|-`) | `!chanset` `!uptime` |

### Channel management (owner)

```
!addchan #newchan      add it, save it to the chanfile and join (also by /msg)
!delchan #oldchan      remove it from the bot and chanfile, users are kept
!suschan #chan         leave but keep every setting and user
!unsuschan #chan       join it again
```

### By private message

Anything that needs a channel takes it as the first argument. Access is checked on the
channel you name, so channel-only ops and masters work too.

```
/msg <bot> help [command]
/msg <bot> verify [nick]
/msg <bot> op #chan [nick]
/msg <bot> module #chan list
/msg <bot> chanlog #chan #ops
/msg <bot> addchan #chan
/msg <bot> away [message] | back
/msg <bot> rehash | restart | jump | save
```

---

## Idle deop

The module is off by default. `!enable idledeop` turns it on for a channel and `!idledeop #chan <minutes>`
sets the limit. Never deopped: the service bots in `cc(protected_bots)`, the bot itself,
anyone with a flag from `cc(protected_flags)`, and anyone named in `cc(deop_exempt)`
(nick or handle, case-insensitive).

---

## Requirements

- eggdrop 1.8 or newer (tested on 1.10.1)
- Tcl 8.5 or newer
- The bot needs op in the channels it manages

---

## License

GPLv3 — see [LICENSE](LICENSE).
