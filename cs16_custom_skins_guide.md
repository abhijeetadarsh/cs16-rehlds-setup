# Complete Guide: Custom Weapon Skins for CS 1.6 Server
### For ReHLDS + ReGameDLL + Metamod-R + AMX Mod X + ReAPI Setup

---

## Prerequisites

Make sure your server has these installed and running:

- ReHLDS
- ReGameDLL
- Metamod-R
- AMX Mod X
- ReAPI module for AMXX

Verify with `meta list` in server console — you should see Metamod, AMXX, and ReAPI all running.

---

## Step 1: Download Custom Weapon Models

### Where to Find Models

- **GameBanana** — https://gamebanana.com/mods/games/1 (largest collection)
- **CS16.net** — search for weapon skins
- Search Google for: `CS 1.6 custom weapon model <weapon_name>`

### What to Download

Each weapon skin can have up to 3 model files:

| File | What It Does | Example |
|------|-------------|---------|
| `v_<weapon>.mdl` | **Viewmodel** — what YOU see in first person | `v_ak47.mdl` |
| `p_<weapon>.mdl` | **Playermodel** — what OTHER players see you holding | `p_ak47.mdl` |
| `w_<weapon>.mdl` | **Worldmodel** — weapon on the ground | `w_ak47.mdl` |

Not all skins include all 3 files. At minimum you need the `v_` (viewmodel) file.

---

## Step 2: Organize Model Files on Server

### Create a Custom Models Directory

```bash
mkdir -p ~/hlds/cstrike/models/custom
```

### Naming Convention

Since you may have multiple skins for the same weapon, organize by skin name:

```bash
mkdir -p ~/hlds/cstrike/models/custom/ak47_gold
mkdir -p ~/hlds/cstrike/models/custom/ak47_dragon
mkdir -p ~/hlds/cstrike/models/custom/m4a1_neon
```

### Upload Files

Upload the `.mdl` files into their respective folders. Your structure should look like:

```
cstrike/models/custom/
├── ak47_gold/
│   ├── v_ak47.mdl
│   ├── p_ak47.mdl
│   └── w_ak47.mdl
├── ak47_dragon/
│   └── v_ak47.mdl
├── m4a1_neon/
│   ├── v_m4a1.mdl
│   ├── p_m4a1.mdl
│   └── w_m4a1.mdl
└── glock_custom/
    └── v_glock18.mdl
```

### Set Permissions

```bash
chmod -R 755 ~/hlds/cstrike/models/custom/
```

---

## Step 3: Install the Weapon Skin System Plugin

### Download the Plugin Source

```bash
cd ~/hlds/cstrike/addons/amxmodx/scripting
wget https://raw.githubusercontent.com/Mistrick/WeaponSkinSystem/master/weapon_skin_system.sma
```

### Create the Include File

The plugin needs an include file for other plugins to interact with it:

```bash
cat > ~/hlds/cstrike/addons/amxmodx/scripting/include/weapon_skin_system.inc << 'INCEOF'
#if defined _weapon_skin_system_included
    #endinput
#endif
#define _weapon_skin_system_included

native wss_register_weapon(weaponid, const skinname[], const model_v[], const model_p[], const model_w[]);
native wss_get_weapon_skin_index(weapon);
native wss_set_weapon_skin_index(weapon, skin);
native wss_get_skin_name(skin, name[], len);
native wss_set_user_skin(id, weaponid, skin_index);

forward wss_loaded_skin(index, weaponid, const name[]);
forward wss_weapon_deploy(id, weapon, weaponid, skin);
forward wss_weapon_holster(id, weapon, weaponid, skin);
forward wss_weapon_can_pickup(id, weaponbox, weapon, weaponid, skin);
forward wss_weapon_drop(id, weaponbox, weapon, weaponid, skin);
INCEOF
```

### Compile the Plugin

```bash
cd ~/hlds/cstrike/addons/amxmodx/scripting
./amxxpc weapon_skin_system.sma -o../plugins/weapon_skin_system.amxx
```

You should see "Done" with no errors.

### Enable the Plugin

```bash
echo 'weapon_skin_system.amxx' >> ~/hlds/cstrike/addons/amxmodx/configs/plugins.ini
```

---

## Step 4: Configure Skins

### Create the Skin Config File

```bash
nano ~/hlds/cstrike/addons/amxmodx/configs/weapon_skins.ini
```

### Config Format

```
weapon_name "Display Name" "v_model_path" "p_model_path" "w_model_path"
```

- Use `""` (empty quotes) if a model file is not available for that type.
- Lines starting with `;` are comments.

### Example Config

```
; AK-47 Skins
weapon_ak47 "Gold AK47" "models/custom/ak47_gold/v_ak47.mdl" "models/custom/ak47_gold/p_ak47.mdl" "models/custom/ak47_gold/w_ak47.mdl"
weapon_ak47 "Dragon AK47" "models/custom/ak47_dragon/v_ak47.mdl" "" ""

; M4A1 Skins
weapon_m4a1 "Neon M4A1" "models/custom/m4a1_neon/v_m4a1.mdl" "models/custom/m4a1_neon/p_m4a1.mdl" "models/custom/m4a1_neon/w_m4a1.mdl"

; Glock Skins
weapon_glock18 "Custom Glock" "models/custom/glock_custom/v_glock18.mdl" "" ""
```

### Supported Weapon Names

