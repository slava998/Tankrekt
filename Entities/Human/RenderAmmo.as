#define CLIENT_ONLY

//ammo rendering

void onInit(CSprite@ this)
{
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	GUI::SetFont("none");

	CBlob@[] list;
	if(getMap().getBlobsInRadius(blob.getAimPos(), 8, @list))
	{
		for(uint i = 0; i < list.length; i++)
		{
			CBlob@ b = list[i];
			if (b !is null && b.hasTag("usesAmmo") && b.getShape().getVars().customData > 0 && b.getTeamNum() == blob.getTeamNum())
			{
				Vec2f screenPos = b.getInterpolatedScreenPos();
				screenPos.y -= 20.0f;
				string text = "" + b.get_u16("ammo");
				Vec2f textSize;
				GUI::GetTextDimensions(text, textSize);
				textSize *= 0.5f;
				GUI::DrawRectangle(screenPos - textSize-Vec2f(2,2), screenPos + textSize+Vec2f(8,4)); 
				GUI::DrawTextCentered(text, screenPos, color_white);  
			}
		}
	}

	GUI::SetFont("menu");
}
