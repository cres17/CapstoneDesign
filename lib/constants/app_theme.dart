import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: AppColors.lightGrey,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    textTheme: const TextTheme(
      displayLarge: AppTextStyles.headline1,
      displayMedium: AppTextStyles.headline2,
      titleMedium: AppTextStyles.subtitle1,
      bodyLarge: AppTextStyles.body1,
      bodyMedium: AppTextStyles.body2,
      labelLarge: AppTextStyles.button,
      bodySmall: AppTextStyles.caption,
    ),
  );
}
