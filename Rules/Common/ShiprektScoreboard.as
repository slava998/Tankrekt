//#define CLIENT_ONLY
// Gingerbeard @ 2/23/2022
// taken from base kag and manipulated for multiple team support
//note: the mothership kills and deaths are set in Mothership.as. the score at Booty.as

#include "ScoreboardCommon.as";
#include "ColoredNameToggleCommon.as";
#include "ShipsCommon.as";
#include "ShiprektTranslation.as";

const f32 scoreboardMargin = 52.0f;
const f32 scrollSpeed = 4.0f;
const f32 maxMenuWidth = 430;
const f32 screenMidX = getScreenWidth()/2;

f32 scrollOffset = 0.0f;
bool mouseWasPressed2 = false;
CPlayer@ hoveredPlayer;

//returns the bottom
float drawScoreboard(CPlayer@[] players, Vec2f topleft, const u8&in teamNum)
{
	CTeam@ team = getRules().getTeam(teamNum);
	const u8 playersLength = players.length;
	if (playersLength <= 0 || team is null)
		return topleft.y;

	CRules@ rules = getRules();

	const f32 lineheight = 16;
	const f32 padheight = 2;
	const f32 stepheight = lineheight + padheight;
	Vec2f bottomright(Maths::Min(getScreenWidth() - 100, screenMidX+maxMenuWidth), topleft.y + (playersLength + 5.5) * stepheight);
	GUI::DrawPane(topleft, bottomright, team.color);

	//offset border
	topleft.x += stepheight;
	bottomright.x -= stepheight;
	topleft.y += stepheight;

	GUI::SetFont("menu");

	//draw team info
	GUI::DrawText(teamColors[teamNum]+" "+Trans::Team, Vec2f(topleft.x, topleft.y), SColor(0xffffffff));
	GUI::DrawText(getTranslatedString("Players: {PLAYERCOUNT}").replace("{PLAYERCOUNT}", "" + playersLength), Vec2f(bottomright.x - 470, topleft.y), SColor(0xffffffff));

	topleft.y += stepheight * 2;
	
	//draw player table header
	
	GUI::DrawText(getTranslatedString("Player"), Vec2f(topleft.x, topleft.y), SColor(0xffffffff));
	GUI::DrawText(getTranslatedString("Username"), Vec2f(bottomright.x - 570, topleft.y), SColor(0xffffffff));
	GUI::DrawText(getTranslatedString("Ping"), Vec2f(bottomright.x - 400, topleft.y), SColor(0xffffffff));
	GUI::DrawText(getTranslatedString("Kills"), Vec2f(bottomright.x - 330, topleft.y), SColor(0xffffffff));
	GUI::DrawText(getTranslatedString("Deaths"), Vec2f(bottomright.x - 260, topleft.y), SColor(0xffffffff));
	GUI::DrawText(Trans::Booty, Vec2f(bottomright.x - 170, topleft.y), SColor(0xffffffff));
	GUI::DrawText(Trans::Core+" "+getTranslatedString("Kills"), Vec2f(bottomright.x - 90, topleft.y), SColor(0xffffffff));

	topleft.y += stepheight * 0.5f;

	CControls@ controls = getControls();
	Vec2f mousePos = controls.getMouseScreenPos();

	//draw players
	for (u8 i = 0; i < playersLength; i++)
	{
		CPlayer@ p = players[i];

		topleft.y += stepheight;
		bottomright.y = topleft.y + lineheight;

		const bool playerHover = mousePos.y > topleft.y && mousePos.y < topleft.y + 15;
		if (playerHover)
		{
			if (controls.mousePressed1)
			{
				setSpectatePlayer(p.getUsername());
			}

			if (controls.mousePressed2 && !mouseWasPressed2)
			{
				// reason for this is because this is called multiple per click (since its onRender, and clicking is updated per tick)
				// we don't want to spam anybody using a clipboard history program
				if (getFromClipboard() != p.getUsername())
				{
					CopyToClipboard(p.getUsername());
					rules.set_u16("client_copy_time", getGameTime());
					rules.set_string("client_copy_name", p.getUsername());
					rules.set_Vec2f("client_copy_pos", mousePos + Vec2f(0, -10));
				}
			}
		}

		Vec2f lineoffset = Vec2f(0, -2);

		const u32 underlinecolor = 0xff404040;
		u32 playercolour = (p.getBlob() is null || p.getBlob().hasTag("dead")) ? 0xff505050 : 0xff808080;
		if (playerHover)
		{
			playercolour = 0xffcccccc;
			@hoveredPlayer = p;
		}

		GUI::DrawLine2D(Vec2f(topleft.x, bottomright.y + 1) + lineoffset, Vec2f(bottomright.x, bottomright.y + 1) + lineoffset, SColor(underlinecolor));
		GUI::DrawLine2D(Vec2f(topleft.x, bottomright.y) + lineoffset, bottomright + lineoffset, SColor(playercolour));

		const string tex = p.getScoreboardTexture();

		if (p.isMyPlayer() && tex.isEmpty())
			GUI::DrawIcon("ScoreboardIcons", 2, Vec2f(16,16), topleft, 0.5f, p.getTeamNum());
		else if (!tex.isEmpty())
			GUI::DrawIcon(tex, p.getScoreboardFrame(), p.getScoreboardFrameSize(), topleft, 0.5f, p.getTeamNum());

		const string username = p.getUsername();
		
		string playername = p.getCharacterName();
		string clantag = p.getClantag();

		if (getSecurity().isPlayerNameHidden(p) && getLocalPlayer() !is p)
		{
			if (isAdmin(getLocalPlayer()))
			{
				playername = username + "(hidden: " + clantag + " " + playername + ")";
				clantag = "";

			}
			else
			{
				playername = username;
				clantag = "";
			}
		}

		//have to calc this from ticks
		const s32 ping_in_ms = s32(p.getPing() * 1000.0f / 30.0f);

		//how much room to leave for names and clantags
		const float name_buffer = 26.0f;

		//render the player + stats
		const SColor namecolour = getNameColour(p);

		//right align clantag
		if (!clantag.isEmpty())
		{
			Vec2f clantag_actualsize(0, 0);
			GUI::GetTextDimensions(clantag, clantag_actualsize);
			
			GUI::DrawText(clantag, topleft + Vec2f(name_buffer, 0), SColor(0xff888888));
			//draw name alongside
			GUI::DrawText(playername, topleft + Vec2f(name_buffer + clantag_actualsize.x + 8, 0), namecolour);
		}
		else
		{
			//draw name alone
			GUI::DrawText(playername, topleft + Vec2f(name_buffer, 0), namecolour);
		}
		
		const int coreKills = p.getAssists();
		const SColor coreKillsCol = SColor(255, 255, 255- Maths::Min(255, coreKills * 30), 255- Maths::Min(255, coreKills * 80));

		GUI::DrawText("" + username, Vec2f(bottomright.x - 570, topleft.y), namecolour);
		GUI::DrawText("" + ping_in_ms, Vec2f(bottomright.x - 400, topleft.y), SColor(0xffffffff));
		GUI::DrawText("" + p.getKills(), Vec2f(bottomright.x - 330, topleft.y), SColor(0xffffffff));
		GUI::DrawText("" + p.getDeaths(), Vec2f(bottomright.x - 260, topleft.y), SColor(0xffffffff));
		GUI::DrawText("" + p.getScore(), Vec2f(bottomright.x - 170, topleft.y), SColor(0xffffffff));
		GUI::DrawText("" + coreKills, Vec2f(bottomright.x - 90, topleft.y), coreKillsCol);
	}

	// username copied text, goes at bottom to overlay above everything else
	u32 durationLeft = rules.get_u16("client_copy_time");

	if ((durationLeft + 64) > getGameTime())
	{
		durationLeft = getGameTime() - durationLeft;
		DrawFancyCopiedText(rules.get_string("client_copy_name"), rules.get_Vec2f("client_copy_pos"), durationLeft);
	}

	return topleft.y;
}

