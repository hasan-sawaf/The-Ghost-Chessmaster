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
import chess
import json

from src.software.infrastructure.hardware.serial_adapter import SerialManager
from src.software.infrastructure.hardware.core_xy_translator import TaskExecutor
from src.software.infrastructure.vision.camera_streamer import CVBridge
from src.software.core.constants import DEFAULT_COM_PORT, BAUD_RATE
from src.software.infrastructure.network.network_manager import NetworkManager
from src.software.infrastructure.network.board_online_manager import BoardOnlineManager
from src.software.infrastructure.vision.camera_manager import CameraManager
from src.software.presentation.state.hardware_state import HardwareMixin
from src.software.presentation.state.vision_state import VisionMixin
from src.software.presentation.state.game_state import GameMixin
from src.software.presentation.state.analysis_state import AnalysisMixin
from src.software.presentation.state.navigation_state import NavigationMixin
from src.software.presentation.state.settings_state import SettingsMixin
from src.software.presentation.state.layout_state import LayoutMixin
from src.software.presentation.state.utils_state import UtilsMixin

from src.software.presentation.views.terminal_view import build_ui as build_terminal_ui
from src.software.presentation.views.manual_control_view import build_ui as build_manual_ctrl_ui
from src.software.presentation.views.settings_view import build_ui as build_settings_ui
from src.software.presentation.views.vision_feed_view import build_ui as build_vision_feeds_ui
from src.software.presentation.views.calibration_view import CalibrationPage
from src.software.presentation.views.analysis_view import AnalysisApp
from src.software.application.use_cases.analyze_match import analyze_game_moves
from src.software.domain.rules.scoring import NormalizedScore, compute_cpl
from src.software.domain.rules.classification import is_sacrifice, is_book_move, DEFAULT_THRESHOLDS


