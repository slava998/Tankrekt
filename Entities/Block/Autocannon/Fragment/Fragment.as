#include "ExplosionEffects.as";;
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "Hitters.as";
#include "PlankCommon.as";

BootyRewards@ booty_reward;
Random _r(1569815698); //clientside

void onInit(CBlob@ this)
{
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 4);
		_booty_reward.addTagReward("engine", 2);
		_booty_reward.addTagReward("mothership", 8);
		_booty_reward.addTagReward("secondarycore", 6);
		_booty_reward.addTagReward("weapon", 5);
		@booty_reward = _booty_reward;
	}
	
	this.Tag("projectile");

	ShapeConsts@ consts = this.getShape().getConsts();
	consts.mapCollisions = true;
	consts.bullet = true;
	
	CSprite@ sprite = this.getSprite();
	sprite.SetZ(550.0f);
	sprite.ScaleBy(Vec2f(0.8,0.8));
	
}

void onCollision(CBlob@ this, CBlob@ b, bool solid, Vec2f normal, Vec2f point1)
{
	
	if (!isServer()) return;
	
	if ((b.hasTag("plank") && !CollidesWithPlank(b, this.getVelocity())) || b.hasTag("non-solid") || !b.getShape().getConsts().collidable)
		return;
	
	//blow up inside the target (big damage)
	const bool sameTeam = this.getTeamNum() == b.getTeamNum();

	if (!sameTeam)
	{
		this.server_Hit(b, point1, Vec2f_zero, getDamage(b) * 7, Hitters::bomb, true);
	}
}
			




void onDie(CBlob@ this)
{

}

const f32 getDamage(CBlob@ hitBlob)
{
	if (hitBlob.hasTag("strong")) return 0.01f;

	if (hitBlob.hasTag("rocket"))
		return 0.55f; 
	if (hitBlob.hasTag("propeller") || hitBlob.hasTag("plank") || hitBlob.hasTag("engineblock") || 	hitBlob.hasTag("factory"))
		return 0.3f;
	if (hitBlob.hasTag("ramengine"))
		return 0.2f;
	if (hitBlob.hasTag("door"))
		return 0.13f;
	if (hitBlob.getName() == "shark" || hitBlob.getName() == "human")
		return 0.5f;
	if (hitBlob.hasTag("seat") || hitBlob.hasTag("weapon") || hitBlob.hasTag("bomb") || hitBlob.hasTag("core"))
		return 0.3f;
	return 0.01f;
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

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return !blob.hasTag("non-solid") && blob.getShape().getConsts().collidable;
}