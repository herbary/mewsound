#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <dhooks>

#undef REQUIRE_PLUGIN
#include <shavit/partner>
#define REQUIRE_PLUGIN

#include <mewsound/info>
#include <mewsound/util>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = {
    name = MEWSOUND_NAME,
    author = MEWSOUND_AUTHOR,
    description = MEWSOUND_DESCRIPTION,
    version = MEWSOUND_VERSION,
    url = MEWSOUND_URL
}

bool g_bLateLoaded = false;

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
    g_bLateLoaded = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    Mewsound_CreateGlobals();

    if (!g_bLateLoaded)
    {
        return;
    }
    for (int client = 1; client <= MaxClients; ++client)
    {
        if (IsClientInGame(client))
        {
            OnClientPutInServer(client);
        }
        if (AreClientCookiesCached(client))
        {
            OnClientCookiesCached(client);
        }
    }
}

public void OnClientPutInServer(int client)
{
    Mewsound_InitStateVars(client);
}

public void OnClientCookiesCached(int client)
{
    Mewsound_InitStateVars(client);
}

static void Mewsound_InitStateVars(int client)
{
}

static void Mewsound_CreateGlobals()
{
}
