#include "AccurateSoundPlay.as";

void onInit(CBlob@ this)
{
	this.Tag("propeller");
	this.Tag("solid");
	this.Tag("landMotor");
	this.Tag("rotates");
	
	this.set_f32("weight", 1.0f);
	
	this.set_f32("power", 0.0f);
	this.set_f32("rot_angle", 0.0f);
	this.set_f32("powerFactor", 4.0f);
	this.set_u32("onTime", 0);
	this.set_u8("stallTime", 0);

	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ propeller = sprite.addSpriteLayer("propeller","RotatingWheel.png", 16,16 );
	if(propeller !is null)
	{
		propeller.ScaleBy(Vec2f(0.5f, 0.5f));
		propeller.SetOffset(Vec2f(0,0));
		propeller.SetRelativeZ(-2);
		propeller.SetLighting(false);
		Animation@ animcharge = propeller.addAnimation("go", 1, true);
		animcharge.AddFrame(3);
		animcharge.AddFrame(4);
		animcharge.AddFrame(5);
		Animation@ animcharge2 = propeller.addAnimation("reverse", 1, true);
		animcharge2.AddFrame(5);
		animcharge2.AddFrame(4);
		animcharge2.AddFrame(3);
		propeller.SetAnimation("go");
	}

	sprite.SetEmitSound("Wheel_Loop");
	sprite.SetEmitSoundVolume(0.5f);
	sprite.SetEmitSoundPaused(true);
	
	this.addCommandID("reverse");
	//this.addCommandID("rotate back");
}

void onTick(CBlob@ this)
{
	CSpriteLayer@ propeller = this.getSprite().getSpriteLayer("propeller");;
	propeller.ResetTransform();
	propeller.RotateBy(this.get_f32("rot_angle"), Vec2f_zero);
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (this.getDistanceTo(caller) > 100
		|| this.getShape().getVars().customData <= 0
		|| this.getTeamNum() != caller.getTeamNum())
		return;
	
	CBitStream params;
	params.write_u16(caller.getNetworkID());
	CButton@ button = caller.CreateGenericButton(2 - this.getTeamNum(), Vec2f_zero, this, BuildMenu, "Reverse Wheel Turning");
	if (button !is null)
	{
		button.radius = 2.0f;
		button.enableRadius = 32.0f;
	}
}

void BuildMenu(CBlob@ this, CBlob@ caller)
{
	CGridMenu@ menu = CreateGridMenu(Vec2f(getScreenWidth()/2, getScreenHeight() * 0.75), this, Vec2f(2, 2), "Confugure Wheel");
	if (menu is null) return;
	menu.deleteAfterClick = false;
	
	CBitStream params;
	params.write_u16(caller.getNetworkID());
	CGridButton@ reverse_button = menu.AddButton("$RIGHT_AND_LEFT$", "Reverse turning of the wheel\n(When rotating left or right)", this.getCommandID("reverse"), params);
	//CGridButton@ rot_button = menu.AddButton("$DOWN$", "Rotate the wheel back", this.getCommandID("rotate back"), params);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if(cmd == this.getCommandID("reverse"))
	{
		if (!this.hasTag("reverse_rotate"))
			this.Tag("reverse_rotate");
		else
			this.Untag("reverse_rotate");
			
		if(isClient()) directionalSoundPlay("mechanical_click", this.getPosition());
	}
	/*else if(cmd == this.getCommandID("rotate back"))
	{
		this.setAngleDegrees(this.getAngleDegrees() + 180);
		if(isClient()) directionalSoundPlay("mechanical_click", this.getPosition());
	}*/
}

