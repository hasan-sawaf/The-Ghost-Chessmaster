import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../history/presentation/pages/history_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../../training/presentation/pages/training_page.dart';

class MainNavigationPage extends StatefulWidget {
  final int initialIndex;
  const MainNavigationPage({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  final List<Widget> _pages = const [
    HomePage(),
    TrainingPage(),
    HistoryPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is UnauthenticatedState) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      },
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                indicatorColor: AppColors.primaryGold.withValues(alpha: 0.25),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.sports_esports_outlined),
                    selectedIcon: const Icon(Icons.sports_esports, color: AppColors.primaryGold),
                    label: settingsState.translate('nav_home'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.model_training_outlined),
                    selectedIcon: const Icon(Icons.model_training, color: AppColors.primaryGold),
                    label: settingsState.translate('nav_training'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.history_edu_outlined),
                    selectedIcon: const Icon(Icons.history_edu, color: AppColors.primaryGold),
                    label: settingsState.translate('nav_history'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person, color: AppColors.primaryGold),
                    label: settingsState.translate('nav_profile'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
