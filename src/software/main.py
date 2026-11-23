import os
import sys
import io
import multiprocessing

os.environ["PYTHONIOENCODING"] = "utf-8"

class SafeStreamWriter:
    def __init__(self, original_stream):
        self.original_stream = original_stream

    def write(self, s):
        if not s:
            return
        try:
            self.original_stream.write(s)
        except Exception:
            try:
                safe_s = s.encode('ascii', errors='replace').decode('ascii')
                self.original_stream.write(safe_s)
            except Exception:
                pass

    def flush(self):
        try:
            self.original_stream.flush()
        except Exception:
            pass

    def isatty(self):
        return False

if sys.stdout is not None and not isinstance(sys.stdout, SafeStreamWriter):
    sys.stdout = SafeStreamWriter(sys.stdout)
if sys.stderr is not None and not isinstance(sys.stderr, SafeStreamWriter):
    sys.stderr = SafeStreamWriter(sys.stderr)

# Force stdout & stderr encoding to UTF-8 with error replacement to prevent charmap UnicodeEncodeError on Windows
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass
if hasattr(sys.stderr, 'reconfigure'):
    try:
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

def run():
    if sys.platform == "win32":
        try:
            import ctypes
            myappid = "graduation.chesstracker.dashboard.1.0"
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)
        except Exception:
            pass

    os.environ["OPENCV_LOG_LEVEL"] = "FATAL"
    multiprocessing.freeze_support()
    
    if len(sys.argv) > 1 and sys.argv[1] == "--vision":
        from src.software.infrastructure.vision.vision_engine import main as vision_main
        vision_main()
    else:
        from src.software.presentation.app import main as gui_main
        gui_main()
