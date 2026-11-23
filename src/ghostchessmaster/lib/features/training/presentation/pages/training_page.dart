import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../data/training_campaign_service.dart';
import 'island_detail_page.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  Map<int, IslandProgressModel> _campaignData = {};

  final List<Map<String, dynamic>> _islandData = [
    {'title': 'Beginner Shore', 'lvl': 0, 'elo': 800, 'icon': 'assets/icons/islands/island_1.jpg'},
    {'title': 'Novice Coast', 'lvl': 1, 'elo': 900, 'icon': 'assets/icons/islands/island_2.jpg'},
    {'title': 'Amateur Haven', 'lvl': 2, 'elo': 1000, 'icon': 'assets/icons/islands/island_3.jpg'},
    {'title': 'Casual Atoll', 'lvl': 3, 'elo': 1100, 'icon': 'assets/icons/islands/island_4.jpg'},
    {'title': 'Club Archipelago', 'lvl': 4, 'elo': 1200, 'icon': 'assets/icons/islands/island_5.jpg'},
    {'title': 'Vanguard Reef', 'lvl': 5, 'elo': 1300, 'icon': 'assets/icons/islands/island_6.jpg'},
    {'title': 'Class B Peninsula', 'lvl': 6, 'elo': 1400, 'icon': 'assets/icons/islands/island_7.jpg'},
    {'title': 'Class A Sanctuary', 'lvl': 7, 'elo': 1500, 'icon': 'assets/icons/islands/island_8.jpg'},
    {'title': 'Expert Isle', 'lvl': 8, 'elo': 1600, 'icon': 'assets/icons/islands/island_9.jpg'},
    {'title': 'Master Heights', 'lvl': 9, 'elo': 1700, 'icon': 'assets/icons/islands/island_10.jpg'},
    {'title': 'Candidate Citadel', 'lvl': 10, 'elo': 1800, 'icon': 'assets/icons/islands/island_11.jpg'},
    {'title': 'FIDE Domain', 'lvl': 11, 'elo': 1900, 'icon': 'assets/icons/islands/island_12.jpg'},
    {'title': 'Grandmaster Peak', 'lvl': 12, 'elo': 2000, 'icon': 'assets/icons/islands/island_13.jpg'},
    {'title': 'National Fortress', 'lvl': 13, 'elo': 2100, 'icon': 'assets/icons/islands/island_14.jpg'},
    {'title': 'International Stronghold', 'lvl': 14, 'elo': 2200, 'icon': 'assets/icons/islands/island_15.jpg'},
    {'title': 'Super GM Summit', 'lvl': 15, 'elo': 2300, 'icon': 'assets/icons/islands/island_16.jpg'},
    {'title': 'Stockfish Abyss', 'lvl': 16, 'elo': 2400, 'icon': 'assets/icons/islands/island_17.jpg'},
    {'title': 'Engine Zenith', 'lvl': 17, 'elo': 2500, 'icon': 'assets/icons/islands/island_18.jpg'},
    {'title': 'Supreme Titan', 'lvl': 18, 'elo': 2600, 'icon': 'assets/icons/islands/island_19.jpg'},
    {'title': 'Infinity Realm', 'lvl': 20, 'elo': 2800, 'icon': 'assets/icons/islands/island_20.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCampaign();
  }

  Future<void> _loadCampaign() async {
    final loaded = await TrainingCampaignService.instance.loadCampaignProgress();
    if (mounted) {
      setState(() {
        _campaignData = loaded;
      });
    }
  }

  bool _isIslandUnlocked(int islandIndex) {
    if (islandIndex == 1) return true;
    final model = _campaignData[islandIndex];
    if (model != null && model.isUnlocked) return true;
    final prevModel = _campaignData[islandIndex - 1];
    return prevModel != null && prevModel.completedRounds >= 4;
  }

  int _getCompletedRounds(int islandIndex) {
    return _campaignData[islandIndex]?.completedRounds ?? 0;
  }

  void _showCampaignRulesDialog(BuildContext context, SettingsState settingsState) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primaryGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  settingsState.translate('training_guide_title'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            settingsState.translate('training_guide_desc'),
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _openIslandDetail(BuildContext context, int islandIndex, SettingsState settingsState) {
    final island = _islandData[islandIndex - 1];
    final completedRounds = _getCompletedRounds(islandIndex);
    final isUnlocked = _isIslandUnlocked(islandIndex);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IslandDetailPage(
          islandIndex: islandIndex,
          islandData: island,
          completedRounds: completedRounds,
          isUnlocked: isUnlocked,
          onRoundCompleted: (roundNum) {
            _loadCampaign();
          },
        ),
      ),
    ).then((_) => _loadCampaign());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return StreamBuilder<Map<int, IslandProgressModel>>(
          stream: TrainingCampaignService.instance.onCampaignChanged,
          initialData: _campaignData,
          builder: (context, snapshot) {
            final campaignMap = snapshot.data ?? _campaignData;

            return Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Campaign Header ---
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: settingsState.isDarkMode
                                ? [const Color(0xFF2C1B18), const Color(0xFF1E1E24)]
                                : [AppColors.primaryMahogany, AppColors.lightSecondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGold.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.map_rounded, size: 28, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    settingsState.translate('training_mode'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    settingsState.translate('island_map_title'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 26),
                              onPressed: () => _showCampaignRulesDialog(context, settingsState),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- 20 Islands Map Path ---
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 20,
                        itemBuilder: (context, index) {
                          final islandNum = index + 1;
                          final islandModel = campaignMap[islandNum];
                          final completedRounds = islandModel?.completedRounds ?? 0;
                          final prevModel = campaignMap[islandNum - 1];
                          final isUnlocked = islandNum == 1 || (islandModel?.isUnlocked ?? false) || ((prevModel?.completedRounds ?? 0) >= 4);
                          final isComplete = completedRounds >= 4;
                          final island = _islandData[index];
                          final String? iconPath = island['icon'] as String?;

                          final isEven = index % 2 == 0;

                          return Column(
                            children: [
                              Align(
                                alignment: isEven ? Alignment.centerLeft : Alignment.centerRight,
                                child: FractionallySizedBox(
                                  widthFactor: 0.88,
                                  child: InkWell(
                                    onTap: () => _openIslandDetail(context, islandNum, settingsState),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isComplete
                                            ? AppColors.success.withValues(alpha: 0.15)
                                            : isUnlocked
                                                ? (settingsState.isDarkMode ? AppColors.darkCard : AppColors.lightCard)
                                                : Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isComplete
                                              ? AppColors.success
                                              : isUnlocked
                                                  ? AppColors.primaryGold
                                                  : Colors.grey.withValues(alpha: 0.3),
                                          width: isUnlocked ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 56,
                                            height: 56,
                                            child: Stack(
                                              children: [
                                                ClipOval(
                                                  child: iconPath != null
                                                      ? Image.asset(
                                                          iconPath,
                                                          width: 56,
                                                          height: 56,
                                                          fit: BoxFit.cover,
                                                          filterQuality: FilterQuality.medium,
                                                        )
                                                      : Container(
                                                          width: 56,
                                                          height: 56,
                                                          color: isUnlocked
                                                              ? AppColors.primaryGold.withValues(alpha: 0.25)
                                                              : Colors.grey.withValues(alpha: 0.25),
                                                          child: Icon(
                                                            Icons.landscape_rounded,
                                                            size: 30,
                                                            color: isUnlocked ? AppColors.primaryGold : Colors.grey,
                                                          ),
                                                        ),
                                                ),
                                                if (!isUnlocked)
                                                  ClipOval(
                                                    child: Container(
                                                      width: 56,
                                                      height: 56,
                                                      color: Colors.black.withValues(alpha: 0.55),
                                                    ),
                                                  ),
                                                if (!isUnlocked)
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(3),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[700],
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: Colors.white, width: 1.5),
                                                      ),
                                                      child: const Icon(
                                                        Icons.lock_rounded,
                                                        size: 12,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                if (isComplete)
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(3),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.success,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: Colors.white, width: 1.5),
                                                      ),
                                                      child: const Icon(
                                                        Icons.check_rounded,
                                                        size: 12,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${settingsState.translate('island_level')} $islandNum: ${island['title']}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isUnlocked ? null : Colors.grey,
                                                  ),
                                                ),
                                                Text(
                                                  'Lvl ${island['lvl']} - ${island['elo']} ELO',
                                                  style: const TextStyle(
                                                      fontSize: 11, color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(4),
                                                        child: LinearProgressIndicator(
                                                          value: completedRounds / 4,
                                                          minHeight: 6,
                                                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                                          valueColor: AlwaysStoppedAnimation<Color>(
                                                            isComplete ? AppColors.success : AppColors.primaryGold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Round $completedRounds/4',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: isUnlocked ? AppColors.primaryGold : Colors.grey,
                                            size: 24,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (index < 19)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Center(
                                    child: Column(
                                      children: List.generate(
                                        3,
                                        (_) => Container(
                                          margin: const EdgeInsets.symmetric(vertical: 2),
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: isUnlocked ? AppColors.primaryGold : Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
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
