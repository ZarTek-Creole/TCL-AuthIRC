###############################################################################################
#
#	Name		:
#		TCL-AuthIRC.tcl
#
#	Description	:
#		AuthIRC is a script for registration and identification with IRC services,
#		It allows to auto-operate, to auto-add rooms, to auto-invite, etc.
#		Ideal to be used with ANOPE, or to invite you via another robot, etc.
#
#		AuthIRC est un script d'enregistrement et d'identification aupres de services IRC,
#		Il permet de s'auto-oper, d'auto-ajouter des salons, d'auto-s'inviter, etc
#		Idéale pour être utiliser avec ANOPE, ou pour vous inviter via un autre robots, etc
#
#	Donation	:
#		https://github.com/ZarTek-Creole/DONATE
#
#	Auteur		:
#		ZarTek @ https://github.com/ZarTek-Creole
#
#	Website		:
#		https://github.com/ZarTek-Creole/TCL-AuthIRC
#
#	Support		:
#		https://github.com/ZarTek-Creole/TCL-AuthIRC/issues
#
#	Docs		:
#		https://github.com/ZarTek-Creole/TCL-AuthIRC/wiki
#
#	Thanks to	:
#		All donators, testers, repporters & contributors
#
###############################################################################################
namespace eval ::AuthIRC {
	set PATH_SCRIPT [file dirname [file normalize [info script]]]
	if { [ catch {
		source ${PATH_SCRIPT}/AuthIRC.conf
	} err ] } {
		putlog "::AuthIRC > Error: Chargement du fichier '${PATH_SCRIPT}/AuthIRC.conf' > $err"
		return -code error $err
	}
	######################
	#      VARS INIT     #
	######################
	variable NS_AList				0;
	variable NS_Identified			0;
	variable NS_requestident		0;
	variable NS_Invited				0;
	array set Script {
		"Name"		"TCL-AuthIRC.tcl"
		"Auteur"	"ZarTek-Creole @ https://github.com/ZarTek-Creole"
		"Version"	"1.3.2"
	}

