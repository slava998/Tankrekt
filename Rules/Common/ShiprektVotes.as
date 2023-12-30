//implements shiprekt vote types and menus for them

#include "VoteCommon.as";
#include "ShiprektTranslation.as";
#include "SoftBans.as";

s32 lastKVote = 0;
s32 lastFBVote = 0;
s32 lastSDVote = 0;
s32 lastSRVote = 0;

string g_lastUsernameVoted = "";

const u32 BaseEnableTimeSuddenDeath = 10*30*60; //minimum base time. decreases on smaller maps and increases with cores count

const u32 kickCooldown = 10*30*60;
const u32 suddenDeathVoteCooldown = 3*30*60;
const u32 freeBuildCooldown = 5*30*60;
const u32 surrenderCooldown = 3*30*60;

const s32 VoteKickTime = 30; //minutes (30min default)

//kicking related globals and enums
enum kick_reason
{
	kick_reason_griefer = 0,
	kick_reason_hacker,
	kick_reason_teamkiller,
	kick_reason_spammer,
	kick_reason_non_participation,
	kick_reason_count,
};
string[] kick_reason_string = {"Griefer", "Hacker", "Teamkiller", "Chat Spam", "Non-Participation"};

string g_kick_reason = kick_reason_string[kick_reason_griefer]; //default

//next map related globals and enums
enum nextmap_reason
{
	nextmap_reason_ruined = 0,
	nextmap_reason_stalemate,
	nextmap_reason_bugged,
	nextmap_reason_count,
};

//votekick and vote nextmap

const string votekick_id = "vote: kick";
const string votenextmap_id = "vote: nextmap";
const string votefreebuild_id = "vote: freebuild";
const string votesurrender_id = "vote: surrender";

//set up the ids
void onInit(CRules@ this)
{
	this.addCommandID(votekick_id);
	this.addCommandID(votenextmap_id);
	this.addCommandID(votefreebuild_id);
	this.addCommandID(votesurrender_id);
	
	initializeTimes(this);
}
	
void onReload(CRules@ this)
{
	initializeTimes(this);
}

void onRestart(CRules@ this)
{
	initializeTimes(this);
}

void initializeTimes(CRules@ this)
{
	lastSDVote = -suddenDeathVoteCooldown;
	lastFBVote = -freeBuildCooldown;
	lastSRVote = 0;
	lastKVote = 0;
}

//VOTE KICK --------------------------------------------------------------------
//votekick functors

class VoteKickFunctor : VoteFunctor
{
	VoteKickFunctor() {} //dont use this
	VoteKickFunctor(CPlayer@ _kickplayer)
	{
		@kickplayer = _kickplayer;
	}

	CPlayer@ kickplayer;

	void Pass(bool outcome)
	{
		if (kickplayer !is null && outcome)
		{
			client_AddToChat(getTranslatedString("Votekick passed! {USER} will be kicked out.").replace("{USER}", kickplayer.getUsername()), vote_message_colour());
			
			if (kickplayer.isMyPlayer())
			{
				client_AddToChat("You are now a shark for a minimum of 30 minutes.");
			}
			
			if (isServer())
			{
				server_SoftBan(kickplayer.getUsername(), 30*60, "[ "+kickplayer.getUsername()+" ] banned by vote for: "+g_kick_reason);
				//getSecurity().ban(kickplayer, VoteKickTime, "Voted off"); //30 minutes ban
			}
		}
	}
};

class VoteKickCheckFunctor : VoteCheckFunctor
{
	VoteKickCheckFunctor() {}//dont use this
	VoteKickCheckFunctor(CPlayer@ _kickplayer, string _reason)
	{
		@kickplayer = _kickplayer;
		reason = _reason;
	}

	CPlayer@ kickplayer;
	string reason;

	bool PlayerCanVote(CPlayer@ player)
	{
		if (!getSecurity().checkAccess_Feature(player, "mark_player")) return false;

		if (reason.find(kick_reason_string[kick_reason_griefer]) != -1 || //reason contains "Griefer"
				reason.find(kick_reason_string[kick_reason_teamkiller]) != -1 || //or TKer
				reason.find(kick_reason_string[kick_reason_non_participation]) != -1) //or AFK
		{
			return (player.getTeamNum() == kickplayer.getTeamNum() || //must be same team
					kickplayer.getTeamNum() == getRules().getSpectatorTeamNum() || //or they're spectator
					getSecurity().checkAccess_Feature(player, "mark_any_team"));   //or has mark_any_team
		}

		return true; //spammer, hacker (custom?)
	}
};

