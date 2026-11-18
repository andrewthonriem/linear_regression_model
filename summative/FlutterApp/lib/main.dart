// Entry point: starts the app and defines its colours and theme.
import 'package:flutter/material.dart';

import 'prediction_page.dart';

void main() => runApp(const MyApp());

/// App colours (palette: #11281E, #209261, #E23030, #FE9F05).
class AppColors {
  static const Color forest = Color(0xFF11281E); // header, headings
  static const Color emerald = Color(0xFF209261); // main colour, high access
  static const Color crimson = Color(0xFFE23030); // errors, low access
  static const Color amber = Color(0xFFFE9F05); // accent, moderate access

  static const Color background = Color(0xFFF1F6F3);
  static const Color border = Color(0xFFD6E4DC);
  static const Color textMuted = Color(0xFF5B6F65);
  static const Color errorBackground = Color(0xFFFDEDED);
  static const Color errorText = Color(0xFF8E1C1C);

  /// Colour for a predicted internet-user share: red, amber, then green.
  static Color forLevel(double percent) {
    if (percent < 20) return crimson;
    if (percent < 50) return amber;
    return emerald;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return MaterialApp(
      title: 'Internet Access Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.emerald,
          primary: AppColors.emerald,
          secondary: AppColors.amber,
          error: AppColors.crimson,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: fieldBorder.copyWith(
            borderSide: const BorderSide(color: AppColors.emerald, width: 2),
          ),
        ),
      ),
      home: const PredictionPage(),
    );
  }
}
