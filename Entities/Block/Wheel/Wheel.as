void onInit(CBlob@ this)
{
	this.Tag("propeller");
	this.Tag("solid");
	this.Tag("wheel");
	this.Tag("landMotor");
	this.Tag("ramengine");
	this.Tag("ramming");
	this.set_f32("mass_coef", 0.05f); //has an extremely strong effect on heavy tanks, high values will make them literally immovable
	
	this.set_f32("weight", 1.0f);
	
	this.set_f32("power", 0.0f);
	this.set_f32("powerFactor", 10.0f);
	this.set_u32("onTime", 0);
	this.set_u8("stallTime", 0);

	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ propeller = sprite.addSpriteLayer( "propeller","Wheel.png", 8,8 );
	if(propeller !is null)
	{
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

	sprite.SetEmitSound("TankMovement");
	sprite.SetEmitSoundVolume(0.5f);
	sprite.SetEmitSoundPaused(true);
}
