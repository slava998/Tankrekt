#include "AccurateSoundPlay.as";
const int FIRE_RATE = 10;

void onInit(CBlob@ this)
{	
	this.Tag("noEnemyEntry");
	this.set_string("seat label", "Look With Binoculars");
	this.set_u8("seat icon", 7);
	
	this.set_f32("weight", 2.5f);
	this.set_f32("gives_zoom", 0.3f);
	
	this.addCommandID("setPoint");

	this.set_u32("fire time", 0);
	this.set_Vec2f("point1", this.getPosition());
	this.set_Vec2f("point2", this.getPosition());

	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ layer = sprite.addSpriteLayer("weapon", "Binoculars.png", 16, 16);
    if (layer !is null)
    {
    	layer.SetRelativeZ(2);
    	layer.SetLighting(false);
    }
}

void onTick(CBlob@ this)
{
	const int col = this.getShape().getVars().customData;
	if (col <= 0) return; //not placed yet

	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	if (occupier !is null)
	{
		this.set_u16("parentID", 0);
		Manual(this, occupier);
	}
}

void Manual(CBlob@ this, CBlob@ controller)
{	
	Vec2f aimpos = controller.getAimPos();
	//print(aimpos.x + "|" + aimpos.y);
	Vec2f aimVec = aimpos - this.getPosition();

	// fire
	if (controller.isMyPlayer() && controller.isKeyPressed(key_action1) || controller.isKeyPressed(key_action2))
	{
		Use(this, aimpos, controller.isKeyPressed(key_action1));
	}

	// rotate turret
	Rotate(this, aimVec);
	aimVec.y *= -1;
	CSprite@ sprite = controller.getSprite();
	sprite.ResetTransform();
	sprite.RotateBy(aimVec.Angle() - controller.getAngleDegrees(), Vec2f_zero); //Rotate player sprite without rotating blob because otherwise rotation would be continious
}

void Use(CBlob@ this, Vec2f aimpos, bool key1)
{
	if(this.get_u32("fire time") + FIRE_RATE > getGameTime()) return;
	if(isClient())
	{
		CBitStream params;
		params.write_Vec2f(aimpos);
		params.write_bool(key1);
		this.SendCommand(this.getCommandID("setPoint"), params);
	}
	this.set_u32("fire time", getGameTime());
}

void Rotate(CBlob@ this, Vec2f&in aimVector)
{
	CSpriteLayer@ layer = this.getSprite().getSpriteLayer("weapon");
	if (layer !is null)
	{
		layer.ResetTransform();
		layer.RotateBy(-aimVector.getAngleDegrees() - this.getAngleDegrees(), Vec2f_zero);
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
    if (cmd == this.getCommandID("setPoint"))
    {
		if(this is null) return; //jsut in case
		
		const Vec2f pos = params.read_Vec2f();
		const bool key1 = params.read_bool();
		if(key1) this.set_Vec2f("point1", pos);
		else this.set_Vec2f("point2", pos);

		if (isClient())
		{
			directionalSoundPlay("setPoint" + (key1 ? 1 : 0) + ".ogg", this.getPosition(), 1);
		}
    }
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	if(detached is null) return;
	detached.getSprite().ResetTransform();
}


// Keeps an angle within the engine's boundaries (-740 to 740)
const f32 loopAngle(f32 angle)
{
	while (angle < 0.0f)	angle += 360.0f;
	while (angle > 360.0f)	angle -= 360.0f;
	return angle;
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	AttachmentPoint@ seat = blob.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	if (occupier is null) return;

	//visual
	GUI::SetFont("menu");
	const float zoom = getCamera().targetDistance;
	Vec2f offset = Vec2f(-6/zoom,-6/zoom) * zoom; //for some reason images are not located exactly where they must be
	Vec2f p1 = blob.get_Vec2f("point1");
	Vec2f p2 = blob.get_Vec2f("point2");
	Vec2f p1scr = getDriver().getScreenPosFromWorldPos(p1) + offset;
	Vec2f p2scr = getDriver().getScreenPosFromWorldPos(p2) + offset;
	GUI::DrawLine2D(p1scr, p2scr, SColor(255,255,0,0)); //line between the points
	GUI::DrawIconByName("$BINO_CROSS$", p1scr - Vec2f(29, 29)); //aim icon
	GUI::DrawIconByName("$BINO_CROSS$", p2scr - Vec2f(29, 29)); //aim icon

	Vec2f v = p2 - p1;
	const string text = Maths::Round((v.Length() / 8)) + " Blocks";
	GUI::DrawTextCentered(text, (p1scr + p2scr) / 2, SColor(255,255,0,0)); //length text
	
	f32 angle = loopAngle(-(v.Angle()) - 90);
	GUI::DrawText(Maths::Round(angle) + "°\n" + text, p1scr + Vec2f(0, 60).RotateBy(angle + 90), SColor(255,255,0,0)); //angle for p1
	const f32 camRot = getCamera().getRotation();
	//an ark that shows the angle
	for(int i = 0; i < (angle / 5.625f); i++)
	{
		GUI::DrawIconByName("$REDDOT$", p1scr + Vec2f(0, 30).RotateBy(i * 5.625f - camRot));
	}

	angle = loopAngle(-((-v).Angle()) - 90);
	GUI::DrawTextCentered(Maths::Round(angle) + "°\n" + text, p2scr + Vec2f(0, 60).RotateBy(angle + 90), SColor(255,255,0,0)); //angle for p2
	//an ark that shows the angle
	for(int i = 0; i < (angle / 5.625f); i++)
	{
		GUI::DrawIconByName("$REDDOT$", p2scr + Vec2f(0, 30).RotateBy(i * 5.625f - camRot));
	}
	GUI::SetFont("normal");
}