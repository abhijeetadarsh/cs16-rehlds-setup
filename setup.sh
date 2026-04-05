#!/bin/bash
#
# CS 1.6 Server Setup Script (Ubuntu) — ReHLDS Stack
# ===================================================
# This script installs a fully working Counter-Strike 1.6 dedicated server
# using the ReHLDS ecosystem on Ubuntu.
#
# Components installed:
#   - SteamCMD + HLDS (steam_legacy branch)
#   - ReHLDS        3.14.0.857   (enhanced engine)
#   - ReGameDLL_CS  5.28.0.756   (enhanced game library)
#   - Metamod-R     1.3.0.149    (plugin loader)
#   - ReUnion       0.2.0.25     (non-steam client support)
#
# Usage:
#   chmod +x setup_cs16_rehlds.sh
#   ./setup_cs16_rehlds.sh
#
# After setup, start the server with:
#   ~/hlds/start.sh
#

set -e

BASE_DIR="$HOME/test"

# ─── Configuration ────────────────────────────────────────────────────────────
HLDS_DIR="$BASE_DIR/hlds"
STEAMCMD_DIR="$BASE_DIR/steamcmd"
WORK_DIR="$BASE_DIR/cs16_setup_tmp"

REHLDS_URL="https://github.com/rehlds/ReHLDS/releases/download/3.14.0.857/rehlds-bin-3.14.0.857.zip"
REGAMEDLL_URL="https://github.com/rehlds/ReGameDLL_CS/releases/download/5.28.0.756/regamedll-bin-5.28.0.756.zip"
METAMOD_URL="https://github.com/rehlds/Metamod-R/releases/download/1.3.0.149/metamod-bin-1.3.0.149.zip"
REUNION_URL="https://github.com/rehlds/ReUnion/releases/download/0.2.0.25/reunion-0.2.0.25.zip"

SERVER_HOSTNAME="CS 1.6 Server"
SERVER_MAP="de_dust2"
SERVER_MAXPLAYERS="32"
SERVER_PORT="27015"
RCON_PASSWORD="change_me_$(date +%s | sha256sum | head -c 12)"
REUNION_SALT="rehlds_salt_$(date +%s | sha256sum | head -c 24)"

# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── Step 1: Install system dependencies ─────────────────────────────────────
info "Step 1/8: Installing system dependencies..."

sudo dpkg --add-architecture i386
sudo apt-get update -qq
sudo apt-get install -y \
    lib32gcc-s1 \
    lib32stdc++6 \
    libc6-i386 \
    lib32z1 \
    curl \
    tar \
    unzip \
    screen \
    ca-certificates

info "System dependencies installed."

# ─── Step 2: Install SteamCMD ────────────────────────────────────────────────
info "Step 2/8: Installing SteamCMD..."

mkdir -p "$STEAMCMD_DIR"
cd "$STEAMCMD_DIR"

if [ ! -f "$STEAMCMD_DIR/steamcmd.sh" ]; then
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar xzf -
    info "SteamCMD downloaded."
else
    info "SteamCMD already exists, skipping download."
fi

# ─── Step 3: Download HLDS with Counter-Strike 1.6 ───────────────────────────
info "Step 3/8: Downloading HLDS (Counter-Strike 1.6)..."
info "This may take a while. SteamCMD can be flaky — running up to 3 attempts."

for attempt in 1 2 3; do
    info "  Attempt $attempt/3..."
    "$STEAMCMD_DIR/steamcmd.sh" \
        +force_install_dir "$HLDS_DIR" \
        +login anonymous \
        +app_set_config 90 mod cstrike \
        +app_update 90 -beta steam_legacy validate \
        +quit && break

    if [ "$attempt" -eq 3 ]; then
        error "HLDS download failed after 3 attempts. Check your network and try again."
    fi
    warn "  Retrying in 5 seconds..."
    sleep 5
done

info "HLDS downloaded."

# ─── Step 4: Prepare temp directory ──────────────────────────────────────────
info "Step 4/8: Downloading ReHLDS components..."

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Download all components
curl -sLO "$REHLDS_URL"
curl -sLO "$REGAMEDLL_URL"
curl -sLO "$METAMOD_URL"
curl -sLO "$REUNION_URL"

# Extract all
unzip -qo rehlds-bin-3.14.0.857.zip    -d rehlds-temp
unzip -qo regamedll-bin-5.28.0.756.zip -d regamedll-temp
unzip -qo metamod-bin-1.3.0.149.zip    -d metamod-temp
unzip -qo reunion-0.2.0.25.zip         -d reunion-temp

info "All components downloaded and extracted."

# ─── Step 5: Install ReHLDS (engine replacement) ────────────────────────────
info "Step 5/8: Installing ReHLDS engine..."

# ReHLDS linux binaries — replaces engine_i486.so
cp -r "$WORK_DIR/rehlds-temp/bin/linux32/"* "$HLDS_DIR/"

info "ReHLDS installed."

# ─── Step 6: Install ReGameDLL_CS (game library replacement) ────────────────
info "Step 6/8: Installing ReGameDLL_CS..."

cp -r "$WORK_DIR/regamedll-temp/bin/linux32/"* "$HLDS_DIR/"

# Copy extra configs if present (game.cfg, gamemode.cfg, etc.)
if [ -d "$WORK_DIR/regamedll-temp/dist" ]; then
    cp -rn "$WORK_DIR/regamedll-temp/dist/"* "$HLDS_DIR/cstrike/" 2>/dev/null || true
