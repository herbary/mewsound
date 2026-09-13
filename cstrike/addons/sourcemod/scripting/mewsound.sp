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
#include <mewsound/gamedata>
#include <mewsound/prop>

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
Cookie g_ckGunshotSounds;
Cookie g_ckZoomSounds;
Cookie g_ckKnifeSounds;
Cookie g_ckGrenadeSounds;
Cookie g_ckExplodeSounds;
Cookie g_ckItemSounds;
Cookie g_ckRadioSounds;
Cookie g_ckRadioMessages;

int g_iSoundscapes[MAXPLAYERS + 1];
int g_iAmbientSounds[MAXPLAYERS + 1];
int g_iTriggerSounds[MAXPLAYERS + 1];
int g_iNormalSounds[MAXPLAYERS + 1];
int g_iHurtSounds[MAXPLAYERS + 1];
int g_iGunshotSounds[MAXPLAYERS + 1];
int g_iZoomSounds[MAXPLAYERS + 1];
int g_iKnifeSounds[MAXPLAYERS + 1];
int g_iGrenadeSounds[MAXPLAYERS + 1];
int g_iExplodeSounds[MAXPLAYERS + 1];
int g_iItemSounds[MAXPLAYERS + 1];
int g_iRadioSounds[MAXPLAYERS + 1];
int g_iRadioMessages[MAXPLAYERS + 1];

