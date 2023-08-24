#include <sourcemod>
#include <sdktools_sound>
#include <geoip>

#pragma newdecls required
#pragma semicolon 1

#define CD_VERSION "3.0"

ConVar g_hVersion						   = null;
ConVar g_hPrintMode						   = null;
ConVar g_hShowAll						   = null;
ConVar g_hSound							   = null;
ConVar g_hPrintCountry					   = null;
ConVar g_hShowAdmins					   = null;
ConVar g_hCountryAbbr					   = null;
ConVar g_hSoundFile						   = null;
ConVar g_hLogging						   = null;

char   g_sSoundFilePath[PLATFORM_MAX_PATH] = "buttons/blip1.wav";
int	   g_iLogging						   = 1;

public Plugin myinfo =
{
	name		= "CD Announcer",
	author		= "Fredd, gH0sTy, MOPO3KO, Monera",
	description = "",
	version		= CD_VERSION,
	url			= "www.sourcemod.net"


}

public void OnPluginStart()
{
	LoadTranslations("cdannouncer.phrases");
	g_hVersion		= CreateConVar("cd_announcer_version", CD_VERSION, "Connect/Disconnect Announcer Version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);

	g_hPrintMode	= CreateConVar("cd_mode", "0", "1 = by SteamId, 2 = by Ip, 3 = ip and SteamId, 0 = No ip and SteamId (Def 1)", 0, true, 0.0, true, 4.0);
	g_hShowAll		= CreateConVar("cd_showall", "1", "1 = show connection only, 2 = show disconnection only, 3 = show both", 0, true, 1.0, true, 3.0);
	g_hSound		= CreateConVar("cd_sound", "1", "Toggles sound on and off (Def 1 = on)", 0, true, 0.0, true, 1.0);
	g_hPrintCountry = CreateConVar("cd_printcountry", "1", "turns on/off priting country names 0 = off, 1= on (Def 1)", 0, true, 0.0, true, 1.0);
	g_hShowAdmins	= CreateConVar("cd_showadmins", "1", "Shows Admins on connect/disconnect, 0= don't show, 1 = show (Def 1)", 0, true, 0.0, true, 1.0);
	g_hCountryAbbr	= CreateConVar("cd_country_abbr", "0", "If enabled, country names are printed in shorthand (Def 1)", 0, true, 0.0, true, 1.0);
	g_hSoundFile	= CreateConVar("cd_sound_file", "buttons/blip1.wav", "Sound file location to be played on a connect/disconnect under the sounds directory (Def =buttons/blip1.wav)");
	g_hLogging		= CreateConVar("cd_loggin", "3", "1 = PrintToChat only, 2 = Logging only, 3 = Both (Def 3)", _, true, 1.0, true, 3.0);
	
	HookConVarChange(g_hLogging, OnLoggingChange);
	HookConVarChange(g_hSoundFile, OnSoundFileChange);

	AutoExecConfig(true, "CD_Announcer");
}

public void OnLoggingChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iLogging = StringToInt(newValue);
}

public void OnSoundFileChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	strcopy(g_sSoundFilePath, sizeof(g_sSoundFilePath), newValue);
}

stock void LogCDMessage(const char[] message, any...)
{
	int iSize				 = strlen(message) + 255;
	char[] sFormattedMessage = new char[iSize];
	VFormat(sFormattedMessage, iSize, message, 2);

	char sFileName[PLATFORM_MAX_PATH];
	char sDate[16];
	FormatTime(sDate, sizeof(sDate), "%F");
	BuildPath(Path_SM, sFileName, sizeof(sFileName), "logs/CD_%s.log", sDate);

	LogToFile(sFileName, sFormattedMessage);
}

public void OnConfigsExecuted()
{
	g_iLogging = g_hLogging.IntValue;
	g_hSoundFile.GetString(g_sSoundFilePath, sizeof(g_sSoundFilePath));
}

public void OnMapStart()
{
	char sPath[PLATFORM_MAX_PATH];
	GetConVarString(g_hSoundFile, sPath, sizeof(sPath));

	if (sPath[0] == '\0')
	{
		return;
	}
	else if (FileExists(sPath, true))
	{
		PrecacheSound(sPath, true);
	}
	else
	{
		LogMessage("%t %s", "File Not Found", sPath);
	}
}

stock const char g_sConnected[4][2][] =
{
	{
		"Connected",
		"Connected_Country"
	},
	{
		"Connected_Auth",
		"Connected_Auth_Country"
	},
	{
		"Connected_IP",
		"Connected_Country_IP"
	},
	{
		"Connected_Auth_IP",
		"Connected_Auth_Country_IP"
	}
};

public void OnClientPostAdminCheck(int client)
{
	Announce(client, 0, g_sConnected[g_hPrintMode.IntValue % 4][g_hPrintCountry.IntValue % 2], "connected");
}

stock const char g_sDisconnected[4][2][] =
{
	{
		"Disconnected",
		"Disconnected_Country"
	},
	{
		"Disconnected_Auth",
		"Disconnected_Auth_Country"
	},
	{
		"Disconnected_IP",
		"Disconnected_Country_IP"
	},
	{
		"Disconnected_Auth_IP",
		"Disconnected_Auth_Country_IP"
	}
};

public void OnClientDisconnect(int client)
{
	Announce(client, 1, g_sDisconnected[g_hPrintMode.IntValue % 4][g_hPrintCountry.IntValue % 2], "disconnected");
}

stock void Announce(int client, int type, const char[] translation, const char[] message)
{
	if (IsFakeClient(client))
	{
		return;
	}
	else if (!(g_hShowAll.IntValue & (1 << type)))
	{
		return;
	}
	else if(GetUserAdmin(client) != INVALID_ADMIN_ID && !g_hShowAdmins.BoolValue)
	{
		return;
	}

	char name[MAX_NAME_LENGTH];
	char ip[16];
	char auth[24];
	char country[48];

	GetClientName(client, name, sizeof(name));
	GetClientIP(client, ip, sizeof(ip));
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

	GetCountryString(ip, country, sizeof(country));
	if (country[0] == '\0')
	{
		Format(country, sizeof(country), "%t", "Network");
	}

	if (g_hSound.BoolValue)
	{
		EmitSoundToAll(g_sSoundFilePath);
	}

	if (g_iLogging & (1 << 0))
	{
		PrintToChatAll("%t", translation, name, auth, country, ip);
	}
	if (g_iLogging & (1 << 1))
	{
		LogCDMessage("%s(%s)[%s][%s] %s", name, auth, country, ip, message);
	}
}

stock void GetCountryString(const char[] ip, char[] country, int maxlength)
{
	if (g_hCountryAbbr.BoolValue)
	{
		char sCountryAbbr[3];
		GeoipCode2(ip, sCountryAbbr);
		strcopy(country, maxlength, sCountryAbbr);
	}
	else
	{
		GeoipCountry(ip, country, maxlength);
	}
}