void onRenderScoreboard(CRules@ this)
{
	const u8 playingTeamsCount = 8; //change this depending on how many teams in the gamemode, this.getTeamsNum() causes errors
	CPlayer@[][] teamsPlayers(playingTeamsCount); //holds all teams and their players
	CPlayer@[] spectators;
	const u8 plyCount = getPlayersCount();
	for (u8 i = 0; i < plyCount; i++)
	{
		CPlayer@ p = getPlayer(i);
		if (p.getTeamNum() == this.getSpectatorTeamNum())
		{
			spectators.push_back(p);
			continue;
		}

		const u8 teamNum = p.getTeamNum();
		if (teamNum < playingTeamsCount)
		{
			//todo: push back team sorted by highest bounty OR push back localPlayers team first
			teamsPlayers[teamNum].push_back(p);
		}
	}

	//draw board

	@hoveredPlayer = null;

	Vec2f topleft(Maths::Max(100, screenMidX-maxMenuWidth), 150);
	drawServerInfo(40);

	// start the scoreboard lower or higher.
	topleft.y -= scrollOffset;

	//draw the scoreboards
	
	const u8 teamsPlyLength = teamsPlayers.length;
	for (u8 i = 0; i < teamsPlyLength; i++)
	{
		if (teamsPlayers[i].length > 0)
		{
			topleft.y = drawScoreboard(teamsPlayers[i], topleft, i);
			topleft.y += 45;
		}
	}

	const u8 spectatorsLength = spectators.length;
	if (spectatorsLength > 0)
	{
		//draw spectators
		const f32 stepheight = 16;
		Vec2f bottomright(Maths::Min(getScreenWidth() - 100, screenMidX+maxMenuWidth), topleft.y + stepheight * 2);
		const f32 specy = topleft.y + stepheight * 0.5;
		GUI::DrawPane(topleft, bottomright, SColor(0xffc0c0c0));

		Vec2f textdim;
		const string s = getTranslatedString("Spectators:");
		GUI::GetTextDimensions(s, textdim);

		GUI::DrawText(s, Vec2f(topleft.x + 5, specy), SColor(0xffaaaaaa));

		f32 specx = topleft.x + textdim.x + 15;
		for (u8 i = 0; i < spectatorsLength; i++)
		{
			CPlayer@ p = spectators[i];
			if (specx < bottomright.x - 100)
			{
				string name = p.getCharacterName();
				if (i != spectatorsLength - 1)
					name += ",";
				GUI::GetTextDimensions(name, textdim);
				SColor namecolour = getNameColour(p);
				GUI::DrawText(name, Vec2f(specx, specy), namecolour);
				specx += textdim.x + 10;
			}
			else
			{
				GUI::DrawText(getTranslatedString("and more ..."), Vec2f(specx, specy), SColor(0xffaaaaaa));
				break;
			}
		}

		topleft.y += 52;
	}

	const float scoreboardHeight = topleft.y + scrollOffset;
	const float screenHeight = getScreenHeight();
	CControls@ controls = getControls();

	if (scoreboardHeight > screenHeight)
	{
		Vec2f mousePos = controls.getMouseScreenPos();

		float fullOffset = (scoreboardHeight + scoreboardMargin) - screenHeight;

		if (scrollOffset < fullOffset && mousePos.y > screenHeight*0.83f)
		{
			scrollOffset += scrollSpeed;
		}
		else if (scrollOffset > 0.0f && mousePos.y < screenHeight*0.16f)
		{
			scrollOffset -= scrollSpeed;
		}

		scrollOffset = Maths::Clamp(scrollOffset, 0.0f, fullOffset);
	}

	mouseWasPressed2 = controls.mousePressed2; 
}

