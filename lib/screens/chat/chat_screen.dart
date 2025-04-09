import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 채팅 목록 예시 데이터
    final List<Map<String, dynamic>> chatList = [
      {
        'name': '실비아',
        'lastMessage': '나는 코더지만 오늘은 쉬어야겠어',
        'time': '11:30',
        'unread': 2,
        'profileImage': 'https://via.placeholder.com/150',
      },
      {
        'name': '루시',
        'lastMessage': '맥도날드에서 만날래?',
        'time': '13:51',
        'unread': 0,
        'profileImage': 'https://via.placeholder.com/150',
      },
      {
        'name': '로이',
        'lastMessage': '다음 주 금요일에 영화 보러 갈까?',
        'time': '어제',
        'unread': 1,
        'profileImage': 'https://via.placeholder.com/150',
      },
      {
        'name': '민지',
        'lastMessage': '알겠어 그때 보자!',
        'time': '어제',
        'unread': 0,
        'profileImage': 'https://via.placeholder.com/150',
      },
    ];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 검색창
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: '채팅방 검색',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.lightGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // 채팅방 목록
            Expanded(
              child: ListView.separated(
                itemCount: chatList.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final chat = chatList[index];
                  return ChatListItem(
                    name: chat['name'],
                    lastMessage: chat['lastMessage'],
                    time: chat['time'],
                    unread: chat['unread'],
                    profileImage: chat['profileImage'],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ChatDetailScreen(name: chat['name']),
                        ),
                      );
                    },
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

class ChatListItem extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final String profileImage;
  final VoidCallback onTap;

  const ChatListItem({
    Key? key,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.profileImage,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.lightGrey,
        backgroundImage: NetworkImage(profileImage),
        onBackgroundImageError: (_, __) {},
        child: Icon(Icons.person, color: Colors.grey[400], size: 30),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 5),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                unread.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String name;

  const ChatDetailScreen({Key? key, required this.name}) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 예시 메시지 데이터
  final List<Map<String, dynamic>> _messages = [
    {'text': '나는 코더지만 오늘은 쉬어야겠어', 'isMe': false, 'time': '11:30'},
    {'text': '시간 될 때 만나서 커피라도 마실래?', 'isMe': true, 'time': '11:32'},
    {'text': '좋아! 내가 꿈꾸던 삶이야', 'isMe': false, 'time': '11:35'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // 메시지 목록
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return MessageBubble(
                    text: message['text'],
                    isMe: message['isMe'],
                    time: message['time'],
                  );
                },
              ),
            ),
          ),

          // 메시지 입력창
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: '메시지 입력...',
                      filled: true,
                      fillColor: AppColors.lightGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (value) {
                      _sendMessage();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        _messages.add({
          'text': _messageController.text,
          'isMe': true,
          'time': '지금',
        });
        _messageController.clear();
      });

      // 스크롤을 맨 아래로 이동
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;

  const MessageBubble({
    Key? key,
    required this.text,
    required this.isMe,
    required this.time,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.lightGrey,
              child: const Icon(Icons.person, color: Colors.grey),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(color: isMe ? Colors.white : Colors.black),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
