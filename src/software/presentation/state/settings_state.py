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
import json

class SettingsMixin:
    def load_game_settings(self):
        from src.software.core.config import SETTINGS_JSON
        settings_path = SETTINGS_JSON

        # Defaults
        self.var_game_timer.set("10")
        self.var_time_increment.set("2")
        self.var_play_style.set("Balanced")
        self.var_pieces_theme.set("Standard")
        self.var_audio_enabled.set(True)
        self.var_player_color.set("White")
        self.var_elo.set(1500)
        self.var_level_name.set("Lvl 7: Class B Player (1500 ELO)")

        if os.path.exists(settings_path):
            try:
                with open(settings_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                self.var_game_timer.set(data.get("timer_minutes", "10"))
                self.var_time_increment.set(data.get("increment_seconds", "2"))
                self.var_play_style.set(data.get("play_style", "Balanced"))
                self.var_pieces_theme.set(data.get("pieces_theme", "Standard"))
                self.var_audio_enabled.set(data.get("audio_enabled", True))
                self.var_player_color.set(data.get("player_color", "White"))

                saved_elo = data.get("ai_elo", 1500)
                self.var_elo.set(saved_elo)
                if saved_elo in self.LEVEL_REVERSE:
                    self.var_level_name.set(self.LEVEL_REVERSE[saved_elo])
                else:
                    self.var_level_name.set("Custom")
                    
                if "last_save_config" in data:
                    self.save_game_config = data["last_save_config"]
                    self.log("[Settings] Loaded last auto-save game configuration.")
                    
                self.log("[Settings] Loaded configurations from config/game_settings.json")
            except Exception as e:
                self.log(f"[Settings] Error loading config: {e}")
        self.update_dashboard_settings_display()

    def save_game_settings(self):
        if hasattr(self, "game_active") and self.game_active:
            from tkinter import messagebox
            messagebox.showerror("Error", "Settings can only be changed when no game is playing.")
            return

        if hasattr(self, "firebase_manager") and self.firebase_manager and self.firebase_manager.is_user_connected:
            from tkinter import messagebox
            email = self.firebase_manager.connected_user_email or "Mobile App User"
            messagebox.showwarning(
                "Settings Locked",
                f"Settings are currently managed remotely by the connected mobile app user ({email}).\n\n"
                "Please disconnect from the mobile app to edit and save settings locally."
            )
            return

        from src.software.core.config import SETTINGS_JSON
        settings_path = SETTINGS_JSON

        payload = {
            "timer_minutes": self.var_game_timer.get(),
            "increment_seconds": self.var_time_increment.get(),
            "play_style": self.var_play_style.get(),
            "pieces_theme": self.var_pieces_theme.get(),
            "audio_enabled": self.var_audio_enabled.get(),
            "player_color": self.var_player_color.get(),
            "ai_elo": self.var_elo.get()
        }
        
        if getattr(self, "save_game_config", None):
            payload["last_save_config"] = self.save_game_config

        try:
            os.makedirs(os.path.dirname(settings_path), exist_ok=True)
            with open(settings_path, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2)
            self.log("[Settings] Saved configurations successfully.")

            # Show a green notifier dialog
            from tkinter import messagebox
            messagebox.showinfo("Success", "Settings saved and applied successfully!")

            # Apply ELO to engine
            self.send_cv_elo(self.var_elo.get())

            # Sync clock parameters over serial to hardware timer if connected
            timer_min = int(self.var_game_timer.get())
            increment_sec = int(self.var_time_increment.get())
            self.send_cmd(f"T {timer_min} {increment_sec}")
            self.update_dashboard_settings_display()
        except Exception as e:
            self.log(f"[Settings] Error saving config: {e}")

    def persist_synced_game_settings(self):
        """Saves current memory settings into config/game_settings.json automatically on RTDB sync."""
        try:
            from src.software.core.config import SETTINGS_JSON
            payload = {
                "timer_minutes": str(self.var_game_timer.get()),
                "increment_seconds": str(self.var_time_increment.get()),
                "play_style": str(self.var_play_style.get()),
                "pieces_theme": str(self.var_pieces_theme.get() if hasattr(self, 'var_pieces_theme') else "Standard"),
                "audio_enabled": bool(self.var_audio_enabled.get() if hasattr(self, 'var_audio_enabled') else True),
                "player_color": str(self.var_player_color.get()),
                "ai_elo": int(self.var_elo.get())
            }
            if getattr(self, "save_game_config", None):
                payload["last_save_config"] = self.save_game_config

            os.makedirs(os.path.dirname(SETTINGS_JSON), exist_ok=True)
            with open(SETTINGS_JSON, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2)
        except Exception as e:
            pass

    def refresh_settings_lock_state(self):
        """Dynamically locks or unlocks the Game Settings tab based on game activity and mobile user connection."""
        is_playing = getattr(self, "game_active", False)
        is_user_conn = hasattr(self, "firebase_manager") and self.firebase_manager and self.firebase_manager.is_user_connected

        if hasattr(self, 'lbl_settings_warning'):
            if is_playing:
                self.lbl_settings_warning.config(
                    text="⚠️ Settings are locked while a game is actively playing.",
                    fg="#d32f2f"
                )
                self.set_settings_widgets_state(tk.DISABLED)
            elif is_user_conn:
                email = self.firebase_manager.connected_user_email or "Mobile User"
                self.lbl_settings_warning.config(
                    text=f"🔒 Settings are locked (Managed remotely by mobile app: {email}). Disconnect from app to edit locally.",
                    fg="#e65100"
                )
                self.set_settings_widgets_state(tk.DISABLED)
            else:
                self.lbl_settings_warning.config(
                    text="✓ Local Editing Enabled (No mobile user connected).",
                    fg="#2e7d32"
                )
                self.set_settings_widgets_state(tk.NORMAL)

    # ==========================================
    # TIMER & INCREMENT DIGITAL INTERACTION
    # ==========================================
    def set_settings_widgets_state(self, state):
        widgets = [
            getattr(self, 'btn_timer_up', None),
            getattr(self, 'btn_timer_down', None),
            getattr(self, 'btn_inc_up', None),
            getattr(self, 'btn_inc_down', None),
            getattr(self, 'combo_levels', None),
            getattr(self, 'btn_elo_dec', None),
            getattr(self, 'btn_elo_inc', None),
            getattr(self, 'combo_play_style', None),
            getattr(self, 'combo_player_color', None),
            getattr(self, 'combo_theme', None),
            getattr(self, 'chk_audio', None),
            getattr(self, 'btn_save_settings', None)
        ]
        for w in widgets:
            if not w:
                continue
            try:
                if w == getattr(self, 'btn_save_settings', None):
                    if state == tk.DISABLED:
                        w.config(state=state, bg="#9e9e9e")
                    else:
                        w.config(state=state, bg="#2e7d32")
                elif isinstance(w, ttk.Combobox):
                    w.config(state="disabled" if state == tk.DISABLED else "readonly")
                else:
                    w.config(state=state)
            except Exception:
                pass

    def on_preset_selected(self, _event):
        level = self.var_level_name.get()
        if level in self.LEVEL_PRESETS:
            elo = self.LEVEL_PRESETS[level]
            self.var_elo.set(elo)
            self.send_cv_elo(elo)

    def adjust_elo(self, amount):
        current_elo = self.var_elo.get()
        new_elo = current_elo + amount
        if new_elo < 800:
            new_elo = 800
        elif new_elo > 2800:
            new_elo = 2800

        self.var_elo.set(new_elo)

        if new_elo in self.LEVEL_REVERSE:
            self.var_level_name.set(self.LEVEL_REVERSE[new_elo])
        else:
            self.var_level_name.set("Custom")

        self.send_cv_elo(new_elo)

    def send_cv_elo(self, elo):
        self.log(f"Setting AI Difficulty ELO target to {elo}...")
        self.cv_bridge.send_cv_cmd(f"set_elo {elo}")

    # ==========================================
    # PAGE NAVIGATION & MANAGEMENT
    # ==========================================
