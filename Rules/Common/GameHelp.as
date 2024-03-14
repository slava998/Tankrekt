#define CLIENT_ONLY
#include "ActorHUDStartPos.as";
#include "ShiprektTranslation.as";

bool showHelp = true;
bool justJoined = true;
bool page1 = true;
bool mouseWasPressed1 = false;
bool shiprektUpdated = false;

const f32 boxMargin = 50.0f;
const SColor tipsColor = SColor(255, 255, 255, 255);
//key names
const string party_key = getControls().getActionKeyKeyName(AK_PARTY);
const string inv_key = getControls().getActionKeyKeyName(AK_INVENTORY);
const string pick_key = getControls().getActionKeyKeyName(AK_PICKUP);
const string taunts_key = getControls().getActionKeyKeyName(AK_TAUNTS);
const string use_key = getControls().getActionKeyKeyName(AK_USE);
const string action1_key = getControls().getActionKeyKeyName(AK_ACTION1);
const string action2_key = getControls().getActionKeyKeyName(AK_ACTION2);
const string action3_key = getControls().getActionKeyKeyName(AK_ACTION3);
const string map_key = getControls().getActionKeyKeyName(AK_MAP);
const string zoomIn_key = getControls().getActionKeyKeyName(AK_ZOOMIN);
const string zoomOut_key = getControls().getActionKeyKeyName(AK_ZOOMOUT);
const string eat_key = getControls().getActionKeyKeyName(AK_EAT);
const string FileName = "Shiprekt/Settings.cfg";

void onInit(CRules@ this)
{
	CFileImage@ image = CFileImage("GameHelp.png");
	const Vec2f imageSize = Vec2f(image.getWidth(), image.getHeight());
	AddIconToken("$HELP$", "GameHelp.png", imageSize, 0);
	
	if (!GUI::isFontLoaded("thick font"))
	{
		GUI::LoadFont("thick font", g_locale == "ru" ? "GUI/Fonts/Arial.ttf" : "GUI/Fonts/AveriaSerif-Bold.ttf", 30, true);
	}
	
	const u32 versionNum = parseInt(this.get_string("version").replace(".", ""));
	
	ConfigFile cfg = ConfigFile();
	if (!cfg.loadFile("../Cache/"+FileName))
	{
		warn("Creating settings config ../Cache/"+FileName);
		cfg.add_u32("version", versionNum);
		cfg.saveFile(FileName);
		if (versionNum == 1531)
			shiprektUpdated = true; //this line should be removed once we update away from 1.53.1
	}
	
	const u32 oldVersionNum = cfg.read_u32("version");
	if (oldVersionNum < versionNum)
	{
		cfg.add_u32("version", versionNum);
		cfg.saveFile(FileName);
		shiprektUpdated = true;
	}
}

void onTick(CRules@ this)
{
	CControls@ controls = getControls();
	if (controls.isKeyJustPressed(KEY_F1))
	{
		showHelp = !showHelp;
		u_showtutorial = showHelp;
		justJoined = false;
	}
	if (controls.isKeyJustPressed(KEY_LBUTTON))
		page1 = !page1;
}

