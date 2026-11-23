import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghostchessmaster/core/theme/app_colors.dart';
import 'package:ghostchessmaster/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ghostchessmaster/features/auth/presentation/bloc/auth_event.dart';
import 'package:ghostchessmaster/features/auth/presentation/pages/reset_password_page.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_state.dart';

class MyAccountPage extends StatelessWidget {
  const MyAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final isDark = settingsState.isDarkMode;
        final isAr = settingsState.isArabic;
        final fontScale = settingsState.fontScaleFactor;
        final user = FirebaseAuth.instance.currentUser;
        final email = user?.email ?? (isAr ? 'غير متوفر' : 'N/A');
        final creationTime = user?.metadata.creationTime;
        final formattedDate = creationTime != null
            ? '${creationTime.year}-${creationTime.month.toString().padLeft(2, '0')}-${creationTime.day.toString().padLeft(2, '0')} ${creationTime.hour.toString().padLeft(2, '0')}:${creationTime.minute.toString().padLeft(2, '0')}'
            : (isAr ? 'غير متوفر' : 'N/A');

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(
                isAr ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 20 * fontScale,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              isAr ? 'حسابي' : 'My Account',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18 * fontScale,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Profile Avatar Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40 * fontScale,
                        backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                        child: Text(
                          email.isNotEmpty ? email[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 32 * fontScale,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 16 * fontScale,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              isAr ? 'حساب موثق' : 'Verified Account',
                              style: TextStyle(
                                fontSize: 11 * fontScale,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section Header: Details
                Text(
                  isAr ? 'معلومات الحساب' : 'Account Details',
                  style: TextStyle(
                    fontSize: 13 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Account Details List
                Material(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Email Tile
                      ListTile(
                        leading: _buildIconBadge(Icons.email_rounded, Colors.blue, fontScale),
                        title: Text(
                          isAr ? 'البريد الإلكتروني' : 'Email Address',
                          style: TextStyle(
                            fontSize: 12 * fontScale,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          email,
                          style: TextStyle(
                            fontSize: 14 * fontScale,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      _buildDivider(isDark),

                      // Creation Time Tile
                      ListTile(
                        leading: _buildIconBadge(Icons.calendar_today_rounded, AppColors.primaryGold, fontScale),
                        title: Text(
                          isAr ? 'تاريخ إنشاء الحساب' : 'Account Open Time',
                          style: TextStyle(
                            fontSize: 12 * fontScale,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 14 * fontScale,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section Header: Security
                Text(
                  isAr ? 'الأمان والإعدادات' : 'Security & Management',
                  style: TextStyle(
                    fontSize: 13 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Security Actions
                Material(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: ListTile(
                    leading: _buildIconBadge(Icons.lock_reset_rounded, Colors.orange, fontScale),
                    title: Text(
                      settingsState.translate('reset_pass_setting'),
                      style: TextStyle(
                        fontSize: 14 * fontScale,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      isAr ? 'تغيير كلمة المرور الخاصة بحسابك' : 'Reset your account password',
                      style: TextStyle(
                        fontSize: 11 * fontScale,
                        color: Colors.grey,
                      ),
                    ),
                    trailing: Icon(
                      isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // 4. Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, 52 * fontScale),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    icon: Icon(Icons.logout_rounded, size: 20 * fontScale),
                    label: Text(
                      settingsState.translate('logout_btn'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15 * fontScale,
                      ),
                    ),
                    onPressed: () {
                      _showLogoutConfirmationDialog(context, settingsState);
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconBadge(IconData icon, Color color, double fontScale) {
    return Container(
      padding: EdgeInsets.all(8 * fontScale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20 * fontScale),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context, SettingsState settingsState) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(settingsState.translate('logout_dialog_title')),
          content: Text(settingsState.translate('logout_dialog_desc')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(settingsState.translate('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                context.read<AuthBloc>().add(SignOutRequestedEvent());
              },
              child: Text(
                settingsState.translate('logout_btn'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
