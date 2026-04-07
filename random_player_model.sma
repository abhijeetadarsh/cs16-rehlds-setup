#include <amxmodx>
#include <amxmisc> // Required for admin commands (cmd_access)
#include <reapi>

new const g_szModelsCT[][32] = {
    "ahri", "caitlyn", "evelynn", "abia", "fey", 
    "gracia", "night", "princess", "ritsuka", "yixuan"
};
new const g_szModelNamesCT[][32] = {
    "Ahri", "Caitlyn", "Evelynn", "Abia", "Fey", 
    "Gracia", "Night Witch Luna", "Princess Ji Yoon", "Guide Ritsuka", "Yixuan"
};

new const g_szModelsT[][32] = {
    "katarina", "morgana", "talon", "amy", "blood", 
    "goku", "milia", "squid", "yuri"
};
new const g_szModelNamesT[][32] = {
    "Katarina", "Morgana", "Talon", "Amy", "Blood Witch", 
    "Goku", "Milia", "Squid", "Pyromaniac Yuri"
};

new g_iCurrentRoundModelCT = 0;
new g_iCurrentRoundModelT = 0;
new bool:g_bHasSeenMessage[33];
new g_iMaxPlayers;

public plugin_init()
{
    register_plugin("Random Team Models per Map", "2.2", "Server");
    
    // Register the admin command (requires ADMIN_KICK flag, which your account has)
    register_concmd("amx_reroll_models", "Cmd_RerollModels", ADMIN_KICK, "- Rerolls the characters for both teams mid-match");

    RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn_Post", .post = true);
    
    g_iMaxPlayers = get_maxplayers();
}

public plugin_cfg()
{
    // Initial map-load roll
    new sysTime = get_systime();
    g_iCurrentRoundModelCT = (random_num(0, 9999) + sysTime) % sizeof(g_szModelsCT);
    g_iCurrentRoundModelT = (random_num(0, 9999) + sysTime + 7) % sizeof(g_szModelsT);
}

public plugin_precache()
{
    new path[128];
    for(new i = 0; i < sizeof(g_szModelsCT); i++)
    {
        formatex(path, charsmax(path), "models/player/%s/%s.mdl", g_szModelsCT[i], g_szModelsCT[i]);
        precache_model(path);
    }
    for(new i = 0; i < sizeof(g_szModelsT); i++)
    {
        formatex(path, charsmax(path), "models/player/%s/%s.mdl", g_szModelsT[i], g_szModelsT[i]);
        precache_model(path);
    }
}

public client_putinserver(id)
{
    g_bHasSeenMessage[id] = false;
}

public OnPlayerSpawn_Post(id)
{
    if(!is_user_alive(id)) return HC_CONTINUE;

    if(!g_bHasSeenMessage[id])
    {
        client_print_color(id, print_team_default, "^4[War!]^1 This match: ^3%s^1 (CT) vs ^3%s^1 (T)!", 
            g_szModelNamesCT[g_iCurrentRoundModelCT], 
            g_szModelNamesT[g_iCurrentRoundModelT]);
        
        g_bHasSeenMessage[id] = true;
    }

    new TeamName:team = get_member(id, m_iTeam);

    if(team == TEAM_CT)
    {
        rg_set_user_model(id, g_szModelsCT[g_iCurrentRoundModelCT]);
    }
    else if(team == TEAM_TERRORIST)
    {
        rg_set_user_model(id, g_szModelsT[g_iCurrentRoundModelT]);
    }

    return HC_CONTINUE;
}

// -----------------------------------------
// ADMIN COMMAND HANDLER
// -----------------------------------------
public Cmd_RerollModels(id, level, cid)
{
    // Check if the user has the required admin flag
    if(!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    // Roll new characters
    new sysTime = get_systime();
    g_iCurrentRoundModelCT = (random_num(0, 9999) + sysTime) % sizeof(g_szModelsCT);
    g_iCurrentRoundModelT = (random_num(0, 9999) + sysTime + 7) % sizeof(g_szModelsT);

    // Announce the change to the whole server
    client_print_color(0, print_team_default, "^4[Admin]^1 Characters rerolled! ^3%s^1 (CT) vs ^3%s^1 (T)!", 
        g_szModelNamesCT[g_iCurrentRoundModelCT], 
        g_szModelNamesT[g_iCurrentRoundModelT]);

    // Instantly morph everyone currently alive into the new characters
    for(new i = 1; i <= g_iMaxPlayers; i++)
    {
        if(is_user_alive(i))
        {
            new TeamName:team = get_member(i, m_iTeam);
            if(team == TEAM_CT)
            {
                rg_set_user_model(i, g_szModelsCT[g_iCurrentRoundModelCT], true);
            }
            else if(team == TEAM_TERRORIST)
            {
                rg_set_user_model(i, g_szModelsT[g_iCurrentRoundModelT], true);
            }
        }
    }

    // Print confirmation in the admin's console
    console_print(id, "Successfully rerolled team models.");

    return PLUGIN_HANDLED;
}
