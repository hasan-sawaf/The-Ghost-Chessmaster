import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ghostchessmaster/core/theme/app_colors.dart';
import 'package:ghostchessmaster/core/widgets/app_snack_bar.dart';
import 'package:ghostchessmaster/features/profile/data/board_connection_service.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_state.dart';

class BoardQrScannerPage extends StatefulWidget {
  const BoardQrScannerPage({super.key});

  @override
  State<BoardQrScannerPage> createState() => _BoardQrScannerPageState();
}

class _BoardQrScannerPageState extends State<BoardQrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  ConnectedBoardInfo? _currentConnection;
  bool _isLoading = false;
  StreamSubscription<ConnectedBoardInfo?>? _connectionSub;

  @override
  void initState() {
    super.initState();
    // Instantly use memory state (0ms startup latency)
    _currentConnection = BoardConnectionService.instance.currentInfo;
    _connectionSub = BoardConnectionService.instance.connectionStream.listen((info) {
      if (mounted) {
        setState(() {
          _currentConnection = info;
          _isLoading = false;
        });
      }
    });

    if (_currentConnection == null) {
      _loadConnectionState();
    }
  }

  Future<void> _loadConnectionState() async {
    final info = await BoardConnectionService.instance.loadConnectionState();
    if (mounted) {
      setState(() {
        _currentConnection = info;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_isProcessing || _currentConnection != null) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _processQrPayload(rawValue);
        break;
      }
    }
  }

  void _processQrPayload(String rawPayload) {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final Map<String, dynamic> data = jsonDecode(rawPayload);
      final String boardId = data['board_id']?.toString() ?? '';
      final String boardName = data['board_name']?.toString() ?? 'BoardOne';
      final String rtdbUrl = data['rtdb_url']?.toString() ??
          'https://YOUR_FIREBASE_PROJECT_ID-default-rtdb.firebaseio.com/$boardId';

      if (boardId.isEmpty) {
        _showInvalidQrError('Invalid Board QR: Missing board_id');
        return;
      }

      _showConnectionConfirmDialog(
        boardId: boardId,
        boardName: boardName,
        rtdbUrl: rtdbUrl,
      );
    } catch (e) {
      // Fallback for simple payload QR codes
      if (rawPayload.startsWith('BOARD_') || rawPayload.contains('Board')) {
        final boardId = rawPayload.trim();
        _showConnectionConfirmDialog(
          boardId: boardId,
          boardName: 'BoardOne',
          rtdbUrl: 'https://YOUR_FIREBASE_PROJECT_ID-default-rtdb.firebaseio.com/$boardId',
        );
      } else {
        _showInvalidQrError('Invalid QR code format. Please scan a valid Chess Board QR.');
      }
    }
  }

  void _showInvalidQrError(String message) {
    AppSnackBar.showError(
      context,
      message,
      iconAsset: 'assets/icons/1024x/incorrect_1024x.png',
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  void _showConnectionConfirmDialog({
    required String boardId,
    required String boardName,
    required String rtdbUrl,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail = currentUser?.email ?? 'Your Account';
    final settingsState = context.read<SettingsBloc>().state;
    final isAr = settingsState.isArabic;
    final fontScale = settingsState.fontScaleFactor;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.sensors_rounded, color: AppColors.primaryGold, size: 24 * fontScale),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr ? 'الاتصال برقعة الشطرنج؟' : 'Connect to Chess Board?',
                  style: TextStyle(fontSize: 16 * fontScale, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr
                    ? 'هل أنت تأكد من رغبتك في الربط مع "$boardName"؟'
                    : 'Are you sure you want to connect your account with "$boardName"?',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13 * fontScale),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.label_rounded, size: 18 * fontScale, color: AppColors.primaryGold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${isAr ? "اسم الرقعة" : "Board Name"}: $boardName',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13 * fontScale,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${isAr ? "المستخدم" : "User"}: $userEmail',
                      style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                setState(() {
                  _isProcessing = false;
                });
              },
              child: Text(isAr ? 'إلغاء' : 'Cancel', style: TextStyle(color: Colors.grey, fontSize: 13 * fontScale)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final success = await BoardConnectionService.instance.connectToBoard(
                  boardId: boardId,
                  boardName: boardName,
                  rtdbUrl: rtdbUrl,
                );

                if (mounted) {
                  if (success) {
                    setState(() {
                      _currentConnection = BoardConnectionService.instance.currentInfo;
                      _isProcessing = false;
                    });
                    AppSnackBar.showSuccess(
                      context,
                      isAr ? 'تم الاتصال بالرقعة بنجاح!' : 'Connected to board successfully!',
                      iconAsset: 'assets/icons/1024x/correct_1024x.png',
                    );
                    Future.delayed(const Duration(milliseconds: 600), () {
                      if (mounted && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    });
                  } else {
                    setState(() {
                      _isProcessing = false;
                    });
                    AppSnackBar.showError(
                      context,
                      isAr ? 'تعذر الاتصال بالرقعة. تحقق من شبكة الإنترنت.' : 'Failed to connect to board. Check internet connection.',
                      iconAsset: 'assets/icons/1024x/incorrect_1024x.png',
                    );
                  }
                }
              },
              child: Text(isAr ? 'نعم، اتصل' : 'Yes, Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * fontScale)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final isDark = settingsState.isDarkMode;
        final isAr = settingsState.isArabic;
        final fontScale = settingsState.fontScaleFactor;
        final user = FirebaseAuth.instance.currentUser;
        final userEmail = user?.email ?? 'User';

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(
                isAr ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 20 * fontScale,
              ),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: Text(
              isAr ? 'الاتصال بالرقعة' : 'Connect with Board',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18 * fontScale,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
              : _currentConnection != null && _currentConnection!.isConnected
                  ? _buildConnectedView(userEmail, settingsState, isDark, isAr, fontScale)
                  : _buildScannerView(settingsState, isDark, isAr, fontScale),
        );
      },
    );
  }

  Widget _buildConnectedView(
    String userEmail,
    SettingsState settingsState,
    bool isDark,
    bool isAr,
    double fontScale,
  ) {
    final board = _currentConnection!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(14 * fontScale),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 48 * fontScale,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isAr ? 'تم الاتصال بـ ${board.boardName}!' : 'Connected to ${board.boardName}!',
                  style: TextStyle(
                    fontSize: 18 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isAr
                      ? 'تطبيقك مرتبط برقعة الشطرنج الفعلية في الوقت الفعلي.'
                      : 'Your app is linked with physical chess board in real-time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12 * fontScale,
                  ),
                ),
                const SizedBox(height: 20),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                const SizedBox(height: 14),

                // Details List (Board ID hidden completely)
                _buildDetailRow(
                  Icons.label_rounded,
                  isAr ? 'اسم الرقعة' : 'Board Name',
                  board.boardName,
                  isDark,
                  fontScale,
                  isGold: true,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.person_rounded,
                  isAr ? 'المستخدم المتصل' : 'Connected User',
                  userEmail,
                  isDark,
                  fontScale,
                  isBlue: true,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.cloud_done_rounded,
                  isAr ? 'حالة الاتصال' : 'Connection Status',
                  isAr ? 'نشط ●' : 'Active ●',
                  isDark,
                  fontScale,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Disconnect Button
          InkWell(
            onTap: () async {
              setState(() {
                _isLoading = true;
              });
              await BoardConnectionService.instance.disconnectFromBoard();
              if (mounted) {
                setState(() {
                  _currentConnection = null;
                  _isLoading = false;
                });
                AppSnackBar.showWarning(
                  context,
                  isAr ? 'تم قطع الاتصال بالرقعة.' : 'Disconnected from board.',
                  iconAsset: 'assets/icons/1024x/inaccuracy_1024x.png',
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14 * fontScale),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off_rounded, color: AppColors.error, size: 20 * fontScale),
                  const SizedBox(width: 8),
                  Text(
                    isAr ? 'قطع الاتصال بالرقعة' : 'Disconnect from Board',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 14 * fontScale,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
    double fontScale, {
    bool isGold = false,
    bool isBlue = false,
  }) {
    Color valColor = isDark ? Colors.white70 : Colors.black87;
    if (isGold) valColor = AppColors.primaryGold;
    if (isBlue) valColor = Colors.blueAccent;

    return Row(
      children: [
        Icon(icon, size: 18 * fontScale, color: valColor),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12 * fontScale,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13 * fontScale,
              fontWeight: FontWeight.bold,
              color: valColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScannerView(
    SettingsState settingsState,
    bool isDark,
    bool isAr,
    double fontScale,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primaryGold, size: 20 * fontScale),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr
                      ? 'قم بتوجيه الكاميرا نحو رمز QR الظاهر في واجهة Python للرقعة.'
                      : 'Point your camera at the QR code displayed on the Board Python GUI.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 12 * fontScale,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onQrDetected,
              ),
              // Scanning Overlay Frame
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primaryGold, width: 3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
