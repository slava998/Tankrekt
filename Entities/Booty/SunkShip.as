#include "Booty.as";
#include "ShipsCommon.as";
#include "AccurateSoundPlay.as"
#include "TileCommon.as"

const u8 CHECK_FREQUENCY = 30; //30 = 1 second
const u32 FISH_RADIUS = 65.0f; //pickup radius
const f32 MAX_REWARD_FACTOR = 0.13f; //% taken per check for mothership (goes fully to captain if no one else on the ship)
const f32 CREW_REWARD_FACTOR = MAX_REWARD_FACTOR/5.0f;
const f32 CREW_REWARD_FACTOR_MOTHERSHIP = MAX_REWARD_FACTOR/2.5f;
const u32 AMOUNT_INSTANT_PICKUP = 50;
const u8 SPACE_HOG_TICKS = 15; //seconds after collecting where no Xs can spawn there

void onInit(CBlob@ this)
{
	this.Tag("booty");
	this.getCurrentScript().tickFrequency = CHECK_FREQUENCY;
	this.set_u8("killtimer", SPACE_HOG_TICKS);
	
	if (!isInWater(this.getPosition()))
		this.server_Die();
}

void onInit(CSprite@ this)
{
	this.ReloadSprites(0, 0);
	const u16 amount = this.getBlob().get_u16("amount");
	const f32 size = amount/ (getRules().get_u16("booty_x_max") * 0.3f);
	if (size >= 1.0f)
		this.ScaleBy(Vec2f(size, size));
	this.SetZ(-15.0f);
	this.RotateBy(XORRandom(360), Vec2f_zero);
}

