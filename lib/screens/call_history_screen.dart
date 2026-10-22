import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<dynamic> _partners = [];
  bool _isLoading = true;
  Map<String, String> _userIdToNickname = {}; // userId → 닉네임 매핑

  @override
  void initState() {
    super.initState();
    _fetchCallHistory();
  }

  Future<void> _fetchCallHistory() async {
    setState(() {
      _isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    print(
      '[CallHistoryScreen] SharedPreferences에서 user_id로 user_id 읽음: $userId',
    );
    if (userId == null) return;
    final url = Uri.parse('${AppConfig.serverUrl}/call-history/$userId');
    final res = await http.get(url);
    print('서버 응답: ${res.body}');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final partners = body['partners'] ?? [];
      print('partners: $partners');
      // user_id 목록 추출
      final userIds =
          partners
              .map((e) => e['partner_id'].toString())
              .toSet()
              .cast<String>();
      print('userIds: $userIds');
      final nicknameMap = await _fetchNicknames(userIds);
      print('nicknameMap: $nicknameMap');
      setState(() {
        _partners = partners;
        _userIdToNickname = nicknameMap;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // user_id → 닉네임 매핑 함수
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

  // 카드 클릭 시 동의/거절 다이얼로그
  void _showStepDialog(Map partner) async {
    final prefs = await SharedPreferences.getInstance();
    final myUserId = prefs.getInt('user_id');
    final partnerId = partner['partner_id']; // 반드시 숫자(user_id)여야 함
    final step = partner['step'] ?? 1;
    final myAgree = partner['my_agree'] ?? 0;
    final partnerAgree = partner['partner_agree'] ?? 0;

    if (step == 1) {
      // 둘 다 동의해야 사진 공개
      if (myAgree == 1 && partnerAgree == 1) {
        // 사진 공개
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('상대방 사진'),
                content: Image.network(
                  '${AppConfig.serverUrl}/user-profile/$partnerId',
                  errorBuilder:
                      (context, error, stackTrace) => const Text('이미지 없음'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ],
              ),
        );
        return;
      }

      // 아직 동의가 안 된 경우
      final result = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('다음 단계로 진행'),
              content: Text(
                partnerAgree == 1
                    ? '상대방이 이미 동의했습니다. 사진을 공개하시겠습니까?'
                    : '서로의 사진을 공개하시겠습니까?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('거절'),
                ),
                if (myAgree == 0)
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('동의'),
                  ),
              ],
            ),
      );
      if (result == null) return;

      final url = Uri.parse('${AppConfig.serverUrl}/call-partner/step');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': myUserId,
          'partnerId': partnerId, // 숫자(user_id)로 보냄
          'agree': result,
          'nextStep': step == 2 ? 3 : 2, // 단계에 따라 2 또는 3
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['step'] == 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서로 동의하여 데이트 단계로 진입합니다!')),
          );
          setState(() {
            partner['step'] = 3;
            partner['my_agree'] = 2;
            partner['partner_agree'] = 2;
          });
        } else if (data['step'] == 2) {
          setState(() {
            partner['step'] = 2;
            partner['my_agree'] = 1;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('사진 공개 단계로 진입합니다!')));
        } else {
          setState(() {
            partner['my_agree'] = 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('동의가 저장되었습니다. 상대방의 동의를 기다려주세요.')),
          );
        }
      }
    } else if (step == 2) {
      // 2단계(사진 공개) 상태에서 카드 클릭 시
      if (myAgree == 2 && partnerAgree == 2) {
        // 이미 데이트 단계
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('데이트 단계'),
                content: const Text('서로 데이트에 동의했습니다!'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ],
              ),
        );
        return;
      }

      // 아직 데이트 동의 전 → 다이얼로그 띄우기
      final result = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('데이트 단계로 진행'),
              content: Text(
                partnerAgree == 2
                    ? '상대방이 이미 데이트에 동의했습니다. 데이트에 동의하시겠습니까?'
                    : '서로 데이트에 동의하면 채팅방이 개설됩니다.\n진행하시겠습니까?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('거절'),
                ),
                if (myAgree < 2)
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('동의'),
                  ),
              ],
            ),
      );
      if (result == null) return;

      // 서버에 3단계 동의 요청
      final url = Uri.parse('${AppConfig.serverUrl}/call-partner/step');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': myUserId,
          'partnerId': partnerId, // 숫자(user_id)로 보냄
          'agree': result,
          'nextStep': step == 2 ? 3 : 2, // 단계에 따라 2 또는 3
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['step'] == 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서로 동의하여 데이트 단계로 진입합니다!')),
          );
          setState(() {
            partner['step'] = 3;
            partner['my_agree'] = 2;
            partner['partner_agree'] = 2;
          });
        } else {
          setState(() {
            partner['my_agree'] = 2;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('동의가 저장되었습니다. 상대방의 동의를 기다려주세요.')),
          );
        }
      }
    } else if (step == 3) {
      // 이미 데이트 단계
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('데이트 단계'),
              content: const Text('서로 데이트에 동의했습니다!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_partners.isEmpty) {
      return const Center(child: Text('통화내역이 없습니다.'));
    }
    return ListView.builder(
      itemCount: _partners.length,
      itemBuilder: (context, index) {
        final partner = _partners[index];
        final step = partner['step'] ?? 1;
        final partnerId = partner['partner_id'].toString();
        final partnerNickname = _userIdToNickname[partnerId] ?? partnerId;

        // 2, 3단계에서만 썸네일 노출
        final showProfile = (step == 2 || step == 3);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading:
                showProfile
                    ? GestureDetector(
                      onTap: () => _showPartnerImageDialog(partnerId),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: NetworkImage(
                          '${AppConfig.serverUrl}/user-profile/$partnerId',
                        ),
                        onBackgroundImageError: (_, __) {},
                        child: Container(), // 이미지 없을 때 기본 아이콘 안보이게
                      ),
                    )
                    : CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: Icon(Icons.person, color: Colors.grey[600]),
                    ),
            title: Text('상대방: $partnerNickname'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('통화 ${partner['count']}회'),
                if (showProfile)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '이미지를 누르면 크게 볼 수 있습니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    step == 3
                        ? Colors.pink.shade100
                        : step == 2
                        ? Colors.purple.shade100
                        : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                step == 3
                    ? '데이트 단계'
                    : step == 2
                    ? '사진 공개'
                    : '대기 중',
                style: TextStyle(
                  color:
                      step == 3
                          ? Colors.pink
                          : step == 2
                          ? Colors.purple
                          : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () => _showStepDialog(partner),
          ),
        );
      },
    );
  }

  // 상대방 이미지 다이얼로그 함수 추가
  void _showPartnerImageDialog(String partnerId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('상대방 프로필 이미지'),
            content: Image.network(
              '${AppConfig.serverUrl}/user-profile/$partnerId',
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) =>
                      const Text('이미지를 불러올 수 없습니다.'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }
}
