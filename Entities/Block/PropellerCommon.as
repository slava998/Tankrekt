#include "ShipsCommon.as";
#include "WaterEffects.as";
#include "PropellerForceCommon.as";
#include "AccurateSoundPlay.as";

Random _r(133701); //global clientside random object

void onInit(CBlob@ this)
{
	this.addCommandID("on/off");
	this.addCommandID("off");
	this.addCommandID("stall");
	this.Tag("engine");
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("on/off") && isServer())
	{
		this.set_f32("power", this.get_f32("power") != 0 ? 0.0f : -this.get_f32("powerFactor"));
	}
	else if (cmd == this.getCommandID("off") && isServer())
	{
		this.set_f32("power", 0.0f);
	}
	else if (cmd == this.getCommandID("stall") && isClient())
	{
		directionalSoundPlay("propellerStall.ogg", this.getPosition(), 2.5f);
		this.set_u8("stallTime", params.read_u8());
	}
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return;
	
	const u32 gameTime = getGameTime();
	CSprite@ sprite = this.getSprite();
	const f32 power = this.get_f32("power");
	Vec2f pos = this.getPosition();
	const u8 stallTime = this.get_u8("stallTime");
	const bool stalled = stallTime > 0;
	const bool on = power != 0 && !stalled;	
	
	if (isClient())
	{
		CSpriteLayer@ propeller = sprite.getSpriteLayer("propeller");
		if (propeller !is null)
			propeller.animation.time = on ? 1 : 0;
	}

	if (isServer())
		this.Sync("power", true); //-179363002 HASH

	if (stalled)
	{
		this.set_u8("stallTime", stallTime - 1);
		if (isClient()) //stall smoke effect
		{
			if (gameTime % (v_fastrender ? 5 : 2) == 0)
				smoke(pos);
		}
	}
	
	if (on)
	{
		//auto turn off after a while
		if (isServer() && gameTime - this.get_u32("onTime") > 750)
		{
			this.SendCommand(this.getCommandID("off"));
			return;
		}
		
		Ship@ ship = getShipSet().getShip(col);
		if (ship !is null)
		{
			// move
			Vec2f moveVel;
			Vec2f moveNorm;
			float angleVel;
			
			PropellerForces(this, ship, power, moveVel, moveNorm, angleVel);
			
			const f32 mass = ship.mass + ship.carryMass + 0.01f;
			moveVel /= mass;
			angleVel /= mass;
			
			ship.vel += moveVel;
			ship.angle_vel += angleVel;
			
			if (isServer() && (gameTime + this.getNetworkID()) % 15 == 0)
			{
				//low health stall failure
				const f32 healthPct = this.getHealth()/this.getInitialHealth();
				if (healthPct < 0.25f && !stalled && XORRandom(25) == 0)
				{
					const u8 stallTime = 30 + XORRandom(50);
					this.set_u8("stallTime", stallTime);
					CBitStream params;
					params.write_u8(stallTime);
					this.SendCommand(this.getCommandID("stall"), params);
				}
				
				//eat stuff
				Vec2f faceNorm(0,-1);
				faceNorm.RotateBy(this.getAngleDegrees());
				CBlob@ victim = getMap().getBlobAtPosition(pos - faceNorm * 8);
				if (victim !is null && victim.getShape().getVars().customData > 0)
				{
					const f32 hitPower = Maths::Max(0.5f, Maths::Abs(this.get_f32("power")));
					if (!victim.hasTag("core"))
						this.server_Hit(victim, pos, Vec2f_zero, hitPower, 9, true);
					else
						victim.server_Hit(this, pos, Vec2f_zero, hitPower, 9, true);
				}
			}
			
			// effects
			if (isClient())
			{
				const u8 tickStep = v_fastrender ? 20 : 4;
				if ((gameTime + this.getNetworkID()) % tickStep == 0 && Maths::Abs(power) >= 1 && !isTouchingLand(pos))
				{
					const Vec2f rpos = Vec2f(_r.NextFloat() * -4 + 4, _r.NextFloat() * -4 + 4);
					MakeWaterParticle(pos + moveNorm * -6 + rpos, moveNorm * (-0.8f + _r.NextFloat() * -0.3f));
				}
				
				// limit sounds
				if (ship.soundsPlayed == 0 && sprite.getEmitSoundPaused())
				{
					sprite.SetEmitSoundPaused(false);
				}

				ship.soundsPlayed++;
				const f32 vol = Maths::Min(0.5f + float(ship.soundsPlayed)*0.5f, 3.0f);
				sprite.SetEmitSoundVolume(vol);
			}
		}
	}
	else
	{
		if (isClient() && !sprite.getEmitSoundPaused())
		{
			sprite.SetEmitSoundPaused(true);
		}
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (!isServer() || this.get_u8("stallTime") > 0)
		return damage;
	
	const f32 healthPct = this.getHealth()/this.getInitialHealth();
	if (healthPct > 0.0f && healthPct < 0.75f)
	{
		const f32 stallFactor = 1.0f/healthPct + Maths::FastSqrt(damage);
		if (stallFactor * XORRandom(9) > 15) //chance based on health and damage to stall
		{
			const u8 stallTime = stallFactor * 30;
			this.set_u8("stallTime", stallTime);
			CBitStream params;
			params.write_u8(stallTime);
			this.SendCommand(this.getCommandID("stall"), params);
		}
	}
	
	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (isClient() && customData == 9 && damage > 0.0f)
		directionalSoundPlay("propellerHit.ogg", worldPoint);
}

Random _smokerandom(0x15125); //clientside
void smoke(const Vec2f&in pos)
{
	CParticle@ p = ParticleAnimated("SmallSmoke1.png",
											  pos, Vec2f_zero,
											  _smokerandom.NextFloat() * 360.0f, //angle
											  1.0f, //scale
											  3+_smokerandom.NextRanged(2), //animtime
											  0.0f, //gravity
											  true); //selflit
	if (p !is null)
		p.Z = 640.0f;
}