//a work in progress
void onRender(CRules@ this)
{
	if (!showHelp) return;
	
	CPlayer@ player = getLocalPlayer();
	if (player is null) return;
	
	const f32 sMid = getScreenWidth()/2;
	const f32 sCenter = getScreenHeight()/2;
	const u32 gameTime = getGameTime();

	Vec2f imageSize;
	GUI::GetIconDimensions("$HELP$", imageSize);

	const string infoTitle = Trans::HowToPlay;
	const string textInfo = "- "+ Trans::Mothership+":\n" +
	"\nSorry, this will be written later :)\n\n\n\n\n\n\n\n";
	/*" * "+ Trans::GatherX    +"\n"+
	" * "+ Trans::EngineWeak +"\n\n"+
	"- " + Trans::Miniship   +":\n" +
	" * "+ Trans::YieldX     +"\n"+
	" * "+ Trans::Docking    +"\n\n"+
	"- " + Trans::OtherTips  +":\n"+
	" * "+ Trans::Leaderboard+"\n"+
	" * "+ Trans::BlockWeight;*/
	
	//Controls
	const string controlsTitle = Trans::Controls;
	const string controlsInfo = " [ " + inv_key + " ] "+ Trans::GetBlocks+"\n"+
	" [ " + action3_key + " ] "+ Trans::RotateBlocks+"\n"+
	" [ " + action1_key + " ] "+ Trans::slash+"\n"+
	" [ " + action2_key + " ] "+Trans::Hold+" "+ Trans::FireGun+"\n"+
	" [ MOUSE MIDDLE ]  "+ Trans::Hold+" "+Trans::PointEmote+"\n"+
	" [ " + zoomIn_key + " ], [ " + zoomOut_key + " ] "+ Trans::Zoom+"\n"+
	" [ " + party_key + " ] "+ Trans::AccessTools+"\n"+
	" [ " + map_key + " ] "+ Trans::ScaleCompass+"\n"+
	" [ " + eat_key + " ] "+ Trans::Hold+" "+Trans::Strafe+"\n"+
	" [ LCTRL ] "+Trans::RotateCamera+".";
	
	GUI::SetFont("menu");
	
	Vec2f infoSize;
	GUI::GetTextDimensions(infoTitle + textInfo, infoSize);
	Vec2f controlsSize;
	GUI::GetTextDimensions(controlsTitle + controlsInfo, controlsSize);

	const Vec2f tlBox = Vec2f(sMid - imageSize.x - boxMargin, Maths::Max(10.0f, sCenter - imageSize.y - infoSize.y/2 - controlsSize.y/2 - boxMargin));
	const Vec2f brBox = Vec2f(sMid + imageSize.x + boxMargin, sCenter + imageSize.y + infoSize.y/2 + controlsSize.y/2);
	
	//draw box
	GUI::DrawButtonPressed(tlBox, brBox);
	
	if (justJoined)
	{
		//welcome text
		const string intro = Trans::Welcome; //last editor
		
		Vec2f introSize;
		GUI::GetTextDimensions(intro, introSize);
		GUI::SetFont("normal");
		GUI::DrawTextCentered(intro, Vec2f(sMid, tlBox.y + 20), tipsColor);
	} 
	
	if (!justJoined || gameTime % 90 > 30)
	{
		//helptoggle
		const string helpToggle = ">> "+Trans::ChangePage+" <<";
		
		Vec2f toggleSize;
		GUI::GetTextDimensions(helpToggle, toggleSize);
		
		GUI::SetFont("menu");
		GUI::DrawTextCentered(helpToggle, Vec2f(sMid, tlBox.y + 40), tipsColor);
		if (page1)
			GUI::DrawTextCentered(helpToggle, Vec2f(sMid, tlBox.y + 2*imageSize.y + boxMargin + 25), tipsColor);
	}
	
	if (page1)
	{
		//PAGE 1
		const string shiprektVersion = "Tankrekt "+Trans::Version+" "+this.get_string("version")+"\n";
		const string lastChangesInfo = Trans::LastChanges+":\n"
		+ "- 07-02-2024\n"
		+ "  * Mod created, major changes:\n"
		+ "  * Tracks and wheels, wheels are good for light tanks,, while tracks are slow but good for heavy tanks\n"
		+ "  * Stone blocks, they are good for forts or very armored tanks\n"
		+ "  * All weapons got damage buff because of economy and balance changes\n"
		+ "  * Artillery is new weapon, deals huge damage in big area but explodes after destroying\n"
		+ "  * Small changes in sprites and remaked some blocks (patcher heals in area for example)\n";
		
		GUI::SetFont("menu");
		Vec2f lastChangesSize;
		GUI::GetTextDimensions(lastChangesInfo, lastChangesSize);
	
		const Vec2f tlBoxJustJoined = Vec2f(sMid - imageSize.x - boxMargin, Maths::Max(10.0f, sCenter - imageSize.y - lastChangesSize.y/2));
		
		GUI::SetFont("thick font");
		GUI::DrawText(shiprektVersion, Vec2f(sMid - imageSize.x, tlBoxJustJoined.y + 2*imageSize.y), tipsColor);
		
		if (shiprektUpdated)
		{
			Vec2f shiprektVersionSize;
			GUI::GetTextDimensions(shiprektVersion, shiprektVersionSize);
			GUI::DrawText("[UPDATE!]", Vec2f(sMid - imageSize.x + shiprektVersionSize.x + 10, tlBoxJustJoined.y + 2*imageSize.y), ConsoleColour::ERROR);
		}
		
		GUI::SetFont("menu");
		GUI::DrawText(lastChangesInfo, Vec2f(sMid - imageSize.x, tlBoxJustJoined.y + 2*imageSize.y + boxMargin), tipsColor);
		
		//image
		GUI::DrawIconByName("$HELP$", Vec2f(sMid - imageSize.x, tlBox.y + boxMargin + 10));
		
		//captions
		if (g_locale != "en")
		{
			GUI::SetFont("normal");
			Vec2f ImagePos(sMid - imageSize.x, tlBox.y + boxMargin + 10);
			GUI::DrawTextCentered(Trans::Caption1, ImagePos + Vec2f(150,230), tipsColor);
			GUI::DrawTextCentered(Trans::Caption2, ImagePos + Vec2f(150,400), tipsColor);
			GUI::DrawTextCentered(Trans::Caption3, ImagePos + Vec2f(550,190), tipsColor);
			GUI::DrawTextCentered(Trans::Caption4, ImagePos + Vec2f(340, 30), tipsColor);
		}
	}
	else
	{
		//PAGE 2
		
		GUI::SetFont("thick font");
		
		GUI::DrawText(infoTitle, Vec2f(tlBox.x + boxMargin, tlBox.y + boxMargin + 20), tipsColor);
		GUI::DrawText(controlsTitle, Vec2f(tlBox.x + boxMargin, tlBox.y + boxMargin + 240), tipsColor);
		
		GUI::SetFont("menu");
		GUI::DrawText(textInfo, Vec2f(tlBox.x + boxMargin, tlBox.y + boxMargin + 60), tipsColor);
		GUI::DrawText(controlsInfo, Vec2f(tlBox.x + boxMargin, tlBox.y + boxMargin + 280), tipsColor);
		
		if (!v_fastrender)
		{
			const string lagTip = "<> "+Trans::FastGraphics+" <>";
			GUI::DrawTextCentered(lagTip, Vec2f(sMid, tlBox.y + boxMargin *10), tipsColor);
		}
		
		if (player.isMod())
		{
			GUI::SetFont("thick font");
			const string RCONDetected = "Moderator status detected!";
			GUI::DrawText(RCONDetected, Vec2f(tlBox.x + boxMargin, tlBox.y + boxMargin * 11), tipsColor);
			
			GUI::SetFont("menu");
			const string modTools = "Tankrekt offers a variety of chat commands for testing and moderation purposes." +
									"\n\n Type ' !list ' in chat and then check the console to see what is available. (check cmd console on server)";
			GUI::DrawText(modTools, Vec2f(tlBox.x + boxMargin, tlBox.y + boxMargin * 12), tipsColor);
		}
	}
	
	GUI::SetFont("menu");
	
	//hud icons
	Vec2f tl = getActorHUDStartPosition(null, 6);
	
	CControls@ controls = getControls();
	if (getLocalPlayerBlob() !is null && (controls.getMouseScreenPos() - (tl + Vec2f(90, 125))).Length() > 200.0f)
	{
		GUI::DrawTextCentered("[ "+Trans::ClickIcons+" ]",  tl + Vec2f(90, -17 + Maths::Sin(gameTime/4.5f) * 2.5f), tipsColor);
	}
	
	//Add social links
	GUI::SetFont("menu");
	makeWebsiteLink(Vec2f(brBox.x, 100.0f), Trans::Go_to_the+" Tankrekt Github", "https://github.com/slava998/Tankrekt");
	makeWebsiteLink(Vec2f(brBox.x, 150.0f), Trans::Go_to_the+" Tankrekt Discord", "https://discord.gg/Mk4Kcrg5R5");
	
	mouseWasPressed1 = controls.mousePressed1; 
}

