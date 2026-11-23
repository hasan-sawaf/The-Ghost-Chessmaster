import tkinter as tk
from tkinter import ttk, scrolledtext
from src.software.core.constants import DEFAULT_COM_PORT, BAUD_RATE

def build_ui(gui, frame):
    # 1. TOP CONTROL BAR
    ctrl_frame = tk.Frame(frame, bg="white", padx=10, pady=8, highlightthickness=1, highlightbackground="#cfd8dc")
    ctrl_frame.pack(fill=tk.X, side=tk.TOP)

    # Port Selection
    tk.Label(ctrl_frame, text="COM Port:", bg="white", font=("Segoe UI", 9, "bold")).pack(side=tk.LEFT, padx=(5, 2))

    gui.var_port = tk.StringVar(value=DEFAULT_COM_PORT)
    gui.combo_ports = ttk.Combobox(ctrl_frame, textvariable=gui.var_port, state="readonly", width=10)
    gui.combo_ports.pack(side=tk.LEFT, padx=5)

    # Baudrate Selection
    tk.Label(ctrl_frame, text="Baud Rate:", bg="white", font=("Segoe UI", 9, "bold")).pack(side=tk.LEFT, padx=(10, 2))

    gui.var_baudrate = tk.StringVar(value=str(BAUD_RATE))
    gui.combo_baudrate = ttk.Combobox(ctrl_frame, textvariable=gui.var_baudrate, values=["9600", "19200", "38400", "57600", "115200"], state="readonly", width=8)
    gui.combo_baudrate.pack(side=tk.LEFT, padx=5)

    # Scan ports button
    btn_scan = tk.Button(ctrl_frame, text="🔄 Scan", bg="#78909c", fg="white", font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2", command=gui.terminal_scan_ports)
    btn_scan.pack(side=tk.LEFT, padx=5, ipady=1)

    # Connect & Disconnect buttons
    gui.btn_serial_connect = tk.Button(ctrl_frame, text="🟢 CONNECT", bg="#2e7d32", fg="white", font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2", command=gui.terminal_connect_serial)
    gui.btn_serial_connect.pack(side=tk.LEFT, padx=5, ipady=1)

    gui.btn_serial_disconnect = tk.Button(ctrl_frame, text="🔴 DISCONNECT", bg="#d32f2f", fg="white", font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2", command=gui.terminal_disconnect_serial)
    gui.btn_serial_disconnect.pack(side=tk.LEFT, padx=5, ipady=1)

    # Clear button
    btn_clear = tk.Button(ctrl_frame, text="🧹 CLEAR CONSOLE", bg="#f57c00", fg="white", font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2", command=gui.terminal_clear_log)
    btn_clear.pack(side=tk.LEFT, padx=10, ipady=1)

    # Status Label
    gui.lbl_serial_status = tk.Label(ctrl_frame, text="🔴 Disconnected", bg="white", font=("Segoe UI", 9, "bold"), fg="#d32f2f")
    gui.lbl_serial_status.pack(side=tk.RIGHT, padx=10)

    # 2. COMMAND INPUT BAR (Bottom)
    cmd_frame = tk.Frame(frame, bg="white", padx=10, pady=8, highlightthickness=1, highlightbackground="#cfd8dc")
    cmd_frame.pack(fill=tk.X, side=tk.BOTTOM)

    tk.Label(cmd_frame, text="Send Command:", bg="white", font=("Segoe UI", 9, "bold")).pack(side=tk.LEFT, padx=(5, 5))

    gui.ent_cmd = tk.Entry(cmd_frame, font=("Consolas", 10), bd=1, relief="solid")
    gui.ent_cmd.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=5, ipady=3)
    gui.ent_cmd.bind("<Return>", lambda event: gui.terminal_send_command())

    gui.btn_send_cmd = tk.Button(cmd_frame, text="✈️ SEND COMMAND", bg="#1976d2", fg="white", font=("Segoe UI", 8, "bold"), relief="flat", cursor="hand2", command=gui.terminal_send_command)
    gui.btn_send_cmd.pack(side=tk.LEFT, padx=5, ipady=2)

    # 2.5 STATUS NOTIFIER BAR
    gui.lbl_terminal_notifier = tk.Label(frame, text="", bg="#eef2f5", font=("Segoe UI", 9, "bold"))
    gui.lbl_terminal_notifier.pack(fill=tk.X, side=tk.BOTTOM, pady=2)

    # 3. TERMINAL DISPLAY (Center)
    gui.log_area = scrolledtext.ScrolledText(frame, bg="#1e1e1e", fg="#76ff03", font=("Consolas", 10), relief="flat", borderwidth=0)
    gui.log_area.pack(fill=tk.BOTH, expand=True, padx=10, pady=8)

