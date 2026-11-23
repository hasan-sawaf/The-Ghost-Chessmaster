import threading
import time
import logging
import datetime

class BoardOnlineManager:
    """Monitors board online status (WiFi + Arduino) with debouncing and writes 0.5s heartbeats to Firebase RTDB whenever WiFi is connected."""
    def __init__(self, network_manager, serial_manager, camera_manager=None, firebase_manager=None, gui=None, check_interval=0.5):
        self._network_manager = network_manager
        self._serial_manager = serial_manager
        self._camera_manager = camera_manager
        self._firebase_manager = firebase_manager
        self._gui = gui
        self._running = False
        self._thread = None
        self._check_interval = check_interval
        
        self._is_board_online = False
        self._last_board_online = None  # Track to avoid redundant logs and UI triggers
        self.on_status_changed = None  # callback(is_board_online: bool)
        
        # Debounce counters for Arduino status
        initial_arduino = self._check_raw_arduino()
        self._arduino_consecutive_fails = 0 if initial_arduino else 2
        self._arduino_consecutive_successes = 2 if initial_arduino else 0
        self._is_arduino_stable = initial_arduino

    @property
    def firebase_manager(self):
        if self._firebase_manager is not None:
            if callable(self._firebase_manager):
                fm = self._firebase_manager()
                if fm:
                    return fm
            else:
                return self._firebase_manager
        if self._gui is not None and hasattr(self._gui, 'firebase_manager'):
            return self._gui.firebase_manager
        return None

    @property
    def is_wifi_connected(self):
        return self._network_manager.is_online if self._network_manager else False

    @property
    def is_arduino_connected(self):
        return self._is_arduino_stable

    @property
    def is_camera_connected(self):
        return self._camera_manager.is_camera_connected if self._camera_manager else False

    @property
    def is_camera_on(self):
        return self._camera_manager.is_camera_on if self._camera_manager else False

    @property
    def is_board_online(self):
        return self._is_board_online

    def start(self):
        if self._running:
            return
        self._running = True
        self._thread = threading.Thread(target=self._heartbeat_loop, daemon=True)
        self._thread.start()
        logging.info("[BoardOnlineManager] Started board online heartbeat monitoring.")

    def stop(self):
        self._running = False
        # Instantly update RTDB when Python GUI stops or closes ONLY if user is connected
        fm = self.firebase_manager
        if (fm is not None 
            and fm.connected
            and fm.is_user_connected):
            try:
                from firebase_admin import db
                board_id = fm.board_id
                ref = db.reference(f"{board_id}/board_status")
                ref.update({
                    'isBoardOnline': False,
                })
                logging.info("[BoardOnlineManager] Sent immediate offline signal to Firebase RTDB on exit.")
            except Exception as e:
                logging.debug(f"[BoardOnlineManager] Exit status write error: {e}")

    def _check_raw_arduino(self):
        return (self._serial_manager is not None
                and hasattr(self._serial_manager, 'serial_port')
                and self._serial_manager.serial_port is not None 
                and self._serial_manager.serial_port.is_open)

    def _heartbeat_loop(self):
        while self._running:
            raw_arduino = self._check_raw_arduino()
            if raw_arduino:
                self._arduino_consecutive_successes += 1
                self._arduino_consecutive_fails = 0
            else:
                self._arduino_consecutive_fails += 1
                self._arduino_consecutive_successes = 0
            
            # Debounce Arduino connection status (require 2 consecutive checks)
            if not self._is_arduino_stable and self._arduino_consecutive_successes >= 2:
                self._is_arduino_stable = True
            elif self._is_arduino_stable and self._arduino_consecutive_fails >= 2:
                self._is_arduino_stable = False

            # Board is online when:
            # 1. WiFi connection is ON
            # 2. Arduino on COM7 is connected and active
            board_online = self.is_wifi_connected and self._is_arduino_stable
            self._is_board_online = board_online

            # Log and notify status changes only when state actually transitions
            if board_online != self._last_board_online:
                self._last_board_online = board_online
                wifi = self.is_wifi_connected
                arduino = self._is_arduino_stable
                logging.info(f"[BoardOnlineManager] Board Online: {board_online} (WiFi: {wifi}, Arduino: {arduino})")
                if self.on_status_changed:
                    try:
                        self.on_status_changed(board_online)
                    except Exception as e:
                        logging.debug(f"[BoardOnlineManager] Callback error: {e}")

            # Write heartbeat to RTDB every 0.5s ONLY if a mobile app user is actively connected
            fm = self.firebase_manager
            if (self.is_wifi_connected 
                and fm is not None):
                try:
                    # Auto-reconnect Firebase if app launched offline or lost connection
                    if not fm.connected:
                        fm.ensure_connection()

                    if fm.connected and fm.is_user_connected:
                        from firebase_admin import db
                        board_id = fm.board_id
                        ref = db.reference(f"{board_id}/board_status")
                        if board_online:
                            now_utc = datetime.datetime.now(datetime.timezone.utc)
                            now_iso = now_utc.strftime('%Y-%m-%dT%H:%M:%S.') + f"{now_utc.microsecond // 1000:03d}Z"
                            ref.update({
                                'isBoardOnline': True,
                                'lastOnlineWriteTime': now_iso,
                            })
                        else:
                            ref.update({
                                'isBoardOnline': False,
                            })
                except Exception as e:
                    logging.debug(f"[BoardOnlineManager] RTDB heartbeat write error: {e}")

            time.sleep(self._check_interval)
