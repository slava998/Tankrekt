#define CLIENT_ONLY
#include "EasyUI.as"
#include "ShiprektTranslation.as";

//Slava 16.06.2024
//I think we have to start signing and dating code

EasyUI@ ui;
Stack@ stack;

void onTick(CBlob@ this)
{
	if(!this.get_bool("placed"))  //A crutch: there is bugs when this called right after blob creating
	{
		if(getGameTime() - this.get_u32("placedTime") == 2 && this.getShape().getVars().customData > 0)
		{
			this.set_bool("running", true);
			Init(this);
			this.set_bool("running", false);
		}
	}
    if(ui is null || !this.get_bool("running")) return;
	CBlob@ blob = this; //FIXTHIS
	if(blob is null || !blob.get_bool("running") || ui is null) return;
	CPlayer@ localPly = getLocalPlayer();
	AttachmentPoint@ seat = blob.getAttachmentPoint(0);
	CPlayer@ occupier = seat.getOccupied().getPlayer();
	if(localPly is null || occupier is null || localPly !is occupier) return;
	ui.Update();
}

void Init(CBlob@ this)
{

	@ui = EasyUI();

    @stack = StandardStack();
    stack.SetMargin(30, 30);
    stack.SetAlignment(0, 1);
    stack.SetMinSize(600, 400);
	stack.SetMaxSize(600, 400);
	ui.AddComponent(stack);
	
	Button@ button = StandardButton(ui);
    button.SetAlignment(0.5f, 0.5f);
    button.SetStretchRatio(0.2f, 0.2f);
	stack.AddComponent(button);
	
	Label@ button_label1 = StandardLabel();
	button_label1.SetText(Trans::SetArtilleryParams);
	button_label1.SetAlignment(0.5f, 0.5f);
	button.AddComponent(button_label1);
	
	Button@ button2 = StandardButton(ui);
    button2.SetAlignment(0.5f, 0);
    button2.SetStretchRatio(0.2f, 0.2f);
	stack.AddComponent(button2);
	
	Label@ button_label2 = StandardLabel();
	button_label2.SetText(Trans::Fire);
	button_label2.SetAlignment(0.5f, 0.5f);
	button2.AddComponent(button_label2);
	
	Slider@ range = StandardVerticalSlider(ui);
	range.SetAlignment(0, 0);
    //range.SetStretchRatio(0.2f, 0.75f);
	range.SetMinSize(112, 270);
	range.SetMaxSize(112, 270);
	stack.AddComponent(range);
	
	Label@ label1 = StandardLabel();
	label1.SetAlignment(0.5f, 0.5f);
	range.AddComponent(label1);
	
	Slider@ angle = StandardHorizontalSlider(ui);
    angle.SetAlignment(0, 1);
    //angle.SetStretchRatio(1, 0.25f);
	angle.SetMinSize(560, 90);
	angle.SetMaxSize(560, 90);
	stack.AddComponent(angle);
	
	Label@ label2 = StandardLabel();
	label2.SetAlignment(0.5f, 0.5f);
	angle.AddComponent(label2);

	button.AddEventListener(Event::Press, ParamsButtonHandler(this, range, angle));
	button2.AddEventListener(Event::Press, FireButtonHandler(this));
	
	Icon@ img = StandardIcon();
    img.SetTexture("artillery_control_gui");
    img.SetMinSize(600, 400);
	img.SetMaxSize(600, 400);
	img.SetFrameDim(600, 400);
	img.SetFrameIndex(0);
	stack.AddComponent(img);
	
	Pane@ pane = StandardPane();
	pane.SetAlignment(1, 0);
    pane.SetMinSize(181, 240);
	pane.SetMaxSize(181, 240);
	pane.SetPadding(10,10);
	stack.AddComponent(pane);
	
	Label@ label = StandardLabel();
	label.SetText(Trans::Arty_help);
	label.SetWrap(true);
	label.SetMinSize(181, 240);
	pane.AddComponent(label);
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	if(blob is null || !blob.get_bool("running") || ui is null) return;
	CPlayer@ localPly = getLocalPlayer();
	AttachmentPoint@ seat = blob.getAttachmentPoint(0);
	CPlayer@ occupier = seat.getOccupied().getPlayer();
	if(localPly is null || occupier is null || localPly !is occupier) return;

	Component@[] comps = stack.getComponents();
	Slider@ range = cast<Slider@>(comps[2]);
	if(range !is null)
	{
		Label@ label1 = cast<Label@>(range.getComponents()[0]);
		if(label1 !is null)
		{
			label1.SetText(Trans::Firing_range + ":\n\n" + Maths::Round((1 - range.getPercentage()) * 143) + " blocks");
		}
	}
	Slider@ angle = cast<Slider@>(comps[3]);
	if(angle !is null)
	{
		Label@ label2 = cast<Label@>(angle.getComponents()[0]);
		if(label2 !is null)
		{
			label2.SetText(Trans::Angle + ":\n\n" + Maths::Round(angle.getPercentage() * 360) + "°");
		}
	}
    ui.Render();
	
	//Display angle

	if (!GUI::isFontLoaded("thick font"))
	{
		GUI::LoadFont("thick font", g_locale == "ru" ? "GUI/Fonts/Arial.ttf" : "GUI/Fonts/AveriaSerif-Bold.ttf", 30, true);
	}
	GUI::SetFont("thick font");
	const f32 rotation = Maths::Round(loopAngle(loopAngle(-blob.get_f32("rot_angle")) - 90 + blob.getAngleDegrees()));
	GUI::DrawTextCentered(rotation + "°", Vec2f(getScreenWidth() / 2, getScreenHeight() * 0.75), SColor(255,255,255,255));
	GUI::SetFont("normal");
}