```
weapon_ak47       weapon_m4a1       weapon_awp        weapon_deagle
weapon_usp        weapon_glock18    weapon_famas      weapon_galil
weapon_aug        weapon_sg552      weapon_scout      weapon_g3sg1
weapon_sg550      weapon_mp5navy    weapon_ump45      weapon_p90
weapon_mac10      weapon_tmp        weapon_m249       weapon_m3
weapon_xm1014     weapon_p228       weapon_elite      weapon_fiveseven
weapon_knife      weapon_hegrenade  weapon_flashbang  weapon_smokegrenade
```

### Important Notes

- Each skin gets a number based on its position in the file (starting from 1).
- You can have multiple skins for the same weapon.
- The order matters — it determines the skin index number.

---

## Step 5: Set Default Skins for All Players

### Create the Default Skins Plugin

```bash
cat > ~/hlds/cstrike/addons/amxmodx/scripting/default_skins.sma << 'EOF'
#include <amxmodx>
#include <weapon_skin_system>

public plugin_init()
{
    register_plugin("Default Skins", "1.0", "Server");
}

public client_putinserver(id)
{
    wss_set_user_skin(id, CSW_AK47, 1);
    wss_set_user_skin(id, CSW_M4A1, 3);
    wss_set_user_skin(id, CSW_GLOCK18, 4);
}
EOF
```

### Skin Index Reference

The number in `wss_set_user_skin` corresponds to the line position in `weapon_skins.ini`:

```
weapon_ak47 "Gold AK47" ...        <- Index 1
weapon_ak47 "Dragon AK47" ...      <- Index 2
weapon_m4a1 "Neon M4A1" ...        <- Index 3
weapon_glock18 "Custom Glock" ...  <- Index 4
```

### CSW Constants for Weapons

```
CSW_AK47        CSW_M4A1        CSW_AWP         CSW_DEAGLE
CSW_USP         CSW_GLOCK18     CSW_FAMAS       CSW_GALIL
CSW_AUG         CSW_SG552       CSW_SCOUT       CSW_G3SG1
CSW_SG550       CSW_MP5NAVY     CSW_UMP45       CSW_P90
CSW_MAC10       CSW_TMP         CSW_M249        CSW_M3
CSW_XM1014      CSW_P228        CSW_ELITE       CSW_FIVESEVEN
CSW_KNIFE       CSW_HEGRENADE   CSW_FLASHBANG   CSW_SMOKEGRENADE
```

### Compile and Enable

```bash
cd ~/hlds/cstrike/addons/amxmodx/scripting
./amxxpc default_skins.sma -o../plugins/default_skins.amxx
echo 'default_skins.amxx' >> ~/hlds/cstrike/addons/amxmodx/configs/plugins.ini
```

---

## Step 6: Restart and Test

### Restart the Server

Stop the running server (Ctrl+C) and start it again:

```bash
cd ~/hlds
./hlds_run -game cstrike +sv_lan 0 +maxplayers 32 +map de_dust2 +port 27015
```

### Verify Plugins Are Loaded

In game console:

```
amx_rcon amxx plugins
```

Look for both "Weapon Skin System" and "Default Skins" as running.

### Test In-Game

- Buy an AK-47 — you should see the default skin automatically applied.
- Type `say /skins` in console to open the skin selection menu.
- Type `say /skinreset` to reset a weapon back to default.

---

## Step 7: Client-Side Setup (Important!)

### The Problem

CS 1.6 clients need the model files too. Without them, players see errors or invisible weapons.

### Option A: Manual Install (Simple)

Each player copies the `models/custom/` folder into their CS 1.6 `cstrike` directory:

```
C:\Program Files\Steam\steamapps\common\Half-Life\cstrike\models\custom\
```

### Option B: FastDL (Recommended for Public Servers)

Set up a web server to auto-download custom files to players:

1. Host your custom files on a web server (e.g., nginx or a file host).

2. Add to `server.cfg`:
```
sv_downloadurl "http://your-server-ip:port/cstrike"
sv_allowdownload 1
```

3. Mirror the file structure on the web server:
```
http://your-server-ip/cstrike/models/custom/ak47_gold/v_ak47.mdl
```

Players will automatically download the files when they join.

---

## Quick Reference: Adding a New Skin

Every time you want to add a new skin, follow these steps:

1. Upload `.mdl` files to `~/hlds/cstrike/models/custom/<skin_name>/`
2. Set permissions: `chmod -R 755 ~/hlds/cstrike/models/custom/<skin_name>/`
3. Add a line to `~/hlds/cstrike/addons/amxmodx/configs/weapon_skins.ini`
4. If you want it as default, update `default_skins.sma` and recompile
5. Restart the server
6. Make sure clients have the files too (manual copy or FastDL)

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `/skins` does nothing | Check `amx_rcon amxx plugins` — is Weapon Skin System running? |
| Plugin won't compile | Make sure `weapon_skin_system.inc` exists in the `include/` folder |
| "symbol already defined" error | Old file content — recreate the `.sma` file cleanly using `cat >` |
| Server crashes on start | Check `weapon_skins.ini` — model paths must be correct and files must exist |
| Invisible weapons | Client doesn't have the model files — copy them or set up FastDL |
| Skin not applying | Check skin index number matches the line position in `weapon_skins.ini` |
| Default skins not working | Make sure `default_skins.amxx` is listed AFTER `weapon_skin_system.amxx` in `plugins.ini` |
