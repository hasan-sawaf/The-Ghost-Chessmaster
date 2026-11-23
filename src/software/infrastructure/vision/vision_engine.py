# Master Vision & AI Engine Loop for ChessTracker
import os
import sys
import io

os.environ["OPENCV_LOG_LEVEL"] = "FATAL"
os.environ["PYTHONIOENCODING"] = "utf-8"

class SafeStreamWriter:
    def __init__(self, original_stream):
        self.original_stream = original_stream

    def write(self, s):
        if not s:
            return
        try:
            self.original_stream.write(s)
        except Exception:
            try:
                safe_s = s.encode('ascii', errors='replace').decode('ascii')
                self.original_stream.write(safe_s)
            except Exception:
                pass

    def flush(self):
        try:
            self.original_stream.flush()
        except Exception:
            pass

    def isatty(self):
        return False

if sys.stdout is not None and not isinstance(sys.stdout, SafeStreamWriter):
    sys.stdout = SafeStreamWriter(sys.stdout)
if sys.stderr is not None and not isinstance(sys.stderr, SafeStreamWriter):
    sys.stderr = SafeStreamWriter(sys.stderr)

# Force stdout & stderr encoding to UTF-8 with error replacement to prevent charmap UnicodeEncodeError on Windows
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass
if hasattr(sys.stderr, 'reconfigure'):
    try:
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

import cv2
import json
import numpy as np
import chess
import chess.engine
import time
import threading
import queue
import random

from src.software.infrastructure.vision.config import (
    sq_points, ENGINE_PATH, CALIB_JSON, CAM_INDEX,
    MOVE_THRESHOLD, MIN_CONTOUR_AREA, DEBUG_MODE
)
from src.software.infrastructure.vision.chess_engine import (
    piece_name_from_type, remap_square, send_frame_to_gui, show_board
)
from src.software.infrastructure.vision.detector import (
    overlay_poly, draw_board_labels, candidates_for_contour, find_square
)

def get_search_limits_for_elo(elo):
    """Returns appropriate (depth_limit, thinking_time) for target ELO."""
    if elo <= 800:
        return 1, random.uniform(0.3, 0.6)
    elif elo <= 900:
        return 2, random.uniform(0.4, 0.7)
    elif elo <= 1000:
        return 2, random.uniform(0.4, 0.8)
    elif elo <= 1100:
        return 3, random.uniform(0.5, 0.9)
    elif elo <= 1200:
        return 4, random.uniform(0.6, 1.0)
    elif elo <= 1300:
        return 5, random.uniform(0.7, 1.2)
    elif elo <= 1400:
        return 6, random.uniform(0.8, 1.3)
    elif elo <= 1500:
        return 7, random.uniform(0.8, 1.5)
    elif elo <= 1600:
        return 8, random.uniform(1.0, 1.6)
    elif elo <= 1700:
        return 9, random.uniform(1.0, 1.8)
    elif elo <= 1800:
        return 10, random.uniform(1.2, 1.9)
    elif elo <= 1900:
        return 12, random.uniform(1.2, 2.0)
    elif elo <= 2000:
        return 13, random.uniform(1.4, 2.2)
    elif elo <= 2200:
        return 15, random.uniform(1.5, 2.5)
    elif elo <= 2400:
        return 17, random.uniform(1.8, 2.8)
    elif elo <= 2600:
        return 19, random.uniform(2.0, 3.0)
    else:
        return None, random.uniform(2.0, 3.5)

