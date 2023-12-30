#include "ShipsCommon.as";
#include "ExplosionEffects.as";
#include "WaterEffects.as";
#include "Booty.as";
#include "BlockProduction.as";
#include "TeamColour.as";
#include "HumanCommon.as";
#include "AccurateSoundPlay.as";
#include "Hitters.as";
#include "BlockCosts.as";
#include "ShiprektTranslation.as";

const u16 BASE_KILL_REWARD = 275;
const f32 HEAL_RADIUS = 16.0f;
const u16 SELF_DESTRUCT_TIME = 8 * 30;
const f32 BLAST_RADIUS = 25 * 8.0f;
const u8 MAX_TEAM_FLAKS = 40;
u8 maxBlockTimer; //can be global since only used for myplayer

void onInit(CBlob@ this)
{
	this.sendonlyvisible = false; //clients always know this blob's position

	this.Tag("mothership");
	this.Tag("core");
	this.Tag("noRenderHealth");
	this.addCommandID("buyBlock");
	this.addCommandID("returnBlocks");
	
	this.set_f32("weight", 12.0f);
	
	if (this.getTeamNum() < 8)
		getRules().setAt("motherships", this.getTeamNum(), this.getNetworkID());
	
	if (isClient())
	{
		//add an additional frame to the damage frames animation
		CSprite@ sprite = this.getSprite();
		Animation@ animation = sprite.getAnimation("default");
		if (animation !is null)
		{
			int[] frames = {3};
			animation.AddFrames(frames);
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("buyBlock"))
	{
		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		const string block = params.read_string();
		const u16 cost = params.read_u16();
		const bool autoBlock = params.read_bool();
		
		if (caller is null)
			return;
		
		if (autoBlock && !caller.get_bool("getting block"))
			return;
			
		if (caller.isMyPlayer())
		{
			caller.set_bool("getting block", false);
			caller.Sync("getting block", false); //379080002 HASH
		}
		caller.set_string("last buy", block);

		if (getGameTime() - caller.get_u32("placedTime") > 26)
			caller.set_u32("placedTime", getGameTime() - 20);

		if (!isServer() || Human::isHoldingBlocks(caller) || !this.hasTag("mothership") || this.getTeamNum() != caller.getTeamNum())
			return;
		
		BuyBlock(this, caller, block, cost);
	}
	else if (cmd == this.getCommandID("returnBlocks"))
	{
		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		if (caller !is null)
			ReturnBlocks(caller);
	}
}

void BuyBlock(CBlob@ this, CBlob@ caller, const string&in bType, const u16&in cost)
{
	CRules@ rules = getRules();

	CPlayer@ player = caller.getPlayer();
	const string pName = player !is null ? player.getUsername() : "";
	const u16 pBooty = server_getPlayerBooty(pName);

	u8 amount = 1;
	u8 teamFlaks = 0;

	if (bType == "coupling") //coupling gives two blocks
	{
		amount = 2;
	}
	else if (bType == "flak")
	{
		//Max turrets to avoid lag
		CBlob@[] turrets;
		getBlobsByTag("flak", @turrets);
		const u16 turretsLength = turrets.length;
		for (u16 i = 0; i < turretsLength; i++)
		{
			if (turrets[i].getTeamNum() == this.getTeamNum())
				teamFlaks++;
		}
	}

	if (teamFlaks < MAX_TEAM_FLAKS)
	{
		if (rules.get_bool("freebuild"))
			ProduceBlock(rules, caller, bType, amount);
		else if (pBooty >= cost)
		{
			server_addPlayerBooty(pName, -cost);
		
			ProduceBlock(rules, caller, bType, amount);
		}
	}
	else if (teamFlaks >= MAX_TEAM_FLAKS && player !is null)
	{
		rules.set_bool("display_flak_team_max", false);
		rules.SyncToPlayer("display_flak_team_max", player); //-296461567 HASH
		rules.set_bool("display_flak_team_max", true);
		rules.SyncToPlayer("display_flak_team_max", player);
	}
}

void ReturnBlocks(CBlob@ this)
{
	CRules@ rules = getRules();
	u16[] blocks;
	if (this.get("blocks", blocks) && blocks.size() > 0)                 
	{
		if (isServer())
		{
			CPlayer@ player = this.getPlayer();
			if (player !is null)
			{
				u16 returnBooty = 0;
				const u16 blocksLength = blocks.length;
				for (u16 i = 0; i < blocksLength; ++i)
				{
					CBlob@ block = getBlobByNetworkID(blocks[i]);
					if (block is null) continue;
					
					if (!block.hasTag("coupling") && block.getShape().getVars().customData == -1)
						returnBooty += getCost(block.getName());
				}
				
				if (returnBooty > 0 && !rules.get_bool("freebuild"))
					server_addPlayerBooty(player.getUsername(), returnBooty);
			}
		}
		
		Human::clearHeldBlocks(this);
		this.set_u32("placedTime", getGameTime());
		
		if (this.isMyPlayer())
		{
			this.set_bool("blockPlacementWarn", false);
			this.getSprite().PlaySound("join");
		}
	}
	else if (sv_test)
		warn("returnBlocks cmd: no blocks"); //happens when block placing & block returning happens at same time
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (hitterBlob is null) return damage;
	
	CRules@ rules = getRules();
	const u8 thisTeamNum = this.getTeamNum();
	u8 hitterTeamNum = hitterBlob.getTeamNum();
	
	if (thisTeamNum == hitterTeamNum && hitterBlob.getTickSinceCreated() < 900)
	{
		if (!rules.isGameOver())
		{
			CPlayer@ owner = hitterBlob.getDamageOwnerPlayer();
			if (owner !is null)
				error(">Core teamHit (" +hitterTeamNum+ "): " + owner.getUsername()); 
		}
		
		damage /= 2;
	}
	
	const f32 hp = this.getHealth();
	if (!this.hasTag("critical") && hp - damage > 0.0f)//assign last team hitter
	{
		if (thisTeamNum != hitterTeamNum && hitterBlob.getName() != "whirlpool")
		{
			this.set_u8("lastHitterTeam", hitterTeamNum);
			this.set_u32("lastHitterTime", getGameTime());
		}
	}
	else
	{
		if (!this.hasTag("critical"))//deathHit(once)
		{
			initiateSelfDestruct(this);
			
			//increase captain deaths
			/*
			string defeatedCaptainName = getCaptainName(thisTeamNum);
			CPlayer@ defeatedCaptain = getPlayerByUsername(defeatedCaptainName);
			if (defeatedCaptain !is null)
			{
				defeatedCaptain.setDeaths(defeatedCaptain.getDeaths() + 1);
				if (defeatedCaptain.isMyPlayer())
					client_AddToChat("You lost your Mothership! A Core Death was added to your Scoreboard.", SColor(0xfffa5a00));
			}
			*/
			
			//rewards if they apply
			if (thisTeamNum == hitterTeamNum || hitterBlob.getName() == "whirlpool" || hitterBlob.hasTag("mothership"))//suicide. try with last good hitterTeam
				if (getGameTime() - this.get_u32("lastHitterTime") < 450)//15 seconds lease
					hitterTeamNum = this.get_u8("lastHitterTeam");
				else
					return Maths::Max(0.0f, hp - 1.0f);//no rewards
					
			//got a possible winner team
			u8 thisPlayers = 0;
			u8 hitterPlayers = 0;
			const u8 plyCount = getPlayersCount();
			for (u8 i = 0; i < plyCount; i++)
			{
				const u8 pteam = getPlayer(i).getTeamNum();
				if (pteam == thisTeamNum)
					thisPlayers++;
				else if (pteam == hitterTeamNum)
					hitterPlayers++;
			}
			
			CBlob@ hitterCore = getMothership(hitterTeamNum);
			if (hitterPlayers == 0 || hitterCore is null)//in case of suicide against leftover/empty team ship
				return Maths::Max(0.0f, hp - 1.0f);//no rewards
			
			//winSound
			CPlayer@ myPlayer = getLocalPlayer();
			if (myPlayer !is null && myPlayer.getTeamNum() == hitterTeamNum)
			{
				Sound::Play("KAGWorldQuickOut.ogg");
				Sound::Play("ResearchComplete.ogg");
			}
			
			//increase core kills for player who struck last blow
			CPlayer@ owner = hitterBlob.getDamageOwnerPlayer();
			if (owner !is null && owner.getTeamNum() != thisTeamNum)
			{
				owner.setAssists(owner.getAssists() + 1);
				if (owner.isMyPlayer())
					client_AddToChat(Trans::CoreKill, SColor(0xfffa5a00));
			}
			
			const f32 ratio = Maths::Max(0.25f, Maths::Min(1.75f,
							float(rules.get_u16("bootyTeam_total" + thisTeamNum))/float(rules.get_u32("bootyTeam_median") + 1.0f))); //I added 1.0f as a safety measure against dividing by 0
			
			const u16 totalReward = (thisPlayers + 1) * BASE_KILL_REWARD * ratio;
			const string bountyreward = Trans::TeamBounty.replace("{winnerteam}", teamColors[hitterTeamNum]+" "+
								  Trans::Team).replace("{reward}", (totalReward + BASE_KILL_REWARD)+"").replace("{killedteam}", teamColors[thisTeamNum]+" "+Trans::Team);
			client_AddToChat("*** "+ bountyreward +"! ***");
			
			//give rewards
			if (isServer())
			{
				const u16 reward = Maths::Round(totalReward/hitterPlayers);
				for (u8 i = 0; i < plyCount; i++)
				{
					CPlayer@ player = getPlayer(i);
					const u8 teamNum = player.getTeamNum();
					const string name = player.getUsername();
					if (teamNum == hitterTeamNum)//winning tam
					{
						server_addPlayerBooty(name, (name == getCaptainName(hitterTeamNum) ? 2 * reward : reward));
					}
					else if (teamNum == thisTeamNum)//losing team consolation money
					{
						const u16 booty = server_getPlayerBooty(name);
						const u16 rewardHalved = Maths::Round(BASE_KILL_REWARD/2);
						if (booty < rewardHalved)
							server_addPlayerBooty(name, rewardHalved);
					}
				}
				server_updateTotalBooty(hitterTeamNum, totalReward + BASE_KILL_REWARD);
				//print ("MothershipKill: " + thisPlayers + " players; " + ((thisPlayers + 1) * BASE_KILL_REWARD) + " to " + rules.getTeam(hitterTeamNum).getName());
			}
		}

		return Maths::Max(0.0f, hp - 1.0f);
	}
		
	return damage;
}

void onDie(CBlob@ this)
{
	selfDestruct(this);
	
	//if there is another mothership on our team, set the index to that mothership (only used in testing)
	CRules@ rules = getRules();
	CBlob@[] cores;
	getBlobsByTag("mothership", @cores);
	const u8 teamNum = this.getTeamNum();
	const u8 coresLength = cores.length;
	for (u8 i = 0; i < coresLength; i++)
	{
		CBlob@ core = cores[i];  
		if (core !is this && core.getTeamNum() == teamNum)
		{
			rules.setAt("motherships", teamNum, core.getNetworkID());
			return;
		}
	}
}

//healing, repelling, dmgmanaging, selfDestruct
void onTick(CBlob@ this)
{
	const Vec2f pos = this.getPosition();
	const u32 gameTime = getGameTime();
	CRules@ rules = getRules();
	//const int color = this.getShape().getVars().customData;
	
	//repel
	/*f32 hp = this.getHealth();
	Ship@ ship = getShipSet(rules).getShip(color);
	if (ship !is null)
	{
		CBlob@[] cores;
		getBlobsByTag("mothership", @cores);
		for (u8 i = 0; i < cores.length; i++)
		{
			f32 distance = cores[i].getDistanceTo(this);
			
			int color2 = cores[i].getShape().getVars().customData;
			if (cores[i] !is this && color != color2 && distance < 125.0f)
			{
				//sparks in the direction of the ship
				Vec2f dir = pos - cores[i].getPosition();
				dir.Normalize();
				
				f32 whirlpoolFactor = !getRules().get_bool("whirlpool") ? 2.0f : 1.25f;
				f32 healthFactor = Maths::Max(0.25f, hp/this.getInitialHealth());
				ship.vel += dir * healthFactor*whirlpoolFactor/distance;
				
				if (isClient())
				{
					dir.RotateBy(-45.0f);
					dir *= -6.0f * healthFactor;
					for (u8 i = 0; i < 5; i++)
					{
						CParticle@ p = ParticlePixel(pos, dir.RotateBy(15), getTeamColor(this.getTeamNum()), true);
						if (p !is null)
						{
							p.Z = 700.0f;
							p.timeout = 4;
						}
					}
				}
			}
		}
	}*/

	if (isClient() && gameTime % 60 == 0)
	{
		const u8 coreTeam = this.getTeamNum();

		//dmgmanaging
		const f32 msDMG = rules.get_f32("msDMG");
		if (msDMG > 0)
			rules.set_f32("msDMG", Maths::Max(msDMG - 0.75f, 0.0f));
	}

	//critical Slowdown, selfDestruct and effects
	if (this.hasTag("critical"))
	{
		//ship.vel *= 0.8f;

		if (isServer() && gameTime > this.get_u32("dieTime"))
			this.server_Die();
		
		//particles
		if (!v_fastrender)
		{
			CParticle@ p = ParticlePixel(pos, getRandomVelocity(90, 4, 360), getTeamColor(this.getTeamNum()), true);
			if (p !is null)
			{
				p.Z = 670.0f;
				p.timeout = XORRandom(3) + 2;
			}
		}
	}
	
	//displayed by ShiprektHUD.as
	if (isClient() && rules.get_bool("display_flak_team_max"))
	{
		maxBlockTimer++;
		if (maxBlockTimer >= 30*5)
		{
			rules.set_bool("display_flak_team_max", false);
			maxBlockTimer = 0;
		}
	}
}

//make shipblocks start exploding
void initiateSelfDestruct(CBlob@ this)
{
	const Vec2f pos = this.getPosition();
	//set timer for selfDestruct sequence
	this.Tag("critical");
	this.set_u32("dieTime", getGameTime() + SELF_DESTRUCT_TIME);
	
	if (isClient())
	{
		//effects
		directionalSoundPlay("ShipExplosion.ogg", pos, 2.0f);
		makeLargeExplosionParticle(pos);
	}

	//add block explosion scripts
	const int color = this.getShape().getVars().customData;
	Ship@ ship = getShipSet().getShip(color); 
	if (ship is null) return;
	
	const u16 blocksLength = ship.blocks.length;
	if (blocksLength < 10) return;
		
	this.AddScript("Block_Explode.as");
	const u8 teamNum = this.getTeamNum();
	for (u16 i = 0; i < blocksLength; ++i)
	{
		CBlob@ b = getBlobByNetworkID(ship.blocks[i].blobID);
		if (b !is null && teamNum == b.getTeamNum())
		{
			if (i % 4 == 0 && !b.hasTag("mothership") && !b.hasTag("coupling"))
				b.AddScript("Block_Explode.as");
		}
	}
}

//kill players, turrets and ship
void selfDestruct(CBlob@ this)
{
	const Vec2f pos = this.getPosition();

	//effects
	if (isClient())
	{
		directionalSoundPlay("ShipExplosion", pos, 2.0f);
		makeWaveRing(pos, 4.5f, 15);
		makeHugeExplosionParticle(pos);
		ShakeScreen(90, 80, pos);
		if (this.isOnScreen())
			SetScreenFlash(150, 255, 255, 255);
	}

	if (!isServer()) return;

	const u8 teamNum = this.getTeamNum();

	//kill team players
	CBlob@[] humans;
	getBlobsByName("human", @humans);
	const u8 humansLength = humans.length;
	for (u8 i = 0; i < humansLength; i++)
	{
		CBlob@ human = humans[i];
		if (human.getTeamNum() == teamNum)
			this.server_Hit(human, human.getPosition(), Vec2f_zero, human.getInitialHealth(), 44, true);
			//hitter set to 44 so human dies no matter what
	}

	//blocks go neutral
	CBlob@[] blocks;
	getBlobsByTag("weapon", @blocks);
	getBlobsByTag("hasSeat", @blocks);
	const u16 turretsLength = blocks.length;
	for (u16 i = 0; i < turretsLength; i++)
	{
		CBlob@ block = blocks[i];
		if (block.getTeamNum() == teamNum)
			block.server_setTeamNum(-1);
	}

	//damage nearby blobs
	CBlob@[] blastBlobs;
	getMap().getBlobsInRadius(pos, BLAST_RADIUS, @blastBlobs);
	const u16 blastBlobsLength = blastBlobs.length;
	for (u16 i = 0; i < blastBlobsLength; i++)
	{
		CBlob@ blastBlob = blastBlobs[i];
		if (blastBlob is this) continue;

		const f32 maxHealth = blastBlob.getInitialHealth();
		const f32 damage = 1.5f * maxHealth * (BLAST_RADIUS - this.getDistanceTo(blastBlob))/BLAST_RADIUS;
		this.server_Hit(blastBlob, pos, Vec2f_zero, Maths::Max(0.1f, damage), Hitters::bomb, true);
	}

	//kill ship
	Ship@ ship = getShipSet().getShip(this.getShape().getVars().customData);
	if (ship is null) return;

	const u16 blocksLength = ship.blocks.length;
	if (blocksLength < 10 || ship.isStation) return;

	for (u16 i = 0; i < blocksLength; ++i)
	{
		CBlob@ b = getBlobByNetworkID(ship.blocks[i].blobID);
		if (b !is null && b !is this && teamNum == b.getTeamNum())
			b.server_Die();
	}
}