	dict set ANONNCE Password_accepted en_US "Password accepted - you are now recognized."
	dict set ANONNCE Password_accepted ca_ES "Clau aceptada - Has estat reconegut."
	dict set ANONNCE Password_accepted de_DE "Passwort akzeptiert - Du bist jetzt angemeldet."
	dict set ANONNCE Password_accepted el_GR "Ο κωδικός έγινε δεκτός - τώρα είσαι αναγνωρισμένος."
	dict set ANONNCE Password_accepted es_ES "Contraseña aceptada - Has sido reconocido."
	dict set ANONNCE Password_accepted fr_FR "Mot de passe accepté - vous êtes maintenant identifié."
	dict set ANONNCE Password_accepted hu_HU "Jelszavad elfogadva - azonosítás sikeres."
	dict set ANONNCE Password_accepted it_IT "Password accettata - adesso sei riconosciuto."
	dict set ANONNCE Password_accepted nl_NL "Wachtwoord aanvaard - je wordt nu herkend."
	dict set ANONNCE Password_accepted pl_PL "Hasło przyjęte - jesteś zidentyfikowany(a)."
	dict set ANONNCE Password_accepted pt_PT "Senha aceita - você está agora reconhecido."
	dict set ANONNCE Password_accepted ru_RU "Пароль принят - вы признаны как владелец ника."
	dict set ANONNCE Password_accepted tr_TR "Şifre kabul edildi."
}
######################
# CODE - Pas Toucher #
######################
proc ::AuthIRC::INIT { } {

	# iDENT
	# Si la variable SASL n'existe pas ou vaut 1, appelle la procédure SASL
	if { ![info exists ::AuthIRC::SASL] || ${::AuthIRC::SASL} == 1 } { ::AuthIRC::SASL; }

	# Lorsque le serveur envoie un message de bienvenue (raw 001), appelle la procédure Connect
	## 001 : Welcome to the Internet Relay Network nickname
	bind raw - 001 ::AuthIRC::Connect

	# Lorsque le serveur indique qu'on ne peut pas rejoindre un channel (raw 473), appelle la procédure Connect
	## 473 channel : Cannot join channel (+i)
	bind raw - 473 ::AuthIRC::Connect

	# IDENTIFIED
	# Récupère les informations de localisation et de message du dictionnaire ANONNCE pour l'événement "Password_accepted"
	# et lie l'événement notc "*message*" à la procédure IDENTIFIED
	dict map { locale message } [dict get ${::AuthIRC::ANONNCE} Password_accepted] {
		bind notc - "*${message}*" ::AuthIRC::IDENTIFIED
	}
	#Lorsque le serveur envoie un message indiquant que l'on est identifié (raw 307), appelle la procédure IDENTIFIED
	bind raw - 307 :AuthIRC::IDENTIFIED

	# NEED RESGITER
	#Lorsque le serveur envoie un message indiquant qu'on doit s'enregistrer (notc "Your nick isn't registered" ou "Votre pseudo n'est pas enregistré"), appelle la procédure NS:Register:Wait
	bind notc - "*Your nick isn't registered*" ::AuthIRC::NS:Register:Wait
	bind notc - "*Votre pseudo n'est pas enregistré*" ::AuthIRC::NS:Register:Wait

	## 477 channel : You need a registered nick to join that channel.
	# Lorsque le serveur indique qu'on a besoin d'un nick enregistré pour rejoindre un channel (raw 477), appelle la procédure NS:Register:Wait
	bind raw - 477  ::AuthIRC::NS:Register:Wait

	## 451 command : Register first.
	# Lorsque le serveur indique qu'on doit d'abord s'enregistrer pour utiliser une commande (raw 451), appelle la procédure NS:Register:Wait
	bind raw - 451  ::AuthIRC::NS:Register:Wait

	## 512 : Authorization required to use Registered Nickname nick
	# Lorsque le serveur indique qu'une authorization est requise pour utiliser un nick enregistré (raw 512), appelle la procédure NS:Register:Wait
	bind raw - 512  ::AuthIRC::NS:Register:Wait

	# Ghost
	## 433 nickname : Nickname is already in use.
	# Lorsque le serveur indique que le nick est déjà utilisé (notc "Nickname is already in use" ou raw 433), appelle la procédure NS:Ghost
	bind notc - "*Nickname is already in use*" ::AuthIRC::NS:Ghost
	bind raw - 433 ::AuthIRC::NS:Ghost

	# Lorsque le serveur indique que le mot de passe est incorrect (notc "Password incorrect"), appelle la procédure NS:WrongPass
	bind notc - "*Password incorrect*" ::AuthIRC::NS:WrongPass
	# Lorsque le serveur indique qu'on est forcé à changer de nick (notc "Your nickname is now being changed to"), appelle la procédure NS:NickChangeForced
	bind notc - "*Your nickname is now being changed to*" ::AuthIRC::NS:NickChangeForced
	# Lorsque le serveur envoie une liste de channels (notc "*"), appelle la procédure NS:AList
	bind notc - "*" ::AuthIRC::NS:AList


	# Invitation sur un salon
	# Lorsque le serveur envoie une invitation à rejoindre un salon (raw INVITE), appelle la procédure OnINVITE
	bind raw - INVITE ::AuthIRC::OnINVITE
	#Lorsque le bot reçoit une commande "reauth" via DCC, appelle la procédure DCC:ReAuth
	bind dcc n "reauth" ::AuthIRC::DCC:ReAuth
	# bind need - * ::AuthIRC::need-all

	putlog "${::AuthIRC::Script(Name)} ${::AuthIRC::Script(Version)} by ${::AuthIRC::Script(Auteur)} loaded."
}
proc ::AuthIRC::SASL {  } {
	set ::sasl 				1
	set ::sasl-username		${::nick}
	set ::sasl-password 	${::AuthIRC::U_Password}
	set ::sasl-continue 	1
	set ::sasl-mechanism 	0
}
proc ::AuthIRC::plog { message } {
	if { [info exists ${::AuthIRC::verbose}] &&  [info exists ${::AuthIRC::verbose}] == 1 } {
		putlog "::AuthIRC : ${message}"
	}
}
proc ::AuthIRC::Connect { args } {
	if { ![info exists ::AuthIRC::NS_requestident] || ${::AuthIRC::NS_requestident} == "0" } {
		set ::AuthIRC::NS_requestident 1;
		::AuthIRC::plog "Password accepted - you are now recognized."
	} else {
		::AuthIRC::plog "Demande d'identification déjà envoyer."
		return 0;
	}
	::AuthIRC::plog [format "Je m'identifie sur %s avec la commande : %s." ${::AuthIRC::NickServName} ${::AuthIRC::NickServIdentify}]
	putnow "PRIVMSG ${::AuthIRC::NickServName} :${::AuthIRC::NickServIdentify} ${::AuthIRC::U_Password}"
	if { [info exists ::AuthIRC::OperLine] && ${::AuthIRC::OperLine} != "" } {
		::AuthIRC::plog "J'utilise ma operline."
		putnow "oper ${::AuthIRC::OperLine}";
		if { [info exists ::AuthIRC::OperSUPERADMIN] && ${::AuthIRC::OperSUPERADMIN} == 1 } {
			putquick "PRIVMSG ${::AuthIRC::OperServName} :set superadmin on";
		}
	}
	# Invité sur des nicks
	if { [info exists ::AuthIRC::Chanserv_Invite] && ${::AuthIRC::Chanserv_Invite} != "" } {
		foreach { channelname } [split ${::AuthIRC::Chanserv_Invite}] {
			if { ![validchan ${channelname}] && $channelname != "" } {
				::AuthIRC::plog [format "Demande à '%s' de m'inviter sur %s." ${::AuthIRC::ChanServName} ${channelname}]
				putserv "PRIVMSG ${::AuthIRC::ChanServName} :invite ${channelname}"
				putserv "JOIN ${channelname}";
			}
		}
	}
}
proc ::AuthIRC::IDENTIFIED { } {
	# Processus d'invite
	if { ![info exists ::AuthIRC::NS_Identified] || ${::AuthIRC::NS_Identified} == "0" } {
		set ::AuthIRC::NS_Identified 1;
		::AuthIRC::plog "Password accepted - you are now recognized."
	} else {
		::AuthIRC::plog "Vous êtes déjà identifier."
		return 0;
	}
	# Ajout des salons depuis la list variable Chanserv_Invite
	if { [info exists ::AuthIRC::Channels_list] && ${::AuthIRC::Channels_list} != "" } {
		foreach { channelname } [split ${::AuthIRC::Channels_list}] {
			if { ![validchan ${channelname}] && $channelname != "" } {
				::AuthIRC::plog [format "Ajout du salon '%s' à ma liste." ${channelname}]
				channel add ${channelname}
				putserv "JOIN ${channelname}";
			}
		}
	}
	# Invite via chanserv invite #salon
	if { [info exists ::AuthIRC::Chanserv_Invite] && ${::AuthIRC::Chanserv_Invite} != "" } {
		foreach { channelname } [split ${::AuthIRC::Chanserv_Invite}] {
			if { ![validchan ${channelname}] && $channelname != "" } {
				::AuthIRC::plog [format "Demande à '%s' de m'inviter sur %s." ${::AuthIRC::ChanServName} ${channelname}]
				putserv "PRIVMSG ${::AuthIRC::ChanServName} :invite ${channelname}"
				putserv "JOIN ${channelname}";
			}
		}
	}

# Utilisation de la commande ALIST de nickserv pour decouvrire ma liste d'acess
if { [info exists ::AuthIRC::NickServ_AList] && ${::AuthIRC::NickServ_AList} == 1 } {
	::AuthIRC::plog [format "Envois de la commande ALIST sur %s." ${::AuthIRC::NickServName}]
	putserv "PRIVMSG ${::AuthIRC::NickServName} :ALIST"
}
# Invité sur des nicks
if { [info exists ::AuthIRC::Invite_On_Nick] && ${::AuthIRC::Invite_On_Nick} != "" } {
	foreach { line } [split ${::AuthIRC::Invite_On_Nick}] {
		set botname			[lindex ${line} 0];
		set msg_invite		[lrange ${line} 1 end];
		::AuthIRC::plog [format "Je contacte '%s' avec le message %s." ${botname} ${msg_invite}]
		putserv "PRIVMSG ${botname} :${msg_invite}";
		}
	}
}



