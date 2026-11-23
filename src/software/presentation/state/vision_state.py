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

class VisionMixin:
    def start_cv(self, show_alert=True, on_started_callback=None):
        # Verify physical Camera 1 connection before spawning CV engine
        if hasattr(self, 'camera_manager') and self.camera_manager and not self.camera_manager.is_camera_connected:
            self.log("❌ Cannot start CV Engine: Camera 1 is not physically connected or detected.")
            if hasattr(self, "lbl_cv_status"):
                self.lbl_cv_status.config(text="● CV Engine: Offline (No Camera 1)", fg="#d32f2f")
            if hasattr(self, "firebase_manager") and self.firebase_manager:
                self.firebase_manager.update_camera_status(False)
            if show_alert:
                try:
                    from tkinter import messagebox
                    messagebox.showerror(
                        "Camera 1 Not Connected",
                        "Camera 1 (overhead board camera) is not connected or could not be detected.\n\n"
                        "Please plug Camera 1 into the USB port and verify it is connected before starting."
                    )
                except Exception:
                    pass
            return

        current_elo = self.var_elo.get() if hasattr(self, 'var_elo') else 10
        def on_cv_ready():
            def _update():
                if hasattr(self, "serial_manager") and self.serial_manager:
                    self.serial_manager.send_cmd('V 1')
                if hasattr(self, "lbl_cv_status"):
                    self.lbl_cv_status.config(text="● CV Engine: Connected", fg="#2e7d32")
                # Sync player color and ELO to CV engine
                player_color = getattr(self, 'var_player_color', None)
                if player_color:
                    self.cv_bridge.send_cv_cmd(f"set_player_color {player_color.get().lower()}")
                if hasattr(self, 'var_elo'):
                    self.cv_bridge.send_cv_cmd(f"set_elo {self.var_elo.get()}")
                if hasattr(self, "firebase_manager") and self.firebase_manager:
                    self.firebase_manager.update_camera_status(True)
                if on_started_callback:
                    try:
                        on_started_callback()
                    except Exception as e:
                        self.log(f"[Warning] on_started_callback error: {e}")
            self.safe_after(_update)

        self.cv_bridge.start_cv(current_elo, on_startup_finished_callback=on_cv_ready)
        if hasattr(self, "lbl_cv_status"):
            self.lbl_cv_status.config(text="● CV Engine: Connecting...", fg="#f57f17")

    def _handle_cv_process_stopped(self):
        """Called whenever the CV Bridge subprocess terminates or crashes."""
        def _update():
            if hasattr(self, "serial_manager") and self.serial_manager:
                self.serial_manager.send_cmd('V 0')
            if hasattr(self, "lbl_cv_status"):
                self.lbl_cv_status.config(text="● CV Engine: Offline", fg="#d32f2f")
            if hasattr(self, "_reset_offline_vision_feed_labels"):
                self._reset_offline_vision_feed_labels()
            if hasattr(self, "firebase_manager") and self.firebase_manager:
                self.firebase_manager.update_camera_status(False)
        self.safe_after(_update)

    def restart_cv(self):
        self.cv_bridge_restart_cv_adapter()
        if hasattr(self, "lbl_cv_status"):
            self.lbl_cv_status.config(text="● CV Engine: Rebooting...", fg="#f57f17")

    def stop_cv(self):
        self.cv_bridge.stop_cv()
        if hasattr(self, "serial_manager"):
            self.serial_manager.send_cmd('V 0')
        if hasattr(self, "lbl_cv_status"):
            self.lbl_cv_status.config(text="● CV Engine: Offline", fg="#d32f2f")
        self._reset_offline_vision_feed_labels()

        if hasattr(self, "firebase_manager") and self.firebase_manager:
            self.firebase_manager.update_camera_status(False)

    def _handle_app_action(self, data):
        """Processes real-time action commands sent from Flutter mobile app."""
        if not data or not isinstance(data, dict):
            return
        action = data.get('action')
        safe_call = getattr(self, 'safe_after', lambda fn, *a: self.root.after(0, fn, *a) if hasattr(self, 'root') else None)
        if action == 'TOGGLE_CAMERA':
            camera_state = data.get('camera')
            self.log(f"📱 Received mobile app action: TOGGLE_CAMERA ({camera_state})")
            if camera_state == 'ON':
                safe_call(self.start_cv)
            elif camera_state == 'OFF':
                safe_call(self.stop_cv)
            else:
                is_reading = getattr(self.cv_bridge, "is_reading", False)
                if is_reading:
                    safe_call(self.stop_cv)
                else:
                    safe_call(self.start_cv)
        elif action in ('START_MATCH', 'START_GAME'):
            self.log("📱 Received mobile app action: START_MATCH -> Syncing settings & Starting Physical Match...")
            def _apply_and_start():
                self.is_physical_app_mode = True
                self.match_origin = "FLUTTER_APP"
                timer_sec = data.get('timer')
                inc_sec = data.get('inc_time')
                is_white = data.get('is_white')
                difficulty = data.get('difficulty')
                elo = data.get('elo')
                play_style = data.get('play_style')
                if timer_sec is not None:
                    timer_min = str(timer_sec // 60)
                    self.var_game_timer.set(timer_min)
                if inc_sec is not None:
                    self.var_time_increment.set(str(inc_sec))
                
                # Resolve AI difficulty level & ELO rating
                if hasattr(self, 'resolve_ai_level_and_elo'):
                    final_elo, preset_name = self.resolve_ai_level_and_elo(difficulty=difficulty, elo=elo)
                    self.var_elo.set(final_elo)
                    self.var_level_name.set(preset_name)
                    if hasattr(self, 'send_cv_elo'):
                        self.send_cv_elo(final_elo)
                elif elo is not None:
                    self.var_elo.set(elo)
                    preset_name = getattr(self, 'LEVEL_REVERSE', {}).get(elo, f"Lvl {difficulty}: ({elo} ELO)")
                    self.var_level_name.set(preset_name)

                if is_white is not None:
                    self.var_player_color.set("White" if is_white else "Black")
                if play_style is not None:
                    self.var_play_style.set(play_style)

                if hasattr(self, 'update_digital_timer_display'):
                    self.update_digital_timer_display()
                if hasattr(self, 'update_digital_increment_display'):
                    self.update_digital_increment_display()
                if hasattr(self, 'persist_synced_game_settings'):
                    self.persist_synced_game_settings()
                if hasattr(self, 'update_dashboard_settings_display'):
                    self.update_dashboard_settings_display()

                self.start_game(prompt_settings=False)

            safe_call(_apply_and_start)
        elif action in ('STOP_MATCH', 'STOP_GAME', 'SURRENDER'):
            self.log("📱 Received mobile app action: STOP_MATCH -> Closing game & homing machine...")
            safe_call(self.close_game)

        if hasattr(self, '_firebase_test_view_on_action'):
            try:
                self._firebase_test_view_on_action(data)
            except Exception:
                pass

    def _reset_offline_vision_feed_labels(self):
        """Safely resets vision feed labels to offline state on the main GUI thread."""
        for lbl, txt in [
            (getattr(self, "lbl_tracker", None), "Camera Offline"),
            (getattr(self, "lbl_board", None), "Board Offline"),
            (getattr(self, "lbl_debug_mask", None), "Mask Offline"),
            (getattr(self, "lbl_debug_map", None), "Map Offline")
        ]:
            if lbl:
                try:
                    lbl.config(image="", text=txt, width=30, height=11)
                    lbl.image = None
                except Exception:
                    pass

        for lbl, txt in [
            (getattr(self, "lbl_tracker_large", None), "Camera Offline"),
            (getattr(self, "lbl_board_large", None), "Board Offline"),
            (getattr(self, "lbl_debug_mask_large", None), "Mask Offline"),
            (getattr(self, "lbl_debug_map_large", None), "Map Offline")
        ]:
            if lbl:
                try:
                    lbl.config(image="", text=txt, width="", height="")
                    lbl.image = None
                except Exception:
                    pass

    def send_cv_cmd(self, cmd):
        self.cv_bridge.send_cv_cmd(cmd)

    def recapture_base_frame(self):
        """
        Unified handler for baseline reference frame recapture.
        Invoked from:
        1. '📷 RECAPTURE BASE FRAME' button on Live Dashboard
        2. Arduino Hardware Button 2 (pin A2)
        3. Automated game setup / state reset
        """
        self.log("📷 [Recapture] Recapture base frame requested.")

        # Check if CV Bridge is alive
        cv_alive = (
            self.cv_bridge
            and getattr(self.cv_bridge, "is_reading", False)
            and self.cv_bridge.cv_process is not None
            and self.cv_bridge.cv_process.poll() is None
        )

        if cv_alive:
            # CV process is running — send capture_base directly via stdin
            try:
                self.cv_bridge.cv_process.stdin.write("capture_base\n")
                self.cv_bridge.cv_process.stdin.flush()
                self.log("📷 [Recapture] 'capture_base' command written to CV Engine stdin.")
            except Exception as e:
                self.log(f"❌ [Recapture] Failed to write 'capture_base' to CV stdin: {e}")
                return
            # Update UI immediately to show we're waiting for confirmation
            def _ui_waiting():
                self.var_status.set("📷 Recapturing baseline...")
            self.safe_after(_ui_waiting)
        else:
            # CV is offline — start it, then send capture_base once ready
            self.log("📷 [Recapture] CV Engine is offline. Starting CV Engine first...")
            def _on_started():
                try:
                    self.cv_bridge.cv_process.stdin.write("capture_base\n")
                    self.cv_bridge.cv_process.stdin.flush()
                    self.log("📷 [Recapture] 'capture_base' sent after CV Engine startup.")
                except Exception as e:
                    self.log(f"❌ [Recapture] Failed to send 'capture_base' after startup: {e}")
            self.start_cv(show_alert=True, on_started_callback=_on_started)

    def highlight_sq(self, sq):
        self.var_current_sq.set(sq)
        for s, b in self.board_buttons.items():
            f_i = "ABCDEFGH".index(s[0])
            r_i = 8 - int(s[1])
            orig = "#f0d9b5" if (r_i + f_i) % 2 == 0 else "#b58863"
            b.config(bg=orig)
        if sq in self.board_buttons:
            self.board_buttons[sq].config(bg="#00e676")

    def scan_available_cameras(self):
        if self.is_scanning_cameras:
            return
        self.is_scanning_cameras = True
        threading.Thread(target=self._scan_cameras_worker, daemon=True).start()

    def _scan_cameras_worker(self):
        import cv2
        from src.software.infrastructure.vision.camera_manager import CAMERA_ACCESS_LOCK
        available = []
        for i in [1, 0]:
            try:
                with CAMERA_ACCESS_LOCK:
                    cap = cv2.VideoCapture(i, cv2.CAP_DSHOW)
                    if not cap.isOpened():
                        cap.release()
                        cap = cv2.VideoCapture(i)
                    if cap.isOpened():
                        available.append(f"Camera {i}")
                        cap.release()
            except Exception:
                pass

        if not available:
            available = ["Camera 1", "Camera 0"]

        self.cached_cameras = available
        self.is_scanning_cameras = False

        # Dispatch notification to calibration screen on GUI thread safely
        if hasattr(self, 'safe_after'):
            self.safe_after(self._notify_calibration_cameras_ready)
        else:
            try:
                self.root.after(0, self._notify_calibration_cameras_ready)
            except Exception:
                pass

    def _notify_calibration_cameras_ready(self):
        if hasattr(self, "calibration_page") and self.calibration_page is not None:
            try:
                self.calibration_page.update_camera_list(self.cached_cameras)
            except Exception:
                pass

    # ==========================================
    # LIVE REAL-TIME ANALYSIS ENGINE
    # ==========================================
    def cv_bridge_restart_cv_adapter(self):
        self.log("🔄 Initiating Full System Reset...")
        self.cv_bridge.stop_cv()

        # Reset Hardware (Magnet Down & Home)
        self.serial_manager.send_cmd('0')
        self.magnet_up = False
        self.serial_manager.send_cmd('H')
        self.serial_manager.send_cmd('R') # Reset the chess timer on LCD

        # Clear Task Queue
        with self.task_queue.mutex:
            self.task_queue.queue.clear()
        self.pending_target = None
        self.kill_mode_active.set(False)
        self.var_current_sq.set("HOME (0,0)")

        if hasattr(self, "firebase_manager") and self.firebase_manager:
            self.firebase_manager.update_corexy_status(True)
            self.firebase_manager.update_game_ended(False)

        # Reset UI & Game Variables
        self.var_turn.set("WAITING CV")
        self.var_status.set("Start CV Bridge to begin...")
        self.var_source.set("B1")
        self.var_target.set("C3")
        self.var_piece_type.set("Standard")
        self.var_held_piece.set("Nothing")
        self.var_current_sq.set("None")
        self.btn_execute.config(state=tk.DISABLED)

        # Reset Digital Board Colors
        for s, b in self.board_buttons.items():
            f_i = "ABCDEFGH".index(s[0])
            r_i = 8 - int(s[1])
            orig = "#f0d9b5" if (r_i + f_i) % 2 == 0 else "#b58863"
            b.config(bg=orig)

        self.log("Restarting CV Bridge in 1s...")
        self.root.after(1000, self.start_cv)

    def _handle_cv_video_feed(self, feed_type, b64_str):
        if feed_type == "tracker":
            self._update_video_feed_label(self.lbl_tracker, getattr(self, "lbl_tracker_large", None), b64_str)
        elif feed_type == "board":
            self._update_video_feed_label(self.lbl_board, getattr(self, "lbl_board_large", None), b64_str)
        elif feed_type == "mask":
            self._update_video_feed_label(self.lbl_debug_mask, getattr(self, "lbl_debug_mask_large", None), b64_str)
        elif feed_type == "map":
            self._update_video_feed_label(self.lbl_debug_map, getattr(self, "lbl_debug_map_large", None), b64_str)

    def _update_video_feed_label(self, label_small, label_large, b64_str):
        if not hasattr(self, "cv_bridge") or not getattr(self.cv_bridge, "is_reading", False):
            return
        import base64
        import io
        from PIL import Image, ImageTk
        try:
            img_data = base64.b64decode(b64_str)
            img = Image.open(io.BytesIO(img_data))

            # Update small thumbnail on dashboard
            img_small = img.copy()
            img_small.thumbnail((260, 260), Image.Resampling.LANCZOS)
            photo_small = ImageTk.PhotoImage(img_small)
            self.root.after(0, self._set_image, label_small, photo_small)

            # Update larger thumbnail on dedicated feeds tab
            if label_large:
                img_large = img.copy()
                img_large.thumbnail((450, 450), Image.Resampling.LANCZOS)
                photo_large = ImageTk.PhotoImage(img_large)
                self.root.after(0, self._set_image, label_large, photo_large)
        except Exception:
            pass

    def _handle_cv_event_received(self, event, data):
        def _ui():
            if event == "base_captured":
                self.log("✅ [CV Engine] Base reference frame successfully captured and synced.")
                if hasattr(self, 'lbl_cv_status'):
                    self.lbl_cv_status.config(text="● CV Engine: Live & Tracking", fg="#2e7d32")
                if hasattr(self, "serial_manager") and self.serial_manager:
                    self.serial_manager.send_cmd('V 1')
                player_color = getattr(self, 'var_player_color', None)
                playing_as_black = player_color and player_color.get() == "Black"
                
                # Only trigger game start turn setup on initial base capture of the game
                if not getattr(self, '_base_game_started', False):
                    self._base_game_started = True
                    if playing_as_black:
                        # START of game, Player is Black: AI (White) moves first
                        self.var_status.set("AI is thinking (White)...")
                        self.var_turn.set("WHITE (AI)")
                        if hasattr(self, 'btn_execute'):
                            self.btn_execute.config(state=tk.DISABLED)
                        if hasattr(self, "serial_manager") and self.serial_manager:
                            self.serial_manager.send_cmd('W')  # Start white timer (AI's turn)
                        self.send_cv_cmd('ai_move_first')
                    else:
                        # Player is White: Human moves first (default)
                        self.var_status.set("System ready. Make move!")
                        if hasattr(self, 'btn_execute'):
                            self.btn_execute.config(state=tk.NORMAL)
                        self.var_turn.set("WHITE")
                        if hasattr(self, "serial_manager") and self.serial_manager:
                            self.serial_manager.send_cmd('W')  # Start white timer
                else:
                    # Subsequent base captures during live play: just re-enable execute button
                    if hasattr(self, 'btn_execute'):
                        self.btn_execute.config(state=tk.NORMAL)
                    human_color_str = "Black" if playing_as_black else "White"
                    self.var_status.set(f"System ready. Make move ({human_color_str})!")

            elif event == "move_valid":
                player_color = getattr(self, 'var_player_color', None)
                playing_as_black = player_color and player_color.get() == "Black"
                move_str = data.get("move")
                if playing_as_black:
                    # Human played Black, now AI (White) thinks
                    self.var_turn.set("WHITE (AI)")
                    self.var_status.set("AI is thinking (White)...")
                    if hasattr(self, "serial_manager") and self.serial_manager:
                        self.serial_manager.send_cmd('W')  # AI's White timer
                    self.register_live_move(move_str, "Black")
                else:
                    # Human played White, now AI (Black) thinks
                    self.var_turn.set("BLACK (AI)")
                    self.var_status.set("AI is thinking...")
                    if hasattr(self, "serial_manager") and self.serial_manager:
                        self.serial_manager.send_cmd('B')  # AI's Black timer
                    self.register_live_move(move_str, "White")

            elif event == "move_invalid":
                reason = data.get("reason", "Unknown error")
                self.var_status.set(f"Invalid: {reason}")
                if hasattr(self, 'btn_execute'):
                    self.btn_execute.config(state=tk.NORMAL)
                if hasattr(self, "serial_manager") and self.serial_manager:
                    self.serial_manager.send_cmd(f"E:{reason}") # Print error on LCD
                    self.serial_manager.send_cmd('P') # Pause turn timer
        self.safe_after(_ui)

    def _handle_cv_action_received(self, action, data):
        if action == "kill":
            tgt = data.get("target_pos").upper()
            self.log(f"🧠 AI ALGORITHM: Queueing KILL sequence for {tgt}...")
            self.task_queue.put({'type': 'kill', 'sq': tgt})

        elif action == "move":
            src = data.get("current_pos").upper()
            tgt = data.get("target_pos").upper()
            piece_name = data.get("piece_name", "").lower()
            p_type = "Knight" if piece_name == "knight" else "Standard"

            is_castling = False
            side = None
            color = None

            if piece_name == "king":
                if src == "E8" and tgt == "G8":
                    is_castling = True
                    side = "king"
                    color = "black"
                elif src == "E8" and tgt == "C8":
                    is_castling = True
                    side = "queen"
                    color = "black"
                elif src == "E1" and tgt == "G1":
                    is_castling = True
                    side = "king"
                    color = "white"
                elif src == "E1" and tgt == "C1":
                    is_castling = True
                    side = "queen"
                    color = "white"

            move_str = src.lower() + tgt.lower()
            player_color = getattr(self, 'var_player_color', None)
            playing_as_black = player_color and player_color.get() == "Black"
            self._pending_ai_move_str = move_str
            self._pending_ai_player_color = "White" if playing_as_black else "Black"
            if is_castling:
                self.log(f"🧠 AI ALGORITHM: Queueing CASTLING sequence ({side}-side, {color})...")
                self.task_queue.put({'type': 'castling', 'side': side, 'color': color})
            else:
                self.log(f"🧠 AI ALGORITHM: Queueing MOVE sequence ({src} -> {tgt})...")
                self.var_source.set(src)
                self.var_target.set(tgt)
                self.var_piece_type.set(p_type)
                self.task_queue.put({'type': 'move', 'src': src, 'tgt': tgt, 'piece': p_type})