void onTick(CRules@ this)
{
	if (!this.isGameOver())
	{
		this.set_u32("match_time", getGameTime());
	}
	
	if (getGameTime() % 30 == 0) //check once a second
	{
		//get captains
		string[] captains;
		CBlob@[] cores;
		getBlobsByTag("mothership", @cores);
		ShipDictionary@ ShipSet = getShipSet(this);
		const u8 coresLength = cores.length;
		for (u8 i = 0; i < coresLength; i++)
		{
			const int coreCol = cores[i].getShape().getVars().customData;
			if (coreCol <= 0) continue;
			
			Ship@ ship = ShipSet.getShip(coreCol);
			if (ship !is null && !ship.owner.isEmpty())
				captains.push_back(ship.owner);
		}
		
		//set vars
		const u8 plyCount = getPlayersCount();
		for (u8 i = 0; i < plyCount; i++)
		{
			CPlayer@ player = getPlayer(i);
			if (captains.find(player.getUsername()) > -1)
				player.SetScoreboardVars("ScoreboardIcons.png", 0, Vec2f(16, 16));
			else
				player.UnsetScoreboardVars();
		}
	}
}

void onInit(CRules@ this)
{
	onRestart(this);
}

void onRestart(CRules@ this)
{
	this.set_u32("match_time", 0);
	
	if (isServer())
	{
		getMapName(this);
	}
}

void onBlobDie(CRules@ this, CBlob@ blob)
{
	if (!this.isGameOver())	//Only count kills, deaths when the game is on
	{
		if (blob !is null)
		{
			CPlayer@ killer = blob.getPlayerOfRecentDamage();
			CPlayer@ victim = blob.getPlayer();

			if (victim !is null)
			{
				victim.setDeaths(victim.getDeaths() + 1);

				if (killer !is null) //requires victim so that killing trees matters
				{
					if (killer.getTeamNum() != blob.getTeamNum())
					{
						killer.setKills(killer.getKills() + 1);
					}
				}
			}
		}
	}
}

void getMapName(CRules@ this)
{
	CMap@ map = getMap();
	if (map !is null)
	{
		string[] name = map.getMapName().split('/');	 //Official server maps seem to show up as
		string mapName = name[name.length - 1];		 //``Maps/CTF/MapNameHere.png`` while using this instead of just the .png
		mapName = getFilenameWithoutExtension(mapName);  // Remove extension from the filename if it exists

		this.set_string("map_name", mapName);
		this.Sync("map_name", true); //734528625 HASH
	}
}

void DrawFancyCopiedText(string username, Vec2f&in mousePos, const u32&in duration)
{
	const string text = "Username copied: " + username;
	const Vec2f pos = mousePos - Vec2f(0, duration);
	const int col = (255 - duration * 3);

	GUI::DrawTextCentered(text, pos, SColor((255 - duration * 4), col, col, col));
}