def configure_engine_elo(engine, elo):
    """Configures Stockfish engine strength based on target ELO."""
    try:
        # Calculate Skill Level (0-20) based on ELO (800-2800) in steps of 100
        level = (elo - 800) // 100
        level = max(0, min(20, level))
        
        if level >= 20 or elo >= 2800:
            # Engine Max (2800+ ELO) -> Full strength
            engine.configure({"UCI_LimitStrength": False, "Skill Level": 20})
            print(f"[INFO] Engine configured to MAX strength (Skill Level: 20, ELO Limit: Off)", flush=True)
        elif elo >= 1320:
            # Supported standard range by Stockfish's UCI_Elo option (1320 - 2700)
            engine.configure({"UCI_LimitStrength": True, "UCI_Elo": elo, "Skill Level": level})
            print(f"[INFO] Engine ELO limited to: {elo} (Skill Level: {level})", flush=True)
        else:
            # Below min UCI_Elo (1320). Stockfish UCI_LimitStrength must be False to allow Skill Level (0 to 5) to control error rate
            engine.configure({"UCI_LimitStrength": False, "Skill Level": level})
            print(f"[INFO] Engine ELO calibrated: {elo} (Skill Level: {level}, UCI_LimitStrength: False)", flush=True)
    except Exception as e:
        print(f"[ERROR] Failed to configure engine ELO: {e}", flush=True)

