import tkinter as tk
from tkinter import ttk, scrolledtext
import datetime
import json
import os
try:
    import qrcode
except ImportError:
    qrcode = None
from PIL import Image, ImageTk

def _get_local_board_config():
    """Loads board configuration from JSON file without making any network calls."""
    try:
        current_dir = os.path.dirname(os.path.abspath(__file__))
        config_file_path = os.path.abspath(os.path.join(current_dir, "..", "..", "infrastructure", "persistence", "config", "board_config.json"))
        if os.path.exists(config_file_path):
            with open(config_file_path, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return {
        "board_id": "BOARD_8AA5C5",
        "board_name": "BoardOne",
        "rtdb_url": "https://YOUR_FIREBASE_PROJECT_ID-default-rtdb.firebaseio.com/BOARD_8AA5C5"
    }

def build_ui(gui, frame):
    fm = getattr(gui, 'firebase_manager', None)
    if fm is not None:
        board_id = fm.board_id
        board_name = fm.board_name
        qr_payload = fm.get_qr_payload_json()
    else:
        cfg = _get_local_board_config()
        board_id = cfg.get("board_id", "BOARD_8AA5C5")
        board_name = cfg.get("board_name", "BoardOne")
        qr_payload = json.dumps(cfg)

    # Top Header bar
    header = tk.Frame(frame, bg="#1b5e20", height=45)
    header.pack(fill=tk.X, side=tk.TOP)
    header.pack_propagate(False)

    lbl_title = tk.Label(
        header,
        text="📶 FIREBASE BOARD CONNECTION & REALTIME LINK",
        font=("Segoe UI", 11, "bold"),
        fg="white",
        bg="#1b5e20"
    )
    lbl_title.pack(side=tk.LEFT, padx=15, fill=tk.Y)

    workspace = tk.Frame(frame, bg="#eef2f5", padx=15, pady=15)
    workspace.pack(fill=tk.BOTH, expand=True)

    # ─────────────────────────────────────────────────────────────
    # Left Column: QR Code & Board Details Card
    # ─────────────────────────────────────────────────────────────
    left_col = tk.Frame(workspace, bg="#eef2f5", width=360)
    left_col.pack(side=tk.LEFT, fill=tk.BOTH, expand=False, padx=(0, 10))

    qr_card = ttk.LabelFrame(left_col, text=" 📲 Board QR Code (Scan to Connect) ", padding=12)
    qr_card.pack(fill=tk.BOTH, expand=True)

    # Generate QR Code image
    if qrcode is not None:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=6,
            border=3,
        )
        qr.add_data(qr_payload)
        qr.make(fit=True)
        pil_img = qr.make_image(fill_color="#1b5e20", back_color="white")
        qr_photo = ImageTk.PhotoImage(pil_img)
        lbl_qr = tk.Label(qr_card, image=qr_photo, bg="white", bd=2, relief="solid")
        lbl_qr.image = qr_photo
        lbl_qr.pack(pady=(5, 10))
    else:
        lbl_qr = tk.Label(qr_card, text=f"QR Payload:\n{qr_payload}", bg="white", fg="#333333", font=("Consolas", 8), bd=2, relief="solid", padx=10, pady=10)
        lbl_qr.pack(pady=(5, 10))

    # Board Details Info Box
    info_frame = tk.Frame(qr_card, bg="#f5f5f5", padx=10, pady=8, bd=1, relief="groove")
    info_frame.pack(fill=tk.X, pady=5)

    lbl_id = tk.Label(info_frame, text=f"🆔 Board ID: {board_id}", font=("Segoe UI", 10, "bold"), bg="#f5f5f5", fg="#1b5e20", anchor="w")
    lbl_id.pack(fill=tk.X)

    lbl_name = tk.Label(info_frame, text=f"🏷️ Board Name: {board_name}", font=("Segoe UI", 9, "bold"), bg="#f5f5f5", fg="#37474f", anchor="w")
    lbl_name.pack(fill=tk.X, pady=(2, 0))

    lbl_rtdb = tk.Label(info_frame, text=f"🌐 RTDB Node: /{board_name}", font=("Consolas", 8), bg="#f5f5f5", fg="#555555", anchor="w")
    lbl_rtdb.pack(fill=tk.X, pady=(2, 0))

    # ─────────────────────────────────────────────────────────────
    # Right Column: User Connection Status & Action Console
    # ─────────────────────────────────────────────────────────────
    right_col = tk.Frame(workspace, bg="#eef2f5")
    right_col.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

    # 1. Connected User Status Card
    user_card = ttk.LabelFrame(right_col, text=" 👤 Connected Mobile User Status ", padding=12)
    user_card.pack(fill=tk.X, pady=(0, 10))

    status_header_frame = tk.Frame(user_card, bg="#ffffff", padx=12, pady=10, bd=1, relief="solid")
    status_header_frame.pack(fill=tk.X)

    lbl_conn_indicator = tk.Label(
        status_header_frame,
        text="🔴 DISCONNECTED",
        font=("Segoe UI", 11, "bold"),
        fg="#d32f2f",
        bg="#ffffff"
    )
    lbl_conn_indicator.pack(side=tk.LEFT)

    lbl_conn_email = tk.Label(
        status_header_frame,
        text="Waiting for mobile app user scan...",
        font=("Segoe UI", 10, "italic"),
        fg="#757575",
        bg="#ffffff"
    )
    lbl_conn_email.pack(side=tk.RIGHT, padx=10)

    # 1.5 Active Match Settings Card (Synced from Mobile App)
    match_card = ttk.LabelFrame(right_col, text=" 🎮 Active Match Settings (Synced from App) ", padding=12)
    match_card.pack(fill=tk.X, pady=(0, 10))

    match_info_frame = tk.Frame(match_card, bg="#ffffff", padx=12, pady=8, bd=1, relief="solid")
    match_info_frame.pack(fill=tk.X)

    lbl_match_timer = tk.Label(
        match_info_frame,
        text="⏱️ Timer: 10m + 2s",
        font=("Segoe UI", 9, "bold"),
        fg="#1b5e20",
        bg="#ffffff"
    )
    lbl_match_timer.pack(side=tk.LEFT, padx=(0, 15))

    lbl_match_elo = tk.Label(
        match_info_frame,
        text="🧠 AI: Lvl 7 (1500 ELO)",
        font=("Segoe UI", 9, "bold"),
        fg="#0d47a1",
        bg="#ffffff"
    )
    lbl_match_elo.pack(side=tk.LEFT, padx=(0, 15))

    lbl_match_color = tk.Label(
        match_info_frame,
        text="♚ Player: White",
        font=("Segoe UI", 9, "bold"),
        fg="#37474f",
        bg="#ffffff"
    )
    lbl_match_color.pack(side=tk.LEFT, padx=(0, 15))

    lbl_match_style = tk.Label(
        match_info_frame,
        text="🎯 Style: Balanced",
        font=("Segoe UI", 9, "bold"),
        fg="#e65100",
        bg="#ffffff"
    )
    lbl_match_style.pack(side=tk.LEFT)

    # 2. Real-time Firebase Message Console
    console_card = ttk.LabelFrame(right_col, text=" 📥 Real-time Board Signal Console ", padding=10)
    console_card.pack(fill=tk.BOTH, expand=True)

    log_area = scrolledtext.ScrolledText(console_card, bg="#1e1e1e", fg="#00e676", font=("Consolas", 9), relief="flat")
    log_area.pack(fill=tk.BOTH, expand=True, pady=(0, 8))

    def log_text(msg):
        def _do_log():
            try:
                timestamp = datetime.datetime.now().strftime("%H:%M:%S")
                log_area.insert(tk.END, f"[{timestamp}] {msg}\n")
                log_area.see(tk.END)
            except Exception:
                pass
        if hasattr(gui, 'root') and gui.root:
            gui.root.after(0, _do_log)
        else:
            print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] {msg}")

    def on_connection_changed(data):
        def _update():
            try:
                if data and isinstance(data, dict):
                    status = str(data.get('status', 'disconnected')).lower()
                    user_id = data.get('connected_user_id') or data.get('user_id') or data.get('userId')
                    email = data.get('connected_user_email') or data.get('user_email') or user_id
                    is_conn = (status == 'connected') and bool(user_id)
                    if is_conn:
                        display_email = email if email else "Connected User"
                        lbl_conn_indicator.config(text="🟢 CONNECTED", fg="#2e7d32")
                        lbl_conn_email.config(text=f"User: {display_email}", font=("Segoe UI", 10, "bold"), fg="#1b5e20")
                        log_text(f"[CONNECTION] 🟢 Mobile User Connected: {display_email}")
                    else:
                        lbl_conn_indicator.config(text="🔴 DISCONNECTED", fg="#d32f2f")
                        lbl_conn_email.config(text="Waiting for mobile app user scan...", font=("Segoe UI", 10, "italic"), fg="#757575")
                        log_text("[CONNECTION] 🔴 User Disconnected.")
                else:
                    lbl_conn_indicator.config(text="🔴 DISCONNECTED", fg="#d32f2f")
                    lbl_conn_email.config(text="Waiting for mobile app user scan...", font=("Segoe UI", 10, "italic"), fg="#757575")
                    log_text("[CONNECTION] 🔴 User Disconnected.")
            except Exception:
                pass
        if hasattr(gui, 'root') and gui.root:
            gui.root.after(0, _update)

    def on_live_session_changed(data):
        def _update_session():
            try:
                if data and isinstance(data, dict):
                    timer_sec = data.get('timer', 600)
                    inc_sec = data.get('inc_time', 2)
                    is_white = data.get('is_white', True)
                    difficulty = data.get('difficulty')
                    elo = data.get('elo')
                    play_style = data.get('play_style', 'Balanced')

                    if hasattr(gui, 'resolve_ai_level_and_elo'):
                        final_elo, preset_name = gui.resolve_ai_level_and_elo(difficulty=difficulty, elo=elo)
                    else:
                        final_elo = elo or 1500
                        preset_name = f"Lvl {difficulty or 7}: ({final_elo} ELO)"

                    timer_min = int(timer_sec) // 60
                    color_str = "White" if is_white else "Black"

                    lbl_match_timer.config(text=f"⏱️ Timer: {timer_min}m + {inc_sec}s")
                    lvl_num = difficulty if difficulty is not None else 7
                    lbl_match_elo.config(text=f"🧠 AI: Lvl {lvl_num} ({final_elo} ELO)")
                    lbl_match_color.config(text=f"♚ Player: {color_str}")
                    lbl_match_style.config(text=f"🎯 Style: {play_style}")
                    log_text(f"[LIVE SESSION] 🎮 Match Settings Synced: {timer_min}m+{inc_sec}s | Lvl {lvl_num} ({final_elo} ELO) | Player: {color_str} | Style: {play_style}")
            except Exception:
                pass
        if hasattr(gui, 'root') and gui.root:
            gui.root.after(0, _update_session)

    def on_action_received(data):
        if data and isinstance(data, dict):
            action = data.get('action')
            sender = data.get('sender', 'Mobile App')
            log_text(f"[SIGNAL] 📱 App Action Received from {sender}: {action} -> {data}")

    def on_firebase_connected(active_fm):
        if active_fm and getattr(active_fm, 'connected', False):
            log_text(f"[SYSTEM] Firebase connected for Board '{active_fm.board_name}' (ID: {active_fm.board_id}).")
            log_text("[SYSTEM] QR Code payload active & listening for app actions...")

    gui._firebase_test_view_on_connected = on_firebase_connected
    gui._firebase_test_view_on_user_conn = on_connection_changed
    gui._firebase_test_view_on_live_session = on_live_session_changed
    gui._firebase_test_view_on_action = on_action_received

    # Start Realtime Firebase Connection & Action Listeners if ready
    if fm is not None and getattr(fm, 'connected', False):
        on_firebase_connected(fm)
    else:
        log_text("[STATUS] Board configuration loaded. Waiting for Firebase connection...")

    btn_clear = tk.Button(
        console_card, text="🧹 Clear Console", bg="#78909c", fg="white",
        font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
        command=lambda: log_area.delete("1.0", tk.END)
    )
    btn_clear.pack(side=tk.RIGHT, pady=2, padx=5)
