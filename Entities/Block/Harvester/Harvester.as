#include "WaterEffects.as";
#include "ShipsCommon.as";
#include "Booty.as";
#include "AccurateSoundPlay.as";
#include "TileCommon.as";
#include "ParticleSpark.as";
#include "BlockCosts.as";
#include "PlankCommon.as";
 
const f32 BULLET_RANGE = 60.0f;
const f32 DECONSTRUCT_RATE = 10.0f; //higher values = higher recover
const int CONSTRUCT_VALUE = 35;

void onInit(CBlob@ this)
{
	this.getCurrentScript().tickFrequency = 2;

	this.Tag("weapon");
	this.Tag("machinegun");
	this.Tag("fixed_gun");

	this.set_f32("weight", 2.0f);

	this.addCommandID("fire");

	if (isClient())
	{
		CSprite@ sprite = this.getSprite();
		sprite.SetRelativeZ(2);
		sprite.SetEmitSound("/ReclaimSound.ogg");
		sprite.SetEmitSoundVolume(0.5f);
		sprite.SetEmitSoundPaused(true);
	}

	this.set_u32("fire time", 0);
}
 
void onTick(CBlob@ this)
{
	if (this.getShape().getVars().customData <= 0) //not placed yet
		return;
	
	if (isClient())
	{
		//kill laser after a certain time
		if (canShoot(this))
		{
			CSprite@ sprite = this.getSprite();
			if (!sprite.getEmitSoundPaused())
			{
				sprite.SetEmitSoundPaused(true);
			}
			
			sprite.RemoveSpriteLayer("laser");
		}
	}
}
 
const bool canShoot(CBlob@ this)
{
	return (this.get_u32("fire time") + DECONSTRUCT_RATE < getGameTime());
}
 
void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
    if (cmd == this.getCommandID("fire"))
    {
		if (!canShoot(this)) return;
		
		u16 shooterID;
		if (!params.saferead_netid(shooterID)) return;
			
		CBlob@ shooter = getBlobByNetworkID(shooterID);
		if (shooter is null) return;
		
		CPlayer@ player = shooter.getPlayer();
		if (player is null) return;
		
		ShipDictionary@ ShipSet = getShipSet();

		this.set_u32("fire time", getGameTime());
			
		CSprite@ sprite = this.getSprite();
	   
		Vec2f aimVector = Vec2f(1, 0).RotateBy(this.getAngleDegrees());
		Vec2f barrelPos = this.getPosition();

		//hit stuff
		HitInfo@[] hitInfos;
		bool killed = false;
		
		if (getMap().getHitInfosFromRay(barrelPos, -aimVector.Angle(), BULLET_RANGE, this, @hitInfos))
		{
			const u8 hitLength = hitInfos.length;
			for (u8 i = 0; i < hitLength; i++)
			{
				HitInfo@ hi = hitInfos[i];
				CBlob@ b = hi.blob;	  
				if (b is null || b is this) continue;
				
				const int bCol = b.getShape().getVars().customData;
				if (bCol <= 0) continue;
				
				Ship@ bship = ShipSet.getShip(bCol);
				if (b.hasTag("station") || (b.hasTag("plank") && !CollidesWithPlank(b, aimVector) && (bship !is null && !bship.owner.isEmpty()))) 
					continue;
					
				killed = true;
				
				if (isClient())//effects
				{
					setLaser(sprite, hi.hitpos - barrelPos);
					sparks(hi.hitpos, 4);
				}

				const f32 bCost = !b.hasTag("coupling") ? getCost(b.getName()) : 1;
				const f32 initialHealth = b.getInitialHealth();
				const f32 currentReclaim = b.get_f32("current reclaim");

				if (bship !is null && bCost > 0)
				{
					const f32 fullConstructAmount = (CONSTRUCT_VALUE/bCost)*initialHealth; //fastest reclaim possible
					const string shipOwnerName = bship.owner;
					
					if (!b.hasTag("mothership"))
					{
						f32 deconstructAmount = 0;
						if ((shipOwnerName.isEmpty() && !bship.isMothership) //true if no owner for ship and ship is not a mothership
							|| (b.get_string("playerOwner").isEmpty() && !bship.isMothership) //true if no owner for the block and is not on a mothership
							|| (shipOwnerName == player.getUsername()) //true if we own the ship
							|| (b.get_string("playerOwner") == player.getUsername())) //true if we own the specific block
						{
							deconstructAmount = fullConstructAmount; 
						}
						else
						{
							deconstructAmount = (1.0f/bCost)*initialHealth; //slower reclaim
						}

						if ((currentReclaim - deconstructAmount) <= 0)
						{
							server_addPlayerBooty(player.getUsername(), (bCost*0.7f)*(b.getHealth()/initialHealth));
							directionalSoundPlay("/ChaChing.ogg", barrelPos);

							b.Tag("disabled");
							b.server_Die();
						}
						else
							b.set_f32("current reclaim", currentReclaim - deconstructAmount);
					}
				}
				break;
			}
		}
		
		if (isClient())
		{
			if (sprite.getEmitSoundPaused())
			{
				sprite.SetEmitSoundPaused(false);
			}

			if (!killed) //full length 'laser'
			{
				setLaser(sprite, aimVector * BULLET_RANGE);
			}
		}
    }
}

void setLaser(CSprite@ this, Vec2f&in lengthPos)
{
	this.RemoveSpriteLayer("laser");
	
	CSpriteLayer@ laser = this.addSpriteLayer("laser", "ReclaimBeam.png", 16, 16);
	if (laser !is null)
	{
		Animation@ anim = laser.addAnimation("default", 1, false);
		int[] frames = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
		anim.AddFrames(frames);
		laser.SetVisible(true);
		f32 laserLength = Maths::Max(0.1f, lengthPos.getLength() / 16.0f);						
		laser.ResetTransform();						
		laser.ScaleBy(Vec2f(laserLength, 1.0f));							
		laser.TranslateBy(Vec2f(laserLength * 8.0f, 0.0f));								
		laser.RotateBy(0.0f, Vec2f());
		laser.setRenderStyle(RenderStyle::light);
		laser.SetRelativeZ(1);
	}
}
