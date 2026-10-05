# https://lmao-tcl.github.io/  -  source: https://github.com/lmao-tcl/lmao-tcl.github.io
# Enhanced version 6.5 - COMPLETE with help system, topic system, module framework,
# ActiveVoice and the access level system (!addvoice !addmod !addop !addmaster)
# For UnderNet ircu with proper flag protection

###########################################################################
# CONFIGURATION SECTION - EDIT THESE VALUES
###########################################################################

# Command character trigger
set cc(cmdchar) "!"

# Main public channel
set cc(mainchan) "#mainchan"

# Back/ops channel (private)
set cc(backchan) "#secretchan"

# Back channel modes
set cc(backmode) "+snt"

# Bot away message. away_enabled 1 = the bot sets itself away with away_message,
# on every connect and on every rehash if it is not away yet. 0 = never away.
# The owner can change it live with the away and back commands; that is saved in
# away_file, survives reboots and rehashes, and takes over from these two values.
set cc(away_enabled) 0
set cc(away_message) "Powered by lmao.tcl - https://lmao-tcl.github.io/"
set cc(away_file) "lmao-away.txt"

# Idle deop configuration
set cc(idledeop_enabled) 1
set cc(idledeop_default_minutes) 180
set cc(idledeop_check_interval) 5

# ActiveVoice configuration
set cc(activevoice_idle_minutes) 180
set cc(activevoice_check_interval) 10

# Access welcome notices are globally throttled to avoid flooding the network.
# One line is sent every N seconds, across all access changes.
set cc(access_welcome_delay) 3

# Flags that make a user exempt from ActiveVoice. ActiveVoice is only for
# non-regulars: anyone registered with +n, +m, +M or +v keeps their own voice.
set cc(activevoice_exempt_flags) [list n m M v]

# Self-registration: /msg <bot> register
# register_handle_max must not exceed the handlen setting in eggdrop.conf
set cc(register_enabled) 1
set cc(register_token_life) 300
set cc(register_cooldown) 600
set cc(register_handle_max) 9
set cc(register_flags) ""

# Guard - flood and attack protection, per channel (!enable/!disable guard).
# Limits are "count:seconds". Ops, registered regulars and service bots are
# never counted. A user who floods alone is kicked (and banned for
# guard_ban_minutes if guard_user_action is "kickban"). When the whole channel
# floods, it is locked with guard_lock_modes until it has been quiet for
# guard_lock_minutes. Modes the server does not support are skipped, and modes
# already set are left alone and never removed by the unlock.
set cc(guard_join_flood) "8:10"
set cc(guard_line_flood) "15:5"
set cc(guard_user_flood) "6:5"
set cc(guard_nick_flood) "5:10"
set cc(guard_user_action) "kickban"
set cc(guard_ban_minutes) 10
set cc(guard_lock_modes) "Dm"
set cc(guard_lock_minutes) 5

# X (UnderNet channel service). Leave x_user empty to keep all of this off.
# With an X account the bot logs in when it connects, can hide its host
# (+x, it becomes <account>.users.undernet.org), and asks X for help when it
# is locked out: op when deopped, unban when banned, invite when the channel
# is +i, +l, +k or +r (an invite gets past all of those on ircu).
set cc(x_user) ""
set cc(x_pass) ""
set cc(x_hide_host) 1
set cc(x_rescue) 1

# Version info
set cc(version_number) "6.7.0"
set cc(version) "\002\[lmao.tcl $cc(version_number)\]\002"
set cc(www) "https://lmao-tcl.github.io/"

###########################################################################
# MODULE ENABLE/DISABLE SYSTEM
###########################################################################

# Per-channel module settings (default: all ON)
array set module_settings {}

# Default module state (1 = enabled, 0 = disabled)
set module_defaults(topic) 1
set module_defaults(activevoice) 1
set module_defaults(idledeop) 0
set module_defaults(idledevoice) 0
set module_defaults(chanlog) 1
set module_defaults(guard) 1

proc init_channel_modules {chan} {
	global module_defaults module_settings
	
	# Initialize all modules for this channel if not already done
	foreach {module enabled} [array get module_defaults] {
		if {![info exists module_settings($chan:$module)]} {
			set module_settings($chan:$module) $enabled
		}
	}
}

proc module_enabled {chan module} {
	global module_settings
	
	if {![info exists module_settings($chan:$module)]} {
		init_channel_modules $chan
	}
	
	return $module_settings($chan:$module)
}

proc toggle_module {chan module state} {
	global module_settings
	
	if {$state eq "on"} {
		set module_settings($chan:$module) 1
	} else {
		set module_settings($chan:$module) 0
	}
}

###########################################################################
# PROTECTED BOTS & FLAGS - DO NOT EDIT
###########################################################################

# Service bots that should NEVER be deopped
set cc(protected_bots) [list "X" "W"]

# Flags that protect users from deop/devoice. Mods (+M) are deliberately not
# in here - a mod is an ordinary channel member as far as modes go.
set cc(protected_flags) [list "n" "m"]

# Nicks or handles the idle deop timer must never touch, whatever flags they
# carry and however long they sit there. The people who actually run the
# channel go in here - they op themselves on purpose and keep it.
set cc(deop_exempt) [list "You" "Bot1" "Bot2"]

# Store idle deop settings per channel
array set idledeop_config {}

# Store topic per channel
array set topic_storage {}

# Store active voice tracking - tracks last activity time per user per channel
array set activevoice_data {}

###########################################################################
# BIND DECLARATIONS
###########################################################################

# A note on the flag masks below. "global|channel" is how eggdrop reads them,
# and the two halves are checked separately: n|m lets through a global owner
# or a channel master, but NOT someone carrying master globally and nothing on
# the channel - which is how a command ends up silently doing nothing. Both
# halves therefore carry the same letters everywhere.

# Channel mode commands - !op !deop !voice !devoice
#
# These four are bound open on purpose and check the access level themselves,
# in access:require. A flag mask that does not match makes eggdrop drop the
# command on the floor without a word, which is exactly what people report as
# "I typed !op and nothing happened". Deciding it inside the proc means there
# is always an answer.
bind pub - [string trim $cc(cmdchar)]voice pub_do_voice
bind pub - [string trim $cc(cmdchar)]devoice pub_do_devoice
bind pub - [string trim $cc(cmdchar)]op pub_do_op
bind pub - [string trim $cc(cmdchar)]deop pub_do_deop

# Flag o - Operator commands
bind pub noM|noM [string trim $cc(cmdchar)]invite pub_do_invite
bind msg - op pub_do_op:msg
bind msg - [string trim $cc(cmdchar)]op pub_do_op:msg
bind pub no|no [string trim $cc(cmdchar)]topic topic:pub
bind pub no|no [string trim $cc(cmdchar)]topicsync topic:sync
bind pub noM|noM [string trim $cc(cmdchar)]kick pub_do_kick
bind pub noM|noM [string trim $cc(cmdchar)]unban pub_do_unban
bind pub noM|noM [string trim $cc(cmdchar)]bans pub_do_bans
bind pub noM|noM [string trim $cc(cmdchar)]ban ban:pub
bind msg - ban ban:msg
bind msg - [string trim $cc(cmdchar)]ban ban:msg

# Flag m - Master commands
bind pub nm|nm [string trim $cc(cmdchar)]mode pub_do_mode
bind pub nm|nm [string trim $cc(cmdchar)]whitelist pub_do_unperm
bind pub nm|nm [string trim $cc(cmdchar)]blacklist pub_do_perm
bind pub nm|nm [string trim $cc(cmdchar)]chattr chattr:pub
bind pub nm|nm [string trim $cc(cmdchar)]act pub:act
bind pub nm|nm [string trim $cc(cmdchar)]say pub:say
bind pub nm|nm [string trim $cc(cmdchar)]idledeop idledeop:pub
bind pub nm|nm [string trim $cc(cmdchar)]module module:pub
bind pub nm|nm [string trim $cc(cmdchar)]modules module:pub
bind pub nm|nm [string trim $cc(cmdchar)]enable module:enable:pub
bind pub nm|nm [string trim $cc(cmdchar)]disable module:disable:pub
bind pub nm|nm [string trim $cc(cmdchar)]chanlog chanlog:pub

# Module control by /msg - access is checked inside the procs so channel-only
# masters work too: /msg <bot> disable #chan idledevoice
bind msg - module module:msg
bind msg - modules module:msg
bind msg - enable module:enable:msg
bind msg - disable module:disable:msg
bind msg - chanlog chanlog:msg

# Flag n - Owner/Bot control
bind pub n [string trim $cc(cmdchar)]away pub_do_away
bind pub n [string trim $cc(cmdchar)]back pub_do_back
bind pub n [string trim $cc(cmdchar)]rehash pub_do_rehash
bind pub n [string trim $cc(cmdchar)]restart pub_do_restart
bind pub n [string trim $cc(cmdchar)]jump pub_do_jump
bind pub n [string trim $cc(cmdchar)]save pub_do_save

# Owner commands by /msg too - the n flag is re-checked inside the procs
bind msg - rehash pub_do_rehash:msg
bind msg - restart pub_do_restart:msg
bind msg - jump pub_do_jump:msg
bind msg - save pub_do_save:msg
bind pub n [string trim $cc(cmdchar)]global pub:global
bind pub n [string trim $cc(cmdchar)]part part:pub
bind pub n [string trim $cc(cmdchar)]comeback comeback:pub
bind pub n [string trim $cc(cmdchar)]join join:pub
bind pub n [string trim $cc(cmdchar)]addchan addchan:pub
bind msg - addchan addchan:msg
bind pub n [string trim $cc(cmdchar)]delchan delchan:pub
bind pub n [string trim $cc(cmdchar)]suschan suschan:pub
bind pub n [string trim $cc(cmdchar)]unsuschan unsuschan:pub
bind pub n [string trim $cc(cmdchar)]botnick botnick:pub
bind pub nm|nm [string trim $cc(cmdchar)]adduser adduser:pub
bind pub nm|nm [string trim $cc(cmdchar)]deluser deluser:pub
bind pub nm|nm [string trim $cc(cmdchar)]chanset chanset:pub
bind pub n|- [string trim $cc(cmdchar)]uptime uptime:pub

# Guard - flood protection. The lock commands check Op level themselves.
bind pub - [string trim $cc(cmdchar)]lockdown guard:lock:pub
bind pub - [string trim $cc(cmdchar)]unlock guard:unlock:pub
bind pub - [string trim $cc(cmdchar)]guard guard:status:pub
bind join - * guard:join
bind pubm - * guard:pubm
bind notc - * guard:notc
bind ctcp - ACTION guard:action
bind nick - * guard:nick

# X (channel service)
bind pub n [string trim $cc(cmdchar)]xlogin x:login:pub
bind evnt - init-server x:on_connect
bind notc - * x:notc

# What the server supports (CHANMODES, MODES, STATUSMSG...)
bind raw - 005 lmao:raw005

# Flag - (registered users)
bind pub - [string trim $cc(cmdchar)]bot pub_do_bot
bind pub - [string trim $cc(cmdchar)]info pub_info
bind pub - [string trim $cc(cmdchar)]whois pub_whois
bind pub - [string trim $cc(cmdchar)]ops pub:alert

# Flag * (Everyone) & Help/Verify
bind pub * [string trim $cc(cmdchar)]version pub_version
bind pub * [string trim $cc(cmdchar)]help help:pub
bind pub * [string trim $cc(cmdchar)]showcommands showcommands:pub
bind pub * [string trim $cc(cmdchar)]verify verify:pub
bind msg * help help:msg
bind msg * showcommands showcommands:msg
bind msg * verify verify:msg
bind msg - register register:msg

# DCC Commands (fn flag)
bind dcc fn|fn lmao pub_lmao
bind dcc fn|fn keepalive dobinddcckeepalive
bind dcc fn|fn undokeepalive undobinddcckeepalive

# When the bot is deopped: ask X for op if an X account is set, otherwise
# cycle the channel when the bot is alone in it (the only case where cycling
# gets op back). It never kicks back - whoever deopped it may be staff, or X.
set hopondeop 1
bind mode - * hop:mode

# CTCP Replies
set replyctcp "[string trim $cc(version)] Get it from: $cc(www)"
bind ctcp - "VERSION" ctcp:reply
bind ctcp - "PING" ctcp:reply
bind ctcp - "TIME" ctcp:reply
bind ctcp - "FINGER" ctcp:reply

# ActiveVoice tracking - bind to PUBM to track activity
bind pubm - * activevoice:track

###########################################################################
# UTILITY FUNCTIONS
###########################################################################

# Check if user has protected flags
proc has_protected_flags {nick chan} {
	global cc
	set user_flags [chattr $nick $chan]
	
	foreach flag $cc(protected_flags) {
		if {[string match "*$flag*" $user_flags]} {
			return 1
		}
	}
	return 0
}

# Is this nick, or the handle behind it, on the never-deop list?
proc is_deop_exempt {nick chan} {
	global cc

	if {![info exists cc(deop_exempt)]} {
		return 0
	}

	set hand [nick2hand $nick $chan]

	foreach who $cc(deop_exempt) {
		if {[string equal -nocase $nick $who]} {
			return 1
		}
		if {$hand ne "" && $hand ne "*" && [string equal -nocase $hand $who]} {
			return 1
		}
	}
	return 0
}

# Check if nick is a protected bot
proc is_protected_bot {nick} {
	global cc
	foreach bot $cc(protected_bots) {
		if {[string tolower $nick] eq [string tolower $bot]} {
			return 1
		}
	}
	return 0
}

# Get user's access level string
# One answer, taken from the access level table further down, so !verify,
# !whois and the access commands can never disagree about what somebody is.
proc get_access_level {nick chan} {
	set row [access:by_rank [access:rank $nick $chan]]
	
	if {$row eq ""} {
		return "User (-)"
	}
	
	return "[lindex $row 4] ([lindex $row 2])"
}

###########################################################################
# MODULE MANAGEMENT COMMAND
###########################################################################

# What each module actually does, shown by !module list
array set module_desc {
	topic		{!topic / !topicsync - stores and re-applies the channel topic}
	activevoice	{auto-voices non-registered users when they talk}
	idledevoice	{removes voice from non-registered users idle too long}
	chanlog		{logs access, sanctions and registrations to the ops channel}
	idledeop	{deops ops who have been idle past the channel limit}
	guard		{flood protection - kicks flooders, locks the channel (+Dm) under attack}
}

proc module:show {nick chan} {
	global module_defaults module_desc cc

	set c [string trim $cc(cmdchar)]

	puthelp "NOTICE $nick :\002Modules for $chan:\002"
	foreach mod [lsort [array names module_defaults]] {
		if {[module_enabled $chan $mod]} {
			set state "ON "
		} else {
			set state "OFF"
		}
		if {[info exists module_desc($mod)]} {
			set what " - $module_desc($mod)"
		} else {
			set what ""
		}
		puthelp "NOTICE $nick :  \[$state\] $mod$what"
	}
	puthelp "NOTICE $nick :Use ${c}enable <module> or ${c}disable <module> (this channel only)"
}

proc module:pub {nick uhost hand chan arg} {
	global module_defaults module_settings cc

	set c [string trim $cc(cmdchar)]
	set action [string tolower [lindex [split $arg] 0]]
	set module [string tolower [lindex [split $arg] 1]]

	if {$action eq "" || $action eq "list"} {
		module:show $nick $chan
		return
	}

	if {$action ne "enable" && $action ne "disable" && $action ne "on" && $action ne "off"} {
		puthelp "NOTICE $nick :Unknown action: $action - use ${c}module list | enable <module> | disable <module>"
		return
	}

	if {$module eq ""} {
		puthelp "NOTICE $nick :Usage: ${c}module list | enable <module> | disable <module>"
		puthelp "NOTICE $nick :Available modules: [help:modules]"
		return
	}

	# Check if module exists
	if {![info exists module_defaults($module)]} {
		puthelp "NOTICE $nick :Unknown module: $module - available: [help:modules]"
		return
	}

	if {$action eq "enable" || $action eq "on"} {
		toggle_module $chan $module "on"
		puthelp "NOTICE $nick :\[OK\] Module $module is now ENABLED in $chan"
		putlog "$nick enabled module $module in $chan"
		chanlog $chan "MODULE" "$nick enabled module \002$module\002"
	} else {
		toggle_module $chan $module "off"
		puthelp "NOTICE $nick :\[OK\] Module $module is now DISABLED in $chan"
		putlog "$nick disabled module $module in $chan"
		chanlog $chan "MODULE" "$nick disabled module \002$module\002"
	}
}

# !enable <module> / !disable <module> - shortcuts for !module enable|disable
proc module:enable:pub {nick uhost hand chan arg} {
	module:pub $nick $uhost $hand $chan "enable [lindex [split $arg] 0]"
}

