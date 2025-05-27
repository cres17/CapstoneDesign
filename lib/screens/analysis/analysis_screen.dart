import 'package:capstone_porj/screens/analysis/analysis_detail_screen.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/analysis_storage_service.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:capstone_porj/providers/analysis_prediction_provider.dart';
import 'package:capstone_porj/main.dart'; // routeObserver import 필요

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with RouteAware {
  List<Map<String, dynamic>> _analysisData = [];
  Map<String, String> _userIdToNickname = {}; // userId → 닉네임 매핑
  Timer? _refreshTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAnalysis();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    // 페이지가 화면에 나타날 때 타이머 시작
    _startTimer();
  }

  @override
  void didPopNext() {
    // 다른 페이지에서 돌아왔을 때 타이머 시작
    _startTimer();
  }

  @override
  void didPop() {
    // 페이지에서 나갈 때 타이머 중지
    _refreshTimer?.cancel();
  }

  @override
  void didPushNext() {
    // 다른 페이지로 이동할 때 타이머 중지
    _refreshTimer?.cancel();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadAnalysis(),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
    // 타이머는 RouteAware에서 관리
  }

  Future<void> _loadAnalysis() async {
    final storage = AnalysisStorageService();
    final data = await storage.loadAnalyses();

    // userId 목록 추출
    final userIds = data.map((e) => e['partner'].toString()).toSet();
    final nicknameMap = await _fetchNicknames(userIds);

    setState(() {
      _analysisData = data;
      _userIdToNickname = nicknameMap;
    });
  }

  Future<Map<String, String>> _fetchNicknames(Set<String> userIds) async {
    Map<String, String> map = {};
    for (final userId in userIds) {
      try {
        final res = await http.get(
          Uri.parse('${AppConfig.serverUrl}/users/$userId'),
        );
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body);
          map[userId] = json['nickname'] ?? userId;
        } else {
          map[userId] = userId;
        }
      } catch (_) {
        map[userId] = userId;
      }
    }
    return map;
  }

  // 분석 데이터 전체 삭제 함수
  Future<void> _clearAnalysisData() async {
    await AnalysisStorageService().clear();
    // Provider로 UI 갱신 알림
    Provider.of<AnalysisPredictionProvider>(
      context,
      listen: false,
    ).notifyUpdate();
    // 또는 _loadAnalysis() 직접 호출해도 됨
    // await _loadAnalysis();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('대화 분석'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '분석 데이터 전체 삭제',
            onPressed: _clearAnalysisData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _analysisData.isEmpty
                ? const Center(child: Text('분석된 대화가 없습니다.'))
                : Column(
                  children: [
                    if (_analysisData.any((a) => a['isProcessing'] == true))
                      Card(
                        color: Colors.grey[200],
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: const CircularProgressIndicator(),
                          title: const Text(
                            '최근 대화 분석중...',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('분석이 완료되면 자동으로 결과가 표시됩니다.'),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount:
                            _analysisData
                                .where((a) => a['isProcessing'] != true)
                                .length,
                        itemBuilder: (context, index) {
                          final filtered =
                              _analysisData
                                  .where((a) => a['isProcessing'] != true)
                                  .toList();
                          final analysis = filtered[index];
                          final partnerId = analysis['partner'].toString();
                          final partnerNickname =
                              _userIdToNickname[partnerId] ?? partnerId;
                          // summary가 Map<String, Map<String, Map<String, String>>> 형태로 저장되어 있다고 가정
                          final summary = analysis['summary'];
                          Map<String, Map<String, Map<String, String>>>
                          summaryMap = {};
                          if (summary is Map) {
                            summaryMap = summary.map(
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
                            partner: partnerNickname,
                            date: analysis['date'] ?? '',
                            summaryMap: summaryMap,
                            conversation: analysis['conversation'] ?? '',
                          );
                        },
                      ),
                    ),
                  ],
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

  String get formattedDate {
    try {
      final dt = DateTime.parse(date).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return date;
    }
  }

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
        subtitle: Text(formattedDate),
        trailing: TextButton(
          child: const Text('자세히 보기 >'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => AnalysisDetailScreen(
                      partner: partner,
                      date: formattedDate,
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
