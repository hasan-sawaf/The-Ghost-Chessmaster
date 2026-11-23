# Hardware Task Queue and Pathing Executor for ChessTracker - Decoupled Data & Driver Layer
import queue
import time
from src.software.core.constants import CHESS_X, CHESS_Y

class TaskExecutor:
    """
    Handles sequential hardware task execution from the GUI queue.
    Translates moves, knight jumps, castling, and kills into serial commands.
    """
    def __init__(self, task_queue, wait_for_idle, log_callback, move_to_sq_callback, send_serial_cmd_callback, send_cv_cmd_callback, get_running_status_callback, on_ai_move_complete_callback=None):
        self.task_queue = task_queue
        self.wait_for_idle = wait_for_idle
        self.log_callback = log_callback
        self.move_to_sq_callback = move_to_sq_callback
        self.send_serial_cmd_callback = send_serial_cmd_callback
        self.send_cv_cmd_callback = send_cv_cmd_callback
        self.get_running_status_callback = get_running_status_callback
        self.on_ai_move_complete_callback = on_ai_move_complete_callback

    def run_worker(self):
        while self.get_running_status_callback():
            try:
                task = self.task_queue.get(timeout=0.1)
                if task['type'] == 'kill':
                    self.execute_kill_piece(task['sq'])
                elif task['type'] == 'move':
                    self._run_pick_and_place_core(task['src'], task['tgt'], task['piece'])
                elif task['type'] == 'castling':
                    self.execute_castling_move(task['side'], task['color'])
                self.task_queue.task_done()
            except queue.Empty:
                pass

    def execute_kill_piece(self, sq):
        f_idx = "ABCDEFGH".index(sq[0])
        r_idx = int(sq[1]) - 1
        sx = CHESS_X[f_idx]
        sy = CHESS_Y[r_idx]

        self._log(f"☠️ HARDWARE: Executing Graveyard Clearance on {sq} (X:{sx}cm, Y:{sy}cm)")

        self.wait_for_idle.clear()
        self.move_to_sq_callback(sq)
        self.wait_for_idle.wait()

        time.sleep(0.5)
        self.send_serial_cmd_callback('9')
        time.sleep(0.5)

        sy_shifted = sy - 3.5 if sy > 24.0 else sy + 3.5
        sx_sc = sx * (350.0 / 600.0)
        sy_shifted_sc = sy_shifted * (410.0 / 600.0)

        self.wait_for_idle.clear()
        self.send_serial_cmd_callback(f"G X{sx_sc:.3f} Y{sy_shifted_sc:.3f}")
        self.wait_for_idle.wait()

        if sx < 30.0:
            graveyard_x = 0.5
        else:
            graveyard_x = 58.5

        gx_sc = graveyard_x * (350.0 / 600.0)

        self.wait_for_idle.clear()
        self.send_serial_cmd_callback(f"G X{gx_sc:.3f} Y{sy_shifted_sc:.3f}")
        self.wait_for_idle.wait()

        time.sleep(0.5)
        self.send_serial_cmd_callback('0')
        time.sleep(0.5)
        self._log(f"🪦 HARDWARE: Opponent piece deposited at graveyard X:{graveyard_x}cm")

    def _run_pick_and_place_core(self, source, target, piece):
        self._log(f"▶ HARDWARE: Auto Move Start [{source} -> {target}] ({piece})")

        self.wait_for_idle.clear()
        self.move_to_sq_callback(source)
        self.wait_for_idle.wait()

        time.sleep(0.5)
        self.send_serial_cmd_callback('9')
        time.sleep(0.5)

        if piece == "Knight":
            self.execute_knight_move(source, target)
        else:
            self.wait_for_idle.clear()
            self.move_to_sq_callback(target)
            self.wait_for_idle.wait()

        time.sleep(0.5)
        self.send_serial_cmd_callback('0')
        self._log("✅ HARDWARE: Move Sequence Complete (Magnet released '0')")
        if self.on_ai_move_complete_callback:
            self.on_ai_move_complete_callback()

    def execute_castling_move(self, side, color):
        self._log(f"▶ HARDWARE: Castling Move Start [{side}-side, {color}]")

        is_black = (color.lower() == "black")
        rank = "8" if is_black else "1"

        ks_sq = f"E{rank}"
        ke_sq = f"G{rank}" if side == "king" else f"C{rank}"
        rs_sq = f"H{rank}" if side == "king" else f"A{rank}"
        re_sq = f"F{rank}" if side == "king" else f"D{rank}"

        self._log(f"Squares involved: King {ks_sq}->{ke_sq}, Rook {rs_sq}->{re_sq}")

        f_idx = "ABCDEFGH".index(ks_sq[0])
        kx = CHESS_X[f_idx]
        if is_black:
            ky_back = CHESS_Y[7] - 4.0
        else:
            ky_back = CHESS_Y[0] + 4.0

        kx_sc = kx * (350.0 / 600.0)
        ky_back_sc = ky_back * (410.0 / 600.0)

        self.wait_for_idle.clear()
        self.move_to_sq_callback(ks_sq)
        self.wait_for_idle.wait()

        time.sleep(0.5)
        self.send_serial_cmd_callback('9')
        time.sleep(0.5)

        self.wait_for_idle.clear()
        self.send_serial_cmd_callback(f"G X{kx_sc:.3f} Y{ky_back_sc:.3f}")
        self.wait_for_idle.wait()

        time.sleep(0.5)
        self.send_serial_cmd_callback('0')
        time.sleep(0.5)

        self.wait_for_idle.clear()
        self.move_to_sq_callback(rs_sq)
        self.wait_for_idle.wait()

        time.sleep(0.5)
        self.send_serial_cmd_callback('9')
        time.sleep(0.5)

        self.wait_for_idle.clear()
        self.move_to_sq_callback(re_sq)
        self.wait_for_idle.wait()

        time.sleep(0.5)
        self.send_serial_cmd_callback('0')
        time.sleep(0.5)

        self.wait_for_idle.clear()
        self.send_serial_cmd_callback(f"G X{kx_sc:.3f} Y{ky_back_sc:.3f}")
        self.wait_for_idle.wait()

        time.sleep(0.5)
        self.send_serial_cmd_callback('9')
        time.sleep(0.5)

        self.wait_for_idle.clear()
        self.move_to_sq_callback(ke_sq)
        self.wait_for_idle.wait()

        time.sleep(0.5)
        self.send_serial_cmd_callback('0')
        time.sleep(0.5)

        self._log("✅ HARDWARE: Castling Move Complete (Magnet released '0')")
        if self.on_ai_move_complete_callback:
            self.on_ai_move_complete_callback()

    def execute_knight_move(self, source, target):
        f_src = "ABCDEFGH".index(source[0])
        r_src = int(source[1]) - 1
        f_tgt = "ABCDEFGH".index(target[0])
        r_tgt = int(target[1]) - 1

        sx, sy = CHESS_X[f_src], CHESS_Y[r_src]
        tx, ty = CHESS_X[f_tgt], CHESS_Y[r_tgt]

        dx = abs(f_tgt - f_src)
        dy = abs(r_tgt - r_src)

        if dx == 1 and dy == 2:
            gutter_x = (CHESS_X[f_src] + CHESS_X[f_tgt]) / 2.0
            gx_sc = gutter_x * (350.0 / 600.0)
            sy_sc = sy * (410.0 / 600.0)
            self.wait_for_idle.clear()
            self.send_serial_cmd_callback(f"G X{gx_sc:.3f} Y{sy_sc:.3f}")
            self.wait_for_idle.wait()

            ty_sc = ty * (410.0 / 600.0)
            self.wait_for_idle.clear()
            self.send_serial_cmd_callback(f"G X{gx_sc:.3f} Y{ty_sc:.3f}")
            self.wait_for_idle.wait()

        elif dx == 2 and dy == 1:
            gutter_y = (CHESS_Y[r_src] + CHESS_Y[r_tgt]) / 2.0
            sx_sc = sx * (350.0 / 600.0)
            gy_sc = gutter_y * (410.0 / 600.0)
            self.wait_for_idle.clear()
            self.send_serial_cmd_callback(f"G X{sx_sc:.3f} Y{gy_sc:.3f}")
            self.wait_for_idle.wait()

            tx_sc = tx * (350.0 / 600.0)
            self.wait_for_idle.clear()
            self.send_serial_cmd_callback(f"G X{tx_sc:.3f} Y{gy_sc:.3f}")
            self.wait_for_idle.wait()

        self.wait_for_idle.clear()
        self.move_to_sq_callback(target)
        self.wait_for_idle.wait()

    def _log(self, msg):
        if self.log_callback:
            self.log_callback(msg)