void onTick(CBlob@ this)
{
	CMap@ map = getMap();
	Vec2f pos = this.getPosition();
	const u16 amount = this.get_u16("amount");
	
	if (amount == 0)
	{
		this.SetVisible(false);

		u8 killtimer = this.get_u8("killtimer");
		if (killtimer == SPACE_HOG_TICKS)
			directionalSoundPlay("/ChaChing.ogg", pos);
			
		if (map.isBlobWithTagInRadius("mothership", pos, FISH_RADIUS * 3.0f))
			killtimer = SPACE_HOG_TICKS;
			
		this.set_u8("killtimer", killtimer - 1);
		
		if (isServer() && killtimer == 1)
			this.server_Die();
		
		return;
	}
	
	CRules@ rules = getRules();
	
	string[] served;
	bool gaveBooty = false;

	//booty to motherships captain crew
	CBlob@[] humans;
	getBlobsByTag("player", @humans);
	CBlob@[] cores;
	getBlobsByTag("mothership", @cores);
	ShipDictionary@ ShipSet = getShipSet(rules);
	const u16 minBooty = rules.get_u16("bootyRefillLimit");
	const u8 coresLength = cores.length;
	const u8 humansLength = humans.length;
	for (u8 i = 0; i < coresLength; i++)
	{
		const int coreColor = cores[i].getShape().getVars().customData;
		if (coreColor <= 0) continue;
		
		Ship@ ship = ShipSet.getShip(coreColor);
		if (ship is null || ship.owner.isEmpty() || ship.owner == "*")
			continue;
			
		served.push_back(ship.owner); //captains only gather through the core
		string[] crew;
		if (this.getDistanceTo(cores[i]) <= FISH_RADIUS)
		{
			bool captainOnShip = false;
			for (u8 i = 0; i < humansLength; i++) //get crew on mothership and check if captain is there
			{
				CBlob@ human = humans[i];
				CPlayer@ player = human.getPlayer();
				if (player is null) continue;
					
				CBlob@ shipBlob = getBlobByNetworkID(human.get_u16("shipBlobID"));
				if (shipBlob is null || shipBlob.getShape().getVars().customData != coreColor)
					continue;
					
				const string pName = player.getUsername();
				if (pName == ship.owner)
					captainOnShip = true;
				else if (server_getPlayerBooty(pName) < minBooty * 4)
					crew.push_back(pName);
				else //wealthy or slacker on the mShip
					served.push_back(pName);
			}
			
			if (!captainOnShip)//go to next core
				continue;
				
			const u8 crewLength = crew.length;
				
			const u16 mothership_maxReward = Maths::Ceil(amount * MAX_REWARD_FACTOR);
			const f32 mothership_crewRewardFactor = Maths::Min(MAX_REWARD_FACTOR * 0.5f,  CREW_REWARD_FACTOR_MOTHERSHIP * crewLength);
			const u16 mothership_crewTotalReward = Maths::Round(amount * mothership_crewRewardFactor);

			//booty to captain
			u16 captainReward = mothership_maxReward - mothership_crewTotalReward;
			if (amount - captainReward <= AMOUNT_INSTANT_PICKUP)
				captainReward = AMOUNT_INSTANT_PICKUP;
			server_giveBooty(ship.owner, captainReward);
			server_updateX(this, captainReward, true);
			gaveBooty = true;

			//booty to crew
			if (crewLength == 0 || !isServer())
				continue;
				
			for (u8 i = 0; i < crewLength; i++)
			{
				const string name = crew[i];
				served.push_back(name);
				const f32 rewardFactor = Maths::Max(mothership_crewRewardFactor/crewLength, CREW_REWARD_FACTOR);
				const u16 reward = Maths::Ceil(amount * rewardFactor);
				server_giveBooty(name, reward);
				server_updateX(this, reward, false);
			}
		}
	}
	
	//booty to over-sea crew
	for (u8 i = 0; i < humansLength; i++)
	{
		CBlob@ human = humans[i];
		CPlayer@ player = human.getPlayer();
		if (player is null) continue;

		const string name = player.getUsername();
		if (this.getDistanceTo(human) <= FISH_RADIUS && served.find(name) == -1)
		{
			const u16 reward = Maths::Ceil(amount * CREW_REWARD_FACTOR);
			server_giveBooty(name, reward);
			server_updateX(this, reward, !gaveBooty);
			gaveBooty = true;
		}
	}
	
	if (gaveBooty)
		directionalSoundPlay("/select.ogg", pos, 0.65f);
	else if (isServer())//bleed out
	{
		if (amount < AMOUNT_INSTANT_PICKUP)
			this.server_Die();
		else if (amount > 0 && (amount < rules.get_u16("booty_x_min") || this.getTickSinceCreated() > 3600))
			server_updateX(this, 2, false);
	}
}

void server_updateX(CBlob@ this, const u16&in reward, const bool&in instaPickup = true)
{
	if (!isServer()) return;
	
	const u16 amount = this.get_u16("amount");
		
	//if X is small enough, kill it and give remaining booty to player
	if (instaPickup && amount - reward <= AMOUNT_INSTANT_PICKUP)
		this.set_u16("amount", 0);
	else
		this.set_u16("amount", Maths::Max(0, amount - reward));

	this.Sync("amount", true); //522519900 HASH
}

void server_giveBooty(const string&in name, const u16&in amount)
{
	if (!isServer()) return;

	CPlayer@ player = getPlayerByUsername(name);
	if (player is null) return;

	server_addPlayerBooty(name, amount);
	server_updateTotalBooty(player.getTeamNum(), amount);
}

void onTick(CSprite@ this)
{
	this.RotateBy(0.5f, Vec2f_zero);
	if (this.animation.name == "default" && this.animation.ended())
		this.SetAnimation("pulse");

	CBlob@ blob = this.getBlob();
	const f32 amount = blob.get_u16("amount");	
	const f32 prevAmount = blob.get_u16("prevAmount");
	blob.set_u16("prevAmount", amount);
	const f32 change = prevAmount - amount;
	
	if (change > 0)
	{
		const f32 size = amount/prevAmount;
		this.ScaleBy(Vec2f(size, size));
	}
}
