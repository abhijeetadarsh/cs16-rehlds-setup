# CS 1.6 Server Commands Reference

## Admin Authentication
```
setinfo _pw xyz
reconnect
amx_who
```

## Admin Commands (In-Game Console)
```
amx_kick "player"              # Kick a player
amx_ban "player" 60            # Ban for 60 minutes
amx_slay "player"              # Kill a player instantly
amx_slap "player" 10           # Slap for 10 damage
amx_map de_dust2               # Change map
amx_pause                      # Pause/unpause game
amx_who                        # See admins on server
amxmodmenu                     # Open admin menu
```

## RCON Commands
```
rcon_password "your_password"   # Set rcon password (once per session)
amx_rcon <command>              # Run any server command via rcon
amx_rcon status                 # Show all connected players
amx_rcon changelevel de_dust2   # Change map
amx_rcon sv_restart 1           # Restart round
amx_rcon exec server.cfg        # Reload server config
amx_rcon amxx plugins           # List loaded AMXX plugins
amx_rcon meta list              # List loaded Metamod plugins
```

## YaPB Bot Commands
```
amx_rcon yb add                 # Add a bot
amx_rcon yb add_ct              # Add bot to CT
amx_rcon yb add_t               # Add bot to T
amx_rcon yb kick                # Kick all bots
amx_rcon yb quota 10            # Maintain 10 bots
amx_rcon yb difficulty 2        # 0-4 difficulty
yb menu                         # Open bot management menu
```

## YaPB Config (yapb.cfg)
```
yb_chat 0                       # Disable bot chat messages
yb_quota 10                     # Number of bots
yb_difficulty 2                 # Bot difficulty
yb_think_fps 30                 # Bot think rate (higher = smoother)
```

## Money Settings
```
amx_rcon mp_startmoney 16000    # Starting money
amx_rcon mp_maxmoney 16000      # Maximum money
```

## Server Settings (server.cfg)
```
hostname "Server Name"
rcon_password "your_secure_password"
sv_maxrate 25000
sv_minrate 5000
sv_maxupdaterate 102
sv_minupdaterate 30
mp_autoteambalance 1
mp_friendlyfire 0
mp_timelimit 30
mp_maxrounds 0
mp_startmoney 16000
mp_maxmoney 16000
mp_freezetime 3
mp_roundtime 2.5
mp_buytime 0.25
mp_c4timer 35
sv_lan 0
sys_ticrate 1000
fps_max 1000
mp_consistency 1
```

## Client Optimization (Game Console)
```
rate 25000
cl_updaterate 102
cl_cmdrate 105
ex_interp 0.01
fps_max 300
gl_max_size 768                 # Full texture resolution
```

## Skin System
```
say /skins                      # Open skin selection menu
say /skinreset                  # Reset to default skin
```

## File Locations (Server)
```
~/hlds/cstrike/server.cfg                                  # Server config
~/hlds/cstrike/addons/amxmodx/configs/users.ini            # Admin accounts
~/hlds/cstrike/addons/amxmodx/configs/plugins.ini          # AMXX plugins list
~/hlds/cstrike/addons/amxmodx/configs/modules.ini          # AMXX modules list
~/hlds/cstrike/addons/amxmodx/configs/weapon_skins.ini     # Skin config
~/hlds/cstrike/addons/metamod/plugins.ini                  # Metamod plugins list
~/hlds/cstrike/addons/yapb/conf/yapb.cfg                   # YaPB bot config
~/hlds/cstrike/models/custom/                              # Custom weapon models
```

## Server Startup
```bash
./hlds_run -game cstrike +sv_lan 0 +maxplayers 32 +map de_dust2 +port 27015
```
