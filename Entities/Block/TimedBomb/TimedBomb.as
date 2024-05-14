#include "Hitters.as";
#include "ExplosionEffects.as";
#include "ShipsCommon.as";
#include "DamageBooty.as";
#include "AccurateSoundPlay.as"

const u8 FUSE_TIME = 60;

BootyRewards@ booty_reward;

Random _effectsrandom(0x15125); //clientside

void onInit(CBlob@ this)
{

	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 20);
		_booty_reward.addTagReward("mothership", 35);
		_booty_reward.addTagReward("secondarycore", 25);
		_booty_reward.addTagReward("weapon", 20);
		_booty_reward.addTagReward("solid", 15);
		_booty_reward.addTagReward("seat", 20);
		_booty_reward.addTagReward("platform", 5);
		_booty_reward.addTagReward("door", 15);
		@booty_reward = _booty_reward;
	}

	this.Tag("timedbomb");
	this.Tag("solid");
	this.Tag("removable"); //for corelinked checks
	this.set_f32("weight", 2.0f);
	this.getShape().getConsts().collidable = true;
	
	this.addCommandID("chainReaction");
	this.addCommandID("activate");
	this.set_u32("detonationTime", 0);
	this.set_u8("gibType", 1);
	this.server_SetHealth(3.0f);

	CSprite@ sprite = this.getSprite();
	//default animation	
	{
		Animation@ anim = sprite.addAnimation("default", 0, false);
		anim.AddFrame(0);
	}
	//activated animation
	{
		Animation@ anim = sprite.addAnimation("activated", FUSE_TIME/5.5f, false);

		int[] frames = {1, 2, 3, 4, 5};
		anim.AddFrames(frames);
	}
}

const u8 findCloseBombs(CBlob@ this)
{
	u8 factor = 0;
	CBlob@[] blobs;
	getMap().getBlobsInRadius(this.getPosition(), 12.0f, @blobs);
	const u8 blobsLength = blobs.length;
	for (u8 i = 0; i < blobsLength; i++)
	{
		CBlob@ blob = blobs[i];
		if (blob.hasTag("bomb"))
		{
			factor++;
		}
	}
	
	return factor;
}


void Explode(CBlob@ this, const f32&in BOMB_RADIUS, const f32&in BOMB_BASE_DAMAGE)
{
	const Vec2f pos = this.getPosition();
	const u8 stackfactor = findCloseBombs(this);

	if (isClient())
	{
		directionalSoundPlay("Bomb.ogg", pos);
		makeLargeExplosionParticle(pos);
		ShakeScreen(4 * BOMB_RADIUS + stackfactor, 45, pos);
	}

	//hit blobs
	CBlob@[] blobs;
	if (!getMap().getBlobsInRadius(pos, (BOMB_RADIUS-3) + (stackfactor*3), @blobs))
		return;
	
	ShipDictionary@ ShipSet = getShipSet();
	const u8 blobsLength = blobs.length;
	for (u8 i = 0; i < blobsLength; i++)
	{
		CBlob@ hit_blob = blobs[i];
		if (hit_blob is this) continue;
		
		const int hitCol = hit_blob.getShape().getVars().customData;

		if (isServer())
		{
			Vec2f hit_blob_pos = hit_blob.getPosition();  

			if (hit_blob.hasTag("block"))
			{
				if (hitCol <= 0) continue;

				// move the ship
				Ship@ ship = ShipSet.getShip(hitCol);
				if (ship !is null && ship.mass > 0.0f)
				{
					Vec2f impact = (hit_blob_pos - pos) * 0.15f / ship.mass;
					ship.vel += impact;
				}
			}
		
			const f32 distanceFactor = Maths::Min(1.0f, Maths::Max(0.0f, BOMB_RADIUS - this.getDistanceTo(hit_blob) + 8.0f + (stackfactor/2)) / BOMB_RADIUS);
			//f32 distanceFactor = 1.0f;
			const f32 damageFactor = (hit_blob.hasTag("mothership")) ? 0.25f : 1.0f;

			//hit the object
			this.server_Hit(hit_blob, hit_blob_pos, Vec2f_zero, BOMB_BASE_DAMAGE * distanceFactor * damageFactor + (stackfactor/3), Hitters::bomb, true);
			//print(hit_blob.getNetworkID() + " for: " + BOMB_BASE_DAMAGE * distanceFactor + " dFctr: " + distanceFactor + ", dist: " + this.getDistanceTo(hit_blob));
		}
		
		CPlayer@ owner = this.getDamageOwnerPlayer();
		if (owner !is null && hitCol > 0)
		{
			rewardBooty(owner, hit_blob, booty_reward, "Pinball_3");
		}
	}
	this.server_Die();
}



void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return;
	
	CPlayer@ owner = getPlayerByUsername(this.get_string("playerOwner"));
	if (owner !is null)
		this.SetDamageOwnerPlayer(owner);

	if (this.hasTag("activated"))
	{
		const u32 gameTime = getGameTime();
		if (gameTime == this.get_u32("detonationTime"))
			Explode(this, 20.0f, 5.0f);	
	}
		//go neutral if bomb is placed on an enemy owned ship
	if (isServer())
	{
		CBlob@[] overlapping;
		this.getOverlapping(@overlapping);
		
		const u8 overlappingLength = overlapping.length;
		for (u8 i = 0; i < overlappingLength; i++)
		{
			CBlob@ b = overlapping[i];
			if (b.getShape().getVars().customData == col && this.getTeamNum() != b.getTeamNum())
			{
				this.server_setTeamNum(255);
				break;
			}
		}
	}
}

void Activate(CBlob@ this, const u32&in time)
{
	this.Tag("activated");
	this.set_u32("detonationTime", time);
	if (isClient())
	{
		this.getSprite().SetAnimation("activated");
		directionalSoundPlay("ChargeUp3.ogg", this.getPosition(), 3.75f);
	}
}

void ChainReaction(CBlob@ this, const u32&in time)
{
	CBitStream bs;
	bs.write_u32(time);
	this.SendCommand(this.getCommandID("activate"), bs);

	CBlob@[] overlapping;
	this.getOverlapping(@overlapping);
	
	const u8 overlappingLength = overlapping.length;
	for (u8 i = 0; i < overlappingLength; i++)
	{
		CBlob@ b = overlapping[i];
		if (b.hasTag("timedbomb") && !b.hasTag("activated") && b.getShape().getVars().customData > 0 && b.getDistanceTo(this) < 8.8f)
		{
			ChainReaction(b, time); //repeat until all connected repulsors are activated
		}
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (hitterBlob.hasTag("engine") && this.getHealth() / this.getInitialHealth() < 0.5f)
		this.Tag("disabled");
	
	if (customData == Hitters::bomb)
	{
		this.server_Die();
	}
	
	return damage;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("activate") && !this.hasTag("activated"))
		Activate(this, params.read_u32());
	else if (isServer() && cmd == this.getCommandID("chainReaction") && !this.hasTag("activated"))
		ChainReaction(this, getGameTime() + FUSE_TIME);
}

void onDie(CBlob@ this)
{
	if (this.getShape().getVars().customData > 0)
	{
		this.getSprite().Gib();
		if (!this.hasTag("disabled"))
			Explode(this, 10.0f, 1.5f);
	}
}

