#include "ShipsCommon.as";
#include "HumanCommon.as";
#include "BlockProduction.as";
#include "PropellerForceCommon.as";

const u16 COUPLINGS_COOLDOWN = 8 * 30;
const u16 CREW_COUPLINGS_LEASE = 10 * 30;//time till the captain can control crew's couplings
const u16 UNUSED_RESET = 2 * 60 * 30;

const u8 CANNON_FIRE_CYCLE = 13;

const u8 SPONSON_FIRE_CYCLE = 5;
const int SPONSON_FIRE_RATE = 60; //this also has to be copied to Sponson.as!

const int AUTOCANNON_FIRE_RATE = 10; //this also has to be copied to Sponson.as!
const u8 AUTOCANNON_FIRE_CYCLE = 5;

int degree = 45 ;


void onInit(CBlob@ this)
{
	this.set_f32("weight", 0.5f);

	if (isServer())
	{
		u16[] left_propellers, strafe_left_propellers, strafe_right_propellers, right_propellers, up_propellers, down_propellers, rotate_wheels, machineguns, cannons, sponsons, autocannons;					
		this.set("left_propellers", left_propellers);
		this.set("strafe_left_propellers", strafe_left_propellers);
		this.set("strafe_right_propellers", strafe_right_propellers);
		this.set("right_propellers", right_propellers);
		this.set("up_propellers", up_propellers);
		this.set("down_propellers", down_propellers);
		this.set("rotate_wheels", rotate_wheels);
		this.set("machineguns", machineguns);
		this.set("cannons", cannons);
		this.set("sponsons", sponsons);
		this.set("autocannons", autocannons);
		
		this.set_bool("kUD", false);
		this.set_bool("kLR", false);
		this.set_bool("kS", false);
		this.set_u32("lastCannonFire", getGameTime());
		this.set_u8("cannonFireIndex", 0);
		this.set_u32("seatResetTime", getGameTime() + UNUSED_RESET);
		this.set_u32("couplingCooldown", 0);
	}
	
	this.set_string("seat label", "Steering Seat");
	this.set_u8("seat icon", 7);
	this.Tag("seat");
	this.Tag("ramming");
	
	//anim
	CSprite@ sprite = this.getSprite();
	//default
	{
		Animation@ anim = sprite.addAnimation("default", 0, false);
		anim.AddFrame(0);
	}
	//folding
	{
		Animation@ anim = sprite.addAnimation("fold", 4, false);
		int[] frames = {0, 1, 2, 3, 4};
		anim.AddFrames(frames);
	}
}

