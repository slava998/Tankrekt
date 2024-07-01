void onInit(CBlob@ this)
{
	this.Tag("propeller");
	this.Tag("solid");
	this.Tag("landMotor");
	this.Tag("rotates");
	this.set_f32("mass_coef", 0.05f); //has an extremely strong effect on heavy tanks, high values will make them literally immovable
	
	this.set_f32("weight", 1.0f);
	
	this.set_f32("power", 0.0f);
	this.set_f32("powerFactor", 9.0f);
	this.set_u32("onTime", 0);
	this.set_u8("stallTime", 0);

	this.set_u8("seat icon", 1);
	this.set_string("seat label", "");
	this.set_u8("seat icon", 0);
	this.addCommandID("get in seat");

	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ propeller = sprite.addSpriteLayer( "propeller","RotatingWheel.png", 16,16 );
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

	sprite.SetEmitSound("RotatingWheel_Loop");
	sprite.SetEmitSoundVolume(0.5f);
	sprite.SetEmitSoundPaused(true);
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (this.getDistanceTo(caller) > 200
		|| this.getShape().getVars().customData <= 0
		|| this.getTeamNum() != caller.getTeamNum())
		return;

	CBitStream params;
	params.write_u32(getGameTime());
	CButton@ button = caller.CreateGenericButton(1, Vec2f_zero, this, ReverseRotate, "Reverse rotate");
	if (button !is null)
	{
		button.radius = 16.0f;
		button.enableRadius = 120.0f;
	}
}


void ReverseRotate(CBlob@ this, CBlob@ caller)
{
	if (!this.hasTag("reverse_rotate"))
	{
		this.Tag("reverse_rotate");
	}
	else
	{
		this.Untag("reverse_rotate");
	}
}