class VoteKickLeaveFunctor : VotePlayerLeaveFunctor
{
	VoteKickLeaveFunctor() {} //dont use this
	VoteKickLeaveFunctor(CPlayer@ _kickplayer)
	{
		@kickplayer = _kickplayer;
	}

	CPlayer@ kickplayer;

	//avoid dangling reference to player
	void PlayerLeft(VoteObject@ vote, CPlayer@ player)
	{
		if (player is kickplayer)
		{
			client_AddToChat(getTranslatedString("{USER} left early, acting as if they were kicked.").replace("{USER}", player.getUsername()), vote_message_colour());
			if (isServer())
			{
				server_SoftBan(player.getUsername(), 30*60, "[ "+player.getUsername()+" ] banned by vote for: vote desertion, "+g_kick_reason);
				//getSecurity().ban(player, VoteKickTime, "Ran from vote");
			}

			CancelVote(vote);
		}
	}
};

//setting up a votekick object
VoteObject@ Create_Votekick(CPlayer@ player, CPlayer@ byplayer, string reason)
{
	VoteObject vote;

	@vote.onvotepassed = VoteKickFunctor(player);
	@vote.canvote = VoteKickCheckFunctor(player, reason);
	@vote.playerleave = VoteKickLeaveFunctor(player);

	vote.title = "Kick {USER}?             ";
	vote.reason = reason;
	vote.byuser = byplayer.getUsername();
	vote.user_to_kick = player.getUsername();
	vote.forcePassFeature = "ban";
	vote.cancel_on_restart = false;

	CalculateVoteThresholds(vote);

	return vote;
}

//VOTE SUDDEN DEATH ----------------------------------------------------------------
//nextmap functors

class VoteNextmapFunctor : VoteFunctor
{
	VoteNextmapFunctor() {} //dont use this
	VoteNextmapFunctor(CPlayer@ player) {}
	
	void Pass(bool outcome)
	{
		CMap@ map = getMap();
		const f32 mapFactor = Maths::Min(1.0f, Maths::Sqrt(map.tilemapwidth * map.tilemapheight) / 300.0f);
		const u32 minTime = Maths::Max(0, Maths::Round(BaseEnableTimeSuddenDeath * mapFactor) - getGameTime());
		
		if (minTime > 0) return; //for left-over votes from last round
			
		if (outcome)
		{
			client_AddToChat("\n*** "+Trans::DeathStarted + "\n" + Trans::AttackReward + "\n" + Trans::WeightNote+" ***\n", vote_message_colour());
			
			if (isServer())
			{
				server_CreateBlob("whirlpool", 0, map.getMapDimensions() / 2);
				
				//kill all stations
				CBlob@[] stations;
				getBlobsByTag("station", @stations);
				const u8 stationsLength = stations.length;
				for (u8 i = 0; i < stationsLength; i++)
				{
					stations[i].server_Die();
				}
			}
		}
		else
		{
			client_AddToChat("*** "+Trans::SuddenDeath+" "+Trans::Failed+"! ***", vote_message_colour());
		}
	}
};

class VoteNextmapCheckFunctor : VoteCheckFunctor
{
	VoteNextmapCheckFunctor() {}

	bool PlayerCanVote(CPlayer@ player)
	{
		return getSecurity().checkAccess_Feature(player, "map_vote");
	}
};

//setting up a vote next map object
VoteObject@ Create_VoteNextmap(CPlayer@ byplayer, string reason)
{
	VoteObject vote;

	@vote.onvotepassed = VoteNextmapFunctor(byplayer);
	@vote.canvote = VoteNextmapCheckFunctor();

	vote.title = Trans::Enable+" "+Trans::SuddenDeath+"?              ";
	vote.reason = reason;
	vote.byuser = byplayer.getUsername();
	vote.forcePassFeature = "nextmap";
	vote.cancel_on_restart = true;

	CalculateVoteThresholds(vote);

	return vote;
}

//VOTE Freebuild ----------------------------------------------------------------
//Freebuild functors

class VoteFreebuildFunctor : VoteFunctor
{
	VoteFreebuildFunctor() {} //dont use this
	VoteFreebuildFunctor(CPlayer@ player) {}

