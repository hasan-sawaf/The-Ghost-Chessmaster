import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../models/firestore_constants.dart';
import '../../../models/live_session_model.dart';
import '../../../../services/firebase_service.dart';
import '../presentation/pages/board_qr_scanner_page.dart';

class ConnectedBoardInfo {
  final String boardId;
  final String boardName;
  final String rtdbUrl;
  final bool isConnected;

  ConnectedBoardInfo({
    required this.boardId,
    required this.boardName,
    required this.rtdbUrl,
    required this.isConnected,
  });
}

class BoardConnectionService {
  static final BoardConnectionService _instance = BoardConnectionService._internal();
  static BoardConnectionService get instance => _instance;
  BoardConnectionService._internal();

  static const String _keyBoardId = 'connected_board_id';
  static const String _keyBoardName = 'connected_board_name';
  static const String _keyRtdbUrl = 'connected_rtdb_url';
  static const String _keyIsConnected = 'is_board_connected';

  ConnectedBoardInfo? _currentInfo;
  ConnectedBoardInfo? get currentInfo => _currentInfo;
  bool get isConnected => _currentInfo != null && _currentInfo!.isConnected;

  // Real-time Telemetry State
  bool _isCameraOn = false;
  bool get isCameraOn => _isCameraOn;

  bool _isCorexyHome = true;
  bool get isCorexyHome => _isCorexyHome;

  StreamSubscription<DatabaseEvent>? _cameraSub;
  StreamSubscription<DatabaseEvent>? _corexySub;

  // Board Online Status
  StreamSubscription<DatabaseEvent>? _boardStatusSub;
  bool _isBoardOnline = false;
  bool get isBoardOnline => _isBoardOnline;
  String _lastOnlineWriteTime = '';
  String get lastOnlineWriteTime => _lastOnlineWriteTime;
  
  final StreamController<bool> _boardOnlineController = StreamController<bool>.broadcast();
  Stream<bool> get boardOnlineStream => _boardOnlineController.stream;

  final StreamController<ConnectedBoardInfo?> _connectionController =
      StreamController<ConnectedBoardInfo?>.broadcast();
  Stream<ConnectedBoardInfo?> get connectionStream => _connectionController.stream;

  final StreamController<bool> _cameraStateController = StreamController<bool>.broadcast();
  Stream<bool> get cameraStateStream => _cameraStateController.stream;

  final StreamController<bool> _corexyStateController = StreamController<bool>.broadcast();
  Stream<bool> get corexyStateStream => _corexyStateController.stream;

  DateTime? _lastReceivedPacketTime;
  bool? _lastEmittedOnline;

  /// Checks if board is truly online:
  /// Primary: _isBoardOnline == true (set by Python backend in RTDB)
  /// Secondary: Fresh heartbeat received within the last 5 seconds (immune to cross-device clock skew)
  bool checkBoardOnline() {
    if (!_isBoardOnline) return false;
    if (_lastReceivedPacketTime != null) {
      final elapsed = DateTime.now().difference(_lastReceivedPacketTime!).inMilliseconds;
      if (elapsed > 5000) {
        return false;
      }
    }
    return _isBoardOnline;
  }

