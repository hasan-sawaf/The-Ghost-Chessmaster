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
from src.software.core.constants import DEFAULT_COM_PORT, BAUD_RATE

class HardwareMixin:
    def _init_serial_async(self):
        self.serial_manager.start_auto_reconnect_watcher()
        self.serial_manager.connect(DEFAULT_COM_PORT, BAUD_RATE)

    def update_serial_status(self, is_connected, port):
        def _do_update():
            if hasattr(self, "lbl_arduino_status"):
                if is_connected:
                    self.lbl_arduino_status.config(text=f"● Arduino: {port}", fg="#43a047")
                else:
                    self.lbl_arduino_status.config(text="● Arduino: OFF", fg="#d32f2f")

            if not hasattr(self, "lbl_serial_status"):
                return
            if is_connected:
                self.lbl_serial_status.config(text=f"🟢 Connected to {port}", fg="#43a047")
                self.btn_serial_connect.config(state=tk.DISABLED)
                self.btn_serial_disconnect.config(state=tk.NORMAL)

                self.ent_cmd.config(state=tk.NORMAL)
                self.btn_send_cmd.config(state=tk.NORMAL, bg="#1976d2")
                self.show_terminal_notifier("", is_success=True)

                # Sync clock parameters and servo angle over serial to hardware timer after Arduino boot delay
                try:
                    timer_min = int(self.var_game_timer.get())
                    increment_sec = int(self.var_time_increment.get())
                    self.root.after(1800, lambda: self.send_cmd(f"T {timer_min} {increment_sec}"))
                    if hasattr(self, "var_magnet_up_angle"):
                        self.root.after(2000, lambda: self.send_cmd(f"A {self.var_magnet_up_angle.get()}"))
                    if hasattr(self, "cv_bridge") and getattr(self.cv_bridge, "is_reading", False):
                        self.root.after(2200, lambda: self.send_cmd("V 1"))
                except Exception:
                    pass
            else:
                self.lbl_serial_status.config(text="🔴 Disconnected", fg="#d32f2f")
                self.btn_serial_connect.config(state=tk.NORMAL)
                self.btn_serial_disconnect.config(state=tk.DISABLED)

                self.ent_cmd.config(state=tk.DISABLED)
                self.btn_send_cmd.config(state=tk.DISABLED, bg="#9e9e9e")
                self.show_terminal_notifier("⚠️ Cannot send command: Serial port is not connected.", is_success=False)
        safe_call = getattr(self, 'safe_after', lambda fn, *a: self.root.after(0, fn, *a) if hasattr(self, 'root') else None)
        safe_call(_do_update)

    def terminal_scan_ports(self):
        ports = self.serial_manager.get_available_ports()
        self.combo_ports.config(values=ports)
        if ports:
            if self.var_port.get() not in ports:
                self.var_port.set(ports[0])
        else:
            self.var_port.set("")
            self.log("[Serial] No available COM ports found.")

    def terminal_connect_serial(self):
        port = self.var_port.get()
        try:
            baud = int(self.var_baudrate.get())
        except ValueError:
            baud = 115200
        if not port:
            from tkinter import messagebox
            messagebox.showwarning("Warning", "Please select or scan for a valid COM port first.")
            return

        self.serial_manager.connect(port, baud)

    def terminal_disconnect_serial(self):
        self.serial_manager.close(manual=True)

    def terminal_clear_log(self):
        self.log_area.delete("1.0", tk.END)
        self.log("[Console Cleared]")

    def terminal_send_command(self):
        if not self.serial_manager.serial_port or not self.serial_manager.serial_port.is_open:
            self.show_terminal_notifier("⚠️ Cannot send command: Serial port is not connected.", is_success=False)
            return

        cmd = self.ent_cmd.get().strip()
        if not cmd:
            return

        self.show_terminal_notifier("Sending...", is_success=True, fg_color="#78909c")
        success = self.serial_manager.send_cmd(cmd)

        if success:
            self.log(f"-> Sent: {cmd}")
            self.show_terminal_notifier(f"✅ Command '{cmd}' sent successfully!", is_success=True)
            self.ent_cmd.delete(0, tk.END)
        else:
            self.log(f"-> Failed to send: {cmd}")
            self.show_terminal_notifier(f"❌ Failed to send command '{cmd}'. Check connection.", is_success=False)

    def show_terminal_notifier(self, text, is_success=True, fg_color=None):
        if not hasattr(self, "lbl_terminal_notifier"):
            return
        color = fg_color if fg_color else ("#2e7d32" if is_success else "#d32f2f")
        self.lbl_terminal_notifier.config(text=text, fg=color)

        # Clear success notifications after 3 seconds
        if is_success and text not in ["", "Sending..."]:
            self.root.after(3000, lambda: self.clear_terminal_notifier_if_text(text))

    def clear_terminal_notifier_if_text(self, text):
        if hasattr(self, "lbl_terminal_notifier") and self.lbl_terminal_notifier.cget("text") == text:
            self.lbl_terminal_notifier.config(text="")

    def send_cmd(self, c):
        self.serial_manager.send_cmd(c)

    def trigger_user_move(self):
        player_color = getattr(self, 'var_player_color', None)
        playing_as_black = player_color and player_color.get() == "Black"
        expected_turn = "BLACK" if playing_as_black else "WHITE"
        
        if self.var_turn.get() == expected_turn:
            self.btn_execute.config(state=tk.DISABLED)
            self.var_status.set("Evaluating move...")
            self.cv_bridge.send_cv_cmd('r')
        else:
            self.log("Ignored physical button press - it is not your turn, or CV is not ready.")

    def move_to_sq(self, sq):
        if hasattr(self, "firebase_manager") and self.firebase_manager:
            self.firebase_manager.update_corexy_status(False)
        if self.kill_mode_active.get():
            self.kill_mode_active.set(False)
            self.task_queue.put({'type': 'kill', 'sq': sq})
        else:
            self.pending_target = sq
            self.send_cmd(f"C {sq}")

    def processGCode(self, x=None, y=None):
        """
        Sends G-code command to MCU to trigger processGCode(cmdStr) in kinematics.cpp.
        Can be called programmatically with x, y numbers or via GUI with no args.
        """
        if x is not None and y is not None:
            try:
                x_f = float(x)
                y_f = float(y)
                if hasattr(self, "var_target_gcode_x"): self.var_target_gcode_x.set(f"{x_f:.1f}")
                if hasattr(self, "var_target_gcode_y"): self.var_target_gcode_y.set(f"{y_f:.1f}")
            except ValueError:
                from tkinter import messagebox
                messagebox.showerror("Invalid Input", "X and Y coordinates must be valid numbers.")
                return
        else:
            x_val = self.var_target_gcode_x.get().strip() if hasattr(self, 'var_target_gcode_x') else ""
            y_val = self.var_target_gcode_y.get().strip() if hasattr(self, 'var_target_gcode_y') else ""
            if not x_val or not y_val:
                from tkinter import messagebox
                messagebox.showwarning("Missing Coordinates", "Please enter valid numeric values for both X and Y coordinates (in mm).")
                return
            try:
                x_f = float(x_val)
                y_f = float(y_val)
            except ValueError:
                from tkinter import messagebox
                messagebox.showerror("Invalid Input", "X and Y coordinates must be valid numbers (e.g. 150 or 25.5).")
                return

        # Format G-code: 'G X{x_f} Y{y_f}' which matches Arduino processGCode() parser
        gcode_cmd = f"G X{x_f:.1f} Y{y_f:.1f}"

        if hasattr(self, "firebase_manager") and self.firebase_manager:
            self.firebase_manager.update_corexy_status(False)

        self.log(f"🎯 [processGCode] Moving CoreXY to coordinates: X={x_f:.1f} mm, Y={y_f:.1f} mm -> Sent '{gcode_cmd}'")
        self.send_cmd(gcode_cmd)

    def process_gcode_coordinate_move(self):
        """Button click handler for GUI coordinate execution."""
        self.processGCode()

    def toggle_mag(self):
        self.magnet_up = not self.magnet_up
        self.send_cmd('9' if self.magnet_up else '0')

    def set_magnet_angle(self, angle=None):
        """Sets the servo engagement angle (in degrees, e.g. 90 or 100) on the Arduino MCU."""
        if angle is not None:
            try:
                ang_int = int(angle)
                if hasattr(self, "var_magnet_up_angle"):
                    self.var_magnet_up_angle.set(str(ang_int))
            except ValueError:
                from tkinter import messagebox
                messagebox.showerror("Invalid Angle", "Magnet angle must be an integer between 0 and 180 degrees.")
                return
        else:
            val = self.var_magnet_up_angle.get().strip() if hasattr(self, 'var_magnet_up_angle') else "90"
            if not val:
                from tkinter import messagebox
                messagebox.showwarning("Missing Value", "Please enter a servo angle in degrees (e.g. 90 or 100).")
                return
            try:
                ang_int = int(val)
            except ValueError:
                from tkinter import messagebox
                messagebox.showerror("Invalid Angle", "Magnet angle must be an integer between 0 and 180 degrees.")
                return

        if ang_int < 0 or ang_int > 180:
            from tkinter import messagebox
            messagebox.showerror("Out of Range", "Magnet angle must be between 0° and 180°.")
            return

        cmd = f"A {ang_int}"
        self.log(f"🧲 [Servo Config] Setting Magnet UP Angle to {ang_int}° -> Sent '{cmd}'")
        self.send_cmd(cmd)

        # If magnet is currently engaged (UP), re-send '9' to move servo to new angle immediately
        if getattr(self, 'magnet_up', False):
            self.send_cmd('9')
            self.log(f"🧲 [Servo Config] Re-applied Magnet UP angle ({ang_int}°).")

    def _handle_serial_status_changed(self, status_type, value):
        if status_type == "idle":
            if self.pending_target:
                self.root.after(0, self.highlight_sq, self.pending_target)
                self.pending_target = None
            if getattr(self, "pending_restore_display", False):
                self.send_cmd("M0")
                self.pending_restore_display = False
            if getattr(self, "pending_start_timers", False):
                if hasattr(self, "_start_timers"):
                    self._start_timers()
                self.pending_start_timers = False
            self.wait_for_idle.set()
        elif status_type == "magnet":
            if value == "up":
                self.var_held_piece.set(f"Piece @ {self.var_current_sq.get()}")
            elif value == "down":
                self.var_held_piece.set("Nothing")
        elif status_type == "home":
            self.var_current_sq.set("HOME (0,0)")
            self.log("System: Back to Zero Point.")
            if hasattr(self, "firebase_manager") and self.firebase_manager:
                self.firebase_manager.update_corexy_status(True)
                self.firebase_manager.update_game_ended(False)

    def _handle_serial_button_pressed(self, btn):
        if btn == "e":
            self.log("🔘 Hardware Button 1 Pressed! Triggering execution...")
            self.root.after(0, self.trigger_user_move)
        elif btn == "r":
            self.log("🔘 Hardware Button 2 Pressed! Recapturing base frame...")
            self.root.after(0, self.recapture_base_frame)
        elif btn == "s":
            if self.cv_bridge.cv_process is None or self.cv_bridge.cv_process.poll() is not None:
                self.log("🔘 Hardware Button 3 Pressed! Starting CV Bridge...")
                self.root.after(0, self.start_cv)
            else:
                self.log("🔘 Hardware Button 3 Pressed! CV is already running - syncing state to hardware...")
                self.root.after(0, lambda: self.serial_manager.send_cmd('V 1'))
        elif btn == "start_game":
            self.log("🔘 Hardware Button 3 Pressed! Starting local game from Arduino...")
            self.match_origin = "ARDUINO_HARDWARE"
            self.is_physical_app_mode = False
            self.root.after(0, lambda: self.start_game(prompt_settings=False))
        elif btn == "restart":
            self.log("🔘 Restart confirmed via hardware! Resetting full system...")
            self.root.after(0, self.cv_bridge_restart_cv_adapter)
        elif btn in ["close", "exit"]:
            self.log("🔘 Game exit request from hardware! Closing game...")
            self.root.after(0, self.close_game)