	void Pass(bool outcome)
	{
		CRules@ rules = getRules();
		const bool newFreeState = !rules.get_bool("freebuild");
		if (outcome)
		{
			rules.set_bool("freebuild", newFreeState);
			client_AddToChat("\n*** "+(newFreeState ? Trans::BuildEnabled : Trans::BuildDisabled)+" ***\n", vote_message_colour());
		}
		else
		{
			lastFBVote = getGameTime() + freeBuildCooldown;
			client_AddToChat("*** "+Trans::FreebuildMode+" "+Trans::Vote+" "+Trans::Failed+"! ***", vote_message_colour());
		}
	}
};

class VoteFreebuildCheckFunctor : VoteCheckFunctor
{
	VoteFreebuildCheckFunctor() {}//dont use this
	VoteFreebuildCheckFunctor(s32 _team) {}

	bool PlayerCanVote(CPlayer@ player)
	{
		return getSecurity().checkAccess_Feature(player, "map_vote");
	}
};

//setting up a vote Freebuild object
VoteObject@ Create_VoteFreebuild(CPlayer@ byplayer)
{
	VoteObject vote;

	@vote.onvotepassed = VoteFreebuildFunctor(byplayer);
	@vote.canvote = VoteFreebuildCheckFunctor(byplayer.getTeamNum());

	vote.title = (getRules().get_bool("freebuild") ? Trans::Disable : Trans::Enable) +" "+Trans::FreebuildMode+"?                  ";
	vote.reason = "";
	vote.byuser = byplayer.getUsername();
	vote.forcePassFeature = "Freebuild";
	vote.cancel_on_restart = true;

	CalculateVoteThresholds(vote);

	return vote;
}

//VOTE SURRENDER ----------------------------------------------------------------
//surrender functors

class VoteSurrenderFunctor : VoteFunctor
{
	VoteSurrenderFunctor() {} //dont use this
	VoteSurrenderFunctor(CPlayer@ player)
	{
		team = player.getTeamNum();
	}

	s32 team;
	void Pass(bool outcome)
	{
		const bool isMyTeam = getLocalPlayer() !is null && getLocalPlayer().getTeamNum() == team;
		if (outcome)
		{
			if (isServer())
			{
				CBlob@ teamCore;
				CBlob@[] cores;
				getBlobsByTag("mothership", @cores);
				const u8 coresLength = cores.length;
				for (u8 i = 0; i < coresLength; i++)
				{
					CBlob@ core = cores[i];  
					if (core.getTeamNum() == team)
					{
						@teamCore = core;
						break;
					}
				}
				
				if (teamCore !is null)
				{
					teamCore.server_Hit(teamCore, teamCore.getPosition(), Vec2f_zero, 8.0f, 0);
				}
			}
			if (isMyTeam)
				client_AddToChat("*** "+Trans::MothershipDie+" ***", vote_message_colour());
		}
		else if (isMyTeam)
		{
			client_AddToChat("*** "+Trans::DestructFail+" ***", vote_message_colour());
		}
	}
};

class VoteSurrenderCheckFunctor : VoteCheckFunctor
{
	VoteSurrenderCheckFunctor() {} //dont use this
	VoteSurrenderCheckFunctor(s32 _team)
	{
		team = _team;
	}

	s32 team;

	bool PlayerCanVote(CPlayer@ player)
	{
		//todo: seclevs? how would they look?

		return player.getTeamNum() == team;
	}
};

//setting up a vote surrender object
VoteObject@ Create_VoteSurrender(CPlayer@ byplayer)
{
	VoteObject vote;

	@vote.onvotepassed = VoteSurrenderFunctor(byplayer);
	@vote.canvote = VoteSurrenderCheckFunctor(byplayer.getTeamNum());

	vote.title = Trans::EnableBoom+"?               ";
	vote.reason = "";
	vote.byuser = byplayer.getUsername();
	vote.forcePassFeature = "surrender";
	vote.cancel_on_restart = true;

	CalculateVoteThresholds(vote);

	return vote;
}

//create menus for kick and nextmap

