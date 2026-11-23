import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghostchessmaster/core/services/global_analysis_service.dart';
import 'package:ghostchessmaster/core/theme/app_colors.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_state.dart';

/// Next-Gen iPhone 16 Pro Max Style Dynamic Island Widget for Deep Game Analysis.
class DynamicIslandWidget extends StatefulWidget {
  const DynamicIslandWidget({super.key});

  @override
  State<DynamicIslandWidget> createState() => _DynamicIslandWidgetState();
}

class _DynamicIslandWidgetState extends State<DynamicIslandWidget>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.fastOutSlowIn,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    GlobalAnalysisService.instance.addListener(_onAnalysisServiceChanged);
  }

  @override
  void dispose() {
    GlobalAnalysisService.instance.removeListener(_onAnalysisServiceChanged);
    _expandController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onAnalysisServiceChanged() {
    final service = GlobalAnalysisService.instance;
    if (service.isAnalyzing || service.showCompletionBanner) {
      if (!_expandController.isCompleted) {
        _expandController.forward();
      }
    } else {
      if (_expandController.isCompleted) {
        _expandController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return ListenableBuilder(
          listenable: GlobalAnalysisService.instance,
          builder: (context, _) {
            final service = GlobalAnalysisService.instance;

            if (!service.isAnalyzing && !service.showCompletionBanner) {
              return const SizedBox.shrink();
            }

            final isAr = settingsState.isArabic;
            final isDark = settingsState.isDarkMode;
            final pctVal = (service.progress * 100).clamp(0, 100).toInt();

            // -------------------------------------------------------------
            // 1. COMPLETION BANNER STATE (Glowing Success Island)
            // -------------------------------------------------------------
            if (service.showCompletionBanner) {
              return Positioned(
                top: MediaQuery.of(context).padding.top + 6,
                left: 14,
                right: 14,
                child: ScaleTransition(
                  scale: _expandAnimation,
                  child: Material(
                    elevation: 16,
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        service.openCompletedMatch(context, settingsState);
                      },
                      borderRadius: BorderRadius.circular(26),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1117),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: AppColors.primaryGold,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGold.withValues(alpha: 0.45),
                              blurRadius: 18,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ScaleTransition(
                              scale: _pulseScale,
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryGold.withValues(alpha: 0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.psychology_rounded,
                                  color: Colors.black,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isAr
                                        ? 'اكتمل التحليل العميق بنجاح! 🧠'
                                        : 'Deep Game Analysis Completed! 🧠',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: AppColors.primaryGold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAr
                                        ? 'انقر لعرض تقرير دقة النقلات وتقييم المحرك'
                                        : 'Tap to review full accuracy report & moves',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => service.dismissCompletionBanner(),
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(6.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            // -------------------------------------------------------------
            // 2. MINIMIZED PILL STATE (Authentic iPhone Dynamic Island)
            // -------------------------------------------------------------
            if (service.isMinimized) {
              return Positioned(
                top: MediaQuery.of(context).padding.top + 6,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ScaleTransition(
                    scale: _expandAnimation,
                    child: Material(
                      elevation: 12,
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => service.expandIsland(),
                        borderRadius: BorderRadius.circular(30),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090A0E),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: AppColors.primaryGold.withValues(alpha: 0.8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGold.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ScaleTransition(
                                scale: _pulseScale,
                                child: const Text(
                                  '🧠',
                                  style: TextStyle(fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isAr
                                    ? 'التحليل العميق: ${service.currentMove}/${service.totalMoves}'
                                    : 'Analyzing: ${service.currentMove}/${service.totalMoves}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$pctVal%',
                                  style: const TextStyle(
                                    color: AppColors.primaryGold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  value: service.progress.clamp(0.0, 1.0),
                                  strokeWidth: 2.2,
                                  color: AppColors.primaryGold,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            // -------------------------------------------------------------
            // 3. EXPANDED ISLAND CARD VIEW (Entirely clickable to minimize)
            // -------------------------------------------------------------
            return Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              left: 14,
              right: 14,
              child: ScaleTransition(
                scale: _expandAnimation,
                child: Material(
                  elevation: 20,
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => service.minimizeToBackground(),
                    borderRadius: BorderRadius.circular(26),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F1117) : Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: AppColors.primaryGold,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              ScaleTransition(
                                scale: _pulseScale,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGold.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.psychology_rounded,
                                    color: AppColors.primaryGold,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isAr
                                          ? 'محلل الشطرنج العميق (Depth 20) 🧠'
                                          : 'Stockfish Deep Analyzer 🧠',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (service.activeMatchRecord != null)
                                      Text(
                                        service.activeMatchRecord!.opponentName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: service.progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.withValues(alpha: 0.18),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primaryGold,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  isAr
                                      ? 'جاري تحليل النقلة ${service.currentMove} من ${service.totalMoves}'
                                      : 'Analyzing Move ${service.currentMove} of ${service.totalMoves}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$pctVal%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