class ParamsButtonHandler : EventHandler
{
	private Slider@ range;
	private Slider@ angle;
	private int blobID;
	
    ParamsButtonHandler(CBlob@ blob, Slider@ range, Slider@ angle)
    {
		@this.range = @range;
		@this.angle = @angle;
		this.blobID = blob.getNetworkID();
    }

    void Handle()
    {
		CBlob@ blob = getBlobByNetworkID(blobID);
		if(range is null || angle is null || blob is null) return;
		CBitStream params;
		params.write_f32((1 - range.getPercentage()) * 143);
		params.write_f32(loopAngle(loopAngle((-angle.getPercentage())) * 360 - 180 + blob.getAngleDegrees()));
        blob.SendCommand(blob.getCommandID("setParams"), params);
    }
}

// Keeps an angle within the engine's boundaries (-740 to 740)
const f32 loopAngle(f32 angle)
{
	while (angle < 0.0f)	angle += 360.0f;
	while (angle > 360.0f)	angle -= 360.0f;
	return angle;
}

class FireButtonHandler : EventHandler
{
	private int blobID;
	
    FireButtonHandler(CBlob@ blob)
    {
		this.blobID = blob.getNetworkID();
    }

    void Handle()
    {
		CBlob@ blob = getBlobByNetworkID(blobID);
		if (blob is null) return;
		AttachmentPoint@ seat = blob.getAttachmentPoint(0);
		CBlob@ occupier = seat.getOccupied();
		if (occupier is null) return;
	
		CBitStream params;
		params.write_netid(occupier.getNetworkID());
        blob.SendCommand(blob.getCommandID("fire"), params);
    }
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	if(detached !is null && detached.hasTag("player"))
	{
		this.set_bool("running", false);
		if(ui !is null) ui.RemoveComponent(stack);
	}
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint)
{
	if(attached !is null && attached.hasTag("player"))
	{
		this.set_bool("running", true);
		Init(this);
		Component@[] comps = stack.getComponents();
		Slider@ range = cast<Slider@>(comps[2]);
		Slider@ angle = cast<Slider@>(comps[3]);
		if(range !is null) range.SetPercentage(1 - this.get_f32("range") / 143);
		if(angle !is null)angle.SetPercentage(loopAngle(loopAngle(-this.get_f32("target_angle")) - 90 + this.getAngleDegrees()) / 360);
	}
}