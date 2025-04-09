import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class DateRecommendationScreen extends StatefulWidget {
  const DateRecommendationScreen({Key? key}) : super(key: key);

  @override
  State<DateRecommendationScreen> createState() =>
      _DateRecommendationScreenState();
}

class _DateRecommendationScreenState extends State<DateRecommendationScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearched = false;

  // 예시 데이트 장소 데이터
  final List<Map<String, dynamic>> _dateSpots = [
    {
      'title': '서울숲 카페거리',
      'description': '자연 속에서 여유로운 대화를 나눌 수 있는 감성 카페가 많은 곳입니다.',
      'location': '서울 성동구',
      'rating': 4.5,
      'tags': ['카페', '자연', '데이트'],
      'imageUrl': 'https://via.placeholder.com/150',
    },
    {
      'title': '남산 타워',
      'description': '서울의 야경을 한눈에 볼 수 있는 로맨틱한 장소입니다.',
      'location': '서울 중구',
      'rating': 4.7,
      'tags': ['야경', '전망', '로맨틱'],
      'imageUrl': 'https://via.placeholder.com/150',
    },
    {
      'title': '한강 피크닉',
      'description': '한강에서 도시락을 먹으며 여유로운 시간을 보낼 수 있어요.',
      'location': '서울 여의도',
      'rating': 4.2,
      'tags': ['피크닉', '한강', '야외'],
      'imageUrl': 'https://via.placeholder.com/150',
    },
    {
      'title': '경복궁 산책',
      'description': '한국의 전통적인 아름다움을 함께 느낄 수 있는 곳입니다.',
      'location': '서울 종로구',
      'rating': 4.6,
      'tags': ['역사', '문화', '산책'],
      'imageUrl': 'https://via.placeholder.com/150',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 검색창
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '상대방 닉네임 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _hasSearched = false;
                    });
                  },
                ),
                filled: true,
                fillColor: AppColors.lightGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _hasSearched = true;
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            if (_hasSearched) ...[
              Text(
                '${_searchController.text}님과 함께 방문하면 좋을 장소',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 데이트 장소 추천 카드 목록
              Expanded(
                child: ListView.builder(
                  itemCount: _dateSpots.length,
                  itemBuilder: (context, index) {
                    final spot = _dateSpots[index];
                    return DatePlaceCard(
                      title: spot['title'],
                      description: spot['description'],
                      location: spot['location'],
                      rating: spot['rating'],
                      tags: List<String>.from(spot['tags']),
                      imageUrl: spot['imageUrl'],
                    );
                  },
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 80, color: AppColors.grey),
                      SizedBox(height: 16),
                      Text(
                        '상대방의 닉네임을 검색하여\n데이트 장소를 추천받아보세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.darkGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DatePlaceCard extends StatelessWidget {
  final String title;
  final String description;
  final String location;
  final double rating;
  final List<String> tags;
  final String imageUrl;

  const DatePlaceCard({
    Key? key,
    required this.title,
    required this.description,
    required this.location,
    required this.rating,
    required this.tags,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 부분
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 150,
                  color: AppColors.lightGrey,
                  child: Center(
                    child: Icon(Icons.image, size: 50, color: Colors.grey[400]),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          rating.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 내용 부분
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.darkGrey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: const TextStyle(color: AppColors.darkGrey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(description, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      // 상세 페이지로 이동하거나 지도 앱 연동
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('위치 보기'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
