#include "ShipsCommon.as";
#include "AccurateSoundPlay.as"
#include "ShiprektTranslation.as";

const u8 ACTIVATION_DELAY = 45; //30 ticks = 1 second

//this.get_bool("state") = true Means gate is open
//this.get_bool("state") = false Means gate is closed



void onInit(CBlob@ this)
{
	this.set_f32("weight", 3.0f);
	
	this.Tag("gate");
	this.Tag("solid");
	this.Tag("armor");
	this.addCommandID("activate");
	this.addCommandID("chain_activate");
	this.addCommandID("client_actions");
	this.getShape().getConsts().collidable = true;
	
	CSprite@ sprite = this.getSprite();
	//activated animation
	{
		Animation@ anim = sprite.addAnimation("open", 7, false);

		int[] frames = {0, 1, 2};
		anim.AddFrames(frames);
	}
	//activated animation
	{
		Animation@ anim = sprite.addAnimation("close", 7, false);

		int[] frames = {2, 1, 0};
		anim.AddFrames(frames);
	}
	sprite.SetAnimation("close");
}
void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (this.getDistanceTo(caller) > 100
		|| this.getShape().getVars().customData <= 0
		|| this.getTeamNum() != caller.getTeamNum()
		|| this.get_u32("activationTime") + ACTIVATION_DELAY > getGameTime())
		return;

	CBitStream params;
	params.write_u32(getGameTime());
	CButton@ button = caller.CreateGenericButton(this.get_bool("state") ? 1	: 3 , Vec2f_zero, this, this.getCommandID("activate"), "", params);
	if (button !is null)
	{
		button.radius = 8.0f;
		button.enableRadius = 120.0f;
	}
}

void ChainReaction(CBlob@ this, const bool state)
{
	if(isServer())
	{
		this.set_u32("activationTime", getGameTime());

		CBitStream bs;
		bs.write_bool(state);
		this.SendCommand(this.getCommandID("chain_activate"), bs);
		

		CBlob@[] overlapping;
		this.getOverlapping(@overlapping);
		
		const u8 overlappingLength = overlapping.length;
		for (u8 i = 0; i < overlappingLength; i++)
		{
			CBlob@ b = overlapping[i];
			if (b.hasTag("gate") && b.get_u32("activationTime") < getGameTime() && b.getShape().getVars().customData > 0 && b.getDistanceTo(this) < 8.8f)
			{
				ChainReaction(b, this.get_bool("state")); //repeat until all connected gates are activated
			}
		}
	}
}

void ChainReactionStart(CBlob@ this, const bool state)
{
	if(isServer())
	{
		this.set_u32("activationTime", getGameTime());

		CBlob@[] overlapping;
		this.getOverlapping(@overlapping);
			
		const u8 overlappingLength = overlapping.length;
		for (u8 i = 0; i < overlappingLength; i++)
		{
			CBlob@ b = overlapping[i];
			if (b.hasTag("gate") && b.get_u32("activationTime") < getGameTime() && b.getShape().getVars().customData > 0 && b.getDistanceTo(this) < 8.8f)
			{
				ChainReaction(b, state); //repeat until all connected gates are activated
			}
		}
	}
}

void setOpen(CBlob@ this, const bool state, const bool playsond)
{
	CSprite@ sprite = this.getSprite();

	if (state)
	{
        sprite.SetAnimation("open");//update sprite
		if(playsond) directionalSoundPlay("Gate_Open.ogg", this.getPosition());
	}
	else
	{
        sprite.SetAnimation("close");//update sprite
		if(playsond)  directionalSoundPlay("Gate_Close.ogg", this.getPosition());
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("chain_activate"))
	{
		if(isServer())
		{
			const bool newState = params.read_bool();
			this.set_bool("state", newState);
			this.getShape().getConsts().collidable = !newState;
	
			if(newState)
			{
				this.Tag("non-solid");
				this.getShape().getConsts().collidable = false;
			}
			else
			{
				this.Untag("non-solid");
				this.getShape().getConsts().collidable = true;
			}

			CBitStream bs;
			bs.write_u32(getGameTime());
			bs.write_bool(newState);
			bs.write_bool(false); //shall we play sound
			this.SendCommand(this.getCommandID("client_actions"), bs);
		}
	}
	else if (cmd == this.getCommandID("client_actions"))
	{
		if(isClient())
		{
			const u32 time = params.read_u32();
			const bool newState = params.read_bool();
			this.set_bool("state", newState);
			this.set_u32("activationTime", time);
			
			if(newState)
			{
				this.Tag("non-solid");
				this.getShape().getConsts().collidable = false;
			}
			else
			{
				this.Untag("non-solid");
				this.getShape().getConsts().collidable = true;
			}
			
			setOpen(this, newState, params.read_bool());
		}
	}
	else if (cmd == this.getCommandID("activate"))
	{
		if(isServer())
		{
			if(this.get_u32("activationTime") + ACTIVATION_DELAY > getGameTime()) return;
			const bool newState = !this.get_bool("state");
			this.set_bool("state", newState);
			this.getShape().getConsts().collidable = !newState;
			
			if(newState)
			{
				this.Tag("non-solid");
				this.getShape().getConsts().collidable = false;
			}
			else
			{
				this.Untag("non-solid");
				this.getShape().getConsts().collidable = true;
			}

			CBitStream bs;
			bs.write_u32(getGameTime());
			bs.write_bool(newState);
			bs.write_bool(true); //shall we play sound
			this.SendCommand(this.getCommandID("client_actions"), bs);

			ChainReactionStart(this, newState);
		}
	}
}