#include "WeaponCommon.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";

const f32 PROJECTILE_RANGE = 375.0F;
const f32 PROJECTILE_SPEED = 15.0f;;
const u16 FIRE_RATE = 120;//max wait between shots

const u8 MAX_AMMO = 10;
const u8 REFILL_AMOUNT = 1;
const u8 REFILL_SECONDS = 4;
const u8 REFILL_SECONDARY_CORE_SECONDS = 12;
const u8 REFILL_SECONDARY_CORE_AMOUNT = 1;

const f32 TURN_SPEED = 2.0f;
const f32 MAX_ANGLE = 45.0f;

Random _shotrandom(0x15125); //clientside

void onInit(CBlob@ this)
{
	this.Tag("weapon");
	this.Tag("cannon");
	this.Tag("usesAmmo");
	this.Tag("fixed_gun");
	
	this.Tag("noEnemyEntry");
	this.set_string("seat label", "Operate Cannono");
	this.set_u8("seat icon", 7);
	
	this.set_f32("weight", 3.25f);
	
	this.addCommandID("fire");

	if (isServer())
	{
		this.set_u16("ammo", MAX_AMMO);
		this.set_u16("maxAmmo", MAX_AMMO);
		this.Sync("ammo", true); //1536888239 HASH
		this.Sync("maxAmmo", true); //2002479429 HASH
	}

	CSprite@ sprite = this.getSprite();
	sprite.SetRelativeZ(2);
	{
		//shoot anim
		Animation@ anim = sprite.addAnimation("fire", 0, false);
		anim.AddFrame(0);
		anim.AddFrame(1);
		sprite.SetAnimation("fire");
	}
	this.set_u32("fire time", 0);
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return; //not placed yet

	const u32 gameTime = getGameTime();

	//fire ready
	const u32 fireTime = this.get_u32("fire time");
	this.set_bool("fire ready", (gameTime > fireTime + FIRE_RATE));
	
	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	if (occupier !is null) Manual(this, occupier);
	
	f32 angle = -this.get_f32("rot_angle");
	
	Vec2f seat_offset = Vec2f(-7, 0).RotateBy(angle);
	this.getAttachments().getAttachmentPointByName("SEAT").offset = seat_offset;
	
	if (isClient())
	{
		//sprite ready
		if (fireTime + FIRE_RATE == gameTime)
		{
			this.getSprite().animation.SetFrameIndex(0);
			directionalSoundPlay("Charging.ogg", this.getPosition(), 2.0f);
		}

		CSprite@ sprite = this.getSprite();
		sprite.ResetTransform();
		sprite.RotateBy(-this.get_f32("rot_angle"), Vec2f_zero);
	}

	if (isServer())
	{
		Ship@ ship = getShipSet().getShip(col);
		if (ship !is null)
		{
			checkDocked(this, ship);
			if (this.get_bool("fire ready"))
				refillAmmo(this, ship, REFILL_AMOUNT, REFILL_SECONDS, REFILL_SECONDARY_CORE_AMOUNT, REFILL_SECONDARY_CORE_SECONDS);
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("fire"))
	{
		if (!this.get_bool("fire ready") || this.get_bool("docked")) return;

		const Vec2f pos = this.getPosition();

		this.set_u32("fire time", getGameTime());

		if (!isClear(this))
		{
			directionalSoundPlay("lightup", pos);
			return;
		}

		//ammo
		u16 ammo = this.get_u16("ammo");

		if (ammo <= 0)
		{
			directionalSoundPlay("LoadingTick1", pos, 1.0f);
			return;
		}

		ammo--;
		this.set_u16("ammo", ammo);

		u16 shooterID;
		if (!params.saferead_netid(shooterID))
			return;

		CBlob@ shooter = getBlobByNetworkID(shooterID);
		if (shooter is null)
			return;

		Fire(this, shooter);

		this.getSprite().animation.SetFrameIndex(1);
	}
}

void Manual(CBlob@ this, CBlob@ controller)
{
	Vec2f aimpos = controller.getAimPos();
	Vec2f pos = this.getPosition();
	Vec2f aimVec = aimpos - pos;

	// fire
	if (controller.isMyPlayer() && controller.isKeyPressed(key_action1) && this.get_bool("fire ready"))
	{
		CBitStream bs;
		bs.write_netid(this.getNetworkID());
		this.SendCommand(this.getCommandID("fire"), bs);
	}

	// rotate turret
	Rotate(this, aimVec);
	CSprite@ sprite = controller.getSprite();
	sprite.ResetTransform();
	sprite.RotateBy(this.getAngleDegrees() - this.get_f32("rot_angle") - controller.getAngleDegrees(), Vec2f_zero); //Rotate player sprite without rotating blob because otherwise rotation would be continious
}

void Rotate(CBlob@ this, Vec2f&in aimVector)
{
	f32 degrees = loopAngle(aimVector.getAngleDegrees() + this.getAngleDegrees());
	f32 curr_angle = this.get_f32("rot_angle");
	f32 diff = curr_angle - degrees;
	if(diff < 180 && diff > -180) diff = curr_angle - degrees;
	else diff = degrees - curr_angle;
	f32 new_angle = curr_angle - Maths::Clamp(diff, -TURN_SPEED, TURN_SPEED);

	new_angle = Maths::Clamp(loopAngle(new_angle - 180), 180 - MAX_ANGLE, 180 + MAX_ANGLE) + 180; //Keep angle withing given bounds
	
	this.set_f32("rot_angle", loopAngle(new_angle));
}

// Keeps an angle within the engine's boundaries (-740 to 740)
const f32 loopAngle(f32 angle)
{
	while (angle < 0.0f)	angle += 360.0f;
	while (angle > 360.0f)	angle -= 360.0f;
	return angle;
}

void Fire(CBlob@ this, CBlob@ shooter)
{
	Vec2f pos = this.getPosition();
	Vec2f aimVector = Vec2f(1, 0).RotateBy(this.getAngleDegrees() - this.get_f32("rot_angle"));

	if (isServer())
	{
		f32 variation = 0.9f + _shotrandom.NextFloat()/5.0f;
		f32 _lifetime = 0.05f + variation*PROJECTILE_RANGE/PROJECTILE_SPEED/32.0f;

		CBlob@ cannonball = server_CreateBlob("cannonball", this.getTeamNum(), pos + aimVector*4);
		if (cannonball !is null)
		{
			Vec2f vel = aimVector * PROJECTILE_SPEED;

			Ship@ ship = getShipSet().getShip(this.getShape().getVars().customData);
			if (ship !is null)
			{
				vel += ship.vel;

				if (shooter !is null)
				{
					CPlayer@ attacker = shooter.getPlayer();
					if (attacker !is null)
						cannonball.SetDamageOwnerPlayer(attacker);
				}

				cannonball.setVelocity(vel);
				cannonball.server_SetTimeToDie(_lifetime);
			}
		}
	}

	if (isClient())
	{
		this.getSprite().animation.SetFrameIndex(0);
		shotParticles(pos + aimVector*9, aimVector.Angle());
		directionalSoundPlay("CannonFire.ogg", pos, 7.0f);
	}
}

const bool isClear(CBlob@ this)
{
	Vec2f aimVector = Vec2f(1, 0).RotateBy(this.getAngleDegrees());

	HitInfo@[] hitInfos;
	if (getMap().getHitInfosFromRay(this.getPosition(), -aimVector.Angle(), 60.0f, this, @hitInfos))
	{
		const u8 hitLength = hitInfos.length;
		for (u8 i = 0; i < hitLength; i++)
		{
			CBlob@ b =  hitInfos[i].blob;
			if (b is null || b is this) continue;

			if (this.getShape().getVars().customData == b.getShape().getVars().customData && (b.hasTag("weapon") || (b.hasTag("solid") && !b.hasTag("plank")))) //same ship
			{
				return false;
			}
		}
	}

	return true;
}
