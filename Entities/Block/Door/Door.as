#include "AccurateSoundPlay.as";

void onInit(CBlob@ this)
{
	this.Tag("door");
	
	this.set_f32("weight", 1.0f);
	
    this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().collidable = true;

	CSprite@ sprite = this.getSprite();
	//default
	{
		Animation@ anim = sprite.addAnimation("default", 0, false);
		anim.AddFrame(0);
	}
	//folding
	{
		Animation@ anim = sprite.addAnimation("open", 2, false);
		int[] frames = {0, 1};
		anim.AddFrames(frames);
	}
}

const bool isOpen(CBlob@ this)
{
	return !this.getShape().getConsts().collidable;
}

void setOpen(CBlob@ this, bool open)
{
	CSprite@ sprite = this.getSprite();

	if (open)
	{
        sprite.SetAnimation("open");//update sprite
		this.getShape().getConsts().collidable = false;
		directionalSoundPlay("/DoorOpen.ogg", this.getPosition());
	}
	else
	{
        sprite.SetAnimation("default");//update sprite
		this.getShape().getConsts().collidable = true;
		directionalSoundPlay("/DoorClose.ogg", this.getPosition());
	}
}

const bool canClose(CBlob@ this)
{
	const u8 count = this.getTouchingCount();
	for (u8 step = 0; step < count; ++step)
	{
		CBlob@ blob = this.getTouchingByIndex(step);
		if (blob.hasTag("player"))
			return false;
	}
	return true;
}

void onEndCollision(CBlob@ this, CBlob@ blob)
{
	if (blob !is null)
	{
		if (canClose(this) && isOpen(this))
			setOpen(this, false);
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	if (isOpen(this) || this.getShape().getVars().customData <= 0)
		return false;

	if (blob.getShape().getConsts().collidable && //can collide
		this.getTeamNum() == blob.getTeamNum() && //is same team
		blob.hasTag("player"))                    //is human
	{
		setOpen(this, true);
		return false;
	}
	return true;
}
