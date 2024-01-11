#include "HumanCommon.as";
#include "WaterEffects.as";
#include "ShipsCommon.as";
#include "Booty.as";
#include "AccurateSoundPlay.as";
#include "TileCommon.as";
#include "Hitters.as";
#include "ParticleSpark.as";
#include "ParticleHeal.as";
#include "BlockCosts.as";
#include "ShiprektTranslation.as";
#include "PlankCommon.as";
#include "WeaponCommon.as";
#include "GunStandard.as";
#include "DamageBooty.as";
#include "BlockProduction.as";
#include "Ships.as";
#include "Knocked.as"

const int CONSTRUCT_RANGE = 48;
const f32 MOTHERSHIP_CREW_HEAL = 0.1f;
const u16 MOTHERSHIP_HEAL_COST = 10;
const f32 BULLET_SPREAD = 0.0f;
const Vec2f BUILD_MENU_SIZE = Vec2f(8, 5);
const Vec2f BUILD_MENU_TEST = Vec2f(8, 4); //for testing, only activates when sv_test is on
const Vec2f TOOLS_MENU_SIZE = Vec2f(2, 6);

//global is fine since only used with isMyPlayer
int useClickTime = 0;
bool buildMenuOpen = false;
u16 stayBlobID = 0;
u8 stayCount = 0;

BootyRewards@ booty_reward;

Random _shotspreadrandom(0x11598);

void onInit(CBlob@ this)
{
	this.sendonlyvisible = false; //clients always know this blob's position

	this.Tag("player");
	this.addCommandID("get out");
	this.addCommandID("shoot");
	this.addCommandID("construct");
	this.addCommandID("punch");
	this.addCommandID("giveBooty");
	this.addCommandID("releaseOwnership");
	this.addCommandID("swap tool");
	this.addCommandID("run over");
	this.addCommandID("fire");
	this.addCommandID("makeBlockWithNoBase");

	this.set_u8("TTL", 15); //bullet params
	this.set_u8("speed", 28);

	this.chatBubbleOffset = Vec2f(0.0f, 10.0f);
	this.getShape().getVars().onground = true;
	
	this.SetMapEdgeFlags(u8(CBlob::map_collide_up | CBlob::map_collide_down | CBlob::map_collide_sides));
	
	this.set_bool("justMenuClicked", false); //placement won't happen immediately after clicking on block menu
	this.set_bool("getting block", false); //grabbing another block
	this.set_bool("onGround", true); //client to server isOnGround()
	this.set_string("last buy", "coupling"); //last bought block
	this.set_string("current tool", "pistol"); //tool the player is using
	this.set_u32("fire time", 0); //gametime when pistol or constructor was last used
	this.set_u32("punch time", 0); //gametime at last punch
	this.set_f32("camera rotation", 0); //the player's camera rotation synced for all clients
	
	CBlob@ core = getMothership(this.getTeamNum());
	if (core !is null && this.getPlayer() !is null) 
	{
		this.set_u16("shipBlobID", core.getNetworkID());
		if (this.isMyPlayer())
		{
			stayBlobID = core.getNetworkID();
			stayCount = 3;
		}
	}
	
	setKnockable(this);
	
	if (booty_reward is null)
	{
		BootyRewards _booty_reward;
		_booty_reward.addTagReward("bomb", 5);
		_booty_reward.addTagReward("engine", 5);
		_booty_reward.addTagReward("mothership", 10);
		_booty_reward.addTagReward("secondarycore", 8);
		_booty_reward.addTagReward("weapon", 8);
		@booty_reward = _booty_reward;
	}
	
	if (isClient())
	{
		CSprite@ sprite = this.getSprite();
		sprite.SetEmitSound("/ReclaimSound.ogg");
		sprite.SetEmitSoundVolume(0.5f);
		sprite.SetEmitSoundPaused(true);
		
		directionalSoundPlay("Respawn", this.getPosition(), 2.5f);
	}
}

void onTick(CBlob@ this)
{
	Move(this);
	
	DoKnockedUpdate(this);

	if (this.isMyPlayer())
	{
		PlayerControls(this);
	}

	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ laser = sprite.getSpriteLayer("laser");
	
	// stop reclaim effects
	if (this.isKeyJustReleased(key_action2) || (!this.isKeyPressed(key_action2) && laser !is null ? laser.isVisible() : false))
	{
		EndConstructEffects(this, sprite);
	}
}

