#include "ShipsCommon.as";
#include "HarpoonForceCommon.as";
#include "ParticleSpark.as";
#include "AccurateSoundPlay.as";
#include "PlankCommon.as";

// BUG: Visual sprite-layers 'shaking' when launching grapple at certain angles

const f32 harpoon_grapple_length = 300.0f;
const f32 harpoon_grapple_throw_speed = 20.0f;
const f32 harpoon_grapple_stiffness = 0.1f;

shared class HarpoonInfo
{
	bool grappling;
	bool reeling;
	u16 grapple_id;
	f32 grapple_ratio;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	HarpoonInfo()
	{
		grappling = false;
		reeling = false;
		grapple_id = 0xffff;
	}
};

void onInit(CBlob@ this)
{
	this.Tag("harpoon");
	this.Tag("weapon");
	
	this.set_f32("weight", 2.0f);
	
	this.set_string("seat label", "Control Harpoon"); 
	
	HarpoonInfo harpoon;
	this.set("harpoonInfo", @harpoon);

	this.addCommandID("hook"); //hook onto a block
	this.addCommandID("unhook"); //start reel
	this.addCommandID("grapple"); //start grapple sequence
	this.addCommandID("resetgrapple"); //return to normal
}

void onInit(CSprite@ this)
{
	const string texname = "Entities/Block/Harpoon.png";
	
	CSpriteLayer@ hook = this.addSpriteLayer("hook", texname, 16, 16);
	if (hook !is null)
	{
		Animation@ anim = hook.addAnimation("default", 0, false);
		anim.AddFrame(28);
		hook.SetRelativeZ(4.0f);
		hook.SetVisible(false);
	}
	
	CSpriteLayer@ looseRope = this.addSpriteLayer("loose rope", texname, 32, 32);
	if (looseRope !is null)
	{
		Animation@ anim = looseRope.addAnimation("default", 1, true);
		array<int> frames = {0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1};
		anim.AddFrames(frames);
		Animation@ tight = looseRope.addAnimation("tight", 0, false);
		tight.AddFrame(3);
		looseRope.SetRelativeZ(2.0f);
		looseRope.SetVisible(false);
	}
	
	CSpriteLayer@ base = this.addSpriteLayer("harpoon", "HarpoonBlock.png", 16, 16);
	if (base !is null)
	{
		base.SetRelativeZ(3.0f);
		base.SetLighting(false);
		Animation@ animFired = base.addAnimation("fired", 0, false);
		animFired.AddFrame(1);

		Animation@ animSet = base.addAnimation("set", 0, false);
		animSet.AddFrame(0);
		base.SetAnimation("set");
	}
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return;
	
	HarpoonInfo@ harpoon;
	if (!this.get("harpoonInfo", @harpoon)) return;
	
	const Vec2f pos = this.getPosition();
	
	CSprite@ sprite = this.getSprite();
	doRopeUpdate(sprite, this, harpoon);
	
	CBlob@ occupier = this.getAttachmentPoint(0).getOccupied();
	if (occupier !is null)
	{
		Manual(this, occupier, harpoon);
		
		if (occupier.isKeyJustPressed(key_action1) && occupier.isMyPlayer()) //left click
		{
			// more intuitive aiming (compensates for gravity and cursor position)
			Vec2f direction = occupier.getAimPos() - pos;
			const f32 distance = direction.Normalize();
				
			if (!harpoon.grappling && !harpoon.reeling && distance > 1.0f) //otherwise grapple PROBLEM BLOCK
			{
				CBitStream bt;
				bt.write_Vec2f(direction);
				this.SendCommand(this.getCommandID("grapple"), bt);
			}
		}
	}
	
	if (harpoon.grappling || harpoon.grapple_id != 0xffff)
	{
		//update grapple
		//TODO move to its own script?
		
		CMap@ map = getMap();
		
		const bool ropeTooLong = (harpoon.grapple_pos - pos).getLength() > harpoon_grapple_length;	
		const f32 harpoon_grapple_range = harpoon_grapple_length * harpoon.grapple_ratio;
		
		//reel in
		if (harpoon.grapple_ratio > 0.2f)
			harpoon.grapple_ratio -= 1.0f / getTicksASecond();
		
		Vec2f force = harpoon.grapple_pos - pos;
		const f32 dist = force.Normalize();
		const f32 offdist = dist - harpoon_grapple_range;
		Vec2f offset;
		
		if (isServer() && !harpoon.reeling)
		{
			const Vec2f dim = map.getMapDimensions();
			//when to start reeling back
			bool ropeOutOfBounds = dim.x <= harpoon.grapple_pos.x || harpoon.grapple_pos.x <= 0.0f || dim.y <= harpoon.grapple_pos.y || harpoon.grapple_pos.y <= 0.0f;
			Tile bTile = map.getTile(harpoon.grapple_pos);
			bool onRock = map.isTileSolid(bTile);
			
			if (((ropeTooLong || ropeOutOfBounds || onRock) && harpoon.grapple_id == 0xffff)
				|| (occupier !is null ? occupier.isKeyJustPressed(key_action2) : false))
			{
				this.SendCommand(this.getCommandID("unhook"));
			}
		}
		
		// Harpoon reeling back
		if (harpoon.reeling)
		{
			//get the force and offset vectors
			if (offdist > 0)
			{
				offset = force * Maths::Min(8.0f, offdist * harpoon_grapple_stiffness);
				force *= 1000.0f / (harpoon.grapple_pos - pos).getLength();
			}
			else
			{
				force.Set(0,0);
			}

			harpoon.grapple_vel = -force;
			
			Vec2f retractBaseMin = (harpoon.grapple_pos - pos);
			retractBaseMin.Normalize();
			const Vec2f retract = retractBaseMin*7.0f;
			Vec2f next = harpoon.grapple_pos + harpoon.grapple_vel - retract;
			next -= offset;

			Vec2f dir = next - harpoon.grapple_pos;
			f32 delta = dir.Normalize();
			const f32 step = map.tilesize * 0.5f;
			while (delta > 0) //fake raycast
			{
				if (delta > step)
				{
					harpoon.grapple_pos += dir * step;
				}
				else
				{
					harpoon.grapple_pos = next;
				}
				delta -= step;
				
				if ((harpoon.grapple_pos - pos).Length() < 5.0f)
				{
					delta = 0.0f;
					if (isServer())
						this.SendCommand(this.getCommandID("resetgrapple"));
				}
			}
		}
		else
		{
			//get the force and offset vectors
			if (offdist > 0)
			{
				offset = force * Maths::Min(8.0f, offdist * harpoon_grapple_stiffness);
			}

			// Grapple is going forward
			if (harpoon.grapple_id == 0xffff)
			{
				Vec2f next = harpoon.grapple_pos + harpoon.grapple_vel;
				next -= offset;

				Vec2f dir = next - harpoon.grapple_pos;
				f32 delta = dir.Normalize();
				bool found = false;
				const f32 step = map.tilesize * 0.5f;
				while (delta > 0 && !found) //fake raycast
				{
					if (delta > step)
					{
						harpoon.grapple_pos += dir * step;
					}
					else
					{
						harpoon.grapple_pos = next;
					}
					delta -= step;
					found = checkGrappleStep(this, harpoon, map);
				}
				
				if (isClient())
				{
					CSpriteLayer@ layer = sprite.getSpriteLayer("harpoon");
					layer.SetAnimation("fired");
				}
			}
			else // Hook has a grappled block
			{
				CBlob@ b = null;
				if (harpoon.grapple_id != 0xffff)
				{
					@b = getBlobByNetworkID(harpoon.grapple_id);
					if (b is null && isServer())
					{
						this.SendCommand(this.getCommandID("unhook"));
					}
				}
				
				if (b !is null)
				{
					harpoon.grapple_pos = b.getPosition();
					
					// Pull the ships together
					if (ropeTooLong)
					{
						ShipDictionary@ ShipSet = getShipSet();
						Ship@ thisShip = ShipSet.getShip(col);
						Ship@ hitShip = ShipSet.getShip(b.getShape().getVars().customData);
						if (hitShip !is null && thisShip !is null && hitShip.id != thisShip.id)
						{
							//TODO: fix angular velocity support & find a better solution for super-sonic speeds
							Vec2f moveVel;
							float angleVel;	
						
							const f32 hitMass = hitShip.mass;
							HarpoonForces(this, b, hitShip, moveVel, angleVel);
							moveVel /= hitMass;
							//angleVel /= hitMass;
							hitShip.vel = ClampSpeed(hitShip.vel + moveVel, 15);
							//hitShip.angle_vel += angleVel;
							
							const f32 thisMass = thisShip.mass;
							HarpoonForces(b, this, thisShip, moveVel, angleVel);
							moveVel /= thisMass;
							//angleVel /= thisMass;
							thisShip.vel = ClampSpeed(thisShip.vel + moveVel, 15);
							//thisShip.angle_vel += angleVel;
						}
					}
				}
			}
		}
	}
}

