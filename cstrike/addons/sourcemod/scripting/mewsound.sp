#include <sourcemod>
#include <clientprefs>
#include <string>
#include <sdktools>
#include <dhooks>

#undef REQUIRE_PLUGIN
#include <shavit/partner>
#define REQUIRE_PLUGIN

#include <mewsound/info>
#include <mewsound/util>
#include <mewsound/menu>
#include <mewsound/cookie>

#pragma newdecls required
#pragma semicolon 1

#define _MEWSOUND_TICK_UNKNOWN -1
#define _MEWSOUND_ENTITY_UNKNOWN -1
#define _MEWSOUND_PARTNER_UNKNOWN -1

public Plugin myinfo = {
    name = MEWSOUND_NAME,
    author = MEWSOUND_AUTHOR,
    description = MEWSOUND_DESCRIPTION,
    version = MEWSOUND_VERSION,
    url = MEWSOUND_URL
}

bool g_bLateLoaded = false;

Cookie g_ckSoundscapes;
Cookie g_ckAmbientSounds;
Cookie g_ckTriggerSounds;
Cookie g_ckNormalSounds;
Cookie g_ckHurtSounds;
Cookie g_ckWeaponSounds;
Cookie g_ckKnifeSounds;
Cookie g_ckRadioSounds;
Cookie g_ckRadioMessages;

int g_iSoundscapes[MAXPLAYERS + 1];
int g_iAmbientSounds[MAXPLAYERS + 1];
int g_iTriggerSounds[MAXPLAYERS + 1];
int g_iNormalSounds[MAXPLAYERS + 1];
int g_iHurtSounds[MAXPLAYERS + 1];
int g_iWeaponSounds[MAXPLAYERS + 1];
int g_iKnifeSounds[MAXPLAYERS + 1];
int g_iRadioSounds[MAXPLAYERS + 1];
int g_iRadioMessages[MAXPLAYERS + 1];

char g_szSoundscapesModes[MEWSOUND_COOKIE_VALUE_SOUNDSCAPES_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szAmbientSoundsModes[MEWSOUND_COOKIE_VALUE_AMBIENT_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szTriggerSoundsModes[MEWSOUND_COOKIE_VALUE_TRIGGER_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szNormalSoundsModes[MEWSOUND_COOKIE_VALUE_NORMAL_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szHurtSoundsModes[MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szWeaponSoundsModes[MEWSOUND_COOKIE_VALUE_WEAPON_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szKnifeSoundsModes[MEWSOUND_COOKIE_VALUE_KNIFE_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szRadioSoundsModes[MEWSOUND_COOKIE_VALUE_RADIO_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szRadioMessagesModes[MEWSOUND_COOKIE_VALUE_RADIO_MESSAGES_COUNT][MEWSOUND_MENU_ITEM_SIZE];

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
    g_bLateLoaded = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    Mewsound_CreateGlobals();
    Mewsound_CreateCookies();
    Mewsound_CreateCommands();
    Mewsound_HookEvents();

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

static int Mewsound_GetPartner(int client)
{
    if (GetFeatureStatus(FeatureType_Native, "Timer_GetPartner") != FeatureStatus_Available)
    {
        return _MEWSOUND_PARTNER_UNKNOWN;
    }

    int partner = Timer_GetPartner(client);
    if (!Mewsound_IsClient(partner))
    {
        return _MEWSOUND_PARTNER_UNKNOWN;
    }

    return partner;
}

static Action Command_Sound(int client, int argc)
{
    if (!Mewsound_IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    Menu_Sound(client, 0);
    return Plugin_Handled;
}

static void Menu_Sound(int client, int position)
{
    if (!Mewsound_IsClientInGame(client))
    {
        return;
    }

    Menu menu = new Menu(MenuHandler_Sound);
    menu.SetTitle("Sound Manager\n ");

    char szItem[MEWSOUND_MENU_ITEM_SIZE];

    // Soundscapes
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_SOUNDSCAPES_FMT, g_szSoundscapesModes[g_iSoundscapes[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_SOUNDSCAPES, szItem, ITEMDRAW_DISABLED);

    // Ambient Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_AMBIENT_SOUNDS_FMT, g_szAmbientSoundsModes[g_iAmbientSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_AMBIENT_SOUNDS, szItem, ITEMDRAW_DISABLED);

    // Trigger Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_TRIGGER_SOUNDS_FMT, g_szTriggerSoundsModes[g_iTriggerSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_TRIGGER_SOUNDS, szItem, ITEMDRAW_DISABLED);

    // Normal Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_NORMAL_SOUNDS_FMT, g_szNormalSoundsModes[g_iNormalSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_NORMAL_SOUNDS, szItem, ITEMDRAW_DISABLED);

    // Hurt Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_HURT_SOUNDS_FMT, g_szHurtSoundsModes[g_iHurtSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_HURT_SOUNDS, szItem, ITEMDRAW_DISABLED);

    // Weapon Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_WEAPON_SOUNDS_FMT, g_szWeaponSoundsModes[g_iWeaponSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_WEAPON_SOUNDS, szItem, ITEMDRAW_DISABLED);

    // Knife Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_KNIFE_SOUNDS_FMT, g_szKnifeSoundsModes[g_iKnifeSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_KNIFE_SOUNDS, szItem, ITEMDRAW_DISABLED);

    // Radio Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_RADIO_SOUNDS_FMT, g_szRadioSoundsModes[g_iRadioSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_RADIO_SOUNDS, szItem, ITEMDRAW_DISABLED);

    // Radio Messages
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_RADIO_MESSAGES_FMT, g_szRadioMessagesModes[g_iRadioMessages[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_RADIO_MESSAGES, szItem, ITEMDRAW_DISABLED);

    menu.ExitBackButton = false;
    menu.ExitButton = true;

    menu.DisplayAt(client, position, MENU_TIME_FOREVER);
}

static void MenuHandler_Sound(Menu menu, MenuAction action, int client, int index)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return;
    }
    if (action != MenuAction_Select)
    {
        return;
    }
    if (!Mewsound_IsClientInGame(client))
    {
        return;
    }

    char szInfo[MEWSOUND_MENU_SELECT_SIZE];
    if (!menu.GetItem(index, szInfo, sizeof(szInfo)))
    {
        return;
    }

    if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_SOUNDSCAPES))
    {
        MenuSelect_Soundscapes(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_AMBIENT_SOUNDS))
    {
        MenuSelect_AmbientSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_TRIGGER_SOUNDS))
    {
        MenuSelect_TriggerSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_NORMAL_SOUNDS))
    {
        MenuSelect_NormalSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_HURT_SOUNDS))
    {
        MenuSelect_HurtSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_WEAPON_SOUNDS))
    {
        MenuSelect_WeaponSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_KNIFE_SOUNDS))
    {
        MenuSelect_KnifeSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_RADIO_SOUNDS))
    {
        MenuSelect_RadioSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_RADIO_MESSAGES))
    {
        MenuSelect_RadioMessages(client);
    }

    Menu_Sound(client, GetMenuSelectionPosition());
}

