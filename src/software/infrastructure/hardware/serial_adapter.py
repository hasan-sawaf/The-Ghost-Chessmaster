# Serial Communication Manager for ChessTracker - Decoupled Data & Driver Layer
import serial
import threading
import time

class SerialManager:
    """
    Manages the Serial connection to the Arduino microcontroller.
    Features automatic background reconnection when Arduino is plugged back in.
    """
    def __init__(self):
        self.serial_port = None
        self.is_running = False
        self.read_thread = None
        self._reconnect_thread = None
        
        self.auto_reconnect = True
        self.last_target_port = 'COM7'
        self.last_baudrate = 115200
        
        # Event callbacks
        self.on_telemetry_received = None  # Expected: callback(x, y)
        self.on_status_changed = None      # Expected: callback(status_type, value)
        self.on_button_pressed = None      # Expected: callback(button_char)
        self.on_log_message = None         # Expected: callback(msg)
        self.on_connection_updated = None  # Expected: callback(connected, port)

    def get_available_ports(self):
        import serial.tools.list_ports
        try:
            ports = serial.tools.list_ports.comports()
            return [p.device for p in ports]
        except Exception:
            return []

    def start_auto_reconnect_watcher(self):
        """Starts a background thread that automatically reconnects to Arduino when plugged in."""
        if self._reconnect_thread and self._reconnect_thread.is_alive():
            return
        
        def _reconnect_loop():
            while True:
                time.sleep(1.5)
                if not self.auto_reconnect:
                    continue
                if self.serial_port is None or not self.serial_port.is_open:
                    target_port = self.last_target_port or 'COM7'
                    available = self.get_available_ports()
                    
                    # If target port (e.g. COM7) or any valid COM port is detected, attempt connection
                    if target_port in available:
                        self._log(f"[Serial] Auto-reconnect: Detected {target_port}. Connecting...")
                        self.connect(target_port, self.last_baudrate, is_auto_retry=True)
                    elif available and 'COM7' not in available:
                        # Fallback to first available COM port if target_port isn't present
                        first_port = available[0]
                        self._log(f"[Serial] Auto-reconnect: Attempting connection on available port {first_port}...")
                        self.connect(first_port, self.last_baudrate, is_auto_retry=True)

        self._reconnect_thread = threading.Thread(target=_reconnect_loop, daemon=True)
        self._reconnect_thread.start()
        self._log("[Serial] Started automatic Arduino COM port reconnect watcher.")

    def connect(self, port, baudrate, is_auto_retry=False):
        if self.serial_port and self.serial_port.is_open:
            self._log(f"Already connected to {self.serial_port.port}")
            return True
        
        self.last_target_port = port
        self.last_baudrate = baudrate
        if not is_auto_retry:
            self.auto_reconnect = True

        try:
            self.serial_port = serial.Serial(port, baudrate, timeout=0.05)
            self._log(f"[Serial] Connected to {port} at {baudrate} baud.")
            if self.on_connection_updated:
                self.on_connection_updated(True, port)
            
            # Start reading loop in background thread
            self.is_running = True
            self.read_thread = threading.Thread(target=self._read_loop, daemon=True)
            self.read_thread.start()
            return True
        except Exception as e:
            if not is_auto_retry:
                self._log(f"[Serial] Connection Error on {port}: {e}")
            if self.on_connection_updated:
                self.on_connection_updated(False, port)
            return False

    def send_cmd(self, c):
        if self.serial_port and self.serial_port.is_open:
            try:
                self.serial_port.write(f"{c}\n".encode())
                return True
            except serial.SerialTimeoutException:
                self._log(f"⚠️ Serial Write Timeout: Failed to send command '{c}'.")
            except serial.SerialException as e:
                self._log(f"⚠️ Serial Error: Failed to send command '{c}' ({e})")
        return False

    def _read_loop(self):
        while self.is_running:
            if self.serial_port and self.serial_port.is_open:
                try:
                    if self.serial_port.in_waiting > 0:
                        line = self.serial_port.readline().decode('utf-8').strip()
                        if not line:
                            continue
                            
                        # Parse telemetry
                        if "X:" in line and "Y:" in line:
                            if self.on_telemetry_received:
                                parts = line.split('|')
                                x_val = parts[0].split(':')[1]
                                y_val = parts[1].split(':')[1]
                                self.on_telemetry_received(x_val, y_val)
                                
                        # Parse status reports
                        elif "STATUS: IDLE" in line:
                            if self.on_status_changed:
                                self.on_status_changed("idle", True)
                        elif "STATUS: MAGNET_UP" in line:
                            if self.on_status_changed:
                                self.on_status_changed("magnet", "up")
                        elif "STATUS: MAGNET_DOWN" in line:
                            if self.on_status_changed:
                                self.on_status_changed("magnet", "down")
                        elif "HOME REACHED" in line:
                            if self.on_status_changed:
                                self.on_status_changed("home", True)
                                
                        # Route hardware button presses
                        elif line in ["e", "r", "s", "start_game", "restart", "close", "exit"]:
                            if self.on_button_pressed:
                                self.on_button_pressed(line)
                        else:
                            self._log(f"MCU: {line}")
                except serial.SerialException as e:
                    self._log(f"⚠️ Serial Connection Lost (Unplugged): {e}")
                    self.close(manual=False)
                    break
                except Exception as e:
                    self._log(f"⚠️ Unexpected Serial Read Error: {e}")
            time.sleep(0.01)

    def close(self, manual=False):
        if manual:
            self.auto_reconnect = False
            self._log("[Serial] Manual disconnect triggered. Auto-reconnect paused.")
            
        self.is_running = False
        if self.serial_port:
            port_name = self.serial_port.port
            try:
                self.serial_port.close()
            except Exception:
                pass
            self.serial_port = None
            self._log(f"[Serial] Disconnected from {port_name}")
            if self.on_connection_updated:
                self.on_connection_updated(False, None)

    def _log(self, message):
        if self.on_log_message:
            self.on_log_message(message)
