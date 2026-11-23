import os
import json
import uuid
import logging
import threading
import sys

try:
    import firebase_admin
    from firebase_admin import credentials, db, firestore
    HAS_FIREBASE_ADMIN = True
except ImportError:
    firebase_admin = None
    credentials = None
    db = None
    firestore = None
    HAS_FIREBASE_ADMIN = False

logging.getLogger("urllib3.connectionpool").setLevel(logging.ERROR)

# Global thread exception handler to gracefully catch background urllib3/requests network timeouts in SSE listener threads
def _install_firebase_thread_exception_handler():
    orig_excepthook = getattr(threading, 'excepthook', None)
    def custom_thread_excepthook(args):
        exc_type = args.exc_type
        exc_value = args.exc_value
        exc_str = str(exc_type.__name__) if exc_type else ""
        val_str = str(exc_value) if exc_value else ""
        thread_name = str(getattr(args.thread, 'name', ''))
        
        # If exception is a network timeout or connection reset from background Firebase SSE listener threads, log warning and swallow
        if (issubclass(exc_type, (ConnectionError, TimeoutError, OSError)) or
            "ReadTimeout" in exc_str or "Connection" in exc_str or "NameResolution" in exc_str or
            "urllib3" in val_str or "firebase" in val_str or "_start_listen" in thread_name or "db.py" in str(args)):
            logging.warning(f"🌐 [Firebase Network Notice] Gracefully handled background stream event ({exc_str}): {val_str}")
            return
        if orig_excepthook:
            orig_excepthook(args)
        else:
            sys.__excepthook__(exc_type, exc_value, args.exc_traceback)

    threading.excepthook = custom_thread_excepthook

_install_firebase_thread_exception_handler()


