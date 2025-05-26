import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AnalysisStorageService {
  static const String _fileName = 'analysis_results.json';

  // 분석 결과 저장
  Future<void> saveAnalysis(Map<String, dynamic> analysis) async {
    final file = await _getFile();
    List<dynamic> list = [];
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        list = jsonDecode(content);
      }
    }
    // 동일 partner의 기존 분석 중 데이터 제거
    list.removeWhere(
      (item) =>
          item is Map &&
          item['partner'] == analysis['partner'] &&
          (item['isProcessing'] ?? false),
    );
    list.insert(0, analysis); // 최신순
    await file.writeAsString(jsonEncode(list));
  }

  // 분석 결과 불러오기
  Future<List<Map<String, dynamic>>> loadAnalyses() async {
    final file = await _getFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        final list = jsonDecode(content) as List;
        return list.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  // 분석 중 데이터 추가 함수
  Future<void> addProcessingAnalysis(String partner, String date) async {
    await saveAnalysis({
      'date': date,
      'partner': partner,
      'isProcessing': true,
    });
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }
}