// Move the player
void Move(CBlob@ this)
{
	CRules@ rules = getRules();
	const u32 gameTime = getGameTime();
	const bool blobInitialized = this.getTickSinceCreated() > 15; //solves some strange problems
	const bool myPlayer = this.isMyPlayer();
	const bool isBot = isServer() && this.getPlayer() !is null && this.getPlayer().isBot();
	const Vec2f pos = this.getPosition();
	Vec2f aimpos = this.getAimPos();
	Vec2f forward = aimpos - pos;
	CShape@ shape = this.getShape();
	CSprite@ sprite = this.getSprite();
	
	ShipDictionary@ ShipSet = getShipSet(rules);
	
	CBlob@ shipBlob = null;
	if (!this.isAttached())
	{
		CBlob@[] blobsInRadius;
		getMap().getBlobsInRadius(pos, 1.0f, @blobsInRadius);
		
		f32 mDist = 9999.0f;
		const u8 blobsLength = blobsInRadius.length;
		for (u8 i = 0; i < blobsLength; i++)
		{
			CBlob@ blob = blobsInRadius[i];
			if (blob.getShape().getVars().customData <= 0) continue;
			
			const f32 dist = (blob.getPosition() - pos).Length();
			if (dist < mDist)
			{
				@shipBlob = blob;
				mDist = dist;
			}
		}
	}
	else
	{
		//reference the seat we are in
		CBlob@ occupier = this.getAttachmentPoint(0).getOccupied();
		if (occupier !is null) @shipBlob = occupier;
		
		shape.getVars().onground = true;
		this.set_bool("onGround", true);
	}
	
	this.set_u16("shipBlobID", shipBlob !is null ? shipBlob.getNetworkID() : 0);
	
	Ship@ ship = shipBlob !is null ? ShipSet.getShip(shipBlob.getShape().getVars().customData) : null;
	this.set_s32("shipID", ship !is null ? ship.id : 0);
	
	if (!this.isAttached())
	{
		const f32 camRotation = myPlayer ? getCamera().getRotation() : this.get_f32("camera rotation");
		
		const bool up = this.isKeyPressed(key_up);
		const bool down = this.isKeyPressed(key_down);
		const bool left = this.isKeyPressed(key_left);
		const bool right = this.isKeyPressed(key_right);	
		const bool punch = this.isKeyPressed(key_action1);
		const bool shoot = this.isKeyPressed(key_action2);
		
		shape.getVars().onground = ship !is null || isTouchingLand(pos);
		
		// artificial stay on ship
		if (myPlayer)
		{
			if (shipBlob !is null && ship !is null)
			{
				stayBlobID = shipBlob.getNetworkID();
				stayCount = Maths::Max(stayCount, Maths::Max(3, Maths::Floor(ship.vel.Length())));
			}
			else
			{
				CBlob@ stayBlob = getBlobByNetworkID(stayBlobID);
				if (stayBlob !is null && !stayBlob.hasTag("solid"))
				{
					stayCount = Maths::Max(0, stayCount-1);
					if (stayCount == 0) stayBlobID = 0;
					
					if ((!up && !left && !right && !down))
					{
						Ship@ stayShip = ShipSet.getShip(stayBlob.getShape().getVars().customData);
						if (stayShip !is null && stayShip.vel.Length() > 3.3f)
						{
							this.setPosition(stayBlob.getPosition() + stayShip.vel);
							this.set_u16("shipBlobID", stayBlobID);
							this.set_s32("shipID", stayShip.id);
							shape.getVars().onground = true;
						}
					}
				}
			}
		}
		
		if (myPlayer || isBot)
		{
			//isOnGround from client's perspective
			if (this.get_bool("onGround") != this.isOnGround() && blobInitialized)
			{
				this.set_bool("onGround", this.isOnGround());
				this.Sync("onGround", false); //1954602763 HASH
			}
		}

		// move
		Vec2f moveVel = Vec2f(0,0);
		
		if(this.get_u8("knocked") <= 0)
		{
			if (up)
			{
				moveVel.y -= Human::walkSpeed;
			}
			else if (down)
			{
				moveVel.y += Human::walkSpeed;
			}
			
			if (left)
			{
				moveVel.x -= Human::walkSpeed;
			}
			else if (right)
			{
				moveVel.x += Human::walkSpeed;
			}
		}

		if (!this.get_bool("onGround"))
		{
			moveVel *= isTouchingShoal(pos) ? 0.8f : Human::swimSlow;
			
			if (isClient())
			{
				const u8 tickStep = v_fastrender ? 15 : 5;

				if ((gameTime + this.getNetworkID()) % tickStep == 0)
					MakeWaterParticle(pos, Vec2f()); 

				if (this.wasOnGround() && gameTime - this.get_u32("lastSplash") > 45)
				{
					directionalSoundPlay("SplashFast", pos);
					this.set_u32("lastSplash", gameTime);
				}
			}
		}
		else if(this.get_u8("knocked") <= 0)
		{
			// punch
			if (isClient() && punch && !Human::isHoldingBlocks(this) && canPunch(this))
			{
				EndConstructEffects(this, sprite);
				Punch(this);
			}
			
			//when on our mothership
			if (ship !is null && ship.isMothership)
			{
				CBlob@ thisCore = getMothership(this.getTeamNum(), rules);
				if (thisCore !is null && thisCore.getShape().getVars().customData == ship.id)
				{
					moveVel *= 1.35f; //speedup on own mothership
					
					if (isServer() && gameTime % 60 == 0 && !thisCore.hasTag("critical")) //heal on own mothership
					{
						this.server_Heal(MOTHERSHIP_CREW_HEAL);
					}
				}
			}
		}
		
		//tool actions
		if (shoot && !punch)
		{
			const string currentTool = this.get_string("current tool");
			
			if (currentTool == "pistol" && canShootPistol(this)) // shoot
			{
				ShootPistol(this);
				if (!sprite.isAnimation("shoot"))
					sprite.SetAnimation("shoot");
			}
			else if (currentTool == "deconstructor" || currentTool == "reconstructor") //reclaim, repair
			{
				Construct(this);
			}
		}

		//canmove check
		if (this.get_bool("onGround") || !rules.get_bool("whirlpool"))
		{
			moveVel.RotateBy(camRotation);
			this.setVelocity(moveVel);
		}

		// face

		f32 angle = camRotation;
		forward.Normalize();
		
		if (!sprite.isAnimation("walk") && !sprite.isAnimation("swim"))
			angle = -forward.Angle();
		else
		{
			if (up && left) angle += 225;
			else if (up && right) angle += 315;
			else if (down && left) angle += 135;
			else if (down && right) angle += 45;
			else if (up) angle += 270;
			else if (down) angle += 90;
			else if (left) angle += 180;
			else if (right) angle += 0;
			else angle = -forward.Angle();
		}
		
		while(angle > 360) angle -= 360;
		while(angle < 0)   angle += 360;

		shape.SetAngleDegrees(angle);
	}
}

