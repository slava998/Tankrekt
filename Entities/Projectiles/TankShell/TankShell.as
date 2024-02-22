#include "ExplosionEffects.as";;
#include "DamageBooty.as";
#include "AccurateSoundPlay.as";
#include "ParticleSpark.as";
#include "Hitters.as";
#include "PlankCommon.as";

const f32 EXPLODE_RADIUS = 15.0f;
const f32 BOMB_BASE_DAMAGE = 2.7f;

BootyRewards@ booty_reward;

void onInit(CBlob@ this)
{
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 8);
		_booty_reward.addTagReward("engine", 6);
		_booty_reward.addTagReward("weapon", 8);
		_booty_reward.addTagReward("core", 12);
		@booty_reward = _booty_reward;
	}
	
	this.Tag("projectile");

	ShapeConsts@ consts = this.getShape().getConsts();
	consts.mapCollisions = true;
	consts.bullet = true;

	this.getSprite().SetZ(550.0f);
	
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
	
	if (b.hasTag("plank") && !CollidesWithPlank(b, this.getVelocity()))
		return;
	
	//blow up inside the target (big damage)
	const bool sameTeam = this.getTeamNum() == b.getTeamNum();
	if ((b.hasTag("solid")) || b.hasTag("door") || 
		(!sameTeam && ((b.hasTag("core") || b.hasTag("weapon") || b.hasTag("projectile") || b.hasTag("bomb")) || (b.hasTag("player") && !b.isAttached()))))
		this.server_Die();
}

void flak(CBlob@ this)
{
	const Vec2f pos = this.getPosition();

	if (isClient())
	{
		directionalSoundPlay("Bomb.ogg", pos);
		makeLargeExplosionParticle(pos);
		ShakeScreen(4 * EXPLODE_RADIUS, 45, pos);
	}

	//hit blobs
	CBlob@[] blobs;
	if (!getMap().getBlobsInRadius(pos, EXPLODE_RADIUS, @blobs))
		return;
	
	ShipDictionary@ ShipSet = getShipSet();
	const u8 blobsLength = blobs.length;
	for (u8 i = 0; i < blobsLength; i++)
	{
		CBlob@ hit_blob = blobs[i];
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
					Vec2f impact = (hit_blob_pos - pos) * 0.15f / ship.mass;
					ship.vel += impact;
				}
			}
		
			const f32 distanceFactor = Maths::Min(1.0f, Maths::Max(0.0f, EXPLODE_RADIUS - this.getDistanceTo(hit_blob) + 8.0f) / EXPLODE_RADIUS);

			//hit the object
			this.server_Hit(hit_blob, hit_blob_pos, Vec2f_zero, BOMB_BASE_DAMAGE * distanceFactor, Hitters::bomb, true);
			//print(hit_blob.getNetworkID() + " for: " + BOMB_BASE_DAMAGE * distanceFactor + " dFctr: " + distanceFactor + ", dist: " + this.getDistanceTo(hit_blob));
		}
		
		CPlayer@ owner = this.getDamageOwnerPlayer();
		if (owner !is null && hitCol > 0)
		{
			rewardBooty(owner, hit_blob, booty_reward, "Pinball_3");
		}
	}
}

void onDie(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	
	if (isClient())
	{
		directionalSoundPlay("FlakExp"+XORRandom(2), pos, 2.0f);
		const u8 particleAmount = v_fastrender ? 1 : 3;
		for (u8 i = 0; i < particleAmount; i++)
		{
			makeSmallExplosionParticle(pos + getRandomVelocity(90, 12, 360));
		}
	}

	if (isServer() && !this.hasTag("noFlakBoom"))
		flak(this);
}

const f32 getDamage(CBlob@ hitBlob)
{
	if (hitBlob.hasTag("rocket"))
		return 3.0f; 
	if (hitBlob.hasTag("propeller") || hitBlob.hasTag("plank") || hitBlob.hasTag("bomb") || hitBlob.hasTag("engineblock"))
		return 0.5f;
	if (hitBlob.hasTag("ramengine"))
		return 0.5f;
	if (hitBlob.hasTag("door"))
		return 0.5f;
	if (hitBlob.getName() == "shark" || hitBlob.getName() == "human")
		return 3.0f; //no chances to survive
	if (hitBlob.hasTag("seat") || hitBlob.hasTag("weapon") || hitBlob.hasTag("core"))
		return 0.15f;
	if (hitBlob.hasTag("stone"))
		return 0.8f;
	return 0.5f; //solids
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
