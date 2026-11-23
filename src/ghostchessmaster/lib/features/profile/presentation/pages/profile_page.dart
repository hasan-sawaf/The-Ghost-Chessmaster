import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../history/data/match_history_service.dart';
import '../../../history/domain/models/match_record_model.dart';
import '../../../training/data/training_campaign_service.dart';
import '../../data/board_connection_service.dart';
import 'board_qr_scanner_page.dart';
import 'my_account_page.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_event.dart';
import '../../../settings/presentation/bloc/settings_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final userEmail = authState is AuthenticatedState
                ? authState.user.email
                : 'Master Player';

            final isDark = settingsState.isDarkMode;
            final isAr = settingsState.isArabic;

            return Scaffold(
              body: SafeArea(
                child: StreamBuilder<List<MatchRecordModel>>(
                  stream: MatchHistoryService.instance.streamAllUserMatches(),
                  builder: (context, snapshot) {
                    final matches = snapshot.data ?? [];

                    // Only count completed games for win/loss/draw stats
                    final completedMatches = matches.where((m) => m.status == 'completed').toList();
                    final totalCompleted = completedMatches.length;
                    final wins = completedMatches.where((m) => m.result == 'victory').length;
                    final losses = completedMatches.where((m) => m.result == 'defeat').length;
                    final draws = completedMatches.where((m) => m.result == 'draw').length;

                    final winRateVal = totalCompleted > 0 ? (wins / totalCompleted * 100) : 0.0;
                    final winRateStr = '${winRateVal.toStringAsFixed(1)}%';

                    // Calculate average move accuracy ONLY for games with REAL analysis
                    final analyzedMatches = completedMatches.where((m) => m.hasRealAnalysis).toList();
                    final int avgAccuracy;
                    if (analyzedMatches.isNotEmpty) {
                      final totalAcc = analyzedMatches.fold<int>(0, (sum, m) {
                        final acc = m.deepAccuracy ?? (m.liveAccuracy > 0 ? m.liveAccuracy : m.accuracy);
                        return sum + acc;
                      });
                      avgAccuracy = (totalAcc / analyzedMatches.length).round();
                    } else {
                      avgAccuracy = 0;
                    }

                    // ELO Calculation (Glicko-simplified)
                    double playerElo = 800.0;
                    for (final m in completedMatches) {
                      final opponentElo = m.stockfishLevel * 100.0 + 400.0;
                      final expected = 1.0 / (1.0 + _pow10((opponentElo - playerElo) / 400.0));
                      double actualScore;
                      if (m.result == 'victory') {
                        actualScore = 1.0;
                      } else if (m.result == 'draw') {
                        actualScore = 0.5;
                      } else {
                        actualScore = 0.0;
                      }
                      final kFactor = totalCompleted < 10 ? 40.0 : (totalCompleted < 30 ? 32.0 : 24.0);
                      playerElo += kFactor * (actualScore - expected);
                    }
                    final displayElo = playerElo.round().clamp(100, 3500);

                    final trainingMatches = completedMatches.where((m) => m.matchType == 'training').toList();
                    final quickMatches = completedMatches.where((m) => m.matchType == 'quick_match').toList();
                    final quickWins = quickMatches.where((m) => m.result == 'victory').length;

                    return FutureBuilder<Map<int, IslandProgressModel>>(
                      future: TrainingCampaignService.instance.loadCampaignProgress(),
                      builder: (context, campaignSnap) {
                        final campaignMap = campaignSnap.data ?? {};
                        int highestIsland = 1;
                        campaignMap.forEach((idx, progress) {
                          if (progress.isUnlocked && idx > highestIsland) {
                            highestIsland = idx;
                          }
                        });
                        for (final m in trainingMatches) {
                          if (m.stockfishLevel > 0 && m.stockfishLevel > highestIsland) {
                            highestIsland = m.stockfishLevel;
                          }
                        }

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Sleek Compact User Profile Header Bar
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primaryGold.withValues(alpha: 0.2),
                                        border: Border.all(color: AppColors.primaryGold, width: 2),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Image.asset(
                                          'assets/Pieces/Standered/white_pieces/WK.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (ctx, err, stack) => const Icon(
                                            Icons.person_rounded,
                                            size: 24,
                                            color: AppColors.primaryGold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userEmail.split('@').first,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            userEmail,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primaryGold,
                                      ),
                                      icon: const Icon(Icons.manage_accounts_rounded, size: 20),
                                      label: Text(
                                        isAr ? 'حسابي' : 'My Account',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const MyAccountPage()),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 2. REAL PLAYER STATUS CARDS (2x2 GRID)
                              Text(
                                isAr ? 'إحصائيات وحالة اللاعب' : 'Player Career Status',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatusCard(
                                      isDark: isDark,
                                      title: isAr ? 'مستوى التدريب' : 'Training Level',
                                      value: isAr ? 'جزيرة $highestIsland' : 'Island $highestIsland',
                                      subtitle: isAr ? 'الجزيرة الحالية' : 'Active Campaign',
                                      icon: Icons.map_rounded,
                                      iconColor: AppColors.primaryGold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildStatusCard(
                                      isDark: isDark,
                                      title: isAr ? 'المباريات السريعة' : 'Quick Matches',
                                      value: '${quickMatches.length}',
                                      subtitle: isAr ? '$quickWins انتصارات' : '$quickWins Wins',
                                      icon: Icons.bolt_rounded,
                                      iconColor: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatusCard(
                                      isDark: isDark,
                                      title: isAr ? 'إجمالي الانتصارات' : 'Total Victories',
                                      value: '$wins',
                                      subtitle: isAr ? 'من أصل $totalCompleted مباراة' : 'Out of $totalCompleted matches',
                                      icon: Icons.emoji_events_rounded,
                                      iconColor: const Color(0xFF81B64C),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildStatusCard(
                                      isDark: isDark,
                                      title: isAr ? 'متوسط الدقة' : 'Avg Accuracy',
                                      value: analyzedMatches.isNotEmpty ? '$avgAccuracy%' : 'N/A',
                                      subtitle: analyzedMatches.isNotEmpty
                                          ? (isAr ? 'تحليل Stockfish' : 'Stockfish Depth-20')
                                          : (isAr ? 'لم يتم التحليل بعد' : 'No analyzed games'),
                                      icon: Icons.psychology_rounded,
                                      iconColor: Colors.purpleAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // 3. QUICK STATS SUMMARY STRIP (Matches, Wins, Losses, Draws, Win Rate, ELO)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatColumn('$totalCompleted', isAr ? 'المباريات' : 'Matches', Colors.blue),
                                    _buildStatDivider(isDark),
                                    _buildStatColumn('$wins', isAr ? 'انتصارات' : 'Wins', AppColors.success),
                                    _buildStatDivider(isDark),
                                    _buildStatColumn('$losses', isAr ? 'هزائم' : 'Losses', AppColors.error),
                                    _buildStatDivider(isDark),
                                    _buildStatColumn('$draws', isAr ? 'تعادل' : 'Draws', Colors.amber),
                                    _buildStatDivider(isDark),
                                    _buildStatColumn(winRateStr, isAr ? 'نسبة الفوز' : 'Win Rate', Colors.tealAccent),
                                    _buildStatDivider(isDark),
                                    _buildStatColumn('$displayElo', isAr ? 'تقييم ELO' : 'ELO', AppColors.primaryGold),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // 4. SETTINGS & PREFERENCES GROUPED SECTIONS
                              Text(
                                settingsState.translate('account_settings'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),

                              // Group 1: Appearance & Display
                              _buildSettingsGroup(
                                isDark: isDark,
                                children: [
                                  SwitchListTile(
                                    secondary: _buildIconBadge(
                                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                      isDark ? Colors.purpleAccent : AppColors.primaryMahogany,
                                    ),
                                    title: Text(settingsState.translate('dark_mode')),
                                    subtitle: Text(
                                      isDark
                                          ? (isAr ? 'الوضع الليلي مفعّل' : 'Dark theme active')
                                          : (isAr ? 'الوضع النهاري مفعّل' : 'Light theme active'),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    value: settingsState.isDarkMode,
                                    onChanged: (val) {
                                      context.read<SettingsBloc>().add(ToggleThemeEvent());
                                    },
                                  ),
                                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  ListTile(
                                    leading: _buildIconBadge(Icons.language_rounded, Colors.blueAccent),
                                    title: Text(settingsState.translate('language')),
                                    subtitle: Text(
                                      isAr ? 'العربية' : 'English',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isAr ? 'تغيير' : 'Change',
                                        style: const TextStyle(
                                          color: AppColors.primaryGold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      context.read<SettingsBloc>().add(ToggleLanguageEvent());
                                    },
                                  ),
                                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildIconBadge(Icons.format_size_rounded, Colors.orangeAccent),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    settingsState.translate('font_size'),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    isAr
                                                        ? (settingsState.fontSizeChoice == 'small'
                                                            ? 'صغير (85%)'
                                                            : (settingsState.fontSizeChoice == 'big' ? 'كبير (115%)' : 'متوسط (100%)'))
                                                        : (settingsState.fontSizeChoice == 'small'
                                                            ? 'Small (85%)'
                                                            : (settingsState.fontSizeChoice == 'big' ? 'Big (115%)' : 'Normal (100%)')),
                                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: SegmentedButton<String>(
                                            segments: [
                                              ButtonSegment<String>(
                                                value: 'small',
                                                label: Text(
                                                  isAr ? 'صغير' : 'Small',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              ButtonSegment<String>(
                                                value: 'normal',
                                                label: Text(
                                                  isAr ? 'وسط' : 'Med',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              ButtonSegment<String>(
                                                value: 'big',
                                                label: Text(
                                                  isAr ? 'كبير' : 'Big',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                            selected: {settingsState.fontSizeChoice},
                                            onSelectionChanged: (newSelection) {
                                              if (newSelection.isNotEmpty) {
                                                context.read<SettingsBloc>().add(SetFontSizeChoiceEvent(newSelection.first));
                                              }
                                            },
                                            style: ButtonStyle(
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              visualDensity: VisualDensity.compact,
                                              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                                if (states.contains(WidgetState.selected)) {
                                                  return AppColors.primaryGold;
                                                }
                                                return Colors.transparent;
                                              }),
                                              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                                if (states.contains(WidgetState.selected)) {
                                                  return Colors.black;
                                                }
                                                return isDark ? Colors.white70 : Colors.black87;
                                              }),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Group 2: Physical Chess Board Integration
                              _buildSettingsGroup(
                                isDark: isDark,
                                children: [
                                  StreamBuilder<ConnectedBoardInfo?>(
                                    stream: BoardConnectionService.instance.connectionStream,
                                    initialData: BoardConnectionService.instance.currentInfo,
                                    builder: (context, connSnap) {
                                      final isConn = connSnap.data != null && connSnap.data!.isConnected;
                                      final boardName = connSnap.data?.boardName ?? 'BoardOne';
                                      return ListTile(
                                        leading: _buildIconBadge(
                                          isConn ? Icons.sensors_rounded : Icons.qr_code_scanner_rounded,
                                          isConn ? Colors.green : AppColors.primaryGold,
                                        ),
                                        title: Text(
                                          isConn ? boardName : settingsState.translate('connect_board_btn'),
                                          style: TextStyle(
                                            fontWeight: isConn ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        subtitle: isConn
                                            ? StreamBuilder<bool>(
                                                stream: BoardConnectionService.instance.boardOnlineStream,
                                                initialData: BoardConnectionService.instance.checkBoardOnline(),
                                                builder: (context, onlineSnap) {
                                                  final isOnline = onlineSnap.data ?? false;
                                                  return Text(
                                                    isAr
                                                        ? (isOnline ? 'متصل ● أونلاين' : 'متصل ● غير متصل بالشبكة')
                                                        : (isOnline ? 'Connected ● Online' : 'Connected ● Offline'),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isOnline ? Colors.green : Colors.orange,
                                                    ),
                                                  );
                                                },
                                              )
                                            : Text(
                                                isAr ? 'مسح رمز QR للربط برقعة الشطرنج' : 'Scan QR code to pair hardware board',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                              ),
                                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(builder: (_) => const BoardQrScannerPage()),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  static double _pow10(double x) => math.pow(10.0, x).toDouble();

  Widget _buildIconBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildSettingsGroup({required bool isDark, required List<Widget> children}) {
    return Material(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildStatusCard({
    required bool isDark,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String val, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      height: 24,
      width: 1,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }
}
