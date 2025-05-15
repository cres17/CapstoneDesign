import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:capstone_porj/services/clova_speech_service.dart';
import 'package:capstone_porj/services/openai_service.dart';
import 'package:capstone_porj/services/analysis_storage_service.dart';
import 'package:capstone_porj/models/call_result_data.dart';
import 'package:http/http.dart' as http;
import 'package:capstone_porj/services/prediction_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisScreen extends StatefulWidget {
  final String audioFilePath;
  final String partnerName;

  const AnalysisScreen({
    Key? key,
    required this.audioFilePath,
    required this.partnerName,
  }) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final clova = ClovaSpeechService();
      final openai = OpenAIService();
      final analysisStorage = AnalysisStorageService();

      // 1. 음성 -> 텍스트
      final file = File(widget.audioFilePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = '녹음 파일이 존재하지 않습니다.';
        });
        return;
      }
      final fileLength = await file.length();
      print('[AnalysisScreen] 녹음 파일 크기: $fileLength bytes');
      if (fileLength < 1000) {
        setState(() {
          _errorMessage = '녹음 파일이 너무 짧거나 비어 있습니다.';
        });
        return;
      }
      final text = await clova.requestSpeechToText(widget.audioFilePath);
      if (text == null || text.trim().isEmpty) {
        setState(() {
          _errorMessage = '음성 인식에 실패했습니다. (결과 없음)';
        });
        return;
      }
      CallResultData.saveCallResult(text);

      // 2. OpenAI 분석
      final analysisResult = await openai.analyzeConversation(text);
      if (analysisResult == null) {
        setState(() {
          _errorMessage = '대화 분석에 실패했습니다.';
        });
        return;
      }

      // 3. 분석 결과 저장 (summary를 Map<String, Map<String, Map<String, String>>> 형태로 저장)
      final analysis = {
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'partner': widget.partnerName,
        'conversation': text,
        'summary': analysisResult,
      };
      await analysisStorage.saveAnalysis(analysis);

      // 4. 매칭률 예측 서버 호출
      final prediction = await _requestPrediction(text, widget.partnerName);
      if (prediction != null) {
        await PredictionStorageService.savePrediction(prediction);
      }

      // 5. 메인화면으로 이동
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/main', (route) => false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '분석 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 매칭률 예측 서버 호출 함수
  Future<Map<String, dynamic>?> _requestPrediction(
    String script,
    String partnerName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      // 유저 성별 정보는 예시로 'male'로 고정, 실제로는 SharedPreferences 등에서 불러와야 함
      final gender = prefs.getString('gender') ?? 'male';

      final response = await http.post(
        Uri.parse('http://192.168.1.50:5001/analyze'), // 실제 서버 IP로 변경
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'input_text': script, 'gender': gender}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 예측 서버에서 받은 호감도 예측 확률(score) 로그 출력
        print('[예측서버 응답] score: ${data['score']}');
        return {
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'partner': partnerName,
          'result': '${((data['score'] ?? 0.0) * 100).toStringAsFixed(0)}%',
          'comment': 'AI가 분석한 매칭률입니다.',
          'compatibility': [], // 추후 확장 가능
        };
      }
    } catch (e) {
      print('매칭률 예측 오류: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child:
            _errorMessage == null
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(color: Colors.purple),
                    SizedBox(height: 30),
                    Text(
                      '대화 분석중입니다...',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ],
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 60),
                    const SizedBox(height: 20),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _analyze();
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
      ),
    );
  }
}
