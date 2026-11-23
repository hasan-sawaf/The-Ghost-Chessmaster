import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/data/board_connection_service.dart';
import '../../../quick_match/presentation/pages/quick_match_page.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_event.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../../settings/presentation/widgets/piece_theme_preview_dialog.dart';

const List<PieceThemeOption> allPieceThemes = [
  PieceThemeOption(key: 'Standered', nameEn: 'Standard Default', nameAr: 'الافتراضي القياسي'),
  PieceThemeOption(key: '3d_staunton', nameEn: '3D Staunton', nameAr: 'ستاونتون 3D'),
  PieceThemeOption(key: '3d_wood', nameEn: '3D Wood', nameAr: 'خشبي 3D'),
  PieceThemeOption(key: '3d_plastic', nameEn: '3D Plastic', nameAr: 'بلاستيك 3D'),
  PieceThemeOption(key: '3d_chesskid', nameEn: '3D ChessKid', nameAr: 'شطرنج الأطفال 3D'),
  PieceThemeOption(key: '8_bit', nameEn: '8-Bit Retro', nameAr: 'بكسل 8-بت كلاسيكي'),
  PieceThemeOption(key: 'alpha', nameEn: 'Alpha Vector', nameAr: 'ألفا فيكتور'),
  PieceThemeOption(key: 'bases', nameEn: 'Bases', nameAr: 'قواعد دائرية'),
  PieceThemeOption(key: 'book', nameEn: 'Book Illustration', nameAr: 'رسم الكتب'),
  PieceThemeOption(key: 'bubblegum', nameEn: 'Bubblegum', nameAr: 'علكة فقاعية'),
  PieceThemeOption(key: 'cases', nameEn: 'Cases', nameAr: 'حقائب وأغلفة'),
  PieceThemeOption(key: 'classic', nameEn: 'Classic Traditional', nameAr: 'كلاسيكي تقليدي'),
  PieceThemeOption(key: 'club', nameEn: 'Club Master', nameAr: 'الأندية الاحترافي'),
  PieceThemeOption(key: 'condal', nameEn: 'Condal Heritage', nameAr: 'كوندال تراثي'),
  PieceThemeOption(key: 'dash', nameEn: 'Dash Modern', nameAr: 'داش حديث'),
  PieceThemeOption(key: 'game_room', nameEn: 'Game Room', nameAr: 'غرفة الألعاب'),
  PieceThemeOption(key: 'glass', nameEn: 'Glass Crystal', nameAr: 'كريستال زجاجي'),
  PieceThemeOption(key: 'gothic', nameEn: 'Gothic Medieval', nameAr: 'قوطي قروسطي'),
  PieceThemeOption(key: 'graffiti', nameEn: 'Graffiti Art', nameAr: 'غرافيتي فني'),
  PieceThemeOption(key: 'icy_sea', nameEn: 'Icy Sea', nameAr: 'بحر جليدي'),
  PieceThemeOption(key: 'light', nameEn: 'Light Minimal', nameAr: 'مضيء بسيط'),
  PieceThemeOption(key: 'lolz', nameEn: 'Lolz Cartoon', nameAr: 'كرتوني مرح'),
  PieceThemeOption(key: 'marble', nameEn: 'Royal Marble', nameAr: 'رخام ملكي'),
  PieceThemeOption(key: 'maya', nameEn: 'Maya Civilization', nameAr: 'حضارة المايا'),
  PieceThemeOption(key: 'metal', nameEn: 'Metallic Steel', nameAr: 'معدني فولاذي'),
  PieceThemeOption(key: 'modern', nameEn: 'Modern Art', nameAr: 'فن حديث'),
  PieceThemeOption(key: 'nature', nameEn: 'Nature Organic', nameAr: 'طبيعي عضوي'),
  PieceThemeOption(key: 'neo', nameEn: 'Neo Futuristic', nameAr: 'نيو مستقبلي'),
  PieceThemeOption(key: 'neo_wood', nameEn: 'Neo Wood', nameAr: 'نيو خشبي'),
  PieceThemeOption(key: 'neon', nameEn: 'Cyber Neon', nameAr: 'سايبر نيون'),
  PieceThemeOption(key: 'newspaper', nameEn: 'Newspaper Print', nameAr: 'طباعة صحفية'),
  PieceThemeOption(key: 'ocean', nameEn: 'Deep Ocean', nameAr: 'محيط عميق'),
  PieceThemeOption(key: 'sky', nameEn: 'Sky Blue', nameAr: 'سماء زرقاء'),
  PieceThemeOption(key: 'space', nameEn: 'Cosmic Space', nameAr: 'فضاء كوني'),
  PieceThemeOption(key: 'tigers', nameEn: 'Tigers Wild', nameAr: 'نمور برية'),
  PieceThemeOption(key: 'tournament', nameEn: 'Official Tournament', nameAr: 'بطولات رسمية'),
  PieceThemeOption(key: 'vintage', nameEn: 'Vintage Antique', nameAr: 'أنتيك عتيق'),
  PieceThemeOption(key: 'wood', nameEn: 'Classic Wood', nameAr: 'خشب فاخر'),
];

