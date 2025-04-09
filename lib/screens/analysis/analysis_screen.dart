import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 대화 분석 예시 데이터
    final List<Map<String, dynamic>> analysisData = [
      {
        'date': '2023-05-15',
        'partner': '김민수',
        'keywords': ['여행', '취미', '음식'],
        'summary': '취미와 여행 경험에 관한 대화를 나눴습니다. 상대방은 해외여행을 좋아하고 요리에 관심이 많았습니다.',
        'emotions': '긍정적, 활기찬',
      },
      {
        'date': '2023-05-10',
        'partner': '이지은',
        'keywords': ['영화', '음악', '독서'],
        'summary': '문화생활에 관한 대화를 나눴습니다. 상대방은 클래식 음악을 좋아하고 스릴러 영화를 선호합니다.',
        'emotions': '차분함, 지적인',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('대화 분석'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '최근 대화 분석',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 분석 카드 리스트
            Expanded(
              child: ListView.builder(
                itemCount: analysisData.length,
                itemBuilder: (context, index) {
                  final analysis = analysisData[index];
                  return AnalysisCard(
                    date: analysis['date'],
                    partner: analysis['partner'],
                    keywords: List<String>.from(analysis['keywords']),
                    summary: analysis['summary'],
                    emotion: analysis['emotions'],
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
  final List<String> keywords;
  final String summary;
  final String emotion;

  const AnalysisCard({
    Key? key,
    required this.date,
    required this.partner,
    required this.keywords,
    required this.summary,
    required this.emotion,
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
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$partner와의 대화 분석',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('날짜: $date'),
                      const SizedBox(height: 16),
                      const Text(
                        '키워드:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Wrap(
                        spacing: 8,
                        children:
                            keywords
                                .map(
                                  (keyword) => Chip(
                                    label: Text(keyword),
                                    backgroundColor: AppColors.primary
                                        .withOpacity(0.2),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '감정 분석:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(emotion),
                      const SizedBox(height: 16),
                      const Text(
                        '요약:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(summary),
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