// Controllable abilities
void PlayerControls(CBlob@ this)
{
	CHUD@ hud = getHUD();
	CControls@ controls = getControls();
	const bool toolsKey = controls.isKeyJustPressed(controls.getActionKeyKey(AK_PARTY));

	if (this.isAttached())
	{
		// get out of seat
		if (this.isKeyJustPressed(key_use))
		{
			this.SendCommand(this.getCommandID("get out"));
		}

		// aim cursor
		hud.SetCursorImage("AimCursor.png", Vec2f(32,32));
		hud.SetCursorOffset(Vec2f(-34, -34));
	}
	else
	{
		// use menu
		if (this.isKeyJustPressed(key_use))
		{
			useClickTime = getGameTime();
		//}
		//if (this.isKeyPressed(key_use))
		//{
			this.ClearMenus();
			this.ClearButtons();
			this.ShowInteractButtons();
		}
		else if (this.isKeyJustReleased(key_use))
		{
			const bool tapped = (getGameTime() - useClickTime) < 10; 
			this.ClickClosestInteractButton(tapped ? this.getPosition() : this.getAimPos(), this.getRadius()*2);
			this.ClearButtons();
		}

		// cursors
		if (hud.hasMenus())
			hud.SetDefaultCursor();
		else if (Human::isHoldingBlocks(this) || this.get_bool("getting block"))
			hud.SetCursorImage("BuilderCursor.png", Vec2f(9,9));
		else
			hud.SetCursorImage("PointerCursor.png", Vec2f(16,16));
	}
	
	// click action1 to click buttons
	if (hud.hasButtons() && this.isKeyPressed(key_action1) && !this.ClickClosestInteractButton(this.getAimPos(), 2.0f)) {}

	// click grid menus
	if (hud.hasButtons())
	{
		if (this.isKeyJustPressed(key_action1))
		{
			CGridMenu@ gmenu;
			CGridButton@ gbutton;
			this.ClickGridMenu(0, gmenu, gbutton); 
		}
	}
	
	//build menu
	if (this.isKeyJustPressed(key_inventory))
	{
		CBlob@ core = getMothership(this.getTeamNum());
		if (core !is null && !core.hasTag("critical"))
		{
			if (!Human::isHoldingBlocks(this) && !this.isAttached())
			{
				if (!hud.hasButtons())
				{
					if (this.get_bool("getting block"))
					{
						this.set_bool("getting block", false);
						this.Sync("getting block", false);
						this.getSprite().PlaySound("join");
					}
					else
					{
						//choose a new block to buy
						const s32 overlappingShipID = this.get_s32("shipID");
						Ship@ pShip = overlappingShipID > 0 ? getShipSet().getShip(overlappingShipID) : null;
						if (pShip !is null && pShip.centerBlock !is null && ((pShip.id == core.getShape().getVars().customData) 
							|| ((pShip.isStation || pShip.isSecondaryCore) && pShip.centerBlock.getTeamNum() == this.getTeamNum())))
						{
							buildMenuOpen = true;
							this.set_bool("justMenuClicked", true);

							Sound::Play("buttonclick.ogg");
							BuildShopMenu(this, core, Trans::Components, Vec2f(0,0), (pShip.isStation || pShip.isSecondaryCore) && !pShip.isMothership);
						}
					}
				} 
				else if (hud.hasMenus())
				{
					//buy same block again
					this.ClearMenus();
					Sound::Play("buttonclick.ogg");
					
					if (buildMenuOpen)
					{
						CBitStream params;
						params.write_netid(this.getNetworkID());
						params.write_string(this.get_string("last buy"));
						params.write_u16(getCost(this.get_string("last buy")));
						params.write_bool(false);
						core.SendCommand(core.getCommandID("buyBlock"), params);
					}
					
					buildMenuOpen = false;
					this.set_bool("justMenuClicked", false);
				}
			}
			else if (Human::isHoldingBlocks(this))
			{
				//return blocks
				CBitStream params;
				params.write_netid(this.getNetworkID());
				core.SendCommand(core.getCommandID("returnBlocks"), params);
			}
		}
	}
	
	//automatically grab another block after placing
	if (this.get_bool("getting block"))
	{
		CBlob@ core = getMothership(this.getTeamNum());
		if (core !is null && !core.hasTag("critical"))
		{
			CBitStream params;
			params.write_netid(this.getNetworkID());
			params.write_string(this.get_string("last buy"));
			params.write_u16(getCost(this.get_string("last buy")));
			params.write_bool(true);
			core.SendCommand(core.getCommandID("buyBlock"), params);
		}
	}
	
	if (this.isKeyJustReleased(key_action1))
	{
		this.set_bool("justMenuClicked", false);
	}

	//tools menu
	if (toolsKey && !this.isAttached())
	{
		if (!hud.hasButtons())
		{
			buildMenuOpen = false;
			
			Sound::Play("buttonclick.ogg");
			BuildToolsMenu(this, Trans::ToolsMenu, Vec2f(0,0));
			
		} 
		else if (hud.hasMenus())
		{
			this.ClearMenus();
			Sound::Play("buttonclick.ogg");
		}
	}
}

