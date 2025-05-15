import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config/app_config.dart';
import '../../constants/app_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> _chatRooms = [];
  bool _isLoading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndRooms();
  }

  Future<void> _loadUserIdAndRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    print('userId: $userId');
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      // 필요시 에러 메시지 표시
      return;
    }
    setState(() {
      _userId = userId;
    });
    await _fetchChatRooms();
  }

  Future<void> _fetchChatRooms() async {
    print('채팅방 목록 요청 url: ${AppConfig.serverUrl}/chat-rooms/$_userId');
    final url = Uri.parse('${AppConfig.serverUrl}/chat-rooms/$_userId');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final List<dynamic> rooms = jsonDecode(res.body)['rooms'];
      setState(() {
        _chatRooms = rooms;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getPartnerId(Map room) {
    if (_userId == null) return '';
    return (room['user1_id'] == _userId ? room['user2_id'] : room['user1_id'])
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_chatRooms.isEmpty) {
      return const Center(child: Text('채팅 가능한 상대가 없습니다.'));
    }
    return ListView.builder(
      itemCount: _chatRooms.length,
      itemBuilder: (context, index) {
        final room = _chatRooms[index];
        final partnerId = _getPartnerId(room);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[200],
            backgroundImage: NetworkImage(
              '${AppConfig.serverUrl}/user-profile/$partnerId',
            ),
          ),
          title: Text('상대방 유저ID: $partnerId'),
          subtitle: Text('채팅방 ID: ${room['id']}'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => ChatRoomPage(
                      roomId: room['id'],
                      myUserId: _userId!,
                      partnerId: int.parse(partnerId),
                    ),
              ),
            );
          },
        );
      },
    );
  }
}

class ChatRoomPage extends StatefulWidget {
  final int roomId;
  final int myUserId;
  final int partnerId;

  const ChatRoomPage({
    Key? key,
    required this.roomId,
    required this.myUserId,
    required this.partnerId,
  }) : super(key: key);

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  late IO.Socket socket;
  List<Map<String, dynamic>> messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _fetchMessages();
  }

  void _connectSocket() {
    socket = IO.io(
      AppConfig.wsUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    socket.connect();
    socket.onConnect((_) {
      socket.emit('joinRoom', widget.roomId);
    });
    socket.on('receiveMessage', (data) {
      if (mounted && data['roomId'] == widget.roomId) {
        setState(() {
          messages.add({
            'sender_id': data['senderId'],
            'message': data['message'],
            'created_at': data['created_at'],
          });
        });
      }
    });
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
    });
    final url = Uri.parse(
      '${AppConfig.serverUrl}/chat-messages/${widget.roomId}',
    );
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final List<dynamic> msgList = jsonDecode(res.body)['messages'];
      setState(() {
        messages = msgList.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    socket.emit('sendMessage', {
      'roomId': widget.roomId,
      'senderId': widget.myUserId,
      'message': text,
    });
    _controller.clear();
  }

  @override
  void dispose() {
    socket.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('상대방 유저ID: ${widget.partnerId}')),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      reverse: false,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg['sender_id'] == widget.myUserId;
                        return Align(
                          alignment:
                              isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMe
                                      ? AppColors.primary.withOpacity(0.8)
                                      : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg['message'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
