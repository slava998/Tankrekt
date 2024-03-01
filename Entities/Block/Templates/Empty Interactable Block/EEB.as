#include "ShipsCommon.as";
#include "AccurateSoundPlay.as"
#include "ShiprektTranslation.as";

const u8 ACTIVATION_DELAY = 30; //30 ticks = 1 second
const u8 INTERACTION_RANGE = 20;

//Template of a block with button.

void onInit(CBlob@ this)
{
	this.set_f32("weight", 1.0f);
	
	this.Tag("solid");
	this.addCommandID("activate");
	this.addCommandID("client_actions");
}
void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (this.getDistanceTo(caller) > INTERACTION_RANGE
		|| this.getShape().getVars().customData <= 0
		|| this.getTeamNum() != caller.getTeamNum()
		|| this.get_u32("activationTime") + ACTIVATION_DELAY > getGameTime())
		return;

	CBitStream params;
	params.write_u32(getGameTime());
	CButton@ button = caller.CreateGenericButton(0 , Vec2f_zero, this, this.getCommandID("activate"), "", params);
	if (button !is null)
	{
		button.radius = 8.0f;
		button.enableRadius = INTERACTION_RANGE * 1.2f;
	}
}

void OnActivationServer(CBlob@ this)
{
	if(isServer())
	{
		print("server: activated");
	}
}

void OnActivationClient(CBlob@ this)
{
	if(isClient())
	{
		print("client: activated");
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("activate"))
	{
		if(isServer())
		{
			const u32 time = getGameTime();
			if(this.get_u32("activationTime") + ACTIVATION_DELAY > time) return;
			
			this.set_u32("activationTime", time);

			OnActivationServer(this);

			CBitStream bs;
			bs.write_u32(time);
			this.SendCommand(this.getCommandID("client_actions"), bs);
		}
	}
	else if (cmd == this.getCommandID("client_actions"))
	{
		if(isClient())
		{
			const u32 time = params.read_u32();
			this.set_u32("activationTime", time);

			OnActivationClient(this);
		}
	}
}