class SaveGameConfigDialog(simpledialog.Dialog):
    def __init__(self, parent, current_elo, player_color="White", last_config=None, title=None):
        self.current_elo = current_elo
        self.player_color = player_color
        self.last_config = last_config or {}
        super().__init__(parent, title=title)

    def body(self, master):
        self.result = None

        self.var_auto_save = tk.BooleanVar(value=self.last_config.get("auto_save", True))
        self.chk_auto = tk.Checkbutton(master, text="Save game while playing", variable=self.var_auto_save, font=("Segoe UI", 10, "bold"), command=self.toggle_fields)
        self.chk_auto.pack(anchor="w", pady=(10, 5), padx=10)

        self.fields_frame = tk.Frame(master)
        self.fields_frame.pack(fill=tk.X, padx=10, pady=5)

        tk.Label(self.fields_frame, text="Saved Game Name:", font=("Segoe UI", 9)).grid(row=0, column=0, sticky="w", pady=2)
        self.ent_name = tk.Entry(self.fields_frame, width=25)
        self.ent_name.insert(0, f"Game_{int(time.time())}")
        self.ent_name.grid(row=0, column=1, sticky="w", pady=2)

        tk.Label(self.fields_frame, text="Event:", font=("Segoe UI", 9)).grid(row=1, column=0, sticky="w", pady=2)
        self.ent_event = tk.Entry(self.fields_frame, width=25)
        self.ent_event.insert(0, self.last_config.get("event", "CoreXY Robotic Chess Match"))
        self.ent_event.grid(row=1, column=1, sticky="w", pady=2)

        tk.Label(self.fields_frame, text="Site:", font=("Segoe UI", 9)).grid(row=2, column=0, sticky="w", pady=2)
        self.ent_site = tk.Entry(self.fields_frame, width=25)
        self.ent_site.insert(0, self.last_config.get("site", "?"))
        self.ent_site.grid(row=2, column=1, sticky="w", pady=2)

        tk.Label(self.fields_frame, text="Round:", font=("Segoe UI", 9)).grid(row=3, column=0, sticky="w", pady=2)
        self.ent_round = tk.Entry(self.fields_frame, width=25)
        self.ent_round.insert(0, self.last_config.get("round", "1"))
        self.ent_round.grid(row=3, column=1, sticky="w", pady=2)

        tk.Label(self.fields_frame, text="White:", font=("Segoe UI", 9)).grid(row=4, column=0, sticky="w", pady=2)
        self.ent_white = tk.Entry(self.fields_frame, width=25)
        self.ent_white.insert(0, self.last_config.get("white", "Human"))
        self.ent_white.grid(row=4, column=1, sticky="w", pady=2)

        import datetime
        ai_label = f"Stockfish (ELO {self.current_elo})"
        if self.player_color == "White":
            tk.Label(self.fields_frame, text="Black (AI):", font=("Segoe UI", 9)).grid(row=5, column=0, sticky="w", pady=2)
            tk.Label(self.fields_frame, text=ai_label, font=("Segoe UI", 9, "italic")).grid(row=5, column=1, sticky="w", pady=2)
        else:
            tk.Label(self.fields_frame, text="White (AI):", font=("Segoe UI", 9)).grid(row=5, column=0, sticky="w", pady=2)
            tk.Label(self.fields_frame, text=ai_label, font=("Segoe UI", 9, "italic")).grid(row=5, column=1, sticky="w", pady=2)

        tk.Label(self.fields_frame, text="Date (Static):", font=("Segoe UI", 9)).grid(row=6, column=0, sticky="w", pady=2)
        tk.Label(self.fields_frame, text=datetime.date.today().strftime("%Y.%m.%d"), font=("Segoe UI", 9, "italic")).grid(row=6, column=1, sticky="w", pady=2)

        self.toggle_fields()
        return self.ent_name

    def toggle_fields(self):
        state = tk.NORMAL if self.var_auto_save.get() else tk.DISABLED
        for child in self.fields_frame.winfo_children():
            if isinstance(child, tk.Entry):
                child.config(state=state)

    def buttonbox(self):
        box = tk.Frame(self)
        btn_save = tk.Button(box, text="💾 Save Next Played Game", font=("Segoe UI", 9, "bold"),
                             bg="#2e7d32", fg="white", command=self.ok)
        btn_save.pack(side=tk.LEFT, padx=6, pady=8)
        btn_cancel = tk.Button(box, text="Cancel", font=("Segoe UI", 9), command=self.cancel)
        btn_cancel.pack(side=tk.LEFT, padx=6, pady=8)
        self.bind("<Return>", self.ok)
        self.bind("<Escape>", self.cancel)
        box.pack()

    def ok(self, event=None):
        if self.var_auto_save.get():
            name = self.ent_name.get().strip()
            if not name:
                from tkinter import messagebox
                messagebox.showerror("Error", "Please enter a saved game name before clicking the save button.")
                return
            if self.player_color == "White":
                white_name = self.ent_white.get()
                black_name = f"Stockfish (ELO {self.current_elo})"
            else:
                white_name = f"Stockfish (ELO {self.current_elo})"
                black_name = self.ent_white.get()
            self.result = {
                "auto_save": True,
                "name": name,
                "event": self.ent_event.get(),
                "site": self.ent_site.get(),
                "round": self.ent_round.get(),
                "white": white_name,
                "black": black_name,
            }
        else:
            self.result = {"auto_save": False}
        self.destroy()

    def apply(self):
        self.result = self.entry.get()

from src.software.presentation.views.terminal_view import build_ui as build_terminal_ui
from src.software.presentation.views.manual_control_view import build_ui as build_manual_ctrl_ui
from src.software.presentation.views.settings_view import build_ui as build_settings_ui
from src.software.presentation.views.vision_feed_view import build_ui as build_vision_feeds_ui