Vec2f ClampSpeed(const Vec2f&in vel, const f32&in cap)
{
	return Vec2f(Maths::Clamp(vel.x, -cap, cap), Maths::Clamp(vel.y, -cap, cap));
}

void Manual(CBlob@ this, CBlob@ occupier, HarpoonInfo@ harpoon)
{
	Vec2f aimpos = occupier.getAimPos();
	Vec2f aimvector = aimpos - this.getPosition();
	Vec2f off = harpoon.grapple_pos - this.getPosition();
	const f32 aimAngle = harpoon.grappling ? -off.Angle() : -aimvector.Angle();

	// rotate muzzle
	CSpriteLayer@ layer = this.getSprite().getSpriteLayer("harpoon");
	layer.ResetTransform();
	layer.RotateBy(aimAngle - this.getAngleDegrees(), Vec2f_zero);
	
	occupier.setAngleDegrees(aimAngle);
}

void doRopeUpdate(CSprite@ this, CBlob@ blob, HarpoonInfo@ harpoon)
{
	if (!isClient()) return;
	
	CSpriteLayer@ looseRope = this.getSpriteLayer("loose rope");
	CSpriteLayer@ hook = this.getSpriteLayer("hook");
	CSpriteLayer@ layer = this.getSpriteLayer("harpoon");
	
	const string anim = harpoon.grapple_id != 0xffff || harpoon.reeling ? "tight" : "default";
	looseRope.SetAnimation(anim);

	const bool visible = harpoon.grappling;
	looseRope.SetVisible(visible);
	hook.SetVisible(visible);

	Vec2f off = harpoon.grapple_pos - blob.getPosition();
	f32 ropelen = Maths::Max(0.1f, off.Length() / 32.0f);
	
	looseRope.ResetTransform();
	looseRope.ScaleBy(Vec2f(ropelen, 1.0f));
	looseRope.TranslateBy(Vec2f(ropelen * 16.0f, 0.0f));	
	looseRope.RotateBy(-off.Angle() - blob.getAngleDegrees(), Vec2f());
	
	hook.ResetTransform();
	hook.TranslateBy(Vec2f(ropelen * 32.0f, 0.0f));
	hook.RotateBy(-off.Angle()- blob.getAngleDegrees(), Vec2f());
	
	if (visible)
	{
		if (!blob.hasAttached())
		{
			layer.ResetTransform();
			layer.RotateBy(-off.Angle() - blob.getAngleDegrees(), Vec2f_zero);
		}
	}
	else
		layer.SetAnimation("set");
}

