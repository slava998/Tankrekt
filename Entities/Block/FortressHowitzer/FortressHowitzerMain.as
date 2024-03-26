#include "WeaponCommon.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";

const f32 PROJECTILE_SPEED = 10.0f;
const f32 FIRE_RATE = 400;
const f32 PROJECTILE_RANGE = 500.0f;
const f32 TURN_SPEED = 1;
const f32 MAX_ANGLE = 60.0f;

const u8 MAX_AMMO = 6;
const u8 REFILL_AMOUNT = 1;
const u8 REFILL_SECONDS = 23;
const u8 REFILL_SECONDARY_CORE_SECONDS = 30;
const u8 REFILL_SECONDARY_CORE_AMOUNT = 1;

void onInit(CBlob@ this)
{
	this.Tag("usesAmmo");
	
	this.Tag("noEnemyEntry");
	this.set_string("seat label", "Operate Howitzer");
	this.set_u8("seat icon", 7);
	
	this.addCommandID("fire");

	if (isServer())
	{
		this.set_u16("ammo", MAX_AMMO);
		this.set_u16("maxAmmo", MAX_AMMO);
		this.Sync("ammo", true);
		this.Sync("maxAmmo", true);
	}

	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ layer = sprite.addSpriteLayer("weapon", "FortressHowitzer_Base.png", 28, 18);
    if (layer !is null)
    {
    	layer.SetRelativeZ(3);
		layer.SetOffset(Vec2f(4, -3));
    	layer.SetLighting(false);
		layer.RotateBy(-90, Vec2f_zero);
    }
	CSpriteLayer@ layer2 = sprite.addSpriteLayer("movable", "FortressHowitzer_Breech.png", 7, 6);
    if (layer2 !is null)
    {
    	layer2.SetRelativeZ(4);
    	layer2.SetLighting(false);
		layer2.SetOffset(Vec2f(4.5, -4));
		layer2.RotateBy(-90, -Vec2f(4.5, -4));
    }
	CSpriteLayer@ layer3 = sprite.addSpriteLayer("barrel", "FortressHowitzer_Barrel.png", 12, 4);
    if (layer2 !is null)
    {
    	layer3.SetRelativeZ(2);
    	layer3.SetLighting(false);
		layer3.SetOffset(Vec2f(-26, 0));
		layer3.RotateBy(-90, -Vec2f(-26, -4));
    }

	sprite.SetEmitSound("Howitzer_rotation.ogg");
	sprite.SetEmitSoundPaused(true);
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return; //not placed yet

	const u32 gameTime = getGameTime();
	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	if (occupier !is null) Manual(this, occupier);
	
	if (isServer())
	{
		Ship@ ship = getShipSet().getShip(col);
		if (ship !is null)
			refillAmmo(this, ship, REFILL_AMOUNT, REFILL_SECONDS, REFILL_SECONDARY_CORE_AMOUNT, REFILL_SECONDARY_CORE_SECONDS);
	}
	
	//Move movable parts
	f32 angle = -this.get_f32("rot_angle") - 90;
	
	Vec2f seat_offset = Vec2f(-8, -5.5).RotateBy(angle) - Vec2f(4, 4);
	this.getAttachments().getAttachmentPointByName("SEAT").offset = seat_offset;
	
	if (isClient())
	{
		CSprite@ sprite = this.getSprite();
		CSpriteLayer@ base = this.getSprite().getSpriteLayer("weapon");
		CSpriteLayer@ breech = this.getSprite().getSpriteLayer("movable");
		CSpriteLayer@ barrel = this.getSprite().getSpriteLayer("barrel");

		const f32 difference = gameTime - this.get_u32("fire time");
		const f32 time_left = FIRE_RATE - difference;
		Vec2f breech_offset;
		if(time_left > 0)
		{
			if(time_left <= 75)
				breech_offset = Vec2f(7, 0) + Vec2f(7.5, 0) * Maths::Min(time_left /75, 1);
			else
				breech_offset = Vec2f(14.5, 0);
		}
		else breech_offset = Vec2f(7.0, 0);

		Vec2f barrel_offset;
		if(difference <= 6)
		{
			const f32 cos = Maths::Cos(0.261 * difference); // 0.314 is pi/10
			barrel_offset = Vec2f(-19, 0) + Vec2f(6.3, 0) * cos * cos; //cos * cos is cos squared
		}
		else barrel_offset = Vec2f(-19, 0);
		if (breech !is null)
		{
			breech.ResetTransform();
			breech.SetOffset(breech_offset + Vec2f(4, -3));
			breech.RotateBy(angle, -breech_offset);
		}
		
		if (base !is null)
		{
			base.ResetTransform();
			base.SetOffset(Vec2f(4, -3));
			base.RotateBy(angle, Vec2f(0,0));
		}

		if (barrel !is null)
		{
			barrel.ResetTransform();
			barrel.SetOffset(barrel_offset + Vec2f(4, -3));
			barrel.RotateBy(angle, -barrel_offset);
		}
		if(time_left == 75) directionalSoundPlay("Howitzer_reload", this.getPosition(), 2.0f);
	}
}