// Open the build menu
void BuildShopMenu(CBlob@ this, CBlob@ core, const string&in desc, const Vec2f&in offset, const bool&in isStation = false)
{
	CGridMenu@ menu = CreateGridMenu(this.getScreenPos() + offset, core, sv_test ? BUILD_MENU_TEST : BUILD_MENU_SIZE, desc);
	if (menu is null) return;
	
	const bool warmup = getRules().isWarmup();
	menu.deleteAfterClick = true;
	
	string description;
	{ //Seat
		AddBlock(this, menu, "seat", "$SEAT$", Trans::Seat, Trans::SeatDesc, core, 0.5f);
	}
	{ //Propeller
		AddBlock(this, menu, "propeller", "$PROPELLER$", Trans::Engine, Trans::EngineDesc, core, 1.0f);
	}
	{ //Ram Engine
		AddBlock(this, menu, "ramengine", "$RAMENGINE$", Trans::RamEngine, Trans::RamEngineDesc, core, 1.25f);
	}
	{ //Coupling
		AddBlock(this, menu, "coupling", "$COUPLING$", Trans::Coupling, Trans::CouplingDesc, core, 0.1f);
	}
	{ //Wooden Hull
		AddBlock(this, menu, "solid", "$SOLID$", Trans::Hull, Trans::WoodHullDesc, core, 0.75f);
	}
	{ //Wooden Platform
		AddBlock(this, menu, "platform", "$WOOD$", Trans::Platform, Trans::PlatformDesc, core, 0.2f);
	}
	{ //Wooden Door
		AddBlock(this, menu, "door", "$DOOR$", Trans::Door, Trans::DoorDesc, core, 1.0f);
	}
	{ //Wooden Plank
		AddBlock(this, menu, "plank", "$PLANK$", Trans::Plank, Trans::PlankDesc, core, 0.7f);
	}
	{ //Harpoon
		AddBlock(this, menu, "harpoon", "$HARPOON$", Trans::Harpoon, Trans::HarpoonDesc, core, 2.0f);
	}
	{ //Harvester
		AddBlock(this, menu, "harvester", "$HARVESTER$", Trans::Harvester, Trans::HarvesterDesc, core, 2.0f);
	}
	{ //Patcher
		AddBlock(this, menu, "patcher", "$PATCHER$", Trans::Patcher, Trans::PatcherDesc, core, 3.0f);
	}
	{ //Repulsor
		AddBlock(this, menu, "repulsor", "$REPULSOR$", Trans::Repulsor, Trans::RepulsorDesc, core, 0.25f);
	}
	{ //Decoy Core
		AddBlock(this, menu, "decoycore", "$DECOYCORE$", Trans::DecoyCore, Trans::DecoyCoreDesc, core, 6.0f);
	}
	{ //Auxilliary Core
		CGridButton@ button = AddBlock(this, menu, "secondarycore", "$SECONDARYCORE$", Trans::Auxilliary, Trans::AuxillDesc, core, 12.0f);
	}
	{ //Bomb
		AddBlock(this, menu, "bomb", "$BOMB$", Trans::Bomb, Trans::BombDesc, core, 2.0f);
	}
	{ //Ram Hull
		AddBlock(this, menu, "ram", "$RAM$", Trans::Ram, Trans::RamDesc, core, 2.0f);
	}
	{ //Machinegun
		description = Trans::MGDesc+"\n"+Trans::AmmoCap+": 250";
		AddBlock(this, menu, "machinegun", "$MACHINEGUN$", Trans::Machinegun, description, core, 2.0f);
	}
	{ //Point Defense
		description = Trans::PointDefDesc+"\n"+Trans::AmmoCap+": 15";
		AddBlock(this, menu, "pointdefense", "$POINTDEFENSE$", Trans::PointDefense, description, core, 3.5f);
	}
	{ //Flak
		description = Trans::FlakDesc+"\n"+Trans::AmmoCap+": 15";
		AddBlock(this, menu, "flak", "$FLAK$", Trans::FlakCannon, description, core, 2.5f);
	}
	{ //Heavy Machinegun
		description = Trans::HeavyMGDesc+"\n"+Trans::AmmoCap+": 160";
		AddBlock(this, menu, "heavymachinegun", "$HEAVYMACHINEGUN$", Trans::HeavyMG, description, core, 3.0f);
	}
	{ //AP Cannon
		description = Trans::CannonDesc+"\n"+Trans::AmmoCap+": 10";
		AddBlock(this, menu, "cannon", "$CANNON$", Trans::Cannon, description, core, 3.25f);
	}
	{ //Missile Launcher
		description = Trans::LauncherDesc+"\n"+Trans::AmmoCap+": 8";
		AddBlock(this, menu, "launcher", "$LAUNCHER$", Trans::Launcher, description, core, 4.5f);
	}
	{ //Stone Bricks
		AddBlock(this, menu, "stone", "$STONE$", Trans::Stone, Trans::StoneDesc, core, 12.0f);
	}
	{ //Tank Track
		AddBlock(this, menu, "tanktrack", "$TANKTRACK$", Trans::TankTrack, Trans::TankTrackDesc, core, 1.0f);
	}
	{ //Tank Cannon
		description = Trans::CannonDesc+"\n"+Trans::AmmoCap+": 10";
		AddBlock(this, menu, "tankcannon", "$CANNON$", Trans::TankCannon, Trans::TankCannonDesc, core, 7.0f);
	}
	{ //Sponson Cannon
		description = Trans::CannonDesc+"\n"+Trans::AmmoCap+": 10";
		AddBlock(this, menu, "sponson", "$FLAK$", Trans::Sponson, Trans::SponsonCannonDesc, core, 3.5f);
	}
	{ //Engine
		description = Trans::CannonDesc+"\n"+Trans::AmmoCap+": 10";
		AddBlock(this, menu, "engineblock", "$ENGINE$", Trans::Sponson, Trans::SponsonCannonDesc, core, 3.5f);
	}
}

// Add a block to the build menu
CGridButton@ AddBlock(CBlob@ this, CGridMenu@ menu, const string&in block, const string&in icon, const string&in bname, const string&in desc, CBlob@ core, const f32&in weight, const bool&in isWeapon = false)
{
	const u16 cost = getCost(block);
	
	CBitStream params;
	params.write_netid(this.getNetworkID());
	params.write_string(block);
	params.write_u16(cost);
	params.write_bool(false);
	
	CGridButton@ button = menu.AddButton(icon, bname + " $" + cost, core.getCommandID("buyBlock"), params);

	const bool selected = this.get_string("last buy") == block;
	if (selected) button.SetSelected(2);
	
	button.SetHoverText(isWeapon ? Trans::WarmupWarning+".\n" :
						desc + "\n"+ Trans::Weight+": " + weight * 100 + "rkt\n" + (selected ? "\n"+Trans::BuyAgain+"\n" : ""));
	button.SetEnabled(!isWeapon);
	return button;
}

