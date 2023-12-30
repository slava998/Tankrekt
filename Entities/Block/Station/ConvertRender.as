//Gingerbeard @ 3/27/2022
#include "TeamColour.as";

void onRender(CSprite@ this)
{
	if (g_videorecording) return;
	
	CCamera@ camera = getCamera();
	if (camera is null) return;
	
	CBlob@ blob = this.getBlob();
	const u8 convertTime = blob.get_u8("convertTime");
	if (convertTime >= blob.get_u8("capture time")) return;
	
	const f32 camFactor = camera.targetDistance;
	Vec2f pos2d = getDriver().getScreenPosFromWorldPos(blob.getPosition());

	const f32 hwidth = 50 * camFactor;
	const f32 hheight = 10 * camFactor;

	pos2d.y -= 40 * camFactor;
	const f32 padding = 4.0f * camFactor;
	const f32 shift = 15.0f;
	const f32 progress = (1.1f - f32(convertTime) / f32(blob.get_u8("capture time")))*(hwidth*2-(13* camFactor)); //13 is a magic number used to perfectly align progress
	
	GUI::DrawPane(Vec2f(pos2d.x - hwidth + padding, pos2d.y + hheight - shift - padding),
			  Vec2f(pos2d.x + hwidth - padding, pos2d.y + hheight - padding),
			  SColor(175,200,207,197)); //draw capture bar background
	
	if (progress >= f32(8)) //draw progress if capture can start
	{
		GUI::DrawPane(Vec2f(pos2d.x - hwidth + padding, pos2d.y + hheight - shift - padding),
					  Vec2f((pos2d.x - hwidth + padding) + progress, pos2d.y + hheight - padding),
				  getTeamColor(blob.get_u8("convertTeam"))); //SColor(175,200,207,197)
	}
}
