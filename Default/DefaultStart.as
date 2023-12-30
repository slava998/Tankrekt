// default startup functions for autostart scripts

void RunServer()
{
	if (getNet().CreateServer())
	{
		LoadRules("Rules/Shiprekt/gamemode.cfg");

		LoadMapCycle("Rules/Shiprekt/mapcycle.cfg");

		LoadNextMap();
	}
}

void ConnectLocalhost()
{
	getNet().Connect("localhost", sv_port);
}

void RunLocalhost()
{
	RunServer();
	ConnectLocalhost();
}

void LoadDefaultMenuMusic()
{
	// nothing
}
