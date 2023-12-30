//render respawn timer
#include "ShiprektTranslation.as";

void onInit(CRules@ this)
{
	this.addCommandID("sync respawn time");
}

void onRender(CRules@ this)
{
	if (this.isIntermission() || this.isGameOver()) return;
	
	CPlayer@ player = getLocalPlayer();
	if (player is null) return;
	
	CBlob@ localBlob = getLocalPlayerBlob();
	if (localBlob !is null) return;

	const s32 time = this.get_u32("respawn time"); // changed from u to s to not overflow
	const s32 time_left = (time - getGameTime())/getTicksASecond();
	
	if (!g_videorecording && player.getTeamNum() != this.getSpectatorTeamNum())
	{
		GUI::SetFont("menu");
		string text;
		if (time_left == 0) text = Trans::Respawn;
		else if (time_left < 0) text = Trans::RespawnSoon;
		else text = getTranslatedString("Respawning in: {SEC}").replace("{SEC}", "" + time_left);

		Vec2f pos = Vec2f(getScreenWidth()/2, 200 + Maths::Cos(getGameTime()/10.0f)*8);
		Vec2f size = Vec2f_zero;
		GUI::GetTextDimensions(text, size);
		pos -= size/2;
		GUI::DrawSunkenPane(pos-Vec2f(8,8), pos+size+Vec2f(12,8));
		GUI::DrawText(text, pos, SColor(0xFFE0BA16));
	}
}

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
	if (isClient() && cmd == this.getCommandID("sync respawn time"))
	{
		const u32 time = params.read_u32();
		this.set_u32("respawn time", time);
	}
}
