void onInit(CBlob@ this)
{
	this.sendonlyvisible = false; //clients always know this blob's position

	this.Tag("decoyCore");
	this.Tag("core");
	
	this.set_f32("weight", 6.0f);

	if (isClient())
	{
		//add an additional frame to the damage frames animation
		Animation@ animation = this.getSprite().getAnimation("default");
		if (animation !is null)
		{
			int[] frames = {3};
			animation.AddFrames(frames);
		}
	}
}