proc module:disable:pub {nick uhost hand chan arg} {
	module:pub $nick $uhost $hand $chan "disable [lindex [split $arg] 0]"
}

# /msg versions - the channel has to be named first:
#   /msg <bot> module #chan list        /msg <bot> disable #chan idledevoice
proc module:msg {nick uhost hand text} {
	global cc

	set c [string trim $cc(cmdchar)]
	set parts [split [string trim $text]]
	set chan [lindex $parts 0]
	set rest [join [lrange $parts 1 end] " "]

	if {![string match "#*" $chan]} {
		puthelp "NOTICE $nick :Usage: /msg $::botnick module <#channel> <list|enable|disable> \[module\]"
		return
	}

	if {![validchan $chan]} {
		puthelp "NOTICE $nick :I am not on $chan"
		return
	}

	if {![matchattr $hand n] && ![matchattr $hand m|m $chan]} {
		puthelp "NOTICE $nick :You do not have access to change modules on $chan"
		chanlog $chan "DENIED" "$nick tried to change modules by /msg"
		return
	}

	module:pub $nick $uhost $hand $chan $rest
}

proc module:enable:msg {nick uhost hand text} {
	set parts [split [string trim $text]]
	module:msg $nick $uhost $hand "[lindex $parts 0] enable [lindex $parts 1]"
}

proc module:disable:msg {nick uhost hand text} {
	set parts [split [string trim $text]]
	module:msg $nick $uhost $hand "[lindex $parts 0] disable [lindex $parts 1]"
}

###########################################################################
# HELP SYSTEM - every reply is delivered by NOTICE (channel and /msg alike)
# Format: Command: / Description / Example
#
# One table, one sender: !help and /msg <bot> help share the same data, so a
# command only ever has to be documented once.
#   %C% = command character     %B% = bot nick     %M% = module list
###########################################################################