// Open the tools menu
void BuildToolsMenu(CBlob@ this, const string&in description, const Vec2f&in offset)
{
	CGridMenu@ menu = CreateGridMenu(this.getScreenPos() + offset, this, TOOLS_MENU_SIZE, description);
	if (menu is null) return;
	
	menu.deleteAfterClick = true;
	
	{ //Pistol
		AddTool(this, menu, "$PISTOL$", Trans::Pistol, Trans::PistolDesc, "pistol");
	}
	{ //Deconstructor
		AddTool(this, menu, "$DECONSTRUCTOR$", Trans::Deconstructor, Trans::DeconstDesc, "deconstructor");
	}
	{ //Reconstructor
		AddTool(this, menu, "$RECONSTRUCTOR$", Trans::Reconstructor, Trans::ReconstDesc, "reconstructor");
	}
	
	Vec2f MENU_POS;

	MENU_POS = menu.getUpperLeftPosition() + Vec2f(-36, 46);
	CGridMenu@ tool = CreateGridMenu(MENU_POS, this, Vec2f(1, 1), "Make Block");

	if (tool !is null)
	{
		tool.SetCaptionEnabled(false);

		CGridButton@ button = tool.AddButton("$WOOD$", "", this.getCommandID("makeBlockWithNoBase"), Vec2f(1, 1));
		if (button !is null)
		{
			if(this.get_s32("shipID") == 0 && this.get_bool("onGround"))
			{
				button.SetHoverText(Trans::IndependentBlock);
			}
			else
			{
				button.SetEnabled(false);
				button.SetSelected(1);
				button.SetHoverText(Trans::IndBlNotOnGr);
			}
		}
	}
}

//Add a tool to the tools menu
CGridButton@ AddTool(CBlob@ this, CGridMenu@ menu, const string&in icon, const string&in toolName, const string&in desc, const string&in currentTool)
{
	CBitStream params;
	params.write_string(currentTool);
	
	CGridButton@ button = menu.AddButton(icon, toolName, this.getCommandID("swap tool"), params);
	
	if (this.get_string("current tool") == currentTool)
		button.SetSelected(2);
	
	button.SetHoverText(desc);
	return button;
}

// Send a command to punch nearby enemies
void Punch(CBlob@ this)
{
	CMap@ map = getMap();
	const Vec2f pos = this.getPosition();
	Vec2f aimVector = this.getAimPos() - pos;
	
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, -aimVector.Angle(), 120.0f, 10.0f, this, @hitInfos))
	{
		const u8 hitLength = hitInfos.length;
		for (u8 i = 0; i < hitLength; i++)
		{
			CBlob@ b = hitInfos[i].blob;
			if (b is null) continue;

			if (b.getName() == "human" && b.getTeamNum() != this.getTeamNum())
			{
				//check to make sure we aren't hitting through blocks
				bool hitBlock = false;
				Vec2f dir = b.getPosition() - pos;
				HitInfo@[] rayInfos;
				if (map.getHitInfosFromRay(pos, -dir.Angle(), dir.Length(), this, @rayInfos))
				{
					const u8 rayLength = rayInfos.length;
					for (u8 q = 0; q < rayLength; q++)
					{
						CBlob@ block = rayInfos[q].blob;
						if (block !is null && block.hasTag("solid"))
						{
							if (block.hasTag("plank") && !CollidesWithPlank(block, dir))
								continue;
							
							hitBlock = true;
							break;
						}
					}
				}
				
				if (!hitBlock)
				{
					if (this.isMyPlayer())
					{
						CBitStream params;
						params.write_netid(b.getNetworkID());
						this.SendCommand(this.getCommandID("punch"), params);
					}
					this.set_u32("punch time", getGameTime());
					return;
				}
			}
		}
	}

	// miss
	directionalSoundPlay("throw", pos);
	this.set_u32("punch time", getGameTime());
}

// Send a command to shoot the pistol
void ShootPistol(CBlob@ this)
{
	this.set_u32("fire time", getGameTime());
	
	if (!this.isMyPlayer()) return;

	Vec2f pos = this.getPosition();
	Vec2f aimVector = this.getAimPos() - pos;
	aimVector.Normalize();

	Vec2f offset(_shotspreadrandom.NextFloat() * BULLET_SPREAD,0);
	offset.RotateBy(_shotspreadrandom.NextFloat() * 360.0f, Vec2f());
	
	const Vec2f vel = aimVector + offset;

	CBitStream params;
	params.write_Vec2f(vel);

	const s32 overlappingShipID = this.get_s32("shipID");
	Ship@ ship = overlappingShipID > 0 ? getShipSet().getShip(overlappingShipID) : null;
	if (ship !is null) //relative positioning
	{
		params.write_bool(true);
		const Vec2f rPos = (pos + aimVector*3) - ship.origin_pos;
		params.write_Vec2f(rPos);
		params.write_u32(ship.id);
	}
	else //absolute positioning
	{
		params.write_bool(false);
		const Vec2f aPos = pos + aimVector*9;
		params.write_Vec2f(aPos);
	}
	
	this.SendCommand(this.getCommandID("shoot"), params);
}

