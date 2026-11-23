import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_event.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'register_page.dart';
import 'reset_password_page.dart';
import '../../../navigation/presentation/pages/main_navigation_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            SignInSubmittedEvent(
              email: _emailController.text,
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthenticatedState) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigationPage()),
          );
        }
      },
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  tooltip: settingsState.translate('theme_toggle'),
                  icon: Icon(settingsState.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => context.read<SettingsBloc>().add(ToggleThemeEvent()),
                ),
                TextButton.icon(
                  onPressed: () => context.read<SettingsBloc>().add(ToggleLanguageEvent()),
                  icon: const Icon(Icons.language, size: 20),
                  label: Text(
                    settingsState.translate('language_toggle'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- Branding Logo ---
                          Center(
                            child: Container(
                              height: 110,
                              width: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryGold.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(55),
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => const Center(
                                    child: Icon(Icons.castle_rounded, size: 44, color: Colors.white70),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          Text(
                            settingsState.translate('welcome_back'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settingsState.translate('login_subtitle'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: settingsState.isDarkMode
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // --- Error Banner ---
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, authState) {
                              if (authState is UnauthenticatedState &&
                                  authState.errorMessage != null) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.error),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: AppColors.error),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          settingsState.translate(authState.errorMessage!),
                                          style: const TextStyle(
                                            color: AppColors.error,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          // --- Fields ---
                          Text(
                            settingsState.translate('email_label'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: settingsState.translate('email_hint'),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return settingsState.translate('field_required');
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return settingsState.translate('invalid_email');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          Text(
                            settingsState.translate('password_label'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: settingsState.translate('password_hint'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return settingsState.translate('field_required');
                              }
                              if (value.length < 6) {
                                return settingsState.translate('short_password');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                context.read<AuthBloc>().add(ClearAuthErrorEvent());
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
                                );
                              },
                              child: Text(
                                settingsState.translate('forgot_password'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // --- Submit Button ---
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, authState) {
                              final isLoading = authState is AuthLoadingState;
                              return ElevatedButton(
                                onPressed: isLoading ? null : () => _submitLogin(context),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(settingsState.translate('sign_in_btn')),
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // --- Navigation Link ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                settingsState.translate('dont_have_account'),
                                style: TextStyle(
                                  color: settingsState.isDarkMode
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  context.read<AuthBloc>().add(ClearAuthErrorEvent());
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                                  );
                                },
                                child: Text(
                                  settingsState.translate('sign_up_btn'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
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
            ),
          );
        },
      ),
    );
  }
}
