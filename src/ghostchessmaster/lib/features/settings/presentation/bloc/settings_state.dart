import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/utils/load_images.dart';

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final Locale locale;
  final String fontSizeChoice; // 'small', 'normal', 'big'
  final bool isPhysicalMode; // true = Physical Board (Vision), false = Local Digital Play
  final String pieceTheme; // e.g. 'Standered', '3d_staunton', 'neon', etc.
  final bool isSoundEnabled; // Sound effects toggle

  const SettingsState({
    this.themeMode = ThemeMode.dark,
    this.locale = const Locale('en'),
    this.fontSizeChoice = 'small', // Default is Small
    this.isPhysicalMode = true, // Default to Physical board
    this.pieceTheme = 'Standered', // Default to Standard piece theme
    this.isSoundEnabled = true, // Default to true
  });

  bool get isDarkMode => themeMode == ThemeMode.dark;
  bool get isArabic => locale.languageCode == 'ar';
  String get langCode => locale.languageCode;

  double get fontScaleFactor {
    switch (fontSizeChoice) {
      case 'normal':
        return 1.0;
      case 'big':
        return 1.15;
      case 'small':
      default:
        return 0.85;
    }
  }

  String translate(String key) {
    return AppStrings.get(key, locale.languageCode);
  }

  /// Returns the asset path for a given piece code (e.g. 'WK', 'BP') based on selected pieceTheme
  String getPieceAssetPath(String pieceCode) {
    return AppImageHelper.getPieceAssetPath(pieceTheme, pieceCode);
  }

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? fontSizeChoice,
    bool? isPhysicalMode,
    String? pieceTheme,
    bool? isSoundEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      fontSizeChoice: fontSizeChoice ?? this.fontSizeChoice,
      isPhysicalMode: isPhysicalMode ?? this.isPhysicalMode,
      pieceTheme: pieceTheme ?? this.pieceTheme,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        locale,
        fontSizeChoice,
        isPhysicalMode,
        pieceTheme,
        isSoundEnabled,
      ];
}
