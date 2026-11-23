import 'package:flutter/material.dart';

/// Centralized utility for resolving and loading all image assets,
/// move classification icons, piece themes, and app graphics across Ghost Chess Master.
class AppImageHelper {
  // Set of valid 12 piece codes used in Ghost Chess Master
  static const Set<String> _validPieceCodes = {
    'WP', 'WN', 'WB', 'WR', 'WQ', 'WK',
    'BP', 'BN', 'BB', 'BR', 'BQ', 'BK',
  };

  // Map of move classification / icon keys to 1024x icon filenames
  static const Map<String, String> _iconFileNameMap = {
    'book': 'book_1024x.png',
    'best': 'best_1024x.png',
    'brilliant': 'brilliant_1024x.png',
    'great': 'great_find_1024x.png',
    'excellent': 'excellent_1024x.png',
    'good': 'good_1024x.png',
    'okay': 'good_1024x.png',
    'inaccuracy': 'inaccuracy_1024x.png',
    'mistake': 'mistake_1024x.png',
    'blunder': 'blunder_1024x.png',
    'miss': 'miss_1024x.png',
    'forced': 'forced_1024x.png',
  };

  // Map of all 38 theme names & keys (lowercase) to exact directory folder names in assets/Pieces/
  static const Map<String, String> _themeFolderMap = {
    'standered': 'Standered',
    'standard default': 'Standered',
    'classic': 'classic',
    'classic traditional': 'classic',
    'light': 'light',
    'light minimal': 'light',
    'club': 'club',
    'club master': 'club',
    'book': 'book',
    'book illustration': 'book',
    'bases': 'bases',
    'newspaper': 'newspaper',
    'newspaper print': 'newspaper',
    'dash': 'dash',
    'dash modern': 'dash',
    '3d_plastic': '3d_plastic',
    '3d plastic': '3d_plastic',
    '3d_staunton': '3d_staunton',
    '3d staunton': '3d_staunton',
    '3d_wood': '3d_wood',
    '3d wood': '3d_wood',
    '8bit': '8bit',
    '8-bit retro': '8bit',
    'alpha': 'alpha',
    'anarcandy': 'anarcandy',
    'cases': 'cases',
    'condal': 'condal',
    'california': 'california',
    'cardinal': 'cardinal',
    'cburnett': 'cburnett',
    'chessnut': 'chessnut',
    'companion': 'companion',
    'dubrovny': 'dubrovny',
    'fantasy': 'fantasy',
    'fresca': 'fresca',
    'gioco': 'gioco',
    'governor': 'governor',
    'horsey': 'horsey',
    'icontropic': 'icontropic',
    'kosal': 'kosal',
    'leipzig': 'leipzig',
    'letter': 'letter',
    'libra': 'libra',
    'maestro': 'maestro',
    'merida': 'merida',
    'monarchy': 'monarchy',
    'mpchess': 'mpchess',
    'pirouetti': 'pirouetti',
    'pixel': 'pixel',
    'reagan': 'reagan',
    'riohacha': 'riohacha',
    'shapes': 'shapes',
    'spatial': 'spatial',
    'tatiana': 'tatiana',
  };

  /// Resolves the piece theme folder name (e.g. 'classic', 'Standered', '3d_staunton')
  /// from any input pieceTheme string (whether folder key or full display name like 'Classic Traditional').
  static String resolvePieceThemeFolderKey(String? pieceTheme) {
    if (pieceTheme == null || pieceTheme.trim().isEmpty) {
      return 'Standered';
    }
    final keyLower = pieceTheme.trim().toLowerCase();
    return _themeFolderMap[keyLower] ?? pieceTheme;
  }

  /// Smart resolver for piece asset path.
  /// Accepts both `(pieceCode, theme)` or `(theme, pieceCode)` seamlessly!
  /// Guarantees exact asset path format: `assets/Pieces/{ThemeFolder}/{black_pieces|white_pieces}/{PieceCode}.png`.
  static String getPieceAssetPath(String arg1, [String? arg2]) {
    final String pieceCode;
    final String? theme;

    final upper1 = arg1.trim().toUpperCase();
    final upper2 = arg2?.trim().toUpperCase();

    if (_validPieceCodes.contains(upper1)) {
      pieceCode = upper1;
      theme = arg2;
    } else if (upper2 != null && _validPieceCodes.contains(upper2)) {
      pieceCode = upper2;
      theme = arg1;
    } else {
      pieceCode = upper1;
      theme = arg2;
    }

    final folderKey = resolvePieceThemeFolderKey(theme);
    final colorFolder = pieceCode.startsWith('B') ? 'black_pieces' : 'white_pieces';
    return 'assets/Pieces/$folderKey/$colorFolder/$pieceCode.png';
  }

  /// Legacy helper returning a non-null asset path string with fallback.
  static String getAssetPath(String? key) {
    final path = getClassificationIconPath(key);
    return path ?? 'assets/icons/1024x/book_1024x.png';
  }

  /// Resolves the full asset path for a classification or icon key.
  /// Returns `null` if the move is unanalyzed ('none', 'not analyzed', empty) or has no real rating.
  static String? getClassificationIconPath(String? iconKey) {
    if (iconKey == null || iconKey.trim().isEmpty) {
      return null;
    }

    final keyLower = iconKey.trim().toLowerCase();
    if (keyLower == 'none' ||
        keyLower == 'null' ||
        keyLower == 'not analyzed' ||
        keyLower == 'غير محللة' ||
        keyLower == 'unanalyzed') {
      return null;
    }

    // Handle legacy full path strings stored in older Firestore documents
    if (iconKey.startsWith('assets/')) {
      return iconKey;
    }

    final fileName = _iconFileNameMap[keyLower];
    if (fileName == null) return null;
    return 'assets/icons/1024x/$fileName';
  }

  /// Returns an [Image] widget for a move classification or icon key.
  /// Returns [SizedBox.shrink()] if the move is unanalyzed.
  static Widget getClassificationIconWidget(
    String? iconKey, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    final path = getClassificationIconPath(iconKey);
    if (path == null) return const SizedBox.shrink();

    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