void onMainMenuCreated(CRules@ this, CContextMenu@ menu)
{
	//get our player first - if there isn't one, move on
	CPlayer@ me = getLocalPlayer();
	if (me is null) return;

	if (Rules_AlreadyHasVote(this))
	{
		Menu::addContextItem(menu, getTranslatedString("(Vote already in progress)"), "ShiprektVotes.as", "void CloseMenu()");
		Menu::addSeparator(menu);

		return;
	}

	//and advance context menu when clicked
	CContextMenu@ votemenu = Menu::addContextMenu(menu, getTranslatedString("Start a Vote"));
	Menu::addSeparator(menu);

	//vote options menu

	CContextMenu@ kickmenu = Menu::addContextMenu(votemenu, getTranslatedString("Kick"));
	CContextMenu@ mapmenu = Menu::addContextMenu(votemenu, Trans::SuddenDeath);
	CContextMenu@ freebuildmenu = Menu::addContextMenu(votemenu, Trans::Freebuild);
	CContextMenu@ surrendermenu = Menu::addContextMenu(votemenu, "Self-Destruct Mothership");
	Menu::addSeparator(votemenu); //before the back button

	const bool can_skip_wait = getSecurity().checkAccess_Feature(me, "skip_votewait");

	//kick menu
	if (getSecurity().checkAccess_Feature(me, "mark_player"))
	{
		const u32 coolDownKick = Maths::Max(0, kickCooldown - (getGameTime() - lastKVote));
		if (coolDownKick > 0 && !can_skip_wait)
		{
			string cantstart_info = getTranslatedString("Voting requires a {REQUIRED_MIN} min wait\nafter each started vote to\nprevent spamming/abuse.\n").replace("{REQUIRED_MIN}", "10");

			Menu::addInfoBox(kickmenu, getTranslatedString("Can't Start Vote"), cantstart_info);
		}
		else
		{
			const string votekick_info = getTranslatedString(
				"Vote to kick a player on your team\nout of the game.\n\n" +
				"- use responsibly\n" +
				"- report any abuse of this feature.\n" +
				"\nTo Use:\n\n" +
				"- select a reason from the\n     list (default is griefing).\n" +
				"- select a name from the list.\n" +
				"- everyone votes.\n"
			);
			Menu::addInfoBox(kickmenu, getTranslatedString("Vote Kick"), votekick_info);

			Menu::addSeparator(kickmenu);

			//reasons
			for (uint i = 0 ; i < kick_reason_count; ++i)
			{
				CBitStream params;
				params.write_u8(i);
				Menu::addContextItemWithParams(kickmenu, getTranslatedString(kick_reason_string[i]), "ShiprektVotes.as", "Callback_KickReason", params);
			}

			Menu::addSeparator(kickmenu);

			//write all players on our team
			bool added = false;
			for (int i = 0; i < getPlayersCount(); ++i)
			{
				CPlayer@ player = getPlayer(i);

				//if(player is me) continue; //don't display ourself for kicking
				//commented out for max lols

				const u8 player_team = player.getTeamNum();
				if ((player_team == me.getTeamNum() || player_team == this.getSpectatorTeamNum()
						|| getSecurity().checkAccess_Feature(me, "mark_any_team"))
						&& (!getSecurity().checkAccess_Feature(player, "kick_immunity")))
				{
					string descriptor = player.getCharacterName();

					if (player.getUsername() != player.getCharacterName())
						descriptor += " (" + player.getUsername() + ")";

					if (g_lastUsernameVoted == player.getUsername())
					{
						const string title = getTranslatedString("Cannot kick {USER}").replace("{USER}", descriptor);
						const string info = getTranslatedString("You started a vote for\nthis person last time.\n\nSomeone else must start the vote.");
						//no-abuse box
						Menu::addInfoBox(kickmenu, title, info);
					}
					else
					{
						const string kick = getTranslatedString("Kick {USER}").replace("{USER}", descriptor);
						const string kicking = getTranslatedString("Kicking {USER}").replace("{USER}", descriptor);
						const string info = getTranslatedString("Make sure you're voting to kick\nthe person you meant.\n");

						CContextMenu@ usermenu = Menu::addContextMenu(kickmenu, kick);
						Menu::addInfoBox(usermenu, kicking, info);
						Menu::addSeparator(usermenu);

						CBitStream params;
						params.write_u16(player.getNetworkID());

						Menu::addContextItemWithParams(usermenu, getTranslatedString("Yes, I'm sure"), "ShiprektVotes.as", "Callback_Kick", params);
						added = true;

						Menu::addSeparator(usermenu);
					}
				}
			}

			if (!added)
			{
				Menu::addContextItem(kickmenu, getTranslatedString("(No-one available)"), "ShiprektVotes.as", "void CloseMenu()");
			}
		}
	}
	else
	{
		Menu::addInfoBox(kickmenu, getTranslatedString("Can't vote"), getTranslatedString("You are now allowed to votekick\nplayers on this server\n"));
	}
	Menu::addSeparator(kickmenu);

	//Sudden Death menu
	if (getSecurity().checkAccess_Feature(me, "map_vote"))
	{
		CMap@ map = getMap();
		CBlob@[] cores;
		getBlobsByTag("mothership", @cores);
		const f32 coresTime = 2.5f * (cores.length - 2) * 30 * 60;
		const f32 mapFactor = Maths::Min(1.0f, Maths::Sqrt(map.tilemapwidth * map.tilemapheight) / 300.0f);
		const u32 minTime = Maths::Max(0, Maths::Round(BaseEnableTimeSuddenDeath * mapFactor + coresTime) - getGameTime());
		const u32 coolDown = Maths::Max(0, suddenDeathVoteCooldown - (getGameTime() - lastSDVote));
		
		const u32 timeToEnable = minTime + coolDown;
		const bool whirlpool = this.get_bool("whirlpool");
		
		string desc = Trans::TooLong+" "+Trans::Vote+" "+Trans::SuddenDeath+"!\n";
		if (whirlpool)
			desc = Trans::ActiveDeath;
		else if (timeToEnable > 0)
			desc += timeToEnable > 30*60 ? (Trans::SwitchTime+" " + (1 + timeToEnable/30/60) + " "+Trans::Minutes+".") : (Trans::SwitchTime+" "+ timeToEnable/30 + getTranslatedString(" seconds")+".");
			
		Menu::addInfoBox(mapmenu, Trans::Vote+" "+Trans::SuddenDeath, desc);

		if (timeToEnable == 0 && !whirlpool)
		{
			Menu::addSeparator(mapmenu);
			//reason
			CBitStream params;
			params.write_u8(1);
			Menu::addContextItemWithParams(mapmenu, Trans::SpeedThings, "ShiprektVotes.as", "Callback_NextMap", params);
			
			Menu::addSeparator(mapmenu);
		}
	}
	else
	{
		Menu::addInfoBox(mapmenu, getTranslatedString("Can't vote"), "You are not allowed to vote\nto activate sudden death on this server\n");
	}
	Menu::addSeparator(mapmenu);

	//Freebuild menu
	//vote free building mode
	{
		const bool canActivate = getPlayersCount() < 5 || this.isWarmup() || this.get_bool("freebuild");
		const u32 coolDownFb = Maths::Max(0, freeBuildCooldown - (getGameTime() - lastFBVote));
		
		string descFb = Trans::Vote+" "+Trans::Enable+"/"+Trans::Disable+" "+Trans::FreebuildMode+".";
		if (coolDownFb > 0 && canActivate) 
			descFb = coolDownFb > 30*60 ? (Trans::SwitchTime+" "+ (1 + coolDownFb/30/60) +" "+Trans::Minutes+".") : (Trans::SwitchTime+" "+ coolDownFb/30 + getTranslatedString(" seconds")+".");
		else
			descFb = "Freebuild can only be activated during warm-up";
		const string nameFb = (this.get_bool("freebuild") ? Trans::Disable : Trans::Enable)+" "+Trans::FreebuildMode+"\n";
		Menu::addInfoBox(freebuildmenu, nameFb, descFb);

		if (coolDownFb == 0 && canActivate)
		{
			Menu::addSeparator(freebuildmenu);
			//reason
			CBitStream params;
			params.write_u8(1);
			Menu::addContextItemWithParams(freebuildmenu, getTranslatedString("Yes"), "ShiprektVotes.as", "Callback_Freebuild", params);
		}
	}
	Menu::addSeparator(freebuildmenu);
	
	//Self-Destruction menu
	//vote to blow up your mothership
	{
		const u32 coolDownSR = Maths::Max(0, surrenderCooldown - (getGameTime() - lastSRVote));
		
		const string nameSurrender = Trans::SelfDestruct+"\n";
		string descSurrender = Trans::VoteDestruct+".";
		if (coolDownSR > 0)
			descSurrender = getTranslatedString("Can't Start Vote")+" : "+ (coolDownSR/30) + getTranslatedString(" seconds")+".";
		
		Menu::addInfoBox(surrendermenu, nameSurrender, descSurrender);

		if (coolDownSR == 0)
		{
			Menu::addSeparator(surrendermenu);
			CBitStream params;
			params.write_u8(1);
			Menu::addContextItemWithParams(surrendermenu, Trans::BlowUp, "ShiprektVotes.as", "Callback_Surrender", params);
		}
	}
	Menu::addSeparator(surrendermenu);
}

