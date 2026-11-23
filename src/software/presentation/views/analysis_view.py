#!/usr/bin/env python
import tkinter as tk
from tkinter import messagebox, ttk, scrolledtext
import threading
import queue
import os
import chess

from src.software.application.use_cases.analyze_match import analyze_game_moves
from src.software.domain.rules.game_rules import get_mate_phrase

from src.software.presentation.components.virtual_board import BoardMixin
from src.software.presentation.components.analysis_report import ReportMixin
from src.software.presentation.components.stats_card import CardsMixin

import sys
if getattr(sys, 'frozen', False):
    ROOT_DIR = getattr(sys, '_MEIPASS', os.path.dirname(sys.executable))
else:
    ROOT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
ENGINE_PATH = os.path.join(ROOT_DIR, "src", "software", "infrastructure", "ai", "stockfish-windows-x86-64-avx2.exe")

DEFAULT_PGN = ""

CLASSIFICATION_DESCRIPTIONS = {
    "Brilliant": "Exceptional, hard-to-find move (often a sacrifice)",
    "Best": "The absolute strongest move available in the position",
    "Excellent": "Very strong move — nearly perfect choice",
    "Good": "Solid move — good positional choice with minor alternatives",
    "Book": "Standard opening theory book move",
    "Inaccuracy": "Minor slip — small advantage or tempo lost",
    "Mistake": "Significant error — positional disadvantage or material lost",
    "Blunder": "Major game-changing error — large advantage or critical piece lost"
}

