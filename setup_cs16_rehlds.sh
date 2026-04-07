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
#   - AMX Mod X     1.10.0.5467  (scripting / admin framework)
#   - ReAPI         5.26.0.338   (ReHLDS/ReGameDLL API for AMXX)
#   - YaPB          4.4.957      (bots)
#   - WeaponSkinSystem by Mistrick (weapon skin plugin)
#
# Features:
#   - Comprehensive validation after each install step
#   - Binary ELF verification for .so files
#   - Permission checks on executables
#   - Config content verification
#   - File size sanity checks
#   - HTML-download-corruption detection
#   - Final end-to-end validation report
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

AMXMODX_BASE_URL="https://amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5474-base-linux.tar.gz"
AMXMODX_CSTRIKE_URL="https://amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5474-cstrike-linux.tar.gz"

REAPI_URL="https://github.com/rehlds/ReAPI/releases/download/5.26.0.338/reapi-bin-5.26.0.338.zip"

YAPB_URL="https://github.com/yapb/yapb/releases/download/4.4.957/yapb-4.4.957-linux.tar.xz"

WSS_REPO_URL="https://raw.githubusercontent.com/Mistrick/WeaponSkinSystem/master"

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
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
test_header() { echo -e "\n${CYAN}[TEST]${NC}  ${BOLD}$1${NC}"; }
test_pass()   { echo -e "  ${GREEN}✔ PASS${NC}  $1"; }
test_fail()   { echo -e "  ${RED}✘ FAIL${NC}  $1"; VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1)); }
test_warn()   { echo -e "  ${YELLOW}⚠ WARN${NC}  $1"; VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1)); }

TOTAL_STEPS=13
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# ─── Validation Helper Functions ─────────────────────────────────────────────

check_file_exists() {
    local file="$1" label="${2:-$1}"
    [ -f "$file" ] && { test_pass "Exists: $label"; return 0; } || { test_fail "Missing: $label"; return 1; }
}

check_dir_exists() {
    local dir="$1" label="${2:-$1}"
    [ -d "$dir" ] && { test_pass "Dir exists: $label"; return 0; } || { test_fail "Dir missing: $label"; return 1; }
}

check_elf_binary() {
    local file="$1" label="${2:-$1}"
    [ -f "$file" ] || { test_fail "ELF check — file missing: $label"; return 1; }
    local ft; ft=$(file -b "$file" 2>/dev/null)
    if echo "$ft" | grep -q "ELF 32-bit.*shared object"; then
        test_pass "Valid ELF 32-bit .so: $label"
    elif echo "$ft" | grep -q "ELF"; then
        test_warn "ELF but unexpected type: $label ($ft)"
    else
        test_fail "NOT ELF (corrupt?): $label — got: $(echo "$ft" | head -c 80)"
    fi
}

check_elf_executable() {
    local file="$1" label="${2:-$1}"
    [ -f "$file" ] || { test_fail "ELF exec — file missing: $label"; return 1; }
    local ft; ft=$(file -b "$file" 2>/dev/null)
    echo "$ft" | grep -q "ELF" && { test_pass "Valid ELF binary: $label"; return 0; } || { test_fail "NOT ELF binary: $label — got: $(echo "$ft" | head -c 80)"; return 1; }
}

check_executable_perm() {
    local file="$1" label="${2:-$1}"
    [ -f "$file" ] || { test_fail "Perm check — file missing: $label"; return 1; }
    [ -x "$file" ] && { test_pass "Execute permission OK: $label"; return 0; } || { test_fail "No execute permission: $label"; return 1; }
}

check_file_size() {
    local file="$1" min_bytes="${2:-1}" label="${3:-$1}"
    [ -f "$file" ] || { test_fail "Size check — file missing: $label"; return 1; }
    local sz; sz=$(stat -c%s "$file" 2>/dev/null || echo 0)
    [ "$sz" -ge "$min_bytes" ] && { test_pass "Size OK (${sz}B >= ${min_bytes}B): $label"; return 0; } || { test_fail "Too small (${sz}B < ${min_bytes}B): $label"; return 1; }
}

check_file_contains() {
    local file="$1" pattern="$2" label="${3:-$1 contains '$2'}"
    [ -f "$file" ] || { test_fail "Content check — file missing: $label"; return 1; }
    grep -q "$pattern" "$file" 2>/dev/null && { test_pass "Content OK: $label"; return 0; } || { test_fail "Content missing: $label"; return 1; }
}

check_file_not_contains() {
    local file="$1" pattern="$2" label="${3:-$1 must not contain '$2'}"
    [ -f "$file" ] || { test_fail "Neg-content check — missing: $label"; return 1; }
    grep -q "$pattern" "$file" 2>/dev/null && { test_fail "Unwanted content found: $label"; return 1; } || { test_pass "Neg-content OK: $label"; return 0; }
}

check_not_html() {
    local file="$1" label="${2:-$1}"
    [ -f "$file" ] || { test_fail "HTML check — missing: $label"; return 1; }
    # Use tr to strip null bytes before grep to avoid bash warnings on binary files
    local hd; hd=$(head -c 200 "$file" 2>/dev/null | tr -d '\0')
    echo "$hd" | grep -qi "<!DOCTYPE\|<html\|404.*Not Found" && { test_fail "HTML error page (bad download): $label"; return 1; } || { test_pass "Not HTML error page: $label"; return 0; }
}

check_command_exists() {
    local cmd="$1" label="${2:-$1}"
    command -v "$cmd" &>/dev/null && { test_pass "Command found: $label"; return 0; } || { test_fail "Command not found: $label"; return 1; }
}

check_file_owner() {
    local file="$1" label="${2:-$1}"
    [ -e "$file" ] || { test_fail "Owner check — not found: $label"; return 1; }
    local owner; owner=$(stat -c%U "$file" 2>/dev/null)
    [ "$owner" = "$(whoami)" ] && { test_pass "Owner OK ($(whoami)): $label"; return 0; } || { test_warn "Owner is '$owner' not '$(whoami)': $label"; return 0; }
}

# Check that a binary file contains an expected embedded string (uses `strings` command)
check_binary_string() {
    local file="$1" pattern="$2" label="${3:-$1 contains '$2'}"
    [ -f "$file" ] || { test_fail "Binary string check — file missing: $label"; return 1; }
    if strings "$file" 2>/dev/null | grep -qi "$pattern"; then
        test_pass "Binary string found: $label"
        return 0
    else
        test_fail "Binary string NOT found: $label"
        return 1
    fi
}

# Check that a binary does NOT contain a specific string
check_binary_no_string() {
    local file="$1" pattern="$2" label="${3:-$1 must not contain '$2'}"
    [ -f "$file" ] || { test_fail "Binary neg-string check — missing: $label"; return 1; }
    if strings "$file" 2>/dev/null | grep -qi "$pattern"; then
        test_fail "Unwanted binary string found: $label"
        return 1
    else
        test_pass "Binary neg-string OK: $label"
        return 0
    fi
}

