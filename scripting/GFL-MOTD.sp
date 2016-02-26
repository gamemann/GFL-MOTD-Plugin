#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define VPPADSURL "http://vppgamingnetwork.com/Client/Content/1151"

public Plugin myinfo =
{
	name = "[GFL] MOTD Links",
	author = "Roy (Christian Deacon)",
	description = "Choices which MOTD shows for each player.",
	version = "1.0.0",
	url = "http://GFLClan.com/"
};

/* ConVars. */
Handle g_hNormalMOTD = null;

/* ConVar Values. */
char g_sNormalMOTD[MAX_NAME_LENGTH];

public void OnPluginStart()
{
	/* ConVars. */
	g_hNormalMOTD = CreateConVar("sm_gfl_motdlink", "http://GFLClan.com", "The link to the MOTD Members+ will be able to see.");
	
	/* Changes. */
	HookConVarChange(g_hNormalMOTD, CVarChanged);
	
	/* Commands. */
	RegConsoleCmd("sm_ads", Command_Ads);
	
	/* Load the translations file. */
	LoadTranslations("gflmotd.phrases.txt");
	
	/* Execute a config. */
	AutoExecConfig(true, "plugin.gfl-motd");
}

public void CVarChanged(Handle hCVar, const char[] sOldV, const char[] sNewV)
{
	OnConfigsExecuted();
}

public void OnConfigsExecuted()
{
	/* Receive the new ConVar values. */
	GetConVarString(g_hNormalMOTD, g_sNormalMOTD, sizeof(g_sNormalMOTD));
}

public void OnClientPutInServer(int iClient)
{
	/* Check whether the player is a Member+ or not. */
	if (HasPermission(iClient, "t"))
	{
		/* User is a member. Use the NormalMOTD ConVar's value as the MOTD link. */
		ShowMOTDPanel(iClient, "GFLClan.com", g_sNormalMOTD, MOTDPANEL_TYPE_URL);
	}
	else
	{
		/* User isn't a Member+. Give them the ads link. */
		ShowMOTDPanel(iClient, "Apply for Membership @ GFLClan.com to remove MOTD ads!", VPPADSURL, MOTDPANEL_TYPE_URL);
	}
}

/* Command: sm_ads (Displays the ad MOTD window). */
public Action Command_Ads(int iClient, int iArgs)
{
	/* Display the ads window. */
	ShowMOTDPanel(iClient, "Thank you for supporting us!", VPPADSURL, MOTDPANEL_TYPE_URL);
	
	/* Reply to the client. */
	CReplyToCommand(iClient, "%t", "AdSupport");
	
	return Plugin_Handled;
}

/* Snippet found from lab.gflclan.com. */
stock bool HasPermission(int iClient, char[] sFlagString) 
{
	if (StrEqual(sFlagString, "")) 
	{
		return true;
	}
	
	AdminId eAdmin = GetUserAdmin(iClient);
	
	if (eAdmin == INVALID_ADMIN_ID)
	{
		return false;
	}
	
	int iFlags = ReadFlagString(sFlagString);

	if (CheckAccess(eAdmin, "", iFlags, true))
	{
		return true;
	}

	return false;
}