# proc ::AuthIRC::need-all { chan type } {
# 	::AuthIRC::NS:Identify
# 	switch -nocase -- $type {
# 		op { putquick "MODE $chan +o $::botnick"; }
# 		invite -
# 		limite -
# 		key {
# 			::AuthIRC::CS:Invite $chan;
# 			putquick "INVITE $::botnick $chan";
# 		}
# 	}
# }
proc ::AuthIRC::Connect { from keyword text } {
	::AuthIRC::Notice "NickServ" host handle text $::botnick;
}

proc ::AuthIRC::NS:Ghost { from keyword text } {
	putlog "::AuthIRC:: Nick déjé utilié, utilisation de GHOST.";
	putquick "NICK ${::nick}2";
	putquick "privmsg NickServ :ghost $::nick $::AuthIRC_Password";
	utimer 5 { putquick "NICK ${::nick}"; }
}

proc ::AuthIRC::NS:WrongPass { nick host handle text dest } {
	putlog "::AuthIRC:: Mot de passe fournis incorrect, Changer le !";
}

proc ::AuthIRC::NS:NickChangeForced { nick host handle text dest } {
	putlog "::AuthIRC:: Ont ma forcer de changer de nick !";
	::AuthIRC::DCC:ReAuth hand idx arg;
}

