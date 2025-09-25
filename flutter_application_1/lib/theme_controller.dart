import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;
  void toggle(bool v) {
    _isDark = v;
    notifyListeners();
  }
}

class ThemeControllerProvider extends InheritedNotifier<ThemeController> {
  const ThemeControllerProvider({
    super.key,
    required ThemeController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ThemeControllerProvider>();
    assert(provider != null, 'ThemeControllerProvider not found in context');
    return provider!.notifier!;
  }
}
