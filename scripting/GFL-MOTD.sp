#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATEURL "http://updater.gflclan.com/GFL-MOTD.txt"
#define REDIRECTURL "http://fastdl.gflclan.com/redirect.html"
//#define DEBUG

public Plugin myinfo =
{
	name = "[GFL] MOTD Links",
	author = "Roy (Christian Deacon) and Peace-Maker",
	description = "Dynamic MOTD links.",
	version = "1.0.3",
	url = "http://GFLClan.com/"
};

/* Client Cookies. */
Handle g_hOverrideAds = null;

/* Cookie Values. */
bool g_bOverrideAds[MAXPLAYERS+1];

/* Other Variables. */
Handle g_hDefaultMOTD[MAXPLAYERS+1];
bool g_bNoMOTDYet[MAXPLAYERS+1];
char g_sURL[256];
int g_iAdType = 2;	/* 1 = VPP, 2 = MOTDGD, ... */
Handle g_hServerIP = null;
Handle g_hServerPort = null;
int g_iServerIP;
int g_iServerPort;
char g_sFullServerIP[16];
char g_sGameDir[MAX_NAME_LENGTH];

public void OnPluginStart()
{
	/* Add the updater to the plugin. */
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATEURL);
	}
	
	/* Set up the user messages. */
	UserMsg VGUIMenu = GetUserMessageId("VGUIMenu");
	
	if (VGUIMenu == INVALID_MESSAGE_ID)
	{
		SetFailState("Failed to find VGUIMenu UserMsg.");
	}
	
	HookUserMessage(VGUIMenu, OnMsgVGUIMenu, true);
	
	/* Client Cookies. */
	g_hOverrideAds = RegClientCookie("gflmotd_override", "Overrides Members+ with advertisements if they would like.", CookieAccess_Protected);
	SetCookieMenuItem(CookieMenuHandler, 0, "Override Adverts Toggle"); 
	
	/* Cookies Late Loading. */
	for (int i = MaxClients; i > 0; --i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		
		OnClientCookiesCached(i);
	}
	
	/* Commands. */
	RegConsoleCmd("sm_ads", Command_Ads);
	RegConsoleCmd("sm_motdtest", Command_MOTDTest);
	RegConsoleCmd("sm_overrideads", Command_OverrideAds);
	
	/* Load the translations file. */
	LoadTranslations("gflmotd.phrases.txt");
	
	/* Get the Server's IP and Port. */
	g_hServerIP = FindConVar("hostip");
	g_hServerPort = FindConVar("hostport");
		
	if (g_hServerIP != null && g_hServerPort != null)
	{
		g_iServerIP = GetConVarInt(g_hServerIP);
		g_iServerPort = GetConVarInt(g_hServerPort);
			
		Format(g_sFullServerIP, sizeof(g_sFullServerIP), "%d.%d.%d.%d", g_iServerIP >>> 24 & 255, g_iServerIP >>> 16 & 255, g_iServerIP >>> 8 & 255, g_iServerIP & 255);
	}
	
	/* Get the Server's Game Directory. */
	GetGameFolderName(g_sGameDir, sizeof(g_sGameDir));
	
	/* Execute a config. */
	//AutoExecConfig(true, "plugin.gfl-motd");
}

/* The Cookie Menu handler. */
public void CookieMenuHandler(int iClient, CookieMenuAction action, any info, char[] sBuffer, int iMaxLen)
{
	switch (action)
	{
		case CookieMenuAction_DisplayOption:
		{
		}

		case CookieMenuAction_SelectOption:
		{
			if (HasPermission(iClient, "t"))
			{
				/* Check whether overriding is enabled/disabled. */
				if (g_bOverrideAds[iClient])
				{
					/* Set the cookie's value. */
					SetClientCookie(iClient, g_hOverrideAds, "0");
					
					/* Set the bool to false. */
					g_bOverrideAds[iClient] = false;
					
					/* Reply to the client. */
					CPrintToChat(iClient, "%t%t", "Tag", "OverrideDisabled");
				}
				else
				{
					/* Set the cookie's value. */
					SetClientCookie(iClient, g_hOverrideAds, "1");
					
					/* Set the bool to true. */
					g_bOverrideAds[iClient] = true;
					
					/* Reply to the client. */
					CPrintToChat(iClient, "%t%t", "Tag", "OverrideEnabled");
				}
				
				/* Refresh the cookie value. */
				OnClientCookiesCached(iClient);
			}
			else
			{
				CPrintToChat(iClient, "%t%t", "Tag", "NotAMember");
			}
		}
	}
}

