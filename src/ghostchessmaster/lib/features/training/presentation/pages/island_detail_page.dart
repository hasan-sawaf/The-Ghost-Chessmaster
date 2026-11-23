import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghostchessmaster/models/island_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/load_images.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../history/data/match_history_service.dart';
import '../../../history/data/local_match_cache_service.dart';
import '../../../history/presentation/pages/match_review_page.dart';
import '../../../profile/data/board_connection_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_event.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../data/training_campaign_service.dart';
import '../../domain/training_theme_helper.dart';
import 'training_game_page.dart';

class IslandDetailPage extends StatefulWidget {
  final int islandIndex;
  final Map<String, dynamic> islandData;
  final int completedRounds;
  final bool isUnlocked;
  final Function(int roundNum) onRoundCompleted;

  const IslandDetailPage({
    super.key,
    required this.islandIndex,
    required this.islandData,
    required this.completedRounds,
    required this.isUnlocked,
    required this.onRoundCompleted,
  });

  bool get isComplete => completedRounds >= 4;

  @override
  State<IslandDetailPage> createState() => _IslandDetailPageState();
}

class _IslandDetailPageState extends State<IslandDetailPage> {
  // Pre-match analysis mode (true = Deep Post-Match Analysis, false = Live Real-time Analysis)
  bool _isDeepAnalyzerMode = true;
  IslandProgressModel? _liveIslandProgress;

  @override
  void initState() {
    super.initState();
    _fetchLiveProgress();
  }