class SplashScreen(tk.Toplevel):
    def __init__(self, parent):
        super().__init__(parent)
        self.overrideredirect(True)
        self.configure(bg="#1a1a2e")
        
        # Center the splash screen
        width = 500
        height = 300
        x = (self.winfo_screenwidth() // 2) - (width // 2)
        y = (self.winfo_screenheight() // 2) - (height // 2)
        self.geometry(f"{width}x{height}+{x}+{y}")
        
        # App title
        tk.Label(self, text="GhostChess Master", font=("Segoe UI", 24, "bold"), 
                 bg="#1a1a2e", fg="white").pack(pady=(60, 5))
        # Subtitle
        tk.Label(self, text="CoreXY Chess Controller", font=("Segoe UI", 12), 
                 bg="#1a1a2e", fg="#a0a0a0").pack(pady=(0, 40))
        
        # Progress bar
        style = ttk.Style(self)
        if "clam" in style.theme_names():
            style.theme_use('clam')
        style.configure("Splash.Horizontal.TProgressbar", background="#4a90e2", 
                        troughcolor="#0f0f1c", bordercolor="#1a1a2e", lightcolor="#4a90e2", darkcolor="#4a90e2")
        self.progress = ttk.Progressbar(self, orient=tk.HORIZONTAL, length=400, 
                                        mode='determinate', style="Splash.Horizontal.TProgressbar")
        self.progress.pack(pady=(0, 15))
        
        # Status label
        self.lbl_status = tk.Label(self, text="Starting...", font=("Segoe UI", 9), 
                                   bg="#1a1a2e", fg="#cccccc")
        self.lbl_status.pack()
        
        self.update()

    def update_status(self, text, progress_float):
        try:
            self.lbl_status.config(text=text)
            self.progress['value'] = progress_float * 100
            self.update()
        except Exception:
            pass

class CoreXY_GUI(HardwareMixin, VisionMixin, GameMixin, AnalysisMixin, NavigationMixin, SettingsMixin, LayoutMixin, UtilsMixin):
    def __init__(self, root, progress_callback=None):
        self.root = root
        self.root.title("CoreXY Chess Controller - Vision & Control Dashboard")
        self.root.configure(bg="#eef2f5")
        
        if progress_callback: progress_callback("Loading modules...", 0.05)

        # Set window icon (loads both PNG via iconphoto and ICO via iconbitmap for full Windows titlebar & taskbar icon parity)
        try:
            asset_root = self.get_asset_root_dir()
            png_paths = [
                os.path.join(asset_root, "src", "ghostchessmaster", "assets", "logo.png"),
                os.path.join(asset_root, "src", "software", "presentation", "assets", "logo.png"),
            ]
            ico_paths = [
                os.path.join(asset_root, "src", "software", "presentation", "assets", "logo.ico"),
                os.path.join(asset_root, "assets", "logo.ico"),
            ]

            for p in png_paths:
                if os.path.exists(p):
                    try:
                        img = Image.open(p)
                        photo = ImageTk.PhotoImage(img)
                        self.root.iconphoto(True, photo)
                        self._app_icon_ref = photo
                        break
                    except Exception:
                        pass

            for p in ico_paths:
                if os.path.exists(p):
                    try:
                        self.root.iconbitmap(default=p)
                        self.root.iconbitmap(p)
                        break
                    except Exception:
                        pass
        except Exception as e:
            print(f"[WARNING] Could not set window icon in init: {e}")

        self.running = True
        self.board_buttons = {}
        self.pending_target = None
        self.magnet_up = False

        if progress_callback: progress_callback("Setting up state variables...", 0.15)
        # --- STATE VARIABLES ---
        self.var_x = tk.StringVar(value="0.00")
        self.var_y = tk.StringVar(value="0.00")
        self.var_target_gcode_x = tk.StringVar(value="0.0")
        self.var_target_gcode_y = tk.StringVar(value="0.0")
        self.var_magnet_up_angle = tk.StringVar(value="90")
        self.var_current_sq = tk.StringVar(value="None")
        self.var_held_piece = tk.StringVar(value="Nothing")
        self.kill_mode_active = tk.BooleanVar(value=False)
        self.var_elo = tk.IntVar(value=1500) # Default Lvl 7 (1500 ELO)
        self.var_level_name = tk.StringVar(value="Lvl 7: Class B Player (1500 ELO)")

        # --- GAME SETTINGS VARIABLES ---
        self.var_game_timer = tk.StringVar(value="10")
        self.var_time_increment = tk.StringVar(value="2")
        self.var_play_style = tk.StringVar(value="Balanced")
        self.var_pieces_theme = tk.StringVar(value="Standard")
        self.var_audio_enabled = tk.BooleanVar(value=True)
        self.var_player_color = tk.StringVar(value="White")

        self.white_time_left = 600
        self.black_time_left = 600

        # Traces to auto-update digital displays on Settings and Dashboard
        self.var_game_timer.trace_add("write", self.update_digital_timer_display)
        self.var_time_increment.trace_add("write", self.update_digital_increment_display)

        self.LEVEL_PRESETS = {
            "Lvl 0: Beginner (800 ELO)": 800,
            "Lvl 1: Novice (900 ELO)": 900,
            "Lvl 2: Amateur (1000 ELO)": 1000,
            "Lvl 3: Amateur (1100 ELO)": 1100,
            "Lvl 4: Casual Player (1200 ELO)": 1200,
            "Lvl 5: Club Player (1300 ELO)": 1300,
            "Lvl 6: Club Player (1400 ELO)": 1400,
            "Lvl 7: Class B Player (1500 ELO)": 1500,
            "Lvl 8: Class A Player (1600 ELO)": 1600,
            "Lvl 9: Expert (1700 ELO)": 1700,
            "Lvl 10: Expert (1800 ELO)": 1800,
            "Lvl 11: Candidate Master (1900 ELO)": 1900,
            "Lvl 12: Candidate Master (2000 ELO)": 2000,
            "Lvl 13: FIDE CM (2100 ELO)": 2100,
            "Lvl 14: FIDE Master (2200 ELO)": 2200,
            "Lvl 15: National Master (2300 ELO)": 2300,
            "Lvl 16: International Master (2400 ELO)": 2400,
            "Lvl 17: Grandmaster (2500 ELO)": 2500,
            "Lvl 18: Grandmaster (2600 ELO)": 2600,
            "Lvl 19: Super GM (2700 ELO)": 2700,
            "Lvl 20: Engine Max (2800+ ELO)": 2800
        }
        self.LEVEL_REVERSE = {v: k for k, v in self.LEVEL_PRESETS.items()}

        # --- Game Flow Variables ---
        self.var_turn = tk.StringVar(value="WAITING CV")
        self.var_status = tk.StringVar(value="Start CV Bridge to begin...")
        self.is_physical_app_mode = False
        self.match_origin = "IDLE"

        # --- Live Analysis Variables ---
        self.live_game_moves = []
        self.live_analyzed_moves = []
        self.target_pct_live = 0.5
        self.current_pct_live = 0.5

        # --- Camera Devices Cache ---
        self.cached_cameras = []
        self.is_scanning_cameras = False

        # Load Stockfish engine path
        root_dir = self.get_asset_root_dir()
        self.engine_path = os.path.join(root_dir, "src", "software", "infrastructure", "ai", "stockfish-windows-x86-64-avx2.exe")

        self.chess_squares = [f"{f}{r}" for r in range(1, 9) for f in "ABCDEFGH"]
        self.var_source = tk.StringVar(value="B1")
        self.var_target = tk.StringVar(value="C3")
        self.var_piece_type = tk.StringVar(value="Standard")
        self.wait_for_idle = threading.Event()

        # HARDWARE TASK QUEUE
        self.task_queue = queue.Queue()

        # Instantiate Core Managers (Layered Architecture - Decoupled)
        self.serial_manager = SerialManager()
        self.cv_bridge = CVBridge()

        # Board Online Status & Camera Managers
        self.network_manager = NetworkManager()
        self.camera_manager = CameraManager(cv_bridge=self.cv_bridge, gui=self)
        self.task_executor = TaskExecutor(
            task_queue=self.task_queue,
            wait_for_idle=self.wait_for_idle,
            log_callback=self.log,
            move_to_sq_callback=self.move_to_sq,
            send_serial_cmd_callback=self.serial_manager.send_cmd,
            send_cv_cmd_callback=self.cv_bridge.send_cv_cmd,
            get_running_status_callback=lambda: self.running,
            on_ai_move_complete_callback=self.on_ai_move_completed
        )

        # Setup Serial Manager Callbacks
        self.serial_manager.on_log_message = self.log
        self.serial_manager.on_connection_updated = self.update_serial_status
        self.serial_manager.on_telemetry_received = lambda x, y: self.root.after(0, lambda: (self.var_x.set(x), self.var_y.set(y)))
        self.serial_manager.on_status_changed = self._handle_serial_status_changed
        self.serial_manager.on_button_pressed = self._handle_serial_button_pressed

        # Setup CV Bridge Callbacks
        self.cv_bridge.on_log_message = self.log
        self.cv_bridge.on_video_feed = self._handle_cv_video_feed
        self.cv_bridge.on_event_received = self._handle_cv_event_received
        self.cv_bridge.on_action_received = self._handle_cv_action_received
        self.cv_bridge.on_process_stopped = self._handle_cv_process_stopped

        # Start background threads
        threading.Thread(target=self.task_executor.run_worker, daemon=True).start()

        if progress_callback: progress_callback("Loading quality icons...", 0.4)
        self.load_quality_icons()
        self.setup_styles()
        if progress_callback: progress_callback("Building user interface...", 0.55)
        self.build_ui()

        if progress_callback: progress_callback("Connecting to Firebase (background)...", 0.8)
        
        self.firebase_manager = None
        def _init_firebase_async():
            try:
                from src.software.infrastructure.firebase.firebase_manager import FirebaseManager
                fm = FirebaseManager()
                if fm.connected:
                    self.firebase_manager = fm
                    if hasattr(self, 'board_online_manager'):
                        self.board_online_manager._firebase_manager = fm

                    # Start SSE listeners in background thread (never blocks GUI main thread)
                    fm.listen_to_app_actions(self._handle_app_action)
                    fm.listen_to_user_connection(self._handle_user_connection_changed)
                    fm.listen_to_live_session(self._handle_live_session_changed)

                    self.log(f"📶 Firebase Manager ready for {fm.board_name}.")
                    if hasattr(self, '_firebase_test_view_on_connected'):
                        self.safe_after(lambda: self._firebase_test_view_on_connected(fm))
            except Exception as e:
                self.log(f"⚠️ Could not start Firebase: {e}")

        threading.Thread(target=_init_firebase_async, daemon=True).start()

        # Connect Serial asynchronously to prevent startup lag
        threading.Thread(target=self._init_serial_async, daemon=True).start()

        if progress_callback: progress_callback("Starting network & hardware monitors...", 0.9)
        # Start Board Online Status Monitoring (WiFi + Arduino COM7)
        self.board_online_manager = BoardOnlineManager(
            network_manager=self.network_manager,
            serial_manager=self.serial_manager,
            camera_manager=self.camera_manager,
            firebase_manager=lambda: self.firebase_manager,
            gui=self
        )
        self.network_manager.on_status_changed = self._on_network_status_changed
        self.camera_manager.on_status_changed = self._on_camera_status_changed
        self.board_online_manager.on_status_changed = self._on_board_online_status_changed
        self.network_manager.start()
        self.camera_manager.start()
        self.board_online_manager.start()

        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        if progress_callback: progress_callback("Ready!", 1.0)

    def safe_after(self, func, *args):
        """Schedules a function to run on the GUI main thread safely, handling pre-mainloop startup calls."""
        if not hasattr(self, 'root') or not self.root:
            return
        try:
            self.root.after(0, func, *args)
        except Exception:
            try:
                func(*args)
            except Exception:
                pass

    def resolve_ai_level_and_elo(self, difficulty=None, elo=None):
        """Consistently resolves (elo, preset_name) given difficulty (0..20) or elo (800..2800)."""
        diff_map = {
            0: 800, 1: 900, 2: 1000, 3: 1100, 4: 1200, 5: 1300,
            6: 1400, 7: 1500, 8: 1600, 9: 1700, 10: 1800,
            11: 1900, 12: 2000, 13: 2100, 14: 2200, 15: 2300,
            16: 2400, 17: 2500, 18: 2600, 19: 2700, 20: 2800
        }
        final_elo = None
        if elo is not None:
            try:
                final_elo = int(elo)
            except Exception:
                pass
        if final_elo is None and difficulty is not None:
            try:
                final_elo = diff_map.get(int(difficulty), 1500)
            except Exception:
                final_elo = 1500

        if final_elo is None:
            final_elo = 1500

        preset_name = self.LEVEL_REVERSE.get(final_elo)
        if not preset_name and difficulty is not None:
            try:
                diff_int = int(difficulty)
                for k in self.LEVEL_PRESETS.keys():
                    if k.startswith(f"Lvl {diff_int}:"):
                        preset_name = k
                        break
            except Exception:
                pass

        if not preset_name:
            preset_name = f"Lvl {difficulty if difficulty is not None else 7}: ({final_elo} ELO)"

        return final_elo, preset_name

    def _handle_user_connection_changed(self, data):
        def _update():
            if data and isinstance(data, dict):
                status = str(data.get('status', 'disconnected')).lower()
                user_id = data.get('connected_user_id') or data.get('user_id') or data.get('userId')
                email = data.get('connected_user_email') or data.get('user_email') or user_id
                if status == 'connected' and bool(user_id):
                    self.log(f"📶 🟢 Mobile App User Connected: {email}")
                    if self.firebase_manager:
                        is_home = (self.var_current_sq.get() == "HOME (0,0)" or not getattr(self, 'game_active', False))
                        self.firebase_manager.update_corexy_status(is_home)
                else:
                    self.is_physical_app_mode = False
                    self.log("📶 🔴 Board Disconnected / User Unlinked. Automatically stopping camera feed...")
                    self.stop_cv()
                    if self.firebase_manager:
                        self.firebase_manager.update_camera_status(False)
            else:
                self.is_physical_app_mode = False
                self.log("📶 🔴 Board Disconnected. Automatically stopping camera feed...")
                self.stop_cv()
                if self.firebase_manager:
                    self.firebase_manager.update_camera_status(False)

            self.update_dashboard_settings_display()
            if hasattr(self, 'refresh_settings_lock_state'):
                self.refresh_settings_lock_state()

            if hasattr(self, '_firebase_test_view_on_user_conn'):
                try:
                    self._firebase_test_view_on_user_conn(data)
                except Exception:
                    pass
        self.safe_after(_update)

    def _handle_live_session_changed(self, data):
        def _update():
            if data and isinstance(data, dict):
                timer_sec = data.get('timer')
                if timer_sec is None:
                    timer_sec = data.get('timer_seconds')

                inc_sec = data.get('inc_time')
                if inc_sec is None:
                    inc_sec = data.get('incTime') or data.get('increment_seconds')

                is_white = data.get('is_white')
                if is_white is None:
                    is_white = data.get('isWhite')

                difficulty = data.get('difficulty')
                elo = data.get('elo')
                play_style = data.get('play_style') or data.get('playStyle')

                # Apply timer & increment
                if timer_sec is not None:
                    timer_min = str(int(timer_sec) // 60)
                    self.var_game_timer.set(timer_min)
                if inc_sec is not None:
                    self.var_time_increment.set(str(int(inc_sec)))

                # Resolve AI difficulty level & ELO rating
                final_elo, preset_name = self.resolve_ai_level_and_elo(difficulty=difficulty, elo=elo)
                self.var_elo.set(final_elo)
                self.var_level_name.set(preset_name)

                # Apply Player Color (handles boolean, string "true"/"false", "White"/"Black")
                if is_white is not None:
                    if isinstance(is_white, str):
                        is_w_bool = is_white.strip().lower() in ('true', 'w', 'white', '1')
                    else:
                        is_w_bool = bool(is_white)
                    new_color = "White" if is_w_bool else "Black"
                    self.var_player_color.set(new_color)
                    if getattr(self, 'game_active', False):
                        self.send_cv_cmd(f"set_player_color {new_color.lower()}")

                if play_style is not None:
                    if play_style.startswith('style_'):
                        play_style = play_style.replace('style_', '').capitalize()
                    self.var_play_style.set(play_style)

                # If the mobile match is marked active, mark physical app mode as active
                if data.get('is_active') is True:
                    self.is_physical_app_mode = True

                self.update_digital_timer_display()
                self.update_digital_increment_display()
                if hasattr(self, 'persist_synced_game_settings'):
                    self.persist_synced_game_settings()
                self.update_dashboard_settings_display()

                # Sync ELO to Stockfish Engine
                self.send_cv_elo(final_elo)

                # Check if mobile app signaled that game ended
                is_game_ended = data.get('isGameEnded', False)
                if is_game_ended and getattr(self, 'game_active', False):
                    self.log("🏁 Mobile App signalled game ended (isGameEnded: true) -> Triggering Close Game & Home Machine...")
                    self.close_game()

                # Send Arduino LCD clock sync command `T {timer_min} {inc_sec}`
                if hasattr(self, 'serial_manager') and self.serial_manager:
                    timer_min = self.var_game_timer.get()
                    inc_sec = self.var_time_increment.get()
                    self.serial_manager.send_cmd(f"T {timer_min} {inc_sec}")
                    if timer_min == "0":
                        self.serial_manager.send_cmd("S 0 0")

                self.log(f"📶 🎮 Synced Game Settings from Mobile App & Saved to JSON: {self.var_game_timer.get()}m+{self.var_time_increment.get()}s | {preset_name} ({self.var_player_color.get()})")

            if hasattr(self, '_firebase_test_view_on_live_session'):
                try:
                    self._firebase_test_view_on_live_session(data)
                except Exception:
                    pass
        self.safe_after(_update)

    def _on_network_status_changed(self, is_online):
        """Called from NetworkManager background thread when WiFi status changes."""
        def _update():
            if hasattr(self, 'lbl_wifi_status'):
                if is_online:
                    self.lbl_wifi_status.config(text="● WiFi: ON", fg="#43a047")
                else:
                    self.lbl_wifi_status.config(text="● WiFi: OFF", fg="#d32f2f")
        self.safe_after(_update)

    def _on_camera_status_changed(self, is_connected, is_on):
        """Called from CameraManager background thread when Camera 1 status changes."""
        def _update():
            if hasattr(self, 'lbl_camera_status'):
                if is_connected:
                    self.lbl_camera_status.config(text="● Camera 1: ON", fg="#43a047")
                else:
                    self.lbl_camera_status.config(text="● Camera 1: OFF", fg="#d32f2f")
        self.safe_after(_update)

    def _on_board_online_status_changed(self, is_board_online):
        """Called from BoardOnlineManager background thread when board online status changes."""
        def _update():
            if hasattr(self, 'lbl_board_online_status'):
                if is_board_online:
                    self.lbl_board_online_status.config(text="● Board Online", fg="#43a047")
                else:
                    self.lbl_board_online_status.config(text="● Board Offline", fg="#d32f2f")
        self.safe_after(_update)

    def on_closing(self):
        self.running = False
        try:
            self.root.withdraw()
        except Exception:
            pass

        def _cleanup():
            try:
                self.stop_cv()
            except Exception:
                pass
            if hasattr(self, "live_analysis_engine"):
                try:
                    self.live_analysis_engine.quit()
                except Exception:
                    pass
            if hasattr(self, "firebase_manager") and self.firebase_manager:
                try:
                    self.firebase_manager.close()
                except Exception:
                    pass
            try:
                self.network_manager.stop()
            except Exception:
                pass
            try:
                self.board_online_manager.stop()
            except Exception:
                pass
            try:
                self.serial_manager.close()
            except Exception:
                pass

        threading.Thread(target=_cleanup, daemon=True).start()

        try:
            self.root.quit()
            self.root.destroy()
        except Exception:
            pass
        os._exit(0)

def main():
    import signal

    # Set Windows taskbar AppUserModelID to ensure the custom taskbar icon is loaded
    try:
        import ctypes
        myappid = "graduation.chesstracker.dashboard.1.0"
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)
    except Exception:
        pass

    root = tk.Tk()
    root.withdraw()
    
    splash = SplashScreen(root)
    
    gui = CoreXY_GUI(root, progress_callback=splash.update_status)
    
    splash.destroy()
    root.deiconify()
    root.state('zoomed')
    root.lift()
    root.focus_force()
    root.update()

    def signal_handler(sig, frame):
        print("\n[System] Ctrl+C / SIGINT signal received. Shutting down GUI process...")
        gui.on_closing()

    try:
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
    except Exception:
        pass

    # Periodic heartbeat to allow Python interpreter to process Ctrl+C signals on Windows
    def check_signals():
        if gui.running:
            root.after(400, check_signals)

    root.after(400, check_signals)

    try:
        root.mainloop()
    except KeyboardInterrupt:
        print("\n[System] KeyboardInterrupt caught in main loop. Exiting...")
        gui.on_closing()
