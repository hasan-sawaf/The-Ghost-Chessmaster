# Computer Vision Detection and Overlay Logic
import cv2
import numpy as np
from src.software.infrastructure.vision.config import sq_points
from src.software.infrastructure.vision.chess_engine import remap_square

def poly_center(pts):
    """Calculates the geometric center of a polygon (square)."""
    a = np.array(pts, np.int32)
    M = cv2.moments(a)
    if M["m00"] == 0:
        return int(a[:, 0].mean()), int(a[:, 1].mean())
    return int(M["m10"] / M["m00"]), int(M["m01"] / M["m00"])

def find_square(x, y):
    """Checks which calibrated square contains the point (x, y)."""
    pt = (float(x), float(y))
    for sq, pts in sq_points.items():
        poly = np.array(pts, np.int32)
        if cv2.pointPolygonTest(poly, pt, False) >= 0:
            return sq
    return None

def overlay_poly(frame, poly_pts, color, alpha=0.45):
    """Draws a semi-transparent colored polygon overlay on the frame."""
    overlay = frame.copy()
    pts = np.array(poly_pts, np.int32)
    cv2.fillPoly(overlay, [pts], color)
    return cv2.addWeighted(overlay, alpha, frame, 1 - alpha, 0)

def draw_board_labels(base_frame):
    """Draws the outlines of all squares and overlays the coordinate label on 'a1'."""
    overlay = base_frame.copy()
    font = cv2.FONT_HERSHEY_SIMPLEX
    for sq, pts in sq_points.items():
        p = np.array(pts, np.int32)
        cv2.polylines(overlay, [p], True, (255, 255, 255), 1)
        if sq == "a1":
            cx, cy = poly_center(pts)
            mapped = remap_square(sq)
            cv2.putText(overlay, mapped, (cx - 12, cy + 5), font, 0.45, (0, 255, 255), 1, cv2.LINE_AA)
    return overlay

def candidates_for_contour(c):
    """
    Finds potential board squares associated with a contour.
    Jitters the center point to compensate for camera perspective and shadows.
    """
    x, y, w, h = cv2.boundingRect(c)
    M = cv2.moments(c)
    if M["m00"] != 0:
        cx_m = int(M["m10"] / M["m00"])
        cy_m = int(M["m01"] / M["m00"])
    else:
        cx_m = x + w//2
        cy_m = y + h//2

    y_factors = [0.20, 0.30, 0.40]
    x_jitters = [0, -6, 6]
    cands = []
    for yf in y_factors:
        cy_try = int(y + yf * h)
        for xj in x_jitters:
            cx_try = cx_m + xj
            sq_try = find_square(cx_try, cy_try)
            if sq_try:
                cands.append((sq_try, cx_try, cy_try))
    seen = set()
    out = []
    for s in cands:
        if s[0] not in seen:
            seen.add(s[0])
            out.append(s)
    return out
