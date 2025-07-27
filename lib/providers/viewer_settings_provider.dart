import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final viewerSettingsProvider = StateNotifierProvider<ViewerSettingsNotifier, ViewerSettings>((ref) {
  return ViewerSettingsNotifier();
});

class ViewerSettings {
  final bool reverseSwipeDirection;

  ViewerSettings({
    this.reverseSwipeDirection = false,
  });

  ViewerSettings copyWith({
    bool? reverseSwipeDirection,
  }) {
    return ViewerSettings(
      reverseSwipeDirection: reverseSwipeDirection ?? this.reverseSwipeDirection,
    );
  }
}

class ViewerSettingsNotifier extends StateNotifier<ViewerSettings> {
  ViewerSettingsNotifier() : super(ViewerSettings()) {
    _loadSettings();
  }

  static const String _reverseSwipeKey = 'reverse_swipe_direction';

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reverseSwipe = prefs.getBool(_reverseSwipeKey) ?? false;
      
      state = state.copyWith(reverseSwipeDirection: reverseSwipe);
    } catch (e) {
      // SharedPreferencesの読み込みに失敗した場合はデフォルト値を使用
      print('設定の読み込みに失敗しました: $e');
    }
  }

  Future<void> toggleSwipeDirection() async {
    final newValue = !state.reverseSwipeDirection;
    state = state.copyWith(reverseSwipeDirection: newValue);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reverseSwipeKey, newValue);
    } catch (e) {
      print('設定の保存に失敗しました: $e');
    }
  }

  Future<void> setReverseSwipeDirection(bool reverse) async {
    state = state.copyWith(reverseSwipeDirection: reverse);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reverseSwipeKey, reverse);
    } catch (e) {
      print('設定の保存に失敗しました: $e');
    }
  }
}