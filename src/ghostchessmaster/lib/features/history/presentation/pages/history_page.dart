import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../data/match_history_service.dart';
import '../../domain/models/match_record_model.dart';
import 'match_review_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(settingsState.translate('match_history')),
              bottom: TabBar(
                indicatorColor: AppColors.primaryGold,
                labelColor: AppColors.primaryGold,
                unselectedLabelColor:
                    settingsState.isDarkMode ? Colors.grey : Colors.black54,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.flash_on_outlined),
                    text: settingsState.translate('quick_history_tab'),
                  ),
                  Tab(
                    icon: const Icon(Icons.map_outlined),
                    text: settingsState.translate('training_history_tab'),
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // --- Tab 1: Quick Match History ---
                _buildHistoryTabContent(
                  context: context,
                  settingsState: settingsState,
                  matchType: 'quick_match',
                ),

                // --- Tab 2: Training Campaign History ---
                _buildHistoryTabContent(
                  context: context,
                  settingsState: settingsState,
                  matchType: 'training',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTabContent({
    required BuildContext context,
    required SettingsState settingsState,
    required String matchType,
  }) {
    return StreamBuilder<List<MatchRecordModel>>(
      stream: MatchHistoryService.instance.streamUserMatches(matchType: matchType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGold),
          );
        }

        final matches = snapshot.data ?? [];

        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  matchType == 'training' ? Icons.map_rounded : Icons.flash_on_rounded,
                  size: 56,
                  color: Colors.grey.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  settingsState.isArabic
                      ? 'لا توجد مباريات مسجلة بعد'
                      : 'No played matches recorded yet',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  settingsState.isArabic
                      ? 'العب مباراة وسجل تحليلاتك لتظهر هنا تلقائياً'
                      : 'Play a match and your move analytics will appear here automatically.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final totalGames = matches.length;
        final winCount = matches.where((m) => m.result == 'victory').length;
        final winRate = totalGames > 0 ? ((winCount / totalGames) * 100).round() : 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Category Stats Summary Card ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: settingsState.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: settingsState.isDarkMode
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      settingsState.translate('total_matches'),
                      '$totalGames',
                      matchType == 'training' ? Icons.map : Icons.sports_esports_outlined,
                    ),
                    Container(height: 36, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
                    _buildStatItem(
                      settingsState.translate('win_rate'),
                      '$winRate%',
                      Icons.emoji_events_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- Match List ---
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matches.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final match = matches[index];
                  return _buildMatchCard(
                    context: context,
                    match: match,
                    settingsState: settingsState,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryGold, size: 24),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMatchCard({
    required BuildContext context,
    required MatchRecordModel match,
    required SettingsState settingsState,
  }) {
    final isVictory = match.result == 'victory';
    final isDraw = match.result == 'draw';
    final isOngoing = match.result == 'ongoing';
    final isResigned = match.resultReason == 'surrendered';

    // Determine result color
    final Color resultColor;
    if (isVictory) {
      resultColor = AppColors.success;
    } else if (isDraw) {
      resultColor = AppColors.warning;
    } else if (isOngoing) {
      resultColor = Colors.blueGrey;
    } else {
      resultColor = AppColors.error;
    }

    // Determine result label with proper translations
    final String resultLabel;
    if (isResigned) {
      resultLabel = settingsState.isArabic ? 'استسلام' : 'RESIGNED';
    } else if (isVictory) {
      resultLabel = settingsState.isArabic ? 'فوز' : 'VICTORY';
    } else if (match.result == 'defeat') {
      resultLabel = settingsState.isArabic ? 'هزيمة' : 'DEFEAT';
    } else if (isDraw) {
      resultLabel = settingsState.isArabic ? 'تعادل' : 'DRAW';
    } else if (isOngoing) {
      resultLabel = settingsState.isArabic ? 'جارية' : 'IN PROGRESS';
    } else {
      resultLabel = match.result.toUpperCase();
    }

    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(match.startedAt);

    final int resolvedAccuracy = match.isDeepAnalyzed
        ? (match.deepAccuracy ?? (match.accuracy > 0 ? match.accuracy : match.liveAccuracy))
        : (match.liveAccuracy > 0 ? match.liveAccuracy : (match.accuracy > 0 ? match.accuracy : (match.deepAccuracy ?? 0)));

    final bool hasRealAnalysis = match.isDeepAnalyzed || resolvedAccuracy > 0 || match.hasRealAnalysis;

    // Build subtitle with correct accuracy info
    final String subtitleText;
    if (match.isDeepAnalyzed && (match.deepAccuracy != null || resolvedAccuracy > 0)) {
      subtitleText = '$dateStr • ${match.moveCount} ${settingsState.isArabic ? "نقلات" : "moves"} • ${settingsState.isArabic ? "الدقة" : "Accuracy"} $resolvedAccuracy%';
    } else if (resolvedAccuracy > 0) {
      subtitleText = '$dateStr • ${match.moveCount} ${settingsState.isArabic ? "نقلات" : "moves"} • ${settingsState.isArabic ? "دقة اللعب المباشر" : "Live Acc"} $resolvedAccuracy%';
    } else if (!hasRealAnalysis) {
      subtitleText = '$dateStr • ${match.moveCount} ${settingsState.isArabic ? "نقلات" : "moves"} • ${settingsState.isArabic ? "لم يتم التحليل العميق" : "Not Deep Analyzed"}';
    } else {
      subtitleText = '$dateStr • ${match.moveCount} ${settingsState.isArabic ? "نقلات" : "moves"}';
    }

    return Card(
      elevation: 0,
      color: settingsState.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: settingsState.isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: resultColor.withValues(alpha: 0.15),
          child: Icon(
            isVictory
                ? Icons.emoji_events
                : (isDraw
                    ? Icons.handshake
                    : (isOngoing
                        ? Icons.play_circle_outline
                        : (isResigned ? Icons.flag_rounded : Icons.close))),
            color: resultColor,
          ),
        ),
        title: Text(
          match.opponentName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          subtitleText,
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: resultColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: resultColor),
          ),
          child: Text(
            resultLabel,
            style: TextStyle(
              color: resultColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        onTap: () {
          MatchReviewPage.open(
            context,
            match: match,
            settingsState: settingsState,
          );
        },
      ),
    );
  }
}