void makeWebsiteLink(Vec2f pos, const string&in text, const string&in website)
{
	Vec2f dim;
	GUI::GetTextDimensions(text, dim);

	const f32 width = dim.x + 20;
	const f32 height = 40;
	const Vec2f tl = Vec2f(getScreenWidth() - 10 - width - pos.x, pos.y);
	const Vec2f br = Vec2f(getScreenWidth() - 10 - pos.x, tl.y + height);

	CControls@ controls = getControls();
	const Vec2f mousePos = controls.getMouseScreenPos();

	const bool hover = (mousePos.x > tl.x && mousePos.x < br.x && mousePos.y > tl.y && mousePos.y < br.y);
	if (hover)
	{
		GUI::DrawButton(tl, br);

		if (controls.mousePressed1 && !mouseWasPressed1)
		{
			Sound::Play("option");
			OpenWebsite(website);
			showHelp = !showHelp;
		}
	}
	else
	{
		GUI::DrawPane(tl, br, 0xffcfcfcf);
	}

	GUI::DrawTextCentered(text, Vec2f(tl.x + (width * 0.50f), tl.y + (height * 0.50f)), 0xffffffff);
}

//failback for F1 key problems
bool onClientProcessChat(CRules@ this, const string &in textIn, string &out textOut, CPlayer@ player)
{
	if (player !is null && player.isMyPlayer() && textIn == "!help")
	{
		showHelp = !showHelp;
		justJoined = false;
	}
	
	return true;
}
