void onInit(CBlob@ this)
{
	this.set_f32("weight", 1.0f);
	this.Tag("solid");
	if(this.hasTag("main_block"))
	{
		this.AddScript("RocketFactory.as");
		CSprite@ sprite = this.getSprite();
		if(sprite !is null)
			this.getSprite().AddScript("RocketFactory.as");
	}
}