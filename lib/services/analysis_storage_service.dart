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

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }
}
