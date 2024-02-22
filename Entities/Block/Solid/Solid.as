
void onInit(CBlob@ this)
{
	this.Tag("hull");
	this.Tag("armor"); //absorbs explosion damage
    this.Tag("solid");
	
	this.set_f32("weight", 0.75f);
}
