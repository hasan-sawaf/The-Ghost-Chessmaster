# Vision and AI Configuration Settings for ChessTracker
import os
import json

import sys
if getattr(sys, 'frozen', False):
    WRITE_ROOT = os.path.dirname(sys.executable)
    ASSET_ROOT = getattr(sys, '_MEIPASS', os.path.dirname(sys.executable))
else:
    from src.software.core.config import WRITE_ROOT
    from src.software.core.config import ASSET_ROOT

from src.software.core.config import CALIB_JSON
from src.software.core.config import ENGINE_PATH
MOVE_THRESHOLD = 25
MIN_CONTOUR_AREA = 250
CAM_INDEX = 1
BOARD_ORIENTATION = "TOP"

DEBUG_MODE = True

SQUARE_SIZE = 35.5
HALF_SQ = SQUARE_SIZE / 2

# Load calibration points
if os.path.exists(CALIB_JSON):
    with open(CALIB_JSON, "r") as f:
        sq_points = json.load(f)
else:
    sq_points = {}