void Manual(CBlob@ this, CBlob@ controller)
{	
	Vec2f pos = this.getPosition();
	Vec2f aimpos = controller.getAimPos();
	Vec2f aimVec = aimpos - pos;

	// fire
	if (controller.isMyPlayer() && controller.isKeyPressed(key_action1) && canShootManual(this) && isClear(this))
	{
		Fire(this, aimVec, controller.getNetworkID());
	}

	// rotate turret
	Rotate(this, aimVec);
	CSprite@ sprite = controller.getSprite();
	sprite.ResetTransform();
	sprite.RotateBy(this.getAngleDegrees() - this.get_f32("rot_angle") - 90 - controller.getAngleDegrees(), Vec2f_zero); //Rotate player sprite without rotating blob because otherwise rotation would be continious
}

bool canShootManual(CBlob@ this)
{
	return this.get_u32("fire time") + FIRE_RATE < getGameTime();
}

void Fire(CBlob@ this, Vec2f&in aimVector, const u16&in netid)
{
	const f32 aimdist = Maths::Min(aimVector.Normalize(), PROJECTILE_RANGE);

	const Vec2f _vel = (aimVector * PROJECTILE_SPEED);
	const f32 _lifetime = Maths::Max(0.05f + aimdist/PROJECTILE_SPEED/32.0f, 0.25f);

	CBitStream params;
	params.write_netid(netid);
	params.write_f32(_lifetime);
	this.SendCommand(this.getCommandID("fire"), params);
}

void Rotate(CBlob@ this, Vec2f&in aimVector)
{
	f32 degrees = loopAngle(aimVector.getAngleDegrees() + this.getAngleDegrees() - 90);
	f32 curr_angle = this.get_f32("rot_angle");
	f32 diff = curr_angle - degrees;
	if(diff < 180 && diff > -180) diff = curr_angle - degrees;
	else diff = degrees - curr_angle;
	f32 new_angle = curr_angle - Maths::Clamp(diff, -TURN_SPEED, TURN_SPEED);

	new_angle = loopAngle(Maths::Clamp(loopAngle(new_angle - 180), 180 - MAX_ANGLE, 180 + MAX_ANGLE) + 180); //Keep angle withing given bounds
	if(new_angle == curr_angle)
	{
		this.getSprite().SetEmitSoundPaused(true);
		return;
	}
	if(Maths::Abs(diff) < 1) this.getSprite().SetEmitSoundPaused(true);
	else this.getSprite().SetEmitSoundPaused(false);

	this.set_f32("rot_angle", new_angle);
}

const bool isClear(CBlob@ this)
{
	Vec2f aimVector = Vec2f(1, 0).RotateBy(this.getAngleDegrees() - this.get_f32("rot_angle") - 90);
	const f32 angle = -aimVector.Angle();

	HitInfo@[] hitInfos;
	if (getMap().getHitInfosFromRay(this.getPosition() + Vec2f(-4, -3) + Vec2f(25,0).RotateBy(angle), angle, 60.0f, this, @hitInfos))
	{
		const u8 hitLength = hitInfos.length;
		for (u8 i = 0; i < hitLength; i++)
		{
			CBlob@ b =  hitInfos[i].blob;
			if (b is null || b is this) continue;

			if (this.getShape().getVars().customData == b.getShape().getVars().customData && !b.hasTag("non-solid") && b.getShape().getConsts().collidable && (b.hasTag("weapon") || (b.hasTag("solid") && !b.hasTag("plank")))) //same ship
			{
				return false;
			}
		}
	}

	return true;
}

// Keeps an angle within the engine's boundaries (-740 to 740)
const f32 loopAngle(f32 angle)
{
	while (angle < 0.0f)	angle += 360.0f;
	while (angle > 360.0f)	angle -= 360.0f;
	return angle;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
    if (cmd == this.getCommandID("fire"))
    {
		if(!canShootManual(this)) return;
		this.set_u32("fire time", getGameTime());

		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		Vec2f pos = this.getPosition();

		//ammo
		u16 ammo = this.get_u16("ammo");

		if (ammo == 0)
		{
			directionalSoundPlay("LoadingTick1", pos, 1.0f);
			return;
		}

		ammo--;
		this.set_u16("ammo", ammo);
		
		f32 angle = -this.get_f32("rot_angle") + this.getAngleDegrees() - 90;

		const Vec2f velocity = Vec2f((PROJECTILE_SPEED), 0).RotateBy(angle, Vec2f());
		
		Vec2f bullet_offset = pos + Vec2f(4, -3) + Vec2f(25, 0).RotateBy(angle, Vec2f(-4, 3));

		if (isServer())
		{
            CBlob@ bullet = server_CreateBlob("howitzershell", this.getTeamNum(), bullet_offset);
            if (bullet !is null)
            {
            	if (caller !is null)
				{
					if (caller.getPlayer() !is null)
						bullet.SetDamageOwnerPlayer(caller.getPlayer());
				}

                bullet.setVelocity(velocity);
                bullet.server_SetTimeToDie(params.read_f32());
				bullet.setAngleDegrees(angle);
            }
    	}

		if (isClient())
		{
			shotParticles(bullet_offset, -angle);
			
			CParticle@ p = ParticleAnimated(CFileMatcher("GenericSmoke4.png").getFirst(), 
							bullet_offset, 
							Vec2f(0.5,0).RotateBy(angle), 
							0, 
							1.0f, 
							10 + XORRandom(8), 
							0.0f, 
							false);
			if (p !is null)
			p.Z = 640.0f;
			
			directionalSoundPlay("Howitzer_Shoot.ogg", bullet_offset, 5.5f);
		}
    }
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	if(detached is null) return;
	detached.getSprite().ResetTransform();
	this.getSprite().SetEmitSoundPaused(true);
}