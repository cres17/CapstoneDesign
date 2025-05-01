import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/analysis_storage_service.dart';

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
                    return AnalysisCard(
                      date: analysis['date'] ?? '',
                      partner: analysis['partner'] ?? '',
                      keywords: [], // 키워드 추출 로직 필요시 추가
                      summary: analysis['summary'] ?? '',
                      emotion: '', // 감정 분석 추가시
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
  final List<String> keywords;
  final String summary;
  final String emotion;
  final String conversation;

  const AnalysisCard({
    Key? key,
    required this.date,
    required this.partner,
    required this.keywords,
    required this.summary,
    required this.emotion,
    required this.conversation,
  }) : super(key: key);

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
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '요약:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(summary),
                        const SizedBox(height: 16),
                        const Text(
                          '대화 내용:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(conversation),
                        const SizedBox(height: 20),
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
              ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    partner,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children:
                    keywords
                        .map(
                          (keyword) => Chip(
                            label: Text(
                              keyword,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: AppColors.primary.withOpacity(0.2),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 10),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '더보기 >',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
