#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "Hitters.as";
#include "PlankCommon.as";

const f32 SPLASH_RADIUS = 8.0f;

const f32 ROCKET_FORCE = 86.0f;
const int ROCKET_DELAY = 15;
const int ROCKET_FUEL = 15;

Random _effectspreadrandom(0x11598); //clientside

BootyRewards@ booty_reward;

void onInit(CBlob@ this)
{
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 20);
		_booty_reward.addTagReward("engine", 15);
		_booty_reward.addTagReward("mothership", 30);
		_booty_reward.addTagReward("secondarycore", 25);
		_booty_reward.addTagReward("weapon", 20);
		_booty_reward.addTagReward("solid", 15);
		@booty_reward = _booty_reward;
	}
	
	this.Tag("projectile");
	this.Tag("rocket");
	
	this.SetMapEdgeFlags(CBlob::map_collide_none);

	ShapeConsts@ consts = this.getShape().getConsts();
    consts.mapCollisions = true;
	consts.bullet = true;	

	this.set_u32("last smoke puff", 0);
	
	this.getSprite().ScaleBy(Vec2f(0.75,0.375));
}

void onTick(CBlob@ this)
{	
	Vec2f pos = this.getPosition();

	if(isClient()) //displays currnent piercing force if debug is on
	{
		if(getGameTime() % 2 == 0 && g_debug > 0)
		{
			const u8 max_pierced = Maths::Floor(this.getVelocity().Length() / 1.2f);
			
			CParticle@ p = ParticleAnimated(CFileMatcher("num_" + max_pierced).getFirst(), 
											pos, 
											Vec2f_zero, 
											0, 
											1.0f, 
											3500, 
											0.0f, 
											false);
		}
	}
	
	const f32 angle = this.getAngleDegrees();
	Vec2f aimvector = Vec2f(1,0).RotateBy(angle);
	
	if(this.getTickSinceCreated() == ROCKET_DELAY)
	{
		directionalSoundPlay("RPGRocket_engine_start.ogg", pos, 2.0f);
	}
	else if (this.getTickSinceCreated() > ROCKET_DELAY && this.getTickSinceCreated() < ROCKET_FUEL + ROCKET_DELAY && this.get_u16("pierced count") == 0)
	{
		//rocket code!
		this.AddForce(aimvector*ROCKET_FORCE);
		
		if (isClient())
		{
			f32 fireRandomOffsetX = (_effectspreadrandom.NextFloat() - 0.5) * 3.0f;
			
			const u32 gametime = getGameTime();
			u32 lastSmokeTime = this.get_u32("last smoke puff");
			const int ticksTillSmoke = v_fastrender ? 5 : 2;
			const int diff = gametime - (lastSmokeTime + ticksTillSmoke);
			if (diff > 0)
			{
				CParticle@ p = ParticleAnimated(CFileMatcher("RocketFire2.png").getFirst(), 
												this.getPosition() - aimvector*4 + Vec2f(fireRandomOffsetX, 0).RotateBy(angle), 
												this.getVelocity() + Vec2f(2.5f, 0).RotateBy(angle), 
												float(XORRandom(360)), 
												1.0f, 
												3, 
												0.0f, 
												false);
				if (p !is null) p.damping = 0.9f;
			
				lastSmokeTime = gametime;
				this.set_u32("last smoke puff", lastSmokeTime);
			}
		}
	}
	
	if (pos.y < 0.0f)
	{
		this.server_Die();
		if (isClient())
		{
			sparks(pos, v_fastrender ? 5 : 15, 5.0f, 20);
		}
	}
}

