import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart'; // 使用免费的 Firebase AI Logic
import '../models/message_model.dart';
import '../services/audio_service.dart';
import 'profile_screen.dart';

class AIChatScreen extends StatefulWidget {
  final String characterName; 
  const AIChatScreen({super.key, this.characterName = "Tanjiro Kamado"});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isTyping = false; 
  late String _selectedCharacter;
 
 // 把这行加回来
  final List<String> _availableCharacters = ["Tanjiro Kamado", "Nezuko Kamado", "Monkey D. Luffy"];

  final AudioService _audioService = AudioService();
  
  String? _userAvatar;
  String? _currentSessionId; // 🌟 新增：记录当前所在的“聊天房间”ID

  @override
  void initState() {
    super.initState();
    _selectedCharacter = widget.characterName; 
    _loadUserAvatar();
  }

  void _loadUserAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && doc.exists && doc.data() != null) {
        setState(() {
          _userAvatar = doc.data()!['avatarUrl'];
        });
      }
    }
  }

  // 1. 角色头像映射库 (⚠️记得把这里的 assets 路径换成你项目里真实的图片路径！)
  String _getCharacterAvatar(String characterName) {
    switch (characterName) {
      case "Tanjiro Kamado": return 'assets/tanjiro.jpg'; 
      case "Nezuko Kamado": return 'assets/nezuko.jpg';
      case "Monkey D. Luffy": return 'assets/luffy.jpg';
      default: return 'assets/default.jpg'; // 默认头像
    }
  }

  // 2. 彻底删除聊天记录的函数
  void _deleteChatSession(String sessionId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Delete Chat", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure? This cannot be undone.", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      // 删掉侧边栏的房间号
      await FirebaseFirestore.instance.collection('chat_sessions').doc(sessionId).delete();
      
      // 如果你删的是正在聊的这个房间，就把屏幕清空
      if (_currentSessionId == sessionId) {
        setState(() => _currentSessionId = null);
      }
    }
  }

  // 呼叫 Firebase AI 的函数
  Future<String> _getAIResponse(String message) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-3-flash-preview');
      final prompt = '''
      You are $_selectedCharacter from anime. 
      Respond to the user exactly in the tone, personality, and catchphrases of $_selectedCharacter. 
      Keep your responses short, engaging, and conversational (1 to 3 sentences maximum).
      User says: $message
      ''';
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Sorry, I am speechless right now.";
    } catch (e) {
      return "*looks confused* Connection error... Please try again.";
    }
  }

  void _handleSubmitted(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (text.trim().isEmpty || user == null) return; 

    _textController.clear(); 
    setState(() { _isTyping = true; });

    // 🌟 核心逻辑：如果是新聊天，先创建一个“聊天会话”房间
    if (_currentSessionId == null) {
      var sessionRef = await FirebaseFirestore.instance.collection('chat_sessions').add({
        'userId': user.uid,
        'character': _selectedCharacter,
        'title': text.length > 15 ? '${text.substring(0, 15)}...' : text, // 用第一句话当标题
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() {
        _currentSessionId = sessionRef.id; // 记录下这个新房间的 ID
      });
    }

    // 1. 把【用户】说的话存入这个房间
    await FirebaseFirestore.instance.collection('chats').add({
      'userId': user.uid,
      'sessionId': _currentSessionId, // 绑定房间 ID
      'character': _selectedCharacter,
      'text': text,
      'isUser': true, 
      'timestamp': Timestamp.now(),
    });

    try {
      // 2. 呼叫 AI
      String aiResponse = await _getAIResponse(text);
      
      // 3. 把【AI】说的话也存入这个房间
      await FirebaseFirestore.instance.collection('chats').add({
        'userId': user.uid,
        'sessionId': _currentSessionId, // 绑定房间 ID
        'character': _selectedCharacter,
        'text': aiResponse,
        'isUser': false, 
        'timestamp': Timestamp.now(),
      });

      if (mounted) _audioService.speak(aiResponse, _selectedCharacter); 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Error")));
    } finally {
      if (mounted) setState(() { _isTyping = false; });
    }
  }

  // --- 新增：用于重命名聊天记录的弹窗 ---
  void _showRenameDialog(String sessionId, String currentTitle) {
    TextEditingController renameController = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Rename Chat", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: renameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Enter new name",
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.deepPurple)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.deepPurpleAccent)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () async {
                if (renameController.text.trim().isNotEmpty) {
                  // 更新云端数据库里的标题
                  await FirebaseFirestore.instance.collection('chat_sessions').doc(sessionId).update({
                    'title': renameController.text.trim(),
                  });
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text("SAVE", style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
          ],
        );
      }
    );
  }

  // --- 🌟 新增：侧边栏 UI (用于显示历史记录) ---
  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    return Drawer(
      backgroundColor: Colors.grey[900],
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple[800]),
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 50)
                ),
                icon: const Icon(Icons.add),
                label: const Text("New Chat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () {
                  // 点击新聊天，清空当前房间号
                  setState(() { _currentSessionId = null; });
                  Navigator.pop(context); // 关掉侧边栏
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Recent Chats", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: user == null ? const SizedBox() : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chat_sessions')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var docs = snapshot.data!.docs.toList();
                // 按照时间倒序排列历史记录
                docs.sort((a, b) {
                  var aTime = (a.data() as Map)['timestamp'] as Timestamp?;
                  var bTime = (b.data() as Map)['timestamp'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isActive = docs[index].id == _currentSessionId;

                   return ListTile(
                      tileColor: isActive ? Colors.deepPurple.withOpacity(0.3) : null,
                      leading: const Icon(Icons.chat_bubble_outline, color: Colors.white54),
                      title: Text(data['title'] ?? 'New Chat', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(data['character'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      // 🌟 新增：右侧的编辑小图标，点击即可重命名
                      // 🌟 新增：包含编辑和删除两个按钮的 Row
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                            onPressed: () => _showRenameDialog(docs[index].id, data['title'] ?? 'New Chat'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                            onPressed: () => _deleteChatSession(docs[index].id),
                          ),
                        ],
                      ),
                      onTap: () {
                        // 点击历史记录，切换到对应的房间
                        setState(() {
                          _currentSessionId = docs[index].id;
                          _selectedCharacter = data['character'];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      drawer: _buildDrawer(), // 🌟 挂载侧边栏
      appBar: AppBar(
        // 🌟 核心修改：换回下拉菜单，并加入新逻辑
        title: DropdownButton<String>(
          isExpanded: true,
          value: _availableCharacters.contains(_selectedCharacter) ? _selectedCharacter : _availableCharacters.first,
          dropdownColor: Colors.deepPurple[800],
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          underline: Container(), // 去掉底部的下划线，更好看
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
         items: _availableCharacters.map((String character) {
            return DropdownMenuItem<String>(
              value: character,
              child: Row(
                children: [
                  // 🌟 下拉菜单里的角色小头像
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: AssetImage(_getCharacterAvatar(character)),
                  ),
                  const SizedBox(width: 8),
                  Text('Chat with $character'),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null && newValue != _selectedCharacter) {
              setState(() {
                _selectedCharacter = newValue;
                _currentSessionId = null; // ⚠️ 重点：切换角色时，自动清空房间号，开启新聊天！
              });
            }
          },
        ),
        backgroundColor: Colors.deepPurple[800],
        actions: [
          // 这里的头像代码保持不变...
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))
                .then((_) => _loadUserAvatar());
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.deepPurpleAccent,
                backgroundImage: _userAvatar != null && _userAvatar!.isNotEmpty ? AssetImage(_userAvatar!) : null,
                child: (_userAvatar == null || _userAvatar!.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
              ),
            ),
          ),
        ],
      ),
      body: user == null
        ? const Center(child: Text("Please login first.", style: TextStyle(color: Colors.white)))
        : Column(
        children: [
          Expanded(
            child: _currentSessionId == null 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.forum_outlined, size: 80, color: Colors.grey[700]),
                    const SizedBox(height: 16),
                    Text("Start a new chat with\n$_selectedCharacter", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  ],
                ),
              )
            : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats')
                  .where('sessionId', isEqualTo: _currentSessionId) // 🌟 只加载当前房间的聊天
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                var docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  var aTime = (a.data() as Map)['timestamp'] as Timestamp?;
                  var bTime = (b.data() as Map)['timestamp'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    Message message = Message(
                      text: data['text'] ?? '',
                      isUser: data['isUser'] ?? true,
                      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                    );
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          if (_isTyping) const Padding(padding: EdgeInsets.all(8.0), child: Align(alignment: Alignment.centerLeft, child: Text("Character is typing...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))),
          _buildMessageInput(),
        ],
      ),
    );
  }

 Widget _buildMessageBubble(Message message) {
    bool isUser = message.isUser;

    // 1. 真实的你的主页头像
    Widget userAvatarWidget = CircleAvatar(
      radius: 16,
      backgroundColor: Colors.deepPurpleAccent,
      backgroundImage: _userAvatar != null && _userAvatar!.isNotEmpty 
          ? AssetImage(_userAvatar!) 
          : null,
      child: (_userAvatar == null || _userAvatar!.isEmpty) 
          ? const Icon(Icons.person, color: Colors.white, size: 16) 
          : null,
    );

    // 2. 真实的动漫角色头像
    Widget characterAvatarWidget = CircleAvatar(
      radius: 16,
      backgroundColor: Colors.transparent, // 背景变透明，更好看
      backgroundImage: AssetImage(_getCharacterAvatar(_selectedCharacter)),
      // 这里的兜底处理：如果图片找不到，就先显示一个灰色的默认笑脸
      onBackgroundImageError: (exception, stackTrace) {
        print("Image load error: $exception");
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI 动漫头像
          if (!isUser) ...[
            characterAvatarWidget,
            const SizedBox(width: 8),
          ],
          
          // 聊天气泡
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isUser ? Colors.deepPurple : Colors.grey[800],
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
                  bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
                ),
              ),
              child: Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
          
          // 你的头像
          if (isUser) ...[
            const SizedBox(width: 8),
            userAvatarWidget,
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Colors.black26,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Message $_selectedCharacter...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: _handleSubmitted,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.deepPurpleAccent,
            child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _handleSubmitted(_textController.text)),
          ),
        ],
      ),
    );
  }
}