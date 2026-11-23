import tkinter as tk

class CardsMixin:
    def build_player_cards(self, cards_frame):
        """Builds player White and Player Black statistics matrices."""
        # White Card
        self.white_card = tk.Frame(cards_frame, bg="white", highlightbackground="#cfd8dc", highlightthickness=1)
        self.white_card.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 4))

        lbl_w_title = tk.Label(self.white_card, text="⚪ Player White", font=("Segoe UI", 9, "bold"), fg="#37474f", bg="white")
        lbl_w_title.pack(anchor="w", padx=8, pady=(4, 0))

        self.lbl_white_accuracy = tk.Label(self.white_card, text="Accuracy: --", font=("Segoe UI", 12, "bold"), fg="#1976d2", bg="white")
        self.lbl_white_accuracy.pack(anchor="w", padx=8, pady=(0, 1))

        # Grid frame for white stats
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
            lbl.grid(row=r, column=c, sticky="w", padx=(0, 10), pady=1)
            self.white_stat_labels[cat] = lbl

        # Black Card
        self.black_card = tk.Frame(cards_frame, bg="white", highlightbackground="#cfd8dc", highlightthickness=1)
        self.black_card.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=(4, 0))

        lbl_b_title = tk.Label(self.black_card, text="⚫ Player Black", font=("Segoe UI", 9, "bold"), fg="#37474f", bg="white")
        lbl_b_title.pack(anchor="w", padx=8, pady=(4, 0))

        self.lbl_black_accuracy = tk.Label(self.black_card, text="Accuracy: --", font=("Segoe UI", 12, "bold"), fg="#e64a19", bg="white")
        self.lbl_black_accuracy.pack(anchor="w", padx=8, pady=(0, 1))

        # Grid frame for black stats
        b_stats_grid = tk.Frame(self.black_card, bg="white")
        b_stats_grid.pack(fill=tk.X, padx=8, pady=(2, 4))

        self.black_stat_labels = {}
        for cat, r, c in cats_to_grid:
            lbl = tk.Label(
                b_stats_grid, text=" 0", image=self.legend_icons.get(cat, ""), 
                compound=tk.LEFT, bg="white", font=("Segoe UI", 8)
            )
            lbl.grid(row=r, column=c, sticky="w", padx=(0, 10), pady=1)
            self.black_stat_labels[cat] = lbl

    def update_player_cards(self, report):
        """Populates player accuracy percentages and stats counts from analysis output report."""
        self.lbl_white_accuracy.config(text=f"Accuracy: {report['white_accuracy']}%")
        w_s = report['white_stats']
        for cat in ["Brilliant", "Best", "Excellent", "Good", "Book", "Inaccuracy", "Mistake", "Blunder"]:
            key = cat.lower()
            val = w_s.get(key, 0)
            self.white_stat_labels[cat].config(text=f" {val}")

        self.lbl_black_accuracy.config(text=f"Accuracy: {report['black_accuracy']}%")
        b_s = report['black_stats']
        for cat in ["Brilliant", "Best", "Excellent", "Good", "Book", "Inaccuracy", "Mistake", "Blunder"]:
            key = cat.lower()
            val = b_s.get(key, 0)
            self.black_stat_labels[cat].config(text=f" {val}")
