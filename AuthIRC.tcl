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
	######################
	#    CONFIGURATION   #
	######################
	variable U_MODES				"+iRShBHIpWxZ-ws";			# Les modes "user" désiré. Plus d'informations : https://www.unrealircd.org/docs/User_Modes
	variable U_Password				"<VotreMotDePasse>";		# Le mot de passe pour s'identifier é NickServ.
	variable U_EMail				"Zartek.Creole@GMail.com";	# L'e-mail pour s'enregistrer.
	variable Channels_list			[list 						\
		"" 						\
		"" 						\
		];														# La liste des channels a joindre (.+chan #salon)
	variable Chanserv_Invite		[list 						\
		"" 						\
		"" 						\
		];														# Liste des salons à s'inviter avec 'msg chanserv invite #salon'
	variable Invite_On_Nick			[list 						\
		"" 						\
		"" 						\
		];														# S'invite sur d'autres robots. Commencer par le nick suivis de l'arguement a envoyer. Ex : "<NickBotToSend> invite <MyLogin> <MyPass>";
	variable OperLine				"";							# Si vous avez une Oper Line mettez le login pass. Ex: "<login> <Pass>";
	variable TimeWaitBeforeRegNick	"61";						# Temps d'attente en secondes, avant s'enregistrer. Plus d'informations : https://https://github.com/cloudposse/anope/blob/master/templates/nickserv.conf#L116
	variable OperServName			"OperServ";					# Le nom du services OperServ
	variable NickServName			"NickServ";					# Le nom du services NickServ
	variable NickServIdentify		"IDENTIFY";					# nom de la commandes pour s'identifier
	variable ChanServName			"ChanServ";					# Le nom du services ChanServ

	variable OperSUPERADMIN			1;							# Activer le mode SUPERADMIN ? Plus d'informations : https://https://github.com/anope/anope/blob/2.0/data/operserv.example.conf#L624
	variable NickServ_AList			1;							# Utiliser ALIST de nickserv pour connaitre les salons dont j'ai acces et m'inviter?
	variable InviteMe_AutoAddChan	1;				    		# Si on invite votre robot sur un channel ou il est pas il auto join si la valeur est 1.
	variable SASL					1;				    		# Essayer de s'identifier via SASL ? Plus d'informations : https://www.unrealircd.org/docs/SASL
	variable verbose				1;							# Rendre le script bavard en partyline

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
		"Version"	"1.3.1"
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

	if { ![info exists ::AuthIRC::SASL] || ${::AuthIRC::SASL} == 1 } { ::AuthIRC::SASL; }
	## 001 : Welcome to the Internet Relay Network nickname
	bind raw - 001 ::AuthIRC::Connect
	## 473 channel : Cannot join channel (+i)
	bind raw - 473 ::AuthIRC::Connect

	# IDENTIFIED
	dict map { locale message } [dict get ${::AuthIRC::ANONNCE} Password_accepted] {
		bind notc - "*${message}*" ::AuthIRC::IDENTIFIED
	}

	bind raw - 307 :AuthIRC::IDENTIFIED

	# NEED RESGITER
	bind notc - "*Your nick isn't registered*" ::AuthIRC::NS:Register:Wait
	bind notc - "*Votre pseudo n'est pas enregistré*" ::AuthIRC::NS:Register:Wait
	## 477 channel : You need a registered nick to join that channel.
	bind raw - 477  ::AuthIRC::NS:Register:Wait
	## 451 command : Register first.
	bind raw - 451  ::AuthIRC::NS:Register:Wait
	## 512 : Authorization required to use Registered Nickname nick
	bind raw - 512  ::AuthIRC::NS:Register:Wait

	# Ghost
	bind notc - "*Nickname is already in use*" ::AuthIRC::NS:Ghost
	## 433 nickname : Nickname is already in use.
	bind raw - 433 ::AuthIRC::NS:Ghost

	bind notc - "*Password incorrect*" ::AuthIRC::NS:WrongPass
	bind notc - "*Your nickname is now being changed to*" ::AuthIRC::NS:NickChangeForced
	bind notc - "*" ::AuthIRC::NS:AList


	# Invitation sur un salon
	bind raw - INVITE ::AuthIRC::OnINVITE
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