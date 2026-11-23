import threading
import time
import logging
import cv2

CAMERA_ACCESS_LOCK = threading.RLock()

class CameraManager:
    """
    Monitors Camera 1 (CAM_INDEX = 1) connection status in a background daemon thread.
    Detects when Camera 1 is plugged in / unplugged, and tracks whether the CV Engine is running.
    """
    def __init__(self, cv_bridge, gui=None, check_interval=1.0):
        self._cv_bridge = cv_bridge
        self._gui = gui
        self._check_interval = check_interval
        self._running = False
        self._thread = None
        
        self._is_camera_connected = False
        self._is_camera_on = False
        self._last_state = (None, None)
        
        self.on_status_changed = None  # callback(is_connected: bool, is_on: bool)

    @property
    def is_camera_connected(self):
        return self._is_camera_connected

    @property
    def is_camera_on(self):
        return self._is_camera_on

    @property
    def is_camera_ready(self):
        return self._is_camera_connected and self._is_camera_on

    def start(self):
        if self._running:
            return
        self._running = True
        self._thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self._thread.start()
        logging.info("[CameraManager] Started Camera 1 monitoring thread.")

    def stop(self):
        self._running = False

    def _check_camera_1_available(self):
        """Quick check to verify if Camera 1 is physically plugged in and openable."""
        # 1. If CV Bridge subprocess is actively running, Camera 1 is connected and ON
        if (self._cv_bridge is not None
            and getattr(self._cv_bridge, 'cv_process', None) is not None
            and self._cv_bridge.cv_process.poll() is None
            and getattr(self._cv_bridge, 'is_reading', False)):
            return True, True

        # 2. If Calibration Page is open in GUI, do NOT probe VideoCapture concurrently
        if self._gui is not None and getattr(self._gui, 'calibration_page', None) is not None:
            calib = self._gui.calibration_page
            if getattr(calib, 'camera_cap', None) is not None and getattr(calib, 'polling_active', False):
                # Camera is actively streaming in calibration view
                return True, True
            else:
                # Calibration view is open; return current state to avoid concurrent VideoCapture calls
                return (self._is_camera_connected, False)

        # 3. Safely probe Camera 1 index with shared lock
        with CAMERA_ACCESS_LOCK:
            try:
                cap = cv2.VideoCapture(1, cv2.CAP_DSHOW)
                if not cap.isOpened():
                    cap.release()
                    cap = cv2.VideoCapture(1)
                
                is_open = cap.isOpened()
                cap.release()
                return is_open, False
            except Exception as e:
                logging.debug(f"[CameraManager] Error probing camera 1: {e}")
                return False, False

    def _monitor_loop(self):
        while self._running:
            is_conn, is_on = self._check_camera_1_available()
            self._is_camera_connected = is_conn
            self._is_camera_on = is_on

            current_state = (is_conn, is_on)
            if current_state != self._last_state:
                self._last_state = current_state
                logging.info(f"[CameraManager] Camera 1 Status -> Connected: {is_conn}, Active/ON: {is_on}")
                if self.on_status_changed:
                    try:
                        self.on_status_changed(is_conn, is_on)
                    except Exception as e:
                        logging.debug(f"[CameraManager] Callback error: {e}")

            time.sleep(self._check_interval)