void CloseMenu()
{
	Menu::CloseAllMenus();
}

void Callback_KickReason(CBitStream@ params)
{
	u8 id; if (!params.saferead_u8(id)) return;

	if (id < kick_reason_count)
	{
		g_kick_reason = kick_reason_string[id];
	}
}

void Callback_Kick(CBitStream@ params)
{
	CloseMenu(); //definitely close the menu

	CPlayer@ me = getLocalPlayer();
	if (me is null) return;

	u16 id;
	if (!params.saferead_u16(id)) return;

	CPlayer@ other_player = getPlayerByNetworkId(id);
	if (other_player is null) return;

	if (getSecurity().checkAccess_Feature(other_player, "kick_immunity"))
		return;

	//monitor to prevent abuse
	g_lastUsernameVoted = other_player.getUsername();

	CBitStream params2;

	params2.write_u16(other_player.getNetworkID());
	params2.write_u16(me.getNetworkID());
	params2.write_string(g_kick_reason);

	getRules().SendCommand(getRules().getCommandID(votekick_id), params2);
}

void Callback_NextMap(CBitStream@ params)
{
	CloseMenu(); //definitely close the menu

	CPlayer@ me = getLocalPlayer();
	if (me is null) return;

	u8 id;
	if (!params.saferead_u8(id)) return;

	const string reason = Trans::SpeedThings;

	CBitStream params2;
	params2.write_u16(me.getNetworkID());
	params2.write_string(reason);

	getRules().SendCommand(getRules().getCommandID(votenextmap_id), params2);
}

