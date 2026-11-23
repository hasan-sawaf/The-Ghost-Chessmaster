import os
import sys
import shutil

if getattr(sys, 'frozen', False):
    WRITE_ROOT = os.path.dirname(sys.executable)
    ASSET_ROOT = getattr(sys, '_MEIPASS', os.path.dirname(sys.executable))
else:
    WRITE_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    ASSET_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

# Config and writable directories
CONFIG_DIR = os.path.join(WRITE_ROOT, "src", "software", "infrastructure", "persistence", "config")
ASSET_CONFIG_DIR = os.path.join(ASSET_ROOT, "src", "software", "infrastructure", "persistence", "config")

SAVED_GAMES_DIR = os.path.join(CONFIG_DIR, "saved_games")
LOG_DIR = os.path.join(WRITE_ROOT, "logs")

# Guarantee directories exist
os.makedirs(CONFIG_DIR, exist_ok=True)
os.makedirs(SAVED_GAMES_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)

CALIB_JSON = os.path.join(CONFIG_DIR, "board_calibration.json")
SETTINGS_JSON = os.path.join(CONFIG_DIR, "game_settings.json")

# Ensure initial config template files are copied from ASSET_ROOT if not yet present in WRITE_ROOT
for filename in ["board_calibration.json", "game_settings.json", "board_config.json", "serviceAccountKey.json"]:
    dest = os.path.join(CONFIG_DIR, filename)
    src = os.path.join(ASSET_CONFIG_DIR, filename)
    if not os.path.exists(dest) and os.path.exists(src):
        try:
            shutil.copy2(src, dest)
        except Exception:
            pass

ENGINE_PATH = os.path.join(ASSET_ROOT, "src", "software", "infrastructure", "ai", "stockfish-windows-x86-64-avx2.exe")

