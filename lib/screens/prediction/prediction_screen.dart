import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/prediction_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:capstone_porj/config/app_config.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:capstone_porj/providers/analysis_prediction_provider.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({Key? key}) : super(key: key);

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  List<Map<String, dynamic>> _predictionData = [];
  bool _isLoading = true;
  Map<String, String> _userIdToNickname = {}; // userId → 닉네임 매핑
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPredictions();
    // 3초마다 새로고침
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadPredictions(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPredictions() async {
    final data = await PredictionStorageService.loadPredictions();
    final userIds = data.map((e) => e['partner'].toString()).toSet();
    final nicknameMap = await _fetchNicknames(userIds);

    setState(() {
      _predictionData = data;
      _userIdToNickname = nicknameMap;
      _isLoading = false;
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

  // 예측 데이터 전체 삭제 함수
  Future<void> _clearPredictionData() async {
    await PredictionStorageService.clear();
    Provider.of<AnalysisPredictionProvider>(
      context,
      listen: false,
    ).notifyUpdate();
    // 또는 _loadPredictions() 직접 호출해도 됨
    // await _loadPredictions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('호감도 예측'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '예측 데이터 전체 삭제',
            onPressed: _clearPredictionData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _predictionData.isEmpty
                ? const Center(child: Text('예측 결과가 없습니다.'))
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 예측중 카드
                    if (_predictionData.any((a) => a['isProcessing'] == true))
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
                            '최근 대화 예측중...',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('예측이 완료되면 자동으로 결과가 표시됩니다.'),
                        ),
                      ),
                    // 기존 예측 카드 리스트
                    Expanded(
                      child: ListView.builder(
                        itemCount:
                            _predictionData
                                .where((a) => a['isProcessing'] != true)
                                .length,
                        itemBuilder: (context, index) {
                          final filtered =
                              _predictionData
                                  .where((a) => a['isProcessing'] != true)
                                  .toList();
                          final prediction = filtered[index];
                          final partnerId = prediction['partner'].toString();
                          final partnerNickname =
                              _userIdToNickname[partnerId] ?? partnerId;
                          return PredictionCard(
                            partner: partnerNickname,
                            result: prediction['result'],
                            date: prediction['date'],
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

class PredictionCard extends StatelessWidget {
  final String date;
  final String partner;
  final String result;

  const PredictionCard({
    Key? key,
    required this.date,
    required this.partner,
    required this.result,
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
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder:
              (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$partner님과의 호감도 예측',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '날짜: $formattedDate',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '호감 지수',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$result',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          child: const Text('닫기'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$result',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '소개팅 호감 지수',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