void Callback_Freebuild(CBitStream@ params)
{
	CloseMenu(); //definitely close the menu

	CPlayer@ me = getLocalPlayer();
	if (me is null) return;

	CBitStream params2;
	params2.write_u16(me.getNetworkID());

	getRules().SendCommand(getRules().getCommandID(votefreebuild_id), params2);
}

void Callback_Surrender(CBitStream@ params)
{
	CloseMenu(); //definitely close the menu

	CPlayer@ me = getLocalPlayer();
	if (me is null) return;

	CBitStream params2;
	params2.write_u16(me.getNetworkID());

	getRules().SendCommand(getRules().getCommandID(votesurrender_id), params2);
}

//actually setting up the votes
void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
	if (Rules_AlreadyHasVote(this))
		return;

	if (cmd == this.getCommandID(votekick_id))
	{
		u16 playerid, byplayerid;
		string reason;

		if (!params.saferead_u16(playerid)) return;
		if (!params.saferead_u16(byplayerid)) return;
		if (!params.saferead_string(reason)) return;
		
		lastKVote = getGameTime();

		CPlayer@ player = getPlayerByNetworkId(playerid);
		CPlayer@ byplayer = getPlayerByNetworkId(byplayerid);
		if (player !is null && byplayer !is null)
			Rules_SetVote(this, Create_Votekick(player, byplayer, reason));
	}
	else if (cmd == this.getCommandID(votenextmap_id))
	{
		u16 byplayerid;
		string reason;

		if (!params.saferead_u16(byplayerid)) return;
		if (!params.saferead_string(reason)) return;
		
		lastSDVote = getGameTime();

		CPlayer@ byplayer = getPlayerByNetworkId(byplayerid);
		if (byplayer !is null)
			Rules_SetVote(this, Create_VoteNextmap(byplayer, reason));
	}
	else if (cmd == this.getCommandID(votefreebuild_id))
	{
		u16 byplayerid;

		if (!params.saferead_u16(byplayerid)) return;
		
		lastFBVote = getGameTime();

		CPlayer@ byplayer = getPlayerByNetworkId(byplayerid);
		if (byplayer !is null)
			Rules_SetVote(this, Create_VoteFreebuild(byplayer));
	}
	else if (cmd == this.getCommandID(votesurrender_id))
	{
		u16 byplayerid;

		if (!params.saferead_u16(byplayerid)) return;
		
		lastSRVote = getGameTime();

		CPlayer@ byplayer = getPlayerByNetworkId(byplayerid);
		if (byplayer !is null)
			Rules_SetVote(this, Create_VoteSurrender(byplayer));
	}
}
