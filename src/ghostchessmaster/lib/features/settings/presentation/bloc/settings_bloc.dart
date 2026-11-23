import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  static const String _prefThemeKey = 'pref_theme_mode';
  static const String _prefLangKey = 'pref_language_code';
  static const String _prefFontSizeKey = 'pref_font_size_choice';
  static const String _prefGameplayModeKey = 'pref_gameplay_mode';
  static const String _prefPieceThemeKey = 'pref_piece_theme';
  static const String _prefSoundKey = 'pref_sound_enabled';

  SettingsBloc() : super(const SettingsState()) {
    on<LoadSavedSettingsEvent>(_onLoadSavedSettings);
    on<ToggleThemeEvent>(_onToggleTheme);
    on<ToggleLanguageEvent>(_onToggleLanguage);
    on<SetThemeModeEvent>(_onSetThemeMode);
    on<SetLocaleEvent>(_onSetLocale);
    on<SetFontSizeChoiceEvent>(_onSetFontSizeChoice);
    on<SetGameplayModeEvent>(_onSetGameplayMode);
    on<SetPieceThemeEvent>(_onSetPieceTheme);
    on<ToggleSoundEffectsEvent>(_onToggleSoundEffects);

    // Auto-load saved preferences on creation
    add(LoadSavedSettingsEvent());
  }

  Future<void> _onLoadSavedSettings(
    LoadSavedSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString(_prefThemeKey) ?? 'dark';
      final langStr = prefs.getString(_prefLangKey) ?? 'en';
      final fontStr = prefs.getString(_prefFontSizeKey) ?? 'small';
      final isPhysical = prefs.getBool(_prefGameplayModeKey) ?? true;
      final pieceThemeStr = prefs.getString(_prefPieceThemeKey) ?? 'Standered';
      final isSound = prefs.getBool(_prefSoundKey) ?? true;

      emit(state.copyWith(
        themeMode: themeStr == 'light' ? ThemeMode.light : ThemeMode.dark,
        locale: Locale(langStr),
        fontSizeChoice: fontStr,
        isPhysicalMode: isPhysical,
        pieceTheme: pieceThemeStr,
        isSoundEnabled: isSound,
      ));
    } catch (e) {
      debugPrint('[SETTINGS_BLOC_ERROR] Error loading SharedPreferences: $e');
    }
  }

  Future<void> _onToggleSoundEffects(
    ToggleSoundEffectsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final newValue = event.isEnabled ?? !state.isSoundEnabled;
    emit(state.copyWith(isSoundEnabled: newValue));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefSoundKey, newValue);
    } catch (e) {
      debugPrint('[SETTINGS_BLOC_ERROR] Error saving _prefSoundKey: $e');
    }
  }

  Future<void> _onSetPieceTheme(
    SetPieceThemeEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(pieceTheme: event.pieceTheme));
    _savePreference(_prefPieceThemeKey, event.pieceTheme);
  }

  Future<void> _onToggleTheme(
    ToggleThemeEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final newTheme = state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    emit(state.copyWith(themeMode: newTheme));
    _savePreference(_prefThemeKey, newTheme == ThemeMode.light ? 'light' : 'dark');
  }

  Future<void> _onToggleLanguage(
    ToggleLanguageEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final newLocale = state.locale.languageCode == 'en' ? const Locale('ar') : const Locale('en');
    emit(state.copyWith(locale: newLocale));
    _savePreference(_prefLangKey, newLocale.languageCode);
  }

  Future<void> _onSetThemeMode(
    SetThemeModeEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(themeMode: event.themeMode));
    _savePreference(_prefThemeKey, event.themeMode == ThemeMode.light ? 'light' : 'dark');
  }

  Future<void> _onSetLocale(
    SetLocaleEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(locale: event.locale));
    _savePreference(_prefLangKey, event.locale.languageCode);
  }

  Future<void> _onSetFontSizeChoice(
    SetFontSizeChoiceEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(fontSizeChoice: event.fontSizeChoice));
    _savePreference(_prefFontSizeKey, event.fontSizeChoice);
  }

  Future<void> _onSetGameplayMode(
    SetGameplayModeEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isPhysicalMode: event.isPhysicalMode));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefGameplayModeKey, event.isPhysicalMode);
    } catch (e) {
      debugPrint('[SETTINGS_BLOC_ERROR] Error saving _prefGameplayModeKey: $e');
    }
  }

  Future<void> _savePreference(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('[SETTINGS_BLOC_ERROR] Error saving SharedPreferences for $key: $e');
    }
  }
}