class PieceThemeOption {
  final String key;
  final String nameEn;
  final String nameAr;

  const PieceThemeOption({
    required this.key,
    required this.nameEn,
    required this.nameAr,
  });
}

class MatchSettingsPage extends StatefulWidget {
  const MatchSettingsPage({super.key});

  @override
  State<MatchSettingsPage> createState() => _MatchSettingsPageState();
}

class _MatchSettingsPageState extends State<MatchSettingsPage> {
  // Configuration State
  int _timerMinutes = 10;
  int _incrementSeconds = 2;
  int _targetElo = 1500;
  String _playStyleKey = 'style_balanced';
  String _preferredColor = 'W'; // 'W', 'B', 'R'
  bool _audioEnabled = true;

  int _calculateStockfishLevel(int elo) {
    return ((elo - 800) / 100).round().clamp(0, 20);
  }

  void _adjustTimer(int delta) {
    setState(() {
      _timerMinutes = (_timerMinutes + delta).clamp(0, 30);
    });
  }

  void _adjustIncrement(int delta) {
    setState(() {
      _incrementSeconds = (_incrementSeconds + delta).clamp(0, 3);
    });
  }

  void _adjustElo(int delta) {
    setState(() {
      _targetElo = (_targetElo + delta).clamp(800, 2800);
    });
  }

  void _startQuickMatch(BuildContext context) async {
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
        if (!context.mounted) return;
        final retry = await connService.showBoardOfflineDialog(context, isAr: isAr);
        if (retry && context.mounted) {
          // Recursive retry
          _startQuickMatch(context);
        }
        return;
      }

      // Check if CoreXY robotic mechanism is at Home (0,0)
      if (!connService.isCorexyHome) {
        if (!context.mounted) return;
        await connService.showCorexyNotHomeDialog(context, isAr: isAr);
        return;
      }

      if (!context.mounted) return;
      final positionConfirmed = await connService.showPhysicalBoardInitialPositionDialog(context, isAr: isAr);
      if (!positionConfirmed) {
        return; // User cancelled position confirmation
      }

