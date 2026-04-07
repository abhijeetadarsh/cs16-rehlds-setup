#include <amxmodx>
#include <weapon_skin_system>

public plugin_init()
{
    register_plugin("Default Skins", "1.0", "Server");
}

public client_putinserver(id)
{
    wss_set_user_skin(id, CSW_AK47, 1);
    wss_set_user_skin(id, CSW_M4A1, 6);
    wss_set_user_skin(id, CSW_GLOCK18, 3);
}