  Future<void> _fetchLiveProgress() async {
    final campaign = await TrainingCampaignService.instance.loadCampaignProgress();
    if (mounted) {
      setState(() {
        _liveIslandProgress = campaign[widget.islandIndex];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return StreamBuilder<Map<int, IslandProgressModel>>(
          stream: TrainingCampaignService.instance.onCampaignChanged,
          builder: (context, snapshot) {
            final campaignMap = snapshot.data;
            final currentProgress = campaignMap?[widget.islandIndex] ?? _liveIslandProgress;

            final int completedRounds = currentProgress?.completedRounds ?? widget.completedRounds;
            final bool isUnlocked = widget.islandIndex == 1 || (currentProgress?.isUnlocked ?? widget.isUnlocked);
            final bool isComplete = completedRounds >= 4;

            final String title = widget.islandData['title'] as String? ?? 'Training Island';
            final int lvl = widget.islandData['lvl'] as int? ?? 1;
            final int elo = widget.islandData['elo'] as int? ?? 800;
            final String? iconPath = widget.islandData['icon'] as String?;
            final bool hasHints = widget.islandIndex <= 10;
            final bool isAr = settingsState.isArabic;
            final isDark = settingsState.isDarkMode;

            final int nextRound = (completedRounds + 1).clamp(1, 4);

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF121218) : const Color(0xFFF6F7FA),
              appBar: AppBar(
                backgroundColor: isDark ? const Color(0xFF1E1E28) : AppColors.primaryMahogany,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  '${settingsState.translate('island_level')} ${widget.islandIndex}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                centerTitle: true,
              ),
              body: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. Profile-Style Top Island Header Card ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? AppColors.primaryGold.withValues(alpha: 0.3) : Colors.grey.shade300,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Island Image Emblem on the Left
                          Stack(
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isComplete
                                        ? AppColors.success
                                        : isUnlocked
                                            ? AppColors.primaryGold
                                            : Colors.grey.shade600,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isComplete ? AppColors.success : AppColors.primaryGold)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: iconPath != null
                                      ? Image.asset(
                                          iconPath,
                                          fit: BoxFit.cover,
                                          filterQuality: FilterQuality.high,
                                        )
                                      : Container(
                                          color: AppColors.primaryGold.withValues(alpha: 0.3),
                                          child: const Icon(
                                            Icons.landscape_rounded,
                                            size: 36,
                                            color: Colors.white70,
                                          ),
                                        ),
                                ),
                              ),
                              if (!isUnlocked)
                                ClipOval(
                                  child: Container(
                                    width: 76,
                                    height: 76,
                                    color: Colors.black.withValues(alpha: 0.65),
                                    child: const Center(
                                      child: Icon(
                                        Icons.lock_rounded,
                                        size: 30,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              if (isComplete)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // Island Title & Details on the Right
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.smart_toy_rounded, size: 14, color: AppColors.primaryGold),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Level $lvl ($elo ELO)',
                                      style: const TextStyle(
                                        color: AppColors.primaryGold,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isComplete
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : isUnlocked
                                            ? AppColors.primaryGold.withValues(alpha: 0.15)
                                            : Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isComplete
                                          ? AppColors.success
                                          : isUnlocked
                                              ? AppColors.primaryGold
                                              : Colors.grey,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    isComplete
                                        ? (isAr ? 'مكتملة 4/4' : 'Completed 4/4')
                                        : isUnlocked
                                            ? '${isAr ? 'الجولة' : 'Round'} $nextRound/4'
                                            : (isAr ? 'مغلقة' : 'Locked'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isComplete
                                          ? AppColors.success
                                          : isUnlocked
                                              ? AppColors.primaryGold
                                              : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campaign Progress Bar
                    if (isUnlocked) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isAr ? 'تقدم الجولات' : 'Rounds Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                isComplete
                                    ? 'Round 4/4 (100%)'
                                    : 'Round $nextRound/4 (${(completedRounds / 4 * 100).toInt()}%)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (completedRounds / 4).clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: isDark ? const Color(0xFF2A2A38) : Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isComplete ? AppColors.success : AppColors.primaryGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Quick Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            settingsState,
                            icon: Icons.flag_rounded,
                            label: isAr ? 'الجولات' : 'Total Rounds',
                            value: '4',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            settingsState,
                            icon: Icons.lightbulb_rounded,
                            label: isAr ? 'التلميحات' : 'Move Hints',
                            value: hasHints ? '3' : (isAr ? 'مغلقة' : 'Off'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            settingsState,
                            icon: Icons.timer_rounded,
                            label: isAr ? 'العداد' : 'Match Timer',
                            value: hasHints ? (isAr ? 'بدون' : 'None') : '10 Min',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // --- 2. Pre-Match Setup Console Card ---
                    if (isUnlocked) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primaryGold.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune_rounded, color: AppColors.primaryGold, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isAr ? 'إعدادات الجولة القادمة' : 'Next Round Setup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 1. Gameplay Mode Selector
                            Text(
                              isAr ? 'طريقة اللعب' : 'Gameplay Interface Mode',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSegmentButton(
                                    title: isAr ? 'رقمي (الشاشة)' : 'Digital (Screen)',
                                    icon: Icons.touch_app_rounded,
                                    isSelected: !settingsState.isPhysicalMode,
                                    selectedColor: AppColors.primaryGold,
                                    onTap: () {
                                      if (settingsState.isPhysicalMode) {
                                        context.read<SettingsBloc>().add(const SetGameplayModeEvent(false));
                                      }
                                    },
                                    settingsState: settingsState,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSegmentButton(
                                    title: isAr ? 'فيزيائي (كاميرا)' : 'Physical (Board)',
                                    icon: Icons.camera_alt_rounded,
                                    isSelected: settingsState.isPhysicalMode,
                                    selectedColor: AppColors.primaryGold,
                                    onTap: () {
                                      if (!settingsState.isPhysicalMode) {
                                        if (!BoardConnectionService.instance.isConnected) {
                                          BoardConnectionService.instance.showBoardRequirementDialog(context);
                                          return;
                                        }
                                        context.read<SettingsBloc>().add(const SetGameplayModeEvent(true));
                                      }
                                    },
                                    settingsState: settingsState,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 2. Engine Analysis Mode Selector
                            Text(
                              isAr ? 'وضع التحليل' : 'Engine Analysis Mode',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSegmentButton(
                                    title: isAr ? 'عميق (عمق 20)' : 'Deep (Depth 20)',
                                    icon: Icons.psychology_rounded,
                                    isSelected: _isDeepAnalyzerMode,
                                    selectedColor: AppColors.success,
                                    onTap: () {
                                      setState(() => _isDeepAnalyzerMode = true);
                                    },
                                    settingsState: settingsState,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSegmentButton(
                                    title: isAr ? 'مباشر (فوري)' : 'Live (Real-time)',
                                    icon: Icons.analytics_rounded,
                                    isSelected: !_isDeepAnalyzerMode,
                                    selectedColor: AppColors.primaryGold,
                                    onTap: () {
                                      setState(() => _isDeepAnalyzerMode = false);
                                    },
                                    settingsState: settingsState,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 3. Sound Effects Switch
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF282836) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        settingsState.isSoundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                        color: settingsState.isSoundEnabled ? AppColors.primaryGold : Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isAr ? 'المؤثرات الصوتية' : 'Sound Effects',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: settingsState.isSoundEnabled,
                                    activeThumbColor: AppColors.primaryGold,
                                    onChanged: (val) {
                                      context.read<SettingsBloc>().add(ToggleSoundEffectsEvent(val));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Locked State Card
                    if (!isUnlocked) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_rounded, color: AppColors.error, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isAr
                                    ? 'هذه الجزيرة مغلقة. أكمل 4 جولات في الجزيرة ${widget.islandIndex - 1} لفتحها.'
                                    : 'This island is locked. Complete 4 rounds on Island ${widget.islandIndex - 1} to unlock.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // --- 3. Round List Section ---
                    Text(
                      isAr ? 'جولات الجزيرة (4 جولات)' : 'Island Rounds (4 Rounds)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...List.generate(4, (rIdx) {
                      final roundNum = rIdx + 1;
                      final isRoundComplete = isUnlocked && roundNum <= completedRounds;
                      final isNextToPlay = isUnlocked && roundNum == completedRounds + 1;

                      final isWhiteRound = roundNum % 2 != 0;
                      final roundTheme = TrainingThemeHelper.getTrainingPieceTheme(widget.islandIndex, roundNum);
                      final kingCode = isWhiteRound ? 'WK' : 'BK';
                      final kingAsset = AppImageHelper.getPieceAssetPath(roundTheme, kingCode);

                      final lastGameId = currentProgress?.roundLastGameIds[roundNum];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: isNextToPlay ? () => _launchRound(roundNum) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isRoundComplete
                                    ? AppColors.success.withValues(alpha: 0.08)
                                    : isNextToPlay
                                        ? AppColors.primaryGold.withValues(alpha: 0.1)
                                        : isDark
                                            ? const Color(0xFF1E1E28)
                                            : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isRoundComplete
                                      ? AppColors.success
                                      : isNextToPlay
                                          ? AppColors.primaryGold
                                          : isDark
                                              ? Colors.white12
                                              : Colors.grey.shade300,
                                  width: isNextToPlay ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // King Piece Tile
                                  Container(
                                    width: 40,
                                    height: 40,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isWhiteRound ? Colors.amber.shade50 : Colors.grey.shade800,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isWhiteRound ? AppColors.primaryGold : Colors.grey.shade600,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Image.asset(
                                      kingAsset,
                                      fit: BoxFit.contain,
                                      errorBuilder: (ctx, err, stack) => Icon(
                                        Icons.circle,
                                        color: isWhiteRound ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Round Title & Piece Color Indicator
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          runSpacing: 2,
                                          children: [
                                            Text(
                                              '${settingsState.translate('round_label')} $roundNum / 4',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isWhiteRound
                                                    ? AppColors.primaryGold.withValues(alpha: 0.2)
                                                    : Colors.grey.withValues(alpha: 0.3),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.circle,
                                                    size: 8,
                                                    color: isWhiteRound ? Colors.white : Colors.grey.shade900,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isWhiteRound
                                                        ? (isAr ? 'الأبيض' : 'White')
                                                        : (isAr ? 'الأسود' : 'Black'),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isWhiteRound ? AppColors.primaryGold : Colors.grey.shade300,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          isRoundComplete
                                              ? (isAr ? 'مكتملة بنجاح' : 'Completed')
                                              : isNextToPlay
                                                  ? (isAr ? 'متاحة للعب الآن' : 'Ready to play')
                                                  : (isAr ? 'مغلقة' : 'Locked'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isRoundComplete
                                                ? AppColors.success
                                                : isNextToPlay
                                                    ? AppColors.primaryGold
                                                    : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // --- "Preview Last Game" Button ---
                                  if (lastGameId != null && lastGameId.isNotEmpty) ...[
                                    InkWell(
                                      onTap: () => _openLastGameReview(lastGameId, settingsState),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGold.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.primaryGold, width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.visibility_rounded, size: 14, color: AppColors.primaryGold),
                                            const SizedBox(width: 4),
                                            Text(
                                              isAr ? 'معاينة آخر مباراة' : 'Preview Last Game',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryGold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],

                                  // Status Indicator Icon
                                  Icon(
                                    isRoundComplete
                                        ? Icons.check_circle_rounded
                                        : isNextToPlay
                                            ? Icons.arrow_forward_ios_rounded
                                            : Icons.lock_outline_rounded,
                                    size: 18,
                                    color: isRoundComplete
                                        ? AppColors.success
                                        : isNextToPlay
                                            ? AppColors.primaryGold
                                            : Colors.grey.shade500,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // --- 4. Sticky Bottom Action Bar ---
              bottomNavigationBar: isUnlocked
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => _launchRound(isComplete ? 1 : nextRound),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isComplete ? AppColors.success : AppColors.primaryGold,
                              foregroundColor: Colors.black,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isComplete ? Icons.refresh_rounded : Icons.play_circle_filled_rounded,
                                  size: 22,
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isComplete
                                      ? (isAr ? 'إعادة الجزيرة (الجولة 1)' : 'Replay Island (Round 1)')
                                      : (isAr ? 'بدء الجولة $nextRound من 4' : 'Play Round $nextRound of 4'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Future<void> _openLastGameReview(String matchId, SettingsState settingsState) async {
    var match = await MatchHistoryService.instance.getMatchRecordById(matchId);
    if (match == null) {
      final cachedList = await LocalMatchCacheService.instance.getCachedMatches();
      for (final m in cachedList) {
        if (m.id == matchId) {
          match = m;
          break;
        }
      }
    }
    if (match != null && mounted) {
      MatchReviewPage.open(
        context,
        match: match,
        settingsState: settingsState,
      );
    } else if (mounted) {
      AppSnackBar.showInfo(
        context,
        settingsState.isArabic ? 'لم يتم العثور على سجل المباراة' : 'Match record not found in cache',
      );
    }
  }

  void _launchRound(int roundNum) async {
    final settingsState = context.read<SettingsBloc>().state;
    final isAr = settingsState.isArabic;
    final connService = BoardConnectionService.instance;

    if (settingsState.isPhysicalMode) {
      if (!connService.isConnected) {
        connService.showBoardRequirementDialog(context);
        return;
      }

      // Actively verify board online status before proceeding
      final isOnline = await connService.verifyAndCheckBoardOnline();
      if (!isOnline) {
        if (!mounted) return;
        final retry = await connService.showBoardOfflineDialog(context, isAr: isAr);
        if (retry && mounted) {
          // Recursive retry
          _launchRound(roundNum);
        }
        return;
      }

      // Check if CoreXY robotic mechanism is at Home (0,0)
      if (!connService.isCorexyHome) {
        if (!mounted) return;
        await connService.showCorexyNotHomeDialog(context, isAr: isAr);
        return;
      }

      if (!mounted) return;
      final positionConfirmed = await connService.showPhysicalBoardInitialPositionDialog(context, isAr: isAr);
      if (!positionConfirmed) {
        return; // User cancelled position confirmation
      }

      if (!mounted) return;
      final cameraSuccess = await connService.startCameraWithVerification(context);
      if (!cameraSuccess) {
        return; // Camera failed to turn ON -> block entry into round
      }
    }

    final title = widget.islandData['title'] as String? ?? 'Island';
    final lvl = widget.islandData['lvl'] as int? ?? 1;
    final elo = widget.islandData['elo'] as int? ?? 800;
    final isWhiteRound = roundNum % 2 != 0;
    final islandTimeSec = IslandModel.getTimeForIsland(widget.islandIndex) * 60;
    final islandIncSec = IslandModel.getIncTimeForIsland(widget.islandIndex);

    if (settingsState.isPhysicalMode) {
      await connService.updateLiveSessionState(
        isWhite: isWhiteRound,
        timer: islandTimeSec,
        incTime: islandIncSec,
        difficulty: lvl,
        playStyle: 'style_balanced',
        elo: elo,
      );
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrainingGamePage(
          islandIndex: widget.islandIndex,
          roundIndex: roundNum,
          islandTitle: title,
          stockfishLevel: lvl,
          eloRating: elo,
          isDeepAnalyzerMode: _isDeepAnalyzerMode,
        ),
      ),
    );

    if (result == true) {
      widget.onRoundCompleted(roundNum);
    }
    _fetchLiveProgress();
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
    required SettingsState settingsState,
  }) {
    final isDark = settingsState.isDarkMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.16)
              : isDark
                  ? const Color(0xFF282836)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedColor : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? selectedColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? selectedColor : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    SettingsState settingsState, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isDark = settingsState.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.primaryGold),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