char g_szSoundscapesModes[MEWSOUND_COOKIE_VALUE_SOUNDSCAPES_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szAmbientSoundsModes[MEWSOUND_COOKIE_VALUE_AMBIENT_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szTriggerSoundsModes[MEWSOUND_COOKIE_VALUE_TRIGGER_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szNormalSoundsModes[MEWSOUND_COOKIE_VALUE_NORMAL_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szHurtSoundsModes[MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szGunshotSoundsModes[MEWSOUND_COOKIE_VALUE_GUNSHOT_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szZoomSoundsModes[MEWSOUND_COOKIE_VALUE_ZOOM_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szKnifeSoundsModes[MEWSOUND_COOKIE_VALUE_KNIFE_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szGrenadeSoundsModes[MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szExplodeSoundsModes[MEWSOUND_COOKIE_VALUE_EXPLODE_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szItemSoundsModes[MEWSOUND_COOKIE_VALUE_ITEM_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szRadioSoundsModes[MEWSOUND_COOKIE_VALUE_RADIO_SOUNDS_COUNT][MEWSOUND_MENU_ITEM_SIZE];
char g_szRadioMessagesModes[MEWSOUND_COOKIE_VALUE_RADIO_MESSAGES_COUNT][MEWSOUND_MENU_ITEM_SIZE];

Handle g_hCBaseClient__GetPlayerSlot;
Handle g_hCGameServer__GetSound;

Address g_pGameServer;

int g_iSoundInfo_t__nEntityIndex;
int g_iSoundInfo_t__fVolume;
int g_iSoundInfo_t__nSoundNum;
int g_iCGameClient__thing;

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
    g_bLateLoaded = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    Mewsound_InitGameData();

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

static void Mewsound_InitGameData()
{
    GameData hGameData = new GameData(MEWSOUND_GAMEDATA_FILENAME);
    if (hGameData == null)
    {
        SetFailState("Failed to load \"%s\" GameData", MEWSOUND_GAMEDATA_FILENAME);
        return;
    }

    DynamicDetour hCGameClient__SendAudio = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Address);
    if (hCGameClient__SendAudio == null)
    {
        delete hGameData;
        SetFailState("Failed to create \"%s\" DynamicDetour", MEWSOUND_GAMEDATA_CGAMECLIENT__SENDSOUND);
        return;
    }
    bool bSuccess = hCGameClient__SendAudio.SetFromConf(hGameData, SDKConf_Signature, MEWSOUND_GAMEDATA_CGAMECLIENT__SENDSOUND);
    if (!bSuccess)
    {
        delete hGameData;
        SetFailState("Failed to find \"%s\" signature", MEWSOUND_GAMEDATA_CGAMECLIENT__SENDSOUND);
        return;
    }
    hCGameClient__SendAudio.AddParam(HookParamType_ObjectPtr);
    hCGameClient__SendAudio.AddParam(HookParamType_Bool);
    bSuccess = hCGameClient__SendAudio.Enable(Hook_Pre, DHook_CGameClient__SendAudio);
    if (!bSuccess)
    {
        delete hGameData;
        SetFailState("Failed to enable \"%s\" detour", MEWSOUND_GAMEDATA_CGAMECLIENT__SENDSOUND);
        return;
    }

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, MEWSOUND_GAMEDATA_CBASECLIENT__GETPLAYERSLOT);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hCBaseClient__GetPlayerSlot = EndPrepSDKCall();
    if (g_hCBaseClient__GetPlayerSlot == INVALID_HANDLE)
    {
        delete hGameData;
        SetFailState("Failed to initialize \"%s\" call", MEWSOUND_GAMEDATA_CBASECLIENT__GETPLAYERSLOT);
        return;
    }

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, MEWSOUND_GAMEDATA_CGAMESERVER__GETSOUND);
    PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    g_hCGameServer__GetSound = EndPrepSDKCall();
    if (g_hCGameServer__GetSound == INVALID_HANDLE)
    {
        delete hGameData;
        SetFailState("Failed to initialize \"%s\" call", MEWSOUND_GAMEDATA_CGAMESERVER__GETSOUND);
        return;
    }

    g_pGameServer = hGameData.GetAddress(MEWSOUND_GAMEDATA_CGAMESERVER);
    if (g_pGameServer == Address_Null)
    {
        delete hGameData;
        SetFailState("Failed to find \"%s\" address", MEWSOUND_GAMEDATA_CGAMESERVER);
        return;
    }

    g_iSoundInfo_t__nEntityIndex = hGameData.GetOffset(MEWSOUND_GAMEDATA_SOUNDINFO_T__NENTITYINDEX);
    if (g_iSoundInfo_t__nEntityIndex == -1)
    {
        delete hGameData;
        SetFailState("Failed to find \"%s\" offset", MEWSOUND_GAMEDATA_SOUNDINFO_T__NENTITYINDEX);
    }

    g_iSoundInfo_t__fVolume = hGameData.GetOffset(MEWSOUND_GAMEDATA_SOUNDINFO_T__FVOLUME);
    if (g_iSoundInfo_t__fVolume == -1)
    {
        delete hGameData;
        SetFailState("Failed to find \"%s\" offset", MEWSOUND_GAMEDATA_SOUNDINFO_T__FVOLUME);
        return;
    }

    g_iSoundInfo_t__nSoundNum = hGameData.GetOffset(MEWSOUND_GAMEDATA_SOUNDINFO_T__NSOUNDNUM);
    if (g_iSoundInfo_t__nSoundNum == -1)
    {
        delete hGameData;
        SetFailState("Failed to find \"%s\" offset", MEWSOUND_GAMEDATA_SOUNDINFO_T__NSOUNDNUM);
        return;
    }

    g_iCGameClient__thing = hGameData.GetOffset(MEWSOUND_GAMEDATA_CGAMECLIENT__THING);
    if (g_iCGameClient__thing == -1)
    {
        delete hGameData;
        SetFailState("Failed to find \"%s\" offset", MEWSOUND_GAMEDATA_CGAMECLIENT__THING);
        return;
    }

    delete hGameData;
}

public MRESReturn DHook_CGameClient__SendAudio(Address pThis, DHookParam hParams)
{
    if (hParams.GetObjectVar(1, g_iSoundInfo_t__fVolume, ObjectValueType_Float) == 0.0)
    {
        return MRES_Ignored;
    }

    Address pClientInterface = pThis + view_as<Address>(g_iCGameClient__thing);
    int client = view_as<int>(SDKCall(g_hCBaseClient__GetPlayerSlot, pClientInterface)) + 1;
    PrintToChatAll("CGameClient__SendAudio @ client :: #%i", client);
    if (!Mewsound_IsClientInGame(client))
    {
        return MRES_Ignored;
    }

    int nEntityIndex = hParams.GetObjectVar(1, g_iSoundInfo_t__nEntityIndex, ObjectValueType_Int);
    if (nEntityIndex != 0 && !IsValidEntity(nEntityIndex))
    {
        return MRES_Supercede;
    }

    int nSoundNum = hParams.GetObjectVar(1, g_iSoundInfo_t__nSoundNum, ObjectValueType_Int);

    char szSample[PLATFORM_MAX_PATH];
    SDKCall(g_hCGameServer__GetSound, g_pGameServer, szSample, sizeof(szSample), nSoundNum);

    PrintToChat(client, "SoundInfo_t @ #%i [%i] %s", nEntityIndex, nSoundNum, szSample);

    if (Mewsound_IsGrenadeSound(szSample))
    {
        return Mewsound_RetGrenadeSound(client, nEntityIndex);
    }

    return MRES_Ignored;
}

static bool Mewsound_IsGrenadeSound(char sample[PLATFORM_MAX_PATH])
{
    return StrContains(sample, "weapons/flashbang/grenade_hit1", false) == 0
        || StrContains(sample, "weapons/hegrenade/he_bounce-1", false) == 0
        || StrContains(sample, "weapons/smokegrenade/grenade_hit1", false) == 0;
}

static MRESReturn Mewsound_RetGrenadeSound(int client, int entity)
{
    if (g_iGrenadeSounds[client] == MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_ENABLED)
    {
        return MRES_Ignored;
    }
    if (g_iGrenadeSounds[client] == MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_REMOVED)
    {
        return MRES_Supercede;
    }

    int owner = -1;
    if (HasEntProp(entity, Prop_Data, MEWSOUND_PROP_M_HOWNERENTITY))
    {
        owner = GetEntPropEnt(entity, Prop_Data, MEWSOUND_PROP_M_HOWNERENTITY);
    }
    if (!Mewsound_IsClient(owner))
    {
        return MRES_Supercede;
    }

    int mode = GetEntProp(owner, Prop_Send, MEWSOUND_PROP_M_IOBSERVERMODE);
    int target = GetEntPropEnt(client, Prop_Send, MEWSOUND_PROP_M_HOBSERVERTARGET);
    if (g_iGrenadeSounds[client] == MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_MUTED)
    {
        if (!Mewsound_IsClientInGame(target))
        {
            if (owner == client)
            {
                return MRES_Ignored;
            }
            return MRES_Supercede;
        }

        if (mode < 4 || mode > 6)
        {
            return MRES_Supercede;
        }

        if (owner == target)
        {
            return MRES_Ignored;
        }
        return MRES_Supercede;
    }
    if (g_iGrenadeSounds[client] == MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_PARTNERSHIP)
    {
        if (!Mewsound_IsClientInGame(target))
        {
            if (owner == client)
            {
                return MRES_Ignored;
            }

            int partner = Mewsound_GetPartner(client);
            if (partner == _MEWSOUND_PARTNER_UNKNOWN)
            {
                return MRES_Supercede;
            }

            if (owner == partner)
            {
                return MRES_Ignored;
            }
            return MRES_Supercede;
        }

        if (mode < 4 || mode > 6)
        {
            return MRES_Supercede;
        }

        if (owner == target)
        {
            return MRES_Ignored;
        }

        int partner = Mewsound_GetPartner(target);
        if (partner == _MEWSOUND_PARTNER_UNKNOWN)
        {
            return MRES_Supercede;
        }

        if (owner == partner)
        {
            return MRES_Ignored;
        }
        return MRES_Supercede;
    }

    return MRES_Ignored;
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
    menu.AddItem(MEWSOUND_MENU_SELECT_SOUNDSCAPES, szItem);

    // Ambient Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_AMBIENT_SOUNDS_FMT, g_szAmbientSoundsModes[g_iAmbientSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_AMBIENT_SOUNDS, szItem);

    // Trigger Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_TRIGGER_SOUNDS_FMT, g_szTriggerSoundsModes[g_iTriggerSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_TRIGGER_SOUNDS, szItem);

    // Normal Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_NORMAL_SOUNDS_FMT, g_szNormalSoundsModes[g_iNormalSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_NORMAL_SOUNDS, szItem);

    // Hurt Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_HURT_SOUNDS_FMT, g_szHurtSoundsModes[g_iHurtSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_HURT_SOUNDS, szItem);

    // Gunshot Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_GUNSHOT_SOUNDS_FMT, g_szGunshotSoundsModes[g_iGunshotSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_GUNSHOT_SOUNDS, szItem);

    // Zoom Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_ZOOM_SOUNDS_FMT, g_szZoomSoundsModes[g_iZoomSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_ZOOM_SOUNDS, szItem);

    // Knife Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_KNIFE_SOUNDS_FMT, g_szKnifeSoundsModes[g_iKnifeSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_KNIFE_SOUNDS, szItem);

    // Grenade Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_GRENADE_SOUNDS_FMT, g_szGrenadeSoundsModes[g_iGrenadeSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_GRENADE_SOUNDS, szItem);

    // Explode Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_EXPLODE_SOUNDS_FMT, g_szExplodeSoundsModes[g_iExplodeSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_EXPLODE_SOUNDS, szItem);

    // Item Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_ITEM_SOUNDS_FMT, g_szItemSoundsModes[g_iItemSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_ITEM_SOUNDS, szItem);

    // Radio Sounds
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_RADIO_SOUNDS_FMT, g_szRadioSoundsModes[g_iRadioSounds[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_RADIO_SOUNDS, szItem);

    // Radio Messages
    FormatEx(szItem, sizeof(szItem), MEWSOUND_MENU_ITEM_RADIO_MESSAGES_FMT, g_szRadioMessagesModes[g_iRadioMessages[client]]);
    menu.AddItem(MEWSOUND_MENU_SELECT_RADIO_MESSAGES, szItem);

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
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_GUNSHOT_SOUNDS))
    {
        MenuSelect_GunshotSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_ZOOM_SOUNDS))
    {
        MenuSelect_ZoomSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_KNIFE_SOUNDS))
    {
        MenuSelect_KnifeSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_GRENADE_SOUNDS))
    {
        MenuSelect_GrenadeSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_EXPLODE_SOUNDS))
    {
        MenuSelect_ExplodeSounds(client);
    }
    else if (StrEqual(szInfo, MEWSOUND_MENU_SELECT_ITEM_SOUNDS))
    {
        MenuSelect_ItemSounds(client);
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

static void MenuSelect_GunshotSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckGunshotSounds, g_iGunshotSounds, MEWSOUND_COOKIE_VALUE_GUNSHOT_SOUNDS_COUNT);
}

static void MenuSelect_ZoomSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckZoomSounds, g_iZoomSounds, MEWSOUND_COOKIE_VALUE_ZOOM_SOUNDS_COUNT);
}

static void MenuSelect_KnifeSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckKnifeSounds, g_iKnifeSounds, MEWSOUND_COOKIE_VALUE_KNIFE_SOUNDS_COUNT);
}

