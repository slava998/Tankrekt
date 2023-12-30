#include "ShipsCommon.as";
#include "AccurateSoundPlay.as";
#include "ParticleHeal.as";

// onInit: called from engine after blob is created with server_CreateBlob()

void onInit(CBlob@ this)
{
	this.Tag("block");
	
	CSprite@ sprite = this.getSprite();
	sprite.SetZ(310.0f);
	sprite.asLayer().SetLighting(false);
	
	ShapeConsts@ consts = this.getShape().getConsts();
	consts.net_threshold_multiplier = -1.0f;
	consts.mapCollisions = false; //ships.as gives own tile collision
	
	this.SetMapEdgeFlags(u8(CBlob::map_collide_none | CBlob::map_collide_nodeath));
	
	this.set_f32("current reclaim", this.getInitialHealth());
}

void onTick(CBlob@ this)
{
	if (!isServer()) return; //only server
	
	if (this.getTickSinceCreated() < 1) //accounts for time after block production
	{
		//Set Owner
		CBlob@ owner = getBlobByNetworkID(this.get_netid("ownerID"));    
		if (owner !is null)
		{
			this.set_string("playerOwner", owner.getPlayer().getUsername());
			this.Sync("playerOwner", true); //2040865191 HASH
		}
	}
	
	//collide even when going super speeds (to avoid clipping)
	const int color = this.getShape().getVars().customData;
	if (color <= 0) return;
	
	CRules@ rules = getRules();
	ShipDictionary@ ShipSet = getShipSet(rules);
	Ship@ ship = ShipSet.getShip(color);
	if (ship !is null && !ship.isStation && ship.mass < 3.0f)
	{
		Vec2f velnorm = ship.vel; 
		const f32 vellen = velnorm.Normalize();		
		
		if (vellen > 8.0f) 
		{
			Vec2f pos = this.getPosition();
			HitInfo@[] hitInfos;
			if (getMap().getHitInfosFromRay(pos, -ship.vel.Angle(), ship.vel.Length()*2.0f, this, @hitInfos))
			{
				//HitInfo objects are sorted, first come closest hits
				const u8 hitLength = hitInfos.length;
				for (u8 i = 0; i < hitLength; i++)
				{
					CBlob@ blob = hitInfos[i].blob;	  
					if (blob is null || blob is this) continue;
					
					const int other_color = blob.getShape().getVars().customData;
					if (color == other_color || other_color <= 0) continue;
					
					Ship@ other_ship = ShipSet.getShip(other_color);
					if (other_ship is null) continue;

					velnorm.Normalize();

					const bool ramming = this.hasTag("ramming") || blob.hasTag("ramming") || blob.hasTag("bomb");
					if (!ship.colliding && !ramming)
					{
						ship.colliding = true; //only collide once per tick
						CollisionResponse(rules, ship, other_ship, pos + velnorm);
					}
					break;
				}
			}
		}
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return (this.getShape().getVars().customData > 0 && this.getTickSinceCreated() > 0);
}

bool doesCollideWithPlank(CBlob@ plank, const Vec2f&in blobPos)
{
	//done by position rather than velocity since blocks dont have velocity
	Vec2f direction = Vec2f(0.0f, -1.0f).RotateBy(plank.getAngleDegrees());
	const f32 hitAngle = direction.AngleWith(plank.getPosition() - blobPos);

	return !(hitAngle > -90.0f && hitAngle < 90.0f);
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (blob is null || this.hasTag("dead") || blob.hasTag("dead"))
		return;

	const int color = this.getShape().getVars().customData;
	if (color <= 0) return;
	
	const int other_color = blob.getShape().getVars().customData;

	if (isServer() && other_color > 0 && color != other_color) // block vs block
	{
		if (this.hasTag("station") || blob.hasTag("station"))
			return;
		if (blob.hasTag("plank") ? !doesCollideWithPlank(blob, this.getPosition()) : false)
			return;
		if (this.hasTag("plank") ? !doesCollideWithPlank(this, blob.getPosition()) : false)
			return;
		
		CRules@ rules = getRules();
		ShipDictionary@ ShipSet = getShipSet(rules);
		
		Ship@ ship = ShipSet.getShip(color);
		Ship@ other_ship = ShipSet.getShip(other_color);
		if (ship is null || other_ship is null) return;
		
		//TODO: isolate collision code in each blob's script rather than here
				
		const bool docking = (this.hasTag("coupling") || blob.hasTag("coupling")) && this.getTeamNum() == blob.getTeamNum()
				&& ((ship.isMothership || other_ship.isMothership) || (ship.isSecondaryCore || other_ship.isSecondaryCore) || (ship.isStation || other_ship.isStation))
				&& ((!ship.isMothership && !ship.isSecondaryCore && !ship.owner.isEmpty()) || (!other_ship.isMothership && !other_ship.isSecondaryCore && !other_ship.owner.isEmpty()));
		
		if (docking) //force ship merge
		{
			if (blob.hasTag("coupling"))
				CoupleShip(blob, rules);
			else if (this.hasTag("coupling"))
				CoupleShip(this, rules);
		}
		else
		{
			if (!ship.colliding && !this.hasTag("ramming") && !blob.hasTag("ramming"))
			{
				ship.colliding = true; //only collide once per tick
				CollisionResponse(rules, ship, other_ship, point1);
			}
			
			// these are checked separately so that seats/ram engines don't break from coups/repulsors
			if (this.hasTag("removable")) Die(this);
			if (blob.hasTag("removable")) Die(blob);
			else if (!this.hasTag("removable"))
			{
				if (this.hasTag("seat")) Die(this);
				if (blob.hasTag("seat")) Die(blob);
					
				if (this.hasTag("ramengine"))
				{
					if (blob.hasTag("core"))
						this.server_Hit(blob, point1, ship.vel, 0.5f, 0, true);
					else if (blob.hasTag("propeller"))
						this.server_Hit(blob, point1, ship.vel, 2.1f, 0, true);
					else if (blob.hasTag("platform") || blob.hasTag("ramengine"))
						Die(blob);
					else
						this.server_Hit(blob, point1, ship.vel, 1.0f, 0, true);
						
					Die(this);
				}
				else if (this.hasTag("ram"))
				{
					if (blob.hasTag("propeller") || blob.hasTag("plank"))
					{
						this.server_Hit(this, point1, ship.vel, 2.2f, 0, true);
						Die(blob);
					}
					else if (blob.hasTag("hull") || blob.hasTag("ram"))
					{
						Die(this);
						Die(blob);
					}
					else if (blob.hasTag("core"))
					{
						this.server_Hit(blob, point1, ship.vel, 1.0f, 0, true);
						Die(this);
					}
					else if (blob.hasTag("weapon"))
					{
						this.server_Hit(blob, point1, ship.vel, this.getHealth()/2, 0, true);
						Die(this);
					}
					else if (!blob.hasTag("solid"))
					{
						this.server_Hit(this, point1, ship.vel, 1.1f, 0, true);
						Die(blob);
					}
				}
				else if (this.hasTag("bomb")) //bombs annihilate all
				{
					if (blob.hasTag("mothership") || blob.hasTag("secondaryCore"))
						this.server_Hit(blob, point1, ship.vel, 2.7f, 0, true);
					else Die(blob);
					Die(this);
				}
			}
		}
	}
	else if (isClient() && blob.getName() == "human" && this.getShape().getConsts().collidable) // block vs player
	{
		if (blob.getAirTime() > 4) //air time is time spent on water
		{
			//kill player by impact
			Ship@ ship = getShipSet().getShip(color);
			if (ship !is null && (ship.vel.LengthSquared() > 5.0f || Maths::Abs(ship.angle_vel) > 1.75f || blob.getOldVelocity().LengthSquared() > 9.0f))
			{
				Vec2f blockSide(5.0f, 0.0f);
				blockSide.RotateBy(-ship.vel.Angle());
				const bool noSideHits = ((this.getPosition() + blockSide) - point1).Length() < 4.15f; //dont die if we arent in block's path
				
				if (!noSideHits)
					directionalSoundPlay("Scrape1", point1);
				
				if ((blob.isMyPlayer() || (blob.getPlayer() !is null && blob.getPlayer().isBot())) && 
					noSideHits && blob.getTeamNum() != this.getTeamNum())
				{
					CBitStream params;
					params.write_netid(this.getNetworkID());
					blob.SendCommand(blob.getCommandID("run over"), params);
				}
			}
		}
	}
}

void CoupleShip(CBlob@ this, CRules@ rules)
{
	this.SendCommand(this.getCommandID("couple"));
	CBlob@[] tempArray; tempArray.push_back(this);
	rules.push("dirtyBlocks", tempArray);
}

void CollisionResponse(CRules@ rules, Ship@ ship, Ship@ other_ship, Vec2f&in point1)
{
	Vec2f velnorm = ship.vel; 
	const f32 vellen = velnorm.Normalize();
	Vec2f other_velnorm = other_ship.vel; 
	const f32 other_vellen = other_velnorm.Normalize();
	
	Vec2f colvec1 = point1 - ship.pos;
	Vec2f colvec2 = point1 - other_ship.pos;
	colvec1.Normalize();
	colvec2.Normalize();
	
	const f32 massratio1 = other_ship.mass / (ship.mass + other_ship.mass + 0.01f);
	const f32 massratio2 = ship.mass / (ship.mass + other_ship.mass + 0.01f);
	
	const Vec2f shipvel = ClampSpeed(ship.vel + colvec1 * -other_vellen * massratio1 * 2 - colvec1*0.2f, 20);
	const Vec2f other_shipvel = ClampSpeed(other_ship.vel + colvec2 * -vellen * massratio2 * 2 - colvec2*0.2f, 20);
	
	const u8 shake = (vellen * ship.mass + other_vellen * other_ship.mass)*0.5f;
	
	CBitStream bs;
	bs.write_s32(ship.id);
	bs.write_s32(other_ship.id);
	bs.write_Vec2f(shipvel);
	bs.write_Vec2f(other_shipvel);
	bs.write_Vec2f(point1);
	bs.write_u8(shake);
	rules.SendCommand(rules.getCommandID("ship collision"), bs); //sent to Ships.as
}

Vec2f ClampSpeed(const Vec2f&in vel, const f32&in cap)
{
	return Vec2f(Maths::Clamp(vel.x, -cap, cap), Maths::Clamp(vel.y, -cap, cap));
}

void onDie(CBlob@ this)
{
	if (!isClient()) return;
	
	//gib the sprite
	if (this.getShape().getVars().customData > 0)
		this.getSprite().Gib();
	
	//kill humans standing on top. done locally because lag makes server unable to catch the overlapping playerblobs
	if (!this.hasTag("removable") && !this.hasTag("disabled"))
	{
		CBlob@ localBlob = getLocalPlayerBlob();
		if (localBlob !is null && localBlob.get_u16("shipBlobID") == this.getNetworkID())
		{
			if (localBlob.isMyPlayer() && localBlob.getDistanceTo(this) < 6.5f)
			{
				CBitStream params;
				params.write_netid(localBlob.getNetworkID());
				localBlob.SendCommand(localBlob.getCommandID("run over"), params);
			}
		}
	}
}

void Die(CBlob@ this)
{
	this.Tag("dead");
	this.server_Die();
}

//mothership damage alerts
f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	const int color = this.getShape().getVars().customData;
	if (color <= 0) return 0.0f; // unplaced blocks are invincible
	
	if (isClient() && damage > 0.0f)
	{
		CPlayer@ localPly = getLocalPlayer();
		if (localPly is null) return damage;
		
		CRules@ rules = getRules();
		Ship@ ship = getShipSet(rules).getShip(color);
		if (ship is null) return damage;
		
		if (localPly.getTeamNum() == this.getTeamNum() && ship.isMothership)
		{	
			const f32 msDMG = rules.get_f32("msDMG");
			if (msDMG < 6.0f)
				rules.set_f32("msDMG", msDMG + (this.hasTag("mothership") ? 4.0f : 1.0f) * damage);
		}
	}
	
	return damage;
}

