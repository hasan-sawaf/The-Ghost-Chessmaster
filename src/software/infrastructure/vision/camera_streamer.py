# Computer Vision Subprocess Bridge - Decoupled Application Logic Layer
import subprocess
import sys
import os
import threading
import time
import json

class CVBridge:
    """
    Manages the subprocess running the Vision & AI Engine.
    Exposes event callbacks to cleanly decouple OpenCV/IPC from Tkinter GUI layers.
    """
    def __init__(self):
        self.cv_process = None
        self.is_reading = False
        
        # Event callbacks
        self.on_video_feed = None       # Expected: callback(feed_type, b64_str)
        self.on_event_received = None   # Expected: callback(event_name, data_dict)
        self.on_action_received = None  # Expected: callback(action_name, data_dict)
        self.on_log_message = None      # Expected: callback(msg)
        self.on_process_stopped = None  # Expected: callback()

    def start_cv(self, current_elo, on_startup_finished_callback=None):
        if self.cv_process is None or self.cv_process.poll() is not None:
            if getattr(sys, 'frozen', False):
                root_dir = os.path.dirname(sys.executable)
                cmd_args = [sys.executable, "--vision"]
            else:
                root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
                cmd_args = [sys.executable, "-u", "-m", "src.software.infrastructure.vision.vision_engine"]

            # Ensure process environment specifies UTF-8 encoding
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "utf-8"

            self.cv_process = subprocess.Popen(
                cmd_args,
                cwd=root_dir,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding='utf-8',
                errors='replace',
                env=env
            )
            self._log("CV Bridge Subprocess Spawned")
            
            self.is_reading = True
            threading.Thread(target=self._read_cv_output_loop, daemon=True).start()

            # Startup health verifier loop
            def _startup_verifier():
                for _ in range(25):
                    time.sleep(0.1)
                    if self.cv_process is None or self.cv_process.poll() is not None:
                        self._log("[CV Bridge] Subprocess exited during initialization (Camera 1 unavailable or failed).")
                        self.is_reading = False
                        self.cv_process = None
                        if self.on_process_stopped:
                            try: self.on_process_stopped()
                            except Exception: pass
                        return

                if self.is_reading and self.cv_process and self.cv_process.poll() is None:
                    self.send_cv_cmd(f"set_elo {current_elo}")
                    if on_startup_finished_callback:
                        on_startup_finished_callback()

            threading.Thread(target=_startup_verifier, daemon=True).start()
        else:
            self._log("CV Bridge process is already running.")

    def send_cv_cmd(self, cmd):
        if self.cv_process and self.cv_process.poll() is None:
            try:
                self.cv_process.stdin.write(cmd + "\n")
                self.cv_process.stdin.flush()
                self._log(f"Sent to CV: '{cmd}'")
            except Exception as e:
                self._log(f"Failed to send CV command: {e}")
        else:
            self._log("CV Bridge is not running.")

    def stop_cv(self):
        self.is_reading = False
        if self.cv_process:
            proc = self.cv_process
            self.cv_process = None
            try:
                proc.terminate()
                proc.wait(timeout=0.1)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass
            self._log("CV Bridge Stopped")

    def _read_cv_output_loop(self):
        if not self.cv_process or not self.cv_process.stdout:
            return

        for line in iter(self.cv_process.stdout.readline, ''):
            if not self.is_reading:
                break
            clean_line = line.strip()
            if clean_line:
                # Video feed outputs
                if clean_line.startswith("__TRACKER__:"):
                    if self.on_video_feed:
                        self.on_video_feed("tracker", clean_line.split(":", 1)[1])
                    continue
                elif clean_line.startswith("__BOARD__:"):
                    if self.on_video_feed:
                        self.on_video_feed("board", clean_line.split(":", 1)[1])
                    continue
                elif clean_line.startswith("__DEBUG_MASK__:"):
                    if self.on_video_feed:
                        self.on_video_feed("mask", clean_line.split(":", 1)[1])
                    continue
                elif clean_line.startswith("__DEBUG_MAP__:"):
                    if self.on_video_feed:
                        self.on_video_feed("map", clean_line.split(":", 1)[1])
                    continue

                self._log(f"[CV] {clean_line}")

                # JSON event routing
                if '"event"' in clean_line:
                    try:
                        data = json.loads(clean_line)
                        if self.on_event_received:
                            self.on_event_received(data.get("event"), data)
                    except Exception:
                        pass
                elif '"action"' in clean_line:
                    try:
                        data = json.loads(clean_line)
                        if self.on_action_received:
                            self.on_action_received(data.get("action"), data)
                    except Exception:
                        pass
                        
        self.is_reading = False
        self.cv_process = None
        self._log("CV Bridge process ended.")
        if self.on_process_stopped:
            try:
                self.on_process_stopped()
            except Exception:
                pass

    def _log(self, message):
        if self.on_log_message:
            self.on_log_message(message)