def main():
    global DEBUG_MODE
    
    # === ENGINE ===
    if not os.path.exists(ENGINE_PATH):
        print(f"[ERROR] File engine tidak ditemukan: {ENGINE_PATH}")
        sys.exit(1)

    engine = chess.engine.SimpleEngine.popen_uci(ENGINE_PATH)
    print(f"[INFO] Stockfish dijalankan dari {ENGINE_PATH}")

    # === LOAD JSON ===
    if not os.path.exists(CALIB_JSON):
        print(f"[ERROR] File kalibrasi tidak ditemukan: {CALIB_JSON}")
        engine.quit()
        sys.exit(1)

    print(f"[INFO] Memuat {len(sq_points)} kotak dari {CALIB_JSON}")

    # === IPC (Inter-Process Communication) LISTENER ===
    input_queue = queue.Queue()

    def stdin_listener():
        for line in sys.stdin:
            cmd = line.strip()
            if cmd:
                input_queue.put(cmd)

    threading.Thread(target=stdin_listener, daemon=True).start()

    # === CAMERA ===
    cap = cv2.VideoCapture(CAM_INDEX, cv2.CAP_DSHOW)
    if not cap.isOpened():
        print("[ERROR] Kamera tidak bisa dibuka.")
        engine.quit()
        sys.exit(1)

    current_engine_elo = 1500
    configure_engine_elo(engine, current_engine_elo)

    board = chess.Board()
    ref_frame = None
    last_move = None
    comp_turn = False
    player_color = "white"  # Default: human plays White, AI plays Black
    move_history = []
    movement_counter = 0

    files = 'abcdefgh'

    print("[INFO] Engine Initialized.")
    show_board(board)

    try:
        while not board.is_game_over():
            ret, frame_raw = cap.read()
            if not ret:
                continue

            display = draw_board_labels(frame_raw.copy())
            send_frame_to_gui("TRACKER", display)

            time.sleep(0.01)

            gui_cmd = None
            # Drain ALL pending commands from the queue.
            # Process configuration commands immediately; keep the last
            # gameplay command (r, capture_base, etc.) as gui_cmd for the
            # rest of this iteration's logic.
            while not input_queue.empty():
                try:
                    _cmd = input_queue.get_nowait()
                except queue.Empty:
                    break
                # Configuration commands are processed inline immediately
                if _cmd.startswith('set_elo '):
                    try:
                        current_engine_elo = int(_cmd.split()[1])
                        configure_engine_elo(engine, current_engine_elo)
                    except Exception as e:
                        print(f"[ERROR] IPC ELO parsing error: {e}", flush=True)
                    continue
                if _cmd.startswith('set_player_color '):
                    try:
                        color_val = _cmd.split()[1].strip().lower()
                        if color_val in ("white", "black"):
                            player_color = color_val
                            print(f"[INFO] Player color set to: {player_color}")
                    except Exception:
                        pass
                    continue
                # capture_base always takes highest priority over any other
                # gameplay command to ensure the reference frame is updated.
                if _cmd == 'capture_base' or _cmd.startswith('save_base'):
                    gui_cmd = _cmd
                elif gui_cmd is None or gui_cmd not in ('capture_base',):
                    gui_cmd = _cmd



            if gui_cmd in ('reset_board', 'reset_game'):
                board = chess.Board()
                move_history.clear()
                last_move = None
                comp_turn = False
                movement_counter = 0
                ref_frame = None
                print(json.dumps({"event": "board_reset"}), flush=True)

            if gui_cmd == 'ai_move_first':
                # AI plays as White and needs to make the first move
                comp_turn = True
                print(f"[INFO] AI making first move as White.")

            # === Toggle debug mode ===
            if gui_cmd == 'd':
                DEBUG_MODE = not DEBUG_MODE
                if not DEBUG_MODE:
                    black_frame = np.zeros((450, 450, 3), dtype=np.uint8)
                    cv2.putText(black_frame, "DEBUG OFF", (130, 225), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                    send_frame_to_gui("DEBUG_MASK", black_frame)
                    send_frame_to_gui("DEBUG_MAP", black_frame)

            # === AUTOMATED SYNC COMMAND: CAPTURE BASE FRAME ===
            if gui_cmd == 'capture_base' or (gui_cmd and gui_cmd.startswith('save_base')):
                print(f"[INFO] Received '{gui_cmd}' command. Updating ref_frame from current camera frame.", flush=True)
                ref_frame = frame_raw.copy()
                try:
                    from src.software.core.config import SAVED_GAMES_DIR
                    os.makedirs(SAVED_GAMES_DIR, exist_ok=True)
                    latest_p = os.path.join(SAVED_GAMES_DIR, "latest_base_frame.png")
                    cv2.imwrite(latest_p, ref_frame)
                    if gui_cmd.startswith('save_base '):
                        g_name = gui_cmd.split(' ', 1)[1].strip()
                        g_p = os.path.join(SAVED_GAMES_DIR, f"{g_name}_base.png")
                        cv2.imwrite(g_p, ref_frame)
                except Exception as e:
                    print(f"[ERROR] Base frame save error: {e}", flush=True)
                print(f"[INFO] ref_frame updated successfully. Shape: {ref_frame.shape}", flush=True)
                print(json.dumps({"event": "base_captured"}), flush=True)

            if gui_cmd and gui_cmd.startswith('load_base'):
                try:
                    from src.software.core.config import SAVED_GAMES_DIR
                    parts = gui_cmd.split(' ', 1)
                    loaded = False
                    if len(parts) > 1:
                        g_name = parts[1].strip()
                        g_p = os.path.join(SAVED_GAMES_DIR, f"{g_name}_base.png")
                        if os.path.exists(g_p):
                            img = cv2.imread(g_p)
                            if img is not None:
                                ref_frame = img
                                loaded = True
                    if not loaded:
                        latest_p = os.path.join(SAVED_GAMES_DIR, "latest_base_frame.png")
                        if os.path.exists(latest_p):
                            img = cv2.imread(latest_p)
                            if img is not None:
                                ref_frame = img
                                loaded = True
                    if not loaded:
                        ref_frame = frame_raw.copy()
                    print(json.dumps({"event": "base_loaded", "success": True}), flush=True)
                except Exception as e:
                    print(f"[ERROR] Base frame load error: {e}", flush=True)

            # === USER EXECUTE COMMAND: COMPUTE DIFF ===
            if gui_cmd == 'r':
                if ref_frame is None:
                    print(json.dumps({"event": "move_invalid", "reason": "No base frame. Camera syncing..."}), flush=True)
                else:
                    g1 = 0.5 * ref_frame[:, :, 2] + 0.4 * ref_frame[:, :, 1] + 0.1 * ref_frame[:, :, 0]
                    g2 = 0.5 * frame_raw[:, :, 2] + 0.4 * frame_raw[:, :, 1] + 0.1 * frame_raw[:, :, 0]
                    g1 = g1.astype(np.uint8)
                    g2 = g2.astype(np.uint8)

                    g1 = cv2.GaussianBlur(g1, (5, 5), 0)
                    g2 = cv2.GaussianBlur(g2, (5, 5), 0)
                    diff = cv2.absdiff(g1, g2)
                    diff = cv2.GaussianBlur(diff, (3,3), 0)
                    diff = cv2.convertScaleAbs(diff, alpha=1.3, beta=0)
                    _, diff_thresh = cv2.threshold(diff, MOVE_THRESHOLD, 255, cv2.THRESH_BINARY)
                    diff_m = cv2.dilate(diff_thresh, None, iterations=4)
                    diff_m = cv2.erode(diff_m, None, iterations=2)

                    mask_board = np.zeros_like(diff_m)
                    for pts in sq_points.values():
                        cv2.fillPoly(mask_board, [np.array(pts, np.int32)], 255)
                    diff_m = cv2.bitwise_and(diff_m, mask_board)

                    # Send Mask to DEBUG_MASK channel
                    if DEBUG_MODE:
                        diff_bgr = cv2.cvtColor(diff_m, cv2.COLOR_GRAY2BGR)
                        send_frame_to_gui("DEBUG_MASK", diff_bgr)

                    kernel = np.ones((3, 3), np.uint8)
                    diff_m = cv2.morphologyEx(diff_m, cv2.MORPH_OPEN, kernel)
                    diff_m = cv2.morphologyEx(diff_m, cv2.MORPH_CLOSE, kernel)

                    contours, _ = cv2.findContours(diff_m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
                    contours_filtered = [c for c in contours if cv2.contourArea(c) > MIN_CONTOUR_AREA]

                    contour_cand_lists = [(c, candidates_for_contour(c)) for c in contours_filtered]
                    detected = set()
                    chosen_mapping = []
                    prev_board = board.copy()
                    validated_from = None
                    validated_to = None

                    if len(contour_cand_lists) >= 2:
                        contour_cand_lists = sorted(contour_cand_lists, key=lambda it: cv2.contourArea(it[0]), reverse=True)[:2]
                        (c0, list0), (c1, list1) = contour_cand_lists

                        found = False
                        for s0, cx0, cy0 in list0:
                            for s1, cx1, cy1 in list1:
                                try_moves = [(s0, s1), (s1, s0)]
                                for fr, to in try_moves:
                                    try: 
                                        mv = chess.Move.from_uci(fr + to)
                                    except Exception: 
                                        continue
                                    if mv in prev_board.legal_moves:
                                        detected = {fr, to}
                                        validated_from = fr
                                        validated_to = to
                                        chosen_mapping = [(fr, cx0, cy0) if fr==s0 else (fr, cx1, cy1),
                                                          (to, cx1, cy1) if to==s1 else (to, cx0, cy0)]
                                        found = True
                                        break
                                if found: break
                            if found: break

                        if not found:
                          if list0 and list1:
                              s0, s1 = list0[0][0], list1[0][0]
                              detected = {s0, s1}
                              chosen_mapping = [(s0, list0[0][1], list0[0][2]), (s1, list1[0][1], list1[0][2])]

                    elif len(contour_cand_lists) == 1:
                        c0, list0 = contour_cand_lists[0]
                        if list0:
                            dest_chosen = None
                            for sq_try, cx_try, cy_try in list0:
                                candidates = [m for m in prev_board.legal_moves if m.uci()[2:] == sq_try]
                                if candidates:
                                    dest_chosen = (sq_try, cx_try, cy_try)
                                    break
                            if dest_chosen:
                                detected = {dest_chosen[0]}
                                chosen_mapping = [dest_chosen]
                            else:
                                detected = {list0[0][0]}
                                chosen_mapping = [list0[0]]

                    # Send mapped contours to DEBUG_MAP channel
                    if DEBUG_MODE:
                        if chosen_mapping:
                            dbg = frame_raw.copy()
                            for sq, cx, cy in chosen_mapping:
                                poly = np.array(sq_points[sq], np.int32)
                                cv2.polylines(dbg, [poly], True, (0,255,0), 2)
                                cv2.circle(dbg, (int(cx), int(cy)), 4, (0,0,255), -1)
                                cv2.putText(dbg, sq, (int(cx)+6, int(cy)), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0,255,0), 1)
                            send_frame_to_gui("DEBUG_MAP", dbg)
                        else:
                            send_frame_to_gui("DEBUG_MAP", frame_raw.copy())

                    from_sq, to_sq = None, None
                    if validated_from and validated_to:
                        from_sq, to_sq = validated_from, validated_to
                    elif len(detected) == 2:
                        a, b = list(detected)
                        prev_board = board.copy()
                        piece_a = prev_board.piece_at(chess.parse_square(a))
                        piece_b = prev_board.piece_at(chess.parse_square(b))

                        if piece_a and not piece_b:
                            from_sq, to_sq = a, b
                        elif piece_b and not piece_a:
                            from_sq, to_sq = b, a
                        elif piece_a and piece_b:
                            # Both squares have pieces -> CAPTURE!
                            if piece_a.color == board.turn and piece_b.color != board.turn:
                                from_sq, to_sq = a, b
                            elif piece_b.color == board.turn and piece_a.color != board.turn:
                                from_sq, to_sq = b, a
                            else:
                                if chess.Move.from_uci(a + b) in board.legal_moves:
                                    from_sq, to_sq = a, b
                                elif chess.Move.from_uci(b + a) in board.legal_moves:
                                    from_sq, to_sq = b, a
                        else:
                            if chess.Move.from_uci(a + b) in board.legal_moves:
                                from_sq, to_sq = a, b
                            elif chess.Move.from_uci(b + a) in board.legal_moves:
                                from_sq, to_sq = b, a

                    elif len(detected) == 1:
                        to_sq = list(detected)[0]
                        prev_board = board.copy()
                        piece_now = board.piece_at(chess.parse_square(to_sq))

                        if piece_now:
                            candidates = [m for m in board.legal_moves if m.uci()[2:] == to_sq]
                            chosen = None
                            for m in candidates:
                                src = m.uci()[:2]
                                if prev_board.piece_at(chess.parse_square(src)):
                                    chosen = m
                                    break
                            if not chosen and candidates: chosen = candidates[0]
                            if chosen:
                                from_sq = chosen.uci()[:2]
                                to_sq = chosen.uci()[2:]
                        else:
                            file = to_sq[0]
                            rank = int(to_sq[1])
                            fi = files.index(file)
                            search_offsets = []
                            if board.turn == chess.WHITE:
                                search_offsets += [(0, -1), (-1, 0), (1, 0), (-1, -1), (1, -1), (0, -2)]
                            else:
                                search_offsets += [(0, 1), (-1, 0), (1, 0), (-1, 1), (1, 1), (0, 2)]
                            search_offsets += [(-1, 1), (1, 1), (-1, -1), (1, -1)]

                            found = False
                            for df, dr in search_offsets:
                                f_idx = fi + df
                                r_idx = rank + dr
                                if 0 <= f_idx < 8 and 1 <= r_idx <= 8:
                                    adj = f"{files[f_idx]}{r_idx}"
                                    if prev_board.piece_at(chess.parse_square(adj)):
                                        try_mv = chess.Move.from_uci(adj + to_sq)
                                        if try_mv in board.legal_moves:
                                            from_sq = adj
                                            found = True
                                            break
                            if not found:
                                for df in (-1, 0, 1):
                                    for dr in (-1, 0, 1):
                                        if df == 0 and dr == 0: continue
                                        f_idx = fi + df
                                        r_idx = rank + dr
                                        if 0 <= f_idx < 8 and 1 <= r_idx <= 8:
                                            adj = f"{files[f_idx]}{r_idx}"
                                            if prev_board.piece_at(chess.parse_square(adj)):
                                                try: try_mv = chess.Move.from_uci(adj + to_sq)
                                                except Exception: try_mv = None
                                                if try_mv and try_mv in board.legal_moves:
                                                    from_sq = adj
                                                    found = True
                                                    break
                                                if not from_sq: from_sq = adj
                                    if found: break

                    if from_sq and to_sq:
                        move = from_sq + to_sq
                        try:
                            mv = chess.Move.from_uci(move)
                            if mv in board.legal_moves:
                                moving_piece = board.piece_at(chess.parse_square(from_sq))
                                board.push(mv)
                                move_history.append(mv)
                                last_move = mv

                                # Valid Move Registered!
                                print(json.dumps({"event": "move_valid", "move": move}), flush=True)

                                if moving_piece:
                                    show_board(board, last_move)
                                try:
                                    frame_high = overlay_poly(frame_raw.copy(), sq_points[from_sq], (0, 255, 0), 0.5)
                                    frame_high = overlay_poly(frame_high, sq_points[to_sq], (0, 0, 255), 0.5)
                                    frame_high = draw_board_labels(frame_high)
                                    send_frame_to_gui("TRACKER", frame_high)
                                    time.sleep(0.7)
                                except Exception: pass

                                comp_turn = True
                                ref_frame = None  # Consume frame only on successful move!
                            else:
                                print(json.dumps({"event": "move_invalid", "reason": "Illegal chess move"}), flush=True)
                        except Exception:
                            print(json.dumps({"event": "move_invalid", "reason": "Parse error"}), flush=True)
                    else:
                        print(json.dumps({"event": "move_invalid", "reason": "No clear move detected"}), flush=True)

            # === Undo 1 langkah ===
            if gui_cmd == 'u':
                if move_history:
                    mv = move_history.pop()
                    board.pop()
                    show_board(board)

            # === Undo 2 langkah ===
            if gui_cmd == 'U':
                if len(move_history) >= 2:
                    mv2 = move_history.pop()
                    mv1 = move_history.pop()
                    board.pop()
                    board.pop()
                    show_board(board)

            # === COMPUTER TURN ===
            if comp_turn:
                depth_limit, thinking_time = get_search_limits_for_elo(current_engine_elo)

                # Beginner move simulation for Level 0 (800 ELO)
                chosen_move = None
                if current_engine_elo <= 800 and random.random() < 0.25:
                    legal_moves = list(board.legal_moves)
                    if legal_moves:
                        chosen_move = random.choice(legal_moves)

                if chosen_move is None:
                    if depth_limit is not None:
                        result = engine.play(board, chess.engine.Limit(time=thinking_time, depth=depth_limit))
                    else:
                        result = engine.play(board, chess.engine.Limit(time=thinking_time))
                    chosen_move = result.move

                mv = chosen_move
                move_str = mv.uci()

                try:
                    src_sq = move_str[:2]
                    tgt_sq = move_str[2:4]
                    moving_piece_ai = board.piece_at(chess.parse_square(src_sq))
                    target_piece = board.piece_at(chess.parse_square(tgt_sq))
                    is_capture = (target_piece is not None)
                except Exception:
                    moving_piece_ai = None
                    is_capture = False

                board.push(mv)
                move_history.append(mv)
                last_move = mv

                try:
                    ai_color = chess.WHITE if player_color == "black" else chess.BLACK
                    if moving_piece_ai and moving_piece_ai.color == ai_color:
                        movement_counter += 1

                        if is_capture:
                            kill_payload = {
                                "action": "kill",
                                "target_pos": tgt_sq
                            }
                            print(json.dumps(kill_payload), flush=True)

                        move_payload = {
                            "action": "move",
                            "piece_name": piece_name_from_type(moving_piece_ai.piece_type),
                            "current_pos": src_sq,
                            "target_pos": tgt_sq
                        }
                        print(json.dumps(move_payload), flush=True)

                except Exception: pass

                show_board(board, last_move)

                try:
                    move_str = mv.uci()
                    frame_ai = overlay_poly(frame_raw.copy(), sq_points[move_str[:2]], (0, 255, 255), 0.45)
                    frame_ai = overlay_poly(frame_ai, sq_points[move_str[2:]], (0, 165, 255), 0.45)
                    frame_ai = draw_board_labels(frame_ai)
                    send_frame_to_gui("TRACKER", frame_ai)
                    time.sleep(0.9)
                except Exception: pass

                comp_turn = False

            if gui_cmd == 'q':
                break

    finally:
        cap.release()
        engine.quit()

if __name__ == "__main__":
    main()
