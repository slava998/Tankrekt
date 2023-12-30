#include "WaterEffects.as";
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "TileCommon.as";
#include "ParticleSpark.as";
#include "Hitters.as";
#include "PlankCommon.as";

const f32 SPLASH_RADIUS = 8.0f;
const f32 SPLASH_DAMAGE = 0.25f;
const f32 MAX_PIERCED = 2;

BootyRewards@ booty_reward;

void onInit(CBlob@ this)
{
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 4);
		_booty_reward.addTagReward("engine", 3);
		_booty_reward.addTagReward("weapon", 4);
		_booty_reward.addTagReward("core", 6);
		@booty_reward = _booty_reward;
	}

	this.Tag("cannonball");
	this.Tag("projectile");

	ShapeConsts@ consts = this.getShape().getConsts();
	consts.mapCollisions = true;
	consts.bullet = true;
	
	this.SetMapEdgeFlags(CBlob::map_collide_none);
	
	this.set_u16("pierced count", 0);

	this.getSprite().SetZ(550.0f);
}

void onCollision(CBlob@ this, CBlob@ b, bool solid, Vec2f normal, Vec2f point1)
{
	if (b is null) //solid tile collision
	{
		if (isClient())
		{
			sparks(point1, v_fastrender ? 5 : 15, 2.5f, 20);
			directionalSoundPlay("MetalImpact" + (XORRandom(2) + 1), point1);
		}
		this.server_Die();
		return;
	}

	if (!isServer()) return;
	
	if (b.hasTag("plank") && !CollidesWithPlank(b, this.getVelocity()))
		return;
	
	u16 piercedCount = this.get_u16("pierced count");

	bool killed = false;
	const int color = b.getShape().getVars().customData;
	const bool sameTeam = b.getTeamNum() == this.getTeamNum();
	const bool isBlock = b.hasTag("block");
	
	if (color > 0 || !isBlock)
	{
		if (isBlock)
		{
			if (b.hasTag("solid") || (b.hasTag("door") && b.getShape().getConsts().collidable) || 
				(!sameTeam && (b.hasTag("core") || b.hasTag("weapon") || b.hasTag("bomb")))) //hit these and die
			{
				if (piercedCount >= MAX_PIERCED)
					killed = true;
				else
				{
					this.setVelocity(this.getVelocity() * 0.5f);
				}
				piercedCount++;
			}
			else if (b.hasTag("hasSeat"))
			{
				AttachmentPoint@ seat = b.getAttachmentPoint(0);
				CBlob@ occupier = seat.getOccupied();
				if (occupier !is null && occupier.getName() == "human" && occupier.getTeamNum() != this.getTeamNum())
				{
					if (piercedCount >= MAX_PIERCED)
						killed = true;
					else
					{
						this.setVelocity(this.getVelocity() * 0.5f);
					}
					piercedCount++;
				}
				else return;
			}
			else return;
		}
		else
		{
			if (sameTeam || (b.hasTag("player") && b.isAttached()) || b.hasTag("projectile")) //don't hit
				return;
		}
		
		this.set_u16("pierced count", piercedCount);
		
		this.server_Hit(b, point1, Vec2f_zero, getDamage(this, b), Hitters::ballista, true);
		
		if (killed) 
		{
			this.server_Die(); 
			return;
		}
	}
}

const f32 getDamage(CBlob@ this, CBlob@ hitBlob)
{
	const u16 piercedCount = this.get_u16("pierced count");
	f32 damageFactor = 1.0f;
	
	if (piercedCount > 2)
		damageFactor = 0.15f;
	else if (piercedCount > 1)
		damageFactor = 0.35f;
	
	if (hitBlob.hasTag("ramengine"))
		return 2.0f * damageFactor;
	if (hitBlob.hasTag("propeller"))
		return 1.65f * damageFactor;
	if (hitBlob.hasTag("seat") || hitBlob.hasTag("plank"))
		return 1.5f * damageFactor;
	if (hitBlob.hasTag("weapon"))
		return 1.35f * damageFactor;
	if (hitBlob.getName() == "shark" || hitBlob.getName() == "human")
		return 0.9f * damageFactor;
	if (hitBlob.hasTag("mothership"))
		return 0.4f * damageFactor;

	return 0.55f *damageFactor;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	CPlayer@ owner = this.getDamageOwnerPlayer();
	if (owner !is null)
	{
		CBlob@ blob = owner.getBlob();
		if (blob !is null)
			rewardBooty(owner, hitBlob, booty_reward);
	}
	
	if (!isClient()) return;
	
	if (customData == 9 || damage <= 0.0f) return;

	if (hitBlob.hasTag("solid") || hitBlob.hasTag("core") || hitBlob.hasTag("door") || hitBlob.hasTag("seat") || hitBlob.hasTag("weapon"))
	{
		sparksDirectional(worldPoint + this.getVelocity(), this.getVelocity(), v_fastrender ? 4 : 7);
		directionalSoundPlay("Pierce1.ogg", worldPoint);
			
		if (hitBlob.hasTag("mothership"))
			directionalSoundPlay("Entities/Characters/Knight/ShieldHit.ogg", worldPoint);
	}
}

void onDie(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	
	if (isClient())
	{
		if (!isInWater(pos))
		{
			sparks(pos + this.getVelocity(), v_fastrender ? 5 : 15, 2.5, 20);
			directionalSoundPlay("MetalImpact" + (XORRandom(2) + 1), pos);
		}
		else if (this.getTouchingCount() <= 0)
		{
			MakeWaterParticle(pos, Vec2f_zero);
			directionalSoundPlay("WaterSplashBall.ogg", pos);
		}
	}
	
	if (!isServer()) return;
	
	//splash damage
	CBlob@[] blobsInRadius;
	if (getMap().getBlobsInRadius(pos, SPLASH_RADIUS, @blobsInRadius))
	{
		const u8 blobsLength = blobsInRadius.length;
		for (u8 i = 0; i < blobsLength; i++)
		{
			CBlob@ b = blobsInRadius[i];
			if (!b.hasTag("hasSeat") && b.hasTag("block") && b.getShape().getVars().customData > 0)
				this.server_Hit(b, Vec2f_zero, Vec2f_zero, SPLASH_DAMAGE, 9, false);
		}
	}
}

Random _sprk_r;
void sparksDirectional(const Vec2f&in pos, Vec2f&in blobVel, const u8&in amount)
{
	for (u8 i = 0; i < amount; i++)
	{
		Vec2f vel(_sprk_r.NextFloat() * 5.0f, 0);
		vel.RotateBy((-blobVel.getAngle() + 180.0f) + _sprk_r.NextFloat() * 30.0f - 15.0f);

		CParticle@ p = ParticlePixel(pos, vel, SColor( 255, 255, 128+_sprk_r.NextRanged(128), _sprk_r.NextRanged(128)), true);
		if (p is null) return; //bail if we stop getting particles

		p.timeout = 20 + _sprk_r.NextRanged(20);
		p.scale = 1.0f + _sprk_r.NextFloat();
		p.damping = 0.85f;
		p.Z = 650.0f;
	}
}
