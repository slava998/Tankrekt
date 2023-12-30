// Gingerbeard @ 3/2/2022

#define CLIENT_ONLY
#include "ShiprektTranslation.as";

//global ok since myplayer
bool showTip;
int tipIndex = 0;
u32 SHOW_FREQUENCY = 3 * 60 * 30;

void onTick(CRules@ this)
{	
	if (getLocalPlayer() is null) return;

	if (showTip)
	{
		s32 time_left = (this.get_u32("respawn time") + 30 - getGameTime())/getTicksASecond();
		if (time_left == 0) showTip = false;
		
		CControls@ controls = getControls();
		if (controls.isKeyJustPressed(controls.getActionKeyKey(AK_ACTION3)))
		{
			tipIndex = XORRandom(shiprektTips.length);
			Sound::Play("LoadingTick2.ogg");
		}
	}
	
	//if (getGameTime() % SHOW_FREQUENCY == 0 && shiprektTips.length > 0)
		//client_AddToChat(">TIP: " + shiprektTips[XORRandom(shiprektTips.length)]);
}

void onRender(CRules@ this)
{
	if (g_videorecording || !showTip || this.isGameOver()) return;
	
	GUI::SetFont("menu");
	
	const s16 scrw = getScreenWidth();
	const s16 scrh = getScreenHeight();
	
	const string tip = getTranslatedString("Tip: {TIP}").replace("{TIP}", shiprektTips[tipIndex]);
	
	const s16 w = Maths::Min(800, scrw - 40);
	const s16 h = (tip.length > (g_locale == "ru" ? 183 : 108) ? 50 : 40);

	const s16 offset = 160;

	Vec2f tl(scrw / 2 - w / 2, scrh - h - offset);
	Vec2f br(scrw / 2 + w / 2, scrh - offset);

	GUI::DrawButton(tl, br);
	GUI::DrawText(tip, tl + Vec2f(10, 10), br - Vec2f(10, 10), color_white, true, true, false);
	
	Vec2f shuffleTipPos(scrw / 2, br.y + 30);
	const string findNewTip = Trans::FindNewTip.replace("{key}", ""+getControls().getActionKeyKeyName(AK_ACTION3));
	GUI::DrawButton(shuffleTipPos + Vec2f(-findNewTip.length * 3.7f, -15), shuffleTipPos - Vec2f(-findNewTip.length * 3.7f, -15));
	GUI::DrawTextCentered(findNewTip, shuffleTipPos, color_white);
}

void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ attacker, u8 customData)
{
	if (victim.isMyPlayer())
	{
		tipIndex = XORRandom(shiprektTips.length);
		showTip = true;
	}
}

void onPlayerChangedTeam(CRules@ this, CPlayer@ player, u8 oldteam, u8 newteam)
{
	if (player.isMyPlayer() && newteam == this.getSpectatorTeamNum())
		showTip = false;
}