proc ::AuthIRC::NS:Register:Wait { nick host handle text dest } {
	putlog "::AuthIRC:: Je vais enregistrer mon Nick é NickServ dans $::AuthIRC_TimeWaitBeforeRegNick secondes.";
	set ::AuthIRC_NS_Identified	"0";
	utimer $::AuthIRC_TimeWaitBeforeRegNick { ::AuthIRC::NS:Register; }
}

proc ::AuthIRC::NS:Register { } {
	putlog "::AuthIRC:: Enregistrement du nick é NickServ.";
	putquick "privmsg NickServ :register $::AuthIRC_Password $::AuthIRC_EMail";
	::AuthIRC::Invite nick host handle text dest;
}

proc ::AuthIRC::Notice { nick host handle text dest } {
	if { $nick == "NickServ" && $dest == $::botnick } {
		if { $::AuthIRC_NS_Identified == "0" } { set ::AuthIRC_NS_Identified	"1"; } else { return 0; }
	::AuthIRC::NS:Identify
	putquick "MODE $::botnick $::AuthIRC_U_MODES";
	}
}

proc ::AuthIRC::DCC:ReAuth { hand idx arg } {
	putdcc $idx "::AuthIRC:: Re identification...\n";
	set ::AuthIRC_NS_Identified	"0";
	set ::AuthIRC_NS_Invited	"0";
	::AuthIRC::NS:Identify
	putquick "MODE $::botnick $::AuthIRC_U_MODES";
	::AuthIRC::Invite nick host handle text dest;
}


proc ::AuthIRC::NS:AList { nick host handle text dest } {
	if { $nick == "NickServ" } {
		regsub -all " +" $text " " text;
		if { $::AuthIRC_NS_AList == "1" } {
			for { set x 0 } { $x < 10 } { incr x } {
				if { [string match -nocase "#*" [lindex $text $x]] } {
					set Channel_to_add [lindex $text $x];
					putlog "::AuthIRC:: Add Channel Name :$Channel_to_add";
					channel add $Channel_to_add;
					::AuthIRC::CS:Invite $Channel_to_add;
				}
			}
	}
	}
}

proc ::AuthIRC::OnINVITE { from keyword text } {
	if { $::AuthIRC_InviteMe_AutoAddChan == "1" } { channel add [lindex [split $text :] 1]; }
}

::AuthIRC::INIT
