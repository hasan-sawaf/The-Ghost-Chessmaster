import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/load_images.dart';

class PieceThemePreviewDialog extends StatelessWidget {
  final String themeKey;
  final String themeName;
  final bool isSelected;
  final VoidCallback onSelect;

  const PieceThemePreviewDialog({
    super.key,
    required this.themeKey,
    required this.themeName,
    required this.isSelected,
    required this.onSelect,
  });

  static const List<Map<String, String>> piecesList = [
    {'codeW': 'WK', 'codeB': 'BK', 'nameEn': 'King', 'nameAr': 'ملك'},
    {'codeW': 'WQ', 'codeB': 'BQ', 'nameEn': 'Queen', 'nameAr': 'ملكة'},
    {'codeW': 'WR', 'codeB': 'BR', 'nameEn': 'Rook', 'nameAr': 'قلعة'},
    {'codeW': 'WB', 'codeB': 'BB', 'nameEn': 'Bishop', 'nameAr': 'فيل'},
    {'codeW': 'WN', 'codeB': 'BN', 'nameEn': 'Knight', 'nameAr': 'حصان'},
    {'codeW': 'WP', 'codeB': 'BP', 'nameEn': 'Pawn', 'nameAr': 'بيدق'},
  ];

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.asset(
                          AppImageHelper.getPieceAssetPath(themeKey, 'WK'),
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) => const Icon(Icons.palette, color: AppColors.primaryGold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              themeName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isAr ? 'معاينة طقم القطع الكامل ♟️' : 'Full Piece Set Preview ♟️',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // White Pieces Row Header
            Text(
              isAr ? 'القطع البيضاء ♔' : 'White Pieces ♔',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGold),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: piecesList.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                          ),
                          child: Image.asset(
                            AppImageHelper.getPieceAssetPath(themeKey, p['codeW']!),
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.extension, size: 24, color: AppColors.primaryGold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAr ? p['nameAr']! : p['nameEn']!,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Black Pieces Row Header
            Text(
              isAr ? 'القطع السوداء ♚' : 'Black Pieces ♚',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: piecesList.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade700),
                          ),
                          child: Image.asset(
                            AppImageHelper.getPieceAssetPath(themeKey, p['codeB']!),
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.extension, size: 24, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAr ? p['nameAr']! : p['nameEn']!,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Action Select Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? AppColors.success : AppColors.primaryGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  onSelect();
                  Navigator.of(context).pop();
                },
                icon: Icon(isSelected ? Icons.check_circle_rounded : Icons.palette_rounded),
                label: Text(
                  isSelected
                      ? (isAr ? 'الثيم الحالي المُختار ✅' : 'Current Active Theme ✅')
                      : (isAr ? 'تأكيد اختيار هذا الثيم 🎨' : 'Select This Piece Theme 🎨'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