static void MenuSelect_Soundscapes(int client)
{
    Mewsound_CycleCookie(client, g_ckSoundscapes, g_iSoundscapes, MEWSOUND_COOKIE_VALUE_SOUNDSCAPES_COUNT);
}

static void MenuSelect_AmbientSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckAmbientSounds, g_iAmbientSounds, MEWSOUND_COOKIE_VALUE_AMBIENT_SOUNDS_COUNT);
}

static void MenuSelect_TriggerSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckTriggerSounds, g_iTriggerSounds, MEWSOUND_COOKIE_VALUE_TRIGGER_SOUNDS_COUNT);
}

static void MenuSelect_NormalSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckNormalSounds, g_iNormalSounds, MEWSOUND_COOKIE_VALUE_NORMAL_SOUNDS_COUNT);
}

static void MenuSelect_HurtSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckHurtSounds, g_iHurtSounds, MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_COUNT);
}

static void MenuSelect_WeaponSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckWeaponSounds, g_iWeaponSounds, MEWSOUND_COOKIE_VALUE_WEAPON_SOUNDS_COUNT);
}

static void MenuSelect_KnifeSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckKnifeSounds, g_iKnifeSounds, MEWSOUND_COOKIE_VALUE_KNIFE_SOUNDS_COUNT);
}

static void MenuSelect_RadioSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckRadioSounds, g_iRadioSounds, MEWSOUND_COOKIE_VALUE_RADIO_SOUNDS_COUNT);
}

static void MenuSelect_RadioMessages(int client)
{
    Mewsound_CycleCookie(client, g_ckRadioMessages, g_iRadioMessages, MEWSOUND_COOKIE_VALUE_RADIO_MESSAGES_COUNT);
}

static void Mewsound_CycleCookie(int client, Cookie cookie, int storage[MAXPLAYERS + 1], int limit)
{
    if (!Mewsound_IsClientInGame(client))
    {
        return;
    }

    storage[client] = (storage[client] + 1) % limit;
    cookie.SetInt(client, storage[client]);
}

