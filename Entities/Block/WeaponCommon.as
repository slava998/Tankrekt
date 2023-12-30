#include "ShipsCommon.as";

// Refill ammunition for weapons
shared void refillAmmo(CBlob@ this, Ship@ ship, const u8&in refillAmount, const u8&in refillSeconds, const u8&in refillSecondaryCore, const u8&in refillSecondaryCoreSeconds)
{
	if (!isServer()) return;
	
	u16 ammo = this.get_u16("ammo");
	const u16 maxAmmo = this.get_u16("maxAmmo");

	if (ammo < maxAmmo)
	{
		if (ship.isMothership || ship.isStation)
		{
			const u8 dockedFactor = this.get_bool("docked") ? 1 : 2; //docked miniships refill faster
			if (getGameTime() % (30 * refillSeconds * dockedFactor) == 0)
			{
				ammo = Maths::Min(maxAmmo, ammo + refillAmount);
			}
		}
		else if (ship.isSecondaryCore)
		{
			if (getGameTime() % (35 * refillSecondaryCoreSeconds) == 0)
			{
				ammo = Maths::Min(maxAmmo, ammo + refillSecondaryCore);
			}
		}

		this.set_u16("ammo", ammo);
		this.Sync("ammo", true);
	}
}

// Check if the weapon is connected to a mothership through couplings (docked miniship)
shared void checkDocked(CBlob@ this, Ship@ ship)
{
	if (!isServer() || !this.get_bool("updateBlock")) return;
	
	const u32 gameTime = getGameTime();
	if ((gameTime + this.getNetworkID() * 33) % 30 == 0)
	{
		if (ship.isMothership && !ship.isStation)
		{
			CBlob@ core = getMothership(this.getTeamNum());
			u16[] checked, unchecked;
			this.set_bool("docked", core !is null ? !shipLinked(this, core, checked, unchecked) : false);
		}
		else
			this.set_bool("docked", false);

		this.Sync("docked", true); //-169657557 HASH
		this.set_bool("updateBlock", false);
	}
}
