import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  bool _isDark = false;
  ThemeMode _mode = ThemeMode.light;
  String _language = 'en';

  bool get isDark => _isDark;
  ThemeMode get mode => _mode;
  String get language => _language;

  /// Set dark mode explicitly
  void setDark(bool value) {
    _isDark = value;
    _mode = _isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// Toggle dark mode (no parameter)
  void toggleDark() => setDark(!isDark);

  /// Toggle dark mode with a bool (for Switch/Checkbox in Settings)
  void toggle(bool value) => setDark(value);

  /// Set theme mode directly (system, light, dark)
  void setMode(ThemeMode newMode) {
    _mode = newMode;
    _isDark = (newMode == ThemeMode.dark)
        ? true
        : (newMode == ThemeMode.light)
            ? false
            : _isDark; // keep last state for system
    notifyListeners();
  }

  /// Set app language
  void setLanguage(String code) {
    if (code == _language) return;
    _language = code;
    notifyListeners();
  }
}

/// Provider for ThemeController
class ThemeControllerProvider extends InheritedNotifier<ThemeController> {
  const ThemeControllerProvider({
    super.key,
    required ThemeController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ThemeControllerProvider>();
    assert(provider != null, 'No ThemeControllerProvider found in context');
    return provider!.notifier!;
  }
}