class AnalysisApp(BoardMixin, ReportMixin, CardsMixin):
    def __init__(self, parent_frame, main_gui=None):
        self.frame = parent_frame
        self.main_gui = main_gui
        self.root = parent_frame.winfo_toplevel()

        self.gui_queue = queue.Queue()
        self.is_analyzing = False
        self.is_playing = False
        self.play_timer_id = None
        self.moves_data = []
        self.current_move_idx = -1 # -1 represents initial starting board position
        self.last_report = None
        
        self.setup_styles()
        self.load_piece_images()
        self.load_icons()
        self.build_ui()
        
        # Draw initial blank board
        self.draw_board_state()
        
        # Start queue poller
        self.root.after(100, self.poll_queue)

    def setup_styles(self):
        style = ttk.Style()
        try:
            style.theme_use("clam")
        except Exception:
            pass
        style.configure("TLabelframe", background="#ffffff", bordercolor="#cfd8dc", borderwidth=1)
        style.configure("TLabelframe.Label", font=("Segoe UI", 10, "bold"), background="#ffffff", foreground="#37474f")
        style.configure("TLabel", background="#ffffff", font=("Segoe UI", 9))
        style.configure("Treeview.Heading", font=("Segoe UI", 9, "bold"))
        style.configure("Treeview", font=("Segoe UI", 9), rowheight=26)

    def load_piece_images(self):
        self.piece_images = {}
        img_size = 30 # Centered in 36px square
        piece_symbols = ["P", "N", "B", "R", "Q", "K"]
        images_dir = os.path.join(ROOT_DIR, "src", "software", "presentation", "assets")
        
        try:
            from PIL import Image, ImageTk
            
            # Load White
            white_dir = os.path.join(images_dir, "white_pieces")
            for sym in piece_symbols:
                path = os.path.join(white_dir, f"W{sym}.png")
                if os.path.exists(path):
                    img = Image.open(path).resize((img_size, img_size), Image.Resampling.LANCZOS)
                    self.piece_images[f"W{sym}"] = ImageTk.PhotoImage(img)
                    
            # Load Black
            black_dir = os.path.join(images_dir, "black_pieces")
            for sym in piece_symbols:
                path = os.path.join(black_dir, f"B{sym}.png")
                if os.path.exists(path):
                    img = Image.open(path).resize((img_size, img_size), Image.Resampling.LANCZOS)
                    self.piece_images[f"B{sym}"] = ImageTk.PhotoImage(img)
            
            print(f"[INFO] Loaded {len(self.piece_images)} piece images from {images_dir}")
        except Exception as e:
            print(f"[WARNING] Could not load piece images via PIL: {e}. Using text fallback.")

    def load_icons(self):
        """Loads and resizes move quality icons for board overlays and legending."""
        self.board_icons = {}
        self.legend_icons = {}
        
        icon_files = {
            "Brilliant": "brilliant_32x.png",
            "Best": "best_32x.png",
            "Excellent": "excellent_32x.png",
            "Good": "good_32x.png",
            "Book": "book_32x.png",
            "Inaccuracy": "inaccuracy_32x.png",
            "Mistake": "mistake_32x.png",
            "Blunder": "blunder_32x.png",
            "Alternative": "alternative_32x.png"
        }
        
        icons_dir = os.path.join(ROOT_DIR, "src", "software", "presentation", "assets", "icons", "32x")
        
        try:
            from PIL import Image, ImageTk
            for name, filename in icon_files.items():
                path = os.path.join(icons_dir, filename)
                if os.path.exists(path):
                    # Load board & table row icon size (18x18 pixels)
                    img_board = Image.open(path).resize((18, 18), Image.Resampling.LANCZOS)
                    self.board_icons[name] = ImageTk.PhotoImage(img_board)
                    
                    # Load legend & detail card size (20x20 pixels)
                    img_legend = Image.open(path).resize((20, 20), Image.Resampling.LANCZOS)
                    self.legend_icons[name] = ImageTk.PhotoImage(img_legend)
            print(f"[INFO] Loaded {len(self.board_icons)} icon assets from {icons_dir}")
        except Exception as e:
            print(f"[WARNING] Could not load icon assets: {e}")

    def build_ui(self):
        # 1. TOP FRAME: PGN input and button controls
        top_frame = ttk.LabelFrame(self.frame, text=" 📝 PGN & Game Info ", padding=8)
        top_frame.pack(fill=tk.X, padx=10, pady=(10, 4))

        pgn_container = tk.Frame(top_frame, bg="white")
        pgn_container.pack(fill=tk.X, side=tk.TOP, pady=(0, 3))
        pgn_container.columnconfigure(0, weight=1)
        pgn_container.columnconfigure(1, weight=1)

        pgn_frame = tk.Frame(pgn_container, bg="white")
        pgn_frame.grid(row=0, column=0, sticky="nsew", padx=(0, 2))
        tk.Label(pgn_frame, text="In Game Now PGN:", bg="white", font=("Segoe UI", 8, "bold")).pack(anchor="w")
        self.txt_pgn = scrolledtext.ScrolledText(pgn_frame, height=4, font=("Consolas", 10), wrap=tk.WORD)
        self.txt_pgn.pack(fill=tk.BOTH, expand=True)
        self.txt_pgn.insert(tk.END, DEFAULT_PGN)

        tags_frame = tk.Frame(pgn_container, bg="white")
        tags_frame.grid(row=0, column=1, sticky="nsew", padx=(2, 0))
        tk.Label(tags_frame, text="Saved Game Tags:", bg="white", font=("Segoe UI", 8, "bold")).pack(anchor="w")
        self.txt_tags = scrolledtext.ScrolledText(tags_frame, height=4, font=("Consolas", 10), wrap=tk.WORD)
        self.txt_tags.pack(fill=tk.BOTH, expand=True)
        self.txt_tags.insert(tk.END, "Not auto-saving. Click 'Save Next Played Game' to configure.")
        self.txt_tags.config(state=tk.DISABLED)

        ctrl_bar = tk.Frame(top_frame, bg="white")
        ctrl_bar.pack(fill=tk.X, side=tk.BOTTOM)

        self.btn_run = tk.Button(
            ctrl_bar, text="🔍 DEEP GAME ANALYSIS", bg="#2e7d32", fg="white", 
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", command=self.start_analysis
        )
        self.btn_run.pack(side=tk.LEFT, ipady=3, padx=(0, 8))

        self.btn_report = tk.Button(
            ctrl_bar, text="📋 GENERATE TEXT REPORT", bg="#0288d1", fg="white", 
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", 
            state=tk.DISABLED, command=self.show_text_report
        )
        self.btn_report.pack(side=tk.LEFT, ipady=3, padx=8)

        self.btn_save_analysis = tk.Button(
            ctrl_bar, text="💾 SAVE ANALYSIS", bg="#43a047", fg="white", 
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", 
            state=tk.DISABLED, command=self.save_manual_analysis
        )
        self.btn_save_analysis.pack(side=tk.LEFT, ipady=3, padx=8)

        self.lbl_progress = tk.Label(ctrl_bar, text="Ready.", bg="white", font=("Segoe UI", 9, "italic"), fg="#546e7a")
        self.lbl_progress.pack(side=tk.LEFT, padx=10)

        self.progress_bar = ttk.Progressbar(ctrl_bar, orient="horizontal", mode="determinate", length=150)
        self.progress_bar.pack(side=tk.RIGHT, pady=3)

        # 2. MIDDLE FRAME: Player cards (Accuracy & Stat Breakdowns)
        cards_frame = tk.Frame(self.frame, bg="#f4f6f9")
        cards_frame.pack(fill=tk.X, padx=10, pady=2)

        # Build player cards using CardsMixin
        self.build_player_cards(cards_frame)

        # 3. BOTTOM WORKSPACE: Left (Table), Center (Board & Controls), Right (Legend)
        workspace = tk.Frame(self.frame, bg="#f4f6f9")
        workspace.pack(fill=tk.BOTH, expand=True, padx=10, pady=(3, 10))

        # Left Column: Move List Table
        table_frame = ttk.LabelFrame(workspace, text=" 📊 Game Moves List ", padding=4)
        table_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 4))

        cols = ("Move #", "Player", "Played Move", "Evaluation")
        self.tree = ttk.Treeview(table_frame, columns=cols, show="tree headings", selectmode="browse")
        
        self.tree.heading("#0", text="Classification")
        self.tree.column("#0", width=115, anchor="w")
        
        self.tree.heading("Move #", text="Move #")
        self.tree.column("Move #", width=45, anchor="center")
        self.tree.heading("Player", text="Player")
        self.tree.column("Player", width=50, anchor="center")
        self.tree.heading("Played Move", text="Played Move")
        self.tree.column("Played Move", width=75, anchor="center")
        self.tree.heading("Evaluation", text="Evaluation")
        self.tree.column("Evaluation", width=75, anchor="center")

        scrollbar_y = ttk.Scrollbar(table_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=scrollbar_y.set)
        
        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar_y.pack(side=tk.RIGHT, fill=tk.Y)

        self.tree.bind("<<TreeviewSelect>>", self.on_move_selected)

        # Center Column: Visual Chessboard & Controls
        board_column = tk.Frame(workspace, bg="#f4f6f9")
        board_column.pack(side=tk.LEFT, fill=tk.BOTH, padx=3)

        self.board_header_frame = tk.Frame(board_column, bg="#f4f6f9")
        lbl_title = tk.Label(self.board_header_frame, text=" ♟️ Visual Position Board ", font=("Segoe UI", 9, "bold"), fg="#37474f", bg="#f4f6f9")
        lbl_title.pack(side=tk.LEFT)
        self.lbl_board_status = tk.Label(self.board_header_frame, text="", font=("Segoe UI", 9, "bold"), fg="#d32f2f", bg="#f4f6f9")
        self.lbl_board_status.pack(side=tk.LEFT, padx=5)

        board_card = ttk.LabelFrame(board_column, labelwidget=self.board_header_frame, padding=5)
        board_card.pack(fill=tk.X)

        # Board layout frame for Eval Bar + Board
        board_layout = tk.Frame(board_card, bg="white")
        board_layout.pack(pady=4)

        # Advantage Eval Bar Canvas (20 width, 288 height - matches chessboard height exactly!)
        self.canvas_eval = tk.Canvas(board_layout, width=20, height=288, bg="#212121", highlightthickness=1, highlightbackground="#cfd8dc")
        self.canvas_eval.pack(side=tk.LEFT, padx=(0, 8), anchor="n")

        # Canvas Size: 36 pixels * 8 + 20 rank margin = 308 pixels width, 308 height
        self.canvas_board = tk.Canvas(board_layout, width=308, height=308, bg="#f4f6f9", highlightthickness=0)
        self.canvas_board.pack(side=tk.LEFT)

        # Step Navigation Controls
        nav_frame = tk.Frame(board_card, bg="white")
        nav_frame.pack(fill=tk.X, pady=(6, 0))

        self.btn_prev = tk.Button(
            nav_frame, text="⏪ Prev", bg="#78909c", fg="white", 
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", width=8, command=self.prev_move
        )
        self.btn_prev.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(0, 2), ipady=3)

        self.btn_play = tk.Button(
            nav_frame, text="▶ Play", bg="#4caf50", fg="white", 
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", width=8, command=self.toggle_play
        )
        self.btn_play.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=2, ipady=3)

        self.btn_next = tk.Button(
            nav_frame, text="Next ⏩", bg="#1976d2", fg="white", 
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2", width=8, command=self.next_move
        )
        self.btn_next.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(2, 0), ipady=3)

        # Selected Move Details inspector
        self.details_card = ttk.LabelFrame(board_column, text=" 🔍 Selected Move Analysis ", padding=10)
        self.details_card.pack(fill=tk.BOTH, expand=True, pady=(8, 0))

        # Detail header (icon + title)
        detail_header = tk.Frame(self.details_card, bg="white")
        detail_header.pack(fill=tk.X, anchor="w")

        self.lbl_selected_icon = tk.Label(detail_header, bg="white")
        self.lbl_selected_icon.pack(side=tk.LEFT, padx=(0, 5))

        self.lbl_selected_title = tk.Label(detail_header, text="Start of game position.", font=("Segoe UI", 10, "bold"), fg="#37474f", bg="white")
        self.lbl_selected_title.pack(side=tk.LEFT, fill=tk.X, expand=True, anchor="w")

        self.lbl_selected_desc = tk.Label(self.details_card, text="Please paste a PGN and click run to analyze.", font=("Segoe UI", 9, "italic"), fg="#546e7a", bg="white", justify=tk.LEFT, wraplength=320)
        self.lbl_selected_desc.pack(anchor="w", pady=5)

        # Engine recommendation frame (Alternative Move icon + text)
        self.engine_frame = tk.Frame(self.details_card, bg="white")
        self.engine_frame.pack(fill=tk.X, anchor="w", pady=(2, 0))

        self.lbl_alternative_icon = tk.Label(self.engine_frame, bg="white")
        self.lbl_alternative_icon.pack(side=tk.LEFT, padx=(0, 5), anchor="n")

        self.lbl_selected_engine = tk.Label(self.engine_frame, text="", font=("Segoe UI", 9), fg="#212121", bg="white", justify=tk.LEFT)
        self.lbl_selected_engine.pack(side=tk.LEFT, fill=tk.X, expand=True, anchor="w")

        # Right Column: Categories Legend & Saved History Sidebar
        side_frame = tk.Frame(workspace, bg="#f4f6f9", width=340)
        side_frame.pack(side=tk.RIGHT, fill=tk.BOTH, padx=(5, 0))

        legend_card = ttk.LabelFrame(side_frame, text=" 📖 Chess Move Classifications ", padding=6)
        legend_card.pack(fill=tk.BOTH, expand=True)

        legend_container = tk.Canvas(legend_card, bg="white", bd=0, highlightthickness=0)
        legend_container.pack(fill=tk.BOTH, expand=True)

        row_idx = 0
        for name, desc in CLASSIFICATION_DESCRIPTIONS.items():
            color_map = self.get_class_colors(name)
            
            # Column 0: Icon Image
            if name in self.legend_icons:
                lbl_icon = tk.Label(legend_container, image=self.legend_icons[name], bg="white")
            else:
                lbl_icon = tk.Label(legend_container, text="", bg="white")
            lbl_icon.grid(row=row_idx, column=0, sticky="w", pady=1, padx=(0, 4))

            # Column 1: Color Name Badge
            lbl_badge = tk.Label(
                legend_container, text=f" {name} ", bg=color_map["bg"], fg=color_map["fg"], 
                font=("Segoe UI", 8, "bold"), relief="flat", width=10
            )
            lbl_badge.grid(row=row_idx, column=1, sticky="w", pady=1, padx=(0, 4))
            
            # Column 2: Description text
            lbl_desc = tk.Label(
                legend_container, text=desc, font=("Segoe UI", 7), 
                fg="#37474f", bg="white", justify=tk.LEFT, wraplength=170
            )
            lbl_desc.grid(row=row_idx, column=2, sticky="w", pady=1)
            row_idx += 1

        if "Alternative" in self.legend_icons:
            lbl_alt_icon = tk.Label(legend_container, image=self.legend_icons["Alternative"], bg="white")
            lbl_alt_icon.grid(row=row_idx, column=0, sticky="w", pady=1, padx=(0, 4))

            lbl_alt_badge = tk.Label(
                legend_container, text=" Alternative ", bg="#e1f5fe", fg="#0288d1", 
                font=("Segoe UI", 8, "bold"), relief="flat", width=10
            )
            lbl_alt_badge.grid(row=row_idx, column=1, sticky="w", pady=1, padx=(0, 4))

            lbl_alt_desc = tk.Label(
                legend_container, text="Alternative best suggestion", font=("Segoe UI", 7), 
                fg="#37474f", bg="white", justify=tk.LEFT, wraplength=170
            )
            lbl_alt_desc.grid(row=row_idx, column=2, sticky="w", pady=1)

        # History Sidebar Card
        history_card = ttk.LabelFrame(side_frame, text=" 💾 Saved Games History ", padding=6)
        history_card.pack(fill=tk.BOTH, expand=True, pady=(6, 0))

        self.lst_history = tk.Listbox(history_card, font=("Segoe UI", 9), bd=0, highlightthickness=0, bg="white")
        self.lst_history.pack(fill=tk.BOTH, expand=True)
        self.lst_history.bind("<<ListboxSelect>>", self.on_history_game_selected)

        self.btn_delete_history = tk.Button(
            history_card, text="🗑️ DELETE GAME", bg="#e53935", fg="white",
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
            command=self.delete_selected_history
        )
        self.btn_delete_history.pack(fill=tk.X, pady=(5, 0), ipady=2)

        # Treeview Tag Configurations
        self.tree.tag_configure("brilliant", background="#f3e5f5", foreground="#8e24aa")
        self.tree.tag_configure("best", background="#e0f2f1", foreground="#004d40")
        self.tree.tag_configure("excellent", background="#e8f5e9", foreground="#2e7d32")
        self.tree.tag_configure("good", background="#e3f2fd", foreground="#1565c0")
        self.tree.tag_configure("book", background="#efebe9", foreground="#4e342e")
        self.tree.tag_configure("inaccuracy", background="#fffde7", foreground="#f57f17")
        self.tree.tag_configure("mistake", background="#fff3e0", foreground="#ef6c00")
        self.tree.tag_configure("blunder", background="#ffebee", foreground="#c62828")

    def get_class_colors(self, name):
        colors = {
            "Brilliant": {"bg": "#f3e5f5", "fg": "#8e24aa"},
            "Best": {"bg": "#e0f2f1", "fg": "#004d40"},
            "Excellent": {"bg": "#e8f5e9", "fg": "#2e7d32"},
            "Good": {"bg": "#e3f2fd", "fg": "#1565c0"},
            "Book": {"bg": "#efebe9", "fg": "#4e342e"},
            "Inaccuracy": {"bg": "#fffde7", "fg": "#f57f17"},
            "Mistake": {"bg": "#fff3e0", "fg": "#ef6c00"},
            "Blunder": {"bg": "#ffebee", "fg": "#c62828"}
        }
        return colors.get(name, {"bg": "#ffffff", "fg": "#000000"})

    def poll_queue(self):
        try:
            while True:
                task = self.gui_queue.get_nowait()
                task()
        except queue.Empty:
            pass
        self.root.after(100, self.poll_queue)

    def start_analysis(self):
        if self.is_analyzing:
            return

        if self.is_playing:
            self.toggle_play()

        pgn_str = self.txt_pgn.get("1.0", tk.END).strip()
        if not pgn_str:
            messagebox.showwarning("Warning", "Please paste a chess PGN game string first.")
            return

        if not os.path.exists(ENGINE_PATH):
            messagebox.showerror("Error", f"Stockfish binary not found at:\n{ENGINE_PATH}\n\nPlease place it.")
            return

        self.is_analyzing = True
        self.btn_run.config(state=tk.DISABLED, bg="#9e9e9e")
        self.btn_report.config(state=tk.DISABLED, bg="#9e9e9e")
        self.btn_save_analysis.config(state=tk.DISABLED, bg="#9e9e9e")
        self.lbl_progress.config(text="Initializing engine...")
        self.progress_bar["value"] = 0
        self.moves_data = []
        self.current_move_idx = -1
        self.last_report = None

        for row in self.tree.get_children():
            self.tree.delete(row)
        
        self.draw_board_state()

        threading.Thread(target=self._analysis_worker, args=(pgn_str, 20), daemon=True).start()

    def _analysis_worker(self, pgn_str, depth):
        def callback(current, total):
            pct = int((current / total) * 100)
            self.gui_queue.put(lambda: self.lbl_progress.config(text=f"Analyzing move {current} of {total}..."))
            self.gui_queue.put(lambda: self.progress_bar.configure(value=pct))

        try:
            report = analyze_game_moves(pgn_str, ENGINE_PATH, depth, callback)
            self.gui_queue.put(lambda: self.display_report(report))
        except Exception as e:
            self.gui_queue.put(lambda: messagebox.showerror("Analysis Error", str(e)))
        finally:
            self.gui_queue.put(self._analysis_finished)

    def _analysis_finished(self):
        self.is_analyzing = False
        self.btn_run.config(state=tk.NORMAL, bg="#2e7d32")
        self.lbl_progress.config(text="Analysis complete!")
        if self.moves_data:
            self.btn_report.config(state=tk.NORMAL, bg="#0288d1")
            self.btn_save_analysis.config(state=tk.NORMAL, bg="#43a047")

    def display_report(self, report):
        self.last_report = report
        
        # Populate player cards using CardsMixin
        self.update_player_cards(report)

        self.moves_data = report["moves"]
        self.current_move_idx = -1

        for idx, item in enumerate(self.moves_data):
            cls = item["classification"]
            cls_lower = cls.lower()
            
            eval_val = item["eval"]
            eval_str = f"+{eval_val}" if isinstance(eval_val, float) and eval_val > 0 else str(eval_val)
            icon_img = self.board_icons.get(cls, "")

            self.tree.insert(
                "", tk.END, iid=str(idx),
                text=f" {cls}",
                image=icon_img,
                values=(
                    item["move_num"],
                    item["player"],
                    item["move_str"],
                    eval_str
                ),
                tags=(cls_lower,)
            )

        if self.moves_data:
            self.current_move_idx = 0
            self.tree.selection_set("0")
            self.tree.see("0")
            self.draw_board_state()

    def on_move_selected(self, event):
        selected = self.tree.selection()
        if not selected:
            return
        
        idx = int(selected[0])
        if idx >= len(self.moves_data):
            return
            
        self.current_move_idx = idx
        self.update_details_display()
        self.draw_board_state()

    def prev_move(self):
        if not self.moves_data:
            return
        if self.current_move_idx > -1:
            self.current_move_idx -= 1
            if self.current_move_idx == -1:
                self.tree.selection_remove(self.tree.selection())
                self.update_details_display()
                self.draw_board_state()
            else:
                self.tree.selection_set(str(self.current_move_idx))
                self.tree.see(str(self.current_move_idx))

    def next_move(self):
        if not self.moves_data:
            return
        if self.current_move_idx < len(self.moves_data) - 1:
            self.current_move_idx += 1
            self.tree.selection_set(str(self.current_move_idx))
            self.tree.see(str(self.current_move_idx))

    def update_details_display(self):
        if self.current_move_idx == -1:
            self.lbl_selected_icon.config(image="")
            self.lbl_selected_title.config(text="Start of game position.")
            self.lbl_selected_desc.config(text="Select a move to inspect details.")
            self.lbl_selected_engine.config(text="")
            self.lbl_alternative_icon.config(image="")
            return

        move_item = self.moves_data[self.current_move_idx]
        cls = move_item["classification"]
        desc = CLASSIFICATION_DESCRIPTIONS.get(cls, "")
        
        if cls in self.legend_icons:
            self.lbl_selected_icon.config(image=self.legend_icons[cls])
        else:
            self.lbl_selected_icon.config(image="")

        title_text = f"Move {move_item['move_num']}: {move_item['player']} played {move_item['move_str']}"
        self.lbl_selected_title.config(text=title_text)
        self.lbl_selected_desc.config(text=desc)
        
        played_eval = move_item["eval"]
        played_eval_str = f"+{played_eval}" if isinstance(played_eval, float) and played_eval > 0 else str(played_eval)
        
        best_eval = move_item["best_eval"]
        best_eval_str = f"+{best_eval}" if isinstance(best_eval, float) and best_eval > 0 else str(best_eval)

        if cls in ["Brilliant", "Best", "Book"]:
            engine_text = f"Position Evaluation: {played_eval_str}\nThis was the strongest move found."
            self.lbl_selected_engine.config(text=engine_text)
            self.lbl_alternative_icon.config(image="")
        else:
            if move_item.get("is_mate_swing", False):
                phrase = get_mate_phrase(move_item['player'], move_item['best_eval'], move_item['eval'])
                loss_desc = phrase.capitalize()
            else:
                loss_desc = f"Evaluation loss: {move_item['cpl']} CP"
            engine_text = (
                f"Position Evaluation: {played_eval_str}\n"
                f"Best engine choice was: {move_item['best_move']} ({best_eval_str})\n"
                f"{loss_desc}"
            )
            self.lbl_selected_engine.config(text=engine_text)
            if "Alternative" in self.legend_icons:
                self.lbl_alternative_icon.config(image=self.legend_icons["Alternative"])
            else:
                self.lbl_alternative_icon.config(image="")

    def toggle_play(self):
        if self.is_playing:
            self.is_playing = False
            self.btn_play.config(text="▶ Play", bg="#4caf50")
            if self.play_timer_id:
                self.root.after_cancel(self.play_timer_id)
                self.play_timer_id = None
        else:
            if not self.moves_data:
                return
            self.is_playing = True
            self.btn_play.config(text="⏸ Pause", bg="#f44336")
            self.play_next_step()

    def play_next_step(self):
        if not self.is_playing:
            return
        if self.current_move_idx < len(self.moves_data) - 1:
            self.next_move()
            self.play_timer_id = self.root.after(1200, self.play_next_step)
        else:
            self.toggle_play()

    def load_saved_games_list(self):
        self.lst_history.delete(0, tk.END)
        from src.software.core.config import SAVED_GAMES_DIR
        saved_dir = SAVED_GAMES_DIR
        
        if os.path.exists(saved_dir):
            import json
            files = [f[:-5] for f in os.listdir(saved_dir) if f.endswith(".json")]
            for f in sorted(files, reverse=True):
                self.lst_history.insert(tk.END, f)

    def on_history_game_selected(self, event):
        selection = self.lst_history.curselection()
        if not selection:
            return
            
        game_name = self.lst_history.get(selection[0])
        from src.software.core.config import SAVED_GAMES_DIR
        file_path = os.path.join(SAVED_GAMES_DIR, f"{game_name}.json")
        
        try:
            import json
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            pgn = data.get("pgn", "")
            
            self.txt_pgn.config(state=tk.NORMAL)
            self.txt_pgn.delete("1.0", tk.END)
            self.txt_pgn.insert(tk.END, pgn)
            self.txt_pgn.config(state=tk.DISABLED)
            
            game_tags = data.get("GameTags", "")
            if hasattr(self, "txt_tags"):
                self.txt_tags.config(state=tk.NORMAL)
                self.txt_tags.delete("1.0", tk.END)
                if game_tags:
                    self.txt_tags.insert(tk.END, game_tags)
                else:
                    self.txt_tags.insert(tk.END, "No tags saved for this game.")
                self.txt_tags.config(state=tk.DISABLED)
            
            # Check if pre-analyzed report and moves exist
            if data.get("report") and isinstance(data.get("moves"), list) and len(data["moves"]) > 0 and isinstance(data["moves"][0], dict):
                self.lbl_progress.config(text="Loaded pre-analyzed game.")
                self.progress_bar["value"] = 100
                
                self.last_report = data["report"]
                self.moves_data = data["moves"]
                self.current_move_idx = -1
                
                # Clear Treeview
                for row in self.tree.get_children():
                    self.tree.delete(row)
                    
                # Populate Treeview
                for idx, item in enumerate(self.moves_data):
                    cls = item["classification"]
                    cls_lower = cls.lower()
                    
                    eval_val = item["eval"]
                    eval_str = f"+{eval_val}" if isinstance(eval_val, (int, float)) and eval_val > 0 else str(eval_val)
                    icon_img = self.board_icons.get(cls, "")
                    
                    self.tree.insert(
                        "", tk.END, iid=str(idx),
                        text=f" {cls}",
                        image=icon_img,
                        values=(
                            item["move_num"],
                            item["player"],
                            item["move_str"],
                            eval_str
                        ),
                        tags=(cls_lower,)
                    )
                
                # Update player cards
                self.update_player_cards(self.last_report)
                
                # Select first move
                if self.moves_data:
                    self.current_move_idx = 0
                    self.tree.selection_set("0")
                    self.tree.see("0")
                    self.update_details_display()
                    
                self.draw_board_state()
                self.btn_report.config(state=tk.NORMAL, bg="#0288d1")
                self.btn_save_analysis.config(state=tk.NORMAL, bg="#43a047")
            else:
                self.start_analysis()
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load saved game: {e}")

    def save_manual_analysis(self):
        if not self.moves_data or not self.last_report:
            return
            
        from tkinter import simpledialog
        import datetime
        import json
        
        game_name = simpledialog.askstring("Save Analysis", "Enter a name to save this analysis:", parent=self.frame)
        if not game_name:
            return
            
        from src.software.core.config import SAVED_GAMES_DIR
        saved_dir = SAVED_GAMES_DIR
        os.makedirs(saved_dir, exist_ok=True)
        
        save_path = os.path.join(saved_dir, f"{game_name}.json")
        
        game_tags = ""
        if hasattr(self, "txt_tags"):
            game_tags = self.txt_tags.get("1.0", tk.END).strip()
            
        payload = {
            "name": game_name,
            "date": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "pgn": self.txt_pgn.get("1.0", tk.END).strip(),
            "GameTags": game_tags,
            "moves": self.moves_data,
            "report": self.last_report
        }
        
        try:
            with open(save_path, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2)
            messagebox.showinfo("Success", f"Analysis saved successfully as '{game_name}'!")
            self.load_saved_games_list()
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save analysis: {e}")

    def delete_selected_history(self):
        selection = self.lst_history.curselection()
        if not selection:
            return
            
        game_name = self.lst_history.get(selection[0])
        confirm = messagebox.askyesno("Confirm Delete", f"Are you sure you want to delete '{game_name}'?")
        if not confirm:
            return
            
        from src.software.core.config import SAVED_GAMES_DIR
        file_path = os.path.join(SAVED_GAMES_DIR, f"{game_name}.json")
        
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
            self.load_saved_games_list()
            
            # Clear UI board and details
            self.txt_pgn.config(state=tk.NORMAL)
            self.txt_pgn.delete("1.0", tk.END)
            self.moves_data = []
            self.current_move_idx = -1
            self.last_report = None
            
            for row in self.tree.get_children():
                self.tree.delete(row)
                
            self.draw_board_state()
            self.update_player_cards({"white_accuracy": 0.0, "black_accuracy": 0.0, "white_stats": {}, "black_stats": {}})
            self.btn_report.config(state=tk.DISABLED, bg="#9e9e9e")
            self.btn_save_analysis.config(state=tk.DISABLED, bg="#9e9e9e")
            self.lbl_progress.config(text="Ready.")
            self.progress_bar["value"] = 0
        except Exception as e:
            messagebox.showerror("Error", f"Failed to delete game: {e}")

    def sync_with_game_state(self):
        self.load_saved_games_list()
        
        is_active = False
        if self.main_gui:
            cv_running = (self.main_gui.cv_bridge.cv_process is not None and self.main_gui.cv_bridge.cv_process.poll() is None)
            is_active = cv_running or (hasattr(self.main_gui, "live_game_moves") and len(self.main_gui.live_game_moves) > 0)
            
        if is_active:
            # Active match state: lock PGN entries and sync in real-time
            self.txt_pgn.config(state=tk.NORMAL)
            self.txt_pgn.delete("1.0", tk.END)
            
            import chess.pgn
            import datetime
            game = chess.pgn.Game()
            
            cfg = getattr(self.main_gui, "save_game_config", None)
            if cfg:
                game.headers["Event"] = cfg.get("event", "CoreXY Robotic Chess Match")
                game.headers["Site"] = cfg.get("site", "?")
                game.headers["Date"] = datetime.date.today().strftime("%Y.%m.%d")
                game.headers["Round"] = cfg.get("round", "1")
                game.headers["White"] = cfg.get("white", "Human")
                game.headers["Black"] = cfg.get("black", f"Stockfish (ELO {self.main_gui.var_elo.get()})")
                
                self.txt_tags.config(state=tk.NORMAL)
                self.txt_tags.delete("1.0", tk.END)
                tags_str = (
                    f"Saved Game Name: {cfg['name']}\n"
                    f"[Event \"{game.headers['Event']}\"]\n"
                    f"[Site \"{game.headers['Site']}\"]\n"
                    f"[Date \"{game.headers['Date']}\"]\n"
                    f"[Round \"{game.headers['Round']}\"]\n"
                    f"[White \"{game.headers['White']}\"]\n"
                    f"[Black \"{game.headers['Black']}\"]\n"
                    f"[Result \"*\"]\n"
                )
                self.txt_tags.insert(tk.END, tags_str)
                self.txt_tags.config(state=tk.DISABLED)
            else:
                game.headers["Event"] = "CoreXY Robotic Chess Match"
                game.headers["White"] = "Human"
                game.headers["Black"] = f"Stockfish (ELO {self.main_gui.var_elo.get()})"
                self.txt_tags.config(state=tk.NORMAL)
                self.txt_tags.delete("1.0", tk.END)
                self.txt_tags.insert(tk.END, "Not auto-saving. Click 'Save Next Played Game' to configure.")
                self.txt_tags.config(state=tk.DISABLED)

            node = game
            board = chess.Board()
            for m_str in self.main_gui.live_game_moves:
                try:
                    mv = chess.Move.from_uci(m_str)
                    if mv in board.legal_moves:
                        node = node.add_variation(mv)
                        board.push(mv)
                except Exception:
                    break
            
            exporter = chess.pgn.StringExporter(headers=False, variations=False, comments=False)
            moves_str = game.accept(exporter)
            moves_str = moves_str.strip()
            if moves_str.endswith(" *"):
                moves_str = moves_str[:-2]
            elif moves_str == "*":
                moves_str = ""
            
            self.txt_pgn.insert(tk.END, moves_str.strip())
            self.txt_pgn.config(state=tk.DISABLED)
            
            self.btn_run.config(state=tk.DISABLED, bg="#9e9e9e")
            self.btn_save_analysis.config(state=tk.DISABLED, bg="#9e9e9e")
            self.lst_history.config(state=tk.DISABLED)
            self.btn_delete_history.config(state=tk.DISABLED)
            
            # Sync analyzed moves
            self.moves_data = list(self.main_gui.live_analyzed_moves)
            
            if not self.moves_data and hasattr(self.main_gui, "live_game_moves") and self.main_gui.live_game_moves:
                import chess
                b_temp = chess.Board()
                constructed_moves = []
                for m_i, m_str in enumerate(self.main_gui.live_game_moves):
                    try:
                        mv = chess.Move.from_uci(m_str)
                        san_str = b_temp.san(mv)
                        b_temp.push(mv)
                        constructed_moves.append({
                            "move_num": (m_i // 2) + 1,
                            "player": "White" if m_i % 2 == 0 else "Black",
                            "move_str": san_str,
                            "move_uci": m_str,
                            "fen": b_temp.fen(),
                            "eval": "-",
                            "classification": "Book"
                        })
                    except Exception:
                        break
                self.moves_data = constructed_moves
            
            for row in self.tree.get_children():
                self.tree.delete(row)
                
            for idx, item in enumerate(self.moves_data):
                cls = item["classification"]
                cls_lower = cls.lower()
                eval_val = item["eval"]
                eval_str = f"+{eval_val}" if isinstance(eval_val, (int, float)) and eval_val > 0 else str(eval_val)
                icon_img = self.board_icons.get(cls, "")
                
                self.tree.insert(
                    "", tk.END, iid=str(idx),
                    text=f" {cls}",
                    image=icon_img,
                    values=(
                        item["move_num"],
                        item["player"],
                        item["move_str"],
                        eval_str
                    ),
                    tags=(cls_lower,)
                )
                
            if self.moves_data:
                self.current_move_idx = len(self.moves_data) - 1
                self.tree.selection_set(str(self.current_move_idx))
                self.tree.see(str(self.current_move_idx))
                self.update_details_display()
                
            self.draw_board_state()
            self.btn_report.config(state=tk.NORMAL if self.moves_data else tk.DISABLED, bg="#0288d1" if self.moves_data else "#9e9e9e")
            
        else:
            # Idle state: enable user PGN inputs
            self.txt_pgn.config(state=tk.NORMAL)
            self.btn_run.config(state=tk.NORMAL, bg="#2e7d32")
            self.btn_save_analysis.config(state=tk.NORMAL if self.moves_data else tk.DISABLED, bg="#43a047" if self.moves_data else "#9e9e9e")
            self.lst_history.config(state=tk.NORMAL)
            self.btn_delete_history.config(state=tk.NORMAL)

def main():
    import sys
    root = tk.Tk()
    root.withdraw()
    messagebox.showerror(
        "Access Denied",
        "The Gameplay Analyzer can only be run inside the main ChessTracker GUI Dashboard.\n"
        "Please run 'python main.py' and select the 'Deep Game Analyzer' tab."
    )
    root.destroy()
    sys.exit(0)

if __name__ == "__main__":
    main()
