// GingerBeard @ 4/14/2022

void onInit(CBlob@ this)
{
	this.Tag("plank");
	this.Tag("solid");
	
	this.set_f32("weight", 0.7f);
	
	CShape@ shape = this.getShape();
	shape.AddPlatformDirection(Vec2f(0, -1), 89, false);
	this.getSprite().SetRelativeZ(2);
}