/* Handle the cookies. */
public void OnClientCookiesCached(int iClient)
{
	/* Receive the client's cookie. */
	char sValue[8];
	GetClientCookie(iClient, g_hOverrideAds, sValue, sizeof(sValue));
	
	/* Set the value. If the cookie is defined and the value is 1, set the override to true for the specific client. */
	g_bOverrideAds[iClient] = (sValue[0] != '\0' && StringToInt(sValue));
}

/* Add the updater to the plugin. */
public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "updater", false))
	{
		Updater_AddPlugin(UPDATEURL);
	}
}
/* Called when a client is authorized. */
public void OnClientPostAdminCheck(int iClient)
{
	/* Check to see if the client has seen the MOTD yet. */
	if (!g_bNoMOTDYet[iClient])
	{
		return;
	}
	
	g_bNoMOTDYet[iClient] = false;
	
	/* Check whether the player is a Member+ or not. */
	if (HasPermission(iClient, "t") && !g_bOverrideAds[iClient])
	{
		/* User is a member. Use the NormalMOTD ConVar's value as the MOTD link. */
		ShowDefaultMOTD(iClient);
	}
	else
	{
		/* User isn't a Member+. Give them the ads link. */
		FrameHook_AfterMOTD(GetClientSerial(iClient));
	}
}

/* Called when a client disconnects. */
public void OnClientDisconnect(int iClient)
{
	/* Set the client's index value back to default for the next client. */
	g_bNoMOTDYet[iClient] = false;
	
	if (g_hDefaultMOTD[iClient] != null)
	{
		delete(g_hDefaultMOTD[iClient]);
		g_hDefaultMOTD[iClient] = null;
	}
}

/* Command: sm_ads (Displays the ad MOTD window). */
public Action Command_Ads(int iClient, int iArgs)
{
	/* Refresh the URL. */
	FormatURL(iClient);
	
	/* Set the URL. */
	char sURL[256];
	Format(sURL, sizeof(sURL), "%s?url=%s", REDIRECTURL, g_sURL);
	
	PrintToServer("Ad URL: %s", sURL);
	
	/* Display the ads window. */
	ShowMOTDPanel(iClient, "Thank you for supporting us!", sURL, MOTDPANEL_TYPE_URL);
	
	/* Reply to the client. */
	CReplyToCommand(iClient, "%t%t", "Tag", "AdSupport");
	
	return Plugin_Handled;
}

/* Command: sm_motdtest (Test for Peace-Maker!). */
public Action Command_MOTDTest(int iClient, int iArgs)
{
	ShowMOTDPanel(iClient, "Test", "Hi, you got HTML MOTDs disabled :'(", MOTDPANEL_TYPE_TEXT);
	
	return Plugin_Handled;
}

