#if defined _mewsound_util_included_
#endinput
#endif
#define _mewsound_util_included_

#include <clients>

stock bool Mewsound_IsAlivePlayerInGame(int client)
{
    return Mewsound_IsPlayerInGame(client) && IsPlayerAlive(client);
}

stock bool Mewsound_IsPlayerInGame(int client)
{
    return Mewsound_IsClientInGame(client) && !IsFakeClient(client);
}

stock bool Mewsound_IsAlivePlayer(int client)
{
    return Mewsound_IsPlayer(client) && IsPlayerAlive(client);
}

stock bool Mewsound_IsPlayer(int client)
{
    return Mewsound_IsClient(client) && !IsFakeClient(client);
}

stock bool Mewsound_IsAliveClientInGame(int client)
{
    return Mewsound_IsClientInGame(client) && IsPlayerAlive(client);
}

stock bool Mewsound_IsClientInGame(int client)
{
    return Mewsound_IsClient(client) && IsClientInGame(client);
}

stock bool Mewsound_IsAliveClient(int client)
{
    return Mewsound_IsClient(client) && IsPlayerAlive(client);
}

stock bool Mewsound_IsClient(int client)
{
    return client >= 1 && client <= MaxClients;
}
