//shiprekt HUD

#include "ActorHUDStartPos.as";
#include "ShipsCommon.as";
#include "ShiprektTranslation.as";

const u8 slotsSize = 8;
const SColor tipsColor = SColor(255, 255, 255, 255);
const f32 MSHIP_DAMAGE_ALERT = 3.0f;

void onInit(CSprite@ this)
{
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
	this.getCurrentScript().removeIfTag = "dead";
	this.getBlob().set_u8("gui_HUD_slots_width", slotsSize);
}

void onTick(CSprite@ this)
{
	if (g_videorecording) return;

	CBlob@ blob = this.getBlob();
	if (blob is null) return;
	CPlayer@ player = blob.getPlayer();  
	if (player is null) return;
	
	CRules@ rules = getRules();
	Vec2f tl = getActorHUDStartPosition(blob, slotsSize);	
	const string name = player.getUsername();
	const u16 pBooty = rules.get_u16("booty" + name);
	CControls@ controls = getControls();
	
	// seat relinquish
	if ((controls.getMouseScreenPos() - tl - Vec2f(100, 20)).Length() < 15.0f)
	{
		if (controls.isKeyJustPressed(KEY_LBUTTON))
		{
			u16 seatID = 0;
			CBlob@[] blobs;
			getMap().getBlobsInRadius(blob.getPosition(), 8.0f, @blobs);
			const u8 blobsLength = blobs.length;
			for (u8 i = 0; i < blobsLength; i++)
			{
				CBlob@ seat = blobs[i];
				if (seat.hasTag("seat") && seat.get_string("playerOwner") == name)
				{
					seatID = seat.getNetworkID();
					break;
				}
			}
			
			if (seatID > 0)
			{
				CBitStream params;
				params.write_netid(seatID);
				blob.SendCommand(blob.getCommandID("releaseOwnership"), params);
				Sound::Play("LoadingTick2.ogg");
			}
		}
	}
	
	// transfer booty
	if ((controls.getMouseScreenPos() - tl - Vec2f(146, 20)).Length() < 15.0f)
	{
		const u16 BOOTY_TRANSFER = rules.get_u16("booty_transfer");
		const f32 BOOTY_TRANSFER_FEE = rules.get_f32("booty_transfer_fee");//% of transfer
		const u16 fee = Maths::Round(BOOTY_TRANSFER * BOOTY_TRANSFER_FEE);
		if (!rules.isWarmup())
		{
			if (pBooty >= BOOTY_TRANSFER + fee)
			{
				if (controls.isKeyJustPressed(KEY_LBUTTON))
				{
					blob.SendCommand(blob.getCommandID("giveBooty"));
					Sound::Play("LoadingTick2.ogg");
				}
			}
		}
	}
}

