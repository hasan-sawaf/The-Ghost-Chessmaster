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
from src.software.presentation.views.terminal_view import build_ui as build_terminal_ui
from src.software.presentation.views.manual_control_view import build_ui as build_manual_ctrl_ui
from src.software.presentation.views.settings_view import build_ui as build_settings_ui
from src.software.presentation.views.vision_feed_view import build_ui as build_vision_feeds_ui
from src.software.presentation.views.firebase_test_view import build_ui as build_firebase_test_ui

class LayoutMixin:
    def setup_styles(self):
        style = ttk.Style()
        try: style.theme_use('clam')
        except Exception: pass
        style.configure("TLabelframe", background="#ffffff", bordercolor="#cfd8dc", borderwidth=1)
        style.configure("TLabelframe.Label", font=("Segoe UI", 10, "bold"), background="#ffffff", foreground="#37474f")
        style.configure("TLabel", background="#ffffff", font=("Segoe UI", 9))
        style.configure("TCombobox", padding=2)

    def build_ui(self):
        # ==========================================
        # 1. TOP TAB NAVIGATION HEADER
        # ==========================================
        self.nav_header = tk.Frame(self.root, bg="#37474f", height=45)
        self.nav_header.pack(fill=tk.X, side=tk.TOP)
        self.nav_header.pack_propagate(False)

        # 4 Status Points (WiFi, Arduino COM7, Camera 1, Board Online) on RIGHT side
        # Packed FIRST so right-side status indicators are guaranteed permanent space and never overlapped
        self.status_header_frame = tk.Frame(self.nav_header, bg="#37474f")
        self.status_header_frame.pack(side=tk.RIGHT, fill=tk.Y, padx=(0, 8))

        self.lbl_board_online_status = tk.Label(
            self.status_header_frame, text="● Board Offline", bg="#37474f", fg="#d32f2f",
            font=("Segoe UI", 9, "bold"), padx=5
        )
        self.lbl_board_online_status.pack(side=tk.RIGHT, fill=tk.Y, pady=6)

        self.lbl_camera_status = tk.Label(
            self.status_header_frame, text="● Camera 1: OFF", bg="#37474f", fg="#d32f2f",
            font=("Segoe UI", 9, "bold"), padx=4
        )
        self.lbl_camera_status.pack(side=tk.RIGHT, fill=tk.Y, pady=6)

        self.lbl_arduino_status = tk.Label(
            self.status_header_frame, text="● Arduino: OFF", bg="#37474f", fg="#d32f2f",
            font=("Segoe UI", 9, "bold"), padx=4
        )
        self.lbl_arduino_status.pack(side=tk.RIGHT, fill=tk.Y, pady=6)

        self.lbl_wifi_status = tk.Label(
            self.status_header_frame, text="● WiFi: OFF", bg="#37474f", fg="#d32f2f",
            font=("Segoe UI", 9, "bold"), padx=4
        )
        self.lbl_wifi_status.pack(side=tk.RIGHT, fill=tk.Y, pady=6)

        btn_opts = {
            "bg": "#263238", "fg": "white", "activebackground": "#455a64",
            "activeforeground": "white", "relief": "flat", "cursor": "hand2",
            "font": ("Segoe UI", 9, "bold"), "padx": 8
        }

        self.btn_tab_dashboard = tk.Button(self.nav_header, text="🎮 Live Dashboard", command=self.show_dashboard_page, **btn_opts)
        self.btn_tab_dashboard.pack(side=tk.LEFT, fill=tk.Y, padx=(8, 2), pady=6)

        self.btn_tab_analysis = tk.Button(self.nav_header, text="📐 Deep Game Analyzer", command=self.show_analysis_page, **btn_opts)
        self.btn_tab_analysis.pack(side=tk.LEFT, fill=tk.Y, padx=2, pady=6)

        self.btn_tab_calibration = tk.Button(self.nav_header, text="⚙️ Camera Calibration", command=self.open_calibration_page, **btn_opts)
        self.btn_tab_calibration.pack(side=tk.LEFT, fill=tk.Y, padx=2, pady=6)

        self.btn_tab_terminal = tk.Button(self.nav_header, text="📟 Serial Terminal", command=self.show_terminal_page, **btn_opts)
        self.btn_tab_terminal.pack(side=tk.LEFT, fill=tk.Y, padx=2, pady=6)

        self.btn_tab_manual_ctrl = tk.Button(self.nav_header, text="🛠️ Manual Controls", command=self.show_manual_ctrl_page, **btn_opts)
        self.btn_tab_manual_ctrl.pack(side=tk.LEFT, fill=tk.Y, padx=2, pady=6)

        self.btn_tab_settings = tk.Button(self.nav_header, text="⚙️ Game Settings", command=self.show_settings_page, **btn_opts)
        self.btn_tab_settings.pack(side=tk.LEFT, fill=tk.Y, padx=2, pady=6)

        self.btn_tab_vision_feeds = tk.Button(self.nav_header, text="📺 Camera Feeds", command=self.show_vision_feeds_page, **btn_opts)
        self.btn_tab_vision_feeds.pack(side=tk.LEFT, fill=tk.Y, padx=2, pady=6)

        self.btn_tab_firebase_test = tk.Button(self.nav_header, text="📶 Board Connection", command=self.show_firebase_test_page, **btn_opts)
        self.btn_tab_firebase_test.pack(side=tk.LEFT, fill=tk.Y, padx=2, pady=6)

        # ==========================================
        # 2. MAIN CONTAINER & SUB-PAGES
        # ==========================================
        self.container_frame = tk.Frame(self.root, bg="#eef2f5")
        self.container_frame.pack(fill=tk.BOTH, expand=True, side=tk.TOP)

        self.dashboard_frame = tk.Frame(self.container_frame, bg="#eef2f5")
        self.dashboard_frame.pack(fill=tk.BOTH, expand=True)

        self.deep_analysis_frame = tk.Frame(self.container_frame, bg="#f4f6f9")

        self.terminal_frame = tk.Frame(self.container_frame, bg="#eef2f5")
        build_terminal_ui(self, self.terminal_frame)

        self.manual_ctrl_frame = tk.Frame(self.container_frame, bg="#eef2f5")
        build_manual_ctrl_ui(self, self.manual_ctrl_frame)

        self.settings_frame = tk.Frame(self.container_frame, bg="#eef2f5")
        build_settings_ui(self, self.settings_frame)

        self.vision_feeds_frame = tk.Frame(self.container_frame, bg="#eef2f5")
        build_vision_feeds_ui(self, self.vision_feeds_frame)

        self.firebase_test_frame = tk.Frame(self.container_frame, bg="#eef2f5")
        build_firebase_test_ui(self, self.firebase_test_frame)

        # ==========================================
        # 3. LIVE DASHBOARD PAGE LAYOUT
        # ==========================================
        self.dashboard_frame.columnconfigure(0, weight=1, uniform="col")
        self.dashboard_frame.columnconfigure(1, weight=1, uniform="col")
        self.dashboard_frame.columnconfigure(2, weight=2)
        self.dashboard_frame.rowconfigure(0, weight=1)

        # ==========================================
        # LEFT COLUMN: AI & SYSTEM CONTROL (SCROLLABLE)
        # ==========================================
        # 1. Container frame placed in the grid
        self.left_scroll_container = tk.Frame(self.dashboard_frame, bg="#eef2f5")
        self.left_scroll_container.grid(row=0, column=0, sticky="nsew")
        self.left_scroll_container.rowconfigure(0, weight=1)
        self.left_scroll_container.columnconfigure(0, weight=1)

        # 2. Canvas for scrolling
        self.canvas_left_scroll = tk.Canvas(self.left_scroll_container, bg="#eef2f5", bd=0, highlightthickness=0)
        self.canvas_left_scroll.grid(row=0, column=0, sticky="nsew")

        # 3. Scrollbar on the right of the canvas
        self.scrollbar_left = ttk.Scrollbar(self.left_scroll_container, orient="vertical", command=self.canvas_left_scroll.yview)
        self.scrollbar_left.grid(row=0, column=1, sticky="ns")

        self.canvas_left_scroll.configure(yscrollcommand=self.scrollbar_left.set)

        # 4. Content frame inside the canvas
        left_col = tk.Frame(self.canvas_left_scroll, bg="#eef2f5", padx=6, pady=6)
        self.left_col = left_col

        self.canvas_window_left = self.canvas_left_scroll.create_window((0, 0), window=left_col, anchor="nw")

        # Auto-adjust scroll region when widgets change size
        left_col.bind(
            "<Configure>",
            lambda e: self.canvas_left_scroll.configure(
                scrollregion=self.canvas_left_scroll.bbox("all")
            )
        )

        # Auto-adjust content frame width to match canvas width
        def _configure_left_canvas(event):
            self.canvas_left_scroll.itemconfig(self.canvas_window_left, width=event.width)
        self.canvas_left_scroll.bind('<Configure>', _configure_left_canvas)

        # Mousewheel scroll binding ONLY when mouse enters the scrollable container
        def _on_left_mousewheel(event):
            self.canvas_left_scroll.yview_scroll(int(-1 * (event.delta / 120)), "units")

        def _bind_left_mousewheel(_event):
            self.canvas_left_scroll.bind_all("<MouseWheel>", _on_left_mousewheel)

        def _unbind_left_mousewheel(_event):
            self.canvas_left_scroll.unbind_all("<MouseWheel>")

        self.left_scroll_container.bind("<Enter>", _bind_left_mousewheel)
        self.left_scroll_container.bind("<Leave>", _unbind_left_mousewheel)

        # 1. Game Status Panel
        game_frame = ttk.LabelFrame(left_col, text=" 🎮 Game Engine Status ", padding=6)
        game_frame.pack(fill=tk.X, pady=(0, 6))

        tk.Label(game_frame, text="Current Turn:", bg="white", font=("Segoe UI", 9)).grid(row=0, column=0, sticky="w")
        tk.Label(game_frame, textvariable=self.var_turn, font=("Segoe UI", 11, "bold"), bg="white", fg="#2e7d32").grid(row=0, column=1, sticky="e", padx=5)

        tk.Label(game_frame, text="Status:", bg="white", font=("Segoe UI", 9)).grid(row=1, column=0, sticky="w", pady=(3,0))
        tk.Label(game_frame, textvariable=self.var_status, font=("Segoe UI", 9, "italic"), bg="white", fg="#1565c0").grid(row=1, column=1, sticky="e", padx=5, pady=(3,0))

        self.btn_execute = tk.Button(game_frame, text="♟️ EXECUTE MOVE", bg="#1976d2", fg="white", font=("Segoe UI", 10, "bold"), relief="flat", cursor="hand2", command=self.trigger_user_move)
        self.btn_execute.grid(row=2, column=0, columnspan=2, sticky="ew", pady=(8, 0), ipady=4)
        self.btn_execute.config(state=tk.DISABLED)

        # 1.3 Active Configurations Box (Split into 2 Columns: Match Settings & App Physical Sync)
        config_frame = ttk.LabelFrame(left_col, text=" ⚙️ Active Configurations & App Sync ", padding=8)
        config_frame.pack(fill=tk.X, pady=6)

        cfg_grid = tk.Frame(config_frame, bg="white")
        cfg_grid.pack(fill=tk.X)
        cfg_grid.columnconfigure(0, weight=1)
        cfg_grid.columnconfigure(1, weight=1)

        # Column 0 (Left): Match Settings
        col_left_cfg = tk.Frame(cfg_grid, bg="white")
        col_left_cfg.grid(row=0, column=0, sticky="nsew", padx=(0, 6))

        self.lbl_dash_config_timer = tk.Label(col_left_cfg, text="⏱️ Time Limit: --", bg="white", font=("Segoe UI", 9, "bold"), fg="#37474f", anchor="w")
        self.lbl_dash_config_timer.pack(fill=tk.X, pady=1)

        self.lbl_dash_config_inc = tk.Label(col_left_cfg, text="⚡ Increment: --", bg="white", font=("Segoe UI", 9), fg="#546e7a", anchor="w")
        self.lbl_dash_config_inc.pack(fill=tk.X, pady=1)

        self.lbl_dash_config_difficulty = tk.Label(col_left_cfg, text="🤖 AI Level: --", bg="white", font=("Segoe UI", 9), fg="#546e7a", anchor="w")
        self.lbl_dash_config_difficulty.pack(fill=tk.X, pady=1)

        self.lbl_dash_config_style = tk.Label(col_left_cfg, text="⚔️ Playing Style: --", bg="white", font=("Segoe UI", 9), fg="#546e7a", anchor="w")
        self.lbl_dash_config_style.pack(fill=tk.X, pady=1)

        self.lbl_dash_config_color = tk.Label(col_left_cfg, text="♟️ Playing As: --", bg="white", font=("Segoe UI", 9), fg="#546e7a", anchor="w")
        self.lbl_dash_config_color.pack(fill=tk.X, pady=1)

        # Column 1 (Right): Match Origin & App Physical Mode Status Box
        col_right_cfg = tk.Frame(cfg_grid, bg="#f8f9fa", bd=1, relief="solid", padx=8, pady=6)
        col_right_cfg.grid(row=0, column=1, sticky="nsew", padx=(6, 0))

        self.lbl_dash_match_origin = tk.Label(
            col_right_cfg, text="🚀 Origin: ⏸️ Idle (Waiting to Start)", bg="#f8f9fa",
            font=("Segoe UI", 9, "bold"), fg="#757575", anchor="w"
        )
        self.lbl_dash_match_origin.pack(fill=tk.X, pady=(0, 2))

        self.lbl_dash_sync_status = tk.Label(
            col_right_cfg, text="⚪ Ready for Next Match", bg="#f8f9fa",
            font=("Segoe UI", 9, "bold"), fg="#546e7a", anchor="w"
        )
        self.lbl_dash_sync_status.pack(fill=tk.X, pady=(0, 2))

        self.lbl_dash_sync_detail = tk.Label(
            col_right_cfg,
            text="Start from Flutter app for Physical Mode,\nor click 'Start Game' for local play.",
            bg="#f8f9fa", font=("Segoe UI", 8), fg="#757575", justify="left", anchor="w"
        )
        self.lbl_dash_sync_detail.pack(fill=tk.X, pady=(0, 4))

        self.lbl_dash_user_link = tk.Label(
            col_right_cfg, text="👤 User: Disconnected", bg="#f8f9fa",
            font=("Segoe UI", 8, "bold"), fg="#757575", anchor="w"
        )
        self.lbl_dash_user_link.pack(fill=tk.X)

        # 1.5 Digital Chess Clock Card
        clock_frame = ttk.LabelFrame(left_col, text=" ⏱️ Digital Chess Clock ", padding=10)
        clock_frame.pack(fill=tk.X, pady=6)

        # Nested grid for dual clocks
        clock_grid = tk.Frame(clock_frame, bg="white")
        clock_grid.pack(fill=tk.X)
        clock_grid.columnconfigure((0, 1), weight=1)

        # White clock box
        self.frame_white_clock = tk.Frame(clock_grid, bg="#212121", highlightthickness=2, highlightbackground="#cfd8dc", bd=0)
        self.frame_white_clock.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")

        tk.Label(self.frame_white_clock, text="⚪ WHITE (HUMAN)", bg="#212121", fg="#b0bec5", font=("Segoe UI", 8, "bold")).pack(pady=(5, 2))
        self.lbl_white_clock = tk.Label(self.frame_white_clock, text="10:00", bg="#212121", fg="#00e676", font=("Consolas", 22, "bold"))
        self.lbl_white_clock.pack(pady=(0, 5))

        # Black clock box
        self.frame_black_clock = tk.Frame(clock_grid, bg="#212121", highlightthickness=2, highlightbackground="#cfd8dc", bd=0)
        self.frame_black_clock.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")

        tk.Label(self.frame_black_clock, text="⚫ BLACK (AI)", bg="#212121", fg="#b0bec5", font=("Segoe UI", 8, "bold")).pack(pady=(5, 2))
        self.lbl_black_clock = tk.Label(self.frame_black_clock, text="10:00", bg="#212121", fg="#ff9100", font=("Consolas", 22, "bold"))
        self.lbl_black_clock.pack(pady=(0, 5))

        # 1.6 Live Move Analysis Card
        live_analysis_frame = ttk.LabelFrame(left_col, text=" 📊 Live Move Analysis ", padding=10)
        live_analysis_frame.pack(fill=tk.BOTH, expand=True, pady=6)

        # Upper section: Detailed stats grid
        stats_grid = tk.Frame(live_analysis_frame, bg="white")
        stats_grid.pack(fill=tk.X, pady=(0, 5))
        stats_grid.columnconfigure((0, 1), weight=1)

        # Left box: Played Move Info
        played_box = tk.LabelFrame(stats_grid, text="Played Move", bg="white", font=("Segoe UI", 8, "bold"), padx=5, pady=5)
        played_box.grid(row=0, column=0, sticky="nsew", padx=(0, 4))

        self.lbl_live_move = tk.Label(played_box, text="--", bg="white", font=("Courier New", 14, "bold"), fg="#1565c0")
        self.lbl_live_move.pack(pady=2)

        self.lbl_live_class = tk.Label(played_box, text="Rating: --", bg="white", font=("Segoe UI", 9, "bold"))
        self.lbl_live_class.pack()

        # Right box: Engine Suggestion Info
        engine_box = tk.LabelFrame(stats_grid, text="Engine Recommendation", bg="white", font=("Segoe UI", 8, "bold"), padx=5, pady=5)
        engine_box.grid(row=0, column=1, sticky="nsew", padx=(4, 0))

        self.lbl_best_move = tk.Label(engine_box, text="--", bg="white", font=("Courier New", 14, "bold"), fg="#2e7d32")
        self.lbl_best_move.pack(pady=2)

        self.lbl_live_eval = tk.Label(engine_box, text="Eval: 0.00", bg="white", font=("Segoe UI", 9, "bold"))
        self.lbl_live_eval.pack()

        # Additional detailed metrics log (e.g. CPL, accuracy)
        self.lbl_detail_metrics = tk.Label(live_analysis_frame, text="Centipawn Loss: 0 | Move Accuracy: 100.0%", bg="white", font=("Segoe UI", 8, "italic"), fg="#546e7a")
        self.lbl_detail_metrics.pack(anchor="w", pady=(5, 5))

        # Live Player stats Cards Frame
        cards_container = tk.Frame(live_analysis_frame, bg="white")
        cards_container.pack(fill=tk.X, pady=(5, 5))
        cards_container.columnconfigure((0, 1), weight=1)

        # White Player Card
        self.white_card = tk.Frame(cards_container, bg="white", highlightbackground="#cfd8dc", highlightthickness=1)
        self.white_card.grid(row=0, column=0, sticky="nsew", padx=(0, 4))

        lbl_w_title = tk.Label(self.white_card, text="⚪ Player White (Human)", font=("Segoe UI", 9, "bold"), fg="#37474f", bg="white")
        lbl_w_title.pack(anchor="w", padx=8, pady=(4, 0))

        self.lbl_white_accuracy = tk.Label(self.white_card, text="Accuracy: --", font=("Segoe UI", 11, "bold"), fg="#1976d2", bg="white")
        self.lbl_white_accuracy.pack(anchor="w", padx=8, pady=(0, 1))

        w_stats_grid = tk.Frame(self.white_card, bg="white")
        w_stats_grid.pack(fill=tk.X, padx=8, pady=(2, 4))

        self.white_stat_labels = {}
        cats_to_grid = [
            ("Brilliant", 0, 0), ("Best", 0, 1), ("Excellent", 0, 2), ("Good", 0, 3),
            ("Book", 1, 0), ("Inaccuracy", 1, 1), ("Mistake", 1, 2), ("Blunder", 1, 3)
        ]
        for cat, r, c in cats_to_grid:
            lbl = tk.Label(
                w_stats_grid, text=" 0", image=self.legend_icons.get(cat, ""),
                compound=tk.LEFT, bg="white", font=("Segoe UI", 8)
            )
            lbl.grid(row=r, column=c, sticky="w", padx=(0, 6), pady=1)
            self.white_stat_labels[cat] = lbl

        # Black Player Card
        self.black_card = tk.Frame(cards_container, bg="white", highlightbackground="#cfd8dc", highlightthickness=1)
        self.black_card.grid(row=0, column=1, sticky="nsew", padx=(4, 0))

        lbl_b_title = tk.Label(self.black_card, text="⚫ Player Black (AI)", font=("Segoe UI", 9, "bold"), fg="#37474f", bg="white")
        lbl_b_title.pack(anchor="w", padx=8, pady=(4, 0))

        self.lbl_black_accuracy = tk.Label(self.black_card, text="Accuracy: --", font=("Segoe UI", 11, "bold"), fg="#e64a19", bg="white")
        self.lbl_black_accuracy.pack(anchor="w", padx=8, pady=(0, 1))

        b_stats_grid = tk.Frame(self.black_card, bg="white")
        b_stats_grid.pack(fill=tk.X, padx=8, pady=(2, 4))

        self.black_stat_labels = {}
        for cat, r, c in cats_to_grid:
            lbl = tk.Label(
                b_stats_grid, text=" 0", image=self.legend_icons.get(cat, ""),
                compound=tk.LEFT, bg="white", font=("Segoe UI", 8)
            )
            lbl.grid(row=r, column=c, sticky="w", padx=(0, 6), pady=1)
            self.black_stat_labels[cat] = lbl

        # Bottom section: History Treeview of analyzed moves
        tk.Label(live_analysis_frame, text="Game Moves Log:", font=("Segoe UI", 8, "bold"), bg="white", fg="#37474f").pack(anchor="w", pady=(5, 2))

        tree_scroll = tk.Frame(live_analysis_frame)
        tree_scroll.pack(fill=tk.BOTH, expand=True)

        self.tree_live_moves = ttk.Treeview(
            tree_scroll,
            columns=("#", "player", "move", "eval", "accuracy", "class"),
            show="headings",
            height=6
        )
        self.tree_live_moves.heading("#", text="#", anchor="center")
        self.tree_live_moves.heading("player", text="Player", anchor="center")
        self.tree_live_moves.heading("move", text="Move", anchor="center")
        self.tree_live_moves.heading("eval", text="Eval", anchor="center")
        self.tree_live_moves.heading("accuracy", text="Accuracy", anchor="center")
        self.tree_live_moves.heading("class", text="Rating", anchor="center")

        self.tree_live_moves.column("#", width=30, anchor="center")
        self.tree_live_moves.column("player", width=70, anchor="center")
        self.tree_live_moves.column("move", width=55, anchor="center")
        self.tree_live_moves.column("eval", width=55, anchor="center")
        self.tree_live_moves.column("accuracy", width=65, anchor="center")
        self.tree_live_moves.column("class", width=85, anchor="center")

        # Scrollbar
        scroll = ttk.Scrollbar(tree_scroll, orient="vertical", command=self.tree_live_moves.yview)
        self.tree_live_moves.configure(yscrollcommand=scroll.set)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.tree_live_moves.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.tree_live_moves.bind("<<TreeviewSelect>>", self.on_live_move_select)

        # Style configurations for classifications in Treeview (tags)
        for class_name in ["Brilliant", "Best", "Excellent", "Good", "Book", "Inaccuracy", "Mistake", "Blunder"]:
            colors = self.get_class_colors(class_name)
            self.tree_live_moves.tag_configure(class_name.lower(), background=colors["bg"], foreground=colors["fg"])

        # 2. CV Controls
        cv_frame = ttk.LabelFrame(left_col, text=" 👁️ Computer Vision Bridge ", padding=10)
        cv_frame.pack(fill=tk.X, pady=6)

        # Status row
        status_row = tk.Frame(cv_frame, bg="white")
        status_row.pack(fill=tk.X, pady=(2, 6))

        self.lbl_cv_status = tk.Label(status_row, text="● CV Engine: Offline", bg="white", font=("Segoe UI", 9, "bold"), fg="#d32f2f")
        self.lbl_cv_status.pack(side=tk.LEFT, padx=5)

        bridge_btns = tk.Frame(cv_frame, bg="white")
        bridge_btns.pack(fill=tk.X, pady=(0, 4))

        btn_start = tk.Button(bridge_btns, text="🚀 START CAMERA", bg="#43a047", fg="white", font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", command=self.start_cv)
        btn_start.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(0, 2), ipady=3)
        btn_start.bind("<Enter>", lambda e: btn_start.config(bg="#388e3c"))
        btn_start.bind("<Leave>", lambda e: btn_start.config(bg="#43a047"))

        btn_stop = tk.Button(bridge_btns, text="🛑 STOP", bg="#d32f2f", fg="white", font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", command=self.stop_cv)
        btn_stop.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(2, 0), ipady=3)
        btn_stop.bind("<Enter>", lambda e: btn_stop.config(bg="#c2185b"))
        btn_stop.bind("<Leave>", lambda e: btn_stop.config(bg="#d32f2f"))

        # 3. System & Game Buttons
        sys_game_frame = ttk.LabelFrame(left_col, text=" ⚙️ System & Game Buttons ", padding=10)
        sys_game_frame.pack(fill=tk.X, pady=6)

        # Use a grid layout for nice compact rows
        sys_game_frame.columnconfigure((0, 1), weight=1)

        # Row 0: Start Game and Stop Game
        btn_start_game = tk.Button(sys_game_frame, text="▶️ Start Game", bg="#43a047", fg="white", font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", command=self.start_game)
        btn_start_game.grid(row=0, column=0, padx=2, pady=3, sticky="ew", ipady=3)
        btn_start_game.bind("<Enter>", lambda e: btn_start_game.config(bg="#388e3c"))
        btn_start_game.bind("<Leave>", lambda e: btn_start_game.config(bg="#43a047"))

        btn_stop_game = tk.Button(sys_game_frame, text="⏸️ Stop Game", bg="#e53935", fg="white", font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", command=self.stop_game)
        btn_stop_game.grid(row=0, column=1, padx=2, pady=3, sticky="ew", ipady=3)
        btn_stop_game.bind("<Enter>", lambda e: btn_stop_game.config(bg="#d32f2f"))
        btn_stop_game.bind("<Leave>", lambda e: btn_stop_game.config(bg="#e53935"))

        # Row 1: Resume Game and Save Game
        btn_resume_game = tk.Button(sys_game_frame, text="⏯️ Resume Game", bg="#1976d2", fg="white", font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", command=self.resume_game)
        btn_resume_game.grid(row=1, column=0, padx=2, pady=3, sticky="ew", ipady=3)
        btn_resume_game.bind("<Enter>", lambda e: btn_resume_game.config(bg="#1565c0"))
        btn_resume_game.bind("<Leave>", lambda e: btn_resume_game.config(bg="#1976d2"))

        btn_save_game = tk.Button(sys_game_frame, text="💾 Save Next Played Game", bg="#00838f", fg="white", font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", command=self.prompt_save_game)
        btn_save_game.grid(row=1, column=1, padx=2, pady=3, sticky="ew", ipady=3)
        btn_save_game.bind("<Enter>", lambda e: btn_save_game.config(bg="#006064"))
        btn_save_game.bind("<Leave>", lambda e: btn_save_game.config(bg="#00838f"))

        # Row 2: Continue Saved Game
        btn_continue_game = tk.Button(sys_game_frame, text="⏪ Continue Saved Game", bg="#f57c00", fg="white", font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", command=self.continue_saved_game_prompt)
        btn_continue_game.grid(row=2, column=0, columnspan=2, padx=2, pady=3, sticky="ew", ipady=3)
        btn_continue_game.bind("<Enter>", lambda e: btn_continue_game.config(bg="#ef6c00"))
        btn_continue_game.bind("<Leave>", lambda e: btn_continue_game.config(bg="#f57c00"))

        # Row 3: Close Game (Full width)
        btn_close_game = tk.Button(sys_game_frame, text="❌ Close Game & Home Machine", bg="#b71c1c", fg="white", font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", command=self.close_game)
        btn_close_game.grid(row=3, column=0, columnspan=2, padx=2, pady=4, sticky="ew", ipady=3)
        btn_close_game.bind("<Enter>", lambda e: btn_close_game.config(bg="#8e0000"))
        btn_close_game.bind("<Leave>", lambda e: btn_close_game.config(bg="#b71c1c"))

        # Separator between game flow and mechatronic tools
        sep = ttk.Separator(sys_game_frame, orient="horizontal")
        sep.grid(row=3, column=0, columnspan=2, sticky="ew", pady=8)

        # Row 4: Recapture Base Frame (Full width)
        btn_recap = tk.Button(sys_game_frame, text="📷 RECAPTURE BASE FRAME", bg="#546e7a", fg="white", font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2", command=self.recapture_base_frame)
        btn_recap.grid(row=4, column=0, columnspan=2, padx=2, pady=3, sticky="ew", ipady=3)
        btn_recap.bind("<Enter>", lambda e: btn_recap.config(bg="#37474f"))
        btn_recap.bind("<Leave>", lambda e: btn_recap.config(bg="#546e7a"))

        # Row 5: Undo 1 and Undo 2
        btn_undo1 = tk.Button(sys_game_frame, text="⏪ Undo 1", bg="#78909c", fg="white", font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2", command=lambda: self.send_cv_cmd('u'))
        btn_undo1.grid(row=5, column=0, padx=2, pady=3, sticky="ew", ipady=2)
        btn_undo1.bind("<Enter>", lambda e: btn_undo1.config(bg="#455a64"))
        btn_undo1.bind("<Leave>", lambda e: btn_undo1.config(bg="#78909c"))

        btn_undo2 = tk.Button(sys_game_frame, text="⏪⏪ Undo 2", bg="#90a4ae", fg="white", font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2", command=lambda: self.send_cv_cmd('U'))
        btn_undo2.grid(row=5, column=1, padx=2, pady=3, sticky="ew", ipady=2)
        btn_undo2.bind("<Enter>", lambda e: btn_undo2.config(bg="#546e7a"))
        btn_undo2.bind("<Leave>", lambda e: btn_undo2.config(bg="#90a4ae"))

        # ==========================================
        # CENTER COLUMN: PHYSICAL HARDWARE CONTROL
        # ==========================================
        self.center_col = tk.Frame(self.dashboard_frame, bg="#eef2f5", padx=6, pady=6)
        self.center_col.grid(row=0, column=1, sticky="nsew")
        center_col = self.center_col

        # 1. State Monitor & Telemetry
        monitor = ttk.LabelFrame(center_col, text=" 📊 Hardware State & Telemetry ", padding=6)
        monitor.pack(fill=tk.X, pady=(0, 6))

        tk.Label(monitor, text="📍 Position:", bg="white", font=("Segoe UI", 9)).grid(row=0, column=0, sticky="w")
        tk.Label(monitor, textvariable=self.var_current_sq, font=("Segoe UI", 10, "bold"), bg="white", fg="#1976d2").grid(row=0, column=1, sticky="w", padx=4)
        tk.Label(monitor, text="X (mm):", bg="white", font=("Segoe UI", 9)).grid(row=0, column=2, sticky="e", padx=(8,0))
        tk.Label(monitor, textvariable=self.var_x, font=("Courier", 10, "bold"), bg="white").grid(row=0, column=3, sticky="e")

        tk.Label(monitor, text="♟️ Holding:", bg="white", font=("Segoe UI", 9)).grid(row=1, column=0, sticky="w", pady=(3,0))
        tk.Label(monitor, textvariable=self.var_held_piece, font=("Segoe UI", 10, "bold"), bg="white", fg="#d32f2f").grid(row=1, column=1, sticky="w", padx=4, pady=(3,0))
        tk.Label(monitor, text="Y (mm):", bg="white", font=("Segoe UI", 9)).grid(row=1, column=2, sticky="e", padx=(8,0), pady=(3,0))
        tk.Label(monitor, textvariable=self.var_y, font=("Courier", 10, "bold"), bg="white").grid(row=1, column=3, sticky="e", pady=(3,0))

        # Direct Coordinate G-Code Move Section (calls processGCode)
        coord_frame = tk.Frame(monitor, bg="white", pady=2)
        coord_frame.grid(row=2, column=0, columnspan=4, sticky="ew", pady=(6, 2))

        tk.Label(coord_frame, text="🎯 Move (mm):", bg="white", font=("Segoe UI", 9, "bold"), fg="#37474f").pack(side=tk.LEFT, padx=(0, 4))
        
        tk.Label(coord_frame, text="X:", bg="white", font=("Segoe UI", 9, "bold"), fg="#1976d2").pack(side=tk.LEFT, padx=(2, 1))
        self.ent_gcode_x = tk.Entry(coord_frame, textvariable=self.var_target_gcode_x, width=6, font=("Segoe UI", 9), justify="center")
        self.ent_gcode_x.pack(side=tk.LEFT, padx=(0, 4))
        self.ent_gcode_x.bind("<Return>", lambda e: self.process_gcode_coordinate_move())

        tk.Label(coord_frame, text="Y:", bg="white", font=("Segoe UI", 9, "bold"), fg="#1976d2").pack(side=tk.LEFT, padx=(2, 1))
        self.ent_gcode_y = tk.Entry(coord_frame, textvariable=self.var_target_gcode_y, width=6, font=("Segoe UI", 9), justify="center")
        self.ent_gcode_y.pack(side=tk.LEFT, padx=(0, 6))
        self.ent_gcode_y.bind("<Return>", lambda e: self.process_gcode_coordinate_move())

        self.btn_execute_gcode = tk.Button(
            coord_frame, text="🚀 Execute", bg="#1976d2", fg="white",
            font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2",
            activebackground="#1565c0", activeforeground="white", padx=8, pady=1,
            command=self.process_gcode_coordinate_move
        )
        self.btn_execute_gcode.pack(side=tk.LEFT, padx=2)

        # 2. Physical Target Mapping
        board_lbl_frame = ttk.LabelFrame(center_col, text=" ♟️ Physical Target Mapping ", padding=10)
        board_lbl_frame.pack(fill=tk.BOTH, expand=True, pady=6)

        # Board layout sub-frame to nest Advantage Bar and Grid side-by-side
        board_layout_frame = tk.Frame(board_lbl_frame, bg="white", padx=5, pady=5)
        board_layout_frame.pack(pady=4, fill=tk.BOTH, expand=True)

        # Dynamic Eval Bar
        self.canvas_eval_live = tk.Canvas(board_layout_frame, width=22, height=300, bg="white", highlightthickness=0, bd=0)
        self.canvas_eval_live.pack(side=tk.LEFT, padx=(5, 10), fill=tk.Y)

        board_grid = tk.Frame(board_layout_frame, bg="white")
        board_grid.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        for r_idx, rank in enumerate(range(8, 0, -1)):
            tk.Label(board_grid, text=str(rank), bg="white", font=("Segoe UI", 10, "bold"), fg="#37474f", width=2).grid(row=r_idx, column=0, padx=4)
            for c_idx, file in enumerate("ABCDEFGH"):
                sq = f"{file}{rank}"
                color = "#f0d9b5" if (r_idx + c_idx) % 2 == 0 else "#b58863"
                btn = tk.Button(
                    board_grid, text=sq, bg=color, width=5, height=2, relief="flat", cursor="hand2",
                    font=("Segoe UI", 9, "bold"), fg="#37474f", command=lambda s=sq: self.move_to_sq(s)
                )
                btn.grid(row=r_idx, column=c_idx + 1, padx=2, pady=2)
                self.board_buttons[sq] = btn

                # Active hover highlights
                btn.bind("<Enter>", lambda e, b=btn: b.config(bg="#81d4fa"))
                btn.bind("<Leave>", lambda e, b=btn, c_orig=color: b.config(bg=c_orig))

        files_frame = tk.Frame(board_grid, bg="white")
        files_frame.grid(row=8, column=1, columnspan=8, pady=4)
        for c_idx, file in enumerate("ABCDEFGH"):
            tk.Label(files_frame, text=file, bg="white", font=("Segoe UI", 10, "bold"), fg="#37474f", width=4).grid(row=0, column=c_idx, padx=3)

        # Initial eval bar redraw
        self.current_pct_live = 0.5
        self.target_pct_live = 0.5
        self.current_eval_str = "0.00"
        self.redraw_live_eval_bar_to_canvas()



        # ==========================================
        # RIGHT COLUMN: VISION SYSTEM
        # ==========================================
        self.right_col = tk.Frame(self.dashboard_frame, bg="#eef2f5", padx=6, pady=6)
        self.right_col.grid(row=0, column=2, sticky="nsew")
        right_col = self.right_col

        vision_frame = ttk.LabelFrame(right_col, text=" 🎥 AI & Vision Feeds ", padding=6)
        vision_frame.pack(fill=tk.BOTH, expand=True)
        vision_frame.columnconfigure(0, weight=1)
        vision_frame.columnconfigure(1, weight=1)
        vision_frame.rowconfigure(1, weight=1)
        vision_frame.rowconfigure(3, weight=1)

        # Top Left
        tk.Label(vision_frame, text="Live Camera Tracker", bg="white", font=("Segoe UI", 9, "bold"), fg="#37474f").grid(row=0, column=0, pady=(3,0))
        self.lbl_tracker = tk.Label(vision_frame, text="Camera Offline", bg="#263238", fg="#eceff1", width=30, height=11, font=("Segoe UI", 9))
        self.lbl_tracker.grid(row=1, column=0, padx=3, pady=3, sticky="n")

        # Top Right
        tk.Label(vision_frame, text="Digital Board State", bg="white", font=("Segoe UI", 9, "bold"), fg="#37474f").grid(row=0, column=1, pady=(3,0))
        self.lbl_board = tk.Label(vision_frame, text="Board Offline", bg="#263238", fg="#eceff1", width=30, height=11, font=("Segoe UI", 9))
        self.lbl_board.grid(row=1, column=1, padx=3, pady=3, sticky="n")

        # Bottom Left: DEBUG 1 (Motion Mask)
        tk.Label(vision_frame, text="Debug: Motion Mask", bg="white", font=("Segoe UI", 9, "bold"), fg="#37474f").grid(row=2, column=0, pady=(6,0))
        self.lbl_debug_mask = tk.Label(vision_frame, text="Mask Offline", bg="#263238", fg="#eceff1", width=30, height=11, font=("Segoe UI", 9))
        self.lbl_debug_mask.grid(row=3, column=0, padx=3, pady=3, sticky="n")

        # Bottom Right: DEBUG 2 (Contour Mapping)
        tk.Label(vision_frame, text="Debug: Extracted Maps", bg="white", font=("Segoe UI", 9, "bold"), fg="#37474f").grid(row=2, column=1, pady=(6,0))
        self.lbl_debug_map = tk.Label(vision_frame, text="Map Offline", bg="#263238", fg="#eceff1", width=30, height=11, font=("Segoe UI", 9))
        self.lbl_debug_map.grid(row=3, column=1, padx=3, pady=3, sticky="n")

        # Sync settings display now that all frames are fully built
        if hasattr(self, "update_digital_timer_display"):
            self.update_digital_timer_display()
        if hasattr(self, "update_digital_increment_display"):
            self.update_digital_increment_display()
        if hasattr(self, "update_dashboard_settings_display"):
            self.update_dashboard_settings_display()

        # Default dashboard is shown first
        self.show_dashboard_page()

    # --- FORWARDING METHODS (Bridges GUI callbacks to Sub-Managers) ---
