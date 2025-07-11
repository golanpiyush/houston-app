// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:houston/widgets/update_wrapper.dart';
import 'providers/settings_provider.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: 'Music Player',
          theme: _getTheme(settings.themeMode, lightDynamic, false),
          darkTheme: _getTheme(settings.themeMode, darkDynamic, true),
          themeMode: _getThemeMode(settings.themeMode),
          home: const UpdateWrapper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  ThemeData _getTheme(
    String themeMode,
    ColorScheme? dynamicScheme,
    bool isDark,
  ) {
    switch (themeMode) {
      case 'light':
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        );
      case 'dark':
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        );
      case 'material':
        return ThemeData(
          colorScheme:
              dynamicScheme ??
              ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: isDark ? Brightness.dark : Brightness.light,
              ),
          useMaterial3: true,
        );
      case 'amoled':
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ).copyWith(background: Colors.black, surface: Colors.black),
          useMaterial3: true,
        );
      default:
        return ThemeData(useMaterial3: true);
    }
  }

  ThemeMode _getThemeMode(String themeMode) {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
      case 'amoled':
        return ThemeMode.dark;
      case 'material':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }
}
