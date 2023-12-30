
void onInit(CBlob@ this)
{
	this.Tag("ram");
	this.Tag("solid");
	this.Tag("ramming");
	this.set_u8("gibType", 1);
	
	this.set_f32("weight", 2.0f);
}

Random _smokerandom(0x15125); //clientside
void onGib(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	CParticle@ p = ParticleAnimated("SmallSmoke2.png",
											  blob.getPosition(), Vec2f_zero,
											  _smokerandom.NextFloat() * 360.0f, //angle
											  1.5f, //scale
											  3+_smokerandom.NextRanged(2), //animtime
											  0.0f, //gravity
											  true); //selflit
	if (p !is null)
		p.Z = 640.0f;
}
