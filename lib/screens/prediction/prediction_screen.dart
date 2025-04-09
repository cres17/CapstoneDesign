import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class PredictionScreen extends StatelessWidget {
  const PredictionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 예측 결과 예시 데이터
    final List<Map<String, dynamic>> predictionData = [
      {
        'date': '2023-05-15',
        'partner': '김민수',
        'result': '78%',
        'comment':
            '대화 내용으로 보아 서로 취향과 관심사가 비슷하여 높은 매칭률을 보입니다. 데이트를 진행하면 좋은 결과가 있을 것으로 예상됩니다.',
        'compatibility': ['취미 활동', '여행 스타일'],
      },
      {
        'date': '2023-05-10',
        'partner': '이지은',
        'result': '65%',
        'comment':
            '문화적 관심사는 유사하지만 생활 방식과 가치관에서 약간의 차이가 있습니다. 추가적인 대화를 통해 더 알아가는 것이 좋겠습니다.',
        'compatibility': ['문화 취향'],
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('매칭 예측'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '매칭 예측 결과',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 예측 카드 리스트
            Expanded(
              child: ListView.builder(
                itemCount: predictionData.length,
                itemBuilder: (context, index) {
                  final prediction = predictionData[index];
                  return PredictionCard(
                    date: prediction['date'],
                    partner: prediction['partner'],
                    result: prediction['result'],
                    comment: prediction['comment'],
                    compatibility: List<String>.from(
                      prediction['compatibility'],
                    ),
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
  final String comment;
  final List<String> compatibility;

  const PredictionCard({
    Key? key,
    required this.date,
    required this.partner,
    required this.result,
    required this.comment,
    required this.compatibility,
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
                        '$partner와의 매칭 예측',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('날짜: $date'),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
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
                              result,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '호환성 강점:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Wrap(
                        spacing: 8,
                        children:
                            compatibility
                                .map(
                                  (item) => Chip(
                                    label: Text(item),
                                    backgroundColor: AppColors.primary
                                        .withOpacity(0.2),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '분석 코멘트:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(comment),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '예측 결과',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          result,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.favorite,
                    color: AppColors.secondary,
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                comment,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '자세히 보기 >',
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
