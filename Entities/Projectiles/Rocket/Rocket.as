#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "Hitters.as";
#include "PlankCommon.as";

const f32 SPLASH_RADIUS = 8.0f;
const f32 SPLASH_DAMAGE = 0.5f;
//const f32 MANUAL_DAMAGE_MODIFIER = 0.75f;

const f32 ROCKET_FORCE = 7.5f;
const int ROCKET_DELAY = 15;
const f32 ROTATION_SPEED = 3.0;
const f32 GUIDANCE_RANGE = 225.0f;

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

	if (isClient())
	{
		CSprite@ sprite = this.getSprite();
		sprite.SetZ(550.0f);	
		sprite.SetEmitSound("/RocketBooster.ogg");
		sprite.SetEmitSoundVolume(0.5f);
		sprite.SetEmitSoundPaused(true);
	}
	
	this.set_u32("last smoke puff", 0);
}

void onTick(CBlob@ this)
{	
	Vec2f pos = this.getPosition();
	const f32 angle = this.getAngleDegrees();
	Vec2f aimvector = Vec2f(1,0).RotateBy(angle - 90.0f);
	
	if (this.getTickSinceCreated() > ROCKET_DELAY)
	{
		//rocket code!
		this.AddForce(aimvector*ROCKET_FORCE);
		
		if (isClient())
		{
			CSprite@ sprite = this.getSprite();
			if (sprite.getEmitSoundPaused())
			{
				sprite.SetEmitSoundPaused(false);
			}
			
			f32 fireRandomOffsetX = (_effectspreadrandom.NextFloat() - 0.5) * 3.0f;
			
			const u32 gametime = getGameTime();
			u32 lastSmokeTime = this.get_u32("last smoke puff");
			const int ticksTillSmoke = v_fastrender ? 5 : 2;
			const int diff = gametime - (lastSmokeTime + ticksTillSmoke);
			if (diff > 0)
			{
				CParticle@ p = ParticleAnimated(CFileMatcher("RocketFire2.png").getFirst(), 
												this.getPosition() - aimvector*4 + Vec2f(fireRandomOffsetX, 0).RotateBy(angle), 
												this.getVelocity() + Vec2f(0.0f, 2.5f).RotateBy(angle), 
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
	
	//mouse guidance
	CPlayer@ owner = this.getDamageOwnerPlayer();
	if (owner !is null)
	{
		CBlob@ ownerBlob = owner.getBlob();
		if (ownerBlob !is null && ownerBlob.isAttached() && ownerBlob.isKeyPressed(key_action1))
		{	
			Vec2f aimPos = ownerBlob.getAimPos();
			Vec2f ownerPos = ownerBlob.getPosition();
			
			const f32 targetDistance = (aimPos - ownerPos).getLength();
			//f32 rocketDistance = (pos - ownerPos).getLength();
			
			if (targetDistance > GUIDANCE_RANGE) //must be done to preven desync issues
			{	
				aimPos = ownerPos + Vec2f(GUIDANCE_RANGE, 0).RotateBy(-(aimPos - ownerPos).getAngleDegrees());
			}
		
			const f32 angleOffset = 270.0f;		
			const f32 targetAngle = (aimPos - pos).getAngle();
			const f32 thisAngle = this.getAngleDegrees();
			f32 shortAngle = (thisAngle + targetAngle + angleOffset) % 360;				
			
			/*this.set_f32("shortAngle", shortAngle);
			if (ownerBlob.isMyPlayer()) 
			{
				this.Sync("shortAngle", false); //324847272 HASH
			}
			else
			{
				shortAngle = this.get_f32("shortAngle");
			}*/
			
			if (shortAngle < 0 - ROTATION_SPEED*2.0f)
			{
				if (shortAngle < 180)
					this.setAngleDegrees(thisAngle + ROTATION_SPEED);
				if (shortAngle > 180)
					this.setAngleDegrees(thisAngle - ROTATION_SPEED);
			}
			if (shortAngle > 0 + ROTATION_SPEED*2.0f)
			{
				this.setAngleDegrees(thisAngle + (ROTATION_SPEED * (shortAngle < 180 ? -1 : 1)));
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
	
	if (b.hasTag("plank") && !CollidesWithPlank(b, this.getVelocity()))
		return;

	bool killed = false;
	
	const int color = b.getShape().getVars().customData;
	const bool isBlock = b.hasTag("block");
	const bool sameTeam = b.getTeamNum() == this.getTeamNum();
	
	if ((b.hasTag("human") || b.hasTag("shark")) && !sameTeam)
	{
		killed = true;
		b.server_Die();
	}
	
	if (color > 0 || !isBlock)
	{
		if (isBlock || b.hasTag("rocket"))
		{
			if (b.hasTag("solid") || b.hasTag("door") ||
				(!sameTeam && (b.hasTag("weapon") || b.hasTag("rocket") || b.hasTag("bomb") || b.hasTag("core"))))
				killed = true;
			else if (b.hasTag("hasSeat") && !sameTeam)
			{
				AttachmentPoint@ seat = b.getAttachmentPoint(0);
				CBlob@ occupier = seat.getOccupied();
				if (occupier !is null && occupier.getName() == "human" && occupier.getTeamNum() != this.getTeamNum())
					killed = true;
			}
			else return;
		}
		else
		{
			if (sameTeam || (b.hasTag("player") && b.isAttached()) || b.hasTag("projectile")) //don't hit
				return;
		}
		
		//f32 damageModifier = this.getDamageOwnerPlayer() !is null ? MANUAL_DAMAGE_MODIFIER : 1.0f;
		this.server_Hit(b, point1, Vec2f_zero, getDamage(b) * (this.hasTag("killedRocket") ? 0.5f : 1), this.hasTag("killedRocket") ? Hitters::explosion : Hitters::bomb, true);
		
		if (killed)
		{
			this.Tag("killedRocket"); //for instances of multiple collisions on same tick
			this.server_Die();
		}
	}
}

f32 getDamage(CBlob@ hitBlob)
{
	if (hitBlob.hasTag("rocket"))
		return 4.0f;
	if (hitBlob.hasTag("ramengine"))
		return 5.0f;
	if (hitBlob.hasTag("propeller") || hitBlob.hasTag("plank"))
		return 3.0f;
	if (hitBlob.hasTag("seat") || hitBlob.hasTag("weapon"))
		return 2.5f;
	if (hitBlob.hasTag("decoyCore"))
		return 1.5f;
	if (hitBlob.hasTag("core"))
		return 0.65f;

	return 1.4f; //solids
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	CPlayer@ owner = this.getDamageOwnerPlayer();
	if (owner !is null && customData != Hitters::explosion) //no splash damage included
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

	if (isServer())
	{
		//splash damage
		CBlob@[] blobsInRadius;
		if (getMap().getBlobsInRadius(pos, SPLASH_RADIUS, @blobsInRadius))
		{
			const u8 blobsLength = blobsInRadius.length;
			for (u8 i = 0; i < blobsLength; i++)
			{
				CBlob@ b = blobsInRadius[i];
				if (!b.hasTag("hasSeat") && !b.hasTag("mothership") && b.hasTag("block") && b.getShape().getVars().customData > 0)
					this.server_Hit(b, Vec2f_zero, Vec2f_zero, getDamage(b) * SPLASH_DAMAGE, Hitters::explosion, false);
			}
		}
	}
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
