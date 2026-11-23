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

class UtilsMixin:
    def get_asset_root_dir(self):
        import sys
        if getattr(sys, 'frozen', False):
            return getattr(sys, '_MEIPASS', os.path.dirname(sys.executable))
        else:
            return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))

    def get_write_root_dir(self):
        import sys
        if getattr(sys, 'frozen', False):
            return os.path.dirname(sys.executable)
        else:
            return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))

    def load_quality_icons(self):
        from PIL import Image, ImageTk
        self.legend_icons = {}
        root_dir = self.get_asset_root_dir()
        icons_dir = os.path.join(root_dir, "src", "software", "presentation", "assets", "icons", "32x")
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
        try:
            for name, filename in icon_files.items():
                path = os.path.join(icons_dir, filename)
                if os.path.exists(path):
                    img = Image.open(path).resize((18, 18), Image.Resampling.LANCZOS)
                    self.legend_icons[name] = ImageTk.PhotoImage(img)
            print(f"[INFO] Loaded {len(self.legend_icons)} quality icons.")
        except Exception as e:
            print(f"[WARNING] Could not load quality icons: {e}")

    def _set_image(self, label, photo):
        label.config(image=photo, width=0, height=0)
        label.image = photo

    def log(self, m):
        print(f"[LOG] {m}")
        if hasattr(self, 'log_area') and self.log_area:
            def _append():
                try:
                    self.log_area.insert(tk.END, m + "\n")
                    self.log_area.see(tk.END)
                except Exception:
                    pass
            if hasattr(self, 'root') and self.root:
                try:
                    self.root.after(0, _append)
                except Exception:
                    _append()

