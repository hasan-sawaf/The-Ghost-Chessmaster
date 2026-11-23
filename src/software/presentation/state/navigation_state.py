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

class NavigationMixin:
    def clean_up_calibration(self):
        if hasattr(self, "calibration_page") and self.calibration_page is not None:
            try:
                self.calibration_page.stop_camera()
            except Exception:
                pass
            try:
                if hasattr(self.calibration_page, "frame") and self.calibration_page.frame.winfo_exists():
                    self.calibration_page.frame.destroy()
            except Exception:
                pass
            self.calibration_page = None

    def _hide_all_pages(self):
        self.clean_up_calibration()
        for attr in ['dashboard_frame', 'deep_analysis_frame', 'terminal_frame',
                     'manual_ctrl_frame', 'settings_frame', 'vision_feeds_frame', 'firebase_test_frame']:
            if hasattr(self, attr):
                frame = getattr(self, attr)
                if frame is not None:
                    try:
                        frame.pack_forget()
                    except Exception:
                        pass

        for btn_attr in ['btn_tab_dashboard', 'btn_tab_analysis', 'btn_tab_calibration',
                         'btn_tab_terminal', 'btn_tab_manual_ctrl', 'btn_tab_settings',
                         'btn_tab_vision_feeds', 'btn_tab_firebase_test']:
            if hasattr(self, btn_attr):
                btn = getattr(self, btn_attr)
                if btn is not None:
                    try:
                        btn.config(bg="#263238")
                    except Exception:
                        pass

    def show_dashboard_page(self):
        self._hide_all_pages()
        self.dashboard_frame.pack(fill=tk.BOTH, expand=True)
        if hasattr(self, 'btn_tab_dashboard'): self.btn_tab_dashboard.config(bg="#37474f")

    def show_analysis_page(self):
        self._hide_all_pages()
        self.deep_analysis_frame.pack(fill=tk.BOTH, expand=True)

        if not hasattr(self, "deep_analysis_page"):
            from src.software.presentation.views.analysis_view import AnalysisApp
            self.deep_analysis_page = AnalysisApp(self.deep_analysis_frame, main_gui=self)

        self.deep_analysis_page.sync_with_game_state()
        if hasattr(self, 'btn_tab_analysis'): self.btn_tab_analysis.config(bg="#37474f")

    def open_calibration_page(self):
        if hasattr(self, "game_active") and self.game_active:
            from tkinter import messagebox
            messagebox.showerror("Calibration Blocked", "Cannot open Camera Calibration while a game is actively playing. Please close or save/finish the game first.")
            return

        if self.cv_bridge.cv_process is not None and self.cv_bridge.cv_process.poll() is None:
            self.log("[Calibration] Stopping CV Bridge to release camera resource...")
            self.stop_cv()

        self._hide_all_pages()

        from src.software.presentation.views.calibration_view import CalibrationPage
        self.calibration_page = CalibrationPage(self)
        if hasattr(self, 'btn_tab_calibration'): self.btn_tab_calibration.config(bg="#37474f")

    def show_terminal_page(self):
        self._hide_all_pages()
        self.terminal_frame.pack(fill=tk.BOTH, expand=True)

        # Automatically scan available ports on entering tab
        self.terminal_scan_ports()
        if hasattr(self, 'btn_tab_terminal'): self.btn_tab_terminal.config(bg="#37474f")

    def show_manual_ctrl_page(self):
        self._hide_all_pages()
        self.manual_ctrl_frame.pack(fill=tk.BOTH, expand=True)
        if hasattr(self, 'btn_tab_manual_ctrl'): self.btn_tab_manual_ctrl.config(bg="#37474f")

    def show_settings_page(self):
        self._hide_all_pages()
        self.settings_frame.pack(fill=tk.BOTH, expand=True)
        if hasattr(self, 'btn_tab_settings'): self.btn_tab_settings.config(bg="#37474f")

        # Dynamically lock or unlock settings based on game play and mobile connection
        if hasattr(self, 'refresh_settings_lock_state'):
            self.refresh_settings_lock_state()

    def show_vision_feeds_page(self):
        self._hide_all_pages()
        self.vision_feeds_frame.pack(fill=tk.BOTH, expand=True)
        if hasattr(self, 'btn_tab_vision_feeds'): self.btn_tab_vision_feeds.config(bg="#37474f")

    def show_firebase_test_page(self):
        self._hide_all_pages()
        if hasattr(self, 'firebase_test_frame'): self.firebase_test_frame.pack(fill=tk.BOTH, expand=True)
        if hasattr(self, 'btn_tab_firebase_test'): self.btn_tab_firebase_test.config(bg="#37474f")

    def restore_dashboard(self):
        self.show_dashboard_page()

    # ==========================================
    # BACKGROUND DEVICE SCANNING & CACHING
    # ==========================================
