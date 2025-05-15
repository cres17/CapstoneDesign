import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PredictionStorageService {
  static const _key = 'prediction_results';

  // 저장
  static Future<void> savePrediction(Map<String, dynamic> prediction) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    list.insert(0, jsonEncode(prediction)); // 최신순 정렬
    await prefs.setStringList(_key, list);
  }

  // 불러오기
  static Future<List<Map<String, dynamic>>> loadPredictions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    return list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  // 전체 삭제 (테스트용)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
