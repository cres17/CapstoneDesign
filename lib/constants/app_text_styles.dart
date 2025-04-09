import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.text,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.text,
  );

  static const TextStyle subtitle1 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  static const TextStyle body1 = TextStyle(fontSize: 16, color: AppColors.text);

  static const TextStyle body2 = TextStyle(fontSize: 14, color: AppColors.text);

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.darkGrey,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );
}
