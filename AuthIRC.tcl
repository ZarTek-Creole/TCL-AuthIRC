##########################################################################
#
# Script Name: AuthIRC.tcl
#
# Information:
#	Ce script ce charge en premier dans la config eggdrop.
#	AuthIRC permet d'identifier votre robot aux services ANOPE.
#	Il s'auto-invite & join les channels desiré.
#
# Copyright 2008-2015 by ARTiSPRETiS (Familly) ARTiSPRETiS@GMail.Com
#
# Create by MalaGaM <MalaGaM.ARTiSPRETiS@GMail.Com>
#
#
##########################################################################

######################
#    CONFIGURATION    #
######################

set AuthIRC_My_Modes				"+iRShB-ws";		# Les modes "user" désiré.
set AuthIRC_Password				"botstats";			# Le mot de passe pour s'identifier à NickServ.
set AuthIRC_EMail					"ARTiSPRETiS@GMail.com";			# L'e-mail pour s'enregistrer.
set AuthIRC_Channels				"";					# La liste des channels a joindre/s'inviter.
set AuthIRC_TimeWaitBeforeRegNick	"40";				# Temps d'attente en secondes, avant s'enregistrer
set AuthIRC_InviteMe_AutoAddChan	"1";				# Si on invite votre robot sur un channel ou il est pas il auto join si la valeur est 1.
set AuthIRC_Chanserv_Invite			"1";				# S'invité via 'msg Chanserv invite #chan' ? Valeur 1 = Oui, 0 = Non
set AuthIRC_Invite_On_Nick			"";					# S'invite sur un autre robot. Commencer par le nick suivis de l'arguement a envoyer. Ex : "<NickBotToSend> invite <MyLogin> <MyPass>";
set AuthIRC_OperLine				"AKiraTana akiranetadmin";		# Si vous avez une Oper Line mettez le login pass. Ex: "<login> <Pass>";
######################
# CODE - Pas Toucher #
######################

bind notc - "*/msg NickServ IDENTIFY*" AuthIRC:Notice
bind notc - "*Password accepted*" AuthIRC:Invite
bind notc - "*Mot de passe accepté - vous êtes maintenant identifié*" AuthIRC:Invite
bind notc - "*Password authentication*" AuthIRC:Invite
bind notc - "*Found your hostname*" AuthIRC:Notice
bind notc - "*Couldn't resolve your hostname*" AuthIRC:Notice

# Register
bind notc - "*Your nick isn't registered*" AuthIRC:NS:Register:Wait
bind notc - "*Votre pseudo n'est pas enregistré*" AuthIRC:NS:Register:Wait
bind raw - 477  AuthIRC:NS:Register:Wait

# Ghost
bind notc - "*Nickname is already in use*" AuthIRC:NS:Ghost
bind raw - 433 AuthIRC:NS:Ghost

bind notc - "*Password incorrect*" AuthIRC:NS:WrongPass
bind notc - "*Your nickname is now being changed to*" AuthIRC:NS:NickChangeForced
bind notc - "*" AuthIRC:NS:AList
bind raw - 001 AuthIRC:Connect


bind raw - INVITE AuthIRC:NS:InviteMe
bind dcc n "reauth" AuthIRC:DCC:ReAuth
bind need - * AuthIRC:need-all
set ::AuthIRC_NS_AList		"0";
set ::AuthIRC_NS_Identified	"0";
set ::AuthIRC_NS_Invited	"0";

proc AuthIRC:need-all { chan type } {
	AuthIRC:NS:Identify
	switch -nocase -- $type {
		op { putquick "MODE $chan +o $::botnick"; }
		invite -
		limite -
		key {
			AuthIRC:CS:Invite $chan;
			putquick "INVITE $::botnick $chan";
		}
	}
}
proc AuthIRC:Connect { from keyword text } {
	AuthIRC:Notice "NickServ" host handle text $::botnick;
}

proc AuthIRC:NS:Ghost { from keyword text } {
	putlog "AuthIRC: Nick déjà utilié, utilisation de GHOST.";
	putquick "NICK ${::nick}2";
	putquick "privmsg NickServ :ghost $::nick $::AuthIRC_Password";
	utimer 5 { putquick "NICK ${::nick}"; }
}

proc AuthIRC:NS:WrongPass { nick host handle text dest } {
	putlog "AuthIRC: Mot de passe fournis incorrect, Changer le !";
}

proc AuthIRC:NS:NickChangeForced { nick host handle text dest } {
	putlog "AuthIRC: Ont ma forcer de changer de nick !";
	AuthIRC:DCC:ReAuth hand idx arg;
}