static void Mewsound_InitStateVars(int client)
{
    g_iSoundscapes[client] = g_ckSoundscapes.GetInt(client, MEWSOUND_COOKIE_VALUE_SOUNDSCAPES_DEFAULT);
    g_iAmbientSounds[client] = g_ckAmbientSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_AMBIENT_SOUNDS_DEFAULT);
    g_iNormalSounds[client] = g_ckNormalSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_NORMAL_SOUNDS_DEFAULT);
    g_iTriggerSounds[client] = g_ckTriggerSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_TRIGGER_SOUNDS_DEFAULT);
    g_iHurtSounds[client] = g_ckHurtSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_DEFAULT);
    g_iWeaponSounds[client] = g_ckWeaponSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_WEAPON_SOUNDS_DEFAULT);
    g_iKnifeSounds[client] = g_ckKnifeSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_KNIFE_SOUNDS_DEFAULT);
    g_iRadioSounds[client] = g_ckRadioSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_RADIO_SOUNDS_DEFAULT);
    g_iRadioMessages[client] = g_ckRadioMessages.GetInt(client, MEWSOUND_COOKIE_VALUE_RADIO_MESSAGES_DEFAULT);
}

static void Mewsound_CreateGlobals()
{
    // Soundscapes
    g_szSoundscapesModes[MEWSOUND_COOKIE_VALUE_SOUNDSCAPES_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szSoundscapesModes[MEWSOUND_COOKIE_VALUE_SOUNDSCAPES_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;

    // Ambient Sounds
    g_szAmbientSoundsModes[MEWSOUND_COOKIE_VALUE_AMBIENT_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szAmbientSoundsModes[MEWSOUND_COOKIE_VALUE_AMBIENT_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;

    // Trigger Sounds
    g_szTriggerSoundsModes[MEWSOUND_COOKIE_VALUE_TRIGGER_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szTriggerSoundsModes[MEWSOUND_COOKIE_VALUE_TRIGGER_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szTriggerSoundsModes[MEWSOUND_COOKIE_VALUE_TRIGGER_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Normal Sounds
    g_szNormalSoundsModes[MEWSOUND_COOKIE_VALUE_NORMAL_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szNormalSoundsModes[MEWSOUND_COOKIE_VALUE_NORMAL_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szNormalSoundsModes[MEWSOUND_COOKIE_VALUE_NORMAL_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Hurt Sounds
    g_szHurtSoundsModes[MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szHurtSoundsModes[MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szHurtSoundsModes[MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Weapon Sounds
    g_szWeaponSoundsModes[MEWSOUND_COOKIE_VALUE_WEAPON_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szWeaponSoundsModes[MEWSOUND_COOKIE_VALUE_WEAPON_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szWeaponSoundsModes[MEWSOUND_COOKIE_VALUE_WEAPON_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Knife Sounds
    g_szKnifeSoundsModes[MEWSOUND_COOKIE_VALUE_KNIFE_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szKnifeSoundsModes[MEWSOUND_COOKIE_VALUE_KNIFE_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szKnifeSoundsModes[MEWOSUND_COOKIE_VALUE_KNIFE_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Radio Sounds
    g_szRadioSoundsModes[MEWSOUND_COOKIE_VALUE_RADIO_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szRadioSoundsModes[MEWSOUND_COOKIE_VALUE_RADIO_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szRadioSoundsModes[MEWSOUND_COOKIE_VALUE_RADIO_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Radio Messages
    g_szRadioMessagesModes[MEWSOUND_COOKIE_VALUE_RADIO_MESSAGES_DISABLED] = MEWSOUND_MENU_ITEM_DISABLED;
    g_szRadioMessagesModes[MEWSOUND_COOKIE_VALUE_RADIO_MESSAGES_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szRadioMessagesModes[MEWSOUND_COOKIE_VALUE_RADIO_MESSAGES_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;
}

static void Mewsound_CreateCookies()
{
    g_ckSoundscapes = RegClientCookie(MEWSOUND_COOKIE_NAME_SOUNDSCAPES, MEWSOUND_COOKIE_DESCRIPTION_SOUNDSCAPES, CookieAccess_Protected);
    g_ckAmbientSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_AMBIENT_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_AMBIENT_SOUNDS, CookieAccess_Protected);
    g_ckTriggerSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_TRIGGER_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_TRIGGER_SOUNDS, CookieAccess_Protected);
    g_ckNormalSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_NORMAL_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_NORMAL_SOUNDS, CookieAccess_Protected);
    g_ckHurtSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_HURT_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_HURT_SOUNDS, CookieAccess_Protected);
    g_ckWeaponSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_WEAPON_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_WEAPON_SOUNDS, CookieAccess_Protected);
    g_ckKnifeSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_KNIFE_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_KNIFE_SOUNDS, CookieAccess_Protected);
    g_ckRadioSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_RADIO_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_RADIO_SOUNDS, CookieAccess_Protected);
    g_ckRadioMessages = RegClientCookie(MEWSOUND_COOKIE_NAME_RADIO_MESSAGES, MEWSOUND_COOKIE_DESCRIPTION_RADIO_MESSAGES, CookieAccess_Protected);
}

static void Mewsound_CreateCommands()
{
    RegConsoleCmd("sm_sound", Command_Sound);
}

static void Mewsound_HookEvents()
{

}
