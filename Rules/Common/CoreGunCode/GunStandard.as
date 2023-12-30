//////////////////////////////////////////////////////
//
//  GunStandard.as - Vamist
//

void shootGun(const u16&in gunID, const f32&in aimangle, const Vec2f&in pos) 
{
	CRules@ rules = getRules();
	CBitStream params;

	params.write_netid(gunID);
	params.write_f32(aimangle);
	params.write_Vec2f(pos);
	params.write_u32(getGameTime());

	rules.SendCommand(rules.getCommandID("fireGun"), params);
}

/*void shootShotgun(const u16&in gunID, const f32&in aimangle, const Vec2f&in pos) 
{
	CRules@ rules = getRules();
	CBitStream params;

	params.write_netid(gunID);
	params.write_f32(aimangle);
	params.write_Vec2f(pos);
	params.write_u32(getGameTime());

	rules.SendCommand(rules.getCommandID("fireShotgun"), params);
}*/