void onCollision(CBlob@ this, CBlob@ b, bool solid, Vec2f normal, Vec2f point1)
{
	if (b is null) //solid tile collision
	{
		if (isClient())
			sparks(point1, v_fastrender ? 5 : 15, 5.0f, 20);
		
		this.server_Die();
		return;
	}
	
	if (!isServer() || this.getTickSinceCreated() <= 4) return;
	
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
	
	if ((b.hasTag("plank") && !CollidesWithPlank(b, this.getVelocity())) || b.hasTag("non-solid") || !b.getShape().getConsts().collidable)
		return;
	
	u16 piercedCount = this.get_u16("pierced count");

	bool killed = false;
	const int color = b.getShape().getVars().customData;
	const bool sameTeam = b.getTeamNum() == this.getTeamNum();
	const bool isBlock = b.hasTag("block");
	
	u8 max_pierced;
	
	if(this.get_u16("pierced count") == 0)
	{
		max_pierced = Maths::Floor(this.getVelocity().Length() / 1.2f); //Penetration force depends on speed
		this.set_u8("max_pierceed", max_pierced); //After collision max pierced becomes locked
		this.getShape().setDrag(0.0); //rocket wont slow down after collision and actually will penetrate given number of blocks
		this.server_SetTimeToDie(0.3f); //rocket will explode soon after collision
	}
	else max_pierced = this.get_u8("max_pierceed");
	
	if (color > 0 || !isBlock)
	{
		if (isBlock)
		{
			if (b.hasTag("solid") || (b.hasTag("door") && b.getShape().getConsts().collidable) || 
				(!sameTeam && (b.hasTag("core") || b.hasTag("weapon") || b.hasTag("bomb")))) //hit these and die
			{
				if (piercedCount >= max_pierced)
					killed = true;
				piercedCount++;
			}
			else if (b.hasTag("hasSeat"))
			{
				AttachmentPoint@ seat = b.getAttachmentPoint(0);
				CBlob@ occupier = seat.getOccupied();
				if (occupier !is null && occupier.getName() == "human" && occupier.getTeamNum() != this.getTeamNum())
				{
					if (piercedCount >= max_pierced)
						killed = true;
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
		
		this.server_Hit(b, point1, Vec2f_zero, getDamage(b), Hitters::ballista, true);
		
		if (killed) 
		{
			this.server_Die();			
			return;
		}
	}
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	CPlayer@ owner = this.getDamageOwnerPlayer();
	if (owner !is null)
	{
		rewardBooty(owner, hitBlob, booty_reward);
	}
		
	if (!isClient()) return;
	
	if (customData == 9) return;

	if (hitBlob.hasTag("solid") || hitBlob.hasTag("core") || 
			 hitBlob.hasTag("seat") || hitBlob.hasTag("door") || hitBlob.hasTag("weapon"))
	{
		sparks(worldPoint, v_fastrender ? 5 : 15, 5.0f, 20);
			
		if (hitBlob.hasTag("core"))
			directionalSoundPlay("Entities/Characters/Knight/ShieldHit.ogg", worldPoint);
		else
			directionalSoundPlay("Blast1.ogg", worldPoint);
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	const f32 spinFactor = this.getInitialHealth() - this.getHealth();
	this.setAngularVelocity((float(XORRandom(30) - 15))*spinFactor);

	return damage;
}

void onDie(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	
	if (isClient())
	{
		smoke(pos, v_fastrender ? 1 : 3);	
		blast(pos, v_fastrender ? 1 : 3);															
		directionalSoundPlay("Blast2.ogg", pos);
	}
	
	//splash damage
	CBlob@[] blobsInRadius;
	if (getMap().getBlobsInRadius(pos, SPLASH_RADIUS, @blobsInRadius))
	{
		const u8 blobsLength = blobsInRadius.length;
		for (u8 i = 0; i < blobsLength; i++)
		{
			CBlob@ b = blobsInRadius[i];
			if (!b.hasTag("hasSeat") && !b.hasTag("mothership") && b.hasTag("block") && b.getShape().getVars().customData > 0)
			{
				this.server_Hit(b, pos, Vec2f_zero, getDamageExpl(b), Hitters::explosion, false);
			}
		}
	}
}

const f32 getDamage(CBlob@ hitBlob)
{
	if (hitBlob.hasTag("strong")) return 0.5f;
	
	if (hitBlob.hasTag("ramengine"))
		return 1.6f;
	if (hitBlob.hasTag("propeller"))
		return 1.0f;
	if (hitBlob.hasTag("engineblock") || hitBlob.hasTag("vulnerable") || hitBlob.hasTag("bomb"))
		return 2.0f;
	if (hitBlob.hasTag("plank"))
		return 0.8f;
	if (hitBlob.hasTag("seat"))
		return 4.0f;
	if (hitBlob.hasTag("weapon"))
		return 0.8f;
	if (hitBlob.getName() == "shark" || hitBlob.getName() == "human")
		return 3.0f;
	if (hitBlob.hasTag("mothership"))
		return 0.4f;

	return 0.5f;
}

const f32 getDamageExpl(CBlob@ hitBlob)
{
	if (hitBlob.hasTag("strong")) return 3.4f;
	
	if (hitBlob.hasTag("rocket"))
		return 4.0f;
	if (hitBlob.hasTag("ramengine"))
		return 8.0f;
	if (hitBlob.hasTag("propeller") || hitBlob.hasTag("engineblock") || hitBlob.hasTag("vulnerable"))
		return 7.0f;
	if (hitBlob.hasTag("seat") || hitBlob.hasTag("weapon"))
		return 3.5f;
	if (hitBlob.hasTag("decoyCore") || hitBlob.hasTag("plank"))
		return 1.5f;
	if (hitBlob.hasTag("core"))
		return 1.5f;
	if (hitBlob.hasTag("player"))
		return 6.0f;
	if (hitBlob.hasTag("bomb"))
		return 8.0f;

	return 3.4f; //solids
}

Random _smoke_r(0x10001);
void smoke(const Vec2f pos, const u8 amount)
{
	for (u8 i = 0; i < amount; i++)
    {
        Vec2f vel(2.0f + _smoke_r.NextFloat() * 2.0f, 0);
        vel.RotateBy(_smoke_r.NextFloat() * 360.0f);

        CParticle@ p = ParticleAnimated(CFileMatcher("GenericSmoke3.png").getFirst(), 
									pos, 
									vel, 
									float(XORRandom(360)), 
									1.0f, 
									4 + XORRandom(8), 
									0.0f, 
									false);
									
        if (p is null) return; //bail if we stop getting particles
		
        p.scale = 0.5f + _smoke_r.NextFloat()*0.5f;
        p.damping = 0.8f;
		p.Z = 650.0f;
    }
}

Random _blast_r(0x10002);
void blast(const Vec2f pos, const u8 amount)
{
	for (u8 i = 0; i < amount; i++)
    {
        Vec2f vel(_blast_r.NextFloat() * 2.5f, 0);
        vel.RotateBy(_blast_r.NextFloat() * 360.0f);

        CParticle@ p = ParticleAnimated(CFileMatcher("GenericBlast6.png").getFirst(), 
									pos, 
									vel, 
									float(XORRandom(360)), 
									1.0f, 
									2 + XORRandom(4), 
									0.0f, 
									false);
									
        if (p is null) return; //bail if we stop getting particles
		
        p.scale = 0.5f + _blast_r.NextFloat()*0.5f;
        p.damping = 0.85f;
		p.Z = 650.0f;
    }
}