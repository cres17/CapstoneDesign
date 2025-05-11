import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../../constants/app_colors.dart';
import 'dart:convert'; // 한글 깨짐 방지용
import '../../config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DateRecommendationScreen extends StatefulWidget {
  const DateRecommendationScreen({Key? key}) : super(key: key);

  @override
  State<DateRecommendationScreen> createState() =>
      _DateRecommendationScreenState();
}

class _DateRecommendationScreenState extends State<DateRecommendationScreen> {
  // 위치기반 데이트 장소 데이터
  List<Map<String, dynamic>> _dateSpots = [];
  bool _isLoading = false;
  String? _errorMsg;
  bool _hasRequested = false; // 버튼 클릭 여부
  List<Map<String, dynamic>> _partners = [];
  bool _isPartnerLoading = false;

  // 위치 받아오기 및 API 요청
  Future<void> _fetchDateSpots() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _dateSpots = [];
    });

    try {
      // 위치 권한 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMsg = '위치 권한이 필요합니다.';
            _isLoading = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMsg = '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.';
          _isLoading = false;
        });
        return;
      }

      // 현재 위치 받아오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double mapX = position.longitude;
      double mapY = position.latitude;

      print('현재 위치: 경도(mapX)=$mapX, 위도(mapY)=$mapY');

      // 디코딩된 서비스키 사용
      final String serviceKey =
          'ZhUweX28UEl3Hx5AekfMOBgq4GkoC+9j//0fcItNuyS0P4gbgx5QQv6rbteypofg7x5qk5gfgawwtFA+hy0WHw==';
      final String encodedServiceKey = Uri.encodeComponent(serviceKey);

      // 요청 URL 생성
      final String url =
          'https://apis.data.go.kr/B551011/KorService1/locationBasedList1'
          '?MobileOS=AND'
          '&MobileApp=daon'
          '&mapX=$mapX'
          '&mapY=$mapY'
          '&radius=5000'
          '&contentTypeId=39'
          '&serviceKey=$encodedServiceKey'
          '&_type=xml'
          '&numOfRows=10';

      print('요청 URL: $url');
      print('서비스키(디코딩): $serviceKey');
      print('서비스키(인코딩): $encodedServiceKey');

      final response = await http.get(Uri.parse(url));
      print('응답 코드: ${response.statusCode}');
      final decodedBody = utf8.decode(response.bodyBytes);
      print('응답 본문: $decodedBody');

      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(decodedBody);
        final items = document.findAllElements('item');
        List<Map<String, dynamic>> spots = [];
        for (var item in items) {
          spots.add({
            'title': item.getElement('title')?.text ?? '',
            'description': item.getElement('addr1')?.text ?? '',
            'location': item.getElement('addr1')?.text ?? '',
            'rating': 4.0, // 별점 데이터가 없으므로 임의값
            'tags': ['음식점', '데이트'],
            'imageUrl':
                item.getElement('firstimage')?.text.isNotEmpty == true
                    ? item.getElement('firstimage')!.text
                    : 'https://via.placeholder.com/150',
          });
        }
        setState(() {
          _dateSpots = spots;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg = 'API 요청 실패: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = '오류 발생: $e';
        _isLoading = false;
      });
      print('오류 발생: $e');
    }
  }

  // 3단계 상대방 목록 불러오기
  Future<void> _fetchDatePartners() async {
    setState(() {
      _isPartnerLoading = true;
      _errorMsg = null;
      _partners = [];
    });
    try {
      final int myUserId = await _getMyUserId();
      print('========== [데이트 추천 디버깅] ==========');
      print('내 userId: $myUserId');
      final url = '${AppConfig.serverUrl}/date-partners/$myUserId';
      print('서버로 요청하는 URL: $url');
      final response = await http.get(Uri.parse(url));
      print('서버 응답 코드: ${response.statusCode}');
      print('서버 응답 body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('서버에서 받은 partners(raw): ${data['partners']}');
        if (data['partners'] is List && data['partners'].isNotEmpty) {
          for (var i = 0; i < data['partners'].length; i++) {
            final p = data['partners'][i];
            print(
              '상대방[$i] partner_id: ${p['partner_id']}, nickname: ${p['nickname']}, lat: ${p['latitude']}, lng: ${p['longitude']}',
            );
          }
        } else {
          print('서버에서 받은 partners가 비어있음');
        }
        setState(() {
          _partners = List<Map<String, dynamic>>.from(data['partners']);
          _isPartnerLoading = false;
        });
      } else {
        setState(() {
          _errorMsg = '상대방 목록 불러오기 실패';
          _isPartnerLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = '상대방 목록 오류: $e';
        _isPartnerLoading = false;
      });
      print('상대방 목록 오류: $e');
    }
    print('=========================================');
  }

  // 내 userId 가져오는 함수 (예시, 실제 구현에 맞게 수정)
  Future<int> _getMyUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    print('[JWT] user_id: $userId');
    return userId ?? 0;
  }

  // 중간값 계산 함수
  Map<String, double> _getMidPoint(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return {'lat': (lat1 + lat2) / 2, 'lng': (lng1 + lng2) / 2};
  }

  // 중간값 위치로 데이트 장소 추천
  Future<void> _fetchDateSpotsAt(double lat, double lng) async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _dateSpots = [];
    });

    try {
      final String serviceKey =
          'ZhUweX28UEl3Hx5AekfMOBgq4GkoC+9j//0fcItNuyS0P4gbgx5QQv6rbteypofg7x5qk5gfgawwtFA+hy0WHw==';
      final String encodedServiceKey = Uri.encodeComponent(serviceKey);

      final String url =
          'https://apis.data.go.kr/B551011/KorService1/locationBasedList1'
          '?MobileOS=AND'
          '&MobileApp=daon'
          '&mapX=$lng'
          '&mapY=$lat'
          '&radius=5000'
          '&contentTypeId=39'
          '&serviceKey=$encodedServiceKey'
          '&_type=xml';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(utf8.decode(response.bodyBytes));
        final items = document.findAllElements('item');
        final spots =
            items.map((item) {
              return {
                'title': item.getElement('title')?.text ?? '',
                'description': item.getElement('addr1')?.text ?? '',
                'location': item.getElement('addr1')?.text ?? '',
                'rating': 4.5,
                'tags': ['데이트', '맛집'],
                'imageUrl': item.getElement('firstimage')?.text ?? '',
              };
            }).toList();
        setState(() {
          _dateSpots = List<Map<String, dynamic>>.from(spots);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg = '추천 장소 불러오기 실패';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = '추천 장소 오류: $e';
        _isLoading = false;
      });
    }
  }

  // 1. 버튼 클릭 핸들러 (이 함수가 반드시 있어야 함)
  Future<void> _onRecommendButtonPressed() async {
    print('데이트장소 추천 버튼 클릭됨');
    final prefs = await SharedPreferences.getInstance();
    dynamic rawUserId =
        prefs.get('user_id') ?? prefs.get('userId') ?? prefs.get('id');
    print(
      '[JWT] SharedPreferences에 저장된 userId raw 값: $rawUserId, 타입: ${rawUserId.runtimeType}',
    );
    int? jwtUserId;
    if (rawUserId is int) {
      jwtUserId = rawUserId;
    } else if (rawUserId is String) {
      jwtUserId = int.tryParse(rawUserId);
    }
    print('[JWT] 변환된 userId: $jwtUserId');
    setState(() {
      _isPartnerLoading = true;
      _errorMsg = null;
      _hasRequested = false;
      _dateSpots = [];
    });

    // 1. 3단계 상대방 목록 불러오기
    await _fetchDatePartners();

    setState(() {
      _isPartnerLoading = false;
    });

    if (_partners.isEmpty) {
      setState(() {
        _errorMsg = '3단계까지 간 상대방이 없습니다.';
        _hasRequested = true;
      });
      print('3단계까지 간 상대방이 없습니다.');
      return;
    }

    // 2. 상대방 선택 다이얼로그
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('상대방 선택'),
          children:
              _partners.map((partner) {
                return SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, partner),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            partner['profile_image'] != null
                                ? NetworkImage(
                                  '${AppConfig.serverUrl}/${partner['profile_image']}',
                                )
                                : null,
                        child:
                            partner['profile_image'] == null
                                ? const Icon(Icons.person)
                                : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${partner['nickname'] ?? '닉네임 없음'} (ID: ${partner['partner_id']})',
                      ),
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );

    if (selected == null) {
      setState(() {
        _errorMsg = '상대방을 선택해주세요.';
        _hasRequested = true;
      });
      print('상대방 선택 안함');
      return;
    }

    print('선택된 상대방: $selected');

    // 3. 내 위치 받아오기
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMsg = '위치 권한이 필요합니다.';
          _hasRequested = true;
        });
        print('위치 권한 거부됨');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMsg = '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.';
        _hasRequested = true;
      });
      print('위치 권한 영구 거부');
      return;
    }

    Position myPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // 4. 중간값 계산
    double myLat = myPosition.latitude;
    double myLng = myPosition.longitude;
    double partnerLat =
        selected['latitude'] is String
            ? double.tryParse(selected['latitude']) ?? 0
            : (selected['latitude'] ?? 0);
    double partnerLng =
        selected['longitude'] is String
            ? double.tryParse(selected['longitude']) ?? 0
            : (selected['longitude'] ?? 0);

    print('내 위치: $myLat, $myLng / 상대 위치: $partnerLat, $partnerLng');

    double midLat = (myLat + partnerLat) / 2;
    double midLng = (myLng + partnerLng) / 2;

    print('중간값 위치: $midLat, $midLng');

    // 5. 중간값 위치로 데이트 장소 추천
    await _fetchDateSpotsAt(midLat, midLng);

    setState(() {
      _hasRequested = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "데이트장소 추천" 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onRecommendButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  '데이트장소 추천',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isPartnerLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_hasRequested)
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMsg != null
                        ? Center(child: Text(_errorMsg!))
                        : _dateSpots.isEmpty
                        ? const Center(child: Text('추천 장소가 없습니다.'))
                        : ListView.builder(
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
              )
            else
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 80, color: AppColors.grey),
                      SizedBox(height: 16),
                      Text(
                        '버튼을 눌러 내 주변 데이트 장소를 추천받아보세요.',
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
