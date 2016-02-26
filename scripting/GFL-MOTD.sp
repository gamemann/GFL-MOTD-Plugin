#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define VPPADSURL "http://vppgamingnetwork.com/Client/Content/1151"

public Plugin myinfo =
{
	name = "[GFL] MOTD Links",
	author = "Roy (Christian Deacon) and Peace-Maker",
	description = "Dynamic MOTD links.",
	version = "1.0.0",
	url = "http://GFLClan.com/"
};

/* Other Variables. */
Handle g_hDefaultMOTD[MAXPLAYERS+1];
bool g_bNoMOTDYet[MAXPLAYERS+1];

public void OnPluginStart()
{
	/* Set up the user messages. */
	UserMsg VGUIMenu = GetUserMessageId("VGUIMenu");
	
	if (VGUIMenu == INVALID_MESSAGE_ID)
	{
		SetFailState("Failed to find VGUIMenu UserMsg.");
	}
	
	HookUserMessage(VGUIMenu, OnMsgVGUIMenu, true);
	
	/* Commands. */
	RegConsoleCmd("sm_ads", Command_Ads);
	
	/* Load the translations file. */
	LoadTranslations("gflmotd.phrases.txt");
	
	/* Execute a config. */
	//AutoExecConfig(true, "plugin.gfl-motd");
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
	if (HasPermission(iClient, "t"))
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
	/* Display the ads window. */
	//FrameHook_AfterMOTD(GetClientSerial(iClient));
	
	/* Reply to the client. */
	CReplyToCommand(iClient, "%t", "AdSupport");
	
	return Plugin_Handled;
}

/* The MOTD User Message. */
public Action:OnMsgVGUIMenu(UserMsg msg_id, Handle hSelf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
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
 
	// Remember the key value data of this vguimenu. That way we can display the old motd, if the client isn't authenticated yet.
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
		if (HasPermission(iClient, "t"))
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
 
	/* Craft a nice fake MOTD. */
	Handle hKV = CreateKeyValues("data");
 
	/* This is to open the team selection menu or whatever the game normally does after the MOTD. */
	char sCloseCommand[32];
	KvGetString(g_hDefaultMOTD[iClient], "cmd", sCloseCommand, sizeof(sCloseCommand));
	KvSetString(hKV, "cmd", sCloseCommand);
 
	KvSetString(hKV, "msg", VPPADSURL);
	KvSetString(hKV, "title", "Apply for Membership @ GFLClan.com to remove MOTD ads!");
	KvSetNum(hKV, "type", MOTDPANEL_TYPE_URL);
 
	ShowVGUIPanel(iClient, "info", hKV);
	
	delete(hKV);
}

/* Displays the defualt MOTD. */
ShowDefaultMOTD(int iClient)
{
	if(g_hDefaultMOTD[iClient] != null)
	{
		// Show the default motd.txt
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