void onHealthChange(CBlob@ this, f32 oldHealth)
{
	if (this.getShape().getVars().customData <= 0) return;
	
	const f32 hp = this.getHealth();

	if (hp <= 0.0f && !this.hasTag("mothership")) this.server_Die();
	else
	{
		//update reclaim status
		if (hp < this.get_f32("current reclaim"))
		{
			this.set_f32("current reclaim", hp);
		}
		
		if (isClient())
		{
			if (hp > oldHealth)
			{
				makeHealParticle(this, "HealParticle2"); //cute green particles
			}
		}
	}
}

void onGib(CSprite@ this)
{
	const Vec2f pos = this.getBlob().getPosition();
	directionalSoundPlay("destroy_wood", pos);
}

void onChangeTeam(CBlob@ this, const int oldTeam)
{
	if (!isServer()) //awkward fix for blob team changes wiping up the frame state (rest on ships.as)
	{
		CSprite@ sprite = this.getSprite();
		const u8 frame = this.get_u8("frame");
		if (sprite.getFrame() == 0 && frame != 0)
			sprite.SetFrame(frame);
	}
}

// network

void onSendCreateData(CBlob@ this, CBitStream@ stream)
{
	stream.write_u8(this.getSprite().getFrame());
	stream.write_netid(this.get_netid("ownerID"));
}

bool onReceiveCreateData(CBlob@ this, CBitStream@ stream)
{
	u8 type = 0;
	u16 ownerID = 0; //netid
	
	if (!stream.saferead_u8(type))
	{
		warn("Block::onReceiveCreateData - missing type");
		return false;
	}

	if (!stream.saferead_netid(ownerID))
	{
		warn("Block::onReceiveCreateData - missing ownerID");
		return false;
	}

	this.getSprite().SetFrame(type);

	CBlob@ owner = getBlobByNetworkID(ownerID);
	if (owner !is null)
	{
	    owner.push("blocks", this.getNetworkID());
		this.getShape().getVars().customData = -1; // don't push on ship
	}

	return true;
}
