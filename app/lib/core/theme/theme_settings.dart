import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../storage/key_value_store.dart';
import 'app_theme.dart';

/// Appearance settings from P20 / T03. `null` fields follow the system.
@immutable
class ThemeSettings {
  const ThemeSettings({this.mode = ThemeMode.system, this.contrast, this.textScale, this.reduceMotion = false, this.locale});

  final ThemeMode mode;

  /// `null` follows the OS high-contrast setting.
  final AppContrast? contrast;

  /// 0.85–2.0 in 0.05 steps; `null` follows the OS text size.
  final double? textScale;
  final bool reduceMotion;

  /// `null` follows the device language.
  final Locale? locale;

  static const minTextScale = 0.85;
  static const maxTextScale = 2.0;

  ThemeSettings copyWith({
    ThemeMode? mode,
    AppContrast? Function()? contrast,
    double? Function()? textScale,
    bool? reduceMotion,
    Locale? Function()? locale,
  }) => ThemeSettings(
    mode: mode ?? this.mode,
    contrast: contrast != null ? contrast() : this.contrast,
    textScale: textScale != null ? textScale() : this.textScale,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    locale: locale != null ? locale() : this.locale,
  );

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'contrast': contrast?.name,
    'textScale': textScale,
    'reduceMotion': reduceMotion,
    'locale': locale?.languageCode,
  };

  factory ThemeSettings.fromJson(Map<String, Object?> json) => ThemeSettings(
    mode: ThemeMode.values.asNameMap()[json['mode']] ?? ThemeMode.system,
    contrast: AppContrast.values.asNameMap()[json['contrast']],
    textScale: (json['textScale'] as num?)?.toDouble().clamp(minTextScale, maxTextScale),
    reduceMotion: json['reduceMotion'] == true,
    locale: json['locale'] is String ? Locale(json['locale']! as String) : null,
  );

  @override
  bool operator ==(Object other) => other is ThemeSettings && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;
}

class ThemeSettingsController extends Notifier<ThemeSettings> {
  static const _key = 'theme_settings';

  @override
  ThemeSettings build() {
    final raw = ref.watch(keyValueStoreProvider).getString(_key);
    if (raw == null) return const ThemeSettings();
    try {
      return ThemeSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return const ThemeSettings();
    }
  }

  void update(ThemeSettings Function(ThemeSettings current) change) {
    state = change(state);
    ref.read(keyValueStoreProvider).setString(_key, jsonEncode(state.toJson()));
  }
}

final themeSettingsProvider = NotifierProvider<ThemeSettingsController, ThemeSettings>(ThemeSettingsController.new);
