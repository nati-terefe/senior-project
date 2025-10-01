import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'routes.dart';
import 'theme_controller.dart';
//Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const EthSLApp());
}

class EthSLApp extends StatefulWidget {
  const EthSLApp({super.key});
  @override
  State<EthSLApp> createState() => _EthSLAppState();
}

class _EthSLAppState extends State<EthSLApp> {
  final ThemeController _theme = ThemeController();

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0E7490);

    final light = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      textTheme: GoogleFonts.interTextTheme(),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
    );

    final dark = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white,
      ),
    );

    return ThemeControllerProvider(
      controller: _theme,
      child: AnimatedBuilder(
        animation: _theme,
        builder: (_, __) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'EthSL',
          theme: light,
          darkTheme: dark,
          themeMode: _theme.isDark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: router,
        ),
      ),
    );
  }
}
