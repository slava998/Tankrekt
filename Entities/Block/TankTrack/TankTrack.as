void onInit(CBlob@ this)
{
	this.Tag("propeller");
	this.Tag("solid");
	this.Tag("landMotor");
	this.Tag("crush people");
	this.Tag("engine");
	
	this.set_f32("weight", 1.0f);
	
	this.set_f32("power", 0.0f);
	this.set_f32("rot_angle", 0.0f);
	this.set_f32("powerFactor", 3.0f);
	this.set_u32("onTime", 0);
	this.set_u8("stallTime", 0);

	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ propeller = sprite.addSpriteLayer( "propeller","TankTrackCaterpillars.png", 8,8 );
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
	sprite.SetEmitSoundPaused(true);
}