/* Command: sm_overrideads (Overrides the ads for the client if a Member+!). */
public Action Command_OverrideAds(int iClient, int iArgs)
{
	if (!HasPermission(iClient, "t"))
	{
		CReplyToCommand(iClient, "%t%t", "Tag", "NotAMember");
		
		return Plugin_Handled;
	}
	
	/* Enable/Disable Ads. */
	if (g_bOverrideAds[iClient])
	{
		/* Set the cookie's value. */
		SetClientCookie(iClient, g_hOverrideAds, "0");
		
		/* Set the bool to false. */
		g_bOverrideAds[iClient] = false;
		
		/* Reply to the client. */
		CReplyToCommand(iClient, "%t%t", "Tag", "OverrideDisabled");
	}
	else
	{
		/* Set the cookie's value. */
		SetClientCookie(iClient, g_hOverrideAds, "1");
		
		/* Set the bool to true. */
		g_bOverrideAds[iClient] = true;
		
		/* Reply to the client. */
		CReplyToCommand(iClient, "%t%t", "Tag", "OverrideEnabled");
	}
	
	return Plugin_Handled;
}

/* The MOTD User Message. */
public Action OnMsgVGUIMenu(UserMsg msg_id, Handle hSelf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	#if defined DEBUG then
		/* Log a message. */
		LogMessage("OnMsgVGUIMenu() executed.");
	#endif
	
	int iClient = iPlayers[0];
	
	/* Check if the player(s) are valid. */
	if (iPlayersNum > 1 || !IsClientInGame(iClient) || IsFakeClient(iClient))
	{
		return Plugin_Continue;
	}
 
	/* Only focus on the first MOTD. */
	if(g_hDefaultMOTD[iClient] != null)
	{
		return Plugin_Continue;
	}
 
	char sBuffer[64];
	
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbReadString(hSelf, "name", sBuffer, sizeof(sBuffer));
	}
	else
	{
		BfReadString(hSelf, sBuffer, sizeof(sBuffer));
	}
	
	if (strcmp(sBuffer, "info") != 0)
	{
		return Plugin_Continue;
	}
 
	if (GetUserMessageType() != UM_Protobuf)
	{
		BfReadByte(hSelf);
	}
 
	/* Remember the key value data of this vguimenu. That way we can display the old motd, if the client isn't authenticated yet. */
	Handle hKV = CreateKeyValues("data");
 
	if (GetUserMessageType() == UM_Protobuf)
	{
		char sKey[128], sValue[128];
		
		int iCount = PbGetRepeatedFieldCount(hSelf, "subkeys");
		
		for (int i = 0; i < iCount; i++)
		{
			Handle hSubKey = PbReadRepeatedMessage(hSelf, "subkeys", i);
			PbReadString(hSubKey, "name", sKey, sizeof(sKey));
			PbReadString(hSubKey, "str", sValue, sizeof(sValue));
			KvSetString(hKV, sKey, sValue);
			
			#if defined DEBUG then
				LogMessage("%s: %s", sKey, sValue);
			#endif
		}
	}
	else
	{
		int iKeyCount = BfReadByte(hSelf);
		char sKey[128], sValue[128];
		
		while(iKeyCount-- > 0)
		{
			BfReadString(hSelf, sKey, sizeof(sKey), true);
			BfReadString(hSelf, sValue, sizeof(sValue), true);
			KvSetString(hKV, sKey, sValue);
		}
	}
	
	KvRewind(hKV);
 
	g_hDefaultMOTD[iClient] = hKV;
 
	/**
	TODO: Check if the sent filename in the motd is motd_text.txt
	Players have html motds disabled in that case, 
	so you won't show any normal motds anyway, 
	so you can stop bothering and just let it through.
	**/
	if (IsClientAuthorized(iClient))
	{
		/* This is a Member - show him the default motd.txt. */
		if (HasPermission(iClient, "t") && !g_bOverrideAds[iClient])
		{
			return Plugin_Continue;
		}
 
		/* This isn't a member. Show him some ads. Can't start another usermessage in this hook -> wait a frame. */
		RequestFrame(FrameHook_AfterMOTD, GetClientSerial(iClient));
		
		/* Block default motd.txt */
		return Plugin_Handled;
	}
	else
	{
		g_bNoMOTDYet[iClient] = true;
	}
 
	/* Block the default MOTD. */
	return Plugin_Handled;
}

