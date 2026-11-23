class TrainingThemeInfo {
  final String key;
  final String displayName;

  const TrainingThemeInfo({required this.key, required this.displayName});
}

class TrainingThemeHelper {
  /// All 38 piece themes ordered by progression & visual difficulty with exact folder key and display name.
  static const List<TrainingThemeInfo> orderedThemeInfos = [
    TrainingThemeInfo(key: 'Standered', displayName: 'Standard Default'),    // Theme 1  (Island 1: R1-4)
    TrainingThemeInfo(key: 'classic', displayName: 'Classic Traditional'),   // Theme 2  (Island 2: R1-4)
    TrainingThemeInfo(key: 'light', displayName: 'Light Minimal'),           // Theme 3  (Island 3: R1-2)
    TrainingThemeInfo(key: 'club', displayName: 'Club Master'),              // Theme 4  (Island 3: R3-4)
    TrainingThemeInfo(key: 'book', displayName: 'Book Illustration'),        // Theme 5  (Island 4: R1-2)
    TrainingThemeInfo(key: 'bases', displayName: 'Bases'),                  // Theme 6  (Island 4: R3-4)
    TrainingThemeInfo(key: 'newspaper', displayName: 'Newspaper Print'),    // Theme 7  (Island 5: R1-2)
    TrainingThemeInfo(key: 'dash', displayName: 'Dash Modern'),             // Theme 8  (Island 5: R3-4)
    TrainingThemeInfo(key: '3d_plastic', displayName: '3D Plastic'),        // Theme 9  (Island 6: R1-2)
    TrainingThemeInfo(key: '3d_staunton', displayName: '3D Staunton'),      // Theme 10 (Island 6: R3-4)
    TrainingThemeInfo(key: '3d_wood', displayName: '3D Wood'),              // Theme 11 (Island 7: R1-2)
    TrainingThemeInfo(key: 'wood', displayName: 'Classic Wood'),            // Theme 12 (Island 7: R3-4)
    TrainingThemeInfo(key: 'neo_wood', displayName: 'Neo Wood'),            // Theme 13 (Island 8: R1-2)
    TrainingThemeInfo(key: 'vintage', displayName: 'Vintage Antique'),      // Theme 14 (Island 8: R3-4)
    TrainingThemeInfo(key: 'cases', displayName: 'Cases'),                  // Theme 15 (Island 9: R1-2)
    TrainingThemeInfo(key: 'game_room', displayName: 'Game Room'),          // Theme 16 (Island 9: R3-4)
    TrainingThemeInfo(key: '3d_chesskid', displayName: '3D ChessKid'),      // Theme 17 (Island 10: R1-2)
    TrainingThemeInfo(key: 'bubblegum', displayName: 'Bubblegum'),          // Theme 18 (Island 10: R3-4)
    TrainingThemeInfo(key: 'lolz', displayName: 'Lolz Cartoon'),            // Theme 19 (Island 11: R1-2)
    TrainingThemeInfo(key: '8_bit', displayName: '8-Bit Retro'),            // Theme 20 (Island 11: R3-4)
    TrainingThemeInfo(key: 'alpha', displayName: 'Alpha Vector'),           // Theme 21 (Island 12: R1-2)
    TrainingThemeInfo(key: 'condal', displayName: 'Condal Heritage'),       // Theme 22 (Island 12: R3-4)
    TrainingThemeInfo(key: 'sky', displayName: 'Sky Blue'),                  // Theme 23 (Island 13: R1-2)
    TrainingThemeInfo(key: 'ocean', displayName: 'Deep Ocean'),              // Theme 24 (Island 13: R3-4)
    TrainingThemeInfo(key: 'icy_sea', displayName: 'Icy Sea'),              // Theme 25 (Island 14: R1-2)
    TrainingThemeInfo(key: 'nature', displayName: 'Nature Organic'),         // Theme 26 (Island 14: R3-4)
    TrainingThemeInfo(key: 'tigers', displayName: 'Tigers Wild'),           // Theme 27 (Island 15: R1-2)
    TrainingThemeInfo(key: 'maya', displayName: 'Maya Civilization'),       // Theme 28 (Island 15: R3-4)
    TrainingThemeInfo(key: 'gothic', displayName: 'Gothic Medieval'),       // Theme 29 (Island 16: R1-2)
    TrainingThemeInfo(key: 'graffiti', displayName: 'Graffiti Art'),        // Theme 30 (Island 16: R3-4)
    TrainingThemeInfo(key: 'glass', displayName: 'Glass Crystal'),          // Theme 31 (Island 17: R1-2)
    TrainingThemeInfo(key: 'marble', displayName: 'Royal Marble'),          // Theme 32 (Island 17: R3-4)
    TrainingThemeInfo(key: 'metal', displayName: 'Metallic Steel'),        // Theme 33 (Island 18: R1-2)
    TrainingThemeInfo(key: 'modern', displayName: 'Modern Art'),            // Theme 34 (Island 18: R3-4)
    TrainingThemeInfo(key: 'tournament', displayName: 'Official Tournament'),// Theme 35 (Island 19: R1-2)
    TrainingThemeInfo(key: 'neo', displayName: 'Neo Futuristic'),           // Theme 36 (Island 19: R3-4)
    TrainingThemeInfo(key: 'neon', displayName: 'Cyber Neon'),              // Theme 37 (Island 20: R1-2)
    TrainingThemeInfo(key: 'space', displayName: 'Cosmic Space'),           // Theme 38 (Island 20: R3-4)
  ];

  /// Legacy list of theme folder keys for backward compatibility.
  static List<String> get orderedThemes =>
      orderedThemeInfos.map((info) => info.key).toList();

  /// Resolves the exact piece theme display name (e.g. 'Classic Traditional') for a given Island (1-20) and Round (1-4).
  static String getTrainingPieceTheme(int islandIndex, int roundIndex) {
    return getTrainingThemeInfo(islandIndex, roundIndex).displayName;
  }

  /// Resolves the exact folder key (e.g. 'classic') for a given Island (1-20) and Round (1-4).
  static String getTrainingPieceThemeFolderKey(int islandIndex, int roundIndex) {
    return getTrainingThemeInfo(islandIndex, roundIndex).key;
  }

  /// Resolves the exact [TrainingThemeInfo] for a given Island (1-20) and Round (1-4).
  static TrainingThemeInfo getTrainingThemeInfo(int islandIndex, int roundIndex) {
    if (islandIndex <= 1) return orderedThemeInfos[0]; // Theme 1 (Island 1: R1-4)
    if (islandIndex == 2) return orderedThemeInfos[1]; // Theme 2 (Island 2: R1-4)

    // For Islands 3 to 20:
    // Base theme index for Island 3:
    // Island 3 -> index 2 (Theme 3: Light Minimal for R1-2, Theme 4: Club Master for R3-4)
    final baseIdx = 2 + (islandIndex - 3) * 2;
    final isSecondHalf = roundIndex >= 3;
    final finalIdx = (baseIdx + (isSecondHalf ? 1 : 0)).clamp(0, orderedThemeInfos.length - 1);

    return orderedThemeInfos[finalIdx];
  }
}
