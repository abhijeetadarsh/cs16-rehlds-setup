#include <amxmodx>
#include <reapi>
#include <fun> 

#define PROTECT_TIME 5.0     
#define HEAL_DELAY 5.0       
#define HEAL_AMOUNT 10       
#define HEAL_MAX 100         

new Float:g_flLastDamageTime[33];
new g_iMaxPlayers;
new g_msgRoundTime;
new g_msgScreenFade; // <-- Network message for the FPP screen tint

public plugin_init()
{
    register_plugin("PUBG TDM Mode", "1.5", "Server");

    // 1. MATCH TIME & ROUND LOGIC
    set_cvar_num("mp_timelimit", 8); 
    set_cvar_num("mp_round_infinite", 1);   

    // 2. RESPAWN SETTINGS
    set_cvar_float("mp_forcerespawn", 5.0); 
    set_cvar_num("mp_forcerespawn_humans_only", 0); 

    // 3. WEAPON DROP CLEANUP
    set_cvar_num("mp_weapondrop", 1);
    set_cvar_float("mp_item_staytime", 10.0); 

    // 4. HOOKS & NETWORK MESSAGES
    RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn_Post", .post = true);
    RegisterHookChain(RG_CBasePlayer_TakeDamage, "OnTakeDamage_Post", .post = true);

    g_iMaxPlayers = get_maxplayers();
    
    g_msgRoundTime = get_user_msgid("RoundTime"); 
    g_msgScreenFade = get_user_msgid("ScreenFade"); // Grab the ScreenFade ID

    // 5. AUTO-HEAL LOOP
    set_task(1.0, "Task_AutoHeal", 1001, _, _, "b");
}

public client_putinserver(id)
{
    g_flLastDamageTime[id] = 0.0;
}

// -----------------------------------------
// SPAWN & HUD SYNC LOGIC
// -----------------------------------------
public OnPlayerSpawn_Post(id)
{
    if (!is_user_alive(id)) return HC_CONTINUE;

    // HUD Timer Sync
    message_begin(MSG_ONE, g_msgRoundTime, _, id);
    write_short(get_timeleft());
    message_end();

    g_flLastDamageTime[id] = get_gametime(); 

    // Determine colors based on team
    new TeamName:team = get_member(id, m_iTeam);
    new r = 0, g = 0, b = 0;
    
    if (team == TEAM_CT) { r = 0; g = 0; b = 255; }
    else if (team == TEAM_TERRORIST) { r = 255; g = 0; b = 0; }

    if (team == TEAM_CT || team == TEAM_TERRORIST)
    {
        // Apply Godmode
        set_user_godmode(id, 1);

        // Apply 3rd-Person Glow
        set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 25); 

        // Apply 1st-Person Screen Tint (Shield effect)
        message_begin(MSG_ONE, g_msgScreenFade, _, id);
        write_short((1<<12) * 1); // Fade duration (1 second)
        write_short((1<<12) * 5); // Hold duration (5 seconds)
        write_short(0x0004);      // Flag: FFADE_STAYOUT (Hold the color)
        write_byte(r);            // Red
        write_byte(g);            // Green
        write_byte(b);            // Blue
        write_byte(20);           // Alpha/Transparency (0-255). 40 is subtle but noticeable.
        message_end();

        // Remove old tasks and set protection removal timer
        remove_task(id); 
        set_task(PROTECT_TIME, "Task_RemoveProtection", id);
    }

    return HC_CONTINUE;
}

public Task_RemoveProtection(id)
{
    if (is_user_alive(id))
    {
        // Remove Godmode and 3rd-Person Glow
        set_user_godmode(id, 0);
        set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderNormal, 0);

        // Remove 1st-Person Screen Tint
        message_begin(MSG_ONE, g_msgScreenFade, _, id);
        write_short(0);
        write_short(0);
        write_short(0x0000);
        write_byte(0);
        write_byte(0);
        write_byte(0);
        write_byte(0);
        message_end();
    }
}

// -----------------------------------------
// AUTO-HEALING LOGIC
// -----------------------------------------
public OnTakeDamage_Post(victim, inflictor, attacker, Float:damage, damage_type)
{
    if (is_user_alive(victim))
    {
        g_flLastDamageTime[victim] = get_gametime();
    }
    return HC_CONTINUE;
}

public Task_AutoHeal()
{
    new Float:currentTime = get_gametime();
    
    for (new id = 1; id <= g_iMaxPlayers; id++)
    {
        if (!is_user_alive(id)) continue; 
        
        new currentHealth = get_user_health(id);
        
        if (currentHealth >= HEAL_MAX) continue;

        if (currentTime - g_flLastDamageTime[id] >= HEAL_DELAY)
        {
            new newHealth = currentHealth + HEAL_AMOUNT;
            
            if (newHealth > HEAL_MAX) newHealth = HEAL_MAX;
            
            set_user_health(id, newHealth);
        }
    }
}
