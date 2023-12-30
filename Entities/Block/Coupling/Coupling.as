//coupling
#include "AccurateSoundPlay.as";
void onInit(CBlob@ this)
{
	this.addCommandID("decouple");
	this.addCommandID("couple");
	this.Tag("coupling");
	this.Tag("ramming");
	this.Tag("removable");//for corelinked checks
	
	this.set_f32("weight", 0.1f);
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (this.getShape().getVars().customData <= 0)
		return;

	//only owners can directly destroy the coupling
	if (this.getDistanceTo(caller) < 6 && caller.getPlayer().getUsername() == this.get_string("playerOwner"))
	{
		CButton@ button = caller.CreateGenericButton(2, Vec2f(0.0f, 0.0f), this, this.getCommandID("decouple"), "Decouple");
		if (button !is null)
		{
			button.radius = 8.0f; //engine fix
			button.enableRadius = 8.0f;
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("decouple"))
	{
		this.server_Die();
	}
	else if (cmd == this.getCommandID("couple"))
	{
		if (isClient())
		{
			directionalSoundPlay("mechanical_click", this.getPosition());
		}
	}
}