static void MenuSelect_GrenadeSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckGrenadeSounds, g_iGrenadeSounds, MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_COUNT);
}

static void MenuSelect_ExplodeSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckExplodeSounds, g_iExplodeSounds, MEWSOUND_COOKIE_VALUE_EXPLODE_SOUNDS_COUNT);
}

static void MenuSelect_ItemSounds(int client)
{
    Mewsound_CycleCookie(client, g_ckItemSounds, g_iItemSounds, MEWSOUND_COOKIE_VALUE_ITEM_SOUNDS_COUNT);
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
    g_iGunshotSounds[client] = g_ckGunshotSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_GUNSHOT_SOUNDS_DEFAULT);
    g_iZoomSounds[client] = g_ckZoomSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_ZOOM_SOUNDS_DEFAULT);
    g_iKnifeSounds[client] = g_ckKnifeSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_KNIFE_SOUNDS_DEFAULT);
    g_iGrenadeSounds[client] = g_ckGrenadeSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_DEFAULT);
    g_iExplodeSounds[client] = g_ckExplodeSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_EXPLODE_SOUNDS_DEFAULT);
    g_iItemSounds[client] = g_ckItemSounds.GetInt(client, MEWSOUND_COOKIE_VALUE_ITEM_SOUNDS_DEFAULT);
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
    g_szTriggerSoundsModes[MEWSOUND_COOKIE_VALUE_TRIGGER_SOUNDS_REMOVED] = MEWSOUND_MENU_ITEM_REMOVED;
    g_szTriggerSoundsModes[MEWSOUND_COOKIE_VALUE_TRIGGER_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szTriggerSoundsModes[MEWSOUND_COOKIE_VALUE_TRIGGER_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Normal Sounds
    g_szNormalSoundsModes[MEWSOUND_COOKIE_VALUE_NORMAL_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szNormalSoundsModes[MEWSOUND_COOKIE_VALUE_NORMAL_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szNormalSoundsModes[MEWSOUND_COOKIE_VALUE_NORMAL_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Hurt Sounds
    g_szHurtSoundsModes[MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szHurtSoundsModes[MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_REMOVED] = MEWSOUND_MENU_ITEM_REMOVED;
    g_szHurtSoundsModes[MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szHurtSoundsModes[MEWSOUND_COOKIE_VALUE_HURT_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Gunshot Sounds
    g_szGunshotSoundsModes[MEWSOUND_COOKIE_VALUE_GUNSHOT_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szGunshotSoundsModes[MEWSOUND_COOKIE_VALUE_GUNSHOT_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szGunshotSoundsModes[MEWSOUND_COOKIE_VALUE_GUNSHOT_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Zoom Sounds
    g_szZoomSoundsModes[MEWSOUND_COOKIE_VALUE_ZOOM_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szZoomSoundsModes[MEWSOUND_COOKIE_VALUE_ZOOM_SOUNDS_REMOVED] = MEWSOUND_MENU_ITEM_REMOVED;
    g_szZoomSoundsModes[MEWSOUND_COOKIE_VALUE_ZOOM_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szZoomSoundsModes[MEWSOUND_COOKIE_VALUE_ZOOM_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Knife Sounds
    g_szKnifeSoundsModes[MEWSOUND_COOKIE_VALUE_KNIFE_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szKnifeSoundsModes[MEWSOUND_COOKIE_VALUE_KNIFE_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szKnifeSoundsModes[MEWOSUND_COOKIE_VALUE_KNIFE_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Grenade Sounds
    g_szGrenadeSoundsModes[MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szGrenadeSoundsModes[MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_REMOVED] = MEWSOUND_MENU_ITEM_REMOVED;
    g_szGrenadeSoundsModes[MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szGrenadeSoundsModes[MEWSOUND_COOKIE_VALUE_GRENADE_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Explode Sounds
    g_szExplodeSoundsModes[MEWSOUND_COOKIE_VALUE_EXPLODE_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szExplodeSoundsModes[MEWSOUND_COOKIE_VALUE_EXPLODE_SOUNDS_REMOVED] = MEWSOUND_MENU_ITEM_REMOVED;
    g_szExplodeSoundsModes[MEWSOUND_COOKIE_VALUE_EXPLODE_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szExplodeSoundsModes[MEWSOUND_COOKIE_VALUE_EXPLODE_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Item Sounds
    g_szItemSoundsModes[MEWSOUND_COOKIE_VALUE_ITEM_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szItemSoundsModes[MEWSOUND_COOKIE_VALUE_ITEM_SOUNDS_REMOVED] = MEWSOUND_MENU_ITEM_REMOVED;
    g_szItemSoundsModes[MEWSOUND_COOKIE_VALUE_ITEM_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szItemSoundsModes[MEWSOUND_COOKIE_VALUE_ITEM_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Radio Sounds
    g_szRadioSoundsModes[MEWSOUND_COOKIE_VALUE_RADIO_SOUNDS_MUTED] = MEWSOUND_MENU_ITEM_MUTED;
    g_szRadioSoundsModes[MEWSOUND_COOKIE_VALUE_RADIO_SOUNDS_ENABLED] = MEWSOUND_MENU_ITEM_ENABLED;
    g_szRadioSoundsModes[MEWSOUND_COOKIE_VALUE_RADIO_SOUNDS_PARTNERSHIP] = MEWSOUND_MENU_ITEM_PARTNERSHIP;

    // Radio Messages
    g_szRadioMessagesModes[MEWSOUND_COOKIE_VALUE_RADIO_MESSAGES_DISABLED] = MEWSOUND_MENU_ITEM_DISABLED;
    g_szRadioMessagesModes[MEWSOUND_COOKIE_VALUE_RADIO_MESSAGES_REMOVED] = MEWSOUND_MENU_ITEM_REMOVED;
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
    g_ckGunshotSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_GUNSHOT_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_GUNSHOT_SOUNDS, CookieAccess_Protected);
    g_ckZoomSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_ZOOM_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_ZOOM_SOUNDS, CookieAccess_Protected);
    g_ckKnifeSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_KNIFE_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_KNIFE_SOUNDS, CookieAccess_Protected);
    g_ckGrenadeSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_GRENADE_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_GRENADE_SOUNDS, CookieAccess_Protected);
    g_ckExplodeSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_EXPLODE_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_EXPLODE_SOUNDS, CookieAccess_Protected);
    g_ckItemSounds = RegClientCookie(MEWSOUND_COOKIE_NAME_ITEM_SOUNDS, MEWSOUND_COOKIE_DESCRIPTION_ITEM_SOUNDS, CookieAccess_Protected);
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