void onTick(CBlob@ this)
{
	const int seatColor = this.getShape().getVars().customData;
	if (seatColor <= 0) return;	

	const u32 gameTime = getGameTime();
	const u8 teamNum = this.getTeamNum();
	const string seatOwner = this.get_string("playerOwner");


	if (isServer())
	{
		//clear ownership on player leave/change team or seat not used
		CPlayer@ ownerPlayer = getPlayerByUsername(seatOwner);
		if (ownerPlayer is null || ownerPlayer.getTeamNum() != teamNum || gameTime >= this.get_u32("seatResetTime"))
		{
			server_setOwner(this, "");
		}
	}

	CSprite@ sprite = this.getSprite();
	sprite.SetAnimation(!seatOwner.isEmpty() ? "default": "fold"); //update sprite

	Ship@ ship = getShipSet().getShip(seatColor);
	if (ship is null) return;
	
	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	if (occupier !is null)
	{
		occupier.setAngleDegrees(this.getAngleDegrees());

		CPlayer@ player = occupier.getPlayer();
		if (player is null) return;
		
		CControls@ controls = getControls();

		CRules@ rules = getRules();
		CHUD@ HUD = getHUD();
		const string occupierName = player.getUsername();
		const u8 occupierTeam = occupier.getTeamNum();
		const bool isCaptain = ship.owner == occupierName || ship.owner == "*" || ship.owner.isEmpty();
		const bool canHijack = seatOwner == ship.owner && occupierTeam != teamNum;
			
		const bool up = occupier.isKeyPressed(key_up);
		const bool left = occupier.isKeyPressed(key_left);
		const bool right = occupier.isKeyPressed(key_right);
		const bool down = occupier.isKeyPressed(key_down);
		const bool strafe = occupier.isKeyPressed(key_eat); //KAG dumbness - i cant use any key, only the ones wich are used in vanilla
		const bool space = occupier.isKeyPressed(key_action3);	
		const bool inv = occupier.isKeyPressed(key_inventory);
		const bool left_click = occupier.isKeyPressed(key_action1);	
		const bool right_click = occupier.isKeyPressed(key_action2);	

		//client-side couplings managing functions
		if (player.isMyPlayer())
		{
			//show help tip
			occupier.set_bool("drawSeatHelp", !ship.owner.isEmpty() && occupierTeam == teamNum && !isCaptain && occupierName == seatOwner);
			
			//couplings help tip
			occupier.set_bool("drawCouplingsHelp", this.get_u32("couplingCooldown") + COUPLINGS_COOLDOWN < gameTime);

			//gather couplings
			CBlob@[] couplings;
			const u16 blocksLength = ship.blocks.length;
			for (u16 i = 0; i < blocksLength; ++i)
			{
				ShipBlock@ ship_block = ship.blocks[i];
				if (ship_block is null) continue;

				CBlob@ block = getBlobByNetworkID(ship_block.blobID);
				if (block is null) continue;
				
				//gather couplings
				if (block.hasTag("coupling") && !block.hasTag("dead") && block.getTeamNum() == teamNum)
					couplings.push_back(block);
			}
			
			const u16 couplingsLength = couplings.length;

			//Show coupling/repulsor buttons on spacebar down
			if (occupier.isKeyJustPressed(key_action3))
			{
				//couplings on ship
				for (u16 i = 0; i < couplingsLength; ++i)
				{
					CBlob@ c = couplings[i];
					if (!c.isOnScreen()) continue;
					
					const bool isOwner = c.get_string("playerOwner") == occupierName;


					CButton@ button = occupier.CreateGenericButton(2, Vec2f_zero, c, c.getCommandID("decouple"), "Decouple");
					if (button !is null)
					{
						button.enableRadius = 999.0f;
						button.radius = 1.0f;
					}
				}
				
				//repulsors on screen
				CBlob@[] repulsors;	
				getBlobsByTag("repulsor", @repulsors);
				const u16 repulsorLength = repulsors.length;
				for (u16 i = 0; i < repulsorLength; ++i)
				{
					CBlob@ r = repulsors[i];
					const int color = r.getShape().getVars().customData;
					if (color > 0 && r.isOnScreen() && !r.hasTag("activated") && seatColor == color)
					{
						CButton@ button = occupier.CreateGenericButton(8, Vec2f_zero, r, r.getCommandID("chainReaction"), "Activate");
						if (button !is null)
						{
							button.enableRadius = 999.0f;
							button.radius = 1.0f;
						}
					}
				}

				CBlob@[] timedbombs;	
					getBlobsByTag("timedbomb", @timedbombs);
					const u16 timedBombsLength = timedbombs.length;
					for (u16 i = 0; i < timedBombsLength; ++i)
					{
						CBlob@ r = timedbombs[i];
						const int color = r.getShape().getVars().customData;
						if (color > 0 && r.isOnScreen() && !r.hasTag("activated") && seatColor == color)
						{
							CButton@ button = occupier.CreateGenericButton(8, Vec2f_zero, r, r.getCommandID("chainReaction"), "Activate");
							if (button !is null)
							{
								button.enableRadius = 999.0f;
								button.radius = 1.0f;
							}
						}
					}
				}
			
			//hax: update can't-decouplers
			if (space)
			{
				for (u16 i = 0; i < couplingsLength; ++i)
				{
					CBlob@ c = couplings[i];
					if (c.get_string("playerOwner") != occupierName && c.getTickSinceCreated() == CREW_COUPLINGS_LEASE)
					{
						occupier.ClickClosestInteractButton(c.getPosition(), 0.0f);
						
						CButton@ button = occupier.CreateGenericButton(1, Vec2f_zero, c, c.getCommandID("decouple"), "Decouple (crew's)");
						if (button !is null)
						{
							button.enableRadius = 999.0f;
							button.radius = 1.0f;
						}
					}
				}
			}

			//Kill coupling/turret buttons on spacebar up
			if (occupier.isKeyJustReleased(key_action3))
				occupier.ClearButtons();
		
			//Release all couplings on spacebar + right click
			if (space && HUD.hasButtons() && right_click)
			{
				for (u16 i = 0; i < couplingsLength; ++i)
				{
					CBlob@ c = couplings[i];
					if (c.get_string("playerOwner") == occupierName)
					{
						c.Tag("dead");
						c.SendCommand(c.getCommandID("decouple"));
					}
				}
			}
		}
		
		//******svOnly below
		if (!isServer()) return;
	
		if (occupierName == seatOwner)
			this.set_u32("seatResetTime", gameTime + UNUSED_RESET);
		else
			this.set_u32("seatResetTime",  Maths::Max(0, this.get_u32("seatResetTime") - 3)); //resets 4x faster if enemy is using it
			
		if (seatOwner.isEmpty() && occupierTeam == teamNum)//Re-set empty seat's owner to occupier
		{
			server_setOwner(this, occupierName);
		}
		
		//Produce coupling
		const bool canProduceCoupling = gameTime > this.get_u32("couplingCooldown") + COUPLINGS_COOLDOWN;
		if (inv && canProduceCoupling && !Human::wasHoldingBlocks(occupier) && !Human::isHoldingBlocks(occupier))
		{
			this.set_u32("couplingCooldown", gameTime);
			this.Sync("couplingCooldown", true);
			ProduceBlock(rules, occupier, "coupling", 2);
		}
		
		//update if ships changed
		if (this.get_bool("updateBlock") && (gameTime + this.getNetworkID()) % 10 == 0)
			updateArrays(this, ship);
		
		if (space && left_click)//so when a player undocks the ship stops
		{
			this.set_bool("kUD", true);
			this.set_bool("kLR", true);
			this.set_bool("kS", true);
		}
		
		//ship controlling

			// gather propellers, couplings, machineguns, cannons and sponsons
			u16[] left_propellers, strafe_left_propellers, strafe_right_propellers, right_propellers, up_propellers, down_propellers, rotate_wheels, machineguns, cannons, sponsons, autocannons;					
			this.get("left_propellers", left_propellers);
			this.get("strafe_left_propellers", strafe_left_propellers);
			this.get("strafe_right_propellers", strafe_right_propellers);
			this.get("right_propellers", right_propellers);
			this.get("up_propellers", up_propellers);
			this.get("down_propellers", down_propellers);
			this.get("rotate_wheels", rotate_wheels);
			this.get("machineguns", machineguns);
			this.get("cannons", cannons);
			this.get("sponsons", sponsons);
			this.get("autocannons", autocannons);

			//propellers
			const bool teamInsensitive = ship.owner != "*"; //combined ships, every side controls their own props
			
			const u16 upPropLength = up_propellers.length;
			const u16 downPropLength = down_propellers.length;
			const u16 leftPropLength = left_propellers.length;
			const u16 rightPropLength = right_propellers.length;
			const u16 leftStrafePropLength = strafe_left_propellers.length;
			const u16 rightStrafePropLength = strafe_right_propellers.length;
			const u16 RotateWheelsLength = rotate_wheels.length;
			
			//reset			
			if (this.get_bool("kUD") && !up && !down)
			{
				this.set_bool("kUD", false);
				
				for (u16 i = 0; i < upPropLength; ++i)
				{
					CBlob@ prop = getBlobByNetworkID(up_propellers[i]);
					if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
						prop.set_f32("power", 0);
				}
				for (u16 i = 0; i < downPropLength; ++i)
				{
					CBlob@ prop = getBlobByNetworkID(down_propellers[i]);
					if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
						prop.set_f32("power", 0);
				}
				for (u16 i = 0; i < RotateWheelsLength; ++i)
				{
					CBlob@ prop = getBlobByNetworkID(rotate_wheels[i]);
					if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
						prop.set_f32("power", 0);
				}
			}
			if (this.get_bool("kLR"))
			{
				if (strafe || (!left && !right))
				{
					this.set_bool("kLR", false);
					
					for (u16 i = 0; i < leftPropLength; ++i)
					{
						CBlob@ prop = getBlobByNetworkID(left_propellers[i]);
						if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
							prop.set_f32("power", 0);
					}
					for (u16 i = 0; i < rightPropLength; ++i)
					{
						CBlob@ prop = getBlobByNetworkID(right_propellers[i]);
						if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
							prop.set_f32("power", 0);
					}
					for (u16 i = 0; i < RotateWheelsLength; ++i)
					{
						CBlob@ prop = getBlobByNetworkID(rotate_wheels[i]);
						if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
						{
							prop.set_f32("rot_angle", 0);
						}
					}
				}
			}
			if (this.get_bool("kS") || !strafe)
			{
				this.set_bool("kS", false);

				for (u16 i = 0; i < leftStrafePropLength; ++i)
				{
					CBlob@ prop = getBlobByNetworkID(strafe_left_propellers[i]);
					if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
						prop.set_f32("power", 0);
				}
				for (u16 i = 0; i < rightStrafePropLength; ++i)
				{
					CBlob@ prop = getBlobByNetworkID(strafe_right_propellers[i]);
					if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
						prop.set_f32("power", 0);
				}
			}
			
			//power to use
			f32 power, reverse_power;
			if (ship.isMothership)
			{
				power = -1.00f;
				reverse_power = 0.8f;
			}
			else
			{
				power = -1.0f;
				reverse_power = 0.8f;
			}
			
			//movement modes
			if (up || down)
			{
				this.set_bool("kUD", true);

				for (u16 i = 0; i < upPropLength; ++i)
				{	
					CBlob@ prop = getBlobByNetworkID(up_propellers[i]);
					if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
					{
						prop.set_u32("onTime", gameTime);
						prop.set_f32("power", up ? power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
					}
				}
				for (u16 i = 0; i < downPropLength; ++i)
				{
					CBlob@ prop = getBlobByNetworkID(down_propellers[i]);
					if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
					{
						prop.set_u32("onTime", gameTime);
						prop.set_f32("power", down ? power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
					}
				}
				for (u16 i = 0; i < RotateWheelsLength; ++i)
				{
					CBlob@ prop = getBlobByNetworkID(rotate_wheels[i]);
					if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
					{
						prop.set_u32("onTime", gameTime);
						prop.set_f32("power", up ? power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
					}
				}
			}
			
			if (left || right)
			{
				if (!strafe)
				{
					this.set_bool("kLR", true);

					for (u16 i = 0; i < leftPropLength; ++i)
					{
						CBlob@ prop = getBlobByNetworkID(left_propellers[i]);
						if (prop !is null && seatColor == prop.getShape().getVars().customData && !prop.hasTag("wheel") && (teamInsensitive || teamNum == prop.getTeamNum()))
						{
							prop.set_u32("onTime", gameTime);
							prop.set_f32("power", left ? power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
								
						}
					}
					for (u16 i = 0; i < rightPropLength; ++i)
					{
						CBlob@ prop = getBlobByNetworkID(right_propellers[i]);
						if (prop !is null && seatColor == prop.getShape().getVars().customData && !prop.hasTag("wheel") && (teamInsensitive || teamNum == prop.getTeamNum()))
						{
							prop.set_u32("onTime", gameTime);
							prop.set_f32("power", right ? power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
						}
					}
					
					for (u16 i = 0; i < RotateWheelsLength; ++i)
					{
						CBlob@ prop = getBlobByNetworkID(rotate_wheels[i]);
						if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
						{

							if (left)
							{
								//prop.setAngleDegrees(prop.getAngleDegrees() + (prop.hasTag("reverse_rotate") ? degree : -degree) * (down ? -1 : 1));
								if(!prop.hasTag("reverse_rotate")) prop.set_f32("rot_angle", -45);
								else prop.set_f32("rot_angle", 45);
							}			
							else
							{
								//prop.setAngleDegrees(prop.getAngleDegrees() - (prop.hasTag("reverse_rotate") ? degree : -degree) * (down ? -1 : 1));
								if(!prop.hasTag("reverse_rotate")) prop.set_f32("rot_angle", 45);
								else prop.set_f32("rot_angle", -45);
							}
						}
					}
				}
				else
				{
					this.set_bool("kS", true);
					
					const u8 maxStrafers = Maths::Round(Maths::FastSqrt(ship.mass)/3.0f);
					const u16 strLeftPropLength = strafe_left_propellers.length;
					for (u16 i = 0; i < strLeftPropLength; ++i)
					{
						CBlob@ prop = getBlobByNetworkID(strafe_left_propellers[i]);
						const f32 oDrive = i < maxStrafers ? 2.0f : 1.0f;
						if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
						{
							prop.set_u32("onTime", gameTime);
							prop.set_f32("power", left ? oDrive * power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
						}
					}
					const u16 strRightPropLength = strafe_right_propellers.length;
					for (u16 i = 0; i < strRightPropLength; ++i)
					{
						CBlob@ prop = getBlobByNetworkID(strafe_right_propellers[i]);
						const f32 oDrive = i < maxStrafers ? 2.0f : 1.0f;
						if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
						{
							prop.set_u32("onTime", gameTime);
							prop.set_f32("power", right ? oDrive * power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
						}
					}
				}
			}
			
			if (!space && !Human::isHoldingBlocks(occupier) && !Human::wasHoldingBlocks(occupier))
			{
				//rotate & fire sponsons
				Vec2f aimpos = occupier.getAimPos();
				Vec2f pos, AimVec;
				const u16 sponsonsLength = sponsons.length;
				for (u16 i = 0; i < sponsonsLength; ++i)
				{
					CBlob@ sponson = getBlobByNetworkID(sponsons[i]);;
					if(sponson !is null)
					{
						pos = sponson.getPosition();
						AimVec = aimpos - pos;
						//rotate
						CBitStream bs;
						bs.write_Vec2f(AimVec);
						sponson.SendCommand(sponson.getCommandID("rotate"), bs); //TODO: REWRITE! using commands for this is very bad
					}
				}
				//fire sponsons
				if (left_click && sponsonsLength > 0 && this.get_u32("lastSponsonFire") + SPONSON_FIRE_CYCLE < gameTime)
				{
					CBlob@[] fireSponsons;
					for (u16 i = 0; i < sponsonsLength; ++i)
					{
						CBlob@ weap = getBlobByNetworkID(sponsons[i]);
						if(weap !is null)
						{
							pos = weap.getPosition();
							AimVec = aimpos - pos;
							if (weap is null || !weap.get_bool("fire ready")) continue;
										
							Vec2f dirFacing = Vec2f(1, 0).RotateBy(weap.getAngleDegrees());
							//if (Maths::Abs(dirFacing.AngleWith(aimpos)) < 40)
								fireSponsons.push_back(weap);
						}
					}
							
					if (fireSponsons.length > 0)
					{
						const u8 index = this.get_u8("sponsonFireIndex");
						CBlob@ weap = fireSponsons[index % fireSponsons.length];
						pos = weap.getPosition();
						AimVec = aimpos - pos;
						if(weap.get_u32("fire time") + SPONSON_FIRE_RATE < getGameTime() && isClearShot(weap, AimVec))
						{
							CBitStream bs;
							bs.write_Vec2f(AimVec);
							bs.write_netid(occupier.getNetworkID());
							
							weap.SendCommand(weap.getCommandID("fire"), bs);
							this.set_u32("lastSponsonFire", gameTime);
						}
						this.set_u8("sponsonFireIndex", index + 1);
					}		
				}

				const u16 autocannonsLength = autocannons.length;
				for (u16 i = 0; i < autocannonsLength; ++i)
				{
					CBlob@ autocannon = getBlobByNetworkID(autocannons[i]);;
					if(autocannon !is null)
					{
						pos = autocannon.getPosition();
						AimVec = aimpos - pos;
						//rotate
						CBitStream bs;
						bs.write_Vec2f(AimVec);
						autocannon.SendCommand(autocannon.getCommandID("rotate"), bs);
					}
				}
				//fire autocannons
				if (left_click && autocannonsLength > 0 && this.get_u32("lastAutocannonFire") + AUTOCANNON_FIRE_CYCLE < gameTime)
				{
					CBlob@[] fireAutocannons;
					for (u16 i = 0; i < autocannonsLength; ++i)
					{
						CBlob@ weap = getBlobByNetworkID(autocannons[i]);
						if(weap !is null)
						{
							pos = weap.getPosition();
							AimVec = aimpos - pos;
							if (weap is null || !weap.get_bool("fire ready")) continue;
										
							Vec2f dirFacing = Vec2f(1, 0).RotateBy(weap.getAngleDegrees());
							//if (Maths::Abs(dirFacing.AngleWith(aimpos)) < 40)
								fireAutocannons.push_back(weap);
						}
					}
							
					if (fireAutocannons.length > 0)
					{
						const u8 index = this.get_u8("autocannonFireIndex");
						CBlob@ weap = fireAutocannons[index % fireAutocannons.length];
						pos = weap.getPosition();
						AimVec = aimpos - pos;
						if(weap.get_u32("fire time") + AUTOCANNON_FIRE_RATE < getGameTime() && isClearShot(weap, AimVec, false, true))
						{
							CBitStream bs;
							bs.write_Vec2f(AimVec);
							bs.write_netid(occupier.getNetworkID());
							
							weap.SendCommand(weap.getCommandID("fire"), bs);
							this.set_u32("lastAutocannonFire", gameTime);
						}
						this.set_u8("autocannonFireIndex", index + 1);
					}		
				
				}

				//machineguns on left click
				Vec2f aim = occupier.getAimPos() - this.getPosition();//relative to seat
				if (left_click)
				{
					const u16 machinegunsLength = machineguns.length;
					for (u16 i = 0; i < machinegunsLength; ++i)
					{
						CBlob@ weap = getBlobByNetworkID(machineguns[i]);
						if (weap is null) continue;
						
						Vec2f dirFacing = Vec2f(1, 0).RotateBy(weap.getAngleDegrees());
						if (Maths::Abs(dirFacing.AngleWith(aim)) < 40)
						{
							CBitStream bs;
							bs.write_netid(occupier.getNetworkID());
							weap.SendCommand(weap.getCommandID("fire"), bs);
						}
					}
				}
				//cannons on right click
				const u16 cannonsLength = cannons.length;
				if (right_click && cannonsLength > 0 && this.get_u32("lastCannonFire") + CANNON_FIRE_CYCLE < gameTime)
				{
					CBlob@[] fireCannons;
					
					for (u16 i = 0; i < cannonsLength; ++i)
					{
						CBlob@ weap = getBlobByNetworkID(cannons[i]);
						if (weap is null || !weap.get_bool("fire ready")) continue;
						
						Vec2f dirFacing = Vec2f(1, 0).RotateBy(weap.getAngleDegrees());
						if (Maths::Abs(dirFacing.AngleWith(aim)) < 40)
							fireCannons.push_back(weap);
					}
					
					if (fireCannons.length > 0)
					{
						const u8 index = this.get_u8("cannonFireIndex");
						CBlob@ weap = fireCannons[index % fireCannons.length];
						CBitStream bs;
						bs.write_netid(occupier.getNetworkID());
						weap.SendCommand(weap.getCommandID("fire"), bs);
						this.set_u32("lastCannonFire", gameTime);
						this.set_u8("cannonFireIndex", index + 1);
					}
				}
			}
	}
	else if (isServer() && ship.owner == seatOwner) //captain seats release rates
	{
		if ((ship.pos - ship.old_pos).Length() > 0.01f) //keep extra seats alive while the mothership moves
			this.set_u32("seatResetTime", gameTime + UNUSED_RESET);
		else //release seat faster for when captain abandons the ship
			this.set_u32("seatResetTime", Maths::Max(0, this.get_u32("seatResetTime") - 2));
	}
}

const bool isClearShot(CBlob@ blob, Vec2f&in aimVec, const bool&in targetMerged = false, const bool&in ignoreRocks = false)
{
	Vec2f pos = blob.getPosition();
	const f32 distanceToTarget = Maths::Max(aimVec.Length(), 80.0f);
	CMap@ map = getMap();

	f32 angle = aimVec.Angle();
	Vec2f offset1 = Vec2f(8.0, 1.5f);
	Vec2f offset2 = Vec2f(8.0, -1.5f);
	offset1.RotateBy(-angle);
	offset2.RotateBy(-angle);

	HitInfo@[] hitInfos;
	map.getHitInfosFromRay(pos + offset1, -angle, distanceToTarget, blob, @hitInfos);
	map.getHitInfosFromRay(pos + offset2, -angle, distanceToTarget, blob, @hitInfos);
	
	const u8 hitLength = hitInfos.length;
	if (hitLength > 0)
	{
		//HitInfo objects are sorted, first come closest hits
		for (u8 i = 0; i < hitLength; i++)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;
			if (b is null || b is blob) continue;

			const int thisColor = blob.getShape().getVars().customData;
			const int bColor = b.getShape().getVars().customData;
			
			const bool sameShip = bColor != 0 && thisColor == bColor;
			const bool canShootSelf = targetMerged && hi.distance > distanceToTarget * 0.7f;

			if (b.hasTag("block") && b.getShape().getVars().customData > 0 && !b.hasTag("non-solid") && b.getShape().getConsts().collidable && !b.hasTag("plank") && sameShip && !canShootSelf)
			{
				return false;
			}
		}
	}
	if(!ignoreRocks)
	{
		//check to make sure we aren't shooting through rock
		Vec2f solidPos;
		if (map.rayCastSolid(pos, pos + aimVec, solidPos))
		{
			AttachmentPoint@ seat = blob.getAttachmentPoint(0);
			CBlob@ occupier = seat.getOccupied();

			if (occupier is null) return false;
		}
	}

	return true;
}


//stop props on sit down if possible
void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint@ attachedPoint)
{
	if (isServer())
	{
		this.set_bool("kUD", true);
		this.set_bool("kLR", true);
		this.set_bool("kS", true);
	}
}

//keep props alive and reset wheel rotation onDetach
void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	if (isServer())
	{
		this.set_bool("kUD", false);
		this.set_bool("kLR", false);
		this.set_bool("kS", true);
	
	//reset the angles of wheels
		const int seatColor = this.getShape().getVars().customData;
		Ship@ ship = getShipSet().getShip(seatColor);
		if (ship is null) return;
		
		u16[] rotate_wheels;
		this.get("rotate_wheels", rotate_wheels);
		const u16 RotateWheelsLength = rotate_wheels.length;
		
		const bool teamInsensitive = ship.owner != "*"; //combined ships, every side controls their own props
		const u8 teamNum = this.getTeamNum();

		for (u16 i = 0; i < RotateWheelsLength; ++i)
		{
			CBlob@ prop = getBlobByNetworkID(rotate_wheels[i]);
			if (prop !is null && seatColor == prop.getShape().getVars().customData && (teamInsensitive || teamNum == prop.getTeamNum()))
			{
				prop.set_f32("rot_angle", 0);
			}
		}
	}
}

const f32 angleLimit = 0.05f;
const f32 forceLimit = 0.01f;
const f32 forceLimit_side = 0.2f;

void updateArrays(CBlob@ this, Ship@ ship)
{
	this.set_bool("updateBlock", false);

	u16[] left_propellers, strafe_left_propellers, strafe_right_propellers, right_propellers, up_propellers, down_propellers, machineguns, rotate_wheels, cannons, sponsons, autocannons;	
	const u16 blocksLength = ship.blocks.length;
	for (u16 i = 0; i < blocksLength; ++i)
	{
		ShipBlock@ ship_block = ship.blocks[i];
		if (ship_block is null) continue;

		CBlob@ block = getBlobByNetworkID(ship_block.blobID);
		if (block is null) continue;
		
		const u16 netID = block.getNetworkID();

		//machineguns
		if (block.hasTag("machinegun"))
			machineguns.push_back(netID);
		else if (block.hasTag("cannon"))
			cannons.push_back(netID);
		else if (block.hasTag("sponson"))
			sponsons.push_back(netID);
		else if (block.hasTag("autocannon"))
			autocannons.push_back(netID);
		
		else if (block.hasTag("rotates"))
			rotate_wheels.push_back(netID);
		
		//propellers
		if (block.hasTag("engine"))
		{
			Vec2f _veltemp, velNorm;
			float angleVel;
			PropellerForces(block, ship, 1.0f, _veltemp, velNorm, angleVel);


			velNorm.RotateBy(-this.getAngleDegrees());

			if (angleVel < -angleLimit || (velNorm.y < -forceLimit_side && angleVel < angleLimit))
				right_propellers.push_back(netID);
			else if (angleVel > angleLimit || (velNorm.y > forceLimit_side && angleVel > -angleLimit))
				left_propellers.push_back(netID);

			if (Maths::Abs(velNorm.x) < forceLimit)
			{
				if (velNorm.y < -forceLimit_side)
					strafe_right_propellers.push_back(netID);
				else if (velNorm.y > forceLimit_side)
					strafe_left_propellers.push_back(netID);
			}

			if (velNorm.x > forceLimit)
				down_propellers.push_back(netID);
			else if (velNorm.x < -forceLimit)
				up_propellers.push_back(netID);
		}
	}
	
	cannons.sortAsc();
	
	this.set("left_propellers", left_propellers);
	this.set("strafe_left_propellers", strafe_left_propellers);
	this.set("strafe_right_propellers", strafe_right_propellers);
	this.set("right_propellers", right_propellers);
	this.set("up_propellers", up_propellers);
	this.set("down_propellers", down_propellers);
	this.set("rotate_wheels", rotate_wheels);
	this.set("machineguns", machineguns);
	this.set("cannons", cannons);
	this.set("sponsons", sponsons);
	this.set("autocannons", autocannons);
}

void server_setOwner(CBlob@ this, const string&in owner)
{
	//print("" + this.getNetworkID() + " seat setOwner: " + owner);
	this.set_string("playerOwner", owner);
	this.Sync("playerOwner", true);
}