// Send a command to construct or deconstruct
void Construct(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	Vec2f aimPos = this.getAimPos();
	Vec2f aimVector = aimPos - pos;

	CSprite@ sprite = this.getSprite();

	CBlob@ blob = getMap().getBlobAtPosition(aimPos);
	if (blob !is null && blob.getShape().getVars().customData > 0 && aimVector.Length() <= CONSTRUCT_RANGE && !blob.hasTag("station"))
	{
		const string currentTool = this.get_string("current tool");
		if (this.isMyPlayer() && canConstruct(this))
		{
			Ship@ ship = getShipSet().getShip(blob.getShape().getVars().customData);
			if (ship is null) return;
			
			CPlayer@ player = this.getPlayer();
			if (player is null) return;
			
			const string playerName = player.getUsername();
			
			const u16 blobCost = Maths::Max(!blob.hasTag("coupling") ? getCost(blob.getName()) : 1, 1);
			const f32 health = blob.getHealth();
			const f32 initHealth = blob.getInitialHealth();
			const f32 currentReclaim = blob.get_f32("current reclaim");
			
			f32 heal = 0.0f;
			f32 reclaim = 0.0f;
			u16 cost = 0;
			bool doWarning = false;
			
			const f32 constructDiscount = 0.5f; //50 percent cheaper to repair block than to replace it
			const f32 constructFactor = (blobCost * (blob.getName() == "stone" ? 2.5f : 1)) / (5.0f + blobCost * 0.04f);
			const f32 constructAmount = initHealth / (blob.hasTag("mothership") ? 100.0f : constructFactor);
			
			if (currentTool == "deconstructor")
			{
				if (blob.hasTag("mothership")) return;
				
				const bool sameTeam = blob.getTeamNum() == this.getTeamNum();
				if ((ship.owner.isEmpty() && (!ship.isMothership || sameTeam)) || //reclaim abandoned ships , reclaim our team's mothership if no owner
				   ((blob.get_string("playerOwner") == playerName || ship.owner == "*" || ship.owner == playerName) && sameTeam)) //reclaim if we own the ship or block- or the ship has multi-teams
				{
					reclaim = -constructAmount;
				}
				else
				{
					reclaim = -(constructAmount / 3);
					doWarning = true;
				}
				
				if (reclaim + currentReclaim <= 0) //give money if we ate this blob
				{
					cost = blobCost * (health / initHealth);
				}
			}
			else if (currentTool == "reconstructor")
			{
				reclaim = constructAmount;
				
				const u16 reconstructCost = blob.hasTag("mothership") ? MOTHERSHIP_HEAL_COST : blobCost*constructDiscount / constructFactor;
				if (currentReclaim + reclaim > health && health < initHealth)
				{
					heal = constructAmount;
					cost = -reconstructCost;
				}
			}

			CBitStream params;
			params.write_netid(blob.getNetworkID());
			params.write_f32(heal);
			params.write_f32(reclaim);
			params.write_u16(cost);
			params.write_bool(doWarning);
			
			this.SendCommand(this.getCommandID("construct"), params);
			this.set_u32("fire time", getGameTime());
		}
		
		//effects
		if (isClient())
		{
			const f32 offsetAngle = aimVector.Angle() - (blob.getPosition() - pos).Angle(); 
			
			CSpriteLayer@ laser = sprite.getSpriteLayer("laser");
			if (laser !is null)
			{
				laser.SetVisible(true);
				const f32 laserLength = Maths::Max(0.1f, (aimPos - pos).getLength() / 32.0f);
				laser.ResetTransform();
				laser.ScaleBy(Vec2f(laserLength, 1.0f));
				laser.TranslateBy(Vec2f(laserLength * 16.0f, + 0.5f));
				laser.RotateBy(offsetAngle, Vec2f());
			}
			
			if (sprite.getEmitSoundPaused())
				sprite.SetEmitSoundPaused(false);
		}
	}
	else
	{
		EndConstructEffects(this, sprite);
	}
}

