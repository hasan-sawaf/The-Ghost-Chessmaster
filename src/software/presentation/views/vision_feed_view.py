import tkinter as tk
from tkinter import ttk, scrolledtext
from src.software.core.constants import DEFAULT_COM_PORT, BAUD_RATE

def build_ui(gui, frame):
    # Header bar
    header = tk.Frame(frame, bg="#37474f", height=45)
    header.pack(fill=tk.X, side=tk.TOP)
    header.pack_propagate(False)

    lbl_title = tk.Label(header, text="📺 LARGE-SCREEN AI & VISION FEEDS MONITOR", font=("Segoe UI", 11, "bold"), fg="white", bg="#37474f")
    lbl_title.pack(side=tk.LEFT, padx=15, fill=tk.Y)

    workspace = tk.Frame(frame, bg="#eef2f5", padx=15, pady=15)
    workspace.pack(fill=tk.BOTH, expand=True)
    workspace.columnconfigure((0, 1), weight=1)
    workspace.rowconfigure((0, 1), weight=1)

    # 1. Tracker Box
    tracker_box = ttk.LabelFrame(workspace, text=" Live Camera Tracker ", padding=6)
    tracker_box.grid(row=0, column=0, sticky="nsew", padx=6, pady=6)
    gui.lbl_tracker_large = tk.Label(tracker_box, text="Camera Offline", bg="#263238", fg="#eceff1", font=("Segoe UI", 12))
    gui.lbl_tracker_large.pack(fill=tk.BOTH, expand=True)

    # 2. Board State Box
    board_box = ttk.LabelFrame(workspace, text=" Digital Board State ", padding=6)
    board_box.grid(row=0, column=1, sticky="nsew", padx=6, pady=6)
    gui.lbl_board_large = tk.Label(board_box, text="Board Offline", bg="#263238", fg="#eceff1", font=("Segoe UI", 12))
    gui.lbl_board_large.pack(fill=tk.BOTH, expand=True)

    # 3. Motion Mask Box
    mask_box = ttk.LabelFrame(workspace, text=" Debug: Motion Mask ", padding=6)
    mask_box.grid(row=1, column=0, sticky="nsew", padx=6, pady=6)
    gui.lbl_debug_mask_large = tk.Label(mask_box, text="Mask Offline", bg="#263238", fg="#eceff1", font=("Segoe UI", 12))
    gui.lbl_debug_mask_large.pack(fill=tk.BOTH, expand=True)

    # 4. Extracted Maps Box
    map_box = ttk.LabelFrame(workspace, text=" Debug: Extracted Maps ", padding=6)
    map_box.grid(row=1, column=1, sticky="nsew", padx=6, pady=6)
    gui.lbl_debug_map_large = tk.Label(map_box, text="Map Offline", bg="#263238", fg="#eceff1", font=("Segoe UI", 12))
    gui.lbl_debug_map_large.pack(fill=tk.BOTH, expand=True)

