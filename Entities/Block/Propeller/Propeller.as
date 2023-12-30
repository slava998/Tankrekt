void onInit(CBlob@ this)
{
	this.Tag("propeller");
	this.Tag("solid");
	
	this.set_f32("weight", 1.0f);
	
	this.set_f32("power", 0.0f);
	this.set_f32("powerFactor", 1.0f);
	this.set_u32("onTime", 0);
	this.set_u8("stallTime", 0);

	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ propeller = sprite.addSpriteLayer("propeller");
	if (propeller !is null)
	{
		propeller.SetOffset(Vec2f(0,8));
		propeller.SetRelativeZ(2);
		propeller.SetLighting(false);
		Animation@ animcharge = propeller.addAnimation("go", 1, true);
		animcharge.AddFrame(3);
		animcharge.AddFrame(4);
		propeller.SetAnimation("go");
	}

	sprite.SetEmitSound("PropellerMotor");
	sprite.SetEmitSoundPaused(true);
}
