import 'package:flutter/material.dart';

class AnalysisDetailScreen extends StatelessWidget {
  final String partner;
  final String date;
  final Map<String, Map<String, Map<String, String>>> summaryMap;
  final String conversation;

  const AnalysisDetailScreen({
    Key? key,
    required this.partner,
    required this.date,
    required this.summaryMap,
    required this.conversation,
  }) : super(key: key);

  // 항목별 이모지 매핑
  String _getEmoji(String key) {
    switch (key) {
      case '주제탐색':
        return '🧭';
      case '자아노출':
        return '🪞';
      case '경청협력':
        return '👂🤝';
      default:
        return '💬';
    }
  }

  // 항목별 색상 매핑
  Color _getTitleColor(String key) {
    switch (key) {
      case '주제탐색':
        return Colors.indigo;
      case '자아노출':
        return Colors.deepPurple;
      case '경청협력':
        return Colors.teal;
      default:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$partner와의 대화 분석'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: ListView(
          children: [
            Text(
              '날짜: $date',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 18),
            ...summaryMap.entries.map(
              (e) => Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 항목명 + 이모지
                      Row(
                        children: [
                          Text(
                            _getEmoji(e.key),
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            e.key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: _getTitleColor(e.key),
                              fontFamily: 'Pretendard', // 원하는 폰트로 변경
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...['A', 'B'].map(
                        (speaker) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '발화자 $speaker',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '잘 드러난 부분',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              e.value[speaker]?['잘 드러난 부분'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '아쉬운 부분',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange[700],
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              e.value[speaker]?['아쉬운 부분'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFB71C1C),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 36, thickness: 1.2),
            const Text(
              '대화 전체 내용',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.blueGrey,
                fontFamily: 'Pretendard',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                conversation,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontFamily: 'Pretendard',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