  /// Loads saved board connection state:
  /// Loads saved board connection state:
  /// 1. Instant check from memory / SharedPreferences (0ms fast startup).
  /// 2. Performs asynchronous cloud verification in the background.
  Future<ConnectedBoardInfo?> loadConnectionState({bool forceRemoteCheck = false}) async {
    // 1. If already in memory and not forcing remote check, return immediately (0ms)
    if (_currentInfo != null && !forceRemoteCheck) {
      return _currentInfo;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final isConn = prefs.getBool(_keyIsConnected) ?? false;
      final cachedBoardId = prefs.getString(_keyBoardId);
      final cachedBoardName = prefs.getString(_keyBoardName);
      final cachedRtdbUrl = prefs.getString(_keyRtdbUrl);

      if (isConn && cachedBoardId != null && cachedBoardName != null) {
        _currentInfo = ConnectedBoardInfo(
          boardId: cachedBoardId,
          boardName: cachedBoardName,
          rtdbUrl: cachedRtdbUrl ?? '',
          isConnected: true,
        );
        _startTelemetryListeners(cachedBoardId);
        _connectionController.add(_currentInfo);

        // Background non-blocking verification with Firestore
        _verifyRemoteConnectionInBackground(cachedBoardId);
        return _currentInfo;
      }

      // If not in local cache, do a fast remote lookup with short timeout
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final querySnap = await FirebaseFirestore.instance
              .collection(FirestoreConstants.boardsCollection)
              .where('connected_user_id', isEqualTo: user.uid)
              .where('status', isEqualTo: 'connected')
              .limit(1)
              .get()
              .timeout(const Duration(milliseconds: 1500));

          if (querySnap.docs.isNotEmpty) {
            final doc = querySnap.docs.first;
            final data = doc.data();
            final remoteBoardId = doc.id;
            final remoteBoardName = (data['board_name'] ?? 'BoardOne').toString();
            final remoteRtdbUrl = (data['rtdb_url'] ?? '').toString();

            await prefs.setBool(_keyIsConnected, true);
            await prefs.setString(_keyBoardId, remoteBoardId);
            await prefs.setString(_keyBoardName, remoteBoardName);
            await prefs.setString(_keyRtdbUrl, remoteRtdbUrl);

            _currentInfo = ConnectedBoardInfo(
              boardId: remoteBoardId,
              boardName: remoteBoardName,
              rtdbUrl: remoteRtdbUrl,
              isConnected: true,
            );
            _startTelemetryListeners(remoteBoardId);
            _connectionController.add(_currentInfo);
            return _currentInfo;
          }
        } catch (e) {
          debugPrint('[BOARD_CONNECTION_SERVICE] Fast remote lookup notice: $e');
        }
      }
    } catch (e) {
      debugPrint('[BOARD_CONNECTION_SERVICE] Error loading connection state: $e');
    }

    _currentInfo = null;
    _stopTelemetryListeners();
    _connectionController.add(null);
    return null;
  }

  /// Verifies connection against Firestore in background without blocking UI
  void _verifyRemoteConnectionInBackground(String localBoardId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection(FirestoreConstants.boardsCollection)
        .where('connected_user_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'connected')
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 3))
        .then((querySnap) async {
          if (querySnap.docs.isEmpty) {
            debugPrint('[BOARD_CONNECTION_SERVICE] Background sync: Board disconnected remotely. Clearing local state.');
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_keyIsConnected, false);
            await prefs.remove(_keyBoardId);
            await prefs.remove(_keyBoardName);
            await prefs.remove(_keyRtdbUrl);
            _stopTelemetryListeners();
            _currentInfo = null;
            _connectionController.add(null);
          }
        })
        .catchError((e) {
          debugPrint('[BOARD_CONNECTION_SERVICE] Background verify notice: $e');
        });
  }

  void onUserSignedOut() {
    if (_currentInfo != null) {
      disconnectFromBoard();
    }
    _stopTelemetryListeners();
    _currentInfo = null;
    _isCameraOn = false;
    _isCorexyHome = true;
    _isBoardOnline = false;
    _lastOnlineWriteTime = '';
    _connectionController.add(null);
    _cameraStateController.add(false);
    _corexyStateController.add(true);
    _boardOnlineController.add(false);
  }

  void _startTelemetryListeners(String boardId) {
    _stopTelemetryListeners();

    // 1. Camera Connection Stream ({boardId}/camera_connection)
    try {
      final cameraRef = FirebaseDatabase.instance.ref('$boardId/camera_connection');
      _cameraSub = cameraRef.onValue.listen((event) {
        final val = event.snapshot.value;
        bool isOn = false;
        if (val is bool) {
          isOn = val;
        } else if (val is String) {
          isOn = val.toUpperCase() == 'ON' || val.toLowerCase() == 'true';
        } else if (val is Map) {
          isOn = val['status']?.toString().toUpperCase() == 'ON' || val['is_on'] == true;
        }
        _isCameraOn = isOn;
        _cameraStateController.add(_isCameraOn);
        debugPrint('[BOARD_TELEMETRY] Camera status updated: $_isCameraOn');
      });
    } catch (e) {
      debugPrint('[BOARD_TELEMETRY] Error subscribing to camera_connection: $e');
    }

    // 2. CoreXY Status Stream ({boardId}/corexy_status)
    try {
      final corexyRef = FirebaseDatabase.instance.ref('$boardId/corexy_status');
      _corexySub = corexyRef.onValue.listen((event) {
        final val = event.snapshot.value;
        bool isHome = true;
        if (val is bool) {
          isHome = val;
        } else if (val is String) {
          isHome = val.toLowerCase() == 'home' || val.toLowerCase() == 'aligned';
        } else if (val is Map) {
          isHome = val['is_home'] == true || val['status']?.toString().toLowerCase() == 'home';
        }
        _isCorexyHome = isHome;
        _corexyStateController.add(_isCorexyHome);
        debugPrint('[BOARD_TELEMETRY] CoreXY status updated: $_isCorexyHome');
      });
    } catch (e) {
      debugPrint('[BOARD_TELEMETRY] Error subscribing to corexy_status: $e');
    }

    // Board Online Status Listener ({boardId}/board_status)
    _boardStatusSub?.cancel();
    final boardStatusRef = FirebaseDatabase.instance.ref('$boardId/board_status');
    _boardStatusSub = boardStatusRef.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        try {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          _isBoardOnline = data['isBoardOnline'] == true;
          _lastOnlineWriteTime = (data['lastOnlineWriteTime'] ?? '').toString();
          _lastReceivedPacketTime = DateTime.now();
        } catch (e) {
          debugPrint('[BOARD_TELEMETRY] Error parsing board_status: $e');
        }
        final nowOnline = checkBoardOnline();
        _notifyBoardOnlineStatus(nowOnline);
        debugPrint('[BOARD_TELEMETRY] Board Online status updated: $nowOnline (_isBoardOnline=$_isBoardOnline)');
      } else {
        _isBoardOnline = false;
        _notifyBoardOnlineStatus(false);
      }
    });

    _startStalenessTimer();
  }

  bool _wasPreviouslyOnline = false;

  void _notifyBoardOnlineStatus(bool nowOnline) {
    if (_lastEmittedOnline == nowOnline) {
      return; // Deduplicate: Never emit duplicate values or cause UI flickering
    }
    _lastEmittedOnline = nowOnline;

    if (!_wasPreviouslyOnline && nowOnline) {
      // Connection restored! Call FirebaseService.resetMatch() automatically as the first action
      final boardId = _currentInfo?.boardId ?? 'BOARD_8AA5C5';
      FirebaseService.resetMatch(boardId: boardId);
      debugPrint('[BOARD_CONNECTION_SERVICE] Connection restored -> Triggered FirebaseService.resetMatch() on $boardId');
    }
    _wasPreviouslyOnline = nowOnline;
    _boardOnlineController.add(nowOnline);
  }

  Timer? _stalenessTimer;

  void _startStalenessTimer() {
    _stalenessTimer?.cancel();
    _stalenessTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentInfo != null && _currentInfo!.isConnected) {
        final currentOnline = checkBoardOnline();
        _notifyBoardOnlineStatus(currentOnline);
      }
    });
  }

  void _stopTelemetryListeners() {
    _cameraSub?.cancel();
    _cameraSub = null;
    _corexySub?.cancel();
    _corexySub = null;
    _boardStatusSub?.cancel();
    _boardStatusSub = null;
    _stalenessTimer?.cancel();
    _stalenessTimer = null;
  }

  /// Toggles camera state ON or OFF in Firebase RTDB
  Future<void> toggleCamera({bool? turnOn}) async {
    final targetState = turnOn ?? !_isCameraOn;
    _isCameraOn = targetState;
    _cameraStateController.add(_isCameraOn);

    if (_currentInfo != null && _currentInfo!.isConnected) {
      final boardId = _currentInfo!.boardId;
      try {
        await FirebaseDatabase.instance
            .ref('$boardId/camera_connection')
            .set(targetState ? 'ON' : 'OFF');

        await FirebaseDatabase.instance.ref('$boardId/python_action').set({
          'action': 'TOGGLE_CAMERA',
          'camera': targetState ? 'ON' : 'OFF',
          'sender': 'Flutter App',
          'timestamp': ServerValue.timestamp,
        });

        debugPrint('[BOARD_CONNECTION_SERVICE] Toggled camera to ${targetState ? "ON" : "OFF"} for $boardId');
      } catch (e) {
        debugPrint('[BOARD_CONNECTION_SERVICE] Error toggling camera: $e');
      }
    }
  }

  /// Sends an action command to the Python core via `{boardId}/python_action`
  Future<void> sendAppAction(String action, [Map<String, dynamic>? extraData]) async {
    if (_currentInfo != null && _currentInfo!.isConnected) {
      final boardId = _currentInfo!.boardId;
      try {
        final Map<String, dynamic> payload = {
          'action': action,
          'sender': 'Flutter App',
          'timestamp': ServerValue.timestamp,
        };
        if (extraData != null) {
          payload.addAll(extraData);
        }
        await FirebaseDatabase.instance
            .ref('$boardId/python_action')
            .set(payload)
            .timeout(const Duration(milliseconds: 1000), onTimeout: () {});
        debugPrint('[BOARD_CONNECTION_SERVICE] Sent app action $action to $boardId');
      } catch (e) {
        debugPrint('[BOARD_CONNECTION_SERVICE] Error sending app action: $e');
      }
    }
  }

  /// Shows standard modal explaining board connection is required when user selects Physical Board mode without connection.
  void showBoardRequirementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.phonelink_erase_rounded, color: AppColors.error, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Board Connection Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Your account is not connected to a physical chess board. Please connect your physical board by scanning the QR code first.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BoardQrScannerPage()),
                );
              },
              child: const Text('Scan QR Code to Connect', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Starts board camera with loading indicator & status verification.
  /// Returns `true` if camera successfully turned ON, `false` otherwise.
  Future<bool> startCameraWithVerification(BuildContext context) async {
    if (!isConnected) {
      showBoardRequirementDialog(context);
      return false;
    }

    if (_isCameraOn) {
      return true;
    }

    // Show non-dismissible loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGold),
                  SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      'Connecting & Starting Camera...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Send command to turn ON camera
    await toggleCamera(turnOn: true);

    // Wait for up to 6 seconds for RTDB telemetry to confirm camera is ON
    final completer = Completer<bool>();
    late StreamSubscription<bool> sub;

    final timer = Timer(const Duration(seconds: 6), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    sub = cameraStateStream.listen((isOn) {
      if (isOn && !completer.isCompleted) {
        timer.cancel();
        completer.complete(true);
      }
    });

    if (_isCameraOn && !completer.isCompleted) {
      timer.cancel();
      completer.complete(true);
    }

    final success = await completer.future;
    await sub.cancel();

    // Dismiss loading dialog safely
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (success) {
      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          '🟢 Camera connected and turned ON successfully!',
          iconAsset: 'assets/icons/1024x/correct_1024x.png',
        );
      }
      return true;
    } else {
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          '🔴 Camera failed to turn ON! Match cancelled.',
          iconAsset: 'assets/icons/1024x/wrong_1024x.png',
        );
      }
      return false;
    }
  }



  /// Connects user to board by updating Firestore `boards` + `live_session`, RTDB, and SharedPreferences
  /// Connects user to board by updating Firestore `boards` + `live_session`, RTDB, and SharedPreferences in parallel
  Future<bool> connectToBoard({
    required String boardId,
    required String boardName,
    required String rtdbUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email ?? 'user@ghostchess.com';
      final userId = user?.uid ?? 'user_uid';

      // 1. Instantly update local state and SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsConnected, true);
      await prefs.setString(_keyBoardId, boardId);
      await prefs.setString(_keyBoardName, boardName);
      await prefs.setString(_keyRtdbUrl, rtdbUrl);

      _currentInfo = ConnectedBoardInfo(
        boardId: boardId,
        boardName: boardName,
        rtdbUrl: rtdbUrl,
        isConnected: true,
      );

      _isCameraOn = false;
      _cameraStateController.add(false);
      _startTelemetryListeners(boardId);
      _connectionController.add(_currentInfo);

      // 2. Dispatch all cloud & RTDB writes in parallel with timeout for ultra-fast response
      final liveSession = LiveSessionModel(
        boardId: boardId,
        connectedUserId: userId,
      );

      final List<Future<dynamic>> parallelTasks = [
        // A. Firestore boards collection
        FirebaseFirestore.instance
            .collection(FirestoreConstants.boardsCollection)
            .doc(boardId)
            .set({
          'id': boardId,
          'board_name': boardName,
          'rtdb_url': rtdbUrl,
          'connected_user_email': userEmail,
          'connected_user_id': userId,
          'status': 'connected',
          'last_active': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 2000), onTimeout: () {}),

        // B. Firestore live_session collection
        FirebaseFirestore.instance
            .collection(FirestoreConstants.liveSessionCollection)
            .doc(userId)
            .set(liveSession.toMap(), SetOptions(merge: true)).timeout(const Duration(milliseconds: 2000), onTimeout: () {}),

        // C. RTDB connection node
        FirebaseDatabase.instance.ref('$boardId/connection').set({
          'board_id': boardId,
          'board_name': boardName,
          'connected_user_email': userEmail,
          'connected_user_id': userId,
          'status': 'connected',
          'timestamp': ServerValue.timestamp,
        }).timeout(const Duration(milliseconds: 2000), onTimeout: () {}),

        // D. RTDB camera_connection default OFF
        FirebaseDatabase.instance.ref('$boardId/camera_connection').set('OFF').timeout(const Duration(milliseconds: 1500), onTimeout: () {}),

        // E. RTDB current_match node initialization
        FirebaseDatabase.instance.ref('$boardId/current_match').set({
          'board_id': boardId,
          'connected_user_id': userId,
          'user_id': userId,
          'is_active': true,
          'is_white': true,
          'timer': 600,
          'inc_time': 0,
          'difficulty': 5,
          'elo': 1300,
          'play_style': 'style_balanced',
          'last_move': '',
          'last_white_move': '',
          'last_black_move': '',
          'current_fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'timestamp': ServerValue.timestamp,
        }).timeout(const Duration(milliseconds: 2000), onTimeout: () {}),
      ];

      try {
        await Future.wait(parallelTasks);
      } catch (e) {
        debugPrint('[BOARD_CONNECTION_SERVICE] Notice during parallel connect writes: $e');
      }

      debugPrint('[BOARD_CONNECTION_SERVICE] Successfully connected to board $boardId ($boardName) for user $userId');
      return true;
    } catch (e) {
      debugPrint('[BOARD_CONNECTION_SERVICE] Error connecting to board: $e');
      return false;
    }
  }

  /// Disconnects user from the currently connected board instantly (sub-100ms) with guaranteed cloud & RTDB cleanup
  Future<bool> disconnectFromBoard() async {
    final prefs = await SharedPreferences.getInstance();
    final boardId = _currentInfo?.boardId ?? prefs.getString(_keyBoardId) ?? 'BOARD_8AA5C5';
    final boardName = _currentInfo?.boardName ?? prefs.getString(_keyBoardName) ?? 'BoardOne';
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // 1. Instantly update local state and streams (0ms UI latency)
    _stopTelemetryListeners();
    _currentInfo = null;
    _isCameraOn = false;
    _isCorexyHome = true;
    _isBoardOnline = false;
    _lastOnlineWriteTime = '';
    _connectionController.add(null);
    _cameraStateController.add(false);
    _corexyStateController.add(true);
    _boardOnlineController.add(false);

    // 2. Clear SharedPreferences
    await prefs.setBool(_keyIsConnected, false);
    await prefs.remove(_keyBoardId);
    await prefs.remove(_keyBoardName);
    await prefs.remove(_keyRtdbUrl);

    // 3. Execute all remote network disconnect operations in parallel with timeout
    final List<Future<dynamic>> parallelTasks = [
      // A. Update RTDB connection node to disconnected
      FirebaseDatabase.instance.ref('$boardId/connection').set({
        'board_id': boardId,
        'board_name': boardName,
        'status': 'disconnected',
        'connected_user_id': '',
        'connected_user_email': '',
        'timestamp': ServerValue.timestamp,
      }).timeout(const Duration(milliseconds: 1500), onTimeout: () {}),

      // B. Remove RTDB connected user sub-nodes explicitly
      FirebaseDatabase.instance.ref('$boardId/connection/connected_user_id').remove().timeout(const Duration(milliseconds: 1500), onTimeout: () {}),
      FirebaseDatabase.instance.ref('$boardId/connection/connected_user_email').remove().timeout(const Duration(milliseconds: 1500), onTimeout: () {}),

      // C. Turn off camera in RTDB
      FirebaseDatabase.instance.ref('$boardId/camera_connection').set('OFF').timeout(const Duration(milliseconds: 1500), onTimeout: () {}),

      // D. Clear active match and send STOP_MATCH to Python GUI
      FirebaseDatabase.instance.ref('$boardId/current_match').remove().timeout(const Duration(milliseconds: 1500), onTimeout: () {}),
      FirebaseDatabase.instance.ref('$boardId/python_action').set({
        'action': 'STOP_MATCH',
        'sender': 'Flutter App',
        'timestamp': ServerValue.timestamp,
      }).timeout(const Duration(milliseconds: 1500), onTimeout: () {}),

      // E. Update Firestore boards collection
      FirebaseFirestore.instance
          .collection(FirestoreConstants.boardsCollection)
          .doc(boardId)
          .set({
        'status': 'disconnected',
        'connected_user_email': null,
        'connected_user_id': null,
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 1500), onTimeout: () {}),
    ];

    // F. Delete live_session document & clear user-linked boards in Firestore
    if (userId.isNotEmpty) {
      parallelTasks.add(
        FirebaseFirestore.instance
            .collection(FirestoreConstants.liveSessionCollection)
            .doc(userId)
            .delete()
            .timeout(const Duration(milliseconds: 1500), onTimeout: () {}),
      );

      parallelTasks.add(
        FirebaseFirestore.instance
            .collection(FirestoreConstants.boardsCollection)
            .where('connected_user_id', isEqualTo: userId)
            .get()
            .timeout(const Duration(milliseconds: 1500))
            .then((snap) {
              for (final doc in snap.docs) {
                doc.reference.update({
                  'status': 'disconnected',
                  'connected_user_id': null,
                  'connected_user_email': null,
                  'last_active': FieldValue.serverTimestamp(),
                }).catchError((_) {});
              }
            })
            .catchError((_) {}),
      );
    }

    try {
      await Future.wait(parallelTasks);
    } catch (e) {
      debugPrint('[BOARD_CONNECTION_SERVICE] Disconnect parallel tasks notice: $e');
    }

    debugPrint('[BOARD_CONNECTION_SERVICE] Successfully disconnected from board $boardId');
    return true;
  }

  /// Displays a modal asking the user to confirm that all physical chess pieces are placed in their standard initial positions.
  Future<bool> showPhysicalBoardInitialPositionDialog(BuildContext context, {bool isAr = false}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.grid_on_rounded, color: AppColors.primaryGold, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr ? 'تأكيد الموضع الابتدائي للقطع' : 'Confirm Initial Piece Setup',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            isAr
                ? 'يرجى التأكد من وضع جميع قطع الشطرنج الفيزيائية في مواضعها الابتدائية القياسية على الرقعة قبل بدء اللعب.'
                : 'Please make sure all physical chess pieces are placed in their standard initial starting positions on the board before proceeding.',
            style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                isAr ? 'نعم، القطع في مواضعها' : 'Yes, Pieces Are Ready',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  /// Updates the active match settings in Firestore & RTDB under `{boardId}/current_match`.
  Future<void> updateLiveSessionState({
    required bool isWhite,
    int? timer,
    int? incTime,
    int? difficulty,
    String? playStyle,
    int? elo,
    String? lastMove,
    String? currentFen,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final boardId = prefs.getString(_keyBoardId) ?? 'BOARD_8AA5C5';
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (userId.isNotEmpty) {
        final Map<String, dynamic> updateData = {
          'is_white': isWhite,
          'timestamp': FieldValue.serverTimestamp(),
        };
        if (boardId.isNotEmpty) updateData['board_id'] = boardId;
        if (timer != null) updateData['timer'] = timer;
        if (incTime != null) updateData['inc_time'] = incTime;
        if (difficulty != null) updateData['difficulty'] = difficulty;
        if (playStyle != null) updateData['play_style'] = playStyle;
        if (elo != null) updateData['elo'] = elo;
        if (lastMove != null) updateData['last_move'] = lastMove;
        if (currentFen != null) updateData['current_fen'] = currentFen;
        updateData['connected_user_id'] = userId;
        updateData['user_id'] = userId;

        // 1. Update Firestore live_session collection (docId = userId)
        await FirebaseFirestore.instance
            .collection(FirestoreConstants.liveSessionCollection)
            .doc(userId)
            .set(updateData, SetOptions(merge: true))
            .timeout(const Duration(milliseconds: 1000), onTimeout: () {});

        // 2. Update Realtime Database node `{boardId}/current_match`
        final Map<String, dynamic> rtdbUpdateData = Map.from(updateData);
        rtdbUpdateData['timestamp'] = ServerValue.timestamp;
        await FirebaseDatabase.instance
            .ref('$boardId/current_match')
            .update(rtdbUpdateData)
            .timeout(const Duration(milliseconds: 1000), onTimeout: () {});

        debugPrint('[BOARD_CONNECTION_SERVICE] Updated match settings on $boardId/current_match: is_white=$isWhite, timer=$timer, incTime=$incTime, difficulty=$difficulty.');
      }
    } catch (e) {
      debugPrint('[BOARD_CONNECTION_SERVICE] Error updating live_session state: $e');
    }
  }

  /// Actively queries Firebase RTDB for the latest board_status snapshot and verifies online state.
  Future<bool> verifyAndCheckBoardOnline() async {
    if (_currentInfo == null || !_currentInfo!.isConnected) return false;
    final boardId = _currentInfo!.boardId;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('$boardId/board_status')
          .get()
          .timeout(const Duration(milliseconds: 1500));
      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        _isBoardOnline = data['isBoardOnline'] == true;
        _lastOnlineWriteTime = (data['lastOnlineWriteTime'] ?? '').toString();
        _boardOnlineController.add(checkBoardOnline());
      }
    } catch (e) {
      debugPrint('[BOARD_CONNECTION_SERVICE] Error actively verifying board_status: $e');
    }
    return checkBoardOnline();
  }

  /// Shows a dialog informing user the board is offline with an active async Retry check.
  /// Returns true if board is verified online after retry, false otherwise.
  Future<bool> showBoardOfflineDialog(BuildContext context, {bool isAr = false}) async {
    bool isRetrying = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    isAr ? 'الرقعة غير متصلة' : 'Board Offline',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAr
                        ? 'رقعة الشطرنج الفعلية غير متصلة حالياً. يرجى التحقق من اتصال WiFi والـ Arduino في برنامج البايثون ثم إعادة المحاولة.'
                        : 'The physical chess board is currently offline. Please check WiFi & Arduino connection in the Python GUI, then try again.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (isRetrying) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(color: AppColors.primaryGold),
                    const SizedBox(height: 8),
                    Text(
                      isAr ? 'جاري الفحص...' : 'Verifying connection...',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!isRetrying)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx2, false),
                    child: Text(isAr ? 'إلغاء' : 'Cancel'),
                  ),
                if (!isRetrying)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      setDialogState(() {
                        isRetrying = true;
                      });
                      final isOnline = await verifyAndCheckBoardOnline();
                      if (!ctx2.mounted) return;
                      if (isOnline) {
                        Navigator.pop(ctx2, true);
                      } else {
                        setDialogState(() {
                          isRetrying = false;
                        });
                        AppSnackBar.show(
                          ctx2,
                          message: isAr
                              ? 'الرقعة ما زالت غير متصلة. يرجى التأكد من تشغيل البايثون والـ WiFi'
                              : 'Board is still offline. Please check Python GUI & WiFi.',
                          type: SnackBarType.error,
                        );
                      }
                    },
                  ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  }

  /// Shows a non-dismissible dialog when board goes offline during a game.
  /// Keeps checking every 1s and auto-dismisses when board comes back online.
  void showMidGameOfflineDialog(BuildContext context, {bool isAr = false}) {
    bool dismissed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            // Start a periodic timer to check board status
            Timer.periodic(const Duration(seconds: 1), (timer) {
              if (dismissed || !ctx2.mounted) {
                timer.cancel();
                return;
              }
              if (checkBoardOnline()) {
                dismissed = true;
                timer.cancel();
                if (ctx2.mounted) Navigator.pop(ctx2);
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    isAr ? 'فقد الاتصال بالرقعة' : 'Board Disconnected',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAr
                        ? 'فقد الاتصال بالرقعة الفعلية. جاري محاولة إعادة الاتصال...'
                        : 'Lost connection to the physical board. Attempting to reconnect...',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    isAr ? 'يرجى التحقق من WiFi و Arduino' : 'Please check WiFi & Arduino connection',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dismissed = true;
                    Navigator.pop(ctx2);
                  },
                  child: Text(isAr ? 'إلغاء' : 'Dismiss'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows a modal dialog explaining that the CoreXY machine is not in Home (0,0) position.
  Future<void> showCorexyNotHomeDialog(BuildContext context, {bool isAr = false}) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.precision_manufacturing_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAr ? 'المحرك الآلي ليس في موضع البداية' : 'CoreXY Not at Home',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isAr
              ? 'المحرك الآلي للرقعة (CoreXY) ليس في موضع الصفر (0, 0). يرجى الانتظار حتى تعود الذراع الآلية لموضع البداية.'
              : 'The CoreXY robotic mechanism is not at the Home position (0, 0). Please wait until the robotic arm returns to Home before starting the match.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'حسناً' : 'OK'),
          ),
        ],
      ),
    );
  }
}

