
void onInit(CBlob@ this)
{
    this.Tag("solid");
	this.Tag("weapon");
	
	this.set_f32("weight", 25.0f);
	
	const u8 num = this.get_u8("number");
	
	if(num < 2)
	{
		this.Tag("armor"); //absorbs explosion damage
		this.Tag("strong"); //its resists are equal to solids
	}
	else this.getShape().getConsts().collidable = false;
	if(this.hasTag("main_block"))
	{
		this.AddScript("GetInSeat.as");
		this.AddScript("FortressHowitzerMain.as");
		
		CSprite@ sprite = this.getSprite();
		if(sprite !is null)
			this.getSprite().AddScript("FortressHowitzerMain.as");
	}
}

