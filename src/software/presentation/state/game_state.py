import tkinter as tk
from tkinter import ttk, scrolledtext, simpledialog, messagebox
import threading
import os
import sys
import base64
import io
import time
import queue
from PIL import Image, ImageTk
import json

class GameMixin:
    def reset_live_game(self):
        self.live_game_moves = []
        self.live_analyzed_moves = []
        self.target_pct_live = 0.5
        self.current_pct_live = 0.5
        self.current_eval_str = "0.00"
        self.lbl_live_move.config(text="--")
        self.lbl_live_class.config(text="Rating: --", fg="black")
        self.lbl_best_move.config(text="--")
        self.lbl_live_eval.config(text="Eval: 0.00")
        self.lbl_detail_metrics.config(text="Centipawn Loss: 0 | Move Accuracy: 100.0%")
        if hasattr(self, "tree_live_moves"):
            for item in self.tree_live_moves.get_children():
                self.tree_live_moves.delete(item)

        # Reset live cards
        if hasattr(self, "lbl_white_accuracy"):
            self.lbl_white_accuracy.config(text="Accuracy: --")
            for cat in self.white_stat_labels:
                self.white_stat_labels[cat].config(text=" 0")
        if hasattr(self, "lbl_black_accuracy"):
            self.lbl_black_accuracy.config(text="Accuracy: --")
            for cat in self.black_stat_labels:
                self.black_stat_labels[cat].config(text=" 0")
        self.redraw_live_eval_bar_to_canvas()
        self.log("[Live Analysis] Game history and metrics reset.")

    def prompt_save_game(self):
        from src.software.presentation.app import SaveGameConfigDialog
        last_cfg = getattr(self, "save_game_config", None)
        player_clr = self.var_player_color.get() if hasattr(self, 'var_player_color') else "White"
        dialog = SaveGameConfigDialog(self.root, current_elo=self.var_elo.get(), player_color=player_clr, last_config=last_cfg, title="Save Next Played Game")
        result = dialog.result

        if result and result.get("auto_save"):
            self.save_game_config = result
            self.log(f"[Game] Configured to auto-save game as: {result['name']}")
            # Immediately save an empty game to create the file
            self.auto_save_game()
            self.save_game_settings() # Persist to last saved game settings
        else:
            self.save_game_config = None
            self.log("[Game] Auto-save disabled for the next game.")
            self.save_game_settings()

    def auto_save_game(self):
        if not getattr(self, "save_game_config", None):
            return
        cfg = self.save_game_config
        moves = getattr(self, "live_game_moves", [])
        self.save_game_to_history(cfg["name"], moves, config=cfg)

    def save_game_to_history(self, game_name, moves, config=None):
        import chess
        import chess.pgn
        import datetime

        game = chess.pgn.Game()
        if config:
            game.headers["Event"] = config.get("event", "CoreXY Robotic Chess Match")
            game.headers["Site"] = config.get("site", "?")
            game.headers["Date"] = datetime.date.today().strftime("%Y.%m.%d")
            game.headers["Round"] = config.get("round", "1")
            game.headers["White"] = config.get("white", "Human")
            game.headers["Black"] = config.get("black", f"Stockfish (ELO {self.var_elo.get()})")
        else:
            game.headers["Event"] = "CoreXY Robotic Chess Match"
            game.headers["Date"] = datetime.date.today().strftime("%Y.%m.%d")
            game.headers["Round"] = "1"
            player_clr = self.var_player_color.get() if hasattr(self, 'var_player_color') else "White"
            if player_clr == "White":
                game.headers["White"] = "Human"
                game.headers["Black"] = f"Stockfish (ELO {self.var_elo.get()})"
            else:
                game.headers["White"] = f"Stockfish (ELO {self.var_elo.get()})"
                game.headers["Black"] = "Human"
        game.headers["Result"] = "*"

        node = game
        board = chess.Board()
        for m_str in moves:
            try:
                mv = chess.Move.from_uci(m_str)
                if mv in board.legal_moves:
                    node = node.add_variation(mv)
                    board.push(mv)
            except Exception:
                break

        if board.is_checkmate():
            game.headers["Result"] = "1-0" if board.turn == chess.BLACK else "0-1"
        elif board.is_game_over():
            game.headers["Result"] = "1/2-1/2"

        exporter = chess.pgn.StringExporter(headers=False, variations=False, comments=False)
        moves_str = game.accept(exporter).strip()
        res_str = game.headers["Result"]
        if moves_str.endswith(f" {res_str}"):
            moves_str = moves_str[:-len(res_str) - 1].strip()
        elif moves_str == res_str:
            moves_str = ""

        tags_str = ""
        for key, value in game.headers.items():
            tags_str += f'[{key} "{value}"]\n'
        tags_str += f"\n{res_str}"

        from src.software.core.config import SAVED_GAMES_DIR
        saved_dir = SAVED_GAMES_DIR
        os.makedirs(saved_dir, exist_ok=True)

        save_path = os.path.join(saved_dir, f"{game_name}.json")
        payload = {
            "name": game_name,
            "date": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "pgn": moves_str,
            "GameTags": tags_str,
            "moves": list(getattr(self, "live_analyzed_moves", [])),
            "report": "",
            "white_elo": self.var_elo.get(),
            "turn": getattr(self, "var_turn", tk.StringVar(value="WHITE")).get(),
            "white_time_left": getattr(self, "white_time_left", int(self.var_game_timer.get() or 10) * 60),
            "black_time_left": getattr(self, "black_time_left", int(self.var_game_timer.get() or 10) * 60),
            "timer_minutes": self.var_game_timer.get(),
            "increment_seconds": self.var_time_increment.get(),
            "play_style": self.var_play_style.get(),
            "last_square": getattr(self, "var_current_sq", tk.StringVar(value="None")).get(),
            "last_x": getattr(self, "var_x", tk.StringVar(value="0.0")).get(),
            "last_y": getattr(self, "var_y", tk.StringVar(value="0.0")).get()
        }

        try:
            with open(save_path, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2)
            self.log(f"[✅] Saved game history to {save_path}")

            if hasattr(self, "send_cv_cmd"):
                self.send_cv_cmd(f"save_base {game_name}")
            try:
                import shutil
                latest_img = os.path.join(saved_dir, "latest_base_frame.png")
                target_img = os.path.join(saved_dir, f"{game_name}_base.png")
                if os.path.exists(latest_img):
                    shutil.copy(latest_img, target_img)
            except Exception: pass

            if hasattr(self, "deep_analysis_page"):
                self.deep_analysis_page.load_saved_games_list()
        except Exception as e:
            self.log(f"[Error Saving Game] {e}")

    # ==========================================
    # HELPER MATH AND BAR ANIMATION
    # ==========================================
    def increase_timer_5m(self):
        try:
            val = int(self.var_game_timer.get())
            if val < 30:
                self.var_game_timer.set(str(val + 5))
        except Exception:
            self.var_game_timer.set("10")

    def decrease_timer_5m(self):
        try:
            val = int(self.var_game_timer.get())
            if val > 5:
                self.var_game_timer.set(str(val - 5))
        except Exception:
            self.var_game_timer.set("10")

    def increase_increment(self):
        try:
            val = int(self.var_time_increment.get())
            if val < 3:
                self.var_time_increment.set(str(val + 1))
        except Exception:
            self.var_time_increment.set("2")

    def decrease_increment(self):
        try:
            val = int(self.var_time_increment.get())
            if val > 1:
                self.var_time_increment.set(str(val - 1))
        except Exception:
            self.var_time_increment.set("2")

    def update_digital_timer_display(self, *_args):
        try:
            minutes = int(self.var_game_timer.get())
            if hasattr(self, "lbl_digital_timer"):
                if minutes == 0:
                    self.lbl_digital_timer.config(text="00:00 (∞)")
                else:
                    self.lbl_digital_timer.config(text=f"{minutes:02d}:00")
            self.update_clock_ui_labels()
        except Exception:
            pass

    def update_digital_increment_display(self, *_args):
        try:
            val = self.var_time_increment.get()
            if hasattr(self, "lbl_digital_increment"):
                self.lbl_digital_increment.config(text=f"{int(val):02d}s")
        except Exception:
            pass

    def update_dashboard_settings_display(self):
        try:
            timer_val = self.var_game_timer.get()
            inc_val = self.var_time_increment.get()
            elo_val = self.var_elo.get()
            style_val = self.var_play_style.get()
            color_val = self.var_player_color.get() if hasattr(self, 'var_player_color') else "White"

            # Column 1 (Left): Match Settings
            if hasattr(self, "lbl_dash_config_timer"):
                if str(timer_val) == "0":
                    self.lbl_dash_config_timer.config(text="⏱️ Time Limit: No Timer (00:00 ∞)")
                else:
                    self.lbl_dash_config_timer.config(text=f"⏱️ Time Limit: {timer_val} minutes")
            if hasattr(self, "lbl_dash_config_inc"):
                self.lbl_dash_config_inc.config(text=f"⚡ Increment: {inc_val}s per move")
            if hasattr(self, "lbl_dash_config_difficulty"):
                lvl_str = self.var_level_name.get().split(':')[0] if hasattr(self, 'var_level_name') else "AI"
                self.lbl_dash_config_difficulty.config(text=f"🤖 AI Level: {lvl_str} ({elo_val} ELO)")
            if hasattr(self, "lbl_dash_config_style"):
                self.lbl_dash_config_style.config(text=f"⚔️ Playing Style: {style_val}")
            if hasattr(self, "lbl_dash_config_color"):
                self.lbl_dash_config_color.config(text=f"♟️ Playing As: {color_val}")

            # Column 2 (Right): Match Origin & App Sync Details
            is_game_active = getattr(self, "game_active", False)
            match_origin = getattr(self, "match_origin", "IDLE")
            is_user_conn = hasattr(self, "firebase_manager") and self.firebase_manager and self.firebase_manager.is_user_connected

            if hasattr(self, "lbl_dash_match_origin"):
                if is_game_active:
                    if match_origin == "FLUTTER_APP":
                        self.lbl_dash_match_origin.config(
                            text="🚀 Origin: 📱 Flutter Mobile App",
                            fg="#1b5e20"
                        )
                    elif match_origin == "PYTHON_GUI":
                        self.lbl_dash_match_origin.config(
                            text="🚀 Origin: 💻 Python Desktop GUI",
                            fg="#0d47a1"
                        )
                    elif match_origin == "ARDUINO_HARDWARE":
                        self.lbl_dash_match_origin.config(
                            text="🚀 Origin: 🔘 Arduino Hardware Button",
                            fg="#e65100"
                        )
                    else:
                        self.lbl_dash_match_origin.config(
                            text="🚀 Origin: Local System",
                            fg="#37474f"
                        )
                else:
                    self.lbl_dash_match_origin.config(
                        text="🚀 Origin: ⏸️ Idle (Waiting to Start)",
                        fg="#757575"
                    )

            if hasattr(self, "lbl_dash_sync_status"):
                if is_game_active and match_origin == "FLUTTER_APP" and is_user_conn:
                    self.lbl_dash_sync_status.config(
                        text="🟢 MATCH STARTED FROM APP",
                        fg="#2e7d32"
                    )
                    if hasattr(self, "lbl_dash_sync_detail"):
                        self.lbl_dash_sync_detail.config(
                            text="✓ Physical Game Mode Active\nMoves are syncing in real-time to Flutter app.",
                            fg="#2e7d32"
                        )
                elif is_game_active:
                    self.lbl_dash_sync_status.config(
                        text="🔴 NOT STARTED FROM APP",
                        fg="#d32f2f"
                    )
                    if hasattr(self, "lbl_dash_sync_detail"):
                        self.lbl_dash_sync_detail.config(
                            text="⚠ Started from GUI/Arduino (Not Physical Mode).\nMoves will NOT show in Flutter app.",
                            fg="#d32f2f"
                        )
                else:
                    self.lbl_dash_sync_status.config(
                        text="⚪ Ready for Next Match",
                        fg="#546e7a"
                    )
                    if hasattr(self, "lbl_dash_sync_detail"):
                        self.lbl_dash_sync_detail.config(
                            text="Start from Flutter app for Physical Mode,\nor click 'Start Game' for local play.",
                            fg="#757575"
                        )

            if hasattr(self, "lbl_dash_user_link"):
                if is_user_conn:
                    email = self.firebase_manager.connected_user_email or "Connected"
                    self.lbl_dash_user_link.config(
                        text=f"👤 User: {email}",
                        fg="#1b5e20" if (is_game_active and match_origin == "FLUTTER_APP") else "#546e7a"
                    )
                else:
                    self.lbl_dash_user_link.config(
                        text="👤 User: Disconnected",
                        fg="#9e9e9e"
                    )
        except Exception:
            pass

    def start_game_timers(self):
        # Cancel any previous ticking loop
        if hasattr(self, "timer_after_id") and self.timer_after_id is not None:
            try: self.root.after_cancel(self.timer_after_id)
            except Exception: pass
            self.timer_after_id = None

        try:
            self.white_time_left = int(self.var_game_timer.get()) * 60
            self.black_time_left = int(self.var_game_timer.get()) * 60
        except Exception:
            self.white_time_left = 600
            self.black_time_left = 600

        self.prev_turn = "WAITING CV"
        self.game_timers_active = True
        self.update_clock_ui_labels()
        # Reschedule ticking in 1s
        self.timer_after_id = self.root.after(1000, self.tick_game_clock)

    def stop_game_timers(self):
        self.game_timers_active = False
        if hasattr(self, "timer_after_id") and self.timer_after_id is not None:
            try: self.root.after_cancel(self.timer_after_id)
            except Exception: pass
            self.timer_after_id = None
        self.update_clock_ui_labels()

    def tick_game_clock(self):
        if not hasattr(self, "game_timers_active") or not self.game_timers_active:
            return

        current_turn = self.var_turn.get()

        # Check for turn change to apply increment
        if current_turn != self.prev_turn:
            try:
                increment = int(self.var_time_increment.get())
                if self.prev_turn in ("WHITE", "WHITE (AI)") and current_turn in ("BLACK (AI)", "BLACK"):
                    self.white_time_left += increment
                elif self.prev_turn in ("BLACK (AI)", "BLACK") and current_turn in ("WHITE", "WHITE (AI)"):
                    self.black_time_left += increment
            except Exception:
                pass
            self.prev_turn = current_turn

        # Decrement active player's clock only if time limit is set (> 0)
        t_limit = int(self.var_game_timer.get() or 0)
        if t_limit > 0:
            if current_turn in ("WHITE", "WHITE (AI)"):
                if self.white_time_left > 0:
                    self.white_time_left -= 1
                    if self.white_time_left == 0:
                        self.handle_time_out("White")
            elif current_turn in ("BLACK (AI)", "BLACK"):
                if self.black_time_left > 0:
                    self.black_time_left -= 1
                    if self.black_time_left == 0:
                        self.handle_time_out("Black")

        self.update_clock_ui_labels()

        # Periodic sync to hardware LCD clock (every 3 seconds) to guarantee 100% sync
        if not hasattr(self, "_sync_tick_counter"):
            self._sync_tick_counter = 0
        self._sync_tick_counter += 1
        if self._sync_tick_counter % 3 == 0:
            self.send_cmd(f"S {self.white_time_left} {self.black_time_left}")

        # Reschedule next tick
        if self.game_timers_active:
            self.timer_after_id = self.root.after(1000, self.tick_game_clock)

    def on_ai_move_completed(self):
        # Do not start timers or change turn if no game is active (manual test move)
        if not getattr(self, "game_active", False):
            self.log("[Hardware] Manual test move complete.")
            return

        # Register pending AI move now that physical hardware execution complete
        if hasattr(self, "_pending_ai_move_str") and self._pending_ai_move_str:
            ai_move = self._pending_ai_move_str
            ai_color = getattr(self, "_pending_ai_player_color", "Black")
            self._pending_ai_move_str = None
            self._pending_ai_player_color = None
            self.register_live_move(ai_move, ai_color)

        w_left = getattr(self, "white_time_left", int(self.var_game_timer.get() or 10) * 60)
        b_left = getattr(self, "black_time_left", int(self.var_game_timer.get() or 10) * 60)

        player_color = getattr(self, 'var_player_color', None)
        playing_as_black = player_color and player_color.get() == "Black"
        human_turn = "BLACK" if playing_as_black else "WHITE"
        cmd = 'B' if playing_as_black else 'W'

        def _gui_update():
            self.var_turn.set(human_turn)
            self.var_status.set(f"System ready. Make move ({human_turn.lower().capitalize()})!")
            self.btn_execute.config(state=tk.NORMAL)

        try:
            self.root.after(0, _gui_update)
        except Exception:
            pass

        # Switch active clock on Arduino and LCD
        self.send_cmd(cmd)
        self.send_cmd(f"S {w_left} {b_left}")

        self.log(f"[Game] AI move hardware execution complete. Turn switched to {human_turn}.")

        # Request new base frame after hardware move complete
        time.sleep(0.5)
        self.send_cv_cmd('capture_base')

    def handle_time_out(self, player):
        self.game_timers_active = False
        self.var_turn.set("GAME OVER")
        self.var_status.set(f"{player} lost on time!")
        self.log(f"[⏰] Game Over: {player} lost on time.")
        from tkinter import messagebox
        messagebox.showinfo("Game Over", f"{player} lost on time!")

    def update_clock_ui_labels(self):
        t_limit = int(self.var_game_timer.get() or 0)
        if not hasattr(self, "game_timers_active") or not self.game_timers_active:
            try:
                if t_limit == 0:
                    clock_str = "00:00"
                else:
                    clock_str = f"{t_limit:02d}:00"
                if hasattr(self, "lbl_white_clock"):
                    self.lbl_white_clock.config(text=clock_str)
                if hasattr(self, "lbl_black_clock"):
                    self.lbl_black_clock.config(text=clock_str)
                if hasattr(self, "frame_white_clock"):
                    self.frame_white_clock.config(highlightbackground="#cfd8dc", highlightcolor="#cfd8dc")
                if hasattr(self, "frame_black_clock"):
                    self.frame_black_clock.config(highlightbackground="#cfd8dc", highlightcolor="#cfd8dc")
            except Exception:
                pass
            return

        if t_limit == 0:
            if hasattr(self, "lbl_white_clock"):
                self.lbl_white_clock.config(text="00:00")
            if hasattr(self, "lbl_black_clock"):
                self.lbl_black_clock.config(text="00:00")
        else:
            w_left = getattr(self, "white_time_left", t_limit * 60)
            b_left = getattr(self, "black_time_left", t_limit * 60)
            w_min = w_left // 60
            w_sec = w_left % 60
            b_min = b_left // 60
            b_sec = b_left % 60

            if hasattr(self, "lbl_white_clock"):
                self.lbl_white_clock.config(text=f"{w_min:02d}:{w_sec:02d}")
            if hasattr(self, "lbl_black_clock"):
                self.lbl_black_clock.config(text=f"{b_min:02d}:{b_sec:02d}")

        # Highlight active clock visually
        current_turn = self.var_turn.get()
        if current_turn in ("WHITE", "WHITE (AI)"):
            if hasattr(self, "frame_white_clock"):
                self.frame_white_clock.config(highlightbackground="#00e676", highlightcolor="#00e676")
            if hasattr(self, "frame_black_clock"):
                self.frame_black_clock.config(highlightbackground="#cfd8dc", highlightcolor="#cfd8dc")
        elif current_turn in ("BLACK (AI)", "BLACK"):
            if hasattr(self, "frame_white_clock"):
                self.frame_white_clock.config(highlightbackground="#cfd8dc", highlightcolor="#cfd8dc")
            if hasattr(self, "frame_black_clock"):
                self.frame_black_clock.config(highlightbackground="#ff9100", highlightcolor="#ff9100")
        else:
            if hasattr(self, "frame_white_clock"):
                self.frame_white_clock.config(highlightbackground="#cfd8dc", highlightcolor="#cfd8dc")
            if hasattr(self, "frame_black_clock"):
                self.frame_black_clock.config(highlightbackground="#cfd8dc", highlightcolor="#cfd8dc")

    # ==========================================
    # SYSTEM & GAME CONTROL LOGIC
    # ==========================================
    def start_game(self, prompt_settings=True):
        # 1. Verify CV Connection & Auto-start Camera
        is_cv_connected = (hasattr(self, "cv_bridge") and self.cv_bridge.cv_process is not None and self.cv_bridge.cv_process.poll() is None)
        if not is_cv_connected:
            self.log("[Game] Automatically starting Camera CV Engine for game play...")
            self.start_cv()

        # 2. Check if a game is already active
        if hasattr(self, "game_active") and self.game_active:
            if prompt_settings:
                from tkinter import messagebox
                confirm = messagebox.askyesno("Game Active", "A game is already active. Do you want to restart it?")
                if not confirm:
                    return
            else:
                self.log("[Game] Match already active, restarting game session...")

        # 3. Setup settings verification warning
        if prompt_settings:
            from tkinter import messagebox
            confirm_settings = messagebox.askyesno(
                "Verify Game Settings",
                "Have you configured your Game Settings (Timer, Increment, Difficulty) in the 'Game Settings' tab?\n\n"
                "Click YES to start the game, or NO to go configure settings."
            )
            if not confirm_settings:
                self.show_settings_page()
                return

        # 4. Set state
        self.game_active = True
        self.game_paused = False
        self._base_game_started = False
        if prompt_settings:
            self.match_origin = "PYTHON_GUI"
            self.is_physical_app_mode = False
        self.update_dashboard_settings_display()

        # 5. Lock settings tab
        self.set_settings_widgets_state(tk.DISABLED)

        # 6. Reset live game metrics and lists
        self.reset_live_game()

        # 7. Cleanly reset CV Engine board state and move history
        self.send_cv_cmd('reset_board')

        # 8. Start timers
        self.start_game_timers()

        # 9. Sync clock parameters over serial to hardware timer if connected
        try:
            timer_min = int(self.var_game_timer.get())
            increment_sec = int(self.var_time_increment.get())
            self.send_cmd(f"T {timer_min} {increment_sec}")
            if timer_min == 0:
                self.send_cmd("S 0 0")
        except Exception as e:
            self.log(f"[Warning] Failed to sync settings to clock module: {e}")

        # 10. Sync player color and AI ELO to CV engine
        player_color = self.var_player_color.get().lower()
        self.send_cv_cmd(f"set_player_color {player_color}")
        current_elo = self.var_elo.get() if hasattr(self, 'var_elo') else 1500
        self.send_cv_cmd(f"set_elo {current_elo}")

        # 11. Trigger baseline frame capture
        self.send_cv_cmd('capture_base')
        self.log(f"[Game] Start Game triggered ({self.match_origin}). Playing as {self.var_player_color.get()}. Reset board & base frame requested.")

    def stop_game(self):
        if not hasattr(self, "game_active") or not self.game_active:
            from tkinter import messagebox
            messagebox.showinfo("Stop Game", "No active game to stop.")
            return

        # Pause game state
        self.game_paused = True

        # Stop local countdown ticking
        self.stop_game_timers()

        # Send Pause command 'P' to hardware to pause the chess clock
        self.send_cmd('P')

        self.log("[Game] Game stopped (paused). Timers halted.")
        self.var_status.set("Game stopped.")

    def resume_game(self):
        if not hasattr(self, "game_active") or not self.game_active:
            from tkinter import messagebox
            messagebox.showinfo("Resume Game", "No active game to resume.")
            return

        if not hasattr(self, "game_paused") or not self.game_paused:
            from tkinter import messagebox
            messagebox.showinfo("Resume Game", "Game is not paused.")
            return

        # Unpause state
        self.game_paused = False

        # Resume local countdown ticking
        self.game_timers_active = True
        self.tick_game_clock()

        # Resume hardware timer based on current turn
        current_turn = self.var_turn.get()
        if current_turn in ("WHITE", "WHITE (AI)"):
            self.send_cmd('W')
        elif current_turn in ("BLACK (AI)", "BLACK"):
            self.send_cmd('B')

        self.log("[Game] Game resumed. Timers activated.")
        self.var_status.set("Game resumed.")

    def close_game(self):
        # 1. Stop timers
        self.stop_game_timers()

        # 2. Stop camera engine
        self.stop_cv()

        # 3. Reset local board and live log metrics
        self.reset_live_game()

        # 4. Clear hardware task queue
        self.task_queue.queue.clear()

        # 5. Clear camera debug displays and offline states
        for lbl, txt in [
            (getattr(self, "lbl_tracker", None), "Camera Offline"),
            (getattr(self, "lbl_board", None), "Board Offline"),
            (getattr(self, "lbl_debug_mask", None), "Mask Offline"),
            (getattr(self, "lbl_debug_map", None), "Map Offline"),
            (getattr(self, "lbl_tracker_large", None), "Camera Offline"),
            (getattr(self, "lbl_board_large", None), "Board Offline"),
            (getattr(self, "lbl_debug_mask_large", None), "Mask Offline"),
            (getattr(self, "lbl_debug_map_large", None), "Map Offline")
        ]:
            if lbl:
                try: lbl.config(image='', text=txt)
                except Exception: pass

        # 6. Send mechatronic home command 'H' and reset CoreXY position to Home (0,0)
        self.send_cmd('0')
        self.magnet_up = False
        self.send_cmd('H')
        self.var_current_sq.set("HOME (0,0)")
        self.pending_target = None
        self.kill_mode_active.set(False)

        if hasattr(self, "firebase_manager") and self.firebase_manager:
            self.firebase_manager.update_corexy_status(True)
            self.firebase_manager.update_game_ended(False)

        # 7. Reset states
        self.game_active = False
        self.game_paused = False
        self.is_physical_app_mode = False
        self.match_origin = "IDLE"
        self.var_turn.set("WAITING CV")
        self.var_status.set("Game closed. System reset and machine sent home.")

        # 8. Enable settings modifications
        self.set_settings_widgets_state(tk.NORMAL)
        self.update_dashboard_settings_display()

        self.log("[Game] Game closed. System reset and machine sent home.")

    def continue_saved_game_prompt(self):
        if hasattr(self, "game_active") and self.game_active:
            messagebox.showerror("Error", "Cannot continue a previous game while currently playing.")
            return
            
        if not hasattr(self, "cv_bridge") or not getattr(self.cv_bridge, "is_reading", False):
            messagebox.showerror("Error", "Camera/CV engine must be ON to continue a game.")
            return

        from src.software.core.config import SAVED_GAMES_DIR
        if not os.path.exists(SAVED_GAMES_DIR):
            messagebox.showinfo("No Games", "No saved games found.")
            return
            
        files = [f for f in os.listdir(SAVED_GAMES_DIR) if f.endswith(".json")]
        if not files:
            messagebox.showinfo("No Games", "No saved games found.")
            return
            
        # Select game dialog
        dlg = tk.Toplevel(self.root)
        dlg.title("Select Game to Continue")
        dlg.update_idletasks()
        w, h = 400, 300
        x = (dlg.winfo_screenwidth() // 2) - (w // 2)
        y = (dlg.winfo_screenheight() // 2) - (h // 2)
        dlg.geometry(f"{w}x{h}+{x}+{y}")
        dlg.transient(self.root)
        dlg.grab_set()
        
        tk.Label(dlg, text="Select a game to resume:", font=("Segoe UI", 10)).pack(pady=5)
        
        lst = tk.Listbox(dlg, font=("Segoe UI", 10))
        lst.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        for f in sorted(files, reverse=True):
            lst.insert(tk.END, f.replace(".json", ""))
            
        def on_select():
            sel = lst.curselection()
            if not sel: return
            game_name = lst.get(sel[0])
            dlg.destroy()
            self._show_continue_confirmation(game_name)
            
        tk.Button(dlg, text="Select Game", command=on_select, bg="#00838f", fg="white", font=("Segoe UI", 9, "bold")).pack(pady=10)

    def _show_continue_confirmation(self, game_name):
        import os
        import json
        from src.software.core.config import SAVED_GAMES_DIR
        path = os.path.join(SAVED_GAMES_DIR, f"{game_name}.json")
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            messagebox.showerror("Error", f"Failed to read {game_name}: {e}")
            return
            
        required_keys = ["last_square", "last_x", "last_y", "white_time_left", "black_time_left"]
        if not all(k in data for k in required_keys):
            messagebox.showerror("Error", "Cannot continue this game. Missing hardware coordinates or timer data.")
            return
            
        # Reconstruct board state from PGN
        pgn_str = data.get("pgn", "")
        import chess.pgn
        import io
        pgn_io = io.StringIO(pgn_str)
        game_pgn = chess.pgn.read_game(pgn_io)
        
        import chess
        board = chess.Board()
        move_strings = []
        if game_pgn:
            for m in game_pgn.mainline_moves():
                move_strings.append(m.uci())
                board.push(m)
                
        dlg = tk.Toplevel(self.root)
        dlg.title(f"Confirm Board Setup: {game_name}")
        dlg.update_idletasks()
        w, h = 450, 550
        x = (dlg.winfo_screenwidth() // 2) - (w // 2)
        y = (dlg.winfo_screenheight() // 2) - (h // 2)
        dlg.geometry(f"{w}x{h}+{x}+{y}")
        dlg.transient(self.root)
        dlg.grab_set()
        
        tk.Label(dlg, text="Please arrange the pieces EXACTLY as shown below.\n(White is at the bottom)", font=("Segoe UI", 10, "bold")).pack(pady=10)
        
        cvs = tk.Canvas(dlg, width=320, height=320, bg="#f0d9b5")
        cvs.pack()
        
        from PIL import Image, ImageTk
        import os
        dlg.piece_images = {}
        sq_size = 40
        base_dir = os.path.dirname(os.path.abspath(__file__))
        asset_dir = os.path.abspath(os.path.join(base_dir, "..", "assets"))
        white_dir = os.path.join(asset_dir, "white_pieces")
        black_dir = os.path.join(asset_dir, "black_pieces")
        
        file_map = {
            'P': ('WP.png', white_dir), 'N': ('WN.png', white_dir), 'B': ('WB.png', white_dir),
            'R': ('WR.png', white_dir), 'Q': ('WQ.png', white_dir), 'K': ('WK.png', white_dir),
            'p': ('BP.png', black_dir), 'n': ('BN.png', black_dir), 'b': ('BB.png', black_dir),
            'r': ('BR.png', black_dir), 'q': ('BQ.png', black_dir), 'k': ('BK.png', black_dir)
        }
        
        for sym, (fname, folder) in file_map.items():
            img_path = os.path.join(folder, fname)
            if os.path.exists(img_path):
                img = Image.open(img_path).convert("RGBA").resize((sq_size, sq_size), Image.Resampling.LANCZOS)
                dlg.piece_images[sym] = ImageTk.PhotoImage(img)
                
        # Draw board visually
        for r in range(8):
            for c in range(8):
                x1 = c * sq_size
                y1 = r * sq_size
                color = "#b58863" if (r+c)%2 != 0 else "#f0d9b5"
                cvs.create_rectangle(x1, y1, x1+sq_size, y1+sq_size, fill=color, outline="")
                
                # Fen starts from rank 8 (row 0) to rank 1 (row 7)
                rank = 7 - r
                file = c
                sq = chess.square(file, rank)
                piece = board.piece_at(sq)
                if piece:
                    sym = piece.symbol()
                    if sym in dlg.piece_images:
                        cvs.create_image(x1 + sq_size/2, y1 + sq_size/2, image=dlg.piece_images[sym])
                    else:
                        cvs.create_text(x1 + sq_size/2, y1 + sq_size/2, text=sym, font=("Arial", 20))

        def on_confirm():
            dlg.destroy()
            correct_turn = "WHITE" if board.turn else "BLACK (AI)"
            self._execute_continue_game(game_name, data, move_strings, data.get("moves", []), correct_turn)
            
        tk.Button(dlg, text="Confirm: Board is Set -> Start Game", command=on_confirm, bg="#43a047", fg="white", font=("Segoe UI", 10, "bold"), pady=5).pack(pady=20)

    def _execute_continue_game(self, game_name, data, move_strings, analyzed_moves, correct_turn):
        self.log(f"[Game] Continuing saved game: {game_name}")
        
        # Load state
        self.var_turn.set(correct_turn)
        self.white_time_left = data.get("white_time_left", 600)
        self.black_time_left = data.get("black_time_left", 600)
        
        # Set config UI variables
        if "timer_minutes" in data: self.var_game_timer.set(data["timer_minutes"])
        if "increment_seconds" in data: self.var_time_increment.set(data["increment_seconds"])
        if "play_style" in data: self.var_play_style.set(data["play_style"])
        if "white_elo" in data: self.var_elo.set(data["white_elo"])
        
        self.live_game_moves = list(move_strings)
        self.live_analyzed_moves = list(analyzed_moves)
        
        self.prev_turn = self.var_turn.get()
        if hasattr(self, "deep_analysis_page") and hasattr(self.deep_analysis_page, "sync_with_game_state"):
            self.deep_analysis_page.sync_with_game_state()
        elif hasattr(self, "sync_with_game_state"):
            self.sync_with_game_state()
        
        # Set game as active
        self.game_active = True
        self.game_paused = False
        self.var_status.set("Live tracking active (Continued)")
        self.set_settings_widgets_state(tk.DISABLED)
        
        self.update_clock_ui_labels()
        if hasattr(self, "update_dashboard_settings_display"):
            self.update_dashboard_settings_display()
            
        # Send timer and state to Arduino
        inc_sec = int(self.var_time_increment.get() or 0)
        try:
            t_val = int(self.var_game_timer.get())
            self.send_cmd(f"T {t_val} {inc_sec}")
            self.send_cmd(f"S {self.white_time_left} {self.black_time_left}")
            
            # Show message on LCD
            self.send_cmd("M1 Reaching last square")
            self.send_cmd("M2 please wait...    ")
        except Exception: pass
        
        # Sync ELO to CV Engine
        self.send_cv_elo(self.var_elo.get())
        
        # Load base frame into CV Engine
        if hasattr(self, "send_cv_cmd"):
            self.send_cv_cmd(f"load_base {game_name}")
        
        # Move CoreXY to last position
        last_sq = data.get("last_square", "A1")
        if move_strings:
            last_mv_uci = move_strings[-1]
            if len(last_mv_uci) >= 4:
                last_sq = last_mv_uci[2:4].upper()
        self.pending_restore_display = True
        self.pending_start_timers = True
        self.move_to_sq(last_sq)
        
    def _start_timers(self):
        try:
            if self.var_turn.get() == "WHITE":
                self.send_cmd("W")
            elif self.var_turn.get() in ("BLACK", "BLACK (AI)"):
                self.send_cmd("B")
        except Exception: pass
        
        # Start GUI Timer
        if hasattr(self, "timer_after_id") and self.timer_after_id:
            try: self.root.after_cancel(self.timer_after_id)
            except: pass
        self.game_timers_active = True
        self.timer_after_id = self.root.after(1000, self.tick_game_clock)
        
        self.log(f"[Game] Resumed state: Turn={self.var_turn.get()}, W_Time={self.white_time_left}s, B_Time={self.black_time_left}s")
