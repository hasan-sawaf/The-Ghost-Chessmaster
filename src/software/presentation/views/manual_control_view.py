import tkinter as tk
from tkinter import ttk, scrolledtext
from src.software.core.constants import DEFAULT_COM_PORT, BAUD_RATE

def build_ui(gui, frame):
    # Header bar
    header = tk.Frame(frame, bg="#37474f", height=45)
    header.pack(fill=tk.X, side=tk.TOP)
    header.pack_propagate(False)

    lbl_title = tk.Label(header, text="🛠️ MANUAL HARDWARE & TASK INJECTION PANEL", font=("Segoe UI", 11, "bold"), fg="white", bg="#37474f")
    lbl_title.pack(side=tk.LEFT, padx=15, fill=tk.Y)

    workspace = tk.Frame(frame, bg="#eef2f5", padx=20, pady=20)
    workspace.pack(fill=tk.BOTH, expand=True)

    # Left Column: Task Injection Card
    left_col = tk.Frame(workspace, bg="#eef2f5", width=340)
    left_col.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 10))

    auto_move = ttk.LabelFrame(left_col, text=" ⚡ Manual Task Injection ", padding=10)
    auto_move.pack(fill=tk.BOTH, expand=True)

    form_frame = tk.Frame(auto_move, bg="white")
    form_frame.pack(fill=tk.X, pady=10)

    tk.Label(form_frame, text="From Square:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=0, column=0, sticky="w", pady=8, padx=5)
    ttk.Combobox(form_frame, textvariable=gui.var_source, values=gui.chess_squares, width=12, font=("Segoe UI", 10)).grid(row=0, column=1, pady=8, padx=10)

    tk.Label(form_frame, text="To Square:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=1, column=0, sticky="w", pady=8, padx=5)
    ttk.Combobox(form_frame, textvariable=gui.var_target, values=gui.chess_squares, width=12, font=("Segoe UI", 10)).grid(row=1, column=1, pady=8, padx=10)

    tk.Label(form_frame, text="Piece Type:", bg="white", font=("Segoe UI", 10, "bold")).grid(row=2, column=0, sticky="w", pady=8, padx=5)
    ttk.Combobox(form_frame, textvariable=gui.var_piece_type, values=["Standard", "Knight"], width=12, font=("Segoe UI", 10)).grid(row=2, column=1, pady=8, padx=10)

    btn_inject = tk.Button(
        auto_move, text="▶ INJECT MOVE SEQUENCE", bg="#2e7d32", fg="white",
        font=("Segoe UI", 10, "bold"), relief="flat", cursor="hand2",
        command=lambda: gui.task_queue.put({'type': 'move', 'src': gui.var_source.get(), 'tgt': gui.var_target.get(), 'piece': gui.var_piece_type.get()})
    )
    btn_inject.pack(fill=tk.X, pady=(20, 5), ipady=5)

    # Right Column: Castling & Tools Cards
    right_col = tk.Frame(workspace, bg="#eef2f5", width=340)
    right_col.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(10, 0))

    # Castling Card
    castling_frame = ttk.LabelFrame(right_col, text=" 🏰 Castling Control Tests ", padding=10)
    castling_frame.pack(fill=tk.X, pady=(0, 15))

    # White Castling Buttons
    tk.Label(castling_frame, text="♔ White Castling Tests:", font=("Segoe UI", 9, "bold"), bg="white", fg="#1565c0").pack(anchor="w", pady=(2, 4))

    btn_w_king = tk.Button(
        castling_frame, text="♔ WHITE KING-SIDE (O-O)", bg="#2e7d32", fg="white",
        font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
        command=lambda: gui.task_queue.put({'type': 'castling', 'side': 'king', 'color': 'white'})
    )
    btn_w_king.pack(fill=tk.X, pady=3, ipady=3)

    btn_w_queen = tk.Button(
        castling_frame, text="♔ WHITE QUEEN-SIDE (O-O-O)", bg="#1565c0", fg="white",
        font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
        command=lambda: gui.task_queue.put({'type': 'castling', 'side': 'queen', 'color': 'white'})
    )
    btn_w_queen.pack(fill=tk.X, pady=3, ipady=3)

    # Black Castling Buttons
    tk.Label(castling_frame, text="♚ Black Castling Tests:", font=("Segoe UI", 9, "bold"), bg="white", fg="#4a148c").pack(anchor="w", pady=(8, 4))

    btn_b_king = tk.Button(
        castling_frame, text="♚ BLACK KING-SIDE (O-O)", bg="#673ab7", fg="white",
        font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
        command=lambda: gui.task_queue.put({'type': 'castling', 'side': 'king', 'color': 'black'})
    )
    btn_b_king.pack(fill=tk.X, pady=3, ipady=3)

    btn_b_queen = tk.Button(
        castling_frame, text="♚ BLACK QUEEN-SIDE (O-O-O)", bg="#4527a0", fg="white",
        font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
        command=lambda: gui.task_queue.put({'type': 'castling', 'side': 'queen', 'color': 'black'})
    )
    btn_b_queen.pack(fill=tk.X, pady=3, ipady=3)

    # Tools Card
    tools = ttk.LabelFrame(right_col, text=" 🛠️ Manual Hardware Controls ", padding=10)
    tools.pack(fill=tk.X, pady=5)

    gui.chk_kill_btn = tk.Checkbutton(
        tools, text="☠️ ARM PIECE KILL MODE", variable=gui.kill_mode_active,
        bg="#ff5252", fg="white", font=("Segoe UI", 9, "bold"), selectcolor="#c62828",
        indicatoron=False, cursor="crosshair"
    )
    gui.chk_kill_btn.pack(fill=tk.X, pady=6, ipady=4)

    btn_home = tk.Button(
        tools, text="🏠 GO HOME (0, 0)", bg="#f57f17", fg="white",
        font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
        command=lambda: gui.send_cmd('H')
    )
    btn_home.pack(fill=tk.X, pady=4, ipady=2)

    btn_mag = tk.Button(
        tools, text="🧲 TOGGLE MAGNET (UP/DOWN)", bg="#0277bd", fg="white",
        font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
        command=gui.toggle_mag
    )
    btn_mag.pack(fill=tk.X, pady=4, ipady=2)

    # Magnet Servo Angle Setting Row
    mag_angle_frame = tk.Frame(tools, bg="white", pady=3)
    mag_angle_frame.pack(fill=tk.X, pady=(6, 2))

    tk.Label(mag_angle_frame, text="🧲 Magnet Angle (°):", bg="white", font=("Segoe UI", 9, "bold"), fg="#0277bd").pack(side=tk.LEFT, padx=(2, 4))
    ent_mag_angle = tk.Entry(mag_angle_frame, textvariable=gui.var_magnet_up_angle, width=5, font=("Segoe UI", 9), justify="center")
    ent_mag_angle.pack(side=tk.LEFT, padx=(0, 4))
    ent_mag_angle.bind("<Return>", lambda e: gui.set_magnet_angle())

    btn_set_mag = tk.Button(
        mag_angle_frame, text="⚙️ Set", bg="#0277bd", fg="white",
        font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2",
        activebackground="#01579b", activeforeground="white", padx=6, pady=1,
        command=gui.set_magnet_angle
    )
    btn_set_mag.pack(side=tk.LEFT, padx=2)

    # Quick preset buttons (90° / 100°)
    btn_90 = tk.Button(
        mag_angle_frame, text="90°", bg="#eceff1", fg="#37474f",
        font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2",
        padx=4, pady=1, command=lambda: gui.set_magnet_angle(90)
    )
    btn_90.pack(side=tk.LEFT, padx=(4, 2))

    btn_100 = tk.Button(
        mag_angle_frame, text="100°", bg="#eceff1", fg="#37474f",
        font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2",
        padx=4, pady=1, command=lambda: gui.set_magnet_angle(100)
    )
    btn_100.pack(side=tk.LEFT, padx=2)

    # Direct G-Code Coordinate Card
    gcode_card = ttk.LabelFrame(right_col, text=" 🎯 Direct G-Code (processGCode) ", padding=10)
    gcode_card.pack(fill=tk.X, pady=5)

    gc_inputs = tk.Frame(gcode_card, bg="white")
    gc_inputs.pack(fill=tk.X, pady=4)

    tk.Label(gc_inputs, text="X (mm):", bg="white", font=("Segoe UI", 9, "bold"), fg="#1976d2").grid(row=0, column=0, padx=4, pady=4, sticky="w")
    ent_x = tk.Entry(gc_inputs, textvariable=gui.var_target_gcode_x, width=8, font=("Segoe UI", 10), justify="center")
    ent_x.grid(row=0, column=1, padx=6, pady=4)
    ent_x.bind("<Return>", lambda e: gui.processGCode())

    tk.Label(gc_inputs, text="Y (mm):", bg="white", font=("Segoe UI", 9, "bold"), fg="#1976d2").grid(row=0, column=2, padx=4, pady=4, sticky="w")
    ent_y = tk.Entry(gc_inputs, textvariable=gui.var_target_gcode_y, width=8, font=("Segoe UI", 10), justify="center")
    ent_y.grid(row=0, column=3, padx=6, pady=4)
    ent_y.bind("<Return>", lambda e: gui.processGCode())

    btn_exec = tk.Button(
        gcode_card, text="🚀 EXECUTE G-CODE (processGCode)", bg="#1976d2", fg="white",
        font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
        activebackground="#1565c0", activeforeground="white",
        command=gui.processGCode
    )
    btn_exec.pack(fill=tk.X, pady=(6, 2), ipady=3)