// End any effects from contructing
void EndConstructEffects(CBlob@ this, CSprite@ sprite)
{
	if (isClient())
	{
		this.set_bool("reclaimPropertyWarn", false);
		
		if (!sprite.getEmitSoundPaused())
			sprite.SetEmitSoundPaused(true);
		
		sprite.RemoveSpriteLayer("laser");
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (isServer() && this.getCommandID("get out") == cmd)
	{
		//get out of a seat
		this.server_DetachFromAll();
	}
	else if (this.getCommandID("punch") == cmd)
	{
		//hurt blob with a punch
		CBlob@ b = getBlobByNetworkID(params.read_netid());
		if (b !is null)
		{
			const Vec2f pos = b.getPosition();
			if (isClient())
				directionalSoundPlay("Kick.ogg", pos);
			if (isServer())
				this.server_Hit(b, pos, Vec2f_zero, 0.25f, Hitters::muscles, false);
		}
	}
	else if (this.getCommandID("shoot") == cmd)
	{
		//shoot pistol
		Vec2f velocity = params.read_Vec2f();
		Vec2f pos = this.getPosition();
		
		if (params.read_bool()) //relative positioning
		{
			Vec2f rPos = params.read_Vec2f();
			const int shipColor = params.read_u32();
			Ship@ ship = getShipSet().getShip(shipColor);
			if (ship !is null)
			{
				pos = rPos + ship.origin_pos;
			}
		}
		else
			pos = params.read_Vec2f();
		
		if (isServer())
		{
			/*CBlob@ bullet = server_CreateBlob("bullet", this.getTeamNum(), pos);
			if (bullet !is null)
			{
				if (this.getPlayer() !is null)
				{
					bullet.SetDamageOwnerPlayer(this.getPlayer());
				}
				bullet.setVelocity(velocity);
				bullet.setAngleDegrees(-velocity.Angle());
				bullet.server_SetTimeToDie(lifetime); 
			}*/
			shootGun(this.getNetworkID(), -velocity.Angle() + XORRandom(BULLET_SPREAD) - XORRandom(BULLET_SPREAD * 2), pos);
		}
		
		if (isClient())
		{
			shotParticles(pos + Vec2f(0.1f ,0).RotateBy(-velocity.Angle())*6.0f, velocity.Angle(), true, 0.02f , 0.6f);
			directionalSoundPlay("RifleFire" + XORRandom(3) + ".ogg", pos, 2.0f);
		}
	}
	else if (this.getCommandID("construct") == cmd)
	{
		CPlayer@ player = this.getPlayer();
		if (player is null) return;
		
		CBlob@ blob = getBlobByNetworkID(params.read_netid());
		if (blob is null) return;
		
		const string playerName = player.getUsername();
		
		const f32 heal = Maths::Min(blob.getHealth() + params.read_f32(), blob.getInitialHealth());
		const f32 reclaim = Maths::Min(blob.get_f32("current reclaim") + params.read_f32(), blob.getInitialHealth());
		const u16 cost = params.read_u16();

		this.set_bool("reclaimPropertyWarn", params.read_bool());	

		if (reclaim <= 0.0f)
		{
			directionalSoundPlay("/ChaChing.ogg", blob.getPosition());
			blob.Tag("disabled");
			blob.server_Die();
		}
		
		blob.set_f32("current reclaim", reclaim);
		if (server_getPlayerBooty(playerName) > -cost || getRules().get_bool("freebuild"))
		{
			server_addPlayerBooty(playerName, cost);
			blob.server_SetHealth(heal);
		}
		
		if (isClient()) //effects
		{
			CSprite@ sprite = this.getSprite();
			sprite.RemoveSpriteLayer("laser");
			
			const string beamSpriteFilename = this.get_string("current tool") == "deconstructor" ? "ReclaimBeam" : "RepairBeam";
			CSpriteLayer@ laser = sprite.addSpriteLayer("laser", beamSpriteFilename, 32, 16);
			if (laser !is null)
			{
				Animation@ reclaimingAnim = laser.addAnimation("constructing", 1, true);
				int[] reclaimingAnimFrames = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
				reclaimingAnim.AddFrames(reclaimingAnimFrames);
				
				laser.SetAnimation("constructing");
				laser.setRenderStyle(RenderStyle::light);
				laser.SetRelativeZ(-1);
			}
		}
	}
	else if (isServer() && this.getCommandID("releaseOwnership") == cmd)
	{
		//release ownership of a seat
		CPlayer@ player = this.getPlayer();
		CBlob@ seat = getBlobByNetworkID(params.read_netid());
		
		if (player is null || seat is null) return;
		
		if (this.isAttached()) this.server_DetachFromAll();
		
		const string owner = seat.get_string("playerOwner");
		if (owner == player.getUsername())
		{
			print("$ " + owner + " released seat: ID " + seat.getNetworkID());

			seat.set_string("playerOwner", "");
			seat.Sync("playerOwner", true); //2040865191 HASH
		}
	}
	else if (isServer() && this.getCommandID("giveBooty") == cmd)
	{
		//transfer booty
		CRules@ rules = getRules();
		if (rules.isWarmup()) return;
			
		const u8 teamNum = this.getTeamNum();
		CPlayer@ player = this.getPlayer();
		const string cName = getCaptainName(teamNum);
		CPlayer@ captain = getPlayerByUsername(cName);
		
		if (captain is null || player is null) return;
		
		const u16 transfer = rules.get_u16("booty_transfer");
		const u16 fee = Maths::Round(transfer * rules.get_f32("booty_transfer_fee"));
		const string pName = player.getUsername();
		const u16 playerBooty = server_getPlayerBooty(pName);
		if (playerBooty < transfer + fee) return;
			
		if (player !is captain)
		{
			print("$ " + pName + " transfers Booty to captain " + cName);
			server_addPlayerBooty(pName, -transfer - fee);
			server_addPlayerBooty(cName, transfer);
		}
		else
		{
			CBlob@ core = getMothership(teamNum, rules);
			if (core !is null)
			{
				const int coreColor = core.getShape().getVars().customData;
				CBlob@[] crew;
				CBlob@[] humans;
				getBlobsByName("human", @humans);
				const u8 humansLength = humans.length;
				for (u8 i = 0; i < humansLength; i++)
				{
					CBlob@ human = humans[i];
					if (human.getTeamNum() == teamNum && human !is this)
					{
						CBlob@ shipBlob = getBlobByNetworkID(human.get_u16("shipBlobID"));
						if (shipBlob !is null && shipBlob.getShape().getVars().customData == coreColor)
							crew.push_back(human);
					}
				}
				
				const u8 crewLength = crew.length;
				if (crewLength > 0)
				{
					print("$ " + pName + " transfers Booty to crew");
					server_addPlayerBooty(pName, -transfer - fee);
					const u16 shareBooty = Maths::Floor(transfer/crewLength);
					for (u8 i = 0; i < crewLength; i++)
					{
						CPlayer@ crewPlayer = crew[i].getPlayer();
						server_addPlayerBooty(crewPlayer.getUsername(), shareBooty);
					}
				}
			}
		}
	}
	else if (this.getCommandID("swap tool") == cmd)
	{
		const string tool = params.read_string();
		
		if (isClient())
		{
			EndConstructEffects(this, this.getSprite());
		}
		
		this.set_string("current tool", tool);
	}
	else if (this.getCommandID("makeBlockWithNoBase") == cmd)
	{
		if(this.get_bool("onGround") && this.get_s32("shipID") == 0 && (server_getPlayerBooty(this.getPlayer().getUsername()) >= 7 || getRules().get_bool("freebuild")))
		{
			CBlob@ b = makeBlock(this.getPosition(), 0.0f, "platform", this.getTeamNum());
			if (b !is null)
			{
				b.set_u32("placedTime", getGameTime());
				CRules@ rules = getRules();
				
				ShipDictionary@ ShipSet = getShipSet(rules);
				Ship@ ship = CreateShip(rules, ShipSet);
				CBlob@[] blob_blocks;
				if (b !is null) blob_blocks.push_back(b);
				rules.push("dirtyBlocks", blob_blocks);
				
				b.set_netid("ownerID", 0);
				const f32 z = b.hasTag("platform") ? 309.0f : (b.hasTag("weapon") ? 311.0f : 310.0f);
				SetDisplay(b, color_white, RenderStyle::normal, z);
				
				if (!isServer()) //add it locally till a sync
				{
					ShipBlock ship_block;
					ship_block.blobID = b.getNetworkID();
					ship_block.offset = b.getPosition();
					ship_block.angle_offset = b.getAngleDegrees();
					b.getShape().getVars().customData = ship.id;
					ship.blocks.push_back(ship_block);
				}
				else b.getShape().getVars().customData = 0; // push on ship
				
				server_addPlayerBooty(this.getPlayer().getUsername(), -7);
			}
		}
	}
	else if (this.getCommandID("run over") == cmd)
	{
		CBlob@ block = getBlobByNetworkID(params.read_netid());
		if (block is null) return;
		
		const Vec2f pos = this.getPosition();
		
		if (block !is this) //player didn't hit themselves
		{
			//death when run-over by a ship
			Ship@ ship = getShipSet().getShip(block.getShape().getVars().customData);
			if (ship !is null)
			{
				//set the damage owner so the ship's owner gets the kill
				CPlayer@ owner = getPlayerByUsername(ship.owner);
				if (owner !is null)
					block.SetDamageOwnerPlayer(owner);
			}
			
			if (isClient())
			{
				directionalSoundPlay("WoodHeavyHit2", pos, 1.2f); //oof
				if (XORRandom(5) == 0) directionalSoundPlay("Wilhelm", pos);
			}
			
			if (isServer())
				block.server_Hit(this, pos, Vec2f_zero, block.getInitialHealth(), Hitters::muscles, false);
		}
		else
		{
			//death when standing over a destroyed block
			if (isClient())
				directionalSoundPlay("destroy_ladder", pos);
			if (isServer())
				this.server_Hit(this, pos, Vec2f_zero, block.getInitialHealth(), Hitters::muscles, false);
		}
	}
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	this.getShape().getVars().onground = true;
	this.set_u16("shipBlobID", detached.getNetworkID());
	this.set_s8("stay count", 3);
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint)
{
	EndConstructEffects(this, this.getSprite());
}

void onDie(CBlob@ this)
{
	//return held blocks
	CRules@ rules = getRules();
	u16[] blocks;
	if (this.get("blocks", blocks) && blocks.size() > 0)
	{
		if (isServer())
		{
			CPlayer@ player = this.getPlayer();
			if (player !is null)
			{
				u16 returnBooty = 0;
				const u8 blocksLength = blocks.length;
				for (u8 i = 0; i < blocksLength; ++i)
				{
					CBlob@ block = getBlobByNetworkID(blocks[i]);
					if (block is null) continue;
					
					if (!block.hasTag("coupling") && block.getShape().getVars().customData == -1)
						returnBooty += getCost(block.getName());
				}
				
				if (returnBooty > 0 && !rules.get_bool("freebuild"))
					server_addPlayerBooty(player.getUsername(), returnBooty);
			}
		}
		Human::clearHeldBlocks(this);
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return (this.getTeamNum() != blob.getTeamNum() || 
			(blob.hasTag("solid") && blob.getShape().getVars().customData > 0) || blob.getShape().isStatic());
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (this.getTickSinceCreated() < 60 && customData != 44) //invincible for a few seconds after spawning
		return 0.0f;
		
	const Vec2f pos = this.getPosition();
	
	//when this is killed: reward hitter player, done in onHit to reward from owned blobs
	if (hitterBlob !is null && this.getHealth() - damage <= 0)
	{
		CPlayer@ hitterPlayer = hitterBlob.getDamageOwnerPlayer();
		const u8 teamNum = this.getTeamNum();
		const u8 hitterTeam = hitterBlob.getTeamNum();
		//only pistol or punches
		if ((customData == Hitters::muscles || customData == Hitters::bomb_arrow) && hitterPlayer !is null && hitterTeam != teamNum)
		{
			u16 reward = 15;
			
			CBlob@ hitterBlob = hitterPlayer.getBlob();
			if (hitterBlob !is null)
			{
				const s32 overlappingShipID = hitterBlob.get_s32("shipID");
				Ship@ pShip = overlappingShipID > 0 ? getShipSet().getShip(overlappingShipID) : null;
				if (pShip !is null && pShip.isMothership && //this is on a mothership
					pShip.centerBlock !is null && pShip.centerBlock.getTeamNum() == teamNum) //hitter is on this mothership
				{
					if (hitterPlayer.isMyPlayer())
						Sound::Play("snes_coin.ogg");
					
					//reward extra if hitter is on our mothership
					reward = 50;
				}
				else
				{
					if (hitterPlayer.isMyPlayer())
						Sound::Play("coinpick.ogg");
				}
			}
			
			if (isServer())
			{
				if (getRules().get_bool("whirlpool")) reward *= 3;
				server_addPlayerBooty(hitterPlayer.getUsername(), reward);
				server_updateTotalBooty(hitterTeam, reward);
			}
		}
		
		if (isClient())
		{
			ParticleBloodSplat(pos, true);
			directionalSoundPlay("BodyGibFall", pos);
			directionalSoundPlay("SR_ManDeath" + (XORRandom(4) + 1), pos, 0.75f);
			
			this.getSprite().Gib();
		}
	}
	
	if (isClient())
	{
		if (customData != Hitters::muscles)
			directionalSoundPlay("ImpactFlesh", worldPoint);
			
		if (!g_kidssafe)
		{
			//blood particle
			CParticle@ p = ParticleAnimated("BloodSplat", pos, velocity, velocity.Angle(), 1.0f, 2, 0.0f, false);
			if (p !is null)
				p.Z = 650.0f;
		}
		
		if (damage > 1.45f) //sound for anything 2 heart+
			directionalSoundPlay("ArgLong", pos, 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
		else if (damage > 0.45f)
			directionalSoundPlay("ArgShort.ogg", pos, 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
	}
	
	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (damage <= 0.0f) return;

	CPlayer@ player = this.getDamageOwnerPlayer();
	if (player !is null)
		rewardBooty(player, hitBlob, booty_reward);
}

void onHealthChange(CBlob@ this, f32 oldHealth)
{
	if (isClient())
	{
		if (this.getHealth() > oldHealth)
		{
			directionalSoundPlay("Heal.ogg", this.getPosition(), 2.0f);
			makeHealParticle(this);
		}
	}
}

void SetDisplay(CBlob@ blob, const SColor&in color, RenderStyle::Style&in style, const f32&in Z = -10000)
{
	CSprite@ sprite = blob.getSprite();
	sprite.asLayer().SetColor(color);
	sprite.asLayer().setRenderStyle(style);
	if (Z > -10000)
	{
		sprite.SetZ(Z);
	}
}