proc AuthIRC:NS:Register:Wait { nick host handle text dest } {
	putlog "AuthIRC: Je vais enregistrer mon Nick à NickServ dans $::AuthIRC_TimeWaitBeforeRegNick secondes.";
	set ::AuthIRC_NS_Identified	"0";
	utimer $::AuthIRC_TimeWaitBeforeRegNick { AuthIRC:NS:Register; }
}

proc AuthIRC:NS:Register { } {
	putlog "AuthIRC: Enregistrement du nick à NickServ.";
	putquick "privmsg NickServ :register $::AuthIRC_Password $::AuthIRC_EMail";
	AuthIRC:Invite nick host handle text dest;
}

proc AuthIRC:Notice { nick host handle text dest } {
	if { $nick == "NickServ" && $dest == $::botnick } {
		if { $::AuthIRC_NS_Identified == "0" } { set ::AuthIRC_NS_Identified	"1"; } else { return 0; }
		AuthIRC:NS:Identify
		putquick "MODE $::botnick $::AuthIRC_My_Modes";
	}
}

proc AuthIRC:DCC:ReAuth { hand idx arg } {
	putdcc $idx "AuthIRC: Re identification...\n";
	set ::AuthIRC_NS_Identified	"0";
	set ::AuthIRC_NS_Invited	"0";
	AuthIRC:NS:Identify
	putquick "MODE $::botnick $::AuthIRC_My_Modes";
	AuthIRC:Invite nick host handle text dest;
}

proc AuthIRC:Invite { nick host handle text dest } {
	if { $::AuthIRC_NS_Invited == "0" } { set ::AuthIRC_NS_Invited	"1"; } else { return 0; }
	AuthIRC:Manual:Channel:Add arg;
	AuthIRC:Auto:Channel:Add arg;
	if { $::AuthIRC_Invite_On_Nick != "" } {
		set BotNickToSend	[lindex $::AuthIRC_Invite_On_Nick 0];
		set ArgsToSend		[lrange $::AuthIRC_Invite_On_Nick 1 end];
		putlog "AuthIRC: Je contacte $BotNickToSend avec '$ArgsToSend'";
		putquick "privmsg $BotNickToSend :$ArgsToSend";
	}
	foreach AuthIRC_Chan [channels] {
		AuthIRC:CS:Invite $Channel_to_add;
		putquick "JOIN $AuthIRC_Chan";
	}
	if { $::AuthIRC_OperLine != "" } {
		putlog "AuthIRC: J' utilise ma OperLine.";
		putquick "oper $::AuthIRC_OperLine";
		putquick "privmsg operserv :set superadmin on";
	}
	putlog "AuthIRC: Fin du processus.";
}

proc AuthIRC:Auto:Channel:Add { arg } {
	set ::AuthIRC_NS_AList		"1";
	putquick "privmsg NickServ :alist";
	utimer 30 {set ::AuthIRC_NS_AList "1"}
}

proc AuthIRC:Manual:Channel:Add { arg } {
	foreach AuthIRC_Chan $::AuthIRC_Channels { channel add $AuthIRC_Chan; }
}
proc AuthIRC:NS:Identify { } {
	putlog "AuthIRC: Je m'identifie à NickServ'";
	putquick "privmsg NickServ :identify $::AuthIRC_Password";
}

proc AuthIRC:NS:AList { nick host handle text dest } {
	if { $nick == "NickServ" } {
		regsub -all " +" $text " " text;
		if { $::AuthIRC_NS_AList == "1" } {
			for { set x 0 } { $x < 10 } { incr x } {
				if { [string match -nocase "#*" [lindex $text $x]] } {
					set Channel_to_add [lindex $text $x];
					putlog "AuthIRC: Add Channel Name :$Channel_to_add";
					channel add $Channel_to_add;
					AuthIRC:CS:Invite $Channel_to_add;
				}
			}
		}
	}
}
proc AuthIRC:CS:Invite { Channel } {
	if { $::AuthIRC_Chanserv_Invite == 1 } {
		putlog "AuthIRC: Je m'invite sur le channel '$Channel'";
		putquick "privmsg ChanServ :invite $Channel";
	}
}
proc AuthIRC:NS:InviteMe { from keyword text } {
	if { $::AuthIRC_InviteMe_AutoAddChan == "1" } { channel add [lindex [split $text :] 1]; }
}

putlog "AuthIRC V1.2 (14/04/2012) ARTiSPRETiS (ARTiSPRETiS@GMail.Com) by MalaGaM.";