import tkinter as tk
from tkinter import ttk, scrolledtext
from src.software.core.constants import DEFAULT_COM_PORT, BAUD_RATE

def build_ui(gui, frame):
    # Header bar
    header = tk.Frame(frame, bg="#37474f", height=45)
    header.pack(fill=tk.X, side=tk.TOP)
    header.pack_propagate(False)

    lbl_title = tk.Label(header, text="⚙️ GAME MATCH & AI DIFFICULTY SETTINGS", font=("Segoe UI", 11, "bold"), fg="white", bg="#37474f")
    lbl_title.pack(side=tk.LEFT, padx=15, fill=tk.Y)

    workspace = tk.Frame(frame, bg="#eef2f5", padx=20, pady=20)
    workspace.pack(fill=tk.BOTH, expand=True)

    # Main Settings Container Card
    settings_card = ttk.LabelFrame(workspace, text=" ⚙️ Game Configurations ", padding=15)
    settings_card.pack(fill=tk.BOTH, expand=True)

    # Row 0: Active Game Warning Label
    gui.lbl_settings_warning = tk.Label(settings_card, text="", font=("Segoe UI", 10, "bold"), bg="white", fg="#d32f2f")
    gui.lbl_settings_warning.pack(fill=tk.X, pady=(0, 10))

    # Grid layout for options
    grid_frame = tk.Frame(settings_card, bg="white")
    grid_frame.pack(fill=tk.X, pady=5)

    # 1. Match Timer Limit (Digital Clock Selector)
    tk.Label(grid_frame, text="🕒 Game Timer Limit:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=0, column=0, sticky="w", pady=8, padx=5)

    timer_clock_frame = tk.Frame(grid_frame, bg="#263238", bd=2, relief="sunken")
    timer_clock_frame.grid(row=0, column=1, sticky="w", pady=8, padx=10)

    gui.lbl_digital_timer = tk.Label(timer_clock_frame, text="10:00", bg="#263238", fg="#00e676", font=("Consolas", 18, "bold"), width=7)
    gui.lbl_digital_timer.pack(side=tk.LEFT, padx=8, pady=4)

    btn_timer_frame = tk.Frame(timer_clock_frame, bg="#263238")
    btn_timer_frame.pack(side=tk.LEFT, padx=(0, 6))

    gui.btn_timer_up = tk.Button(
        btn_timer_frame, text="▲", font=("Segoe UI", 8, "bold"), bg="#37474f", fg="white",
        activebackground="#455a64", activeforeground="white", relief="flat", width=3, height=1,
        command=gui.increase_timer_5m, cursor="hand2"
    )
    gui.btn_timer_up.pack(side=tk.TOP, pady=1)

    gui.btn_timer_down = tk.Button(
        btn_timer_frame, text="▼", font=("Segoe UI", 8, "bold"), bg="#37474f", fg="white",
        activebackground="#455a64", activeforeground="white", relief="flat", width=3, height=1,
        command=gui.decrease_timer_5m, cursor="hand2"
    )
    gui.btn_timer_down.pack(side=tk.BOTTOM, pady=1)

    tk.Label(grid_frame, text="(5 min increments, Min: 5m, Max: 30m)", bg="white", font=("Segoe UI", 9, "italic"), fg="#546e7a").grid(row=0, column=2, sticky="w", pady=8)

    # 2. Match Increment (Digital Increment Selector)
    tk.Label(grid_frame, text="➕ Time Increment:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=1, column=0, sticky="w", pady=8, padx=5)

    inc_clock_frame = tk.Frame(grid_frame, bg="#263238", bd=2, relief="sunken")
    inc_clock_frame.grid(row=1, column=1, sticky="w", pady=8, padx=10)

    gui.lbl_digital_increment = tk.Label(inc_clock_frame, text="02s", bg="#263238", fg="#00e676", font=("Consolas", 18, "bold"), width=7)
    gui.lbl_digital_increment.pack(side=tk.LEFT, padx=8, pady=4)

    btn_inc_frame = tk.Frame(inc_clock_frame, bg="#263238")
    btn_inc_frame.pack(side=tk.LEFT, padx=(0, 6))

    gui.btn_inc_up = tk.Button(
        btn_inc_frame, text="▲", font=("Segoe UI", 8, "bold"), bg="#37474f", fg="white",
        activebackground="#455a64", activeforeground="white", relief="flat", width=3, height=1,
        command=gui.increase_increment, cursor="hand2"
    )
    gui.btn_inc_up.pack(side=tk.TOP, pady=1)

    gui.btn_inc_down = tk.Button(
        btn_inc_frame, text="▼", font=("Segoe UI", 8, "bold"), bg="#37474f", fg="white",
        activebackground="#455a64", activeforeground="white", relief="flat", width=3, height=1,
        command=gui.decrease_increment, cursor="hand2"
    )
    gui.btn_inc_down.pack(side=tk.BOTTOM, pady=1)

    tk.Label(grid_frame, text="(1, 2, or 3 seconds per move)", bg="white", font=("Segoe UI", 9, "italic"), fg="#546e7a").grid(row=1, column=2, sticky="w", pady=8)

    # 3. AI Preset Difficulty
    tk.Label(grid_frame, text="🤖 AI Difficulty Preset:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=2, column=0, sticky="w", pady=8, padx=5)
    gui.combo_levels = ttk.Combobox(
        grid_frame, textvariable=gui.var_level_name,
        values=list(gui.LEVEL_PRESETS.keys()) + ["Custom"],
        state="readonly", width=32, font=("Segoe UI", 10)
    )
    gui.combo_levels.grid(row=2, column=1, columnspan=2, sticky="w", pady=8, padx=10)
    gui.combo_levels.bind("<<ComboboxSelected>>", gui.on_preset_selected)

    # 4. ELO Adjuster
    tk.Label(grid_frame, text="🎯 Stockfish Target ELO:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=3, column=0, sticky="w", pady=8, padx=5)

    elo_adjust_frame = tk.Frame(grid_frame, bg="white")
    elo_adjust_frame.grid(row=3, column=1, columnspan=2, sticky="w", pady=8, padx=10)

    gui.btn_elo_dec = tk.Button(
        elo_adjust_frame, text="➖ 100", bg="#cfd8dc", font=("Segoe UI", 9, "bold"),
        relief="flat", cursor="hand2", command=lambda: gui.adjust_elo(-100), width=6
    )
    gui.btn_elo_dec.pack(side=tk.LEFT, padx=(0, 5))

    gui.lbl_elo_val = tk.Label(
        elo_adjust_frame, textvariable=gui.var_elo, font=("Courier", 11, "bold"),
        bg="#f5f7f8", fg="#d84315", width=6, relief="groove", bd=1
    )
    gui.lbl_elo_val.pack(side=tk.LEFT, padx=5, ipady=2)

    gui.btn_elo_inc = tk.Button(
        elo_adjust_frame, text="➕ 100", bg="#cfd8dc", font=("Segoe UI", 9, "bold"),
        relief="flat", cursor="hand2", command=lambda: gui.adjust_elo(100), width=6
    )
    gui.btn_elo_inc.pack(side=tk.LEFT, padx=(5, 0))

    # 5. Play Style Settings
    tk.Label(grid_frame, text="⚔️ AI Playing Style:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=4, column=0, sticky="w", pady=8, padx=5)
    gui.combo_play_style = ttk.Combobox(
        grid_frame, textvariable=gui.var_play_style,
        values=["Balanced", "Defensive", "Aggressive"],
        state="readonly", width=15, font=("Segoe UI", 10)
    )
    gui.combo_play_style.grid(row=4, column=1, sticky="w", pady=8, padx=10)

    # 6. Pieces Theme Settings
    tk.Label(grid_frame, text="🎨 Pieces Virtual Theme:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=5, column=0, sticky="w", pady=8, padx=5)
    gui.combo_theme = ttk.Combobox(
        grid_frame, textvariable=gui.var_pieces_theme,
        values=["Standard", "Classic Wood", "Glass Highlight"],
        state="readonly", width=15, font=("Segoe UI", 10)
    )
    gui.combo_theme.grid(row=5, column=1, sticky="w", pady=8, padx=10)

    # 7. Player Color (Play As White or Black)
    tk.Label(grid_frame, text="♟️ Play As:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=6, column=0, sticky="w", pady=8, padx=5)
    gui.combo_player_color = ttk.Combobox(
        grid_frame, textvariable=gui.var_player_color,
        values=["White", "Black"],
        state="readonly", width=15, font=("Segoe UI", 10)
    )
    gui.combo_player_color.grid(row=6, column=1, sticky="w", pady=8, padx=10)
    tk.Label(grid_frame, text="(White: you move first, Black: AI moves first)", bg="white", font=("Segoe UI", 9, "italic"), fg="#546e7a").grid(row=6, column=2, sticky="w", pady=8)

    # 8. Audio Settings
    tk.Label(grid_frame, text="🔊 Audio Effects:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=7, column=0, sticky="w", pady=8, padx=5)
    gui.chk_audio = tk.Checkbutton(
        grid_frame, text="Enable virtual speech & sound effects", variable=gui.var_audio_enabled,
        bg="white", font=("Segoe UI", 10), activebackground="white"
    )
    gui.chk_audio.grid(row=7, column=1, columnspan=2, sticky="w", pady=8, padx=10)

    # Save Settings button at the bottom
    gui.btn_save_settings = tk.Button(
        settings_card, text="💾 SAVE & APPLY CONFIGURATIONS", bg="#2e7d32", fg="white",
        font=("Segoe UI", 11, "bold"), relief="flat", cursor="hand2",
        command=gui.save_game_settings
    )
    gui.btn_save_settings.pack(fill=tk.X, pady=(20, 5), ipady=6)

    # Trigger load settings initially
    gui.load_game_settings()

