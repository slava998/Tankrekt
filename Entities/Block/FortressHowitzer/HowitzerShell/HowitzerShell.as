#include "ExplosionEffects.as";;
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "Hitters.as";
#include "PlankCommon.as";
#include "TileCommon.as";

const f32 EXPLODE_RADIUS = 30.0f;		//Raycast range
const f32 RAYCAST_DAMAGE = 2.0f; 		//There's 32 raycasts with this damage so it is not small
const u8  RAYCAST_NUM = 32; 			//Number of explosion rays fired in a circle
const u8  PIERCE_NUM = 3;				//How many blocks raycast can pierce
const f32 SPLASH_RADIUS = 12.0f;		//Splash is a damage through walls
const f32 SPLASH_DAMAGE = 2.0f; 		//Splash is a damage through walls
const f32 RAYCAST_DAMAGE_CORE = 1.0f; 	//Damage for cores
const f32 SPLASH_DAMAGE_CORE = 2.0f;	//Damage for cores

BootyRewards@ booty_reward;

void onInit(CBlob@ this)
{
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 3);
		_booty_reward.addTagReward("engine", 3);
		_booty_reward.addTagReward("weapon", 3);
		_booty_reward.addTagReward("core", 6);
		@booty_reward = _booty_reward;
	}

	this.Tag("projectile");

	ShapeConsts@ consts = this.getShape().getConsts();
	consts.mapCollisions = true;
	consts.bullet = true;

	CSprite@ sprite = this.getSprite();
	sprite.SetZ(550.0f);
	sprite.SetEmitSound("Shell_Whistle.ogg");
	sprite.SetEmitSoundPaused(false);
	sprite.SetEmitSoundVolume(4);
	sprite.ScaleBy(Vec2f(0.7,0.8));
	
	//shake screen (onInit accounts for firing latency)
	CPlayer@ localPlayer = getLocalPlayer();
	if (localPlayer !is null && localPlayer is this.getDamageOwnerPlayer())
		ShakeScreen(4, 4, this.getPosition());
}

void onCollision(CBlob@ this, CBlob@ b, bool solid, Vec2f normal, Vec2f point1)
{
	if (b is null) //solid tile collision
	{
		this.server_Die();
		return;
	}

	if (!isServer()) return;
	
	if ((b.hasTag("plank") && !CollidesWithPlank(b, this.getVelocity())) || b.hasTag("non-solid") || !b.getShape().getConsts().collidable)
		return;
	
	//blow up inside the target
	if ((b.hasTag("solid")) || b.hasTag("door") || 
		((b.hasTag("core") || b.hasTag("weapon") || b.hasTag("projectile") || b.hasTag("bomb")) || (b.hasTag("player") && !b.isAttached())))
		this.server_Die();
}

void Explode(CBlob@ this)
{
	const Vec2f pos = this.getPosition() - this.getVelocity();

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
				this.server_Hit(hit_blob, hit_blob_pos, Vec2f_zero, hit_blob.hasTag("core") ? SPLASH_DAMAGE_CORE : SPLASH_DAMAGE, Hitters::bomb, true);
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
					if(!absorbed || b.hasTag("armor")) this.server_Hit(b, hitInfos[i].hitpos, Vec2f_zero, dmg / hitnum, Hitters::bomb, true);

					if(hitnum > PIERCE_NUM) break;
				}
			}
		}
	}
}

void onDie(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	
	if (isClient())
	{
		directionalSoundPlay("ArtilleryShellExplode" + XORRandom(6), pos, 10.0f);
		makeHugeExplosionParticle(pos);
		ShakeScreen(4 * EXPLODE_RADIUS, 45, pos);
		const u8 particleAmount = v_fastrender ? 8 : 16;

		for (u8 i = 0; i < particleAmount; i++)
		{
			CParticle@ p = ParticleAnimated(CFileMatcher("GenericSmoke4.png").getFirst(), 
							pos + Vec2f(XORRandom(30) - XORRandom(30), XORRandom(30) - XORRandom(30)), 
							Vec2f(0.5f + 0.008 *(XORRandom(5) - XORRandom(5)), -0.25f + 0.002 *(XORRandom(5) - XORRandom(5))), 
							0, 
							1.0f, 
							20 + XORRandom(8), 
							0.0f, 
							false);
			if (p !is null)
			p.Z = 640.0f;
		}
	}

	if(isTouchingLand(pos)) //no holes in water
	{
		CParticle@ hole = makeGibParticle("Explosion_Hole_Big.png",
													pos,
													Vec2f_zero,
													0,
													0,
													Vec2f (58,59),
													1,
													0,
													"/BodyGibFall");

		if (hole !is null)
		{
			hole.timeout = 5600;
			hole.Z = -5.0f;
		}
	}
	
	if (isServer() && !this.hasTag("noFlakBoom"))
		Explode(this);
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	CPlayer@ owner = this.getDamageOwnerPlayer();
	if (owner !is null)
	{
		rewardBooty(owner, hitBlob, booty_reward);
	}
	
	if (!isClient()) return;
	
	if (hitBlob.hasTag("block"))
	{
		Vec2f vel = worldPoint - hitBlob.getPosition();
		ShrapnelParticle(worldPoint, vel);
		directionalSoundPlay("Ricochet" +  (XORRandom(3) + 1) + ".ogg", worldPoint, 0.35f);
	}
}