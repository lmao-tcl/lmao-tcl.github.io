# lmao.tcl

**Channel management for eggdrop, built for UnderNet.**

[![Version](https://img.shields.io/badge/version-6.8.1-orange.svg)](https://github.com/lmao-tcl/lmao-tcl.github.io)
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
- **Flood guard.** Kicks a lone flooder and locks the channel `+Dm` when a drone wave hits,
  then opens it again by itself.
- **Works with X.** With its own X account the bot logs in, hides its host, and asks X for
  op, unban or invite when it is locked out.
- **Delayed join.** Keeps a channel `+Dm` and lets newcomers in by voice: X users first,
  everyone else once they check out.
- **Drone blacklists.** Checks IPs against DroneBL and EFnet RBL and bans drones while they are
  still hidden by `+D`.
- **Bad channels.** Bans people who sit in channels you list.
- **Any channel setting.** `!chanset` lists and changes every eggdrop channel setting, including
  the ones other scripts add.
- **UnderNet aware.** Written against ircu, and reads what the server supports instead of assuming it.

---

## Install

```sh
cd ~/eggdrop/scripts
wget https://lmao-tcl.github.io/lmao.tcl
```

Add it to your `eggdrop.conf`:

```tcl
source scripts/lmao.tcl
```

Then `.rehash` on the partyline. You should see:

```
[lmao.tcl 6.8.1] - Complete production ready version
Loaded successfully - ready to serve!
```

Nothing else to install. The `dnsbl` module uses eggdrop's `dns` module, which is loaded by
default, and `badchan` saves its lists in `lmao-badchan.txt` next to the bot.

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
| `cc(deop_exempt)` | `You Bot1 Bot2` | Nicks or handles the idle-deop sweep never touches |
| `cc(guard_user_flood)` | `6:5` | Lines in seconds from one person before a kick |
| `cc(guard_line_flood)` | `15:5` | Lines in seconds from the whole channel before a lock |
| `cc(guard_join_flood)` | `8:10` | Joins in seconds before a lock |
| `cc(guard_nick_flood)` | `5:10` | Nick changes in seconds before a lock |
| `cc(guard_user_action)` | `kickban` | `kickban`, `kick` or `none` for a lone flooder |
| `cc(guard_ban_minutes)` | `10` | How long that ban lasts |
| `cc(guard_lock_modes)` | `Dm` | Modes a lock sets (unsupported letters are skipped) |
| `cc(guard_lock_minutes)` | `5` | Quiet minutes before a lock lifts itself |
| `cc(guard_netsplit_seconds)` | `120` | Grace after a netsplit: joins are not counted as a flood |
| `cc(x_user)` / `cc(x_pass)` | empty | The bot's own X account. Empty keeps X off |
| `cc(x_hide_host)` | `1` | Set `+x` after logging in to X |
| `cc(x_rescue)` | `1` | Ask X for op, unban or invite when locked out |
| `cc(dj_modes)` | `Dm` | Modes delayjoin keeps on the channel |
| `cc(dj_scan_seconds)` | `15` | How often hidden members are looked up |
| `cc(dj_voice_authed)` / `cc(dj_voice_unauthed)` | `0` / `30` | Seconds before X users / everyone else are voiced |
| `cc(dj_welcome)` | text | Notice sent while they wait (`""` sends nothing) |
| `cc(dnsbl_zones)` | DroneBL, EFnet RBL | Blacklists and the reply codes that mean ban |
| `cc(dnsbl_ban_minutes)` | `120` | How long a blacklist ban lasts |
| `cc(dnsbl_cache_minutes)` | `60` | How long each IP's answer is remembered |
| `cc(badchan_file)` | `lmao-badchan.txt` | Where the bad channel lists are saved |
| `cc(badchan_ban_minutes)` | `60` | How long a bad channel ban lasts |

---

## Modules

Modules are per channel. Four start **on**; the other five start **off** because they change how
the channel works.

| Module | Default | What it does |
| --- | --- | --- |
| `topic` | on | `!topic` / `!topicsync` — stores the topic and re-applies it when it drifts |
| `activevoice` | on | Auto-voices non-registered users when they talk, and tracks their activity |
| `idledevoice` | **off** | Removes voice from non-registered users who have gone idle |
| `idledeop` | **off** | Deops ops who have been idle past the channel's limit |
| `chanlog` | on | Sends the channel's audit trail to the ops channel |
| `guard` | on | Flood protection: kicks lone flooders, locks the channel under attack |
| `delayjoin` | off | Keeps the channel `+Dm` and voices hidden newcomers once they check out |
| `dnsbl` | off | Bans IPs listed on drone and proxy blacklists, even before they show up |
| `badchan` | off | Bans people who sit in listed channels |

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
| Op+ | `!op` `!deop` `!topic` `!topicsync` `!addmod` `!delaccess` `!lockdown` `!unlock` `!guard` `!dnsbl` `!badchan` |
| Master+ | `!mode` `!blacklist` `!whitelist` `!chattr` `!adduser` `!deluser` `!say` `!act` `!idledeop` `!module` `!enable` `!disable` `!chanlog` `!addop` `!chanset` |
| Owner | `!addchan` `!delchan` `!suschan` `!unsuschan` `!join` `!part` `!comeback` `!botnick` `!away` `!back` `!global` `!rehash` `!restart` `!jump` `!save` `!addmaster` `!xlogin` |
| Anyone (bound `n\|-`) | `!uptime` |

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

## Flood guard

The `guard` module is on by default. One person saying 6 lines in 5 seconds is kicked and
banned for 10 minutes. The whole channel flooding (15 lines in 5 seconds), 8 joins in 10
seconds or 5 nick changes in 10 seconds **locks the channel** with `+Dm`:

- `+D` hides new joins until they are voiced or opped, so a drone wave never fills the nick list.
- `+m` silences everyone without voice; regulars who have voice keep talking.

The lock lifts itself after 5 quiet minutes and only removes the modes it set. Ops, registered
regulars and service bots are never counted. The ops get a notice only they see, and every
lock, unlock and kick goes to chanlog.

```
!lockdown [minutes]    lock now
!unlock                lift it early
!guard                 state and limits
```

**Netsplits are not attacks.** People returning from a split rejoin quietly, and for 2 minutes
after any split sign in a channel, joins are not counted and the bad channel WHOIS is skipped, so
a relink never trips the guard. UnderNet's hidden `*.net *.split` quits are recognized; a user's
own quit always starts with `Quit:`, so a split cannot be faked.

If a channel's eggdrop `chanmode` setting enforces `-m` or `-D`, it will undo a lock.

---

## X

Give the bot **its own** X account and it can get itself out of trouble:

```tcl
set cc(x_user) "mybot"
set cc(x_pass) "its-x-password"
```

On connect it logs in through `x@channels.undernet.org` and sets `+x`. Deopped, it asks X
for op; banned, for an unban; kept out by `+i`, `+l`, `+k` or `+r`, for an invite (an invite
gets past all of those on ircu). This goes through eggdrop's `need-*` hooks; one you set
yourself is never overwritten. `!xlogin` sends the login again.

---

## Delayed join (+Dm)

`!enable delayjoin` turns a channel into a waiting room. The bot keeps `+Dm` on: nobody sees a
join, and nobody without voice can talk. Every 15 seconds it asks for the hidden members
(`NAMES -d`), looks them up in batches with WHOX, and lets them in by voicing them:

- logged in to X: right away
- everyone else: after 30 seconds, once the DNSBL and bad channel checks pass (when on)
- banned people stay hidden; during a guard lock only X users and regulars get in

People already talking are voiced before `+m` goes on, and switching the module off removes only
the modes it set.

---

## Drone blacklists (DNSBL)

`!enable dnsbl` checks the IP of people who join against DroneBL and EFnet RBL, and bans listed
drones and proxies for 2 hours. On a `+D` channel the hidden members are checked too, so a drone is
banned **before anyone sees it**. IPv4 and IPv6, hostnames resolved first, answers cached for an
hour, web client IPs (Mibbit, KiwiIRC) decoded. `!dnsbl <nick|ip|host>` checks one by hand.

The lookups use eggdrop's non-blocking `dnslookup` (the `dns` module, loaded by default). Asking a
blacklist means its operator sees the IP being checked.

---

## Bad channels

```
!badchan add #*spam* no spammers      this channel's list
!badchan add -global #*warez*         every channel (Owner)
!badchan del #*spam*
!badchan list
!enable badchan
```

Newcomers are WHOISed and banned for an hour if they sit in a matching channel. A host checked
clean is not checked again for 3 minutes. Lists are saved in `lmao-badchan.txt`.

---

## Channel settings

`!chanset` works with every eggdrop channel setting, built in or added by another script:

```
!chanset                 list them all (eggdrop 1.9+)
!chanset +autoop         turn one on, - turns it off
!chanset flood-chan 10:60
```

It reads the change back and tells you if it failed. `need-*` settings are refused because
their value is Tcl code the bot runs.

---

## Requirements

- eggdrop 1.8 or newer (tested on 1.10.1)
- Tcl 8.5 or newer
- The bot needs op in the channels it manages

---

## Credits

lmao.tcl stands on the work of people who gave their scripts to the community. The modules are
written fresh for lmao.tcl, but these ideas are theirs, and we are grateful:

- **^The_law^ and #Ayuda** (UnderNet) — `eafs.tcl`, running a channel behind `+Dm` with tiered
  voicing; the base of the delayed join module
- **xplorer** (#mircscripting) and **OUTsider** — `Dm.tcl`, the first `+Dm` delay-voice script and
  its multi-channel version
- **Stefan Wold (Ratler)** — [zapdnsbl](https://github.com/Ratler/zapdnsbl), DNS blacklist checks
  and the web client IP trick; the base of the DNSBL module
- **Bass** (UnderNet #eggdrop) — `badchan.tcl`, the bad channel list
- **UnderNet coder-com** — [ircu and gnuworld](https://github.com/UndernetIRC)
- **The Eggheads** — [eggdrop](https://www.eggheads.org/)
- **[DroneBL](https://dronebl.org/)** and **[EFnet RBL](https://rbl.efnetrbl.org/)**, run by volunteers

---

## License

GPLv3 — see [LICENSE](LICENSE).
