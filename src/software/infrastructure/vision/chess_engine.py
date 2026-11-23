# Chess Engine Helper Functions and Board Rendering
import os
import sys
import chess
import chess.engine
import cv2
import numpy as np
import base64
from PIL import Image, ImageDraw, ImageFont
from src.software.core.config import ASSET_ROOT
from src.software.infrastructure.vision.config import BOARD_ORIENTATION

files = 'abcdefgh'
ranks = '12345678'

_PIECE_CACHE = {}

def remap_square(square_name: str) -> str:
    """Remaps square coordinates depending on the board orientation style."""
    f = square_name[0]
    r = square_name[1]
    fi = files.index(f)
    ri = ranks.index(r)
    if BOARD_ORIENTATION == "TOP":
        return square_name
    elif BOARD_ORIENTATION == "BOTTOM":
        return f"{files[7 - fi]}{ranks[7 - ri]}"
    elif BOARD_ORIENTATION == "SIDE_L":
        return f"{files[ri]}{ranks[7 - fi]}"
    elif BOARD_ORIENTATION == "SIDE_R":
        return f"{files[7 - ri]}{ranks[fi]}"
    else:
        return square_name

def piece_name_from_type(piece_type: int) -> str:
    """Translates chess piece types to string representations."""
    names = {
        chess.PAWN: "pawn",
        chess.KNIGHT: "knight",
        chess.BISHOP: "bishop",
        chess.ROOK: "rook",
        chess.QUEEN: "queen",
        chess.KING: "king",
    }
    return names.get(piece_type, "unknown")

def send_frame_to_gui(window_name: str, frame: np.ndarray):
    """Encodes a video frame as JPEG and prints it to stdout for the GUI to capture."""
    try:
        _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        b64_str = base64.b64encode(buffer).decode('utf-8')
        print(f"__{window_name}__:{b64_str}", flush=True)
    except Exception:
        pass

def get_piece_image(piece_symbol: str, target_size: int):
    """Loads and caches piece PNG image scaled to target_size."""
    key = (piece_symbol, target_size)
    if key in _PIECE_CACHE:
        return _PIECE_CACHE[key]

    color_dir = "white_pieces" if piece_symbol.isupper() else "black_pieces"
    color_prefix = "W" if piece_symbol.isupper() else "B"
    piece_type = piece_symbol.upper()
    filename = f"{color_prefix}{piece_type}.png"

    possible_paths = [
        os.path.join(ASSET_ROOT, "src", "ghostchessmaster", "assets", "Pieces", "Standered", color_dir, filename),
        os.path.join(ASSET_ROOT, "src", "software", "presentation", "assets", filename),
    ]

    piece_img = None
    for p in possible_paths:
        if os.path.exists(p):
            try:
                piece_img = Image.open(p).convert("RGBA")
                piece_img = piece_img.resize((target_size, target_size), Image.Resampling.LANCZOS)
                break
            except Exception:
                pass

    _PIECE_CACHE[key] = piece_img
    return piece_img

def render_board_pil(board: chess.Board, last_move: chess.Move = None, size: int = 480) -> np.ndarray:
    """Renders the chess board state using PIL and converts to OpenCV BGR frame."""
    margin = 24
    grid_size = size - (2 * margin)
    sq_size = grid_size // 8

    board_img = Image.new("RGBA", (size, size), (55, 71, 79, 255))
    draw = ImageDraw.Draw(board_img)

    LIGHT_SQ = (240, 217, 181, 255)
    DARK_SQ = (181, 136, 99, 255)
    HIGHLIGHT_LIGHT = (205, 210, 106, 255)
    HIGHLIGHT_DARK = (170, 162, 58, 255)

    highlight_sqs = set()
    if last_move:
        highlight_sqs.add(last_move.from_square)
        highlight_sqs.add(last_move.to_square)

    try:
        font = ImageFont.truetype("arial.ttf", 12)
    except Exception:
        font = ImageFont.load_default()

    for r in range(8):
        for f in range(8):
            sq = chess.square(f, 7 - r)
            x1 = margin + f * sq_size
            y1 = margin + r * sq_size
            x2 = x1 + sq_size
            y2 = y1 + sq_size

            is_light = (r + f) % 2 == 0
            fill_color = (HIGHLIGHT_LIGHT if is_light else HIGHLIGHT_DARK) if sq in highlight_sqs else (LIGHT_SQ if is_light else DARK_SQ)

            draw.rectangle([x1, y1, x2, y2], fill=fill_color)

            piece = board.piece_at(sq)
            if piece:
                p_img = get_piece_image(piece.symbol(), sq_size)
                if p_img:
                    board_img.paste(p_img, (x1, y1), p_img)

    for f in range(8):
        file_char = files[f].upper()
        x = margin + f * sq_size + sq_size // 2 - 4
        draw.text((x, 6), file_char, fill=(255, 255, 255, 255), font=font)
        draw.text((x, size - margin + 4), file_char, fill=(255, 255, 255, 255), font=font)

    for r in range(8):
        rank_char = ranks[7 - r]
        y = margin + r * sq_size + sq_size // 2 - 6
        draw.text((8, y), rank_char, fill=(255, 255, 255, 255), font=font)
        draw.text((size - margin + 8, y), rank_char, fill=(255, 255, 255, 255), font=font)

    rgb_img = board_img.convert("RGB")
    return cv2.cvtColor(np.array(rgb_img), cv2.COLOR_RGB2BGR)

def show_board(board: chess.Board, last_move: chess.Move = None):
    """Draws the current chess board using pure PIL/OpenCV and feeds it to the GUI."""
    try:
        img_cv = render_board_pil(board, last_move=last_move, size=480)
        send_frame_to_gui("BOARD", img_cv)
    except Exception as e:
        print(f"[WARNING] Failed to render board: {e}")
        img_cv = np.zeros((480, 480, 3), dtype=np.uint8)
        cv2.putText(img_cv, "Board Display Error", (80, 240),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
        send_frame_to_gui("BOARD", img_cv)
