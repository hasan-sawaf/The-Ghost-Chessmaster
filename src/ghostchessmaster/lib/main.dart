import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/di/injection_container.dart' as di;
import 'core/theme/app_theme.dart';
import 'core/widgets/dynamic_island_widget.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/navigation/presentation/pages/main_navigation_page.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_state.dart';
import 'services/firebase_service.dart';
import 'features/training/data/training_campaign_service.dart';

import 'core/services/connectivity_service.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await FirebaseService.initialize();
  await di.initDependencyInjection();
  InternetConnectivityService.instance.initialize();
  TrainingCampaignService.instance.initialize();
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsBloc>(
          create: (_) => di.sl<SettingsBloc>(),
        ),
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(AuthCheckRequestedEvent()),
        ),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'GhostchessMaster',
            debugShowCheckedModeBanner: false,

            // --- Theme Configuration ---
            themeMode: settingsState.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,

            // --- Localization Configuration ---
            locale: settingsState.locale,
            supportedLocales: const [
              Locale('en', ''),
              Locale('ar', ''),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // --- System Font & Display Scale Guard ---
            // Prevents device-level font size or display scaling from distorting UI layouts
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settingsState.fontScaleFactor),
                ),
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => Stack(
                        children: [
                          ?child,
                          const DynamicIslandWidget(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },

            // --- Navigation Root via BLoC ---
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                if (authState is AuthenticatedState) {
                  return const MainNavigationPage();
                } else if (authState is AuthInitialState || authState is AuthLoadingState) {
                  if (FirebaseAuth.instance.currentUser != null) {
                    return const MainNavigationPage();
                  }
                  return const LoginPage();
                }
                return const LoginPage();
              },
            ),
          );
        },
      ),
    );
  }
}
