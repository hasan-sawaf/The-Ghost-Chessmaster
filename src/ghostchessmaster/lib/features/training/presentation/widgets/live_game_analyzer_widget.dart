import 'package:flutter/material.dart';
import 'package:ghostchessmaster/core/theme/app_colors.dart';
import 'package:ghostchessmaster/core/utils/load_images.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_state.dart';

class LiveGameAnalyzerWidget extends StatefulWidget {
  final List<Map<String, dynamic>> moveLog;
  final SettingsState settingsState;
  final double evalBarValue;
  final int overallAccuracy;

  const LiveGameAnalyzerWidget({
    super.key,
    required this.moveLog,
    required this.settingsState,
    required this.evalBarValue,
    required this.overallAccuracy,
  });

  @override
  State<LiveGameAnalyzerWidget> createState() => _LiveGameAnalyzerWidgetState();
}

class _LiveGameAnalyzerWidgetState extends State<LiveGameAnalyzerWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant LiveGameAnalyzerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.moveLog.length != oldWidget.moveLog.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getClassificationColor(String? classification) {
    if (classification == null || classification.isEmpty) {
      return AppColors.primaryGold;
    }
    switch (classification.toLowerCase()) {
      case 'brilliant':
        return const Color(0xFF1BACC5);
      case 'best':
        return const Color(0xFF2E7D32);
      case 'excellent':
        return const Color(0xFF66BB6A);
      case 'good':
      case 'okay':
        return const Color(0xFF42A5F5);
      case 'book':
        return const Color(0xFFA1887F);
      case 'inaccuracy':
        return const Color(0xFFFFB300);
      case 'mistake':
        return const Color(0xFFFB8C00);
      case 'blunder':
        return const Color(0xFFE53935);
      default:
        return AppColors.primaryGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.settingsState.isDarkMode;
    final isAr = widget.settingsState.isArabic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header Section ---
        Row(
          children: [
            const Icon(
              Icons.analytics_rounded,
              size: 20,
              color: AppColors.primaryGold,
            ),
            const SizedBox(width: 8),
            Text(
              isAr ? 'المحلل المباشر' : 'Live Game Analyzer',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGold.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    size: 14,
                    color: AppColors.primaryGold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.overallAccuracy > 0 ? '${widget.overallAccuracy}% ACC' : (isAr ? 'بدون تحليل' : 'N/A'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // --- Smooth Evaluation Bar ---
        Container(
          height: 22,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.5,
            ),
            color: isDark ? const Color(0xFF1E1E24) : Colors.black87,
          ),
          child: Stack(
            children: [
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                widthFactor: widget.evalBarValue.clamp(0.05, 0.95),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.horizontal(
                      left: const Radius.circular(6),
                      right: Radius.circular(widget.evalBarValue > 0.9 ? 6 : 0),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'W',
                    style: TextStyle(
                      color: widget.evalBarValue > 0.15
                          ? Colors.black87
                          : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    'B',
                    style: TextStyle(
                      color: widget.evalBarValue < 0.85
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- Live Move Log Feed ---
        Container(
          constraints: const BoxConstraints(minHeight: 140),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.moveLog.isEmpty
              ? Container(
                  height: 140,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_esports_rounded,
                        size: 32,
                        color: Colors.grey.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.settingsState.translate('waiting_match_start'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  itemCount: widget.moveLog.length,
                  itemBuilder: (context, idx) {
                    final item = widget.moveLog[idx];
                    final playerStr = item['player']?.toString();
                    final isWhite = playerStr == 'White' || (item['isWhite'] == true) || (idx % 2 == 0);

                    final bool hasRealClassification = item.containsKey('classification') &&
                        item['classification'] != null &&
                        item['classification'].toString().isNotEmpty &&
                        (item['isAnalyzing'] != true);

                    final classification = hasRealClassification
                        ? item['classification'].toString()
                        : (isAr ? 'غير محللة' : 'Not Analyzed');
                    final tagColor = hasRealClassification ? _getClassificationColor(classification) : Colors.grey;
                    final rawIconKey = hasRealClassification
                        ? (item['icon']?.toString() ?? item['classification']?.toString())
                        : 'book';
                    final iconPath = AppImageHelper.getClassificationIconPath(rawIconKey);
                    final moveNum = item['num'] ?? (idx ~/ 2 + 1);
                    final moveSan = item['move']?.toString() ?? item['san']?.toString() ?? '';
                    final accuracyVal = hasRealClassification ? (item['accuracy'] ?? 100) : null;
                    final commentaryText = item['commentary']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.4)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Piece / Classification Icon Badge
                          Container(
                            width: 32,
                            height: 32,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isWhite ? Colors.white : Colors.black87,
                              shape: BoxShape.circle,
                              border: Border.all(color: tagColor, width: 1.5),
                            ),
                            child: iconPath != null
                                ? Image.asset(
                                    iconPath,
                                    fit: BoxFit.contain,
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 12),

                          // Move Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '#$moveNum. ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      moveSan,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                if (commentaryText.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    commentaryText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Classification Tag & Accuracy
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: tagColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: tagColor.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  classification,
                                  style: TextStyle(
                                    color: tagColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                accuracyVal != null ? '$accuracyVal% ACC' : '-',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: tagColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
