//////////////////////////////////////////////////////
//
//  BulletClass.as - Vamist
//
//  CORE FILE
//  
//  A bit messy, stuff gets removed and added as time 
//  goes on. Handles the bullet class, what it hits
//  onTick, onRender etc
//
//  Try not poke around here unless you need to
//  Some code here is messy
//

#include "WaterEffects.as";
#include "ParticleSpark.as";
#include "AccurateSoundPlay.as";
#include "PlankCommon.as";
#include "Hitters.as";
const SColor trueWhite = SColor(255,255,255,255);
Driver@ PDriver = getDriver();
const int ScreenX = getDriver().getScreenWidth();
const int ScreenY = getDriver().getScreenWidth();

class BulletObj
{
	u16 GunID;
	Vec2f CurrentPos;
	Vec2f OldPos;
	Vec2f LastPos;
	f32 StartingAngle;
	u8 Speed;
	s8 TimeLeft;
	bool Killed;
	
	BulletObj(CBlob@ gun, const f32&in angle, const Vec2f&in pos)
	{
		GunID = gun.getNetworkID();
		CurrentPos = OldPos = LastPos = pos;
		StartingAngle = angle;
		Speed    = gun.get_u8("speed");
		TimeLeft = gun.get_u8("TTL");
		Killed = false;
	}

	bool onFakeTick(CMap@ map)
	{
		const Vec2f dim = map.getMapDimensions();
		const bool LeftMap = CurrentPos.x < 0 || CurrentPos.y < 0 || CurrentPos.x > dim.x || CurrentPos.y > dim.y;

		//Time to live check
		TimeLeft--;
		if (TimeLeft == 0 || LeftMap)
		{
			if (!v_fastrender && !Killed)
			{
				if (isInWater(CurrentPos))
					MakeWaterParticle(CurrentPos, Vec2f_zero);
				else
					AngledDirtParticle(CurrentPos, StartingAngle - 90);
			}

			return true; //kill bullet
		}

		// Update bullet position
		OldPos = CurrentPos;
		Vec2f dir = Vec2f(1, 0.0f).RotateBy(StartingAngle);
		CurrentPos += dir * Speed;
		
		HitTargets(map, dir);

		if (Killed)
		{
			TimeLeft = 1;
		}
		return false;
	}
	
	void HitTargets(CMap@ map, const Vec2f&in dir)
	{
		CBlob@ gunBlob = getBlobByNetworkID(GunID);
		if (gunBlob is null) return;

		bool breakLoop = false;
		HitInfo@[] list;
		if (!map.getHitInfosFromRay(OldPos, -(CurrentPos - OldPos).Angle(), (OldPos - CurrentPos).Length(), gunBlob, @list)) return;

		for (int a = 0; a < list.length(); a++)
		{
			HitInfo@ hit = list[a];
			Vec2f hitpos = hit.hitpos;
			CBlob@ b = @hit.blob;
			if (b !is null) // blob
			{
				//print(blob.getName() + '\n'+blob.getName().getHash()); useful for debugging new tiles to hit
				if (b.hasTag("plank") && !CollidesWithPlank(b, dir)) continue;

				if (canHit(gunBlob, b))
				{
					if (b.hasTag("block"))
						hitEffects(hitpos);

					breakLoop = true;
				}
				else if (b.hasTag("seat"))
				{
					AttachmentPoint@ seat = b.getAttachmentPoint(0);
					if (seat is null) continue;

					CBlob@ occupier = seat.getOccupied();
					if (occupier !is null && occupier.getTeamNum() != gunBlob.getTeamNum())
					{
						@b = occupier;
						breakLoop = true;
					}
				}

				CBlob@ owner = gunBlob;
				if (gunBlob.hasTag("seat"))
				{
					AttachmentPoint@ seat = b.getAttachmentPoint(0);
					if (seat is null) continue;

					CBlob@ owner = seat.getOccupied();
					
				}
				if (breakLoop && isServer())
				{
					gunBlob.server_Hit(b, hitpos, dir, getDamage(b, gunBlob), Hitters::arrow, true);
				}
			}
			else
			{
				hitEffects(hitpos);
				breakLoop = true;
			}

			if (breakLoop)
			{
				CurrentPos = hitpos;
				Killed = true;
				break;
			}
		}
	}

