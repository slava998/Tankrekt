// tree logic
void onInit(CBlob@ this)
{
	this.setAngleDegrees(XORRandom(361));
	this.getShape().SetStatic(true);
}

void onInit(CSprite@ this)
{
	this.SetZ(550.0f);
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	damage = 0.5f;
	return damage;
}
