import tkinter as tk
from tkinter import ttk, messagebox
import cv2
import numpy as np
import json
import os
import threading
from PIL import Image, ImageTk
from src.software.infrastructure.vision.calibration import compute_grid_calibration
from src.software.infrastructure.vision.camera_manager import CAMERA_ACCESS_LOCK

# Silence OpenCV logging inside this module
os.environ["OPENCV_LOG_LEVEL"] = "FATAL"

class CalibrationPage:
    """
    Dedicated Calibration view within the dashboard window (no new window).
    Replaces the dashboard panels when active and displays a live camera feed.
    """
    def __init__(self, gui):
        self.gui = gui
        self.root = gui.root
        self.points = []
        self.camera_cap = None
        self.polling_active = False

        self.var_rot = tk.StringVar(value="0")
        self.var_cam = tk.StringVar(value="Camera 1")
        self.var_mirror = tk.BooleanVar(value=False)

        # Main containing frame for the Calibration Screen
        self.frame = tk.Frame(self.gui.container_frame, bg="#eef2f5")
        self.frame.pack(fill=tk.BOTH, expand=True)

        self.build_ui()
        
        # Populate camera dropdown
        if self.gui.cached_cameras:
            self.update_camera_list(self.gui.cached_cameras)
        else:
            self.combo_cam.config(values=["Camera 1", "Camera 0"])
            self.gui.scan_available_cameras()

    def build_ui(self):
        # 1. HEADER BAR
        header = tk.Frame(self.frame, bg="#37474f", height=50)
        header.pack(fill=tk.X, side=tk.TOP)
        header.pack_propagate(False)

        btn_back = tk.Button(
            header, text="⬅  Back to Dashboard", bg="#263238", fg="white",
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
            activebackground="#455a64", activeforeground="white",
            padx=15, command=self.go_back
        )
        btn_back.pack(side=tk.LEFT, fill=tk.Y, padx=10, pady=8)

        lbl_title = tk.Label(
            header, text="📐 CHESSBOARD CAMERA CALIBRATION UTILITY",
            font=("Segoe UI", 12, "bold"), fg="white", bg="#37474f"
        )
        lbl_title.pack(side=tk.LEFT, padx=15, fill=tk.Y)

        # Main workspace below header
        workspace = tk.Frame(self.frame, bg="#eef2f5", padx=15, pady=15)
        workspace.pack(fill=tk.BOTH, expand=True)

        # 2. LEFT SIDE PANEL (Controls & Help Document)
        left_panel = tk.Frame(workspace, bg="#eef2f5", width=340)
        left_panel.pack(side=tk.LEFT, fill=tk.BOTH, padx=(0, 10))
        left_panel.pack_propagate(False)

        # Controls Card
        ctrl_card = ttk.LabelFrame(left_panel, text=" Settings & Actions ", padding=10)
        ctrl_card.pack(fill=tk.X, pady=(0, 10))

        # Camera Selector Combobox
        tk.Label(ctrl_card, text="Select Camera:", bg="white", font=("Segoe UI", 9)).grid(row=0, column=0, sticky="w", pady=5)
        self.combo_cam = ttk.Combobox(
            ctrl_card, textvariable=self.var_cam,
            values=["Camera 1", "Camera 0"],
            state="readonly", width=12
        )
        self.combo_cam.grid(row=0, column=1, sticky="w", padx=10, pady=5)
        self.combo_cam.bind("<<ComboboxSelected>>", self.on_camera_changed)

        # Toggle Camera Button
        self.btn_toggle_camera = tk.Button(
            ctrl_card, text="Turn Camera ON", bg="#43a047", fg="white",
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
            activebackground="#2e7d32", activeforeground="white",
            command=self.toggle_camera
        )
        self.btn_toggle_camera.grid(row=1, column=0, columnspan=2, sticky="ew", pady=10, ipady=3)

        # Mirror Preview Feed Checkbox
        self.chk_mirror = tk.Checkbutton(
            ctrl_card, text="Mirror Preview Feed", variable=self.var_mirror,
            bg="white", font=("Segoe UI", 9), activebackground="white"
        )
        self.chk_mirror.grid(row=2, column=0, columnspan=2, sticky="w", pady=5)

        self.btn_reset = tk.Button(
            ctrl_card, text="RESET POINTS", bg="#e53935", fg="white",
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
            command=self.reset_points
        )
        self.btn_reset.grid(row=3, column=0, columnspan=2, sticky="ew", pady=(10, 5), ipady=3)

        self.btn_save = tk.Button(
            ctrl_card, text="SAVE CONFIGURATION", bg="#43a047", fg="white",
            font=("Segoe UI", 9, "bold"), relief="flat", cursor="hand2",
            command=self.save_calibration
        )
        self.btn_save.grid(row=4, column=0, columnspan=2, sticky="ew", pady=5, ipady=3)

        # Help / Instructions Card
        help_card = ttk.LabelFrame(left_panel, text=" How to Calibrate ", padding=10)
        help_card.pack(fill=tk.BOTH, expand=True)

        help_text = (
            "QUICK CALIBRATION GUIDE\n\n"
            "This utility maps camera pixels to chess squares on the physical board.\n\n"
            "INSTRUCTIONS:\n"
            "1. Align the camera so the entire chessboard is in view.\n"
            "2. Choose the correct camera from the 'Select Camera' dropdown.\n"
            "3. Turn the camera ON using the 'Turn Camera ON' button.\n"
            "4. Check 'Mirror Preview Feed' if the camera is physically mirrored or mounted upside down.\n"
            "5. Click on the 4 outer corner squares of the chessboard in the live camera feed in this exact order:\n"
            "   1st click: Top-Left corner\n"
            "   2nd click: Top-Right corner\n"
            "   3rd click: Bottom-Right corner\n"
            "   4th click: Bottom-Left corner\n"
            "6. A grid overlay will display the calculated squares. Verify the coordinate labels (e.g. a1, h8) match your board orientation.\n"
            "7. Click 'SAVE CONFIGURATION' to apply."
        )

        txt_help = tk.Text(
            help_card, font=("Segoe UI", 9), wrap=tk.WORD,
            bg="white", bd=0, highlightthickness=0
        )
        txt_help.pack(fill=tk.BOTH, expand=True)
        txt_help.insert(tk.END, help_text)
        txt_help.config(state=tk.DISABLED)

        # 3. CENTER / RIGHT PANEL (Live Camera Viewer)
        video_card = ttk.LabelFrame(workspace, text=" Live Camera Feed ", padding=10)
        video_card.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        self.lbl_video = tk.Label(
            video_card, 
            text="Camera is Off.\nTurn the camera on using the controls panel to start calibration.", 
            bg="#263238", fg="#eceff1", font=("Segoe UI", 11, "bold")
        )
        self.lbl_video.pack(fill=tk.BOTH, expand=True)
        self.lbl_video.bind("<Button-1>", self.on_video_click)

        # Initialize default controls state (disabled since camera is off by default)
        self.update_controls_state()

    def update_controls_state(self):
        try:
            is_on = (self.camera_cap is not None and self.polling_active)
            if is_on:
                if hasattr(self, 'btn_toggle_camera') and self.btn_toggle_camera.winfo_exists():
                    self.btn_toggle_camera.config(text="🔌 Turn Camera OFF", bg="#e53935", fg="white", activebackground="#c62828")
                if hasattr(self, 'btn_reset') and self.btn_reset.winfo_exists():
                    self.btn_reset.config(state=tk.NORMAL)
                if hasattr(self, 'btn_save') and self.btn_save.winfo_exists():
                    self.btn_save.config(state=tk.NORMAL)
                if hasattr(self, 'chk_mirror') and self.chk_mirror.winfo_exists():
                    self.chk_mirror.config(state=tk.NORMAL)
            else:
                if hasattr(self, 'btn_toggle_camera') and self.btn_toggle_camera.winfo_exists():
                    self.btn_toggle_camera.config(text="🔌 Turn Camera ON", bg="#43a047", fg="white", activebackground="#2e7d32")
                if hasattr(self, 'btn_reset') and self.btn_reset.winfo_exists():
                    self.btn_reset.config(state=tk.DISABLED)
                if hasattr(self, 'btn_save') and self.btn_save.winfo_exists():
                    self.btn_save.config(state=tk.DISABLED)
                if hasattr(self, 'chk_mirror') and self.chk_mirror.winfo_exists():
                    self.chk_mirror.config(state=tk.DISABLED)
        except Exception:
            pass

    def toggle_camera(self):
        if self.camera_cap is None:
            val = str(self.var_cam.get())
            cam_idx = 1
            if "0" in val:
                cam_idx = 0
            elif "1" in val:
                cam_idx = 1
            self.connect_camera_async(cam_idx)
        else:
            self.stop_camera()
            if hasattr(self, 'lbl_video') and self.lbl_video.winfo_exists():
                self.lbl_video.config(image="", text="Camera is Off.\nTurn the camera on using the controls panel to start calibration.")

    def update_camera_list(self, available):
        try:
            if hasattr(self, 'combo_cam') and self.combo_cam.winfo_exists():
                self.combo_cam.config(values=available)
            if hasattr(self, 'var_cam'):
                if self.var_cam.get() in ["Scanning...", "Scanning"]:
                    default_cam = "Camera 1" if "Camera 1" in available else available[0]
                    self.var_cam.set(default_cam)
        except Exception:
            pass

    def on_camera_changed(self, event):
        # Only switch camera automatically if the camera is currently running
        if self.camera_cap is not None and self.polling_active:
            val = str(self.var_cam.get())
            cam_idx = 1 if "1" in val else 0
            self.connect_camera_async(cam_idx)

    def connect_camera_async(self, cam_idx):
        """Asynchronously connects to the chosen camera on a background thread."""
        self.stop_camera()
        if hasattr(self, 'lbl_video') and self.lbl_video.winfo_exists():
            self.lbl_video.config(image="", text=f"Connecting to Camera {cam_idx}... Please wait...")
        self.points = []
        
        # Disable states while connecting
        try:
            self.root.after(0, self.update_controls_state)
        except Exception:
            pass
        
        threading.Thread(target=self._connect_camera_worker, args=(cam_idx,), daemon=True).start()

    def _connect_camera_worker(self, cam_idx):
        try:
            with CAMERA_ACCESS_LOCK:
                cap = cv2.VideoCapture(cam_idx, cv2.CAP_DSHOW)
                if not cap.isOpened():
                    cap.release()
                    cap = cv2.VideoCapture(cam_idx)
                
            if cap.isOpened():
                self.camera_cap = cap
                self.polling_active = True
                self.root.after(0, self.update_feed)
                self.root.after(0, self.update_controls_state)
            else:
                self.root.after(0, self._handle_connection_failure, cam_idx)
        except Exception:
            self.root.after(0, self._handle_connection_failure, cam_idx)

    def _handle_connection_failure(self, cam_idx):
        try:
            if hasattr(self, 'lbl_video') and self.lbl_video.winfo_exists():
                self.lbl_video.config(image="", text=f"Failed to connect to Camera {cam_idx}.\nPlease choose a different camera index or plug in Camera {cam_idx}.")
            self.update_controls_state()
        except Exception:
            pass

    def update_feed(self):
        """Continuously pulls frame, draws overlays, and updates label."""
        if not self.polling_active or not self.camera_cap:
            return

        try:
            if not hasattr(self, 'lbl_video') or not self.lbl_video.winfo_exists():
                return

            ret, frame = self.camera_cap.read()
            if not ret or frame is None:
                if self.polling_active:
                    self.root.after(30, self.update_feed)
                return

            # Handle mirroring on screen preview
            if self.var_mirror.get():
                vis = cv2.flip(frame, 1)
            else:
                vis = frame.copy()

            # Draw mouse clicks
            for idx, p in enumerate(self.points):
                cv2.circle(vis, p, 6, (0, 0, 255), -1)
                cv2.putText(vis, str(idx+1), (p[0]+8, p[1]-8),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

            if len(self.points) == 4:
                pts = np.array(self.points, dtype=np.int32)
                cv2.polylines(vis, [pts], True, (255, 255, 255), 2)

                src = np.array([[0,0],[8,0],[8,8],[0,8]], dtype=np.float32)
                dst = np.array(self.points, dtype=np.float32)
                H = cv2.getPerspectiveTransform(src, dst)

                src_grid = np.array([[[x,y] for x in range(9)] for y in range(9)], dtype=np.float32)
                dst_grid = cv2.perspectiveTransform(src_grid.reshape(-1,1,2), H).reshape(9,9,2)

                # Draw lines
                for r in range(9):
                    cv2.polylines(vis, [dst_grid[r,:,:].astype(int)], False, (180, 180, 180), 1)
                for c in range(9):
                    cv2.polylines(vis, [dst_grid[:,c,:].astype(int)], False, (180, 180, 180), 1)

                # Draw labels
                files = 'abcdefgh'
                ranks = '87654321'
                font = cv2.FONT_HERSHEY_SIMPLEX

                for r in range(8):
                    for c in range(8):
                        file_letter = files[c]
                        rank_char = ranks[r]
                        label = f"{file_letter}{rank_char}"

                        center = dst_grid[r, c] + (dst_grid[r+1, c+1] - dst_grid[r, c]) / 2
                        cx, cy = int(center[0]), int(center[1])
                        cv2.putText(vis, label, (cx-12, cy+5), font, 0.4, (0, 255, 255), 1, cv2.LINE_AA)

            # Fit image size dynamically to visual frame using cv2.resize for speed and stability
            lbl_w, lbl_h = self.lbl_video.winfo_width(), self.lbl_video.winfo_height()
            h, w, _ = vis.shape
            if lbl_w > 100 and lbl_h > 100:
                scale = min(lbl_w / w, lbl_h / h)
                new_w, new_h = max(1, int(w * scale)), max(1, int(h * scale))
                vis = cv2.resize(vis, (new_w, new_h), interpolation=cv2.INTER_LINEAR)

            rgb_frame = cv2.cvtColor(vis, cv2.COLOR_BGR2RGB)
            img = Image.fromarray(rgb_frame)
            photo = ImageTk.PhotoImage(image=img)
            self.lbl_video.config(image=photo)
            self.lbl_video.image = photo

            if self.polling_active:
                self.root.after(30, self.update_feed)
        except Exception:
            if self.polling_active:
                self.root.after(50, self.update_feed)

    def on_video_click(self, event):
        """Records pixel coordinates of mouse click directly mapping to original image."""
        if not self.camera_cap:
            return
            
        lbl_w = self.lbl_video.winfo_width()
        lbl_h = self.lbl_video.winfo_height()
        
        ret, frame = self.camera_cap.read()
        if not ret:
            return
        orig_h, orig_w, _ = frame.shape

        scale = min(lbl_w / orig_w, lbl_h / orig_h)
        new_w, new_h = int(orig_w * scale), int(orig_h * scale)
        
        start_x = (lbl_w - new_w) // 2
        start_y = (lbl_h - new_h) // 2

        click_x = event.x - start_x
        click_y = event.y - start_y

        if 0 <= click_x < new_w and 0 <= click_y < new_h:
            x = int(click_x / scale)
            y = int(click_y / scale)

            if len(self.points) < 4:
                self.points.append((x, y))
                self.gui.log(f"[Calibration] Point {len(self.points)}: ({x}, {y})")
            else:
                self.gui.log("[Calibration] Already clicked 4 points. Click 'Reset' to clear.")

    def reset_points(self):
        self.points = []
        self.gui.log("[Calibration] Reset points list.")

    def save_calibration(self):
        if len(self.points) != 4:
            messagebox.showwarning("Warning", "Please select exactly 4 corner points on the board first.")
            return

        ret, frame = self.camera_cap.read()
        if not ret:
            messagebox.showerror("Error", "Could not capture frame to complete calibration saving.")
            return
        orig_h, orig_w, _ = frame.shape

        cam_rot = int(self.var_rot.get())
        mirror_active = self.var_mirror.get()

        # If mirrored preview was active, we un-mirror coordinates back to the original un-mirrored stream coordinate system
        final_points = []
        for pt in self.points:
            if mirror_active:
                final_points.append((orig_w - 1 - pt[0], pt[1]))
            else:
                final_points.append(pt)

        squares_std = compute_grid_calibration(final_points)

        from src.software.core.config import CALIB_JSON
        out_json_path = CALIB_JSON
        os.makedirs(os.path.dirname(out_json_path), exist_ok=True)

        try:
            with open(out_json_path, 'w') as f:
                json.dump(squares_std, f, indent=2)
            self.gui.log(f"[✅] Mapped coordinates written to {out_json_path}.")
            messagebox.showinfo("Success", "Calibration saved successfully!")
            self.go_back()
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save calibration file:\n{e}")

    def stop_camera(self):
        self.polling_active = False
        if self.camera_cap:
            cap_to_release = self.camera_cap
            self.camera_cap = None
            def _release():
                try:
                    with CAMERA_ACCESS_LOCK:
                        cap_to_release.release()
                except Exception:
                    pass
            threading.Thread(target=_release, daemon=True).start()
        try:
            self.root.after(0, self.update_controls_state)
        except Exception:
            pass

    def go_back(self):
        self.stop_camera()
        try:
            if hasattr(self, 'frame') and self.frame.winfo_exists():
                self.frame.destroy()
        except Exception:
            pass
        self.gui.restore_dashboard()
