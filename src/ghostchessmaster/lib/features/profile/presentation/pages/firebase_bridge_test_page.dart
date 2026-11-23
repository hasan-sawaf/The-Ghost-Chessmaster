import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';

class FirebaseBridgeTestPage extends StatefulWidget {
  const FirebaseBridgeTestPage({super.key});

  @override
  State<FirebaseBridgeTestPage> createState() => _FirebaseBridgeTestPageState();
}

class _FirebaseBridgeTestPageState extends State<FirebaseBridgeTestPage> {
  final DatabaseReference _testBridgeRef = FirebaseDatabase.instance.ref('BoardOne');
  StreamSubscription<DatabaseEvent>? _pythonActionSubscription;
  final List<Map<String, String>> _logMessages = [];
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _listenToPythonMessages();
  }

  @override
  void dispose() {
    _pythonActionSubscription?.cancel();
    super.dispose();
  }

  void _listenToPythonMessages() {
    _pythonActionSubscription = _testBridgeRef.child('python_action').onValue.listen(
      (event) {
        if (!mounted) return;
        final data = event.snapshot.value;
        if (data != null && data is Map) {
          final action = data['action']?.toString() ?? 'unknown';
          final sender = data['sender']?.toString() ?? 'Python GUI';
          final message = data['message']?.toString() ?? 'Signal received from Python GUI';
          final timestamp = DateTime.now().toIso8601String().substring(11, 19);

          debugPrint('[FIREBASE_BRIDGE_DEBUG] Incoming Python Msg: $data');

          setState(() {
            _logMessages.insert(0, {
              'sender': sender,
              'action': action,
              'message': message,
              'time': timestamp,
              'type': 'incoming',
            });
          });
        }
      },
      onError: (err) {
        debugPrint('[FIREBASE_BRIDGE_ERROR] Error listening to Python action: $err');
        setState(() => _isConnected = false);
      },
    );
  }

  Future<void> _sendAppAction(String actionKey, String label) async {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final payload = {
      'action': actionKey,
      'sender': 'Flutter App',
      'message': 'User clicked [$label] in Flutter App',
      'timestamp': ServerValue.timestamp,
    };

    debugPrint('[FIREBASE_BRIDGE_DEBUG] Outgoing App Action: $payload');

    try {
      await _testBridgeRef.child('app_action').set(payload);

      setState(() {
        _logMessages.insert(0, {
          'sender': 'Flutter App',
          'action': actionKey,
          'message': 'Sent [$label] signal to Python GUI',
          'time': timestamp,
          'type': 'outgoing',
        });
      });

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Sent: [$label] -> Firebase',
          iconAsset: 'assets/icons/1024x/correct_1024x.png',
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e) {
      debugPrint('[FIREBASE_BRIDGE_ERROR] Failed to send app action: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Firebase Error: $e',
          iconAsset: 'assets/icons/1024x/incorrect_1024x.png',
        );
      }
    }
  }

  void _clearLogs() {
    setState(() {
      _logMessages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return Scaffold(
          appBar: AppBar(
            title: Text(settingsState.isArabic ? 'اختبار جسر الفايربيس (Temp)' : 'Test Firebase Bridge (Temp)'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Clear Console',
                onPressed: _clearLogs,
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Status Banner ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: settingsState.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isConnected ? AppColors.success : AppColors.error,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          color: _isConnected ? AppColors.success : AppColors.error,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isConnected
                                    ? (settingsState.isArabic ? 'متصل بجسر الفايربيس Realtime' : 'Connected to Firebase Realtime Bridge')
                                    : 'Firebase Connection Issue',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Path: /test_bridge | Real-time Bi-directional Test',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Gameplay Action Buttons Grid (Matching Python GUI Gameplay Controls) ---
                  Text(
                    settingsState.isArabic ? 'أزرار التحكم بالمباراة والعتاد (Python Parity)' : 'Gameplay & Hardware Action Controls (Python Parity)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.3,
                    children: [
                      _buildActionButton(
                        label: settingsState.isArabic ? 'بدء مباراة' : 'Start Match',
                        icon: Icons.play_arrow_rounded,
                        color: AppColors.success,
                        onPressed: () => _sendAppAction('start_match', 'Start Match'),
                      ),
                      _buildActionButton(
                        label: settingsState.isArabic ? 'إيقاف مؤقت' : 'Pause Match',
                        icon: Icons.pause_rounded,
                        color: Colors.orange,
                        onPressed: () => _sendAppAction('pause_match', 'Pause Match'),
                      ),
                      _buildActionButton(
                        label: settingsState.isArabic ? 'إعادة ضبط' : 'Reset Match',
                        icon: Icons.refresh_rounded,
                        color: AppColors.error,
                        onPressed: () => _sendAppAction('reset_match', 'Reset Match'),
                      ),
                      _buildActionButton(
                        label: settingsState.isArabic ? 'حقن نقلة e2->e4' : 'Inject Move e2->e4',
                        icon: Icons.bolt_rounded,
                        color: AppColors.primaryGold,
                        onPressed: () => _sendAppAction('inject_move_e2e4', 'Inject Move e2->e4'),
                      ),
                      _buildActionButton(
                        label: settingsState.isArabic ? 'تبييت جهة الملك' : 'King Side Castle',
                        icon: Icons.fort_rounded,
                        color: Colors.purple,
                        onPressed: () => _sendAppAction('castle_king', 'King Side Castle'),
                      ),
                      _buildActionButton(
                        label: settingsState.isArabic ? 'تبييت جهة الوزير' : 'Queen Side Castle',
                        icon: Icons.castle_rounded,
                        color: Colors.indigo,
                        onPressed: () => _sendAppAction('castle_queen', 'Queen Side Castle'),
                      ),
                      _buildActionButton(
                        label: settingsState.isArabic ? 'محاذاة المحركات (0,0)' : 'Go Home (0,0)',
                        icon: Icons.home_rounded,
                        color: Colors.teal,
                        onPressed: () => _sendAppAction('home_motors', 'Go Home (0,0)'),
                      ),
                      _buildActionButton(
                        label: settingsState.isArabic ? 'مغناطيس الكهرومغناطيسي' : 'Toggle Magnet',
                        icon: Icons.shield_moon_rounded,
                        color: Colors.blueAccent,
                        onPressed: () => _sendAppAction('toggle_magnet', 'Toggle Magnet'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Real-time Console Log Area ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        settingsState.isArabic ? 'سجل الرسائل الحية (Live Console)' : 'Live Messaging Log Console',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '${_logMessages.length} Messages',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    height: 260,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _logMessages.isEmpty
                        ? const Center(
                            child: Text(
                              'Console ready. Click any action button above or send signals from Python GUI.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _logMessages.length,
                            separatorBuilder: (ctx, idx) => const Divider(color: Colors.white10, height: 12),
                            itemBuilder: (context, index) {
                              final msg = _logMessages[index];
                              final isIncoming = msg['type'] == 'incoming';

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '[${msg['time']}] ',
                                    style: const TextStyle(
                                      fontFamily: 'Consolas',
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Icon(
                                    isIncoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                    size: 14,
                                    color: isIncoming ? const Color(0xFF00E676) : AppColors.primaryGold,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${msg['sender']}: ${msg['action']}',
                                          style: TextStyle(
                                            fontFamily: 'Consolas',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isIncoming ? const Color(0xFF00E676) : AppColors.primaryGold,
                                          ),
                                        ),
                                        Text(
                                          msg['message'] ?? '',
                                          style: const TextStyle(
                                            fontFamily: 'Consolas',
                                            fontSize: 11,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      onPressed: onPressed,
    );
  }
}
