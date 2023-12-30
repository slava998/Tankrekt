#include "Hitters.as";
#include "ExplosionEffects.as";
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";

const f32 BOMB_RADIUS = 15.0f;
const f32 BOMB_BASE_DAMAGE = 2.7f;

BootyRewards@ booty_reward;

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
	
	this.Tag("bomb");
	//this.Tag("ramming");
	this.set_u8("gibType", 1);
	//this.getCurrentScript().tickFrequency = 60;
	
	this.set_f32("weight", 2.0f);
	
	/*CSprite@ sprite = this.getSprite();
	if (sprite !is null)
	{
		//default animation
		{
			Animation@ anim = sprite.addAnimation("default", 0, false);
			anim.AddFrame(0);
		}
		//exploding "warmup" animation
		{
			Animation@ anim = sprite.addAnimation("exploding", 2, true);

			int[] frames = {
				1, 1,
				2, 2,
				0, 0,
				0, 0,

				1, 1,
				2, 2,
				0, 0,
				0,

				1,
				2,
				0, 0,

				1,
				2,
				0, 0,

				1,
				2,
				0, 0,

				1,
				2,
				0, 0,

				1,
				2,
				0, 0,
			};

			anim.AddFrames(frames);
		}
	}*/
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return;
	
	CPlayer@ owner = getPlayerByUsername(this.get_string("playerOwner"));
	if (owner !is null)
		this.SetDamageOwnerPlayer(owner);
	
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
	this.getCurrentScript().tickFrequency = 0; //only tick once, when this block is placed
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

void Explode(CBlob@ this, const f32&in radius = BOMB_RADIUS)
{
	const Vec2f pos = this.getPosition();
	const u8 stackfactor = findCloseBombs(this);

	if (isClient())
	{
		directionalSoundPlay("Bomb.ogg", pos);
		makeLargeExplosionParticle(pos);
		ShakeScreen(4 * radius + stackfactor, 45, pos);
	}

	//hit blobs
	CBlob@[] blobs;
	if (!getMap().getBlobsInRadius(pos, (radius-3)+ (stackfactor*3), @blobs))
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
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (isClient() && customData == Hitters::bomb)
	{
		//explosion particle
		makeSmallExplosionParticle(worldPoint);
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

void onDie(CBlob@ this)
{
	if (this.getShape().getVars().customData > 0)
	{
		this.getSprite().Gib();
		if (!this.hasTag("disabled"))
			Explode(this);
	}
}

/*void StartDetonation(CBlob@ this)//not being used
{
	this.server_SetTimeToDie(2);
	CSprite@ sprite = this.getSprite();
	sprite.SetAnimation("exploding");
	sprite.SetEmitSound("/bomb_timer.ogg");
	sprite.SetEmitSoundPaused(false);
	sprite.RewindEmitSound();
}*/
