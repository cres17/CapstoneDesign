import 'package:capstone_porj/screens/analysis/analysis_detail_screen.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/analysis_storage_service.dart';
import 'dart:convert';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  List<Map<String, dynamic>> _analysisData = [];

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    final storage = AnalysisStorageService();
    final data = await storage.loadAnalyses();
    setState(() {
      _analysisData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('대화 분석'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _analysisData.isEmpty
                ? const Center(child: Text('분석된 대화가 없습니다.'))
                : ListView.builder(
                  itemCount: _analysisData.length,
                  itemBuilder: (context, index) {
                    final analysis = _analysisData[index];
                    // summary가 Map<String, Map<String, Map<String, String>>> 형태로 저장되어 있다고 가정
                    final summary = analysis['summary'];
                    Map<String, Map<String, Map<String, String>>> summaryMap =
                        {};
                    if (summary is Map) {
                      summaryMap = summary.map(
                        (k, v) => MapEntry(
                          k.toString(),
                          (v as Map).map(
                            (kk, vv) => MapEntry(
                              kk.toString(),
                              (vv as Map).map(
                                (kkk, vvv) =>
                                    MapEntry(kkk.toString(), vvv.toString()),
                              ),
                            ),
                          ),
                        ),
                      );
                    } else if (summary is String) {
                      try {
                        final parsed = jsonDecode(summary);
                        if (parsed is Map) {
                          summaryMap = parsed.map(
                            (k, v) => MapEntry(
                              k.toString(),
                              (v as Map).map(
                                (kk, vv) => MapEntry(
                                  kk.toString(),
                                  (vv as Map).map(
                                    (kkk, vvv) => MapEntry(
                                      kkk.toString(),
                                      vvv.toString(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      } catch (_) {}
                    }
                    return AnalysisCard(
                      date: analysis['date'] ?? '',
                      partner: analysis['partner'] ?? '',
                      summaryMap: summaryMap,
                      conversation: analysis['conversation'] ?? '',
                    );
                  },
                ),
      ),
    );
  }
}

class AnalysisCard extends StatelessWidget {
  final String date;
  final String partner;
  final Map<String, Map<String, Map<String, String>>> summaryMap;
  final String conversation;

  const AnalysisCard({
    Key? key,
    required this.date,
    required this.partner,
    required this.summaryMap,
    required this.conversation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        title: Text(
          partner,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(date),
        trailing: TextButton(
          child: const Text('자세히 보기 >'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => AnalysisDetailScreen(
                      partner: partner,
                      date: date,
                      summaryMap: summaryMap,
                      conversation: conversation,
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}
