#include "WaterEffects.as";
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "TileCommon.as";
#include "ParticleSpark.as";
#include "Hitters.as";

BootyRewards@ booty_reward;

void onInit(CBlob@ this)
{
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 5);
		_booty_reward.addTagReward("engine", 5);
		_booty_reward.addTagReward("mothership", 10);
		_booty_reward.addTagReward("secondarycore", 8);
		_booty_reward.addTagReward("weapon", 8);
		@booty_reward = _booty_reward;
	}

	this.Tag("projectile");
	this.Tag("bullet");

	ShapeConsts@ consts = this.getShape().getConsts();
	consts.mapCollisions = true;
	consts.bullet = true;
	
	this.SetMapEdgeFlags(CBlob::map_collide_none);

	this.getSprite().SetZ(550.0f);	
}

const f32 getDamage(CBlob@ hitBlob)
{
	if (hitBlob.getName() == "shark" || hitBlob.getName() == "human" || hitBlob.hasTag("weapon"))
		return 0.4f;
	if (hitBlob.hasTag("bomb"))
		return 1.35f;
	if (hitBlob.hasTag("propeller"))
		return 0.75f;
	if (hitBlob.hasTag("ramengine"))
		return 1.5f;
	if (hitBlob.hasTag("door"))
		return 0.7f;
	if (hitBlob.hasTag("seat") || hitBlob.hasTag("decoyCore") || hitBlob.hasTag("plank"))
		return 0.4f;
		
	return 0.25f; //cores | solids
}

void onCollision(CBlob@ this, CBlob@ b, bool solid, Vec2f normal, Vec2f point1)
{
	if (b is null) //solid tile collision
	{
		if (isClient())
		{
			this.Tag("noDeathParticles");
			sparks(point1, 8);
			directionalSoundPlay("Ricochet" +  (XORRandom(3) + 1) + ".ogg", point1, 0.50f);
		}
		this.server_Die();
		return;
	}
	
	if (!isServer()) return;
	
	bool killed = false;
	const int color = b.getShape().getVars().customData;
	const bool sameTeam = b.getTeamNum() == this.getTeamNum();
	const bool isBlock = b.hasTag("block");

	if (color > 0 || !isBlock)
	{
		if (isBlock)
		{
			if ((b.hasTag("solid") && solid) || (b.hasTag("door") && b.getShape().getConsts().collidable) || 
				(!sameTeam && (b.hasTag("core") || b.hasTag("weapon") || b.hasTag("bomb")))) //hit these and die
			{
				killed = true;
			}
			else if (b.hasTag("hasSeat"))
			{
				AttachmentPoint@ seat = b.getAttachmentPoint(0);
				CBlob@ occupier = seat.getOccupied();
				if (occupier !is null && occupier.getName() == "human" && occupier.getTeamNum() != this.getTeamNum())
				{
					killed = true;
					if (XORRandom(3) == 0)//1/3 chance to hit the driver
						@b = occupier;
				}
				else return;
			}
			else return;
		}
		else
		{
			if (!sameTeam && !b.isAttached())
			{
				if (b.getName() == "shark" || b.hasTag("player"))
					killed = true;
			}
			else return;
		}

		this.server_Hit(b, point1, Vec2f_zero, getDamage(b), Hitters::bomb_arrow, true);
		
		if (killed)
			this.server_Die();
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
	
	if (hitBlob.hasTag("block"))
	{
		sparks(worldPoint, v_fastrender ? 3 : 8);
		directionalSoundPlay("Ricochet" + (XORRandom(3) + 1) + ".ogg", worldPoint, 0.50f);
	}
}

void onDie(CBlob@ this)
{
	if (!isClient() || this.hasTag("noDeathParticles")) return;
	
	Vec2f pos = this.getPosition();
	if (!isInWater(pos))
	{
		AngledDirtParticle(pos, -this.getVelocity().Angle() - 90.0f);
		directionalSoundPlay("Ricochet" + (XORRandom(3) + 1) + ".ogg", pos, 0.50f);
	}
	else if (this.getTouchingCount() <= 0)
	{
		MakeWaterParticle(pos, Vec2f_zero);
	}
}
