import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/load_images.dart';

enum SnackBarType { success, error, warning, info }

class AppSnackBar {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Displays a custom modern top notification banner with 1024x icon & swipe-to-dismiss.
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    String? customIconAsset,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    // 1. Remove any currently active top notification overlay
    dismissCurrent();

    final overlayState = Overlay.of(context);

    String iconAsset;
    Color accentColor;
    Color iconBgColor;

    switch (type) {
      case SnackBarType.success:
        iconAsset = AppImageHelper.getAssetPath(customIconAsset ?? 'correct_1024x.png');
        accentColor = AppColors.success;
        iconBgColor = AppColors.success.withValues(alpha: 0.18);
        break;
      case SnackBarType.error:
        iconAsset = AppImageHelper.getAssetPath(customIconAsset ?? 'incorrect_1024x.png');
        accentColor = AppColors.error;
        iconBgColor = AppColors.error.withValues(alpha: 0.18);
        break;
      case SnackBarType.warning:
        iconAsset = AppImageHelper.getAssetPath(customIconAsset ?? 'inaccuracy_1024x.png');
        accentColor = Colors.amber;
        iconBgColor = Colors.amber.withValues(alpha: 0.18);
        break;
      case SnackBarType.info:
        iconAsset = AppImageHelper.getAssetPath(customIconAsset ?? 'good_1024x.png');
        accentColor = AppColors.primaryGold;
        iconBgColor = AppColors.primaryGold.withValues(alpha: 0.18);
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeTop = MediaQuery.of(context).padding.top;
    final topPadding = math.max(safeTop + 18.0, 52.0);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          top: topPadding,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.horizontal,
              onDismissed: (_) {
                dismissCurrent();
              },
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
                    dismissCurrent();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E24) : Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 1024x Chess Icon Tile
                      Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                        ),
                        child: Image.asset(
                          iconAsset,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) => Icon(
                            type == SnackBarType.success
                                ? Icons.check_circle_rounded
                                : (type == SnackBarType.error
                                    ? Icons.error_rounded
                                    : (type == SnackBarType.warning
                                        ? Icons.warning_rounded
                                        : Icons.info_rounded)),
                            color: accentColor,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Message Text
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),

                      if (action != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            action.onPressed();
                            dismissCurrent();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: Text(
                            action.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    _dismissTimer = Timer(duration, () {
      dismissCurrent();
    });
  }

  /// Dismisses the currently displayed top overlay snackbar.
  static void dismissCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  /// Convenience helper for Success SnackBar
  static void showSuccess(
    BuildContext context,
    String message, {
    String? iconAsset = 'assets/icons/1024x/correct_1024x.png',
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      type: SnackBarType.success,
      customIconAsset: iconAsset,
      duration: duration,
    );
  }

  /// Convenience helper for Error SnackBar
  static void showError(
    BuildContext context,
    String message, {
    String? iconAsset = 'assets/icons/1024x/incorrect_1024x.png',
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      type: SnackBarType.error,
      customIconAsset: iconAsset,
      duration: duration,
    );
  }

  /// Convenience helper for Warning SnackBar
  static void showWarning(
    BuildContext context,
    String message, {
    String? iconAsset = 'assets/icons/1024x/inaccuracy_1024x.png',
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      type: SnackBarType.warning,
      customIconAsset: iconAsset,
      duration: duration,
    );
  }

  /// Convenience helper for Info SnackBar
  static void showInfo(
    BuildContext context,
    String message, {
    String? iconAsset = 'assets/icons/1024x/good_1024x.png',
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      type: SnackBarType.info,
      customIconAsset: iconAsset,
      duration: duration,
    );
  }
}
