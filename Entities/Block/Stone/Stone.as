
void onInit(CBlob@ this)
{
	this.Tag("hull");
	this.Tag("armor"); //absorbs explosion damage
    this.Tag("solid");
	this.Tag("stone");
	
	this.set_f32("weight", 12.0f);
}
