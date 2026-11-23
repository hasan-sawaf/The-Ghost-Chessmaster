import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSavedSettingsEvent extends SettingsEvent {}

class ToggleThemeEvent extends SettingsEvent {}

class ToggleLanguageEvent extends SettingsEvent {}

class SetThemeModeEvent extends SettingsEvent {
  final ThemeMode themeMode;
  const SetThemeModeEvent(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class SetLocaleEvent extends SettingsEvent {
  final Locale locale;
  const SetLocaleEvent(this.locale);

  @override
  List<Object?> get props => [locale];
}

class SetFontSizeChoiceEvent extends SettingsEvent {
  final String fontSizeChoice; // 'small', 'normal', 'big'
  const SetFontSizeChoiceEvent(this.fontSizeChoice);

  @override
  List<Object?> get props => [fontSizeChoice];
}

class SetGameplayModeEvent extends SettingsEvent {
  final bool isPhysicalMode; // true = physical board mode, false = local mode
  const SetGameplayModeEvent(this.isPhysicalMode);

  @override
  List<Object?> get props => [isPhysicalMode];
}

class SetPieceThemeEvent extends SettingsEvent {
  final String pieceTheme; // e.g. 'Standered', '3d_staunton', 'neon'
  const SetPieceThemeEvent(this.pieceTheme);

  @override
  List<Object?> get props => [pieceTheme];
}

class ToggleSoundEffectsEvent extends SettingsEvent {
  final bool? isEnabled;
  const ToggleSoundEffectsEvent([this.isEnabled]);

  @override
  List<Object?> get props => [isEnabled];
}