# command -> {usage  description  example  /msg-example (empty = no msg bind)}
array set helpdb {
	help		{{%C%help [command]} {Shows command help. Replies always come to you by notice, never to the channel} {%C%help ban} {/msg %B% help ban}}
	showcommands	{{%C%showcommands} {Lists every command name the bot knows} {%C%showcommands} {/msg %B% showcommands}}
	op		{{%C%op [nick]} {Gives op (+o) to yourself or someone specified. Needs Op level or above in the user list} {%C%op nickname} {/msg %B% op #chan nickname}}
	deop		{{%C%deop [nick]} {Removes op (+o) from a user (cannot deop +n/+m flagged users or service bots). Needs Op level or above} {%C%deop nickname} {}}
	voice		{{%C%voice [nick]} {Gives voice (+v) to yourself or someone specified. Needs Voice level or above} {%C%voice nickname} {}}
	devoice		{{%C%devoice [nick]} {Removes voice (+v) from a user (cannot devoice +n/+m flagged users). Needs Voice level or above} {%C%devoice nickname} {}}
	invite		{{%C%invite <nick>} {Invites a user to the channel (bot must be opped)} {%C%invite someuser} {}}
	kick		{{%C%kick <nick> [reason]} {Kicks a user from the channel with optional reason} {%C%kick spammer spam detected} {}}
	ban		{{%C%ban <nick> [reason]} {Bans and kicks a user (mask: *!*@host). Protects +n/+m flags and service bots} {%C%ban baduser being annoying} {}}
	unban		{{%C%unban <*!*@host>} {Removes a ban from the channel banlist} {%C%unban *!*@example.com} {}}
	bans		{{%C%bans} {Lists all current bans on the channel with details} {%C%bans} {}}
	topic		{{%C%topic <new topic text>} {Sets and stores the channel topic (bot must be opped). Needs the topic module} {%C%topic Welcome to the channel - read the rules} {}}
	topicsync	{{%C%topicsync} {Re-applies the stored channel topic when it gets out of sync} {%C%topicsync} {}}
	mode		{{%C%mode <channel modes>} {Sets channel modes (bot must be opped). Use + or - with mode letters} {%C%mode +nt} {}}
	blacklist	{{%C%blacklist <nick> [reason]} {Permanently bans a user (mask: *!*@host) with optional reason} {%C%blacklist troll repeat offender} {}}
	whitelist	{{%C%whitelist <*!*@host>} {Removes a user from the permanent blacklist} {%C%whitelist *!*@example.com} {}}
	addvoice	{{%C%addvoice <nick|handle>} {Gives someone Voice level on this channel and sets +v on them if they are here. A nick with no user record gets one made from the host they are on. Replaces any level they already had} {%C%addvoice john} {}}
	addmod		{{%C%addmod <nick|handle>} {Gives someone Mod level (+M): kick, ban, unban, bans, invite, voice and devoice, but no channel +o. Sets +v on them and takes +o off if they had it. Op or above only} {%C%addmod john} {}}
	addop		{{%C%addop <nick|handle>} {Gives someone Op level on this channel and ops them (+o) if they are here. Master or above only. Upgrades whatever level they had - a Voice or Mod becomes an Op, nothing is left behind} {%C%addop john} {}}
	addmaster	{{%C%addmaster <nick|handle>} {Gives someone Master level on this channel and ops them (+o) if they are here. Owner only} {%C%addmaster john} {}}
	delvoice	{{%C%delvoice <nick|handle>} {Takes Voice level away, leaving no access, and removes +v in the channel. Only works on someone whose level actually is Voice} {%C%delvoice john} {}}
	delmod		{{%C%delmod <nick|handle>} {Takes Mod level away, leaving no access, and removes +v in the channel. Op or above only} {%C%delmod john} {}}
	delop		{{%C%delop <nick|handle>} {Takes Op level away, leaving no access, and removes +o in the channel. Master or above only} {%C%delop john} {}}
	delmaster	{{%C%delmaster <nick|handle>} {Takes Master level away, leaving no access, and removes +o in the channel. Owner only} {%C%delmaster john} {}}
	delaccess	{{%C%delaccess <nick|handle>} {Removes whatever level someone holds, without having to know which one it is, and takes +o/+v off them in the channel. The user record itself stays - use %C%deluser to remove that} {%C%delaccess john} {}}
	access		{{%C%access [level]} {Lists everyone with a level on this channel, highest first. Add a level name to list just that one. Levels: voice, mod, op, master, owner} {%C%access mod} {}}
	chattr		{{%C%chattr <handle> <+|-flags>} {Modifies a user's access flags on this channel (add with +, remove with -)} {%C%chattr john +o} {}}
	adduser		{{%C%adduser <handle> [*!*@host]} {Adds a user to the bot. Without a hostmask the nick's current host is used} {%C%adduser john *!*@his.host.com} {}}
	deluser		{{%C%deluser <handle>} {Removes a user from the bot completely} {%C%deluser john} {}}
	verify		{{%C%verify [nick]} {Shows your access level or someone elses (handle, flags, registered hosts). Given a registration code instead, it finishes your registration} {%C%verify someuser} {/msg %B% verify someuser}}
	register	{{/msg %B% register [handle]} {Registers you with the bot using the host you are on. You get a one-time code to type back, and the bot re-checks everything before saving. Auth with X and set +x first so your host is hidden} {/msg %B% register} {}}
	whois		{{%C%whois <nick>} {Shows a users access level and flags} {%C%whois someuser} {}}
	info		{{%C%info [text|none]} {Sets your personal infoline, shows it when used alone, clears it with none} {%C%info Hello, I am a channel regular} {}}
	say		{{%C%say <message text>} {Makes the bot speak a message to the channel (master+ only)} {%C%say Hello everyone} {}}
	act		{{%C%act <action text>} {Makes the bot perform an action (/me) in the channel (master+ only)} {%C%act waves at everyone} {}}
	global		{{%C%global <message text>} {Sends a message to every channel the bot is on (owner only)} {%C%global Server maintenance in 10 minutes} {}}
	ops		{{%C%ops <reason>} {Alerts the ops in the back channel that you need help here} {%C%ops someone is flooding} {}}
	module		{{%C%module <list|enable|disable> [module]} {Shows or changes which modules run on THIS channel. Modules: %M%} {%C%module list} {/msg %B% module #chan list}}
	enable		{{%C%enable <module>} {Turns a module ON for this channel. Modules: %M%} {%C%enable idledevoice} {/msg %B% enable #chan idledevoice}}
	disable		{{%C%disable <module>} {Turns a module OFF for this channel - use this to stop the idle devoicer or the idle deopper. Modules: %M%} {%C%disable idledevoice} {/msg %B% disable #chan idledevoice}}
	chanlog		{{%C%chanlog [#channel|on|off]} {Shows or sets where this channel's audit log goes. Access changes, sanctions, registrations, denied attempts and bot control all land there} {%C%chanlog #ops} {/msg %B% chanlog #chan #ops}}
	idledeop	{{%C%idledeop <#channel> [minutes]} {Sets the idle-deop timer for a channel (default 180 minutes). Master+ only. Switch it off with %C%disable idledeop} {%C%idledeop #canada 180} {}}
	chanset		{{%C%chanset [list | +setting | -setting | setting value]} {Lists or changes any eggdrop channel setting here, built in or added by another script. Says so if it fails and suggests close names. Master+} {%C%chanset +autoop} {}}
	lockdown	{{%C%lockdown [minutes]} {Locks the channel with the guard modes (+Dm by default) for a while: new joins stay hidden and only voiced users can talk. Op+} {%C%lockdown 10} {}}
	unlock		{{%C%unlock} {Lifts a guard lock early and removes only the modes the guard set. Op+} {%C%unlock} {}}
	guard		{{%C%guard} {Shows whether the flood guard is on, whether the channel is locked, and the flood limits. Op+} {%C%guard} {}}
	xlogin		{{%C%xlogin} {Makes the bot log in to X again with the account from the config (owner only)} {%C%xlogin} {}}
	join		{{%C%join <#channel>} {Makes the bot join a channel and adds it to the channel list (owner only)} {%C%join #newchan} {}}
	addchan		{{%C%addchan <#channel>} {Adds a channel, saves it to the chanfile and joins it} {%C%addchan #newchan} {/msg %B% addchan #newchan}}
	delchan		{{%C%delchan <#channel>} {Removes the channel from the bot and chanfile without deleting users} {%C%delchan #oldchan} {}}
	suschan		{{%C%suschan <#channel>} {Suspends a channel, makes the bot leave and keeps its channel/user data} {%C%suschan #channel} {}}
	unsuschan	{{%C%unsuschan <#channel>} {Unsuspends a channel and makes the bot join it again} {%C%unsuschan #channel} {}}
	part		{{%C%part <#channel>} {Makes the bot leave a channel and removes it from the channel list (owner only)} {%C%part #oldchan} {}}
	comeback	{{%C%comeback} {Makes the bot part and rejoin this channel (owner only)} {%C%comeback} {}}
	botnick		{{%C%botnick <newnick>} {Changes the bot nickname (owner only)} {%C%botnick newbotnick} {}}
	away		{{%C%away [message]} {Sets the bot away message, or shows it when you give no message. It is saved, so it survives reboots and rehashes (owner only)} {%C%away back at 8pm} {/msg %B% away back at 8pm}}
	back		{{%C%back} {Clears the bot away message and keeps it off, even after a reboot (owner only)} {%C%back} {/msg %B% back}}
	uptime		{{%C%uptime} {Shows how long the bot has been running} {%C%uptime} {}}
	rehash		{{%C%rehash} {Reloads the bot config and scripts (owner only)} {%C%rehash} {/msg %B% rehash}}
	restart		{{%C%restart} {Restarts the bot completely (owner only)} {%C%restart} {/msg %B% restart}}
	jump		{{%C%jump} {Makes the bot jump to another IRC server (owner only)} {%C%jump} {/msg %B% jump}}
	save		{{%C%save} {Writes the userfile and channel file to disk (owner only)} {%C%save} {/msg %B% save}}
	version		{{%C%version} {Shows the bot version number and GitHub repository link} {%C%version} {}}
	bot		{{%C%bot} {Shows basic bot information (trigger character, support channel)} {%C%bot} {}}
}

# Comma separated list of every module, substituted for %M%
proc help:modules {} {
	global module_defaults
	return [join [lsort [array names module_defaults]] ", "]
}

# The one and only help sender - always NOTICE, never to the channel
proc help:send {nick text} {
	global cc botnick helpdb

	set c [string trim $cc(cmdchar)]
	set map [list %C% $c %B% $botnick %M% [help:modules]]
	set htext [string tolower [lindex [split $text] 0]]

	# Strip a leading command character so !help !ban works too
	if {[string first $c $htext] == 0} {
		set htext [string range $htext [string length $c] end]
	}

	if {$htext eq ""} {
		puthelp "NOTICE $nick :\002Quick Help:\002 Type ${c}help <command> for details - (To prevent spam, you can use /msg $botnick help <command>)"
		puthelp "NOTICE $nick :\002Common:\002 op deop voice devoice invite kick ban unban bans topic mode verify whois info ops"
		puthelp "NOTICE $nick :\002Access:\002 ${c}access - ${c}addvoice ${c}addmod ${c}addop ${c}addmaster - ${c}delvoice ${c}delmod ${c}delop ${c}delmaster ${c}delaccess"
		puthelp "NOTICE $nick :\002Guard:\002 ${c}guard - ${c}lockdown \[minutes\] - ${c}unlock (flood protection, locks the channel +Dm under attack)"
		puthelp "NOTICE $nick :\002Modules:\002 ${c}module list - ${c}enable <module> - ${c}disable <module> (available: [help:modules])"
		puthelp "NOTICE $nick :Or try ${c}showcommands for the full list"
		return
	}

	if {![info exists helpdb($htext)]} {
		puthelp "NOTICE $nick :\002Unknown command:\002 $htext - Type ${c}help for the command list"
		return
	}

	foreach {usage desc example msgexample} $helpdb($htext) break

	puthelp "NOTICE $nick :\002Command:\002 [string map $map $usage]"
	puthelp "NOTICE $nick :[string map $map $desc]"
	puthelp "NOTICE $nick :\002Example:\002 [string map $map $example]"

	if {$msgexample ne ""} {
		puthelp "NOTICE $nick :\002By /msg:\002 [string map $map $msgexample]"
	}
}

proc help:pub {nick host hand chan text} {
	help:send $nick $text
}

proc help:msg {nick host hand text} {
	help:send $nick $text
}

###########################################################################
# SHOWCOMMANDS - every command name, built from the help table so the two
# can never drift apart. NOTICE only, same as help.
###########################################################################

proc showcommands:send {nick} {
	global cc botnick helpdb

	set c [string trim $cc(cmdchar)]

	puthelp "NOTICE $nick :\002All Commands:\002"

	set line ""
	foreach command [lsort [array names helpdb]] {
		append line "$command "
		if {[string length $line] > 300} {
			puthelp "NOTICE $nick :[string trimright $line]"
			set line ""
		}
	}
	if {$line ne ""} {
		puthelp "NOTICE $nick :[string trimright $line]"
	}

	puthelp "NOTICE $nick :\002Modules (per channel):\002 [help:modules] - see ${c}help module"
	puthelp "NOTICE $nick :Type ${c}help <command> for details - (To prevent spam, you can use /msg $botnick help <command>)"
}

proc showcommands:pub {nick host hand chan text} {
	showcommands:send $nick
}

proc showcommands:msg {nick host hand text} {
	showcommands:send $nick
}

###########################################################################
# CHANLOG MODULE - audit trail to the ops channel
#
# Every access change, every sanction, every registration and every piece
# of bot control lands in one channel, so the staff can read what happened
# without trawling the partyline.
#
#   !chanlog                 show where this channel logs, and whether it does
#   !chanlog #ops            send this channel's log to #ops and switch it on
#   !chanlog off             stop logging this channel
#   !chanlog on              start again, to wherever it was pointed
#
# Categories: ACCESS (who got what), SANCTION (kick/ban/deop/devoice),
# REGISTER (self-registration), MODULE (feature toggles), BOT (owner
# commands), DENIED (refused attempts at privileged commands).
###########################################################################

# chan (lowercase) -> destination channel
array set chanlog_dest {}

# Where does this channel's log go? Falls back to the configured back channel.
proc chanlog:dest {chan} {
	global cc chanlog_dest

	set key [string tolower $chan]
	if {[info exists chanlog_dest($key)]} {
		return $chanlog_dest($key)
	}
	return $cc(backchan)
}

# The one call every action site uses.
# chan "" means the event is not tied to a channel (owner commands, /msg
# registrations) - those always go to the configured back channel.
proc chanlog {chan category text} {
	global cc botnick

	if {$chan ne "" && [validchan $chan]} {
		if {![module_enabled $chan "chanlog"]} {
			return
		}
		set dest [chanlog:dest $chan]
		set where "\002$chan\002 "
	} else {
		set dest $cc(backchan)
		set where ""
	}

	if {$dest eq ""} {
		return
	}

	# Never log a channel into itself - that is how you get a feedback loop
	if {$chan ne "" && [string equal -nocase $dest $chan]} {
		return
	}

	# No point shouting at a channel the bot is not sitting in
	if {![validchan $dest] || ![botonchan $dest]} {
		return
	}

	puthelp "PRIVMSG $dest :\[$category\] $where$text"
}

proc chanlog:pub {nick uhost hand chan arg} {
	global cc chanlog_dest

	set c [string trim $cc(cmdchar)]
	set want [string trim [lindex [split $arg] 0]]
	set key [string tolower $chan]

	# --- no argument: report ---
	if {$want eq ""} {
		if {[module_enabled $chan "chanlog"]} {
			set state "ON"
		} else {
			set state "OFF"
		}
		set dest [chanlog:dest $chan]
		if {$dest eq ""} {
			set dest "\002nowhere\002 - set one with ${c}chanlog <#channel>"
		} elseif {![botonchan $dest]} {
			append dest " (I am not on that channel)"
		}
		puthelp "NOTICE $nick :Channel log for \002$chan\002 is \[$state\] and goes to $dest"
		puthelp "NOTICE $nick :Change it with ${c}chanlog <#channel>, or ${c}chanlog off"
		return
	}

	# --- off / on ---
	if {[string equal -nocase $want "off"]} {
		toggle_module $chan "chanlog" "off"
		puthelp "NOTICE $nick :\[OK\] Channel logging is now OFF for $chan"
		putlog "$nick turned channel logging off for $chan"
		chanlog "" "MODULE" "$nick turned channel logging \002off\002 for $chan"
		return
	}

	if {[string equal -nocase $want "on"]} {
		set dest [chanlog:dest $chan]
		if {$dest eq ""} {
			puthelp "NOTICE $nick :Nowhere to log to yet. Use ${c}chanlog <#channel> first."
			return
		}
		toggle_module $chan "chanlog" "on"
		puthelp "NOTICE $nick :\[OK\] Channel logging is now ON for $chan, going to $dest"
		putlog "$nick turned channel logging on for $chan (to $dest)"
		chanlog $chan "MODULE" "$nick turned channel logging \002on\002"
		return
	}

	# --- set a destination ---
	if {![string match "#*" $want]} {
		puthelp "NOTICE $nick :Usage: ${c}chanlog <#channel> | on | off"
		return
	}

	if {[string equal -nocase $want $chan]} {
		puthelp "NOTICE $nick :I will not log \002$chan\002 into itself - pick a different channel."
		return
	}

	if {![validchan $want]} {
		puthelp "NOTICE $nick :I am not on \002$want\002. Add it first with ${c}join $want"
		return
	}

	if {![botonchan $want]} {
		puthelp "NOTICE $nick :\002$want\002 is on my channel list but I am not in it right now - logging will start once I am."
	}

	set chanlog_dest($key) $want
	toggle_module $chan "chanlog" "on"

	puthelp "NOTICE $nick :\[OK\] $chan will now log to \002$want\002"
	putlog "$nick set the channel log for $chan to $want"
	chanlog $chan "MODULE" "$nick set the channel log to \002$want\002"
}

# /msg <bot> chanlog #channel [#dest|on|off]
proc chanlog:msg {nick uhost hand text} {
	global cc botnick

	set parts [split [string trim $text]]
	set chan [lindex $parts 0]
	set rest [join [lrange $parts 1 end] " "]

	if {![string match "#*" $chan]} {
		puthelp "NOTICE $nick :Usage: /msg $botnick chanlog <#channel> \[#logchannel|on|off\]"
		return
	}

	if {![validchan $chan]} {
		puthelp "NOTICE $nick :I am not on $chan"
		return
	}

	if {![matchattr $hand n] && ![matchattr $hand m|m $chan]} {
		puthelp "NOTICE $nick :You do not have access to change logging on $chan"
		chanlog $chan "DENIED" "$nick tried to change logging by /msg"
		return
	}

	chanlog:pub $nick $uhost $hand $chan $rest
}

###########################################################################
# SELF-REGISTRATION - /msg <bot> register
#
# Two steps on purpose:
#   1. register        -> the bot shows exactly what it would store and
#                         hands out a one-time token
#   2. verify <token>  -> the bot re-checks EVERYTHING and then registers
#
# The token has to be read out of a notice and typed back, which is what
# stops a script from registering nicks in bulk. Every check from step 1 is
# run again in step 2, because nick, host and userfile can all change in
# between.
#
# Hosts are the whole security story here. A user authed to X with usermode
# +x appears as <account>.users.undernet.org, which nobody else on the
# network can wear - that is the host worth storing. A bare ISP host is
# recycled by the ISP sooner or later, and whoever gets it next inherits the
# access, so the bot says so loudly before and after registering.
###########################################################################

# nick (lowercase) -> {token host handle issued}
array set register_pending {}

# host (lowercase) -> unixtime of last attempt
array set register_attempts {}

# 12 random characters - long enough that nobody guesses it inside the
# token's lifetime, short enough to retype from a notice
proc register:token {} {
	set chars "abcdefghijklmnopqrstuvwxyz0123456789"
	set token ""
	for {set i 0} {$i < 12} {incr i} {
		append token [string index $chars [rand [string length $chars]]]
	}
	return $token
}

# Drop tokens that have expired
proc register:cleanup {} {
	global register_pending cc

	set now [unixtime]
	foreach key [array names register_pending] {
		set issued [lindex $register_pending($key) 3]
		if {($now - $issued) > $cc(register_token_life)} {
			unset register_pending($key)
		}
	}
}

# Is this an Undernet hidden host? Those are the safe ones.
proc register:hidden_host {host} {
	return [string match -nocase "*.users.undernet.org" $host]
}

# First channel the bot shares with this nick ("" if none)
proc register:shared_chan {nick} {
	foreach chan [channels] {
		if {[onchan $nick $chan]} {
			return $chan
		}
	}
	return ""
}

# ident@host as the bot sees it on the channel, not as the user claims it
proc register:uhost_of {nick chan} {
	return [getchanhost $nick $chan]
}

# Just the host part of the above
proc register:host_of {nick chan} {
	set uhost [register:uhost_of $nick $chan]
	if {$uhost eq ""} {
		return ""
	}
	return [lindex [split $uhost "@"] end]
}

# A handle the userfile will accept
proc register:valid_handle {handle} {
	global cc

	if {[string length $handle] < 2 || [string length $handle] > $cc(register_handle_max)} {
		return 0
	}
	if {[string match "*\[ ,:@!*?#\]*" $handle]} {
		return 0
	}
	# a handle that starts with # would collide with a channel record
	if {[string index $handle 0] eq "#"} {
		return 0
	}
	return 1
}

# The advice the user gets every single time, before and after
proc register:advice {nick host} {
	global botnick

	if {[register:hidden_host $host]} {
		puthelp "NOTICE $nick :Good: your host is hidden by Undernet ($host). That host belongs to your X account, so nobody else can wear it."
		return
	}

	puthelp "NOTICE $nick :Read this first: your host is \002not\002 hidden. It is safer to auth with X and hide it \002before\002 registering:"
	puthelp "NOTICE $nick :  1. /msg x@channels.undernet.org login \002<account> <password>\002   (only ever send that to x@channels.undernet.org)"
	puthelp "NOTICE $nick :  2. /mode $nick +x     - your host becomes <account>.users.undernet.org"
	puthelp "NOTICE $nick :  3. come back and register again"
	puthelp "NOTICE $nick :Why: an ISP host like \002$host\002 gets handed to someone else when your IP changes, and they would inherit your access here."
}

proc register:msg {nick uhost hand text} {
	global cc botnick register_pending register_attempts

	if {!$cc(register_enabled)} {
		puthelp "NOTICE $nick :Self-registration is switched off. Ask a channel op to add you."
		return
	}

	register:cleanup

	# --- must be somewhere the bot can see them ---
	set chan [register:shared_chan $nick]
	if {$chan eq ""} {
		puthelp "NOTICE $nick :Join one of my channels first - I only register people I can see."
		return
	}

	# --- what host does the bot actually see? ---
	set host [register:host_of $nick $chan]
	if {$host eq "" || [string match "*\[*?\]*" $host]} {
		puthelp "NOTICE $nick :I cannot read your host right now. Try again in a moment."
		return
	}

	set mask "*!*@$host"
	set lhost [string tolower $host]
	set now [unixtime]

	# --- does the userfile already answer to this host? ---
	# Host-based identification cuts both ways: anyone sharing a registered
	# host IS that user as far as the bot is concerned. Say exactly that
	# rather than pretending to know which of them is asking.
	set owner [finduser "$nick![register:uhost_of $nick $chan]"]
	if {$owner ne "" && $owner ne "*"} {
		puthelp "NOTICE $nick :Your host (\002$host\002) already matches the user record \002$owner\002."
		puthelp "NOTICE $nick :If that record is yours you are registered already - check with /msg $botnick verify"
		puthelp "NOTICE $nick :If it is not yours, do \002not\002 register a second time - talk to a channel op."
		putlog "REGISTER: $nick ($host) asked to register, host already matches $owner"
		register:alert_ops "$nick ($host) asked to register - host already matches \002$owner\002"
		return
	}

	# --- pick the handle ---
	set words [split [string trim $text]]
	if {[llength $words] > 1} {
		puthelp "NOTICE $nick :One handle only, no spaces: /msg $botnick register <handle>"
		return
	}

	set handle [lindex $words 0]
	if {$handle eq ""} {
		set handle $nick
	}

	if {![register:valid_handle $handle]} {
		puthelp "NOTICE $nick :\002$handle\002 will not work as a handle. Use 2-$cc(register_handle_max) characters, no spaces or punctuation: /msg $botnick register <handle>"
		return
	}

	if {[validuser $handle]} {
		puthelp "NOTICE $nick :The handle \002$handle\002 is taken. Pick another: /msg $botnick register <handle>"
		return
	}

	# --- rate limit, checked last so a mistyped handle does not burn it ---
	if {[info exists register_attempts($lhost)]} {
		set wait [expr {$cc(register_cooldown) - ($now - $register_attempts($lhost))}]
		if {$wait > 0} {
			puthelp "NOTICE $nick :Too many registration attempts from your host. Try again in $wait seconds."
			return
		}
	}

	# --- everything checks out: advise, then hand out the token ---
	set token [register:token]
	set register_pending([string tolower $nick]) [list $token $host $handle $now]
	set register_attempts($lhost) $now

	register:advice $nick $host

	puthelp "NOTICE $nick :---"
	puthelp "NOTICE $nick :I would register \002$handle\002 with the hostmask \002$mask\002 and no access flags."
	puthelp "NOTICE $nick :To register please type: \002/msg $botnick verify $token\002"
	puthelp "NOTICE $nick :That code is good for [expr {$cc(register_token_life) / 60}] minutes. If you did not ask for this, ignore it - nothing has been saved."

	putlog "REGISTER: $nick ($host) requested handle $handle - token issued"
}

# Step two. Nothing from step one is trusted: it is all checked again.
proc register:confirm {nick uhost hand token} {
	global cc botnick register_pending

	register:cleanup

	set key [string tolower $nick]
	if {![info exists register_pending($key)]} {
		puthelp "NOTICE $nick :No registration is waiting for that nick, or the code expired. Start again with /msg $botnick register"
		return
	}

	foreach {want host handle issued} $register_pending($key) break

	if {$token ne $want} {
		puthelp "NOTICE $nick :That code is not right. Check the notice I sent you, or start again with /msg $botnick register"
		putlog "REGISTER: $nick sent a bad confirmation code"
		return
	}

	# --- re-run every check from step one ---
	set chan [register:shared_chan $nick]
	if {$chan eq ""} {
		puthelp "NOTICE $nick :Join one of my channels first - I only register people I can see."
		return
	}

	set now_host [register:host_of $nick $chan]
	if {$now_host eq ""} {
		puthelp "NOTICE $nick :I cannot read your host right now. Try again in a moment."
		return
	}

	if {![string equal -nocase $now_host $host]} {
		unset register_pending($key)
		puthelp "NOTICE $nick :Your host changed since you asked (\002$host\002 became \002$now_host\002), so I stopped. Start again with /msg $botnick register"
		putlog "REGISTER: $nick host changed mid-registration ($host -> $now_host) - refused"
		return
	}

	set owner [finduser "$nick![register:uhost_of $nick $chan]"]
	if {$owner ne "" && $owner ne "*"} {
		unset register_pending($key)
		puthelp "NOTICE $nick :Your host now matches the user record \002$owner\002. Nothing was changed - talk to a channel op."
		putlog "REGISTER: $nick refused at confirm - host $now_host matches $owner"
		return
	}

	if {[validuser $handle]} {
		unset register_pending($key)
		puthelp "NOTICE $nick :The handle \002$handle\002 was taken while you were deciding. Start again with /msg $botnick register <handle>"
		return
	}

	# --- register ---
	set mask "*!*@$now_host"
	adduser $handle $mask

	if {![validuser $handle]} {
		unset register_pending($key)
		puthelp "NOTICE $nick :Something went wrong writing your record. Tell a channel op."
		putlog "REGISTER: FAILED to add $handle ($mask) for $nick"
		return
	}

	if {$cc(register_flags) ne ""} {
		chattr $handle $cc(register_flags)
	}

	unset register_pending($key)
	save

	puthelp "NOTICE $nick :Registered. Handle \002$handle\002, hostmask \002$mask\002, no access flags - a channel op grants those."
	puthelp "NOTICE $nick :Check it any time with /msg $botnick verify"

	if {![register:hidden_host $now_host]} {
		puthelp "NOTICE $nick :Reminder: you registered an ISP host. When your IP changes you will lose access and someone else could gain it. Auth with X, set /mode $nick +x, and ask an op to move you to your hidden host."
	}

	putlog "REGISTER: $nick registered as $handle with $mask"
	register:alert_ops "$nick registered as \002$handle\002 ($mask)"
}

# Tell the ops channel what happened, so registrations are never silent
proc register:alert_ops {text} {
	chanlog "" "REGISTER" $text
}

###########################################################################
# VERIFY COMMAND - Check access levels, and confirm a registration
###########################################################################

proc verify:pub {nick host hand chan arg} {
	set target [lindex $arg 0]

	if {$target eq ""} {
		set target $nick
	}

	set target_hand [nick2hand $target $chan]

	if {$target_hand eq "*"} {
		puthelp "NOTICE $nick :\002$target\002 is not registered with the bot."
		return
	}

	if {![validuser $target_hand]} {
		puthelp "NOTICE $nick :\002$target\002 is not a registered user."
		return
	}

	set flags [chattr $target_hand $chan]
	set access [get_access_level $target_hand $chan]
	set hostmasks [getuser $target_hand hosts]

	puthelp "NOTICE $nick :\002Access Info for $target:\002"
	puthelp "NOTICE $nick :  Handle: $target_hand"
	puthelp "NOTICE $nick :  Level: $access"
	puthelp "NOTICE $nick :  Flags: $flags"
	puthelp "NOTICE $nick :  Hosts: $hostmasks"
}

# /msg <bot> verify              -> show my access
# /msg <bot> verify <nick>       -> show someone else's
# /msg <bot> verify <token>      -> finish a registration
proc verify:msg {nick host hand text} {
	global register_pending

	set arg [lindex [split [string trim $text]] 0]

	set chan [register:shared_chan $nick]

	# While a registration is pending for this nick, an argument that is not
	# somebody standing in the channel is a confirmation code - right or
	# wrong. Without this a mistyped code gets answered with "no such user",
	# which tells the person nothing about what actually went wrong.
	# Anything shaped like a code is also treated as one even with nothing
	# pending, so an expired code is answered with "it expired" rather than
	# with "no such user".
	if {$arg ne ""} {
		register:cleanup
		set key [string tolower $nick]
		set shaped_like_code [regexp {^[a-z0-9]{12}$} $arg]
		if {[info exists register_pending($key)] || $shaped_like_code} {
			if {$chan eq "" || ![onchan $arg $chan]} {
				register:confirm $nick $host $hand $arg
				return
			}
		}
	}

	if {$chan eq ""} {
		set chan "*"
	}
	verify:pub $nick $host $hand $chan $text
}

###########################################################################
# TOPIC SYSTEM - Set, Store, and Sync Channel Topics
###########################################################################

proc topic:pub {nick uhost hand chan arg} {
	global cc topic_storage
	
	if {![module_enabled $chan "topic"]} {
		putserv "NOTICE $nick :Topic module is disabled"
		return
	}
	
	set new_topic [lrange $arg 0 end]
	
	if {$new_topic eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]topic <new topic>"
		return
	}
	
	if {![botisop $chan]} {
		putserv "NOTICE $nick :I need to be op to change the topic"
		return
	}
	
	# Store topic for later sync
	set topic_storage($chan) $new_topic
	
	# Change topic on server
	putserv "TOPIC $chan :$new_topic"
	
	putlog "$nick changed topic in $chan to: $new_topic"
	chanlog $chan "ACCESS" "$nick set the topic: $new_topic"
	putserv "NOTICE $nick :Topic updated"
}

proc topic:sync {nick uhost hand chan arg} {
	global cc topic_storage
	
	if {![module_enabled $chan "topic"]} {
		putserv "NOTICE $nick :Topic module is disabled"
		return
	}
	
	# Check if we have a stored topic for this channel
	if {![info exists topic_storage($chan)]} {
		putserv "NOTICE $nick :No stored topic for $chan"
		return
	}
	
	if {![botisop $chan]} {
		putserv "NOTICE $nick :I need to be op to sync the topic"
		return
	}
	
	set stored_topic $topic_storage($chan)
	
	# Re-apply the stored topic
	putserv "TOPIC $chan :$stored_topic"
	
	putlog "$nick synced topic in $chan"
	chanlog $chan "ACCESS" "$nick re-synced the topic"
	putserv "NOTICE $nick :Topic re-synced"
}

###########################################################################
# ACTIVEVOICE MODULE - Auto-voice active users, devoice on idle
###########################################################################

# Is this nick exempt from ActiveVoice? ActiveVoice exists to voice/devoice
# NON-regulars: anyone who is a registered user carrying +n, +m, +M or +v
# (global or on this channel) manages their own voice and is left alone.
proc activevoice:exempt {nick chan} {
	global cc

	set hand [nick2hand $nick $chan]
	if {$hand eq "" || $hand eq "*"} {
		return 0
	}

	if {![validuser $hand]} {
		return 0
	}

	foreach flag $cc(activevoice_exempt_flags) {
		if {[matchattr $hand $flag|$flag $chan]} {
			return 1
		}
	}

	return 0
}

proc activevoice:track {nick host hand chan text} {
	global activevoice_data cc

	if {![module_enabled $chan "activevoice"]} {
		return
	}

	# Skip service bots
	if {[is_protected_bot $nick]} {
		return
	}

	# Skip ops (they usually already have voice or op)
	if {[isop $nick $chan]} {
		return
	}

	# Skip registered regulars (+n / +m / +v) - not our business
	if {[activevoice:exempt $nick $chan]} {
		return
	}

	# Update activity time for this user in this channel
	set activevoice_data($chan:$nick) [clock seconds]

	# Never voice anyone while the guard has the channel locked - under +m
	# that would hand the flood its voice back.
	if {[guard:locked $chan]} {
		return
	}

	# If user doesn't have voice yet, give it to them. pushmode batches it
	# with other mode changes, up to what the server allows per line.
	if {![isvoice $nick $chan] && [botisop $chan]} {
		pushmode $chan +v $nick
	}
}

proc activevoice:devoice_idle {min hour day weekday year} {
	global activevoice_data cc botnick

	# Check all channels
	foreach chan [channels] {
		# The devoicer needs BOTH modules: activevoice does the tracking,
		# idledevoice does the removing. Either one off = nobody is devoiced.
		if {![module_enabled $chan "idledevoice"]} {
			continue
		}

		if {![module_enabled $chan "activevoice"]} {
			continue
		}

		# Make sure bot is in channel and op'd
		if {![onchan $botnick $chan]} {
			continue
		}

		if {![botisop $chan]} {
			continue
		}

		# Calculate idle threshold
		set current_time [clock seconds]
		set idle_threshold [expr {$current_time - ($cc(activevoice_idle_minutes) * 60)}]

		# Check each voiced user
		foreach user [chanlist $chan] {
			# Skip if not voiced
			if {![isvoice $user $chan]} {
				continue
			}

			# Skip service bots
			if {[is_protected_bot $user]} {
				continue
			}

			# Skip ops
			if {[isop $user $chan]} {
				continue
			}

			# Skip registered regulars (+n / +m / +v) - their voice is theirs
			if {[activevoice:exempt $user $chan]} {
				continue
			}

			# No activity recorded yet (voiced before the script loaded, or
			# voiced by X). Start their clock NOW instead of devoicing them -
			# the old code devoiced every one of them on the first tick.
			if {![info exists activevoice_data($chan:$user)]} {
				set activevoice_data($chan:$user) $current_time
				continue
			}

			# Check if idle
			set last_activity $activevoice_data($chan:$user)
			if {$last_activity < $idle_threshold} {
				# User is idle, devoice them
				pushmode $chan -v $user
				unset activevoice_data($chan:$user)
			}
		}
	}
}

###########################################################################
# ENHANCED BAN COMMAND - Ban + Kick with reason
###########################################################################

proc ban:pub {nick uhost hand chan arg} {
	global botnick cc
	
	set target [lindex $arg 0]
	set reason [lrange $arg 1 end]
	
	if {$target eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]ban <nick> \[reason\]"
		return
	}
	
	# Check if target is online
	if {![onchan $target $chan]} {
		putserv "NOTICE $nick :$target is not on $chan"
		return
	}
	
	# Protect the bot
	if {[string tolower $target] eq [string tolower $botnick]} {
		putserv "KICK $chan $nick :Nice try buddy"
		return
	}
	
	# Protect owner/master flags
	set target_hand [nick2hand $target $chan]
	if {$target_hand ne "*" && [has_protected_flags $target_hand $chan]} {
		putserv "KICK $chan $nick :Can't ban someone with protected flags"
		return
	}
	
	# Create ban mask
	set hostmask [getchanhost $target $chan]
	if {$hostmask eq ""} {
		set ban_mask "*!*@*"
	} else {
		set ban_mask "*!*@[lindex [split $hostmask @] 1]"
	}
	
	# Apply ban
	putserv "MODE $chan +b $ban_mask"
	
	# Set default reason if none provided
	if {$reason eq ""} {
		set reason "banned by $nick"
	}
	
	# Kick with reason
	putserv "KICK $chan $target :$reason"
	
	# Log to backchannel
	putserv "PRIVMSG $cc(backchan) :\[BAN\] $nick banned $target ($ban_mask) - Reason: $reason"
	
	putlog "$nick banned $target ($ban_mask) from $chan - Reason: $reason"
	chanlog $chan "SANCTION" "$nick banned \002$target\002 ($ban_mask) - $reason"
}

proc ban:msg {nick host handle text} {
	global botnick

	set parts [split [string trim $text]]
	set chan [lindex $parts 0]
	set rest [join [lrange $parts 1 end]]

	if {![string match "#*" $chan]} {
		puthelp "NOTICE $nick :Usage: /msg $botnick ban <#channel> <nick> \[reason\]"
		return
	}

	if {![validchan $chan]} {
		puthelp "NOTICE $nick :I am not on $chan"
		return
	}

	if {![matchattr $handle n] && ![matchattr $handle noM|noM $chan]} {
		puthelp "NOTICE $nick :You do not have ban access on $chan"
		chanlog $chan "DENIED" "$nick tried to ban by /msg"
		return
	}

	ban:pub $nick $host $handle $chan $rest
}

###########################################################################
# DEOP WITH FLAG PROTECTION
###########################################################################

proc pub_do_deop {nick host handle channel args} {
	global botnick cc

	if {![access:require $nick $handle $channel [access:rank_of op] "deop anyone"]} {
		return
	}

	set who [mode:target $args $nick]

	if {![botisop $channel]} {
		putserv "NOTICE $nick :I am not op on $channel!"
		return
	}

	# Self-deop comes before the protections - a master taking his own op
	# off is not an attack on himself, so he must not be kicked for it.
	if {[string equal -nocase $who $nick]} {
		if {![isop $nick $channel]} {
			putserv "NOTICE $nick :You are not op'd on $channel"
			return
		}
		putserv "MODE $channel -o $nick"
		putlog "$nick deopped himself in $channel"
		return
	}

	# Protect service bots
	if {[is_protected_bot $who]} {
		putserv "NOTICE $nick :Cannot deop protected service bot $who"
		return
	}

	# Protect the bot itself
	if {[string equal -nocase $who $botnick]} {
		putserv "NOTICE $nick :I won't deop myself"
		return
	}

	if {![onchan $who $channel]} {
		putserv "NOTICE $nick :$who is not on $channel"
		return
	}

	# Protect users with protected flags
	set target_hand [nick2hand $who $channel]
	if {$target_hand ne "" && $target_hand ne "*" && [has_protected_flags $target_hand $channel]} {
		putserv "NOTICE $nick :Cannot deop user with protected flags"
		putserv "KICK $channel $nick :Nice try"
		return
	}

	# Check if target is actually op'd
	if {![isop $who $channel]} {
		putserv "NOTICE $nick :$who is not op'd on $channel"
		return
	}

	# Perform deop
	putserv "MODE $channel -o $who"
	putlog "$nick deopped $who from $channel"
	chanlog $channel "SANCTION" "$nick deopped \002$who\002"
}

###########################################################################
# DEVOICE WITH FLAG PROTECTION
###########################################################################

proc pub_do_devoice {nick host handle channel args} {
	global botnick cc

	if {![access:require $nick $handle $channel [access:rank_of voice] "devoice anyone"]} {
		return
	}

	set who [mode:target $args $nick]

	if {![botisop $channel]} {
		putserv "NOTICE $nick :I am not op on $channel!"
		return
	}

	# Self-devoice comes before the protections, same as !deop
	if {[string equal -nocase $who $nick]} {
		if {![isvoice $nick $channel]} {
			putserv "NOTICE $nick :You are not voiced on $channel"
			return
		}
		putserv "MODE $channel -v $nick"
		putlog "$nick devoiced himself in $channel"
		return
	}

	# Protect service bots
	if {[is_protected_bot $who]} {
		putserv "NOTICE $nick :Cannot devoice protected service bot $who"
		return
	}

	# Protect the bot
	if {[string equal -nocase $who $botnick]} {
		putserv "NOTICE $nick :I won't devoice myself"
		return
	}

	if {![onchan $who $channel]} {
		putserv "NOTICE $nick :$who is not on $channel"
		return
	}

	# Protect users with protected flags
	set target_hand [nick2hand $who $channel]
	if {$target_hand ne "" && $target_hand ne "*" && [has_protected_flags $target_hand $channel]} {
		putserv "NOTICE $nick :Cannot devoice user with protected flags"
		putserv "KICK $channel $nick :Nice try"
		return
	}

	# Check if actually voiced
	if {![isvoice $who $channel]} {
		putserv "NOTICE $nick :$who is not voiced on $channel"
		return
	}

	# Perform devoice
	putserv "MODE $channel -v $who"
	putlog "$nick devoiced $who in $channel"
	chanlog $channel "SANCTION" "$nick devoiced \002$who\002"
}

###########################################################################
# IDLE DEOP MODULE
###########################################################################

proc idledeop:pub {nick uhost hand chan arg} {
	global cc idledeop_config
	
	if {![module_enabled $chan "idledeop"]} {
		putserv "NOTICE $nick :Idle deop module is disabled"
		return
	}
	
	set target_chan [lindex $arg 0]
	set minutes [lindex $arg 1]
	
	if {$target_chan eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]idledeop <#channel> \[minutes\]"
		return
	}
	
	# Validate channel format
	if {![string match "#*" $target_chan]} {
		putserv "NOTICE $nick :Invalid channel format, must start with #"
		return
	}

	# Resolve to the exact case eggdrop tracks the channel under. module_enabled
	# keys module_settings by the real bind-context casing (e.g. #Canada); if
	# target_chan is stored as typed (e.g. #canada) the two never match and
	# idledeop:timer silently no-ops for the channel. See idledeop:timer.
	set real_chan ""
	foreach c [channels] {
		if {[string equal -nocase $c $target_chan]} {
			set real_chan $c
			break
		}
	}
	if {$real_chan eq ""} {
		putserv "NOTICE $nick :I'm not on $target_chan"
		return
	}
	set target_chan $real_chan

	# Set default if not specified
	if {$minutes eq ""} {
		set minutes $cc(idledeop_default_minutes)
	}
	
	# Validate hour input
	if {![string is integer -strict $minutes]} {
		putserv "NOTICE $nick :Hours must be a number"
		return
	}
	
	if {$minutes < 1 || $minutes > 2880} {
		putserv "NOTICE $nick :Hours must be between 1 and 48"
		return
	}
	
	# Store configuration
	set idledeop_config($target_chan) $minutes
	
	putserv "NOTICE $nick :Idle deop set for $target_chan: $minutes minutes"
	putserv "PRIVMSG $cc(backchan) :\[IDLEDEOP\] $nick configured idle deop for $target_chan: $minutes minutes"
	putlog "$nick set idle deop for $target_chan to $minutes minutes"
	chanlog $chan "MODULE" "$nick set idle deop for $target_chan to $minutes minutes"
}

proc idledeop:timer {min hour day weekday year} {
	global botnick cc idledeop_config
	
	# Check all channels with idledeop configured
	foreach chan [array names idledeop_config] {
		set minutes $idledeop_config($chan)
		
		if {![module_enabled $chan "idledeop"]} {
			continue
		}
		
		# Check if bot is in channel and op'd
		if {![onchan $botnick $chan]} {
			continue
		}
		
		if {![botisop $chan]} {
			continue
		}
		
		# Get current time
		set current_time [clock seconds]
		set idle_threshold $minutes
		
		# Get list of all users in channel
		foreach user [chanlist $chan] {
			# Skip service bots
			if {[is_protected_bot $user]} {
				continue
			}
			
			# Skip the bot itself
			if {[string tolower $user] eq [string tolower $botnick]} {
				continue
			}
			
			# Only process ops
			if {![isop $user $chan]} {
				continue
			}
			
			# Never touch anyone on the never-deop list
			if {[is_deop_exempt $user $chan]} {
				continue
			}

			# Check if user has protected flags
			set user_hand [nick2hand $user $chan]
			if {$user_hand ne "*" && [has_protected_flags $user_hand $chan]} {
				continue
			}
			
			# Get user's idle time
			set user_idle [getchanidle $user $chan]
			
			if {$user_idle >= $idle_threshold} {
				# User is idle, deop them
				putserv "MODE $chan -o $user"
				putserv "PRIVMSG $chan :$user has been deopped for idleness ($minutes minutes)"
				putlog "Idle deop: $user deopped from $chan (idle: $user_idle seconds)"
				chanlog $chan "SANCTION" "auto: deopped \002$user\002 after $user_idle minutes idle"
			}
		}
	}
}

###########################################################################
# EXISTING COMMANDS - FULL IMPLEMENTATIONS
###########################################################################

proc pub_do_invite {nick host handle channel text} {
	global botnick cc
	set who [lindex [split $text] 0]
	
	if {$who eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]invite <nick>"
		return
	}
	
	if {[string tolower $who] eq [string tolower $nick]} {
		putserv "NOTICE $nick :Really?"
		return
	}
	
	if {[string tolower $who] eq [string tolower $botnick]} {
		putserv "NOTICE $nick :Really?"
		return
	}
	
	if {[onchan $who $channel]} {
		putserv "NOTICE $nick :$who is already here"
		return
	}
	
	putserv "INVITE $who :$channel"
	putserv "NOTICE $nick :Done"
	putserv "NOTICE $who :You have been invited to $channel by $nick"
}

proc pub_do_op {nick host handle channel args} {
	global botnick

	if {![access:require $nick $handle $channel [access:rank_of op] "op anyone"]} {
		return
	}

	set who [mode:target $args $nick]

	if {![botisop $channel]} {
		putserv "NOTICE $nick :I am not op on $channel!"
		return
	}

	if {![onchan $who $channel]} {
		putserv "NOTICE $nick :$who is not on $channel"
		return
	}

	if {[isop $who $channel]} {
		if {[string equal -nocase $who $nick]} {
			putserv "NOTICE $nick :You are already op on $channel"
		} else {
			putserv "NOTICE $nick :$who is already op on $channel"
		}
		return
	}

	putserv "MODE $channel +o $who"
	putlog "$nick made me op $who in $channel"
	chanlog $channel "ACCESS" "$nick opped \002$who\002"
}

proc pub_do_op:msg {nick host handle text} {
	global botnick

	set parts [split [string trim $text]]
	set chan [lindex $parts 0]
	set who [lindex $parts 1]

	if {![string match "#*" $chan]} {
		puthelp "NOTICE $nick :Usage: /msg $botnick op <#channel> \[nick\]"
		return
	}

	if {![validchan $chan]} {
		puthelp "NOTICE $nick :I am not on $chan"
		return
	}

	if {$handle eq "" || $handle eq "*" || ![validuser $handle]} {
		puthelp "NOTICE $nick :You are not in my user list, so I cannot op anyone on $chan."
		return
	}

	set my_rank [access:rank $handle $chan]
	if {$my_rank < [access:rank_of op]} {
		if {$my_rank == 0} {
			puthelp "NOTICE $nick :You are not an \002Op\002 in the user list on $chan, so I cannot op anyone there."
		} else {
			puthelp "NOTICE $nick :You are \002[access:label $my_rank]\002 on $chan, not \002Op\002, so I cannot op anyone there."
		}
		chanlog $chan "DENIED" "$nick tried to op by /msg"
		return
	}

	pub_do_op $nick $host $handle $chan $who
}

proc pub_do_voice {nick host handle channel args} {
	global botnick

	if {![access:require $nick $handle $channel [access:rank_of voice] "voice anyone"]} {
		return
	}

	set who [mode:target $args $nick]

	if {![botisop $channel]} {
		putserv "NOTICE $nick :I am not op on $channel!"
		return
	}

	if {![onchan $who $channel]} {
		putserv "NOTICE $nick :$who is not on $channel"
		return
	}

	if {[isvoice $who $channel]} {
		if {[string equal -nocase $who $nick]} {
			putserv "NOTICE $nick :You are already voiced on $channel"
		} else {
			putserv "NOTICE $nick :$who is already voiced on $channel"
		}
		return
	}

	putserv "MODE $channel +v $who"
	putlog "$nick voiced $who in $channel"
	chanlog $channel "ACCESS" "$nick voiced \002$who\002"
}

proc pub_do_kick {nick uhost hand chan args} {
	global botnick cc
	
	set who [lindex $args 0]
	set why [lrange $args 1 end]
	
	if {![onchan $who $chan]} {
		putserv "NOTICE $nick :$who is not on $chan"
		return
	}
	
	if {[string tolower $who] eq [string tolower $botnick]} {
		putserv "KICK $chan $nick :nice try"
		return
	}
	
	if {$who eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]kick <nick> \[reason\]"
		return
	}
	
	if {[string tolower $who] eq [string tolower $nick]} {
		putserv "NOTICE $nick :no"
		return
	}
	
	set target_hand [nick2hand $who $chan]
	if {$target_hand ne "*" && [has_protected_flags $target_hand $chan]} {
		putserv "KICK $chan $nick :Nice Try"
		return
	}
	
	if {$why eq ""} {
		putserv "KICK $chan $who"
		set why "no reason given"
	} else {
		putserv "KICK $chan $who :$why"
	}

	putlog "$nick kicked $who from $chan - Reason: $why"
	chanlog $chan "SANCTION" "$nick kicked \002$who\002 - $why"
}

proc pub_do_unban {nick host handle channel args} {
	set who [lindex $args 0]
	
	if {$who eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]unban <*!*@host>"
		return
	}
	
	putserv "MODE $channel -b $who"
	putlog "$nick removed ban $who from $channel"
	chanlog $channel "SANCTION" "$nick removed ban $who"
}

proc pub_do_unperm {nick host handle channel args} {
	set who [lindex $args 0]
	
	if {$who eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]whitelist <*!*@host>"
		return
	}
	
	killchanban $channel $who
	putlog "$nick removed blacklist $who from $channel"
	chanlog $channel "SANCTION" "$nick whitelisted $who"
}

proc pub_do_bans {nick uhost hand chan text} {
	puthelp "NOTICE $nick :-Ban List for ($chan)-"
	foreach {a b c d} [banlist $chan] {
		puthelp "NOTICE $nick :- [format %-15s%-15s%-15s%-15s $a $b $c $d]"
	}
	puthelp "NOTICE $nick :-End of list-"
}

proc pub_do_perm {nick host handle channel args} {
	global botnick cc
	
	set who [lindex $args 0]
	set reason [lrange $args 1 end]
	
	if {$who eq ""} {
		putserv "NOTICE $nick :Usage: [string trim $cc(cmdchar)]blacklist <nick> \[reason\]"
		return
	}
	
	if {![onchan $who $channel]} {
		putserv "NOTICE $nick :$who is not on $channel"
		return
	}
	
	if {[string tolower $who] eq [string tolower $botnick]} {
		putserv "KICK $channel $nick :no"
		return
	}
	
	set target_hand [nick2hand $who $channel]
	if {$target_hand ne "*" && [has_protected_flags $target_hand $channel]} {
		putserv "NOTICE $who :$nick tried to blacklist you"
		putserv "NOTICE $nick :Not going to happen!"
		return
	}
	
	set ban [maskhost [getchanhost $who $channel]]
	newchanban $channel $ban $nick $reason
	stick $ban $channel
	putserv "KICK $channel $who :$reason"
	putserv "NOTICE $nick :Blacklisted: $who - $reason"
	putlog "$nick blacklisted $who ($ban) - Reason: $reason"
	chanlog $channel "SANCTION" "$nick blacklisted \002$who\002 ($ban) - $reason"
}

###########################################################################
# BOT AWAY MESSAGE
###########################################################################
# away_msg  = what the bot wants to be away with ("" = not away)
# away_sent = what it has told the server on this connection ("" = nothing)
# Both are globals, so a rehash keeps them and only sends AWAY when they differ.

# One line, no control characters, at most 160 characters (the network limit)
proc away:clean {text} {
	regsub -all {[\u0001-\u001f\u007f]} $text " " text
	regsub -all {\s+} $text " " text
	return [string range [string trim $text] 0 159]
}

# The saved file has two lines: 1 or 0 (away on or off), then the message
proc away:save {on msg} {
	global cc
	if {[catch {
		set fh [open $cc(away_file) w]
		puts $fh $on
		puts $fh $msg
		close $fh
	} err]} {
		putlog "lmao away: could not save $cc(away_file): $err"
		return 0
	}
	return 1
}

# Work out the wanted away message: the config first, then the saved file on top of it
proc away:load {} {
	global cc away_msg
	set away_msg ""
	if {$cc(away_enabled)} { set away_msg [away:clean $cc(away_message)] }
	if {![file exists $cc(away_file)]} { return }
	if {[catch {
		set fh [open $cc(away_file) r]
		set data [split [read $fh] "\n"]
		close $fh
	} err]} {
		putlog "lmao away: could not read $cc(away_file): $err"
		return
	}
	set on [string trim [lindex $data 0]]
	set saved [away:clean [join [lrange $data 1 end] " "]]
	if {$on eq "1" && $saved ne ""} {
		set away_msg $saved
	} elseif {$on eq "0"} {
		set away_msg ""
	}
}

# Tell the server, but only if it is connected and does not already have this message
proc away:apply {} {
	global away_msg away_sent server
	if {![info exists away_msg]} { return }
	if {![info exists server] || $server eq ""} { return }
	if {![info exists away_sent]} { set away_sent "" }
	if {$away_msg ne $away_sent} {
		putserv "AWAY :$away_msg"
		set away_sent $away_msg
	}
}

proc away:on_connect {type} {
	global away_sent
	set away_sent ""
	away:apply
	return 0
}

proc away:on_disconnect {type} {
	global away_sent
	set away_sent ""
	return 0
}

# 305 = "You are no longer marked as being away": the server has no message any more
proc away:raw305 {from keyword text} {
	global away_sent
	set away_sent ""
	return 0
}

proc pub_do_away {nick host handle channel args} {
	global cc away_msg
	set c [string trim $cc(cmdchar)]
	set why [away:clean [lindex $args 0]]

	if {$why eq ""} {
		if {$away_msg ne ""} {
			puthelp "NOTICE $nick :I am set away with: $away_msg"
		} else {
			puthelp "NOTICE $nick :I am not set away."
		}
		puthelp "NOTICE $nick :Try: ${c}away <message>  (it is saved, so it survives reboots - ${c}back turns it off)"
		return
	}

	set away_msg $why
	if {[away:save 1 $why]} {
		puthelp "NOTICE $nick :Away message set and saved: $why"
	} else {
		puthelp "NOTICE $nick :Away message set, but I could not save it to $cc(away_file), so a reboot will forget it."
	}
	chanlog "" "BOT" "$nick set the away message: $why"
	away:apply
}

proc pub_do_back {nick host handle channel args} {
	global cc away_msg
	set keep $away_msg
	if {$keep eq ""} { set keep [away:clean $cc(away_message)] }
	set away_msg ""
	away:save 0 $keep
	chanlog "" "BOT" "$nick cleared the away message"
	puthelp "NOTICE $nick :I'm back. The away message stays off, even after a reboot, until you use away again."
	away:apply
}

proc pub_do_away:msg {nick host handle text} {
	if {![matchattr $handle n]} {
		puthelp "NOTICE $nick :That command is owner only"
		putlog "$nick ($handle) tried away by /msg - denied"
		chanlog "" "DENIED" "$nick ($handle) tried \002away\002 by /msg"
		return
	}
	pub_do_away $nick $host $handle "msg" $text
}

proc pub_do_back:msg {nick host handle text} {
	owner:msg $nick $host $handle $text pub_do_back
}

bind msg - away pub_do_away:msg
bind msg - back pub_do_back:msg
bind evnt - init-server away:on_connect
bind evnt - disconnect-server away:on_disconnect
bind raw - 305 away:raw305

proc pub_do_mode {nick host handle channel args} {
	global cc
	set who [lindex $args 0]
	
	if {![botisop $channel]} {
		putserv "NOTICE $nick :I'm not op'd in $channel!"
		return
	}
	
	if {$who eq ""} {
		putserv "NOTICE $nick :Usage: [string trim $cc(cmdchar)]mode <modes>"
		return
	}
	
	putserv "MODE $channel $who"
	putlog "$nick set mode $who in $channel"
	chanlog $channel "ACCESS" "$nick set mode \002$who\002"
}

# Owner commands. The notice goes out BEFORE the action - restart and jump
# drop the send queue, so a notice queued afterwards is never delivered.
proc pub_do_rehash {nick host handle channel args} {
	putquick "NOTICE $nick :Rehashing TCL script(s)"
	putlog "$nick requested a rehash"
	chanlog "" "BOT" "$nick reloaded the scripts (rehash)"
	rehash
}

proc pub_do_restart {nick host handle channel args} {
	putquick "NOTICE $nick :Restarting bot"
	putlog "$nick requested a restart"
	chanlog "" "BOT" "$nick restarted the bot"
	restart
}

proc pub_do_jump {nick host handle channel args} {
	putquick "NOTICE $nick :Jumping servers"
	putlog "$nick requested a server jump"
	chanlog "" "BOT" "$nick made me jump servers"
	jump
}

proc pub_do_save {nick host handle channel args} {
	save
	putquick "NOTICE $nick :Saved user file and channel file"
	putlog "$nick requested a userfile save"
	chanlog "" "BOT" "$nick saved the userfile"
}

# /msg versions - owner only, checked here because msg binds match global flags
proc owner:msg {nick host handle text command} {
	if {![matchattr $handle n]} {
		puthelp "NOTICE $nick :That command is owner only"
		set what [string map {pub_do_ ""} $command]
		putlog "$nick ($handle) tried $what by /msg - denied"
		chanlog "" "DENIED" "$nick ($handle) tried \002$what\002 by /msg"
		return
	}
	$command $nick $host $handle "msg" ""
}

proc pub_do_rehash:msg {nick host handle text} {
	owner:msg $nick $host $handle $text pub_do_rehash
}

proc pub_do_restart:msg {nick host handle text} {
	owner:msg $nick $host $handle $text pub_do_restart
}

proc pub_do_jump:msg {nick host handle text} {
	owner:msg $nick $host $handle $text pub_do_jump
}

proc pub_do_save:msg {nick host handle text} {
	owner:msg $nick $host $handle $text pub_do_save
}

###########################################################################
# CHANSET - any eggdrop channel setting, not a fixed list
#
# Settings come from eggdrop itself (channel get), so built-in ones and the
# ones other scripts add with setudef all work with no list to maintain.
#   !chanset                  list every setting on this channel
#   !chanset +autoop          turn an on/off setting on (- turns it off)
#   !chanset flood-chan 10:60 give a setting a value
# need-* settings are refused: their value is Tcl code eggdrop runs.
###########################################################################

# Every setting on this channel as a name/value list, or "" when this eggdrop
# cannot list them (channel get with no setting needs eggdrop 1.9 or newer).
proc chanset:all {chan} {
	if {[catch {channel get $chan} all] || [llength $all] % 2} {
		return ""
	}
	return $all
}

proc chanset:list {nick chan} {
	global cc
	set all [chanset:all $chan]
	if {$all eq ""} {
		putserv "NOTICE $nick :This eggdrop cannot list channel settings (it needs eggdrop 1.9 or newer). [string trim $cc(cmdchar)]chanset +name / -name / name value still work."
		return
	}

	set flags {}
	set values {}
	foreach {name value} $all {
		if {[string match "need-*" $name]} {
			continue
		}
		if {$value eq "0" || $value eq "1"} {
			lappend flags [expr {$value ? "+" : "-"}]$name
		} else {
			lappend values "$name=[expr {$value eq "" ? {""} : $value}]"
		}
	}

	puthelp "NOTICE $nick :\002Channel settings for $chan\002 ([expr {[llength $flags] + [llength $values]}]):"
	foreach group [list $flags $values] {
		set line ""
		foreach item [lsort -dictionary $group] {
			if {[string length $line] + [string length $item] > 380} {
				puthelp "NOTICE $nick :[string trimright $line]"
				set line ""
			}
			append line "$item "
		}
		if {$line ne ""} {
			puthelp "NOTICE $nick :[string trimright $line]"
		}
	}
	puthelp "NOTICE $nick :Change one with [string trim $cc(cmdchar)]chanset +name, -name, or name value"
}

proc chanset:pub {nick uhost hand chan arg} {
	global cc
	set c [string trim $cc(cmdchar)]
	set words [split [string trim $arg]]
	set first [lindex $words 0]

	if {$first eq "" || [string equal -nocase $first "list"]} {
		chanset:list $nick $chan
		return
	}

	if {[string index $first 0] in {+ -}} {
		set name [string tolower [string range $first 1 end]]
		set opt [list "[string index $first 0]$name"]
		set want "[string index $first 0]$name"
	} else {
		set name [string tolower $first]
		set value [join [lrange $words 1 end]]
		set opt [list $name $value]
		set want "$name $value"
	}

	if {$name eq ""} {
		putserv "NOTICE $nick :\002Usage:\002 ${c}chanset \[list | +setting | -setting | setting value\]"
		return
	}

	if {[string match -nocase "need-*" $name]} {
		putserv "NOTICE $nick :\002$name\002 runs Tcl code inside the bot, so it can only be changed from the partyline."
		chanlog $chan "DENIED" "$nick tried ${c}chanset $want"
		return
	}

	# Unknown setting: say so and point at the ones that look close
	set all [chanset:all $chan]
	if {$all ne "" && [lsearch -exact [dict keys $all] $name] < 0} {
		set close {}
		foreach known [dict keys $all] {
			if {[string first [string tolower $name] $known] >= 0 || [string first $known [string tolower $name]] >= 0} {
				lappend close $known
			}
		}
		if {[llength $close]} {
			putserv "NOTICE $nick :There is no \002$name\002 setting on $chan. Did you mean: [join [lrange [lsort $close] 0 9] {, }]?"
		} else {
			putserv "NOTICE $nick :There is no \002$name\002 setting on $chan. Type ${c}chanset list to see them all."
		}
		return
	}

	if {[catch {channel set $chan {*}$opt} err]} {
		putserv "NOTICE $nick :Could not set \002$want\002 on $chan: $err"
		return
	}

	if {[catch {channel get $chan $name} now]} {
		putserv "NOTICE $nick :Sent \002$want\002 to $chan, but I could not read the setting back to check it."
		return
	}

	if {[string index $first 0] in {+ -}} {
		set shown [expr {$now eq "0" ? "-$name (off)" : "+$name (on)"}]
	} else {
		set shown "$name = $now"
	}
	putserv "NOTICE $nick :\[OK\] $chan: $shown"
	chanlog $chan "MODULE" "$nick set channel setting $shown"
}

proc comeback:pub {nick uhost hand chan text} {
	putserv "PART $chan :coming right back"
	utimer 2 [list putserv "JOIN $chan"]
}

# Deopped: X first, cycling only when it can actually help.
array set hop_last {}
proc hop:mode {nick uhost hand chan mc vict} {
	global hopondeop botnick hop_last

	if {$mc ne "-o" || ![isbotnick $vict] || [isbotnick $nick]} {
		return
	}

	if {[x:configured]} {
		putlog "lmao.tcl: deopped on $chan by $nick - asking X for op"
		x:need op $chan
		return
	}

	if {!$hopondeop || [llength [chanlist $chan]] > 1} {
		return
	}

	# Alone in the channel: a part and rejoin makes the server op us again.
	# Once a minute at most, so a flapping mode can never become a join flood.
	set key [string tolower $chan]
	set now [clock seconds]
	if {[info exists hop_last($key)] && $now - $hop_last($key) < 60} {
		return
	}
	set hop_last($key) $now
	putlog "lmao.tcl: deopped on $chan and alone there - cycling to get op back"
	putserv "PART $chan :brb"
	utimer 2 [list putserv "JOIN $chan"]
}


proc addchan:pub {nick uhost hand chan text} {
	global botnick cc
	set target [string trim [lindex $text 0]]
	if {$target eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]addchan <#channel>"
		return
	}
	if {![string match "#*" $target]} {
		putserv "NOTICE $nick :Channel must start with #"
		return
	}
	if {[validchan $target]} {
		if {[channel get $target inactive]} {
			channel set $target -inactive
			putserv "NOTICE $nick :$target was suspended. Unsuspended it and requested a join."
		} elseif {![onchan $botnick $target]} {
			putserv "JOIN :$target"
			putserv "NOTICE $nick :$target was already configured. Requested a join."
		} else {
			putserv "NOTICE $nick :$target is already configured and I am already there."
		}
	} else {
		channel add $target; x:setup_need $target
		putserv "JOIN :$target"
		putserv "NOTICE $nick :Added $target and joined it."
	}
	savechannels
	putlog "$nick added channel $target"
	chanlog "" "BOT" "$nick added channel \002$target\002"
}

# /msg <bot> addchan #channel - owner-only channel setup without DCC.
# MSG binds are intentionally open so an unauthorized owner is told why it
# failed instead of Eggdrop silently dropping the command.
proc addchan:msg {nick uhost hand text} {
	global botnick cc

	if {![matchattr $hand n]} {
		puthelp "NOTICE $nick :You do not have owner access for addchan."
		return
	}

	set target [string trim [lindex [split $text] 0]]
	if {$target eq ""} {
		puthelp "NOTICE $nick :Try: /msg $botnick addchan <#channel>"
		return
	}

	addchan:pub $nick $uhost $hand "" $target
}

proc delchan:pub {nick uhost hand chan text} {
	global botnick cc
	set target [string trim [lindex $text 0]]
	if {$target eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]delchan <#channel>"
		return
	}
	if {![validchan $target]} {
		putserv "NOTICE $nick :$target is not configured."
		return
	}
	if {[onchan $botnick $target]} { putserv "PART $target :Channel removed" }
	channel remove $target
	savechannels
	putserv "NOTICE $nick :Removed $target from the bot and chanfile. User accounts were not deleted."
	putlog "$nick removed channel $target"
	chanlog "" "BOT" "$nick removed channel \002$target\002 (users preserved)"
}

proc suschan:pub {nick uhost hand chan text} {
	global botnick cc
	set target [string trim [lindex $text 0]]
	if {$target eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]suschan <#channel>"
		return
	}
	if {![validchan $target]} {
		putserv "NOTICE $nick :$target is not configured."
		return
	}
	channel set $target +inactive
	savechannels
	putserv "NOTICE $nick :Suspended $target. I have left it, but the channel record and users were kept."
	putlog "$nick suspended channel $target"
	chanlog "" "BOT" "$nick suspended channel \002$target\002"
}

proc unsuschan:pub {nick uhost hand chan text} {
	global botnick cc
	set target [string trim [lindex $text 0]]
	if {$target eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]unsuschan <#channel>"
		return
	}
	if {![validchan $target]} {
		putserv "NOTICE $nick :$target is not configured."
		return
	}
	channel set $target -inactive
	putserv "JOIN :$target"
	savechannels
	putserv "NOTICE $nick :Unsuspended $target and requested a join."
	putlog "$nick unsuspended channel $target"
	chanlog "" "BOT" "$nick unsuspended channel \002$target\002"
}

proc join:pub {nick uhost hand chan text} {
	global cc
	set target [lindex $text 0]
	
	if {$target eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]join <#channel>"
		return
	}
	
	putlog "Joining $target at $nick's request"
	chanlog "" "BOT" "$nick had me join \002$target\002"
	putserv "JOIN :$target"
	channel add $target; x:setup_need $target
}

proc part:pub {nick uhost hand chan text} {
	global cc
	set target [lindex $text 0]
	
	if {$target eq ""} {
		putserv "NOTICE $nick :Try: [string trim $cc(cmdchar)]part <#channel>"
		return
	}
	
	if {![validchan $target]} {
		putserv "NOTICE $nick :$target is not a valid channel"
		return
	}
	
	putlog "Parting $target at $nick's request"
	chanlog "" "BOT" "$nick had me leave \002$target\002"
	putserv "PART $target :bye"
	channel remove $target
}

proc botnick:pub {mynick uhost hand chan text} {
	global cc
	set newnick $text
	
	if {$newnick eq ""} {
		putserv "NOTICE $mynick :Try: [string trim $cc(cmdchar)]botnick <newnick>"
		return
	}
	
	putlog "Changing botnick to $newnick"
	chanlog "" "BOT" "$mynick changed my nick to \002$newnick\002"
	putserv "NICK $newnick"
}

proc ctcp:reply {nick host hand dest key text} {
	global cc
	putserv "NOTICE $nick :$cc(version) - $cc(www)"
	return 0
}

proc uptime:pub {nick host handle chan arg} {
	global uptime
	set current_time [unixtime]
	set uptime_seconds [expr {$current_time - $uptime}]
	puthelp "NOTICE $nick :My uptime is [format_duration $uptime_seconds]"
}

proc format_duration {seconds} {
	set days [expr {$seconds / 86400}]
	set hours [expr {($seconds % 86400) / 3600}]
	set minutes [expr {($seconds % 3600) / 60}]
	set secs [expr {$seconds % 60}]
	
	return "${days}d ${hours}h ${minutes}m ${secs}s"
}

proc chattr:pub {nick uhost handle chan arg} {
	global cc
	set target [lindex $arg 0]
	set flags [lindex $arg 1]
	
	if {$target eq ""} {
		puthelp "NOTICE $nick :Usage: [string trim $cc(cmdchar)]chattr <handle> <+|->flags"
		return
	}
	
	if {![validuser $target]} {
		puthelp "NOTICE $nick :$target is not a valid user"
		return
	}
	
	if {$flags eq ""} {
		puthelp "NOTICE $nick :Usage: [string trim $cc(cmdchar)]chattr <handle> <+|->flags"
		return
	}
	
	chattr $target |$flags $chan
	puthelp "NOTICE $nick :Updated flags for $target"
	putlog "$nick set flags $flags on $target in $chan"
	chanlog $chan "ACCESS" "$nick set flags \002$flags\002 on \002$target\002"
}

proc adduser:pub {nick uhost handle chan arg} {
	global cc
	set newuser [lindex $arg 0]
	set hostmask [lindex $arg 1]
	
	if {$newuser eq ""} {
		puthelp "NOTICE $nick :Usage: [string trim $cc(cmdchar)]adduser <handle> \[*!*@host\]"
		return
	}
	
	if {[validuser $newuser]} {
		puthelp "NOTICE $nick :$newuser already exists!"
		return
	}
	
	if {$hostmask eq ""} {
		set hostmask "*!*@unknown.host"
	}
	
	adduser $newuser $hostmask
	puthelp "NOTICE $nick :User $newuser added"
	putlog "$nick added user $newuser ($hostmask)"
	chanlog $chan "ACCESS" "$nick added user \002$newuser\002 ($hostmask)"
}

proc deluser:pub {nick uhost handle chan arg} {
	global cc
	set user [lindex $arg 0]
	
	if {$user eq ""} {
		puthelp "NOTICE $nick :Usage: [string trim $cc(cmdchar)]deluser <handle>"
		return
	}
	
	if {![validuser $user]} {
		puthelp "NOTICE $nick :$user does not exist"
		return
	}
	
	deluser $user
	puthelp "NOTICE $nick :User $user deleted"
	putlog "$nick deleted user $user"
	chanlog $chan "ACCESS" "$nick deleted user \002$user\002"
}

###########################################################################
# USER MANAGEMENT - ACCESS LEVELS WITH HIERARCHY
#
# !addvoice !addmod !addop !addmaster and the matching !del... commands.
#
# A level is a position, not a pile of flags. Granting one takes every other
# level off the user first, so !addop on someone who was only voiced moves
# them up instead of leaving both behind, and !addvoice on an op moves them
# back down. Only the level actually held counts.
#
# Mod (+M) is a custom flag: kick and ban powers with no channel +o.
###########################################################################

# The single table everything below reads:
#   rank  name  marker  flags granted  label
# The marker identifies the level. The granted flags include the levels
# underneath, so an op keeps his autovoice if someone takes the op away.
set cc(levels) [list \
	[list 1 voice  v v   "Voice"] \
	[list 2 mod    M Mv  "Mod"] \
	[list 3 op     o ov  "Op"] \
	[list 4 master m mov "Master"] \
	[list 5 owner  n n   "Owner"] \
]

# Levels that can be handed out by command. Owner is recognised and
# protected but never granted this way - that stays a .chattr job on DCC.
set cc(grantable) [list voice mod op master]

# {rank name marker flags label} for a level name, "" if there is no such level
proc access:by_name {name} {
	global cc
	foreach row $cc(levels) {
		if {[lindex $row 1] eq $name} {
			return $row
		}
	}
	return ""
}

# The same row, looked up by rank
proc access:by_rank {rank} {
	global cc
	foreach row $cc(levels) {
		if {[lindex $row 0] == $rank} {
			return $row
		}
	}
	return ""
}

# "voice, mod, op, master, owner" - for usage messages
proc access:names {} {
	global cc
	set names [list]
	foreach row $cc(levels) {
		lappend names [lindex $row 1]
	}
	return [join $names ", "]
}

# Every marker flag in one string - what gets stripped before a level is set
proc access:all_markers {} {
	global cc
	set markers ""
	foreach row $cc(levels) {
		append markers [lindex $row 2]
	}
	return $markers
}

# Rank a handle holds on a channel, 0 when it holds none. Global and channel
# flags both count and the highest one wins, so a global master outranks a
# channel op the same way the rest of the script already treats him.
proc access:rank {handle chan} {
	global cc

	if {$handle eq "" || $handle eq "*" || ![validuser $handle]} {
		return 0
	}

	set flags [chattr $handle $chan]
	set best 0
	foreach row $cc(levels) {
		if {[string first [lindex $row 2] $flags] != -1 && [lindex $row 0] > $best} {
			set best [lindex $row 0]
		}
	}
	return $best
}

# "Op" / "Mod" / "None"
proc access:label {rank} {
	set row [access:by_rank $rank]
	if {$row eq ""} {
		return "None"
	}
	return [lindex $row 4]
}

# Move a handle to a level (0 removes all access). Every level flag comes off
# first, globally as well as on the channel, so a leftover global +o can never
# outlive the channel level it was meant to replace.
proc access:apply {handle chan rank} {
	set strip [access:all_markers]

	chattr $handle -$strip
	chattr $handle |-$strip $chan

	if {$rank > 0} {
		set row [access:by_rank $rank]
		chattr $handle |+[lindex $row 3] $chan
	}
}

# Turn what somebody typed into a handle.
#   - an existing handle is used as it stands
#   - a nick on the channel is resolved to the handle behind it
#   - a nick with no record is registered on the spot from the host he is
#     wearing right now, which is what makes !addvoice a one step command
# Returns the handle, or "" after explaining the problem to $nick.
proc access:handle {nick chan target {create 0}} {
	global cc

	if {[validuser $target]} {
		return $target
	}

	if {![onchan $target $chan]} {
		puthelp "NOTICE $nick :\002$target\002 is not a handle I know and is not on $chan - add the record first with [string trim $cc(cmdchar)]adduser"
		return ""
	}

	set hand [nick2hand $target $chan]
	if {$hand ne "" && $hand ne "*" && [validuser $hand]} {
		return $hand
	}

	if {!$create} {
		puthelp "NOTICE $nick :\002$target\002 is not registered with me, so there is no access to take away."
		return ""
	}

	# No record yet - build one from the host the bot can actually see
	if {![register:valid_handle $target]} {
		puthelp "NOTICE $nick :\002$target\002 will not do as a handle - add the user yourself with [string trim $cc(cmdchar)]adduser <handle> <*!*@host> first"
		return ""
	}

	set host [register:host_of $target $chan]
	if {$host eq ""} {
		puthelp "NOTICE $nick :I cannot read $target's host right now. Try again in a moment."
		return ""
	}

	set mask "*!*@$host"
	adduser $target $mask

	if {![validuser $target]} {
		puthelp "NOTICE $nick :Something went wrong writing a record for \002$target\002."
		putlog "ACCESS: failed to add user $target ($mask)"
		return ""
	}

	puthelp "NOTICE $nick :\002$target\002 had no record, so I made one: handle \002$target\002, hostmask \002$mask\002"
	if {![register:hidden_host $host]} {
		puthelp "NOTICE $nick :Note: that is an ISP host, not a hidden one. When their IP changes they lose access and the next person on that IP inherits it."
	}
	putlog "ACCESS: $nick had me add user $target ($mask)"
	chanlog $chan "ACCESS" "$nick added user \002$target\002 ($mask)"

	return $target
}

# Tell the user himself what changed, if he is around to hear it
proc access:tell {handle chan text} {
	set target [hand2nick $handle $chan]
	if {$target ne "" && $target ne "*"} {
		puthelp "NOTICE $target :$text"
	}
}
# Access welcome queue. Access changes can happen in bursts, so these
# notices are deliberately serialized. Only one welcome line enters the
# send queue every access_welcome_delay seconds across the whole bot.
set access_welcome_queue [list]

proc access:welcome:pump {} {
	global access_welcome_queue cc
	if {![llength $access_welcome_queue]} { return }
	set item [lindex $access_welcome_queue 0]
	set access_welcome_queue [lrange $access_welcome_queue 1 end]
	set handle [lindex $item 0]
	set chan [lindex $item 1]
	set line [lindex $item 2]
	set target [hand2nick $handle $chan]
	if {$target ne "" && $target ne "*"} {
		puthelp "NOTICE $target :$line"
	}
	if {[llength $access_welcome_queue]} {
		utimer $cc(access_welcome_delay) access:welcome:pump
	}
}

proc access:welcome:enqueue {handle chan line} {
	global access_welcome_queue
	set was_empty [expr {[llength $access_welcome_queue] == 0}]
	lappend access_welcome_queue [list $handle $chan $line]
	if {$was_empty} { access:welcome:pump }
}

proc access:welcome {handle chan level setter} {
	global cc botnick
	set target [hand2nick $handle $chan]
	if {$target eq "" || $target eq "*"} { return }
	set c [string trim $cc(cmdchar)]
	set label [access:label $level]
	access:welcome:enqueue $handle $chan "Welcome, $target! You have been granted $label access on $chan by $setter. Use ${c}help <command>"
	access:welcome:enqueue $handle $chan "You can also use /msg $botnick <command> to keep the channel clean."
}

# The rank of the person giving the order, or -1 when the bot has no record
# for him at all. Kept here so every command answers that the same way.
proc access:caller_rank {nick hand chan} {
	if {$hand eq "" || $hand eq "*" || ![validuser $hand]} {
		puthelp "NOTICE $nick :I have no user record for you, so I cannot check your access."
		return -1
	}
	return [access:rank $hand $chan]
}

# The rank a level name sits at, so the mode commands can ask for
# [access:rank_of op] instead of a bare 3.
proc access:rank_of {name} {
	set row [access:by_name $name]
	if {$row eq ""} {
		return 0
	}
	return [lindex $row 0]
}

# The gatekeeper for the channel mode commands - !op !deop !voice !devoice.
#
# Those four are bound open on purpose. A bind flag mask that does not match
# makes eggdrop drop the command without a word, which is what people mean
# when they say "I typed !op and nothing happened". The level is decided here
# instead, and every refusal is explained.
#
# Somebody the bot has never heard of gets a notice only - a stranger should
# not be able to make the bot talk to the channel. A registered user who is
# simply not high enough is told in the channel, which is where he asked.
proc access:require {nick hand chan need action} {
	global cc botnick

	set c [string trim $cc(cmdchar)]
	set needed [access:label $need]

	if {$hand eq "" || $hand eq "*" || ![validuser $hand]} {
		puthelp "NOTICE $nick :You are not in my user list, so I cannot $action on $chan. You need \002$needed\002 access - try /msg $botnick register, or ask a channel op to add you."
		return 0
	}

	set rank [access:rank $hand $chan]

	if {$rank < $need} {
		if {$rank == 0} {
			putserv "PRIVMSG $chan :$nick: you are not an \002$needed\002 in the user list on $chan, so I cannot $action. (${c}verify shows your access)"
		} else {
			putserv "PRIVMSG $chan :$nick: you are \002[access:label $rank]\002 on $chan, not \002$needed\002, so I cannot $action. (${c}verify shows your access)"
		}
		chanlog $chan "DENIED" "$nick ([access:label $rank]) tried to $action"
		return 0
	}

	return 1
}

# The nick a mode command was aimed at. Falls back to the caller when nothing
# was given, and keeps only the first word, so "!op bob joe" cannot turn into
# a MODE for a nick called "bob joe".
proc mode:target {arglist fallback} {
	set who [lindex [split [string trim [join $arglist " "]]] 0]
	if {$who eq ""} {
		return $fallback
	}
	return $who
}

# Put the channel modes where the access level says they belong.
#
# Op, Master and Owner wear +o. Voice and Mod wear +v. Somebody who has just
# lost his level loses both. Called straight after the flags are written, so
# !addop really does op the man and !delop really does take it back.
proc access:sync_modes {nick handle chan rank} {
	global botnick

	set who [hand2nick $handle $chan]
	if {$who eq "" || $who eq "*"} {
		return
	}

	if {[is_protected_bot $who] || [string equal -nocase $who $botnick]} {
		return
	}

	set want_op [expr {$rank >= [access:rank_of op]}]
	set want_voice [expr {$rank >= [access:rank_of voice]}]

	set changes [list]

	if {$want_op} {
		if {![isop $who $chan]} {
			lappend changes "+o"
		}
		# A voice sitting next to an op does no harm - leave it alone
	} else {
		if {[isop $who $chan]} {
			lappend changes "-o"
		}
		# isop still reads true here because the -o above has not landed
		# yet, so the voice is decided from the level being set instead.
		if {$want_voice} {
			if {![isvoice $who $chan]} {
				lappend changes "+v"
			}
		} else {
			if {[isvoice $who $chan]} {
				lappend changes "-v"
			}
		}
	}

	if {![llength $changes]} {
		return
	}

	if {![botisop $chan]} {
		puthelp "NOTICE $nick :I am not op on $chan, so I could not set [join $changes " "] on \002$who\002. The access itself is saved."
		return
	}

	# One MODE line: "-o+v bob bob" rather than two round trips
	set modes ""
	set targets [list]
	foreach m $changes {
		append modes $m
		lappend targets $who
	}

	putserv "MODE $chan $modes [join $targets " "]"
	putlog "ACCESS: $nick had me set [join $changes " "] on $who in $chan"
}

# !addvoice / !addmod / !addop / !addmaster all land here
proc access:add {nick hand chan arg level} {
	global cc

	set c [string trim $cc(cmdchar)]
	set row [access:by_name $level]
	foreach {rank lname marker fset label} $row break

	set target [lindex [split $arg] 0]
	if {$target eq ""} {
		puthelp "NOTICE $nick :Usage: ${c}add$level <nick|handle>"
		return
	}

	set my_rank [access:caller_rank $nick $hand $chan]
	if {$my_rank < 0} {
		return
	}

	# You can only hand out a level below your own
	if {$my_rank <= $rank} {
		puthelp "NOTICE $nick :You have to be above \002$label\002 yourself before you can give \002$label\002 to anyone."
		chanlog $chan "DENIED" "$nick tried to give \002$label\002 to \002$target\002"
		return
	}

	set target_hand [access:handle $nick $chan $target 1]
	if {$target_hand eq ""} {
		return
	}

	if {[string equal -nocase $target_hand $hand]} {
		puthelp "NOTICE $nick :You cannot change your own access."
		return
	}

	set old_rank [access:rank $target_hand $chan]

	# Never touch somebody standing level with you or above you
	if {$old_rank >= $my_rank} {
		puthelp "NOTICE $nick :\002$target_hand\002 is \002[access:label $old_rank]\002 - that is not below your own level, so I left it alone."
		chanlog $chan "DENIED" "$nick tried to set \002$target_hand\002 ([access:label $old_rank]) to \002$label\002"
		return
	}

	if {$old_rank == $rank} {
		puthelp "NOTICE $nick :\002$target_hand\002 is already \002$label\002 on $chan."
		return
	}

	access:apply $target_hand $chan $rank
	save

	if {$old_rank == 0} {
		set what "is now \002$label\002"
		set logged "gave \002$label\002 to"
	} elseif {$old_rank < $rank} {
		set what "moves up from \002[access:label $old_rank]\002 to \002$label\002"
		set logged "promoted \002[access:label $old_rank]\002 -> \002$label\002 for"
	} else {
		set what "moves down from \002[access:label $old_rank]\002 to \002$label\002"
		set logged "demoted \002[access:label $old_rank]\002 -> \002$label\002 for"
	}

	# Now make the channel agree with the user list
	access:sync_modes $nick $target_hand $chan $rank

	puthelp "NOTICE $nick :\[OK\] \002$target_hand\002 $what on $chan (flags: [chattr $target_hand $chan])"
	access:tell $target_hand $chan "Your access on $chan $what - set by $nick. Check it any time with ${c}verify"

	putlog "ACCESS: $nick set $target_hand to $label on $chan (was [access:label $old_rank])"
	chanlog $chan "ACCESS" "$nick $logged \002$target_hand\002"
}

# !delvoice / !delmod / !delop / !delmaster, and !delaccess for whatever
# level the user happens to hold. Level "" means "remove what they have".
proc access:del {nick hand chan arg level} {
	global cc

	set c [string trim $cc(cmdchar)]

	if {$level eq ""} {
		set rank 0
		set label "access"
		set command "delaccess"
	} else {
		set row [access:by_name $level]
		foreach {rank lname marker fset label} $row break
		set command "del$level"
	}

	set target [lindex [split $arg] 0]
	if {$target eq ""} {
		puthelp "NOTICE $nick :Usage: ${c}$command <nick|handle>"
		return
	}

	set my_rank [access:caller_rank $nick $hand $chan]
	if {$my_rank < 0} {
		return
	}

	if {$level ne "" && $my_rank <= $rank} {
		puthelp "NOTICE $nick :You have to be above \002$label\002 yourself before you can take \002$label\002 away."
		chanlog $chan "DENIED" "$nick tried to take \002$label\002 from \002$target\002"
		return
	}

	set target_hand [access:handle $nick $chan $target 0]
	if {$target_hand eq ""} {
		return
	}

	if {[string equal -nocase $target_hand $hand]} {
		puthelp "NOTICE $nick :You cannot change your own access."
		return
	}

	set old_rank [access:rank $target_hand $chan]

	if {$old_rank == 0} {
		puthelp "NOTICE $nick :\002$target_hand\002 has no access on $chan."
		return
	}

	if {$old_rank >= $my_rank} {
		puthelp "NOTICE $nick :\002$target_hand\002 is \002[access:label $old_rank]\002 - that is not below your own level, so I left it alone."
		chanlog $chan "DENIED" "$nick tried to remove access from \002$target_hand\002 ([access:label $old_rank])"
		return
	}

	# A level command only removes that exact level. Somebody who has been
	# moved up since is left alone rather than quietly knocked all the way
	# down by a stale !delvoice.
	if {$level ne "" && $old_rank != $rank} {
		set other [access:by_rank $old_rank]
		puthelp "NOTICE $nick :\002$target_hand\002 is \002[access:label $old_rank]\002, not \002$label\002 - use ${c}del[lindex $other 1] or ${c}delaccess"
		return
	}

	set had [access:label $old_rank]
	access:apply $target_hand $chan 0
	save

	# And take the matching channel modes back off him
	access:sync_modes $nick $target_hand $chan 0

	puthelp "NOTICE $nick :\[OK\] \002$target_hand\002 is no longer \002$had\002 on $chan - no access left (flags: [chattr $target_hand $chan])"
	access:tell $target_hand $chan "Your \002$had\002 access on $chan was removed by $nick."

	putlog "ACCESS: $nick removed $had from $target_hand on $chan"
	chanlog $chan "ACCESS" "$nick removed \002$had\002 from \002$target_hand\002"
}

# !access [level] - everybody the bot knows with a level on this channel
proc access:list {nick chan arg} {
	global cc

	set c [string trim $cc(cmdchar)]
	set only [string tolower [lindex [split $arg] 0]]

	if {$only ne "" && [access:by_name $only] eq ""} {
		puthelp "NOTICE $nick :Unknown level: $only - pick one of: [access:names]"
		return
	}

	# Collected per rank so the list comes out top down
	foreach row $cc(levels) {
		set found([lindex $row 0]) [list]
	}

	set total 0
	foreach handle [userlist] {
		set rank [access:rank $handle $chan]
		if {$rank == 0} {
			continue
		}
		if {$only ne "" && [lindex [access:by_name $only] 0] != $rank} {
			continue
		}
		lappend found($rank) $handle
		incr total
	}

	if {$total == 0} {
		if {$only ne ""} {
			puthelp "NOTICE $nick :Nobody holds \002$only\002 on $chan."
		} else {
			puthelp "NOTICE $nick :Nobody has access on $chan yet."
		}
		return
	}

	puthelp "NOTICE $nick :\002Access list for $chan\002 - $total with access:"

	foreach row [lsort -integer -decreasing -index 0 $cc(levels)] {
		set rank [lindex $row 0]
		if {![llength $found($rank)]} {
			continue
		}
		set line ""
		foreach handle [lsort $found($rank)] {
			if {[hand2nick $handle $chan] ne ""} {
				append line "$handle\[*\] "
			} else {
				append line "$handle "
			}
			if {[string length $line] > 300} {
				puthelp "NOTICE $nick :  \002[lindex $row 4]\002 ([lindex $row 2]): [string trimright $line]"
				set line ""
			}
		}
		if {$line ne ""} {
			puthelp "NOTICE $nick :  \002[lindex $row 4]\002 ([lindex $row 2]): [string trimright $line]"
		}
	}

	puthelp "NOTICE $nick :\[*\] = on the channel right now. ${c}verify <nick> shows one user in full."
}

###########################################################################
# USER MANAGEMENT - COMMANDS
###########################################################################

proc addvoice:pub {nick uhost hand chan arg}  { access:add $nick $hand $chan $arg voice }
proc addmod:pub {nick uhost hand chan arg}    { access:add $nick $hand $chan $arg mod }
proc addop:pub {nick uhost hand chan arg}     { access:add $nick $hand $chan $arg op }
proc addmaster:pub {nick uhost hand chan arg} { access:add $nick $hand $chan $arg master }

proc delvoice:pub {nick uhost hand chan arg}  { access:del $nick $hand $chan $arg voice }
proc delmod:pub {nick uhost hand chan arg}    { access:del $nick $hand $chan $arg mod }
proc delop:pub {nick uhost hand chan arg}     { access:del $nick $hand $chan $arg op }
proc delmaster:pub {nick uhost hand chan arg} { access:del $nick $hand $chan $arg master }

proc delaccess:pub {nick uhost hand chan arg} { access:del $nick $hand $chan $arg "" }

proc access:pub {nick uhost hand chan arg} { access:list $nick $chan $arg }

# Bound open, for the same reason as !op and friends: access:add and
# access:del decide the level themselves and explain every refusal, whereas a
# bind flag mask that does not match just makes the bot sit there. Someone who
# is not high enough is told so instead of being ignored.
bind pub - [string trim $cc(cmdchar)]addvoice addvoice:pub
bind pub - [string trim $cc(cmdchar)]delvoice delvoice:pub
bind pub - [string trim $cc(cmdchar)]addmod addmod:pub
bind pub - [string trim $cc(cmdchar)]delmod delmod:pub
bind pub - [string trim $cc(cmdchar)]addop addop:pub
bind pub - [string trim $cc(cmdchar)]delop delop:pub
bind pub - [string trim $cc(cmdchar)]addmaster addmaster:pub
bind pub - [string trim $cc(cmdchar)]delmaster delmaster:pub
bind pub - [string trim $cc(cmdchar)]delaccess delaccess:pub
bind pub nmMo|nmMo [string trim $cc(cmdchar)]access access:pub

proc pub_whois {nick uhost handle chan text} {
	global cc
	
	set target [lindex [split $text] 0]
	
	if {$target eq ""} {
		set target $nick
	}
	
	set target_hand [nick2hand $target $chan]
	
	if {$target_hand eq "*"} {
		puthelp "NOTICE $nick :$target is not registered with the bot"
		return
	}
	
	set flags [chattr $target_hand $chan]
	set access [get_access_level $target_hand $chan]
	
	puthelp "NOTICE $nick :WHOIS: $target ($target_hand) - Level: $access - Flags: $flags"
}

proc pub_version {nick uhost handle chan arg} {
	global cc
	puthelp "NOTICE $nick :$cc(version) available at: $cc(www)"
}

proc pub:alert {nick uhost handle chan arg} {
	global cc
	puthelp "PRIVMSG $cc(backchan) :\[OPS\] $nick calling ops in $chan: $arg"
}

proc pub_info {nick uhost handle chan arg} {
	if {$arg eq "none"} {
		setchaninfo $handle $chan "none"
		puthelp "NOTICE $nick :Infoline removed"
		return
	}
	
	if {$arg ne ""} {
		setchaninfo $handle $chan $arg
		puthelp "NOTICE $nick :Infoline set"
		return
	}
	
	set info [getchaninfo $handle $chan]
	if {$info eq ""} {
		puthelp "NOTICE $nick :You don't have an infoline set"
	} else {
		puthelp "NOTICE $nick :Your infoline: $info"
	}
}

proc pub:say {nick uhost handle chan arg} {
	puthelp "PRIVMSG $chan :$arg"
	chanlog $chan "ACCESS" "$nick made me say: $arg"
}

proc pub:global {nick uhost handle chan arg} {
	foreach c [channels] {
		puthelp "PRIVMSG $c :\[GLOBAL\] $arg"
	}
	putlog "$nick sent a global: $arg"
	chanlog "" "BOT" "$nick sent a global message: $arg"
}

proc pub:act {nick uhost handle chan arg} {
	puthelp "PRIVMSG $chan :\001ACTION $arg\001"
	chanlog $chan "ACCESS" "$nick made me act: $arg"
}

proc pub_do_bot {nick host hand channel text} {
	global cc botnick
	puthelp "NOTICE $nick :Trigger: [string trim $cc(cmdchar)]"
	puthelp "NOTICE $nick :Main support channel: $cc(backchan)"
	puthelp "NOTICE $nick :Type: /msg $botnick help - for full command list"
}

proc dobinddcckeepalive {handle idx text} {
	bind cron - "* * * * *" dcckeepalive
	putdcc $idx "Keep-alive enabled"
	return 0
}

proc dcckeepalive {min hour day weekday year} {
	if {[hand2idx DooubleTap] > 0} {
		putdcc [hand2idx DooubleTap] " "
	}
}

proc undobinddcckeepalive {handle idx text} {
	unbind cron - "* * * * *" dcckeepalive
	putdcc $idx "Keep-alive disabled"
	return 0
}

proc pub_lmao {handle idx text} {
	global cc
	putidx $idx "Welcome to lmao.tcl"
	putidx $idx "Version: $cc(version_number)"
	putidx $idx "Repository: $cc(www)"
	putidx $idx " "
	putidx $idx "Type 'help' on the partyline for more information"
}

###########################################################################
# SERVER CAPABILITIES - what the IRC server says it supports
#
# Eggdrop 1.9+ answers through isupport; older ones get it from the 005
# numeric, which is cached here. The fallbacks are what UnderNet's servers
# announce today, so the script is right even before the first 005 arrives.
###########################################################################

array set lmao_isupport {}

proc lmao:raw005 {from keyword text} {
	global lmao_isupport

	# "<ournick> TOKEN TOKEN=value ... :are supported by this server"
	foreach tok [lrange [split $text] 1 end] {
		if {[string index $tok 0] eq ":"} {
			break
		}
		set kv [split $tok "="]
		set lmao_isupport([string toupper [lindex $kv 0]]) [join [lrange $kv 1 end] "="]
	}
	return 0
}

proc lmao:isup {key default} {
	global lmao_isupport

	if {[info commands isupport] ne ""} {
		if {![catch {isupport get $key} value] && $value ne ""} {
			return $value
		}
	}
	if {[info exists lmao_isupport($key)] && $lmao_isupport($key) ne ""} {
		return $lmao_isupport($key)
	}
	return $default
}

# Every channel mode letter the server knows, e.g. "bklimnpstrDdRcC"
proc lmao:server_modes {} {
	return [string map {, ""} [lmao:isup CHANMODES "b,k,l,imnpstrDdRcC"]]
}

# Is this mode letter set on the channel right now?
proc lmao:chan_has_mode {chan letter} {
	set modes [lindex [split [getchanmode $chan]] 0]
	return [expr {[string first $letter $modes] >= 0}]
}

###########################################################################
# GUARD MODULE - flood and attack protection
#
# Four counters per channel, all "count:seconds" from the config:
#   guard_user_flood  one person saying too much  -> kick (and ban)
#   guard_line_flood  the channel as a whole       -> lock
#   guard_join_flood  joins (drones, clones)       -> lock
#   guard_nick_flood  nick changes                 -> lock
# Ops, registered regulars (n m o M v) and service bots are never counted.
#
# A lock sets guard_lock_modes (default +Dm). On ircu +D hides new joins
# until they are voiced or opped, and +m silences everyone without voice, so
# a drone wave neither shows up nor talks while regulars carry on. The lock
# lifts itself after guard_lock_minutes, and only removes the modes it set.
#   !lockdown [minutes]   lock now          (Op+)
#   !unlock               lift it early     (Op+)
#   !guard                state and limits  (Op+)
###########################################################################

array set guard_hits {}
array set guard_until {}
array set guard_added {}

# {count seconds} for a config limit, or "" when it is off or malformed
proc guard:limit {name} {
	global cc
	if {[info exists cc($name)] && [scan $cc($name) "%d:%d" count secs] == 2 && $count > 0 && $secs > 0} {
		return [list $count $secs]
	}
	return ""
}

# Count one event; 1 when that pushed it over the limit
proc guard:hit {key name} {
	global guard_hits
	set lim [guard:limit $name]
	if {$lim eq ""} {
		return 0
	}
	lassign $lim count secs

	set now [clock seconds]
	set keep {}
	if {[info exists guard_hits($key)]} {
		foreach t $guard_hits($key) {
			if {$now - $t < $secs} {
				lappend keep $t
			}
		}
	}
	lappend keep $now
	set guard_hits($key) $keep
	return [expr {[llength $keep] >= $count}]
}

proc guard:clear {key} {
	global guard_hits
	if {[info exists guard_hits($key)]} {
		unset guard_hits($key)
	}
}

proc guard:active {chan} {
	return [expr {[validchan $chan] && [module_enabled $chan "guard"]}]
}

proc guard:trusted {nick chan} {
	if {[isbotnick $nick] || [is_protected_bot $nick]} {
		return 1
	}
	if {[onchan $nick $chan] && [isop $nick $chan]} {
		return 1
	}
	set hand [nick2hand $nick $chan]
	if {$hand ne "" && $hand ne "*" && [matchattr $hand nmoMv|nmoMv $chan]} {
		return 1
	}
	return 0
}

proc guard:locked {chan} {
	global guard_until
	return [info exists guard_until([string tolower $chan])]
}

# A notice only the channel ops see (ircu STATUSMSG: NOTICE @#chan)
proc guard:tell_ops {chan text} {
	if {![validchan $chan] || ![botonchan $chan]} {
		return
	}
	if {[string first "@" [lmao:isup STATUSMSG "@+"]] >= 0} {
		putquick "NOTICE @$chan :$text"
	}
}

# One line said in the channel (message, action or notice)
proc guard:line {nick uhost chan} {
	if {![guard:active $chan] || [guard:trusted $nick $chan]} {
		return
	}
	set lc [string tolower $chan]
	set host [string tolower [lindex [split $uhost "@"] 1]]

	if {[guard:hit "$lc,user,$host" guard_user_flood]} {
		guard:clear "$lc,user,$host"
		guard:punish $nick $uhost $chan "flooding"
	}
	if {[guard:hit "$lc,lines" guard_line_flood]} {
		guard:clear "$lc,lines"
		guard:lock $chan "channel flood"
	}
}

proc guard:pubm {nick uhost hand chan text} {
	guard:line $nick $uhost $chan
	return 0
}

proc guard:notc {nick uhost hand text {dest ""}} {
	set dest [string trimleft $dest "@+"]
	if {$dest ne "" && [string index $dest 0] in {# &}} {
		guard:line $nick $uhost $dest
	}
	return 0
}

proc guard:action {nick uhost hand dest keyword text} {
	if {[string index $dest 0] in {# &}} {
		guard:line $nick $uhost $dest
	}
	return 0
}

proc guard:join {nick uhost hand chan} {
	if {[isbotnick $nick] || ![guard:active $chan] || [guard:trusted $nick $chan]} {
		return 0
	}
	set lc [string tolower $chan]
	if {[guard:hit "$lc,joins" guard_join_flood]} {
		guard:clear "$lc,joins"
		guard:lock $chan "join flood"
	}
	return 0
}

proc guard:nick {nick uhost hand chan newnick} {
	if {![guard:active $chan] || [guard:trusted $newnick $chan]} {
		return 0
	}
	set lc [string tolower $chan]
	if {[guard:hit "$lc,nicks" guard_nick_flood]} {
		guard:clear "$lc,nicks"
		guard:lock $chan "nick change flood"
	}
	return 0
}

# One person flooding: kick, and ban for a while when set to kickban
proc guard:punish {nick uhost chan why} {
	global cc botnick

	set action [string tolower $cc(guard_user_action)]
	set mask "*!*@[lindex [split $uhost "@"] 1]"

	if {$action eq "none" || ![onchan $nick $chan]} {
		return
	}
	if {![botisop $chan]} {
		chanlog $chan "GUARD" "$nick ($mask) is $why, but I am not opped"
		return
	}

	if {$action eq "kickban"} {
		newchanban $chan $mask $botnick "flood" $cc(guard_ban_minutes)
		set did "kickbanned $nick ($mask) for $cc(guard_ban_minutes) min"
	} else {
		set did "kicked $nick ($mask)"
	}
	putkick $chan $nick "Flood detected - slow down"
	chanlog $chan "SANCTION" "guard $did - $why"
}

proc guard:lock {chan reason {minutes ""}} {
	global cc guard_until guard_added

	if {$minutes eq ""} {
		set minutes $cc(guard_lock_minutes)
	}
	set key [string tolower $chan]
	set until [expr {[clock seconds] + $minutes * 60}]

	# Already locked: more trouble just keeps it locked longer
	if {[info exists guard_until($key)]} {
		if {$until > $guard_until($key)} {
			set guard_until($key) $until
		}
		return
	}

	# Only modes this server has, and only ones not set already - those are
	# not ours to remove later
	set supported [lmao:server_modes]
	set add ""
	foreach m [split $cc(guard_lock_modes) ""] {
		if {[string first $m $supported] >= 0 && ![lmao:chan_has_mode $chan $m]} {
			append add $m
		}
	}
	set guard_until($key) $until
	set guard_added($key) $add

	if {$add ne ""} {
		if {[botisop $chan]} {
			putquick "MODE $chan +$add"
		} elseif {[x:configured]} {
			putquick "PRIVMSG X :mode $chan +$add"
		}
	}

	set shown [expr {$add eq "" ? "modes already set" : "+$add"}]
	guard:tell_ops $chan "Guard: $reason - channel locked ($shown) for $minutes min. [string trim $cc(cmdchar)]unlock opens it early."
	chanlog $chan "GUARD" "$reason - locked ($shown) for $minutes min"
	putlog "lmao.tcl guard: $reason on $chan - locked ($shown)"
}

# 1 = unlocked, 0 = was not locked, -1 = cannot change modes right now
proc guard:unlock {chan why} {
	global guard_until guard_added

	set key [string tolower $chan]
	if {![info exists guard_until($key)]} {
		return 0
	}

	set remove ""
	if {[validchan $chan]} {
		foreach m [split $guard_added($key) ""] {
			if {[lmao:chan_has_mode $chan $m]} {
				append remove $m
			}
		}
	}

	if {$remove ne ""} {
		if {[botisop $chan]} {
			putquick "MODE $chan -$remove"
		} elseif {[x:configured]} {
			putquick "PRIVMSG X :mode $chan -$remove"
		} else {
			return -1
		}
	}

	unset guard_until($key) guard_added($key)
	set shown [expr {$remove eq "" ? "" : " (-$remove)"}]
	guard:tell_ops $chan "Guard: channel unlocked$shown - $why."
	chanlog $chan "GUARD" "unlocked$shown - $why"
	return 1
}

# Every 15 seconds: lift locks that have run out, forget old counts
proc guard:timer_check {} {
	global guard_until guard_hits

	set now [clock seconds]
	foreach key [array names guard_until] {
		if {$now >= $guard_until($key)} {
			guard:unlock $key "quiet for long enough"
		}
	}
	foreach key [array names guard_hits] {
		set last [lindex $guard_hits($key) end]
		if {$last eq "" || $now - $last > 300} {
			unset guard_hits($key)
		}
	}
	utimer 15 guard:timer_check
}

proc guard:lock:pub {nick uhost hand chan arg} {
	global cc guard_until

	if {![access:require $nick $hand $chan [access:rank_of op] "lock the channel"]} {
		return
	}
	set minutes [lindex [split [string trim $arg]] 0]
	if {$minutes eq ""} {
		set minutes $cc(guard_lock_minutes)
	}
	if {![string is integer -strict $minutes] || $minutes < 1 || $minutes > 1440} {
		putserv "NOTICE $nick :\002Usage:\002 [string trim $cc(cmdchar)]lockdown \[minutes\] (1 to 1440)"
		return
	}
	if {[guard:locked $chan]} {
		set guard_until([string tolower $chan]) [expr {[clock seconds] + $minutes * 60}]
		putserv "NOTICE $nick :$chan was already locked - it now stays locked for $minutes min."
		return
	}
	if {![botisop $chan] && ![x:configured]} {
		putserv "NOTICE $nick :I am not opped on $chan and have no X account, so I cannot set the lock modes."
		return
	}
	guard:lock $chan "locked by $nick" $minutes
}

proc guard:unlock:pub {nick uhost hand chan arg} {
	global cc

	if {![access:require $nick $hand $chan [access:rank_of op] "unlock the channel"]} {
		return
	}
	switch -- [guard:unlock $chan "opened by $nick"] {
		1  { putserv "NOTICE $nick :$chan is unlocked." }
		0  { putserv "NOTICE $nick :$chan is not locked by the guard. To clear modes by hand: [string trim $cc(cmdchar)]mode -[string trim $cc(guard_lock_modes)]" }
		-1 { putserv "NOTICE $nick :I am not opped on $chan and have no X account, so I cannot remove the lock modes yet. I will keep trying." }
	}
}

proc guard:status:pub {nick uhost hand chan arg} {
	global cc guard_until

	if {![access:require $nick $hand $chan [access:rank_of op] "see the guard"]} {
		return
	}
	set key [string tolower $chan]
	set state [expr {[module_enabled $chan "guard"] ? "ON" : "OFF"}]
	if {[info exists guard_until($key)]} {
		set left [expr {max(0, $guard_until($key) - [clock seconds])}]
		set lock "LOCKED for [expr {($left + 59) / 60}] more min"
	} else {
		set lock "not locked"
	}
	set usable ""
	foreach m [split $cc(guard_lock_modes) ""] {
		if {[string first $m [lmao:server_modes]] >= 0} {
			append usable $m
		}
	}
	putserv "NOTICE $nick :\002Guard on $chan:\002 $state, $lock. Lock modes: +$usable"
	putserv "NOTICE $nick :Limits (count:seconds) - one user: $cc(guard_user_flood) ($cc(guard_user_action)), channel: $cc(guard_line_flood), joins: $cc(guard_join_flood), nick changes: $cc(guard_nick_flood)"
}

###########################################################################
# X - UnderNet channel service
#
# All of this stays off until cc(x_user) and cc(x_pass) are set. Then the bot
# logs in to X when it connects, can hide its host with +x, and asks X when
# it is locked out of a channel through eggdrop's need-* hooks:
#   need-op                      -> X op #chan
#   need-unban                   -> X unban #chan <bot>
#   need-invite/need-limit/need-key -> X invite #chan
# On ircu an invite gets past +i, +l, +k, +b and +r alike. A need-* hook that
# was set by hand (not by this script) is never overwritten.
###########################################################################

array set x_last {}

proc x:configured {} {
	global cc
	return [expr {[info exists cc(x_user)] && $cc(x_user) ne "" && [info exists cc(x_pass)] && $cc(x_pass) ne ""}]
}

proc x:login {} {
	global cc
	if {![x:configured]} {
		return 0
	}
	# The secure form X asks for: the full address, never plain "X"
	putquick "PRIVMSG x@channels.undernet.org :login $cc(x_user) $cc(x_pass)"
	if {$cc(x_hide_host)} {
		utimer 5 x:hide
	}
	putlog "lmao.tcl: logging in to X as $cc(x_user)"
	return 1
}

proc x:hide {} {
	global botnick
	putquick "MODE $botnick +x"
}

proc x:on_connect {type} {
	x:login
	return 0
}

# Ask X for something, at most once every 30 seconds per channel and request
proc x:need {type chan} {
	global botnick x_last
	if {![x:configured]} {
		return
	}
	set key "$type,[string tolower $chan]"
	set now [clock seconds]
	if {[info exists x_last($key)] && $now - $x_last($key) < 30} {
		return
	}
	set x_last($key) $now

	switch -- $type {
		op      { putquick "PRIVMSG X :op $chan" }
		unban   { putquick "PRIVMSG X :unban $chan $botnick" }
		default { putquick "PRIVMSG X :invite $chan" }
	}
	putlog "lmao.tcl: asked X to $type on $chan"
}

proc x:setup_need {chan} {
	global cc
	if {![x:configured] || !$cc(x_rescue) || ![validchan $chan]} {
		return
	}
	foreach type {op unban invite limit key} {
		if {[catch {channel get $chan need-$type} current]} {
			continue
		}
		if {$current eq "" || [string match "x:need *" $current]} {
			set ask [expr {$type in {limit key} ? "invite" : $type}]
			catch {channel set $chan need-$type [list x:need $ask $chan]}
		}
	}
}

# X's answers (login result and so on) go to the partyline
proc x:notc {nick uhost hand text {dest ""}} {
	if {[string equal -nocase $nick "X"] && [string match -nocase "*@undernet.org" $uhost] && [isbotnick $dest]} {
		putlog "X: $text"
	}
	return 0
}

proc x:login:pub {nick uhost hand chan arg} {
	global cc
	if {![x:configured]} {
		putserv "NOTICE $nick :No X account is set. Fill in cc(x_user) and cc(x_pass) in the config, then .rehash."
		return
	}
	x:login
	putserv "NOTICE $nick :Sent the login to X for $cc(x_user). X's answer shows on the partyline."
}

###########################################################################
# TIMER INITIALIZATION - Set up recurring checks
###########################################################################

proc setup_timers {} {
	global cc

	# Kill any leftover timers first - without this a .rehash (or the old
	# re-arm bug) stacks duplicate timers until every check runs many times
	foreach t [utimers] {
		if {[lindex $t 1] in {idledeop:timer_check activevoice:timer_check guard:timer_check}} {
			killutimer [lindex $t 2]
		}
	}

	# Guard: lift expired locks and forget old flood counts
	utimer 15 guard:timer_check

	# Schedule idle deop check
	utimer $cc(idledeop_check_interval) idledeop:timer_check

	# Schedule activevoice idle devoice check
	utimer $cc(activevoice_check_interval) activevoice:timer_check
}

# Each check re-arms ONLY itself. Calling setup_timers here (as the old code
# did) doubled the number of running timers on every single tick.
proc idledeop:timer_check {} {
	global cc
	idledeop:timer 0 0 0 0 0
	utimer $cc(idledeop_check_interval) idledeop:timer_check
}

proc activevoice:timer_check {} {
	global cc
	activevoice:devoice_idle 0 0 0 0 0
	utimer $cc(activevoice_check_interval) activevoice:timer_check
}

###########################################################################
# INITIALIZATION
###########################################################################

# Initialize module system for main channel
init_channel_modules $cc(mainchan)

# Set up recurring timers
setup_timers

# Away message: load the wanted state and, on a rehash, set it if the bot is not away yet
away:load
away:apply

# X: point every channel's need-* hooks at X (only when an X account is set)
foreach lmao_chan [channels] {
	x:setup_need $lmao_chan
}
unset -nocomplain lmao_chan

putlog "$cc(version) - Complete production ready version"
putlog "Loaded successfully - ready to serve!"
