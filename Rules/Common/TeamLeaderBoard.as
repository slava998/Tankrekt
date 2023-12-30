#define CLIENT_ONLY
#include "TeamColour.as";
#include "ShiprektTranslation";

f32 lineHeight = 17.5f;
f32 panelWidth = 155.0f;
u16[] boardBooty = {0};
u8[] boardTeams = {0};

void onTick(CRules@ this)
{
	if (getGameTime() % 30 != 0) return;
	
	boardBooty.clear();
	CBlob@[] cores;
	getBlobsByTag("mothership", @cores);
	const u8 coresLength = cores.length;
	for (u8 i = 0; i < coresLength; i++)
	{
		boardBooty.push_back(this.get_u16("bootyTeam_total" + cores[i].getTeamNum()));
	}

	boardBooty.sortDesc();
	boardTeams.clear();
	
	const u8 bootyLength = boardBooty.length;
	for (u8 b = 0; b < bootyLength; b++)
	{
		for (u8 i = 0; i < coresLength; i++)
		{
			u8 coreTeamNum = cores[i].getTeamNum();
			if (boardBooty[b] == this.get_u16("bootyTeam_total" + coreTeamNum) && boardTeams.find(coreTeamNum) == -1)
				boardTeams.push_back(coreTeamNum);
		}
	}
}

void onRender(CRules@ this)
{
	if (g_videorecording || !isClient())
		return;
	
	Vec2f mousePos = getControls().getMouseScreenPos();
	Vec2f panelCenter = Vec2f(getScreenWidth() - panelWidth/2, 75);
	if ((mousePos - panelCenter).Length() < panelWidth/2)
		return;
	
	//Draw
	Vec2f panelStart = Vec2f(getScreenWidth() - panelWidth - 5, 15);
	GUI::SetFont("menu");

	//background
	GUI::DrawButtonPressed(panelStart - Vec2f(10, 10), panelStart + Vec2f(panelWidth, 10 + lineHeight * (boardTeams.length + 1)));
	
	//teams column
	const string header = Trans::Total+" "+Trans::Booty;
	Vec2f size;
	GUI::GetTextDimensions(header, size);
	GUI::DrawText(header, panelStart + Vec2f((panelWidth - size.x)/2 - 6, 0), SColor(255, 255, 255, 255));
	
	const u8 teamsLength = boardTeams.length;
	for (u8 i = 0; i < teamsLength; i++)
	{
		GUI::DrawText(teamColors[boardTeams[i]]+" "+Trans::Team, panelStart + Vec2f(0, (i+1)*lineHeight), getTeamColor(boardTeams[i]));
	}
	
	//booty column
	const u8 bootyLength = boardBooty.length;
	for (u8 i = 0; i < bootyLength; i++)
	{
		GUI::DrawText("" + Maths::Round(boardBooty[i]/10) * 10, panelStart + Vec2f(103, (i+1)*lineHeight), SColor(255, 255, 255, 255));
	}
}
