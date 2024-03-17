#include "Hitters.as";
#include "ExplosionEffects.as";
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";

const f32 EXPLODE_RADIUS = 28.0f;		//Raycast range
const f32 RAYCAST_DAMAGE = 4.0f; 		//There's 20 raycasts with this damage so it is not small
const u8  RAYCAST_NUM = 20; 			//Number of explosion rays fired in a circle
const u8  PIERCE_NUM = 4;				//How many blocks raycast can pierce
const f32 SPLASH_RADIUS = 12.0f;		//Splash is a damage through walls
const f32 SPLASH_DAMAGE = 3.0f; 		//Splash is a damage through walls
const f32 RAYCAST_DAMAGE_CORE = 1.0f; 	//Damage for cores
const f32 SPLASH_DAMAGE_CORE = 2.0f;	//Damage for cores

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
	print("factor");
	return factor;
}

void Explode(CBlob@ this)
{
	const Vec2f pos = this.getPosition();
	const u8 stackfactor = findCloseBombs(this);

	if (isClient())
	{
		directionalSoundPlay("Bomb.ogg", pos);
		makeLargeExplosionParticle(pos);
		ShakeScreen(4 * EXPLODE_RADIUS + stackfactor, 45, pos);
	}

	//Splash that hits through the walls. Also it pushes blocks.
	CBlob@[] pblobs;
	if (getMap().getBlobsInRadius(pos, SPLASH_RADIUS, @pblobs))
	{
		
		ShipDictionary@ ShipSet = getShipSet();
		const u8 blobsLength = pblobs.length;
		for (u8 i = 0; i < blobsLength; i++)
		{
			CBlob@ hit_blob = pblobs[i];
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
						Vec2f impact = (hit_blob_pos - pos) * 0.3f / ship.mass;
						ship.vel += impact;
					}
				}

				if(hit_blob.hasTag("solid") || hit_blob.hasTag("door") || hit_blob.hasTag("seat") || hit_blob.hasTag("weapon") || hit_blob.hasTag("projectile") || hit_blob.hasTag("core") || hit_blob.hasTag("bomb") || (hit_blob.hasTag("player") && !hit_blob.isAttached()))
				//hit the object
				this.server_Hit(hit_blob, hit_blob_pos, Vec2f_zero, (hit_blob.hasTag("core") ? SPLASH_DAMAGE_CORE : SPLASH_DAMAGE), Hitters::bomb, true);
			}
		}
	}
	//Firing raycasts

	CMap@ map = getMap();
	CBlob@[] blobs;
	map.getBlobsInRadius(pos, EXPLODE_RADIUS, @blobs);
	
	if (blobs.length < 2) return;

	for (u8 s = 0; s <= RAYCAST_NUM; s++)
	{
		f32 angle = (360 / RAYCAST_NUM) * s; //firing in a circle

		HitInfo@[] hitInfos;
		if (map.getHitInfosFromRay(pos, angle, EXPLODE_RADIUS, this, @hitInfos))
		{
			u8 hitnum = 1;
			bool absorbed = false;
	
			const u8 hitLength = hitInfos.length;
			for (u8 i = 0; i < hitLength; i++)//sharpnel trail
			{
				CBlob@ b = hitInfos[i].blob;
				if (b is null || b is this) continue;
				
				const bool sameTeam = b.getTeamNum() == this.getTeamNum();
				if (b.hasTag("solid") || b.hasTag("door") || (!sameTeam
					&& (b.hasTag("seat") || b.hasTag("weapon") || b.hasTag("projectile") || b.hasTag("core") || b.hasTag("bomb") || (b.hasTag("player") && !b.isAttached()))))
				{
				
					//hit the object
					if(b.hasTag("armor")) absorbed = true; //if a projectile hits armor, only armor blocks take damage
					hitnum++;
					f32 dmg = b.hasTag("core") ? RAYCAST_DAMAGE_CORE : RAYCAST_DAMAGE;
					if(!absorbed || b.hasTag("armor")) this.server_Hit(b, hitInfos[i].hitpos, Vec2f_zero, (dmg / hitnum), Hitters::bomb, true);

					//particles
					if(isClient())
					{
						CParticle@ p = ParticleAnimated("Entities/Effects/Sprites/WhitePuff2.png",
									pos,
									Vec2f(1,0).RotateBy(angle),
									1.0f, 0.5f, 
									2, 
									0.0f, true);
									
						if (p !is null)
						p.Z = 650;
					}
				
					if(hitnum > PIERCE_NUM) break;
				}
			}
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