const bool checkGrappleStep(CBlob@ this, HarpoonInfo@ harpoon, CMap@ map)
{
	CBlob@ b = map.getBlobAtPosition(harpoon.grapple_pos);
	if (b !is null)
	{
		if (b.hasTag("plank") && !CollidesWithPlank(b, harpoon.grapple_vel))
			return false;
		
		if (b.getShape().getVars().customData > 0 && b.getShape().getConsts().collidable)
		{
			if (isServer())
			{
				CBitStream bt;
				bt.write_netid(b.getNetworkID());
				this.SendCommand(this.getCommandID("hook"), bt);
			}
			
			return true;
		}
	}

	return false;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	HarpoonInfo@ harpoon;
	if (!this.get("harpoonInfo", @harpoon)) return;

	if (cmd == this.getCommandID("grapple"))
	{
		Vec2f pos = this.getPosition();
		Vec2f direction = params.read_Vec2f();
		Ship@ ship = getShipSet().getShip(this.getShape().getVars().customData);
		Vec2f shipVel = ship !is null ? ship.vel : Vec2f();
		
		harpoon.grappling = true;
		harpoon.grapple_id = 0xffff;
		harpoon.grapple_pos = pos + direction + (shipVel*2);
		harpoon.grapple_ratio = 1.0f; //allow fully extended
		harpoon.grapple_vel = direction * harpoon_grapple_throw_speed;
		
		if (isClient())
		{
			directionalSoundPlay("HookShot.ogg", pos, 1.0f, XORRandom(2) == 1 ? 1.0f : 1.5f);
			CParticle@ p = ParticleAnimated("Entities/Effects/Sprites/WhitePuff.png",
								pos,
								this.getVelocity()*0.5f + direction/(direction).getLength(),
								1.0f, 0.5f, 
								2, 
								0.0f, true);
								
			if (p !is null)
				p.Z = 650;
		}
	}
	else if (cmd == this.getCommandID("hook"))
	{
		const u16 id = params.read_netid();
		harpoon.grapple_id = id;
		if (isClient())
		{
			directionalSoundPlay("crowbar_impact2.ogg", harpoon.grapple_pos);
			sparks(harpoon.grapple_pos, v_fastrender ? 7 : 9, 3.0f);
		}
	}
	else if (cmd == this.getCommandID("unhook"))
	{
		if (isClient())
			directionalSoundPlay("HookReel.ogg", this.getPosition());
			
		harpoon.grapple_id = 0xffff;
		harpoon.reeling = true;
	}
	else if (cmd == this.getCommandID("resetgrapple"))
	{
		if (isClient())		
			directionalSoundPlay("HookReset.ogg", this.getPosition());
		
		harpoon.grapple_id = 0xffff;
		harpoon.grappling = false;
		harpoon.reeling = false;
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	HarpoonInfo@ harpoon;
	if (!this.get("harpoonInfo", @harpoon)) 
		return;
	
	if ((harpoon.grapple_pos - caller.getPosition()).getLength() > 16.0f || this.getShape().getVars().customData <= 0)
		return;

	if (harpoon.grapple_id != 0xffff)
	{
		CBlob@ b = getBlobByNetworkID(harpoon.grapple_id);
		if (b !is null)
		{
			CButton@ unhookButton = caller.CreateGenericButton(1, Vec2f(), b, unhookGrapple, "Unhook Harpoon");
			if (unhookButton !is null)
			{
				unhookButton.radius = 8.0f; //engine fix
				unhookButton.enableRadius = 13.0f;
			}
		}
	}
}

//HACK: use a callback function in order to allow the button to follow the block the harpoon has grappled 
void unhookGrapple(CBlob@ block, CBlob@ caller)
{
	const u16 id = block.getNetworkID();
	CBlob@[] harpoons;
	getBlobsByTag("harpoon", @harpoons); //we cant inherit the harpoon blob with callback so we have to find it ourselves
	
	for (u8 i = 0; i < harpoons.length; ++i)
	{
		CBlob@ b = harpoons[i];
		HarpoonInfo@ harpoon;
		if (!b.get("harpoonInfo", @harpoon)) continue;
		
		if (harpoon.grapple_id == id)
		{
			b.SendCommand(b.getCommandID("unhook"));
			return;
		}
	}
}

// network

void onSendCreateData(CBlob@ this, CBitStream@ stream)
{
	HarpoonInfo@ harpoon;
	if (!this.get("harpoonInfo", @harpoon)) return;

	stream.write_bool(harpoon.grappling);
	stream.write_bool(harpoon.reeling);
	stream.write_u16(harpoon.grapple_id);
	stream.write_f32(harpoon.grapple_ratio);
	stream.write_Vec2f(harpoon.grapple_pos);
	stream.write_Vec2f(harpoon.grapple_vel);
}

bool onReceiveCreateData(CBlob@ this, CBitStream@ stream)
{
	HarpoonInfo@ harpoon;
	if (!this.get("harpoonInfo", @harpoon)) return true;

	if (!stream.saferead_bool(harpoon.grappling))     return false;
	if (!stream.saferead_bool(harpoon.reeling))       return false;
	if (!stream.saferead_u16(harpoon.grapple_id))     return false;
	if (!stream.saferead_f32(harpoon.grapple_ratio))  return false;
	if (!stream.saferead_Vec2f(harpoon.grapple_pos))  return false;
	if (!stream.saferead_Vec2f(harpoon.grapple_vel))  return false;

	return true;
}