class FirebaseManager:
    """
    Handles connection and communication with Firebase Realtime Database & Firestore.
    Pushes live chess moves and match state from the Python core to the Flutter application,
    and manages real-time board connection tracking via single board node.
    """
    # Default database URL placeholder. Configure your actual URL in board_config.json or pass via constructor.
    def __init__(self, db_url="https://YOUR_FIREBASE_PROJECT_ID-default-rtdb.firebaseio.com/"):
        self.base_db_url = db_url.rstrip('/')
        self.connected = False
        self.board_id = ""
        self.board_name = "BoardOne"
        self.full_rtdb_url = ""
        self.connected_user_email = None
        self.connected_user_id = None
        self.firestore_db = None

        self._action_listener = None
        self._connection_listener = None
        self._live_session_listener = None

        self._load_or_create_board_config()

        if HAS_FIREBASE_ADMIN:
            self._setup_connection()
        else:
            logging.warning("firebase-admin package not found. Run 'pip install firebase-admin' to enable Firebase.")

    @property
    def is_user_connected(self):
        """Returns True only when a user is actively linked and connected to this board."""
        return bool(self.connected_user_id)

    def _load_or_create_board_config(self):
        """Loads board configuration from JSON file or generates a new one if not present."""
        current_dir = os.path.dirname(os.path.abspath(__file__))
        config_dir = os.path.abspath(os.path.join(current_dir, "..", "persistence", "config"))
        os.makedirs(config_dir, exist_ok=True)
        config_file_path = os.path.join(config_dir, "board_config.json")

        if os.path.exists(config_file_path):
            try:
                with open(config_file_path, "r", encoding="utf-8") as f:
                    config_data = json.load(f)
                    self.board_id = config_data.get("board_id", f"BOARD_{uuid.uuid4().hex[:6].upper()}")
                    self.board_name = config_data.get("board_name", "BoardOne")
                    self.full_rtdb_url = config_data.get("rtdb_url", f"{self.base_db_url}/{self.board_id}")
                    logging.info(f"Loaded existing Board Config: {self.board_id} ({self.board_name})")
                    return
            except Exception as e:
                logging.error(f"Error reading board_config.json: {e}")

        # If file doesn't exist or failed to load, generate new config
        self.board_id = f"BOARD_{uuid.uuid4().hex[:6].upper()}"
        self.board_name = "BoardOne"
        self.full_rtdb_url = f"{self.base_db_url}/{self.board_id}"

        config_data = {
            "board_id": self.board_id,
            "board_name": self.board_name,
            "rtdb_url": self.full_rtdb_url
        }

        try:
            with open(config_file_path, "w", encoding="utf-8") as f:
                json.dump(config_data, f, indent=2)
            logging.info(f"Created new Board Config: {self.board_id} at {config_file_path}")
        except Exception as e:
            logging.error(f"Failed to write board_config.json: {e}")

    def get_qr_payload_json(self):
        """Returns JSON payload string for QR code generation."""
        return json.dumps({
            "board_id": self.board_id,
            "board_name": self.board_name,
            "rtdb_url": self.full_rtdb_url
        })

    def ensure_connection(self):
        """Ensures Firebase RTDB connection is active when network connection comes online."""
        if not HAS_FIREBASE_ADMIN:
            return False
        if not self.connected:
            self._setup_connection()
        return self.connected

    def _setup_connection(self):
        if not HAS_FIREBASE_ADMIN:
            return

        try:
            current_dir = os.path.dirname(os.path.abspath(__file__))
            key_path = os.path.abspath(os.path.join(current_dir, "..", "persistence", "config", "serviceAccountKey.json"))

            if not os.path.exists(key_path):
                logging.error(f"Firebase key not found at {key_path}")
                return

            if not firebase_admin._apps:
                cred = credentials.Certificate(key_path)
                firebase_admin.initialize_app(cred, {
                    'databaseURL': self.base_db_url
                })

            if firestore is not None:
                try:
                    self.firestore_db = firestore.client()
                except Exception as fs_err:
                    logging.warning(f"Firestore client init notice: {fs_err}")
            
            self.connected = True
            logging.info(f"Connected to Firebase RTDB & Firestore for board '{self.board_id}'.")
        except Exception as e:
            logging.error(f"Failed to initialize Firebase: {e}")
            self.connected = False

    def push_move(self, move_uci, current_fen, player_color=None):
        """
        Pushes a single move and current board state under {board_id}/current_match in RTDB asynchronously.
        Updates last_move, current_fen, fen, and last_white_move or last_black_move depending on player_color.
        Only writes if a user is actively connected.
        """
        if not self.connected or not HAS_FIREBASE_ADMIN:
            return

        def _do_push():
            try:
                # Resilient connection check
                if not self.is_user_connected:
                    try:
                        conn_snap = db.reference(f"{self.board_id}/connection").get()
                        if isinstance(conn_snap, dict):
                            uid = conn_snap.get('connected_user_id') or conn_snap.get('user_id') or conn_snap.get('userId')
                            status = str(conn_snap.get('status', '')).lower()
                            if uid and status != 'disconnected':
                                self.connected_user_id = uid
                                self.connected_user_email = conn_snap.get('connected_user_email') or conn_snap.get('user_email') or uid
                    except Exception:
                        pass

                if not self.is_user_connected:
                    logging.info(f"Skipping push_move for '{move_uci}' because board is disconnected from any user.")
                    return

                is_white = True
                if player_color:
                    p_str = str(player_color).lower()
                    if p_str.startswith('b') or p_str == 'black':
                        is_white = False

                update_data = {
                    'last_move': move_uci,
                    'current_fen': current_fen,
                    'fen': current_fen,
                    'timestamp': {'.sv': 'timestamp'}
                }

                if is_white:
                    update_data['last_white_move'] = move_uci
                else:
                    update_data['last_black_move'] = move_uci

                ref = db.reference(f"{self.board_id}/current_match")
                ref.update(update_data)

                if self.connected_user_id and self.firestore_db:
                    try:
                        self.firestore_db.collection('live_session').document(self.connected_user_id).set({
                            'last_move': move_uci,
                            'current_fen': current_fen,
                            'timestamp': firestore.SERVER_TIMESTAMP
                        }, merge=True)
                    except Exception as fs_e:
                        logging.warning(f"Could not update Firestore live_session: {fs_e}")

                logging.info(f"Pushed move {move_uci} (White: {is_white}) to {self.board_id}/current_match.")
            except Exception as e:
                logging.warning(f"Notice pushing move to Firebase: {e}")

        threading.Thread(target=_do_push, daemon=True).start()

    def reset_match(self):
        """Resets the match state under {board_id}/current_match in Firebase asynchronously. Preserves session configuration."""
        if not self.connected or not HAS_FIREBASE_ADMIN or not self.is_user_connected:
            return

        def _do_reset():
            try:
                initial_fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
                ref = db.reference(f"{self.board_id}/current_match")
                ref.update({
                    'is_active': True,
                    'last_move': '',
                    'last_white_move': '',
                    'last_black_move': '',
                    'current_fen': initial_fen,
                    'fen': initial_fen,
                    'status': 'ongoing',
                    'timestamp': {'.sv': 'timestamp'}
                })
            except Exception as e:
                logging.warning(f"Notice resetting match on Firebase: {e}")

        threading.Thread(target=_do_reset, daemon=True).start()

    def send_action(self, action_key, message):
        """Sends an action signal under the board's node asynchronously. Only writes if a user is connected."""
        if not self.connected or not HAS_FIREBASE_ADMIN or not self.is_user_connected:
            return

        def _do_send():
            try:
                ref = db.reference(f"{self.board_id}/python_action")
                ref.set({
                    'action': action_key,
                    'sender': 'Python Board GUI',
                    'message': message,
                    'timestamp': {'.sv': 'timestamp'}
                })
                logging.info(f"Python sent action: {action_key}")
            except Exception as e:
                logging.warning(f"Notice sending action to Firebase: {e}")

        threading.Thread(target=_do_send, daemon=True).start()

    def update_camera_status(self, is_on: bool):
        """Updates camera_connection status node in Firebase RTDB asynchronously. Only writes if a user is connected."""
        if not self.connected or not HAS_FIREBASE_ADMIN or not self.is_user_connected:
            return

        def _do_update():
            try:
                ref = db.reference(f"{self.board_id}/camera_connection")
                ref.set('ON' if is_on else 'OFF')
                logging.info(f"Updated camera_connection to {'ON' if is_on else 'OFF'} for {self.board_id}")
            except Exception as e:
                logging.warning(f"Notice updating camera_connection on Firebase: {e}")

        threading.Thread(target=_do_update, daemon=True).start()

    def update_corexy_status(self, is_home: bool):
        """Updates corexy_status node in Firebase RTDB asynchronously as boolean True/False. Only writes if a user is connected."""
        if not self.connected or not HAS_FIREBASE_ADMIN or not self.is_user_connected:
            return

        def _do_update():
            try:
                ref = db.reference(f"{self.board_id}/corexy_status")
                ref.set(bool(is_home))
                logging.info(f"Updated corexy_status to {bool(is_home)} for {self.board_id}")
            except Exception as e:
                logging.warning(f"Notice updating corexy_status on Firebase: {e}")

        threading.Thread(target=_do_update, daemon=True).start()

    def update_game_ended(self, is_ended: bool):
        """Updates isGameEnded field under {board_id}/current_match in Firebase RTDB."""
        if not self.connected or not HAS_FIREBASE_ADMIN or not self.is_user_connected:
            return

        def _do_update():
            try:
                ref = db.reference(f"{self.board_id}/current_match")
                ref.update({'isGameEnded': bool(is_ended)})
                logging.info(f"Updated isGameEnded to {bool(is_ended)} for {self.board_id}")
            except Exception as e:
                logging.warning(f"Notice updating isGameEnded on Firebase: {e}")

        threading.Thread(target=_do_update, daemon=True).start()

    def listen_to_app_actions(self, callback):
        """Listens for action commands pushed from Flutter mobile app under {board_id}/python_action."""
        if not self.connected or not HAS_FIREBASE_ADMIN:
            return None
        try:
            if self._action_listener:
                try:
                    self._action_listener.close()
                except Exception:
                    pass
                self._action_listener = None

            ref = db.reference(f"{self.board_id}/python_action")
            def listener(event):
                data = event.data if isinstance(event.data, dict) else {}
                if not data:
                    return

                if not self.is_user_connected:
                    logging.info(f"Dropped action {data.get('action')} because board is disconnected.")
                    return

                if callback:
                    try:
                        callback(data)
                    except Exception as err:
                        logging.debug(f"Notice in python_action listener callback: {err}")
            
            self._action_listener = ref.listen(listener)
            return self._action_listener
        except Exception as e:
            logging.warning(f"Failed to set python_action listener: {e}")
            return None

    def listen_to_user_connection(self, callback=None):
        """Listens in real-time to board user connection status from Firebase RTDB under {board_id}/connection."""
        if not self.connected or not HAS_FIREBASE_ADMIN:
            logging.warning("Firebase not connected. Connection listener not started.")
            return None
        try:
            if self._connection_listener:
                try:
                    self._connection_listener.close()
                except Exception:
                    pass
                self._connection_listener = None

            ref = db.reference(f"{self.board_id}/connection")

            def _process_data(data):
                if isinstance(data, dict):
                    status = str(data.get('status', 'disconnected')).lower()
                    user_id = data.get('connected_user_id') or data.get('user_id') or data.get('userId')
                    email = data.get('connected_user_email') or data.get('user_email')
                    
                    if status == 'connected' and bool(user_id):
                        self.connected_user_id = str(user_id)
                        self.connected_user_email = str(email) if email else str(user_id)
                    else:
                        self.connected_user_id = None
                        self.connected_user_email = None
                else:
                    self.connected_user_id = None
                    self.connected_user_email = None

            def listener(event):
                try:
                    # Always read latest complete connection state from reference to handle granular/child events reliably
                    snap = ref.get()
                    data = snap if isinstance(snap, dict) else {}
                    _process_data(data)

                    if callback:
                        try:
                            callback(data)
                        except Exception as cb_err:
                            logging.debug(f"Notice in connection callback: {cb_err}")
                except Exception as err:
                    logging.debug(f"Notice in connection listener event: {err}")

            try:
                initial_snapshot = ref.get()
                data = initial_snapshot if isinstance(initial_snapshot, dict) else {}
                _process_data(data)
                if callback:
                    try:
                        callback(data)
                    except Exception as cb_err:
                        logging.debug(f"Notice in initial connection callback: {cb_err}")
            except Exception as init_err:
                logging.warning(f"Notice getting initial connection snapshot: {init_err}")

            self._connection_listener = ref.listen(listener)
            return self._connection_listener
        except Exception as e:
            logging.warning(f"Failed to set connection listener: {e}")
            return None

    def listen_to_live_session(self, callback=None):
        """Listens in real-time to live game session settings from Firebase RTDB under {board_id}/current_match."""
        if not self.connected or not HAS_FIREBASE_ADMIN:
            logging.warning("Firebase not connected. Live session listener not started.")
            return None
        try:
            if self._live_session_listener:
                try:
                    self._live_session_listener.close()
                except Exception:
                    pass
                self._live_session_listener = None

            ref = db.reference(f"{self.board_id}/current_match")
            def listener(event):
                try:
                    # Always read latest complete match snapshot to handle granular single-field changes (e.g. is_white, timer, etc.)
                    snap = ref.get()
                    data = snap if isinstance(snap, dict) else {}
                    if not data:
                        return

                    if callback:
                        try:
                            callback(data)
                        except Exception as cb_err:
                            logging.debug(f"Notice in live_session callback: {cb_err}")
                except Exception as err:
                    logging.debug(f"Notice in live_session listener event: {err}")

            try:
                initial_snapshot = ref.get()
                if isinstance(initial_snapshot, dict) and callback:
                    try:
                        callback(initial_snapshot)
                    except Exception as cb_err:
                        logging.debug(f"Notice in initial live_session callback: {cb_err}")
            except Exception:
                pass

            self._live_session_listener = ref.listen(listener)
            return self._live_session_listener
        except Exception as e:
            logging.warning(f"Failed to set live_session listener: {e}")
            return None

    def close(self):
        """Safely closes all active Firebase SSE stream listeners without blocking the main GUI thread."""
        listeners = [self._action_listener, self._connection_listener, self._live_session_listener]
        self._action_listener = None
        self._connection_listener = None
        self._live_session_listener = None

        def _async_close(lst):
            for listener in lst:
                if listener:
                    try:
                        listener.close()
                    except Exception as e:
                        logging.debug(f"Notice closing Firebase listener: {e}")

        threading.Thread(target=_async_close, args=(listeners,), daemon=True).start()
        logging.info("FirebaseManager initiated non-blocking closure of SSE listeners.")