fi

info "ReGameDLL_CS installed."

# ─── Step 7: Install Metamod-R ──────────────────────────────────────────────
info "Step 7/8: Installing Metamod-R..."

# Metamod-R has addons/metamod/ at the root of the zip (no dlls subfolder)
cp -r "$WORK_DIR/metamod-temp/addons" "$HLDS_DIR/cstrike/"

# Point the engine to load Metamod instead of the game DLL directly
# Edit liblist.gam: change gamedll_linux to load metamod
LIBLIST="$HLDS_DIR/cstrike/liblist.gam"
if [ -f "$LIBLIST" ]; then
    sed -i 's|^gamedll_linux.*|gamedll_linux "addons/metamod/metamod_i386.so"|' "$LIBLIST"
    info "liblist.gam updated to load Metamod-R."
else
    warn "liblist.gam not found — creating it."
    echo 'gamedll_linux "addons/metamod/metamod_i386.so"' > "$LIBLIST"
fi

# Create plugins.ini (will be populated with ReUnion next)
touch "$HLDS_DIR/cstrike/addons/metamod/plugins.ini"

info "Metamod-R installed."

# ─── Step 8: Install ReUnion (non-steam support) ────────────────────────────
info "Step 8/8: Installing ReUnion..."

# Create reunion addon directory
mkdir -p "$HLDS_DIR/cstrike/addons/reunion"

# Copy the .so (note: capital 'L' in Linux)
REUNION_SO=$(find "$WORK_DIR/reunion-temp" -name "reunion_mm_i386.so" | head -1)
if [ -z "$REUNION_SO" ]; then
    error "reunion_mm_i386.so not found in the archive!"
fi
cp "$REUNION_SO" "$HLDS_DIR/cstrike/addons/reunion/"

# Copy reunion.cfg to cstrike directory
REUNION_CFG=$(find "$WORK_DIR/reunion-temp" -name "reunion.cfg" | head -1)
if [ -z "$REUNION_CFG" ]; then
    error "reunion.cfg not found in the archive!"
fi
cp "$REUNION_CFG" "$HLDS_DIR/cstrike/"

# Set SteamIdHashSalt (must be >16 chars or ReUnion fails to start)
sed -i "s|^SteamIdHashSalt.*|SteamIdHashSalt = \"$REUNION_SALT\"|" "$HLDS_DIR/cstrike/reunion.cfg"

# Register ReUnion in Metamod's plugins.ini (at the top)
PLUGINS_INI="$HLDS_DIR/cstrike/addons/metamod/plugins.ini"
if ! grep -q "reunion_mm_i386.so" "$PLUGINS_INI" 2>/dev/null; then
    echo 'linux addons/reunion/reunion_mm_i386.so' >> "$PLUGINS_INI"
fi

info "ReUnion installed and configured."

# ─── Configure: steam_appid.txt ──────────────────────────────────────────────
info "Writing steam_appid.txt..."
echo "10" > "$HLDS_DIR/steam_appid.txt"

# ─── Configure: server.cfg ──────────────────────────────────────────────────
info "Writing server.cfg..."

cat > "$HLDS_DIR/cstrike/server.cfg" << EOF
hostname "$SERVER_HOSTNAME"
rcon_password "$RCON_PASSWORD"

sv_lan 0

// Network
sv_maxrate 25000
sv_minrate 5000
sv_maxupdaterate 101
sv_minupdaterate 30

// Gameplay
mp_autoteambalance 1
mp_friendlyfire 0
mp_timelimit 30
mp_maxrounds 0
mp_freezetime 3
mp_roundtime 2.5
mp_startmoney 800
mp_c4timer 35

// Logging
log on
sv_logbans 1
sv_logfile 1

// Bans
exec listip.cfg
exec banned.cfg
EOF

# ─── Create start script ────────────────────────────────────────────────────
info "Creating start script..."

cat > "$HLDS_DIR/start.sh" << 'STARTEOF'
#!/bin/bash
cd "$(dirname "$0")"
screen -dmS cs16 ./hlds_run -game cstrike +sv_lan 0 +maxplayers 32 +map de_dust2 +port 27015
echo "Server started in screen session 'cs16'"
echo "  Attach:  screen -r cs16"
echo "  Detach:  Ctrl+A, then D"
STARTEOF
chmod +x "$HLDS_DIR/start.sh"

# ─── Cleanup ─────────────────────────────────────────────────────────────────
info "Cleaning up temp files..."
rm -rf "$WORK_DIR"

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo -e "${GREEN}  CS 1.6 ReHLDS Server Setup Complete!${NC}"
echo "=============================================="
echo ""
echo "  Install dir:   $HLDS_DIR"
echo "  Server IP:     $(hostname -I | awk '{print $1}'):$SERVER_PORT"
echo "  RCON password: $RCON_PASSWORD"
echo "  ReUnion salt:  $REUNION_SALT"
echo ""
echo "  Start server:  $HLDS_DIR/start.sh"
echo "  Attach console: screen -r cs16"
echo "  Detach console: Ctrl+A, then D"
echo ""
echo "  Stop server (from inside screen):"
echo "    Type 'quit' in the server console, or"
echo "    screen -S cs16 -X quit"
echo ""
echo "  Don't forget to open the firewall:"
echo "    sudo ufw allow 27015/udp"
echo "    sudo ufw allow 27015/tcp"
echo ""
echo "  Verify ReUnion is loaded by typing"
echo "  'meta list' in the server console."
echo "=============================================="