      if (!context.mounted) return;
      final cameraSuccess = await connService.startCameraWithVerification(context);
      if (!cameraSuccess) {
        return; // Camera failed to turn ON -> block entry into match
      }
    }

    final lvl = _calculateStockfishLevel(_targetElo);
    final isWhiteChosen = _preferredColor == 'W' || (_preferredColor == 'R' && DateTime.now().millisecond % 2 == 0);

    if (settingsState.isPhysicalMode) {
      await connService.updateLiveSessionState(
        isWhite: isWhiteChosen,
        timer: _timerMinutes * 60,
        incTime: _incrementSeconds,
        difficulty: lvl,
        playStyle: _playStyleKey,
        elo: _targetElo,
      );
    }

    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuickMatchPage(
          preferredColor: _preferredColor,
          stockfishLevel: lvl,
          eloRating: _targetElo,
          timerMinutes: _timerMinutes,
          incrementSeconds: _incrementSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final isDark = settingsState.isDarkMode;
        final isAr = settingsState.isArabic;
        final lvlNum = _calculateStockfishLevel(_targetElo);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isAr ? 'إعدادات المباراة السريعة' : 'Quick Match Setup',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: Game Mode & Piece Color
                _buildSectionHeader(
                  icon: Icons.sports_esports_rounded,
                  title: isAr ? '1. نمط اللعب ولون القطع' : '1. Gameplay Mode & Side',
                ),
                const SizedBox(height: 12),
                _buildModeAndColorCard(settingsState, isDark, isAr),
                const SizedBox(height: 20),

                // SECTION 2: AI Opponent & Difficulty
                _buildSectionHeader(
                  icon: Icons.psychology_rounded,
                  title: isAr ? '2. مستوى الذكاء الاصطناعي (Stockfish)' : '2. AI Opponent & Difficulty',
                ),
                const SizedBox(height: 12),
                _buildDifficultyCard(settingsState, isDark, isAr),
                const SizedBox(height: 20),

                // SECTION 3: Time Control & Clock
                _buildSectionHeader(
                  icon: Icons.timer_rounded,
                  title: isAr ? '3. إعدادات العداد والوقت' : '3. Time Control & Clock',
                ),
                const SizedBox(height: 12),
                _buildClockCard(settingsState, isDark, isAr),
                const SizedBox(height: 20),

                // SECTION 4: Aesthetics & Sound
                _buildSectionHeader(
                  icon: Icons.palette_rounded,
                  title: isAr ? '4. ثيم القطع والأصوات' : '4. Aesthetics & Sound',
                ),
                const SizedBox(height: 12),
                _buildAestheticsCard(settingsState, isDark, isAr),
                const SizedBox(height: 30),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomActionBar(settingsState, isAr, lvlNum),
        );
      },
    );
  }

  // ==========================================
  // SECTION HEADER HELPER (Without Subtitle)
  // ==========================================
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryGold),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SECTION 1 CARD: MODE & COLOR
  // ==========================================
  Widget _buildModeAndColorCard(SettingsState settingsState, bool isDark, bool isAr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Board Mode Options
          Text(
            isAr ? 'نمط الرقعة' : 'Board Type',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGold),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              // Digital Mode
              Expanded(
                child: _buildModeOptionTile(
                  title: isAr ? 'رقمي (شاشة اللمس)' : 'Digital Touch',
                  icon: Icons.touch_app_rounded,
                  isSelected: !settingsState.isPhysicalMode,
                  onTap: () {
                    context.read<SettingsBloc>().add(const SetGameplayModeEvent(false));
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              // Physical Mode
              Expanded(
                child: _buildModeOptionTile(
                  title: isAr ? 'فيزيائي (الكاميرا)' : 'Physical Board',
                  icon: Icons.camera_alt_rounded,
                  isSelected: settingsState.isPhysicalMode,
                  onTap: () async {
                    if (!BoardConnectionService.instance.isConnected) {
                      BoardConnectionService.instance.showBoardRequirementDialog(context);
                      return;
                    }
                    final confirmed = await BoardConnectionService.instance.showPhysicalBoardInitialPositionDialog(context, isAr: isAr);
                    if (confirmed && mounted) {
                      context.read<SettingsBloc>().add(const SetGameplayModeEvent(true));
                    }
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Player Color Choice
          Text(
            isAr ? 'لون قطعك' : 'Your Color',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGold),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildColorOptionCard(
                  title: isAr ? 'أبيض' : 'White',
                  colorKey: 'W',
                  assetPath: 'assets/Pieces/Standered/white_pieces/WK.png',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildColorOptionCard(
                  title: isAr ? 'أسود' : 'Black',
                  colorKey: 'B',
                  assetPath: 'assets/Pieces/Standered/black_pieces/BK.png',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildColorOptionCard(
                  title: isAr ? 'عشوائي' : 'Random',
                  colorKey: 'R',
                  iconData: Icons.shuffle_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOptionTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E1E24) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryGold : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? AppColors.primaryGold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOptionCard({
    required String title,
    required String colorKey,
    String? assetPath,
    IconData? iconData,
    required bool isDark,
  }) {
    final isSelected = _preferredColor == colorKey;

    return InkWell(
      onTap: () => setState(() => _preferredColor = colorKey),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E1E24) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (assetPath != null)
              Image.asset(assetPath, width: 32, height: 32)
            else if (iconData != null)
              Icon(iconData, size: 32, color: AppColors.primaryGold),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? AppColors.primaryGold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SECTION 2 CARD: AI OPPONENT & ELO SLIDER
  // ==========================================
  Widget _buildDifficultyCard(SettingsState settingsState, bool isDark, bool isAr) {
    final currentLvl = _calculateStockfishLevel(_targetElo);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ELO Rating Slider & Level Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr ? 'تقييم ELO والمستوى' : 'ELO Rating & Level',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Lvl $currentLvl • $_targetElo ELO',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryGold,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade300,
              thumbColor: AppColors.primaryGold,
              overlayColor: AppColors.primaryGold.withValues(alpha: 0.2),
              valueIndicatorColor: AppColors.primaryGold,
              valueIndicatorTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            child: Slider(
              value: _targetElo.toDouble(),
              min: 800,
              max: 2800,
              divisions: 20,
              label: '$_targetElo ELO (Lvl $currentLvl)',
              onChanged: (val) {
                _adjustElo(val.round() - _targetElo);
              },
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('800 ELO (Lvl 0)', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('2800 ELO (Lvl 20)', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 18),

          // Playing Style Personality
          Text(
            isAr ? 'أسلوب لعب الذكاء الاصطناعي' : 'AI Playstyle',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGold),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildStyleChip('style_balanced', isAr ? 'متوازن' : 'Balanced', isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStyleChip('style_aggressive', isAr ? 'هجومي' : 'Aggressive', isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStyleChip('style_solid', isAr ? 'صلب' : 'Solid', isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyleChip(String key, String title, bool isDark) {
    final isSelected = _playStyleKey == key;
    return InkWell(
      onTap: () => setState(() => _playStyleKey = key),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E1E24) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isSelected ? AppColors.primaryGold : null,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SECTION 3 CARD: CLOCK & TIMER (Only +/- Steppers)
  // ==========================================
  Widget _buildClockCard(SettingsState settingsState, bool isDark, bool isAr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timer Stepper Controls
          Text(
            isAr ? 'وقت المباراة الإجمالي' : 'Game Time Limit',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGold),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _timerMinutes == 0
                    ? (isAr ? 'الوقت: مفتوح (بدون حد)' : 'Time: Unlimited')
                    : '$_timerMinutes ${isAr ? 'دقائق لكل لاعب' : 'Minutes per player'}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                    onPressed: () => _adjustTimer(-1),
                  ),
                  Text('$_timerMinutes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                    onPressed: () => _adjustTimer(1),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),

          // Increment Stepper Controls
          Text(
            isAr ? 'زيادة الثواني لكل نقلة (إنكريمنت)' : 'Increment Per Move',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGold),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '+$_incrementSeconds ${isAr ? 'ثانية تضاف بعد كل نقلة' : 'seconds added per move'}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                    onPressed: () => _adjustIncrement(-1),
                  ),
                  Text('+$_incrementSeconds', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                    onPressed: () => _adjustIncrement(1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 4 CARD: AESTHETICS & AUDIO
  // ==========================================
  Widget _buildAestheticsCard(SettingsState settingsState, bool isDark, bool isAr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Piece Theme Selector Header
          Text(
            isAr ? 'تصميم قطع الشطرنج' : 'Chess Pieces Theme',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGold),
          ),
          const SizedBox(height: 10),

          // Piece Theme List Container
          Material(
            color: isDark ? const Color(0xFF1E1E24) : Colors.grey.shade100,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: SizedBox(
              height: 260,
              child: ListView.separated(
                itemCount: allPieceThemes.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final theme = allPieceThemes[index];
                  final themeName = isAr ? theme.nameAr : theme.nameEn;
                  final isSelected = settingsState.pieceTheme == theme.key;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    onTap: () {
                      context.read<SettingsBloc>().add(SetPieceThemeEvent(theme.key));
                    },
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primaryGold : Colors.grey,
                      size: 20,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            themeName,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13,
                              color: isSelected ? AppColors.primaryGold : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => PieceThemePreviewDialog(
                                themeKey: theme.key,
                                themeName: themeName,
                                isSelected: isSelected,
                                onSelect: () {
                                  context.read<SettingsBloc>().add(SetPieceThemeEvent(theme.key));
                                },
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.primaryGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryGold.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryGold : Colors.grey.shade400,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Image.asset(
                        'assets/Pieces/${theme.key}/white_pieces/WK.png',
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.extension, size: 18),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Audio Effects Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _audioEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: _audioEnabled ? AppColors.primaryGold : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isAr ? 'أصوات النقلات والتنبيهات 🔊' : 'Game Sound Effects 🔊',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Switch(
                value: _audioEnabled,
                activeThumbColor: AppColors.primaryGold,
                onChanged: (val) {
                  setState(() => _audioEnabled = val);
                  context.read<SettingsBloc>().add(ToggleSoundEffectsEvent(val));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FLOATING BOTTOM ACTION BAR
  // ==========================================
  Widget _buildBottomActionBar(SettingsState settingsState, bool isAr, int lvlNum) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: settingsState.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_timerMinutes == 0 ? (isAr ? "بدون وقت" : "No Clock") : "$_timerMinutes m + $_incrementSeconds s"} • Lvl $lvlNum ($_targetElo ELO)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    settingsState.isPhysicalMode
                        ? (isAr ? 'الوضع الفيزيائي' : 'Physical Board')
                        : (isAr ? 'الوضع الرقمي' : 'Digital Touch'),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => _startQuickMatch(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                    const SizedBox(width: 4),
                    Text(
                      isAr ? 'المتابعة إلى الرقعة ♟️' : 'Continue to Board ♟️',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
