#define CLIENT_ONLY

//health & reclaim rendering

void onInit(CSprite@ this)
{
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;
	 
	CBlob@ mBlob = getMap().getBlobAtPosition(blob.getAimPos());
	if (mBlob !is null && mBlob.getShape().getVars().customData > 0 && !mBlob.hasTag("noRenderHealth") && 
	   (blob.get_string("current tool") == "deconstructor" || blob.get_string("current tool") == "reconstructor"))
	{
		mBlob.RenderForHUD(RenderStyle::outline_front);
		const Vec2f pos2d = mBlob.getInterpolatedScreenPos() + Vec2f(0, -50);
		const Vec2f dim = Vec2f(24,8);
		const f32 y = mBlob.getHeight()*2.4f;
		const Vec2f tl = Vec2f(pos2d.x - dim.x+2, pos2d.y + y+2);
		const f32 initialHealth = mBlob.getInitialHealth();
		
		const f32 health = mBlob.getHealth() / initialHealth;
		if (health > 0.0f)
		{
			GUI::DrawRectangle(Vec2f(pos2d.x - dim.x-2, pos2d.y + y-2), Vec2f(pos2d.x +dim.x+2, pos2d.y + y + dim.y+2));
			GUI::DrawRectangle(tl, Vec2f(pos2d.x - dim.x + health*2.0f*dim.x -2, pos2d.y + y + dim.y-2), SColor(0xffac1512));
		}

		const f32 reclaim = mBlob.get_f32("current reclaim") / initialHealth;
		if (reclaim > 0.0f)
		{
			GUI::DrawRectangle(tl, Vec2f(pos2d.x - dim.x + reclaim*2.0f*dim.x -2, pos2d.y + y + dim.y-2), SColor(255, 36, 177, 53));
		}
	}
}