void onRender(CSprite@ this)
{
	if (g_videorecording)
		return;

	CBlob@ blob = this.getBlob();
	if (blob is null) return;
	CPlayer@ player = blob.getPlayer();  
	if (player is null) return;
	
	CRules@ rules = getRules();
	Vec2f tl = getActorHUDStartPosition(blob, slotsSize);
	const u8 teamNum = player.getTeamNum();
	const string name = player.getUsername();
	const string captainName = getCaptainName(teamNum);
	const u16 pBooty = rules.get_u16("booty" + name);
	CBlob@ teamCore = getMothership(teamNum);
	CControls@ controls = getControls();
	const f32 screenHeight = getScreenHeight();
	const f32 screenWidth = getScreenWidth();
	const u32 gameTime = getGameTime();
	
	GUI::SetFont("none"); //shite fix but works
	
	//			Gameplay Tips
	//Seat produce couplings help
	if (blob.isAttached() && blob.get_bool("drawCouplingsHelp"))
		GUI::DrawText(Trans::CouplingRDY.replace("{key}",""+getControls().getActionKeyKeyName(AK_INVENTORY)),  tl + Vec2f(350, 10), tipsColor);
	
	//Can't place blocks on mothership
	//if (blob.get_bool("blockPlacementWarn"))
		//GUI::DrawText(Trans::WarmupPlacing, controls.getMouseScreenPos() + Vec2f(-200, -40), tipsColor);
	
	//Seat couplings help
	if (blob.isAttached() && blob.get_bool("drawSeatHelp"))
	{
		GUI::DrawText(Trans::ReleaseCoup2, Vec2f(screenWidth/2 - 150, screenHeight/3 + Maths::Sin(gameTime/4.5f) * 4.5f), tipsColor);
		GUI::DrawText(Trans::ReleaseCoup1, Vec2f(screenWidth/2 - 300, screenHeight/3 + 15 + Maths::Sin(gameTime/4.5f) * 4.5f), tipsColor);
	}

	//Reclaiming other property is slower
	if (blob.get_bool("reclaimPropertyWarn"))
	{
		GUI::DrawText(Trans::Reclaiming, Vec2f(screenWidth/2 - 340, screenHeight/2 + 310 + Maths::Sin(gameTime/4.5f) * 4.5f), tipsColor);
	}
	
	//warm-up/freebuild
	const bool freebuild = rules.get_bool("freebuild");
	if (freebuild)
	{
		if (getPlayersCount() == 1)
			GUI::DrawText(Trans::FreeMode, Vec2f(screenWidth/2 - 125, 15), tipsColor);
		else
			GUI::DrawText(Trans::FreebuildMode, Vec2f(screenWidth/2 - 75, 15), tipsColor);
	}
	else if (rules.isWarmup())
	{
		const int WARMUP_TIME = rules.get_u16("warmup_time") - gameTime;
		if (WARMUP_TIME > 0)
		{
			const u8 seconds = Maths::Round(WARMUP_TIME/30 % 60);
			const string warmupText = getTranslatedString("WARMUP")+" "+ Maths::Round(WARMUP_TIME/30/60) + ":" + (seconds > 9 ? "" : "0") + seconds;
			GUI::DrawText(warmupText, Vec2f(screenWidth/2 - 75, 15), tipsColor);
		}
	}
	
	if (rules.get_bool("display_flak_team_max"))
		GUI::DrawText(Trans::FlaksLimit, Vec2f(screenWidth/2 - 205, 40), tipsColor);
	
	//mothership alerts
	if (teamCore !is null)
	{
		const f32 mShipDMG = rules.get_f32("msDMG");
		const bool mShipOnScreen = teamCore.isOnScreen();
		
		if (!mShipOnScreen)
		{	
			if (name == captainName) //captain has abandoned ship!
				GUI::DrawText(Trans::Abandon, Vec2f(screenWidth/2 - 100, screenHeight/3 + Maths::Sin(gameTime/4.5f) * 4.5f), SColor(255, 235, 35, 35));
			else if (mShipDMG > MSHIP_DAMAGE_ALERT) //mothership under attack alert
				GUI::DrawText(Trans::ShipAttack, Vec2f(screenWidth/2 - 135, screenHeight/3 + Maths::Sin(gameTime/4.5f) * 4.5f), tipsColor);
		}
		else if (captainName.isEmpty() && pBooty < rules.get_u16("bootyRefillLimit") && !freebuild) //poor and no captain: sharks for income
			GUI::DrawText("[ "+Trans::KillSharks+" ]", Vec2f(220, 60 + Maths::Sin(gameTime/4.5f) * 4.5f), tipsColor);
	}
	
	//			Draw HUD Icons and Status text
	DrawShipStatus(blob, name, tl, controls);
	
	GUI::SetFont("menu");
	DrawCoreStatus(teamCore, tl, controls);
	DrawStationStatus(teamNum, tl, controls);
	DrawResources(pBooty, name, captainName, tl, controls);
}

void DrawShipStatus(CBlob@ this, const string&in name, Vec2f&in tl, CControls@ controls)
{
	const s32 overlappingShipID = this.get_s32("shipID");
	Ship@ ship = overlappingShipID > 0 ? getShipSet().getShip(overlappingShipID) : null;
	if (ship !is null)
	{
		CPlayer@ shipOwner = getPlayerByUsername(ship.owner);
		
		//Owner name text (top left)
		if (!ship.owner.isEmpty() && ship.owner != "*")
		{
			const string lastChar = ship.owner.substr(ship.owner.size() -1);
			const string ownership = ship.owner + (lastChar == "s" ? "'" : "'s") +" "+Trans::Ship;
			Vec2f size;
			GUI::GetTextDimensions(ownership, size);
			GUI::DrawText(ownership, Vec2f(Maths::Max(4.0f, 69.0f - size.x/2.0f), 3.0f), SColor(255, 255, 255, 255));
		}
		
		//icon
		if (shipOwner is null || (shipOwner !is null && shipOwner.getTeamNum() == this.getTeamNum()))
		{
			if (name == ship.owner || ship.owner == "*")
				GUI::DrawIconByName("$CAPTAIN$", tl + Vec2f(67, -12));
			else if (!ship.owner.isEmpty())
				GUI::DrawIconByName("$CREW$", tl + Vec2f(67, -11));
			else
				GUI::DrawIconByName("$FREEMAN$", tl + Vec2f(67, -12));
		}
		else
			GUI::DrawIconByName("$ASSAIL$", tl + Vec2f(67, -11));		
		
		//Speed
		const u16 speed = ship.vel.Length() * 30;
		GUI::DrawText(Trans::Speed+" : " + speed + " kilorekts/h", Vec2f(24, getScreenHeight() - 24), tipsColor);
	}
	else
		GUI::DrawIconByName("$SEA$", tl + Vec2f(67, -12));
		
	//GUI buttons text/function
	if ((controls.getMouseScreenPos() - tl - Vec2f(100, 20)).Length() < 15.0f)
	{
		GUI::SetFont("menu");
		GUI::DrawText(Trans::Relinquish, tl + Vec2f(-25, -25), tipsColor);
	}
}

