
void onInit(CRules@ this)
{
	this.addCommandID("Csync");
}

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
	if(!isClient()) return;
    if (cmd == this.getCommandID("Csync"))
    {
		u8 num;
		if (!params.saferead_u8(num))
			return;
			
		string var;
		if (!params.saferead_string(var))
			return;
			
		u32 ID;
		if (!params.saferead_netid(ID))
			return;

		CBlob@ b = getBlobByNetworkID(ID);
		print("sync |" + var + "| " + num);
		if(b is null)
		{
			warn("Sync: blob is null! netID: " + ID);
			return;
		}
		
		switch(num)
		{
			case 0: //u8
			{
				u8 value;
				if (params.saferead_u8(value))
					b.set_u8(var, value);
				//print("u8");
				break;
			}
			case 1: //u16
			{
				u16 value;
				if (params.saferead_u16(value))
					b.set_u16(var, value);
				//print("u16");
				break;
			}
			case 2: //u32
			{
				u32 value;
				if (params.saferead_u32(value))
					b.set_u32(var, value);
				//print("u32");
				break;
			}
			case 3: //f32
			{
				f32 value;
				if (params.saferead_f32(value))
					b.set_f32(var, value);
				print("f32");
				break;
			}
			case 4: //bool
			{
				bool value;
				if (params.saferead_bool(value))
					b.set_bool(var, value);
				//print("bool");
				break;
			}
			case 5: //string
			{
				string value;
				if (params.saferead_string(value))
					b.set_string(var, value);
				//print("str");
				break;
			}
			case 6: //tag
			{
				bool value;
				if(!params.saferead_bool(value)) return;
				if(value) b.Tag(var);
				else b.Untag(var);
				//print("tag");
				break;
			}
		}
	}
}