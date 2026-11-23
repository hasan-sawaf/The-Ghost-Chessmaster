# Camera-to-Board 2D Grid Calibration Utility
import cv2
import numpy as np

def compute_grid_calibration(points):
    """
    Computes the 8x8 grid polygons for all 64 squares given 4 corner points.
    Returns a dictionary: {"a1": [[x1,y1], [x2,y2], [x3,y3], [x4,y4]], ...}
    """
    if len(points) != 4:
        raise ValueError("Exactly 4 points are required for calibration.")

    src = np.array([[0,0],[8,0],[8,8],[0,8]], dtype=np.float32)
    dst = np.array(points, dtype=np.float32)
    H = cv2.getPerspectiveTransform(src, dst)

    print()
    src_grid = np.array([[[x,y] for x in range(9)] for y in range(9)], dtype=np.float32)
    dst_grid = cv2.perspectiveTransform(src_grid.reshape(-1,1,2), H).reshape(9,9,2)

    files = 'abcdefgh'
    ranks = '87654321'
    squares_std = {}

    for r in range(8):
        for c in range(8):
            tl = dst_grid[r, c].tolist()
            tr = dst_grid[r, c+1].tolist()
            br = dst_grid[r+1, c+1].tolist()
            bl = dst_grid[r+1, c].tolist()
            file_letter = files[c]
            rank_char = ranks[r]
            squares_std[f"{file_letter}{rank_char}"] = [tl, tr, br, bl]
    return squares_std