void DrawCoreStatus(CBlob@ core, Vec2f&in tl, CControls@ controls)
{
	if (core is null) return;
	
	GUI::DrawIcon("InteractionIconsBig.png", 30, Vec2f(32,32), tl + Vec2f(-12, -12), 1.0f, core.getTeamNum());

	const u8 health = core.hasTag("critical") ? 0 : Maths::Min(100, Maths::Round(core.getHealth()/core.getInitialHealth() * 100));
	
	SColor col;
	if (health <= 10)
		col = SColor(255, 255, 0, 0);
	else if (health < 50)
		col = SColor(255, 255, 255, 0);
	else
		col = SColor(255, 255, 255, 255);

	GUI::DrawText(health + "%", tl + Vec2f(37, 11), col);
	
	//GUI buttons text/function
	if ((controls.getMouseScreenPos() - (tl + Vec2f(17, 20))).Length() < 15.0f)
		GUI::DrawText(Trans::CoreHealth,  tl + Vec2f(-45, -25), tipsColor);
}

void DrawStationStatus(const u8&in teamnum, Vec2f&in tl, CControls@ controls)
{
	GUI::DrawIcon("Station.png", 0, Vec2f(16,16), tl + Vec2f(210, 4), 1.0f, teamnum);
	
	CBlob@[] stations;
	getBlobsByTag("station", @stations);
	
	const u8 totalStationCount = stations.length;
	u8 teamStationCount = 0;
	for (u8 i = 0; i < totalStationCount; i++)
	{
		if (stations[i].getTeamNum() == getLocalPlayer().getTeamNum())
			teamStationCount++;
	}

	GUI::DrawText(teamStationCount + "/" + totalStationCount + " (+"+teamStationCount*4+")", tl + Vec2f(246, 11), tipsColor);
	
	//GUI buttons text/function
	if ((controls.getMouseScreenPos() - (tl + Vec2f(245, 20))).Length() < 35.0f)
		GUI::DrawText(Trans::Bases,  tl + Vec2f(200, -25), tipsColor);
}

void DrawResources(const u16&in pBooty, const string&in name, const string&in captainName, Vec2f&in tl, CControls@ controls)
{
	GUI::DrawIconByName("$BOOTY$", tl + Vec2f(111, -12));

	SColor col;
	if (pBooty < 10)
		col = SColor(255, 255, 0, 0);
	else if (pBooty <= 100)
		col = SColor(255, 255, 255, 0);
	else
		col = SColor(255, 255, 255, 255);
		
	GUI::DrawText("" + pBooty, tl + Vec2f(158 , 11), col);
	//GUI buttons text/function
	if ((controls.getMouseScreenPos() - tl - Vec2f(146, 20)).Length() < 15.0f)
	{
		CRules@ rules = getRules();
		const u16 BOOTY_TRANSFER = rules.get_u16("booty_transfer");
		const f32 BOOTY_TRANSFER_FEE = rules.get_f32("booty_transfer_fee");//% of transfer
		const u16 fee = Maths::Round(BOOTY_TRANSFER * BOOTY_TRANSFER_FEE);
		if (!rules.isWarmup())
		{
			if (pBooty >= BOOTY_TRANSFER + fee)
			{
				string feeString = fee > 0 ? (" for " + (BOOTY_TRANSFER + fee) + " Booty") : "";
				if (name != captainName)
					GUI::DrawText(Trans::Transfer.replace("{booty}", BOOTY_TRANSFER+"")+" "+Trans::Captain+" "+captainName+ feeString, tl + Vec2f(35, -25), tipsColor);
				else
					GUI::DrawText(Trans::Transfer.replace("{booty}", BOOTY_TRANSFER+"")+" "+Trans::ShipCrew+ feeString, tl + Vec2f(35, -25), tipsColor);
			}
			else
				GUI::DrawText(Trans::BootyTransM.replace("{booty}", BOOTY_TRANSFER+""), tl + Vec2f(35, -25), tipsColor);
		}
		else
			GUI::DrawText(Trans::BootyTransW, tl + Vec2f(35, -25), tipsColor);
	}
}