/* The frame after the MOTD. */
public void FrameHook_AfterMOTD(any serial)
{
	int iClient = GetClientFromSerial(serial);
	
	if (!iClient)
	{
		return;
	}
	
	/* Format the URL. */
	FormatURL(iClient);
 
	/* Craft a nice fake MOTD. */
	Handle hKV = CreateKeyValues("data");
 
	/* This is to open the team selection menu or whatever the game normally does after the MOTD. */
	char sCloseCommand[32];
	KvGetString(g_hDefaultMOTD[iClient], "cmd", sCloseCommand, sizeof(sCloseCommand));
	KvSetString(hKV, "cmd", sCloseCommand);
 
	KvSetString(hKV, "msg", g_sURL);
	
	char sTitle[256];
	Format(sTitle, sizeof(sTitle), "%t", "RemoveAds");
	
	KvSetString(hKV, "title", sTitle);
	KvSetNum(hKV, "type", MOTDPANEL_TYPE_URL);
 
	ShowVGUIPanel(iClient, "info", hKV);
	
	delete(hKV);
}

/* Displays the defualt MOTD. */
ShowDefaultMOTD(int iClient)
{
	if(g_hDefaultMOTD[iClient] != null)
	{
		/* Show the default motd.txt. */
		ShowVGUIPanel(iClient, "info", g_hDefaultMOTD[iClient]);
	}
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

/* Formats the Ad URL. */
stock void FormatURL(int iClient)
{
	if (g_iAdType == 1)
	{
		/* VPP Ads. */
		Format(g_sURL, sizeof(g_sURL), "http://vppgamingnetwork.com/Client/Content/1151");
	}
	else if (g_iAdType == 2)
	{
		/* MOTDGD Ads. */
		
		/* We must get some information first. */	
		/* Now get the client's username and Steam ID. */
		char sSteamID[64];
		char sName[MAX_NAME_LENGTH];
		char sNameEncoded[MAX_NAME_LENGTH * 2];
		
		bool bGotSteamID = GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));
		
		GetClientName(iClient, sName, sizeof(sName));
		urlencode(sName, sNameEncoded, sizeof(sNameEncoded));
			
		/* Finally, format the URL. */
		if (bGotSteamID)
		{
			Format(g_sURL, sizeof(g_sURL), "http://motdgd.com/motd/?user=9038&ip=%s&pt=%d&v=2.3.5&st=%s&gm=%s&name=%s", g_sFullServerIP, g_iServerPort, sSteamID, g_sGameDir, sNameEncoded);
		}
		else
		{
			Format(g_sURL, sizeof(g_sURL), "http://motdgd.com/motd/?user=9038&ip=%s&pt=%d&v=2.3.5&gm=%s&name=%s", g_sFullServerIP, g_iServerPort, g_sGameDir, sNameEncoded);
		}
			
	}
	
	#if defined DEBUG then
		/* Log a message. */
		LogMessage("Formatting URL: %s", g_sURL);
	#endif
}

/* Found from the MOTDGD plugin. Though, I did reformat it for the new SourceMod syntax. */
stock void urlencode(const char[] sString, char[] sResult, int iLen)
{
	char[] sHexTable = "0123456789abcdef";
	int from, c;
	int to;

	while(from < iLen)
	{
		c = sString[from++];
		
		if(c == 0)
		{
			sResult[to++] = c;
			break;
		}
		else if(c == ' ')
		{
			sResult[to++] = '+';
		}
		else if((c < '0' && c != '-' && c != '.') ||
				(c < 'A' && c > '9') ||
				(c > 'Z' && c < 'a' && c != '_') ||
				(c > 'z'))
		{
			if((to + 3) > iLen)
			{
				sResult[to] = 0;
				break;
			}
			sResult[to++] = '%';
			sResult[to++] = sHexTable[c >> 4];
			sResult[to++] = sHexTable[c & 15];
		}
		else
		{
			sResult[to++] = c;
		}
	}
}  