# Extract and display a version string from a binary
check_binary_version() {
    local file="$1" pattern="$2" label="${3:-$1}"
    [ -f "$file" ] || { test_fail "Version extract — file missing: $label"; return 1; }
    local ver
    ver=$(strings "$file" 2>/dev/null | grep -oiE "$pattern" | head -1)
    if [ -n "$ver" ]; then
        test_pass "Version: $label → $ver"
        return 0
    else
        test_warn "Could not extract version from: $label"
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALLATION STEPS
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Step 1: Install system dependencies ─────────────────────────────────────
info "Step 1/${TOTAL_STEPS}: Installing system dependencies..."

sudo dpkg --add-architecture i386
sudo apt-get update -qq
sudo apt-get install -y \
    lib32gcc-s1 lib32stdc++6 libc6-i386 lib32z1 \
    curl tar unzip screen ca-certificates xz-utils file

test_header "Validating Step 1: System dependencies"
check_command_exists "curl"
check_command_exists "tar"
check_command_exists "unzip"
check_command_exists "screen"
check_command_exists "file" "file (binary inspection)"
check_command_exists "xz" "xz (tar.xz extraction)"
dpkg --print-foreign-architectures 2>/dev/null | grep -q "i386" \
    && test_pass "i386 architecture enabled" \
    || test_fail "i386 architecture not enabled"
# 32-bit zlib
([ -f "/lib32/libz.so.1" ] || [ -f "/usr/lib32/libz.so.1" ] || ldconfig -p 2>/dev/null | grep -q "libz.so.1.*32") \
    && test_pass "32-bit zlib available" \
    || test_warn "Could not confirm 32-bit zlib"

info "System dependencies installed."

# ─── Step 2: Install SteamCMD ────────────────────────────────────────────────
info "Step 2/${TOTAL_STEPS}: Installing SteamCMD..."

mkdir -p "$STEAMCMD_DIR" && cd "$STEAMCMD_DIR"
if [ ! -f "$STEAMCMD_DIR/steamcmd.sh" ]; then
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar xzf -
fi

test_header "Validating Step 2: SteamCMD"
check_file_exists "$STEAMCMD_DIR/steamcmd.sh" "steamcmd.sh"
check_executable_perm "$STEAMCMD_DIR/steamcmd.sh" "steamcmd.sh"
check_file_size "$STEAMCMD_DIR/steamcmd.sh" 100 "steamcmd.sh (>100B)"
check_file_owner "$STEAMCMD_DIR/steamcmd.sh" "steamcmd.sh"
[ -d "$STEAMCMD_DIR/linux32" ] \
    && test_pass "SteamCMD linux32 runtime dir exists" \
    || test_warn "SteamCMD linux32 dir missing (downloads on first run)"

info "SteamCMD installed."

# ─── Step 3: Download HLDS ──────────────────────────────────────────────────
info "Step 3/${TOTAL_STEPS}: Downloading HLDS (Counter-Strike 1.6)..."
info "SteamCMD can be flaky — running up to 3 attempts."

for attempt in 1 2 3; do
    info "  Attempt $attempt/3..."
    "$STEAMCMD_DIR/steamcmd.sh" \
        +force_install_dir "$HLDS_DIR" \
        +login anonymous \
        +app_set_config 90 mod cstrike \
        +app_update 90 -beta steam_legacy validate \
        +quit && break
    [ "$attempt" -eq 3 ] && error "HLDS download failed after 3 attempts."
    warn "  Retrying in 5s..." && sleep 5
done

test_header "Validating Step 3: HLDS base"
check_dir_exists "$HLDS_DIR" "HLDS root"
check_dir_exists "$HLDS_DIR/cstrike" "cstrike/"
check_dir_exists "$HLDS_DIR/cstrike/maps" "cstrike/maps/"
check_dir_exists "$HLDS_DIR/cstrike/models" "cstrike/models/"
check_file_exists "$HLDS_DIR/hlds_run" "hlds_run"
check_executable_perm "$HLDS_DIR/hlds_run" "hlds_run"
check_file_exists "$HLDS_DIR/hlds_linux" "hlds_linux"
check_elf_executable "$HLDS_DIR/hlds_linux" "hlds_linux"
check_executable_perm "$HLDS_DIR/hlds_linux" "hlds_linux"
check_file_exists "$HLDS_DIR/engine_i486.so" "engine_i486.so (stock)"
check_elf_binary "$HLDS_DIR/engine_i486.so" "engine_i486.so"
check_file_exists "$HLDS_DIR/cstrike/liblist.gam" "liblist.gam"
check_file_exists "$HLDS_DIR/cstrike/maps/de_dust2.bsp" "de_dust2.bsp"
check_file_size "$HLDS_DIR/cstrike/maps/de_dust2.bsp" 10000 "de_dust2.bsp (>10KB)"

info "HLDS downloaded."

# ─── Step 4: Download & extract all components ──────────────────────────────
info "Step 4/${TOTAL_STEPS}: Downloading all components..."

mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

curl -sLO "$REHLDS_URL"
curl -sLO "$REGAMEDLL_URL"
curl -sLO "$METAMOD_URL"
curl -sLO "$REUNION_URL"
curl -sLo amxmodx-base-linux.tar.gz "$AMXMODX_BASE_URL"
curl -sLo amxmodx-cstrike-linux.tar.gz "$AMXMODX_CSTRIKE_URL"
curl -sLo reapi-bin.zip "$REAPI_URL"
curl -sLo yapb-linux.tar.xz "$YAPB_URL"

mkdir -p "$WORK_DIR/wss"
curl -sLo "$WORK_DIR/wss/weapon_skin_system.sma" "$WSS_REPO_URL/weapon_skin_system.sma" || true
curl -sLo "$WORK_DIR/wss/weapon_skin_system.inc" "$WSS_REPO_URL/include/weapon_skin_system.inc" || true
curl -sLo "$WORK_DIR/wss/weapon_skins.ini" "$WSS_REPO_URL/weapon_skins.ini" || true

test_header "Validating Step 4a: Downloaded archives (existence + size + not-HTML)"
for arc_info in \
    "rehlds-bin-3.14.0.857.zip:ReHLDS:50000" \
    "regamedll-bin-5.28.0.756.zip:ReGameDLL:50000" \
    "metamod-bin-1.3.0.149.zip:Metamod-R:10000" \
    "reunion-0.2.0.25.zip:ReUnion:10000" \
    "amxmodx-base-linux.tar.gz:AMXX-base:100000" \
    "amxmodx-cstrike-linux.tar.gz:AMXX-cstrike:10000" \
    "reapi-bin.zip:ReAPI:50000" \
    "yapb-linux.tar.xz:YaPB:50000"; do
    IFS=':' read -r fname label minsz <<< "$arc_info"
    check_file_exists "$WORK_DIR/$fname" "$label archive"
    check_file_size "$WORK_DIR/$fname" "$minsz" "$label (>${minsz}B)"
    check_not_html "$WORK_DIR/$fname" "$label archive"
done

test_header "Validating Step 4b: WSS source files"
check_file_exists "$WORK_DIR/wss/weapon_skin_system.sma" "weapon_skin_system.sma"
check_file_size "$WORK_DIR/wss/weapon_skin_system.sma" 1000 "weapon_skin_system.sma (>1KB)"
check_not_html "$WORK_DIR/wss/weapon_skin_system.sma" "weapon_skin_system.sma"
check_file_contains "$WORK_DIR/wss/weapon_skin_system.sma" "#include <amxmodx>" ".sma has AMXX include"
check_file_contains "$WORK_DIR/wss/weapon_skin_system.sma" "Weapon Skin System" ".sma has plugin name"
check_file_exists "$WORK_DIR/wss/weapon_skin_system.inc" "weapon_skin_system.inc"
check_not_html "$WORK_DIR/wss/weapon_skin_system.inc" "weapon_skin_system.inc"

# Extract all
unzip -qo rehlds-bin-3.14.0.857.zip    -d rehlds-temp
unzip -qo regamedll-bin-5.28.0.756.zip -d regamedll-temp
unzip -qo metamod-bin-1.3.0.149.zip    -d metamod-temp
unzip -qo reunion-0.2.0.25.zip         -d reunion-temp
unzip -qo reapi-bin.zip                -d reapi-temp
mkdir -p "$WORK_DIR/amxmodx-temp"
tar xzf amxmodx-base-linux.tar.gz    -C "$WORK_DIR/amxmodx-temp"
tar xzf amxmodx-cstrike-linux.tar.gz -C "$WORK_DIR/amxmodx-temp"
mkdir -p "$WORK_DIR/yapb-temp"
tar xJf yapb-linux.tar.xz -C "$WORK_DIR/yapb-temp"

test_header "Validating Step 4c: Extracted directories & key binaries"
check_dir_exists "$WORK_DIR/rehlds-temp/bin/linux32" "ReHLDS linux32/"
check_dir_exists "$WORK_DIR/regamedll-temp/bin/linux32" "ReGameDLL linux32/"
check_dir_exists "$WORK_DIR/metamod-temp/addons/metamod" "Metamod addons/"
check_dir_exists "$WORK_DIR/amxmodx-temp/addons/amxmodx" "AMXX addons/"
check_dir_exists "$WORK_DIR/reapi-temp/addons" "ReAPI addons/"
# Verify key extracted .so files are real ELF binaries
REHLDS_SO=$(find "$WORK_DIR/rehlds-temp" -name "engine_i486.so" | head -1)
[ -n "$REHLDS_SO" ] && check_elf_binary "$REHLDS_SO" "ReHLDS engine_i486.so (extracted)" || test_fail "ReHLDS engine_i486.so not found in archive"
META_SO=$(find "$WORK_DIR/metamod-temp" -name "metamod_i386.so" | head -1)
[ -n "$META_SO" ] && check_elf_binary "$META_SO" "Metamod .so (extracted)" || test_fail "metamod_i386.so not found in archive"
REUN_SO=$(find "$WORK_DIR/reunion-temp" -name "reunion_mm_i386.so" | head -1)
[ -n "$REUN_SO" ] && check_elf_binary "$REUN_SO" "ReUnion .so (extracted)" || test_fail "reunion_mm_i386.so not found in archive"

info "All components downloaded and extracted."

# ─── Step 5: Install ReHLDS ─────────────────────────────────────────────────
info "Step 5/${TOTAL_STEPS}: Installing ReHLDS engine..."
cp -r "$WORK_DIR/rehlds-temp/bin/linux32/"* "$HLDS_DIR/"

test_header "Validating Step 5: ReHLDS engine"
check_file_exists "$HLDS_DIR/engine_i486.so" "engine_i486.so"
check_elf_binary "$HLDS_DIR/engine_i486.so" "engine_i486.so"
check_file_size "$HLDS_DIR/engine_i486.so" 500000 "engine_i486.so (>500KB = ReHLDS)"
check_file_owner "$HLDS_DIR/engine_i486.so" "engine_i486.so"
[ -f "$HLDS_DIR/hlds_linux" ] && check_executable_perm "$HLDS_DIR/hlds_linux" "hlds_linux"
# Binary identity: ReHLDS embeds "sv_rehlds_" cvars and "ReHLDS" string
check_binary_string "$HLDS_DIR/engine_i486.so" "sv_rehlds" "engine_i486.so is ReHLDS (has sv_rehlds cvars)"
check_binary_string "$HLDS_DIR/engine_i486.so" "rehlds" "engine_i486.so has 'rehlds' identifier"
check_binary_version "$HLDS_DIR/engine_i486.so" "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" "ReHLDS engine version"

info "ReHLDS installed."

# ─── Step 6: Install ReGameDLL_CS ───────────────────────────────────────────
info "Step 6/${TOTAL_STEPS}: Installing ReGameDLL_CS..."
cp -r "$WORK_DIR/regamedll-temp/bin/linux32/"* "$HLDS_DIR/"
[ -d "$WORK_DIR/regamedll-temp/dist" ] && cp -rn "$WORK_DIR/regamedll-temp/dist/"* "$HLDS_DIR/cstrike/" 2>/dev/null || true

test_header "Validating Step 6: ReGameDLL_CS"
RGDLL=$(find "$HLDS_DIR" -maxdepth 1 \( -name "cs.so" -o -name "mp.so" \) 2>/dev/null | head -1)
if [ -z "$RGDLL" ]; then
    RGDLL=$(find "$HLDS_DIR/cstrike" -name "cs.so" -o -name "mp.so" 2>/dev/null | head -1)
fi
if [ -n "$RGDLL" ]; then
    check_elf_binary "$RGDLL" "$(basename "$RGDLL") (ReGameDLL)"
    check_file_size "$RGDLL" 500000 "$(basename "$RGDLL") (>500KB)"
    # Binary identity: ReGameDLL embeds "regamedll" and version strings
    check_binary_string "$RGDLL" "regamedll" "$(basename "$RGDLL") is ReGameDLL (has 'regamedll' identifier)"
    check_binary_string "$RGDLL" "ReGameDLL" "$(basename "$RGDLL") has 'ReGameDLL' string"
    check_binary_version "$RGDLL" "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" "ReGameDLL version"
else
    test_warn "Could not locate ReGameDLL .so (cs.so/mp.so)"
fi
([ -f "$HLDS_DIR/cstrike/game.cfg" ] || [ -f "$HLDS_DIR/cstrike/gamemode.cfg" ]) \
    && test_pass "ReGameDLL extra configs present" \
    || test_warn "ReGameDLL extra configs not found (optional)"

info "ReGameDLL_CS installed."

# ─── Step 7: Install Metamod-R ──────────────────────────────────────────────
info "Step 7/${TOTAL_STEPS}: Installing Metamod-R..."
cp -r "$WORK_DIR/metamod-temp/addons" "$HLDS_DIR/cstrike/"

LIBLIST="$HLDS_DIR/cstrike/liblist.gam"
if [ -f "$LIBLIST" ]; then
    sed -i 's|^gamedll_linux.*|gamedll_linux "addons/metamod/metamod_i386.so"|' "$LIBLIST"
else
    warn "liblist.gam not found — creating it."
    echo 'gamedll_linux "addons/metamod/metamod_i386.so"' > "$LIBLIST"
fi
touch "$HLDS_DIR/cstrike/addons/metamod/plugins.ini"

test_header "Validating Step 7: Metamod-R"
check_dir_exists "$HLDS_DIR/cstrike/addons/metamod" "addons/metamod/"
check_file_exists "$HLDS_DIR/cstrike/addons/metamod/metamod_i386.so" "metamod_i386.so"
check_elf_binary "$HLDS_DIR/cstrike/addons/metamod/metamod_i386.so" "metamod_i386.so"
check_file_size "$HLDS_DIR/cstrike/addons/metamod/metamod_i386.so" 50000 "metamod_i386.so (>50KB)"
check_file_exists "$HLDS_DIR/cstrike/addons/metamod/plugins.ini" "metamod/plugins.ini"
check_file_exists "$LIBLIST" "liblist.gam"
check_file_contains "$LIBLIST" 'addons/metamod/metamod_i386.so' "liblist.gam → metamod"
check_file_not_contains "$LIBLIST" '^gamedll_linux.*dlls/cs.so' "liblist.gam no longer → stock cs.so"
# Binary identity: Metamod-R embeds "metamod-r" or "Metamod-r" strings
check_binary_string "$HLDS_DIR/cstrike/addons/metamod/metamod_i386.so" "metamod-r\|Metamod-r\|metamod_r" "metamod_i386.so is Metamod-R (not stock Metamod)"
check_binary_version "$HLDS_DIR/cstrike/addons/metamod/metamod_i386.so" "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" "Metamod-R version"

info "Metamod-R installed."

# ─── Step 8: Install ReUnion ────────────────────────────────────────────────
info "Step 8/${TOTAL_STEPS}: Installing ReUnion..."
mkdir -p "$HLDS_DIR/cstrike/addons/reunion"

REUNION_SO=$(find "$WORK_DIR/reunion-temp" -name "reunion_mm_i386.so" | head -1)
[ -z "$REUNION_SO" ] && error "reunion_mm_i386.so not found in archive!"
cp "$REUNION_SO" "$HLDS_DIR/cstrike/addons/reunion/"

REUNION_CFG=$(find "$WORK_DIR/reunion-temp" -name "reunion.cfg" | head -1)
[ -z "$REUNION_CFG" ] && error "reunion.cfg not found in archive!"
cp "$REUNION_CFG" "$HLDS_DIR/cstrike/"

sed -i "s|^SteamIdHashSalt.*|SteamIdHashSalt = \"$REUNION_SALT\"|" "$HLDS_DIR/cstrike/reunion.cfg"

test_header "Validating Step 8: ReUnion"
check_dir_exists "$HLDS_DIR/cstrike/addons/reunion" "addons/reunion/"
check_file_exists "$HLDS_DIR/cstrike/addons/reunion/reunion_mm_i386.so" "reunion_mm_i386.so"
check_elf_binary "$HLDS_DIR/cstrike/addons/reunion/reunion_mm_i386.so" "reunion_mm_i386.so"
check_file_size "$HLDS_DIR/cstrike/addons/reunion/reunion_mm_i386.so" 10000 "reunion_mm_i386.so (>10KB)"
check_file_exists "$HLDS_DIR/cstrike/reunion.cfg" "reunion.cfg"
check_file_size "$HLDS_DIR/cstrike/reunion.cfg" 100 "reunion.cfg (>100B)"
check_file_contains "$HLDS_DIR/cstrike/reunion.cfg" "SteamIdHashSalt" "reunion.cfg has SteamIdHashSalt key"
grep -q "SteamIdHashSalt = \"rehlds_salt_" "$HLDS_DIR/cstrike/reunion.cfg" 2>/dev/null \
    && test_pass "SteamIdHashSalt value is set (>16 chars)" \
    || test_fail "SteamIdHashSalt not properly set"
# Binary identity: ReUnion embeds "reunion" and version strings
check_binary_string "$HLDS_DIR/cstrike/addons/reunion/reunion_mm_i386.so" "reunion" "reunion_mm_i386.so has 'reunion' identifier"
check_binary_string "$HLDS_DIR/cstrike/addons/reunion/reunion_mm_i386.so" "SteamIdHashSalt" "reunion .so has SteamIdHashSalt cvar"
check_binary_version "$HLDS_DIR/cstrike/addons/reunion/reunion_mm_i386.so" "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" "ReUnion version"

info "ReUnion installed."

# ─── Step 9: Install AMX Mod X ──────────────────────────────────────────────
info "Step 9/${TOTAL_STEPS}: Installing AMX Mod X 1.10.0..."
cp -r "$WORK_DIR/amxmodx-temp/addons/amxmodx" "$HLDS_DIR/cstrike/addons/"

test_header "Validating Step 9: AMX Mod X"
for d in dlls modules plugins configs scripting scripting/include logs data; do
    check_dir_exists "$HLDS_DIR/cstrike/addons/amxmodx/$d" "amxmodx/$d"
done
check_file_exists "$HLDS_DIR/cstrike/addons/amxmodx/dlls/amxmodx_mm_i386.so" "amxmodx_mm_i386.so"
check_elf_binary "$HLDS_DIR/cstrike/addons/amxmodx/dlls/amxmodx_mm_i386.so" "amxmodx_mm_i386.so"
check_file_size "$HLDS_DIR/cstrike/addons/amxmodx/dlls/amxmodx_mm_i386.so" 100000 "amxmodx_mm_i386.so (>100KB)"
# Key modules
for mod in fun_amxx_i386.so engine_amxx_i386.so fakemeta_amxx_i386.so cstrike_amxx_i386.so hamsandwich_amxx_i386.so; do
    [ -f "$HLDS_DIR/cstrike/addons/amxmodx/modules/$mod" ] \
        && check_elf_binary "$HLDS_DIR/cstrike/addons/amxmodx/modules/$mod" "$mod" \
        || test_warn "Optional module not found: $mod"
done
# Compiler
check_file_exists "$HLDS_DIR/cstrike/addons/amxmodx/scripting/amxxpc" "amxxpc compiler"
check_executable_perm "$HLDS_DIR/cstrike/addons/amxmodx/scripting/amxxpc" "amxxpc"
check_elf_executable "$HLDS_DIR/cstrike/addons/amxmodx/scripting/amxxpc" "amxxpc"
# Configs
for cfg in plugins.ini modules.ini users.ini amxx.cfg; do
    check_file_exists "$HLDS_DIR/cstrike/addons/amxmodx/configs/$cfg" "AMXX $cfg"
done
# Core plugins
for plug in admin.amxx adminhelp.amxx adminslots.amxx menufront.amxx cmdmenu.amxx; do
    check_file_exists "$HLDS_DIR/cstrike/addons/amxmodx/plugins/$plug" "$plug"
done
# Binary identity: AMX Mod X .so embeds "AMX Mod X" and version
check_binary_string "$HLDS_DIR/cstrike/addons/amxmodx/dlls/amxmodx_mm_i386.so" "AMX Mod X" "amxmodx_mm_i386.so has 'AMX Mod X' identifier"
check_binary_version "$HLDS_DIR/cstrike/addons/amxmodx/dlls/amxmodx_mm_i386.so" "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" "AMX Mod X version"

info "AMX Mod X installed."

# ─── Step 10: Install ReAPI ─────────────────────────────────────────────────
info "Step 10/${TOTAL_STEPS}: Installing ReAPI 5.26.0.338..."
if [ -d "$WORK_DIR/reapi-temp/addons" ]; then
    cp -r "$WORK_DIR/reapi-temp/addons/amxmodx/modules/"* "$HLDS_DIR/cstrike/addons/amxmodx/modules/" 2>/dev/null || true
    [ -d "$WORK_DIR/reapi-temp/addons/amxmodx/scripting/include" ] && \
        cp -r "$WORK_DIR/reapi-temp/addons/amxmodx/scripting/include/"* "$HLDS_DIR/cstrike/addons/amxmodx/scripting/include/" 2>/dev/null || true
fi

test_header "Validating Step 10: ReAPI"
check_file_exists "$HLDS_DIR/cstrike/addons/amxmodx/modules/reapi_amxx_i386.so" "reapi_amxx_i386.so"
check_elf_binary "$HLDS_DIR/cstrike/addons/amxmodx/modules/reapi_amxx_i386.so" "reapi_amxx_i386.so"
check_file_size "$HLDS_DIR/cstrike/addons/amxmodx/modules/reapi_amxx_i386.so" 50000 "reapi_amxx_i386.so (>50KB)"
check_file_exists "$HLDS_DIR/cstrike/addons/amxmodx/scripting/include/reapi.inc" "reapi.inc"
check_file_contains "$HLDS_DIR/cstrike/addons/amxmodx/scripting/include/reapi.inc" "is_rehlds" "reapi.inc has expected native"
# Binary identity: ReAPI .so embeds "ReAPI" and "reapi"
check_binary_string "$HLDS_DIR/cstrike/addons/amxmodx/modules/reapi_amxx_i386.so" "reapi\|ReAPI" "reapi_amxx_i386.so has 'reapi' identifier"
check_binary_version "$HLDS_DIR/cstrike/addons/amxmodx/modules/reapi_amxx_i386.so" "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" "ReAPI version"

info "ReAPI installed."

# ─── Step 11: Install YaPB ──────────────────────────────────────────────────
info "Step 11/${TOTAL_STEPS}: Installing YaPB 4.4.957..."
if [ -d "$WORK_DIR/yapb-temp/addons/yapb" ]; then
    cp -r "$WORK_DIR/yapb-temp/addons/yapb" "$HLDS_DIR/cstrike/addons/"
elif [ -d "$WORK_DIR/yapb-temp/yapb" ]; then
    mkdir -p "$HLDS_DIR/cstrike/addons/yapb"
    cp -r "$WORK_DIR/yapb-temp/yapb/"* "$HLDS_DIR/cstrike/addons/yapb/"
else
    YAPB_SO=$(find "$WORK_DIR/yapb-temp" -name "yapb.so" | head -1)
    if [ -n "$YAPB_SO" ]; then
        mkdir -p "$HLDS_DIR/cstrike/addons/yapb/bin"
        cp "$YAPB_SO" "$HLDS_DIR/cstrike/addons/yapb/bin/"
        YAPB_BASE=$(dirname "$(dirname "$YAPB_SO")")
        [ -d "$YAPB_BASE/conf" ] && cp -r "$YAPB_BASE/conf" "$HLDS_DIR/cstrike/addons/yapb/"
        [ -d "$YAPB_BASE/data" ] && cp -r "$YAPB_BASE/data" "$HLDS_DIR/cstrike/addons/yapb/"
    else
        warn "Could not find yapb.so — install YaPB manually."
    fi
fi

test_header "Validating Step 11: YaPB"
check_dir_exists "$HLDS_DIR/cstrike/addons/yapb" "addons/yapb/"
YAPB_INSTALLED=$(find "$HLDS_DIR/cstrike/addons/yapb" -name "yapb.so" | head -1)
if [ -n "$YAPB_INSTALLED" ]; then
    check_elf_binary "$YAPB_INSTALLED" "yapb.so"
    check_file_size "$YAPB_INSTALLED" 50000 "yapb.so (>50KB)"
    # Binary identity: YaPB embeds "yapb" and "YaPB" strings
    check_binary_string "$YAPB_INSTALLED" "yapb\|YaPB" "yapb.so has 'yapb' identifier"
    check_binary_version "$YAPB_INSTALLED" "[0-9]\+\.[0-9]\+\.[0-9]\+" "YaPB version"
else
    test_fail "yapb.so not found in addons/yapb/"
fi
[ -d "$HLDS_DIR/cstrike/addons/yapb/data" ] \
    && test_pass "YaPB data/ dir present" \
    || test_warn "YaPB data/ dir missing (bots may lack waypoints)"
if [ -d "$HLDS_DIR/cstrike/addons/yapb/data" ]; then
    WPC=$(find "$HLDS_DIR/cstrike/addons/yapb/data" -name "*.pwf" 2>/dev/null | wc -l)
    [ "$WPC" -gt 0 ] && test_pass "Waypoint files: $WPC maps" || test_warn "No .pwf waypoint files"
fi
[ -d "$HLDS_DIR/cstrike/addons/yapb/conf" ] \
    && test_pass "YaPB conf/ dir present" \
    || test_warn "YaPB conf/ dir missing"

info "YaPB installed."

# ─── Step 12: Install WeaponSkinSystem ──────────────────────────────────────
info "Step 12/${TOTAL_STEPS}: Installing WeaponSkinSystem (Mistrick)..."

AMXX_SCRIPTING="$HLDS_DIR/cstrike/addons/amxmodx/scripting"
AMXX_PLUGINS="$HLDS_DIR/cstrike/addons/amxmodx/plugins"
AMXX_CONFIGS="$HLDS_DIR/cstrike/addons/amxmodx/configs"
AMXX_INCLUDE="$AMXX_SCRIPTING/include"

[ -f "$WORK_DIR/wss/weapon_skin_system.inc" ] && cp "$WORK_DIR/wss/weapon_skin_system.inc" "$AMXX_INCLUDE/"
[ -f "$WORK_DIR/wss/weapon_skin_system.sma" ] && cp "$WORK_DIR/wss/weapon_skin_system.sma" "$AMXX_SCRIPTING/"

# Compile
WSS_COMPILE_OK=0
COMPILE_OUTPUT=""
if [ -x "$AMXX_SCRIPTING/amxxpc" ]; then
    cd "$AMXX_SCRIPTING"
    info "  Compiling weapon_skin_system.sma..."
    COMPILE_OUTPUT=$(./amxxpc weapon_skin_system.sma -o"$AMXX_PLUGINS/weapon_skin_system.amxx" 2>&1) || true
    echo "$COMPILE_OUTPUT"
    [ -f "$AMXX_PLUGINS/weapon_skin_system.amxx" ] && WSS_COMPILE_OK=1
else
    warn "AMXX compiler not found — compile manually."
fi

cat > "$AMXX_CONFIGS/weapon_skins.ini" << 'SKINEOF'
; WeaponSkinSystem config — weapon_skins.ini
; Format: weapon_<n> "Skin Display Name" "models/custom/v_<weapon>.mdl" "models/custom/p_<weapon>.mdl" "models/custom/w_<weapon>.mdl"
;
; Suggested skins (GameBanana):
;   https://gamebanana.com/mods/640080  — AK-47 Blood Dragon Japan
;   https://gamebanana.com/mods/658487  — CrossFire G Spirit Pack
;   https://gamebanana.com/mods/648450  — v_ak47 custom
;   https://gamebanana.com/mods/610900  — M4A1-S Night Terror
;
; Example (uncomment after placing models):
; weapon_ak47 "Blood Dragon AK47" "models/custom/ak47_blood_dragon/v_ak47.mdl" "models/custom/ak47_blood_dragon/p_ak47.mdl" "models/custom/ak47_blood_dragon/w_ak47.mdl"
SKINEOF

mkdir -p "$HLDS_DIR/cstrike/models/custom"

AMXX_PLUGINS_INI="$AMXX_CONFIGS/plugins.ini"
[ -f "$AMXX_PLUGINS_INI" ] && grep -q "weapon_skin_system.amxx" "$AMXX_PLUGINS_INI" 2>/dev/null \
    || echo 'weapon_skin_system.amxx' >> "$AMXX_PLUGINS_INI"

test_header "Validating Step 12: WeaponSkinSystem"
check_file_exists "$AMXX_SCRIPTING/weapon_skin_system.sma" "weapon_skin_system.sma (source)"
check_file_contains "$AMXX_SCRIPTING/weapon_skin_system.sma" "#include <amxmodx>" ".sma has valid header"
check_file_not_contains "$AMXX_SCRIPTING/weapon_skin_system.sma" "<!DOCTYPE" ".sma is not HTML garbage"
check_file_exists "$AMXX_INCLUDE/weapon_skin_system.inc" "weapon_skin_system.inc"
check_not_html "$AMXX_INCLUDE/weapon_skin_system.inc" "weapon_skin_system.inc"

if [ "$WSS_COMPILE_OK" -eq 1 ]; then
    check_file_exists "$AMXX_PLUGINS/weapon_skin_system.amxx" "weapon_skin_system.amxx (compiled)"
    check_file_size "$AMXX_PLUGINS/weapon_skin_system.amxx" 1000 "weapon_skin_system.amxx (>1KB)"
    check_not_html "$AMXX_PLUGINS/weapon_skin_system.amxx" "weapon_skin_system.amxx"
    echo "$COMPILE_OUTPUT" | grep -qi "error" \
        && test_fail "Compiler output had errors" \
        || test_pass "Compiler output clean"
    echo "$COMPILE_OUTPUT" | grep -q "Done\." \
        && test_pass "Compiler reported Done" \
        || test_warn "Compiler did not explicitly say Done"
else
    test_fail "weapon_skin_system.amxx was not compiled"
fi

check_file_exists "$AMXX_CONFIGS/weapon_skins.ini" "weapon_skins.ini"
check_file_contains "$AMXX_PLUGINS_INI" "weapon_skin_system.amxx" "AMXX plugins.ini → weapon_skin_system"
check_dir_exists "$HLDS_DIR/cstrike/models/custom" "models/custom/"

info "WeaponSkinSystem installed."

# ─── Step 13: Configure Metamod plugins.ini ─────────────────────────────────
info "Step 13/${TOTAL_STEPS}: Configuring Metamod plugins.ini..."

PLUGINS_INI="$HLDS_DIR/cstrike/addons/metamod/plugins.ini"
# NOTE: ReAPI is an AMXX *module* (loaded by AMXX via modules.ini), NOT a Metamod plugin.
#       It lives in addons/amxmodx/modules/ and AMXX auto-loads it.
#       Only true Metamod plugins (_mm_ suffix) go here.
cat > "$PLUGINS_INI" << 'METAEOF'
linux addons/reunion/reunion_mm_i386.so
linux addons/amxmodx/dlls/amxmodx_mm_i386.so
linux addons/yapb/bin/yapb.so
METAEOF

test_header "Validating Step 13: Metamod plugins.ini"
check_file_exists "$PLUGINS_INI" "metamod/plugins.ini"
check_file_contains "$PLUGINS_INI" "reunion_mm_i386.so" "→ ReUnion"
check_file_contains "$PLUGINS_INI" "amxmodx_mm_i386.so" "→ AMX Mod X"
check_file_contains "$PLUGINS_INI" "yapb.so" "→ YaPB"
# ReAPI must NOT be in metamod plugins.ini — it's an AMXX module
check_file_not_contains "$PLUGINS_INI" "reapi_amxx" "ReAPI not in metamod (it's an AMXX module)"

# Cross-reference: every .so in plugins.ini must exist and be a valid ELF
while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    so_path=$(echo "$line" | awk '{print $2}')
    [ -z "$so_path" ] && continue
    full="$HLDS_DIR/cstrike/$so_path"
    if [ -f "$full" ]; then
        check_elf_binary "$full" "plugins.ini → $so_path"
    else
        test_fail "plugins.ini references MISSING file: $so_path"
    fi
done < "$PLUGINS_INI"

PCOUNT=$(grep -c "^linux " "$PLUGINS_INI" 2>/dev/null || echo 0)
[ "$PCOUNT" -eq 3 ] && test_pass "plugins.ini: exactly 3 Metamod entries" || test_warn "plugins.ini: $PCOUNT entries (expected 3)"

# Verify ReAPI is loadable by AMXX (exists in modules/ dir)
check_file_exists "$HLDS_DIR/cstrike/addons/amxmodx/modules/reapi_amxx_i386.so" "ReAPI in AMXX modules/ (auto-loaded by AMXX)"

info "Metamod plugins.ini configured."

# ─── Write configs & start script ───────────────────────────────────────────
info "Writing steam_appid.txt..."
echo "10" > "$HLDS_DIR/steam_appid.txt"

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
mp_maxmoney 16000

// Logging
log on
sv_logbans 1
sv_logfile 1

// Bans
exec listip.cfg
exec banned.cfg
EOF

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

test_header "Validating configs & start script"
check_file_exists "$HLDS_DIR/steam_appid.txt" "steam_appid.txt"
check_file_contains "$HLDS_DIR/steam_appid.txt" "10" "steam_appid.txt = 10"
check_file_exists "$HLDS_DIR/cstrike/server.cfg" "server.cfg"
check_file_contains "$HLDS_DIR/cstrike/server.cfg" "hostname" "server.cfg → hostname"
check_file_contains "$HLDS_DIR/cstrike/server.cfg" "rcon_password" "server.cfg → rcon_password"
check_file_contains "$HLDS_DIR/cstrike/server.cfg" "mp_maxmoney 16000" "server.cfg → mp_maxmoney 16000"
check_file_contains "$HLDS_DIR/cstrike/server.cfg" "sv_lan 0" "server.cfg → sv_lan 0"
check_file_exists "$HLDS_DIR/start.sh" "start.sh"
check_executable_perm "$HLDS_DIR/start.sh" "start.sh"
check_file_contains "$HLDS_DIR/start.sh" "hlds_run" "start.sh → hlds_run"
check_file_contains "$HLDS_DIR/start.sh" "screen" "start.sh → screen"
check_file_contains "$HLDS_DIR/start.sh" "de_dust2" "start.sh → de_dust2"

# ─── Cleanup ─────────────────────────────────────────────────────────────────
info "Cleaning up temp files..."
rm -rf "$WORK_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL END-TO-END VALIDATION REPORT
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo -e "║  ${BOLD}FINAL END-TO-END VALIDATION REPORT${NC}                          ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo ""

FE=0  # final errors
FW=0  # final warnings

# --- Directory tree ---
echo -e "  ${BOLD}[1/7] Directory Structure${NC}"
for d in \
    "$HLDS_DIR" "$HLDS_DIR/cstrike" "$HLDS_DIR/cstrike/maps" "$HLDS_DIR/cstrike/models" \
    "$HLDS_DIR/cstrike/models/custom" "$HLDS_DIR/cstrike/addons/metamod" \
    "$HLDS_DIR/cstrike/addons/reunion" "$HLDS_DIR/cstrike/addons/amxmodx" \
    "$HLDS_DIR/cstrike/addons/amxmodx/dlls" "$HLDS_DIR/cstrike/addons/amxmodx/modules" \
    "$HLDS_DIR/cstrike/addons/amxmodx/plugins" "$HLDS_DIR/cstrike/addons/amxmodx/configs" \
    "$HLDS_DIR/cstrike/addons/amxmodx/scripting" "$HLDS_DIR/cstrike/addons/yapb"; do
    if [ -d "$d" ]; then echo -e "    ${GREEN}✔${NC} ${d#$HLDS_DIR/}"
    else echo -e "    ${RED}✘${NC} ${d#$HLDS_DIR/}"; FE=$((FE+1)); fi
done

# --- Critical .so binaries ---
echo -e "\n  ${BOLD}[2/7] Critical Binaries (ELF check)${NC}"
for entry in \
    "$HLDS_DIR/hlds_linux:HLDS engine" \
    "$HLDS_DIR/engine_i486.so:ReHLDS engine" \
    "$HLDS_DIR/cstrike/addons/metamod/metamod_i386.so:Metamod-R" \
    "$HLDS_DIR/cstrike/addons/reunion/reunion_mm_i386.so:ReUnion" \
    "$HLDS_DIR/cstrike/addons/amxmodx/dlls/amxmodx_mm_i386.so:AMX Mod X" \
    "$HLDS_DIR/cstrike/addons/amxmodx/modules/reapi_amxx_i386.so:ReAPI"; do
    IFS=':' read -r bp lbl <<< "$entry"
    if [ ! -f "$bp" ]; then
        echo -e "    ${RED}✘ MISSING${NC}   $lbl"; FE=$((FE+1)); continue
    fi
    ft=$(file -b "$bp" 2>/dev/null)
    if echo "$ft" | grep -q "ELF"; then
        echo -e "    ${GREEN}✔ OK${NC}       $lbl"
    else
        echo -e "    ${RED}✘ NOT ELF${NC}   $lbl  ($ft)"; FE=$((FE+1))
    fi
done
# YaPB
YF=$(find "$HLDS_DIR/cstrike/addons/yapb" -name "yapb.so" 2>/dev/null | head -1)
if [ -n "$YF" ] && file -b "$YF" 2>/dev/null | grep -q "ELF"; then
    echo -e "    ${GREEN}✔ OK${NC}       YaPB"
else
    echo -e "    ${RED}✘ MISSING${NC}   YaPB yapb.so"; FE=$((FE+1))
fi

# --- Config files ---
echo -e "\n  ${BOLD}[3/7] Configuration Files${NC}"
for entry in \
    "$HLDS_DIR/cstrike/server.cfg:server.cfg" \
    "$HLDS_DIR/cstrike/liblist.gam:liblist.gam" \
    "$HLDS_DIR/cstrike/reunion.cfg:reunion.cfg" \
    "$HLDS_DIR/steam_appid.txt:steam_appid.txt" \
    "$HLDS_DIR/cstrike/addons/metamod/plugins.ini:metamod/plugins.ini" \
    "$HLDS_DIR/cstrike/addons/amxmodx/configs/plugins.ini:amxmodx plugins.ini" \
    "$HLDS_DIR/cstrike/addons/amxmodx/configs/weapon_skins.ini:weapon_skins.ini"; do
    IFS=':' read -r fp lbl <<< "$entry"
    if [ -f "$fp" ] && [ -s "$fp" ]; then echo -e "    ${GREEN}✔ OK${NC}       $lbl"
    elif [ -f "$fp" ]; then echo -e "    ${YELLOW}⚠ EMPTY${NC}    $lbl"; FW=$((FW+1))
    else echo -e "    ${RED}✘ MISSING${NC}   $lbl"; FE=$((FE+1)); fi
done

# --- AMXX compiled plugin ---
echo -e "\n  ${BOLD}[4/7] Compiled AMXX Plugins${NC}"
if [ -f "$HLDS_DIR/cstrike/addons/amxmodx/plugins/weapon_skin_system.amxx" ]; then
    AMSZ=$(stat -c%s "$HLDS_DIR/cstrike/addons/amxmodx/plugins/weapon_skin_system.amxx" 2>/dev/null || echo 0)
    if [ "$AMSZ" -gt 1000 ]; then echo -e "    ${GREEN}✔ OK${NC}       weapon_skin_system.amxx (${AMSZ}B)"
    else echo -e "    ${RED}✘ TOO SMALL${NC} weapon_skin_system.amxx (${AMSZ}B)"; FE=$((FE+1)); fi
else
    echo -e "    ${RED}✘ MISSING${NC}   weapon_skin_system.amxx"; FE=$((FE+1))
fi

# --- Metamod cross-reference ---
echo -e "\n  ${BOLD}[5/7] Metamod plugins.ini Cross-Reference${NC}"
while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    sp=$(echo "$line" | awk '{print $2}')
    [ -z "$sp" ] && continue
    fp="$HLDS_DIR/cstrike/$sp"
    if [ -f "$fp" ]; then
        ft=$(file -b "$fp" 2>/dev/null)
        if echo "$ft" | grep -q "ELF"; then echo -e "    ${GREEN}✔${NC} $sp"
        else echo -e "    ${RED}✘${NC} $sp (NOT ELF: $ft)"; FE=$((FE+1)); fi
    else
        echo -e "    ${RED}✘${NC} $sp → FILE MISSING"; FE=$((FE+1))
    fi
done < "$HLDS_DIR/cstrike/addons/metamod/plugins.ini"

# --- Permissions ---
echo -e "\n  ${BOLD}[6/7] Execute Permissions${NC}"
for exe in "$HLDS_DIR/hlds_run" "$HLDS_DIR/hlds_linux" "$HLDS_DIR/start.sh" \
           "$HLDS_DIR/cstrike/addons/amxmodx/scripting/amxxpc"; do
    nm=$(basename "$exe")
    if [ -f "$exe" ] && [ -x "$exe" ]; then echo -e "    ${GREEN}✔${NC} $nm"
    elif [ -f "$exe" ]; then echo -e "    ${RED}✘${NC} $nm (no +x)"; FE=$((FE+1))
    else echo -e "    ${RED}✘${NC} $nm (missing)"; FE=$((FE+1)); fi
done

# --- Binary Identity (strings check) ---
echo -e "\n  ${BOLD}[7/7] Binary Identity (embedded strings)${NC}"
# Checks that installed .so files are the correct Re* replacements, not stock Valve originals
for id_entry in \
    "$HLDS_DIR/engine_i486.so:ReHLDS engine:sv_rehlds" \
    "$HLDS_DIR/engine_i486.so:ReHLDS engine:rehlds" \
    "$HLDS_DIR/cstrike/addons/metamod/metamod_i386.so:Metamod-R:Metamod-r"; do
    IFS=':' read -r id_path id_label id_str <<< "$id_entry"
    if [ ! -f "$id_path" ]; then
        echo -e "    ${RED}✘ MISSING${NC}   $id_label"; FE=$((FE+1)); continue
    fi
    if strings "$id_path" 2>/dev/null | grep -qi "$id_str"; then
        echo -e "    ${GREEN}✔ OK${NC}       $id_label  (has '$id_str')"
    else
        echo -e "    ${RED}✘ FAIL${NC}     $id_label  ('$id_str' NOT found — may be stock binary)"; FE=$((FE+1))
    fi
done
# ReGameDLL cs.so
RGDLL_FINAL=$(find "$HLDS_DIR" -maxdepth 1 \( -name "cs.so" -o -name "mp.so" \) 2>/dev/null | head -1)
[ -z "$RGDLL_FINAL" ] && RGDLL_FINAL=$(find "$HLDS_DIR/cstrike" \( -name "cs.so" -o -name "mp.so" \) 2>/dev/null | head -1)
if [ -n "$RGDLL_FINAL" ]; then
    if strings "$RGDLL_FINAL" 2>/dev/null | grep -qi "regamedll"; then
        echo -e "    ${GREEN}✔ OK${NC}       ReGameDLL $(basename "$RGDLL_FINAL")  (has 'regamedll')"
    else
        echo -e "    ${RED}✘ FAIL${NC}     $(basename "$RGDLL_FINAL")  ('regamedll' NOT found — may be stock)"; FE=$((FE+1))
    fi
else
    echo -e "    ${YELLOW}⚠ SKIP${NC}     ReGameDLL cs.so/mp.so not found"; FW=$((FW+1))
fi
# ReUnion
if [ -f "$HLDS_DIR/cstrike/addons/reunion/reunion_mm_i386.so" ]; then
    if strings "$HLDS_DIR/cstrike/addons/reunion/reunion_mm_i386.so" 2>/dev/null | grep -qi "reunion"; then
        echo -e "    ${GREEN}✔ OK${NC}       ReUnion  (has 'reunion')"
    else
        echo -e "    ${RED}✘ FAIL${NC}     ReUnion  ('reunion' NOT found)"; FE=$((FE+1))
    fi
fi
# AMX Mod X
if [ -f "$HLDS_DIR/cstrike/addons/amxmodx/dlls/amxmodx_mm_i386.so" ]; then
    if strings "$HLDS_DIR/cstrike/addons/amxmodx/dlls/amxmodx_mm_i386.so" 2>/dev/null | grep -qi "AMX Mod X"; then
        echo -e "    ${GREEN}✔ OK${NC}       AMX Mod X  (has 'AMX Mod X')"
    else
        echo -e "    ${RED}✘ FAIL${NC}     AMX Mod X  ('AMX Mod X' NOT found)"; FE=$((FE+1))
    fi
fi
# ReAPI
if [ -f "$HLDS_DIR/cstrike/addons/amxmodx/modules/reapi_amxx_i386.so" ]; then
    if strings "$HLDS_DIR/cstrike/addons/amxmodx/modules/reapi_amxx_i386.so" 2>/dev/null | grep -qi "reapi"; then
        echo -e "    ${GREEN}✔ OK${NC}       ReAPI  (has 'reapi')"
    else
        echo -e "    ${RED}✘ FAIL${NC}     ReAPI  ('reapi' NOT found)"; FE=$((FE+1))
    fi
fi
# YaPB
YF_FINAL=$(find "$HLDS_DIR/cstrike/addons/yapb" -name "yapb.so" 2>/dev/null | head -1)
if [ -n "$YF_FINAL" ]; then
    if strings "$YF_FINAL" 2>/dev/null | grep -qi "yapb"; then
        echo -e "    ${GREEN}✔ OK${NC}       YaPB  (has 'yapb')"
    else
        echo -e "    ${RED}✘ FAIL${NC}     YaPB  ('yapb' NOT found)"; FE=$((FE+1))
    fi
fi
# Version summary
echo -e "\n  ${BOLD}    Detected Versions:${NC}"
for ver_entry in \
    "$HLDS_DIR/engine_i486.so:ReHLDS:ReHLDS version: [0-9.]*" \
    "$HLDS_DIR/cstrike/addons/metamod/metamod_i386.so:Metamod-R:v[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" \
    "$HLDS_DIR/cstrike/addons/reunion/reunion_mm_i386.so:ReUnion:[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+"; do
    IFS=':' read -r vp vl vpat <<< "$ver_entry"
    [ -f "$vp" ] || continue
    ver=$(strings "$vp" 2>/dev/null | grep -oE "$vpat" | head -1)
    [ -n "$ver" ] && echo -e "      $vl: $ver" || echo -e "      $vl: (version not detected)"
done
RGDLL_V=""
[ -n "$RGDLL_FINAL" ] && RGDLL_V=$(strings "$RGDLL_FINAL" 2>/dev/null | grep -oE "ReGameDLL version: [0-9.]*|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -1)
[ -n "$RGDLL_V" ] && echo -e "      ReGameDLL: $RGDLL_V" || echo -e "      ReGameDLL: (version not detected)"

# --- Summary ---
TOTAL_E=$((VALIDATION_ERRORS + FE))
TOTAL_W=$((VALIDATION_WARNINGS + FW))

echo ""
echo "╠══════════════════════════════════════════════════════════════╣"
if [ "$TOTAL_E" -eq 0 ]; then
    echo -e "║  ${GREEN}${BOLD}✔ ALL CHECKS PASSED${NC}                                        ║"
else
    echo -e "║  ${RED}${BOLD}✘ ISSUES DETECTED${NC}                                            ║"
fi
printf "║  Errors: %-4d  Warnings: %-4d                               ║\n" "$TOTAL_E" "$TOTAL_W"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ─── Server Info ─────────────────────────────────────────────────────────────
echo "=============================================="
echo -e "${GREEN}  CS 1.6 ReHLDS Server Setup Complete!${NC}"
echo "=============================================="
echo ""
echo "  Components:"
echo "    ReHLDS 3.14.0.857 | ReGameDLL 5.28.0.756"
echo "    Metamod-R 1.3.0.149 | ReUnion 0.2.0.25"
echo "    AMX Mod X 1.10.0.5467 | ReAPI 5.26.0.338"
echo "    YaPB 4.4.957 | WeaponSkinSystem (Mistrick)"
echo ""
echo "  Server:  $HLDS_DIR"
echo "  IP:      $(hostname -I | awk '{print $1}'):$SERVER_PORT"
echo "  RCON:    $RCON_PASSWORD"
echo ""
echo "  Start:   $HLDS_DIR/start.sh"
echo "  Attach:  screen -r cs16"
echo "  Detach:  Ctrl+A, D"
echo "  Stop:    screen -S cs16 -X quit"
echo ""
echo "  Firewall: sudo ufw allow 27015/udp"
echo "            sudo ufw allow 27015/tcp"
echo ""
echo "  Verify:  'meta list' in server console"
echo ""
echo "  Skins:   Edit $HLDS_DIR/cstrike/addons/amxmodx/configs/weapon_skins.ini"
echo "           Place models in $HLDS_DIR/cstrike/models/custom/"
echo "           In-game: /skins"
echo "=============================================="

[ "$TOTAL_E" -gt 0 ] && { warn "Completed with $TOTAL_E error(s). Review output above."; exit 1; }
exit 0
