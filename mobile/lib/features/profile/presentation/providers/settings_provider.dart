// ============================================================
// settings_provider.dart
// Erişilebilirlik ayarlarının durumu ve kalıcı saklanması
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _minTextScale = 1.0;
const double _maxTextScale = 1.5;

/// Erişilebilirlik ekranındaki ayarların durumunu temsil eder.
class SettingsState {
  final double textScale;
  final bool isHighContrast;
  final bool isVoiceGuidanceEnabled;

  const SettingsState({
    this.textScale = 1.0,
    this.isHighContrast = false,
    this.isVoiceGuidanceEnabled = false,
  }) : assert(
         textScale >= _minTextScale && textScale <= _maxTextScale,
         'textScale 1.0 ile 1.5 arasında olmalıdır.',
       );

  SettingsState copyWith({
    double? textScale,
    bool? isHighContrast,
    bool? isVoiceGuidanceEnabled,
  }) {
    return SettingsState(
      textScale: textScale ?? this.textScale,
      isHighContrast: isHighContrast ?? this.isHighContrast,
      isVoiceGuidanceEnabled:
          isVoiceGuidanceEnabled ?? this.isVoiceGuidanceEnabled,
    );
  }
}

/// Ayarları SharedPreferences üzerinden yükler, günceller ve kaydeder.
class SettingsController extends StateNotifier<SettingsState> {
  SettingsController() : super(const SettingsState()) {
    _loadSettings();
  }

  static const String _textScaleKey = 'accessibility_text_scale';
  static const String _highContrastKey = 'accessibility_high_contrast';
  static const String _voiceGuidanceKey = 'accessibility_voice_guidance';

  Future<void> _loadSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;

      final savedTextScale = preferences.getDouble(_textScaleKey);
      final savedHighContrast = preferences.getBool(_highContrastKey);
      final savedVoiceGuidance = preferences.getBool(_voiceGuidanceKey);

      state = SettingsState(
        textScale:
            (savedTextScale ?? _minTextScale)
                .clamp(_minTextScale, _maxTextScale)
                .toDouble(),
        isHighContrast: savedHighContrast ?? false,
        isVoiceGuidanceEnabled: savedVoiceGuidance ?? false,
      );
    } catch (_) {
      // SharedPreferences kullanılamıyorsa varsayılan ayarlarla devam et.
    }
  }

  Future<void> setTextScale(double value) async {
    final textScale = value.clamp(_minTextScale, _maxTextScale).toDouble();

    state = state.copyWith(textScale: textScale);
    await _saveDouble(_textScaleKey, textScale);
  }

  Future<void> setHighContrast(bool value) async {
    state = state.copyWith(isHighContrast: value);
    await _saveBool(_highContrastKey, value);
  }

  Future<void> setVoiceGuidanceEnabled(bool value) async {
    state = state.copyWith(isVoiceGuidanceEnabled: value);
    await _saveBool(_voiceGuidanceKey, value);
  }

  Future<void> _saveDouble(String key, double value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(key, value);
    } catch (_) {
      // Ayar bu oturumda uygulanmaya devam eder.
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, value);
    } catch (_) {
      // Ayar bu oturumda uygulanmaya devam eder.
    }
  }
}

/// Uygulama genelindeki erişilebilirlik ayarlarını yönetir.
final settingsProvider =
    StateNotifierProvider<SettingsController, SettingsState>(
      (ref) => SettingsController(),
    );
