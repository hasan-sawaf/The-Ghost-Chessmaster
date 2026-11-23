import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ghostchessmaster/core/theme/app_colors.dart';
import 'package:ghostchessmaster/features/history/data/match_history_service.dart';
import 'package:ghostchessmaster/features/history/domain/models/match_record_model.dart';
import 'package:ghostchessmaster/features/history/presentation/pages/match_review_page.dart';
import 'package:ghostchessmaster/features/profile/data/board_connection_service.dart';
import 'package:ghostchessmaster/features/profile/presentation/pages/board_qr_scanner_page.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_state.dart';
import 'match_settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ConnectedBoardInfo? _connectedBoard;
  StreamSubscription<ConnectedBoardInfo?>? _connSub;

  @override
  void initState() {
    super.initState();
    _initBoardConnectionState();
  }

  Future<void> _initBoardConnectionState() async {
    final info = await BoardConnectionService.instance.loadConnectionState();
    if (mounted) {
      setState(() {
        _connectedBoard = info;
      });
    }

    _connSub = BoardConnectionService.instance.connectionStream.listen((info) {
      if (mounted) {
        setState(() {
          _connectedBoard = info;
        });
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final isDark = settingsState.isDarkMode;
        final isAr = settingsState.isArabic;
        final fontScale = settingsState.fontScaleFactor;
        final isConnected = _connectedBoard != null && _connectedBoard!.isConnected;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Game Hub Header Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2C1B18), const Color(0xFF1E1E24)]
                            : [AppColors.primaryAmber, AppColors.primaryGold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGold.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10 * fontScale),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.castle_rounded,
                            size: 28 * fontScale,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settingsState.translate('app_title'),
                                style: TextStyle(
                                  fontSize: 18 * fontScale,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAr
                                    ? 'العب وتحدى الذكاء الاصطناعي على رقعتك الرقمية أو الفعلية'
                                    : 'Play & challenge Stockfish AI on digital or physical board',
                                style: TextStyle(
                                  fontSize: 11 * fontScale,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Connected Physical Board Widget (Compact & Modern UI)
                  _buildBoardConnectionCard(isConnected, settingsState, isDark, isAr, fontScale),
                  const SizedBox(height: 20),

                  // Section Title: Game Modes
                  Text(
                    isAr ? 'أنماط اللعب المتاحة' : 'Game Modes',
                    style: TextStyle(
                      fontSize: 14 * fontScale,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Quick Match Mode Card
                  _buildGameModeCard(
                    title: isAr ? 'مباراة سريعة' : 'Quick Match',
                    subtitle: isAr
                        ? 'مباراة مخصصة ضد Stockfish AI (مستويات 0-20) مع التحكم بالوقت والألوان'
                        : 'Custom match vs Stockfish AI (Levels 0-20) with full time controls & side selection',
                    btnText: isAr ? 'بدء المباراة ♟️' : 'Start Match ♟️',
                    icon: Icons.play_circle_fill_rounded,
                    accentColor: AppColors.primaryGold,
                    isDark: isDark,
                    fontScale: fontScale,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MatchSettingsPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 4. Last 5 Matches Table Section
                  _buildRecentMatchesTable(settingsState, isDark, isAr, fontScale),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardConnectionCard(
    bool isConnected,
    SettingsState settingsState,
    bool isDark,
    bool isAr,
    double fontScale,
  ) {
    final boardName = _connectedBoard?.boardName ?? 'BoardOne';

    if (!isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phonelink_off_rounded,
                color: AppColors.primaryGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAr ? 'لم يتم ربط رقعة' : 'No Board Linked',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13 * fontScale,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAr ? 'امسح رمز QR للربط' : 'Scan QR code to pair',
                    style: TextStyle(
                      fontSize: 11 * fontScale,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 1,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BoardQrScannerPage()),
                );
              },
              child: Text(
                isAr ? 'ربط' : 'Connect',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11 * fontScale,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<bool>(
      stream: BoardConnectionService.instance.boardOnlineStream,
      initialData: BoardConnectionService.instance.checkBoardOnline(),
      builder: (context, onlineSnap) {
        final isOnline = onlineSnap.data ?? false;
        final statusColor = isOnline ? AppColors.success : Colors.orange;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? statusColor.withValues(alpha: 0.5)
                  : statusColor.withValues(alpha: 0.7),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline ? Icons.sensors_rounded : Icons.wifi_off_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAr ? 'مرتبطة بـ $boardName' : 'Linked: $boardName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13 * fontScale,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 7,
                          color: statusColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isAr
                              ? (isOnline ? 'أونلاين (جاهزة للعب)' : 'أوفلاين (غير متصلة بالشبكة)')
                              : (isOnline ? 'Online (Ready to play)' : 'Offline (No heartbeat)'),
                          style: TextStyle(
                            fontSize: 11 * fontScale,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2C3240) : const Color(0xFFE8ECEF),
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BoardQrScannerPage()),
                  );
                },
                child: Text(
                  isAr ? 'التفاصيل' : 'Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11 * fontScale,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameModeCard({
    required String title,
    required String subtitle,
    required String btnText,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required double fontScale,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10 * fontScale),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 24 * fontScale),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15 * fontScale,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11 * fontScale,
                        color: Colors.grey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                minimumSize: Size(0, 46 * fontScale),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              icon: Icon(Icons.play_arrow_rounded, size: 22 * fontScale),
              label: Text(
                btnText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14 * fontScale,
                ),
              ),
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentMatchesTable(
    SettingsState settingsState,
    bool isDark,
    bool isAr,
    double fontScale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isAr ? 'آخر 5 مباريات' : 'Recent 5 Matches',
              style: TextStyle(
                fontSize: 14 * fontScale,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Icon(Icons.history_rounded, color: AppColors.primaryGold, size: 18 * fontScale),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<MatchRecordModel>>(
          stream: MatchHistoryService.instance.streamAllUserMatches(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
              );
            }

            final matches = (snapshot.data ?? []).take(5).toList();

            if (matches.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history_rounded, size: 32, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    Text(
                      isAr
                          ? 'لا توجد مباريات مسجلة بعد. العب الآن لإنشاء سجل!'
                          : 'No match history recorded yet. Play a match to start!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11 * fontScale, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              isAr ? 'النمط' : 'Mode',
                              style: TextStyle(
                                fontSize: 11 * fontScale,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              isAr ? 'النتيجة' : 'Result',
                              style: TextStyle(
                                fontSize: 11 * fontScale,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              isAr ? 'التفاصيل' : 'Details',
                              style: TextStyle(
                                fontSize: 11 * fontScale,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 65 * fontScale,
                            child: Text(
                              isAr ? 'مراجعة' : 'Review',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11 * fontScale,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    // Table Rows
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: matches.length,
                      separatorBuilder: (ctx, idx) => Divider(
                        height: 1,
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      itemBuilder: (ctx, idx) {
                        final m = matches[idx];
                        final isTraining = m.matchType == 'training';
                        final modeLabel = isTraining
                            ? (isAr ? '🏝️ تدريب' : '🏝️ Training')
                            : (isAr ? '⚡ مباراة' : '⚡ Quick');
                        final modeColor = isTraining ? AppColors.primaryGold : Colors.blueAccent;

                        Color resColor = Colors.grey;
                        String resLabel = isAr ? 'تعادل' : 'Draw';
                        if (m.result == 'victory') {
                          resColor = AppColors.success;
                          resLabel = isAr ? 'فوز 🟢' : 'Win 🟢';
                        } else if (m.result == 'defeat' || m.result == 'loss') {
                          resColor = AppColors.error;
                          resLabel = isAr ? 'خسارة 🔴' : 'Loss 🔴';
                        }

                        final movesCount = m.liveMoveLog.length;
                        final dateStr = DateFormat('dd MMM').format(m.startedAt);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              // Mode Pill
                              Expanded(
                                flex: 3,
                                child: Text(
                                  modeLabel,
                                  style: TextStyle(
                                    fontSize: 11 * fontScale,
                                    fontWeight: FontWeight.bold,
                                    color: modeColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Result Pill
                              Expanded(
                                flex: 2,
                                child: Text(
                                  resLabel,
                                  style: TextStyle(
                                    fontSize: 11 * fontScale,
                                    fontWeight: FontWeight.bold,
                                    color: resColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Details (Moves & Date)
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '$movesCount m • $dateStr',
                                  style: TextStyle(
                                    fontSize: 10 * fontScale,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Review Button
                              SizedBox(
                                width: 65 * fontScale,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGold.withValues(alpha: 0.15),
                                    foregroundColor: AppColors.primaryGold,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4 * fontScale,
                                      vertical: 4 * fontScale,
                                    ),
                                    minimumSize: const Size(0, 30),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: AppColors.primaryGold.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    MatchReviewPage.open(
                                      context,
                                      match: m,
                                      settingsState: settingsState,
                                    );
                                  },
                                  child: Text(
                                    isAr ? 'مراجعة' : 'Review',
                                    style: TextStyle(
                                      fontSize: 10 * fontScale,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