	void JoinQueue() // Every bullet gets forced to join the queue in onRenders, so we use this to calc to position
	{   
		// Are we on the screen?
		const Vec2f xLast = PDriver.getScreenPosFromWorldPos(LastPos);
		const Vec2f xNew  = PDriver.getScreenPosFromWorldPos(CurrentPos);
		if(!(xNew.x > 0 && xNew.x < ScreenX)) // Is our main position still on screen?
		{
			if(!(xLast.x > 0 && xLast.x < ScreenX)) // Was our last position on screen?
			{
				return; // No, lets not stay here then
			}
		}

		// Lerp
		Vec2f newPos = Vec2f_lerp(LastPos, CurrentPos, FRAME_TIME);
		LastPos = newPos;

		Vec2f TopLeft  = Vec2f(newPos.x -1.0, newPos.y-5);
		Vec2f TopRight = Vec2f(newPos.x -1.0, newPos.y+5);
		Vec2f BotLeft  = Vec2f(newPos.x +1.0, newPos.y-5);
		Vec2f BotRight = Vec2f(newPos.x +1.0, newPos.y+5);

		BotLeft.RotateBy( StartingAngle-90,newPos);
		BotRight.RotateBy(StartingAngle-90,newPos);
		TopLeft.RotateBy( StartingAngle-90,newPos);
		TopRight.RotateBy(StartingAngle-90,newPos);

		v_r_bullet.push_back(Vertex(TopLeft.x,  TopLeft.y,      0, 0, 0,   trueWhite)); // top left
		v_r_bullet.push_back(Vertex(TopRight.x, TopRight.y,     0, 1, 0,   trueWhite)); // top right
		v_r_bullet.push_back(Vertex(BotRight.x, BotRight.y,     0, 1, 1, trueWhite));   // bot right
		v_r_bullet.push_back(Vertex(BotLeft.x,  BotLeft.y,      0, 0, 1, trueWhite));   // bot left
	}

}

class BulletHolder
{
	BulletObj[] bullets;
	BulletHolder(){}

	void FakeOnTick(CRules@ this)
	{
		CMap@ map = getMap();
		for (int a = 0; a < bullets.length(); a++)
		{
			BulletObj@ bullet = bullets[a];
			if (bullet.onFakeTick(map))
			{
				bullets.erase(a);
				a--;
			}
		}
		//print(bullets.length() + '');
	}
	
	void FillArray()
	{
		for (int a = 0; a < bullets.length(); a++)
		{
			bullets[a].JoinQueue();
		}
	}

	void AddNewObj(BulletObj@ this)
	{
		CMap@ map = getMap();
		this.onFakeTick(map);
		bullets.push_back(this);
	}
}

void hitEffects(const Vec2f&in worldPoint)
{
	sparks(worldPoint, v_fastrender ? 1 : 4);
	directionalSoundPlay("Ricochet" + (XORRandom(3) + 1) + ".ogg", worldPoint, 0.50f);
}

bool canHit(CBlob@ gunBlob, CBlob@ b)
{
	if (b.hasTag("block") && b.getShape().getVars().customData <= 0)
		return false;
	if (b.getTeamNum() != gunBlob.getTeamNum() &&
	   (b.hasTag("core") || b.hasTag("weapon") || b.hasTag("rocket") || b.hasTag("bomb") || b.hasTag("player")))
		return true;

	return b.hasTag("solid") || (b.hasTag("door") && b.getShape().getConsts().collidable) || b.hasTag("bullet_collidable");
}

const f32 getDamage(CBlob@ hitBlob, CBlob@ gunBlob)
{
	f32 damage = 0.0f;

	if(gunBlob.getName() == "human")
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
	else if (gunBlob.hasTag("heavy machinegun"))
	{
		damage = 0.05f;

		if (hitBlob.hasTag("ramengine"))
			return 0.4f;
		if (hitBlob.hasTag("propeller"))
			return 0.135f;
		if (hitBlob.hasTag("plank"))
			return 0.1f;
		if (hitBlob.hasTag("decoyCore"))
			return 0.1f;
		if (hitBlob.hasTag("bomb"))
			return 0.5f;
		if (hitBlob.hasTag("rocket"))
			return 0.5f;
		if (hitBlob.hasTag("weapon"))
			return 0.125f;
		if (hitBlob.getName() == "human")
			return 0.25f;

		return damage;//cores, solids
	}
	else //machinegun
	
	damage = 0.01f;
	
	if (hitBlob.hasTag("ramengine"))
		return 0.25f;
	if (hitBlob.hasTag("propeller"))
		return 0.08f;
	if (hitBlob.hasTag("plank"))
		return 0.05f;
	if (hitBlob.hasTag("decoyCore"))
		return 0.075f;
	if (hitBlob.hasTag("bomb"))
		return 0.4f;
	if (hitBlob.hasTag("rocket"))
		return 0.35f;
	if (hitBlob.hasTag("weapon"))
		return 0.075f;
	if (hitBlob.getName() == "human")
		return 0.2f;

	return damage;//cores, solids

}