# CS 1.6 ReHLDS Server Setup Script

Automated setup script for a **Counter-Strike 1.6** dedicated server on **Ubuntu**, using the [ReHLDS](https://github.com/rehlds) open-source stack.

## What it installs

| Component | Version | Purpose |
|---|---|---|
| [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) | latest | Downloads the base HLDS server files |
| [ReHLDS](https://github.com/rehlds/ReHLDS) | 3.14.0.857 | Enhanced HLDS engine — security fixes, performance optimizations |
| [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS) | 5.28.0.756 | Enhanced CS 1.6 game library with extended features |
| [Metamod-R](https://github.com/rehlds/Metamod-R) | 1.3.0.149 | Plugin loader for the server |
| [ReUnion](https://github.com/rehlds/ReUnion) | 0.2.0.25 | Allows non-steam (protocol 47/48) clients to connect |

## Usage

```bash
chmod +x setup_cs16_rehlds.sh
./setup_cs16_rehlds.sh
```

After setup completes, start the server:

```bash
~/hlds/start.sh
```

Manage the server console:

```bash
# Attach to the running server console
screen -r cs16

# Detach without stopping (inside screen)
# Press Ctrl+A, then D

# Stop the server (from inside screen)
quit
```

## Things you should change

Open `setup_cs16_rehlds.sh` and edit the **Configuration** section at the top before running.

### Install location

```bash
HLDS_DIR="$HOME/hlds"
STEAMCMD_DIR="$HOME/steamcmd"
```

Change these if you want the server installed somewhere else. If you change `HLDS_DIR`, the start script and all paths adjust automatically.

### Server settings

```bash
SERVER_HOSTNAME="CS 1.6 Server"    # Name shown in the server browser
SERVER_MAP="de_dust2"               # Starting map
SERVER_MAXPLAYERS="32"              # Max player slots
SERVER_PORT="27015"                 # Server port (change if running multiple servers)
```

### RCON password

The script auto-generates a random RCON password and prints it at the end. If you want to set your own, change this line:

```bash
RCON_PASSWORD="change_me_$(date +%s | sha256sum | head -c 12)"
```

To something like:

```bash
RCON_PASSWORD="your_secure_password_here"
```

> **Save the RCON password** — it's printed once at the end of setup. You can also find it later in `~/hlds/cstrike/server.cfg`.

### ReUnion salt (SteamIdHashSalt)

The script auto-generates a random salt for non-steam player SteamID hashing. This prevents players from impersonating each other's SteamIDs.

**Important:** Once your server is live and players have established bans/stats tied to their SteamIDs, **do not change the salt** — it will change everyone's SteamID and break all existing bans and player data.

The salt is stored in `~/hlds/cstrike/reunion.cfg`.

### Component versions

To upgrade any component, update the URL variables:

```bash
REHLDS_URL="https://github.com/rehlds/ReHLDS/releases/download/..."
REGAMEDLL_URL="https://github.com/rehlds/ReGameDLL_CS/releases/download/..."
METAMOD_URL="https://github.com/rehlds/Metamod-R/releases/download/..."
REUNION_URL="https://github.com/rehlds/ReUnion/releases/download/..."
```

Check the respective GitHub release pages for the latest versions.

## Post-install configuration

### Firewall

Open the server port:

```bash
sudo ufw allow 27015/udp    # Game traffic
sudo ufw allow 27015/tcp    # RCON
```

### server.cfg

The script writes a basic `server.cfg` at `~/hlds/cstrike/server.cfg`. Edit it to adjust gameplay settings like round time, friendly fire, start money, etc.

### reunion.cfg

Located at `~/hlds/cstrike/reunion.cfg`. Controls which client protocols are allowed, SteamID generation, and query rate limiting. The defaults work fine for most servers.

### Adding more Metamod plugins

Edit `~/hlds/cstrike/addons/metamod/plugins.ini` and add one line per plugin:

```
linux addons/your_plugin/your_plugin_i386.so
```

### Installing AMX Mod X

For server-side scripting and admin plugins, install [AMX Mod X](https://www.amxmodx.org/downloads-new.php) and [ReAPI](https://github.com/rehlds/ReAPI/releases) on top of this setup.

## Verify everything is working

Attach to the server console and run:

```
# Check ReHLDS version
version

# Check all Metamod plugins are loaded
meta list
```

ReUnion should show status `RUN`:

```
Currently loaded plugins:
      description  stat pend  file                vers       src  load  unload
 [ 1] Reunion      RUN  -     reunion_mm_i386.so  v0.2.0.25  ini  Start Never
```

## Requirements

- Ubuntu (tested on 22.04 / 24.04)
- Root or sudo access (for installing system packages)
- ~2 GB disk space
- Internet connection (for downloading components)

## Credits

All server components are developed by the [ReHLDS](https://github.com/rehlds) community. This script just automates the installation.

## License

MIT
