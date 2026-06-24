import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart'; 
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
  
  final List<String> _availableCharacters = ["Tanjiro Kamado", "Nezuko Kamado", "Monkey D. Luffy"];
  final AudioService _audioService = AudioService();
  
  String? _userAvatar;
  String? _currentSessionId; 

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

  String _getCharacterAvatar(String characterName) {
    switch (characterName) {
      case "Tanjiro Kamado": return 'assets/tanjiro.jpg'; 
      case "Nezuko Kamado": return 'assets/nezuko.jpg';
      case "Monkey D. Luffy": return 'assets/luffy.jpg';
      default: return 'assets/default.jpg';
    }
  }

  Color _getCharacterThemeColor() {
    switch (_selectedCharacter) {
      case "Tanjiro Kamado": return Colors.teal;
      case "Nezuko Kamado": return Colors.pinkAccent;
      case "Monkey D. Luffy": return Colors.redAccent;
      default: return Colors.deepPurpleAccent;
    }
  }

  Color _getCharacterAccentColor() {
    switch (_selectedCharacter) {
      case "Tanjiro Kamado": return Colors.tealAccent;
      case "Nezuko Kamado": return const Color(0xFFFFB7D5); 
      case "Monkey D. Luffy": return Colors.amberAccent;
      default: return Colors.purpleAccent;
    }
  }

  Map<String, dynamic> _getCard1Data() {
    if (_selectedCharacter == "Monkey D. Luffy") {
      return {
        "title": "King's Haki Willpower Grounding",
        "icon": Icons.bolt,
        "desc": "Focus your inner Conqueror's Spirit against the chaotic storm of stress. Harness Luffy's unbreakable willpower to blow away your panic and anxieties!",
        "btnText": "Unleash Haki Grounding",
        "prompt": "Luffy, I am feeling totally overwhelmed and stressed out right now. Give me some of your pirate courage and help me anchor my mind!"
      };
    } else {
      return {
        "title": "Total Concentration Breathing Grounding",
        "icon": Icons.air,
        "desc": "Learn to control your pulse and calm your mind through targeted breathing exercises under Tanjiro's gentle guidance. Perfect for sudden heavy pressure.",
        "btnText": "Begin Breathing Session",
        "prompt": "Tanjiro, my heart is racing and I feel anxious. Can you teach me Total Concentration Breathing step-by-step to calm me down?"
      };
    }
  }

  Map<String, dynamic> _getCard2Data() {
    if (_selectedCharacter == "Monkey D. Luffy") {
      return {
        "title": "Straw Hat Crew Recruitment Audition",
        "icon": Icons.sailing,
        "desc": "Overcome social shyness by speaking with absolute, bold conviction! Practice shouting your true dreams aloud and pitch ideas with the future Pirate King.",
        "btnText": "Join Straw Hat Audition",
        "prompt": "Luffy, let's do a roleplay rehearsal! Give me a high-energy pirate scenario where I have to project my voice and pitch an idea confidently!"
      };
    } else {
      return {
        "title": "Demon Slayer Resolve & Speech Practice",
        "icon": Icons.shield,
        "desc": "Practice clear, honest, and empathetic communication skills. Tanjiro will help you find the inner resolve to express yourself confidently without social fear.",
        "btnText": "Start Resolve Training",
        "prompt": "Tanjiro, let's start the Communication Training. Give me a scenario where I need to speak up honestly and defend my ideas confidently!"
      };
    }
  }

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
      await FirebaseFirestore.instance.collection('chat_sessions').doc(sessionId).delete();
      if (_currentSessionId == sessionId) {
        setState(() => _currentSessionId = null);
      }
    }
  }

  // 🌟 核心升级：细化大模型的声线生成引导，强行格式化为完美适合 TTS 朗读的剧本台词格式
  Future<String> _getAIResponse(String message) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-3-flash-preview');
      
      String voiceStyleGuideline = "";
      if (_selectedCharacter == "Monkey D. Luffy") {
        voiceStyleGuideline = """
        You are Monkey D. Luffy from One Piece. 
        [VOICE STYLE]: Speak with explosive high-energy, wild enthusiasm, and a booming childish loudness! Use lots of exclamation marks (!) to trigger shouting inflections. Use his iconic laugh 'Shishishi!' naturally. Talk about being nakama, eating meat, and sailing.
        [CRITICAL RULE]: Do NOT include any physical action descriptions inside asterisks or brackets (e.g., do NOT write *laughs* or *stretches arm*). Speak ONLY spoken verbal dialogue.
        """;
      } else if (_selectedCharacter == "Tanjiro Kamado") {
        voiceStyleGuideline = """
        You are Tanjiro Kamado from Demon Slayer. 
        [VOICE STYLE]: Speak with deep, heartfelt sincerity, immense kindness, and polite, comforting warmth. You are protective and deeply empathetic. Your tone is steady, gentle, yet full of unwavering resolve.
        [CRITICAL RULE]: Do NOT include any text inside asterisks like *cries* or *takes a deep breath*. Output ONLY clean, pure verbal spoken statements that can be read aloud perfectly.
        """;
      } else {
        voiceStyleGuideline = "You are $_selectedCharacter. Speak purely in their dialogue tone. Never use markdown or action words in asterisks.";
      }

      final prompt = '''
      $voiceStyleGuideline
      Keep your response short, punchy, and highly conversational (maximum 1 to 2 sentences).
      User says: $message
      ''';
      
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "I am ready.";
    } catch (e) {
      return "Connection is weak, try again!";
    }
  }

  void _handleSubmitted(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (text.trim().isEmpty || user == null) return; 

    _textController.clear(); 
    setState(() { _isTyping = true; });

    if (_currentSessionId == null) {
      var sessionRef = await FirebaseFirestore.instance.collection('chat_sessions').add({
        'userId': user.uid,
        'character': _selectedCharacter,
        'title': text.length > 15 ? '${text.substring(0, 15)}...' : text, 
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() {
        _currentSessionId = sessionRef.id; 
      });
    }

    await FirebaseFirestore.instance.collection('chats').add({
      'userId': user.uid,
      'sessionId': _currentSessionId, 
      'character': _selectedCharacter,
      'text': text,
      'isUser': true, 
      'timestamp': Timestamp.now(),
    });

    try {
      String aiResponse = await _getAIResponse(text);
      
      await FirebaseFirestore.instance.collection('chats').add({
        'userId': user.uid,
        'sessionId': _currentSessionId, 
        'character': _selectedCharacter,
        'text': aiResponse,
        'isUser': false, 
        'timestamp': Timestamp.now(),
      });

      if (mounted) {
        // 🌟 核心双重滤网拦截器：利用正则表达式，强行把文本里死灰复燃的 *动作描述* 过滤抹杀掉，保护语音播报！
        String cleanSpeechText = aiResponse.replaceAll(RegExp(r'\*.*?\*'), '').replaceAll(RegExp(r'\[.*?\]'), '').trim();
        if (cleanSpeechText.isEmpty) cleanSpeechText = aiResponse; // 兜底安全
        
        _audioService.speak(cleanSpeechText, _selectedCharacter); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Error")));
    } finally {
      if (mounted) setState(() { _isTyping = false; });
    }
  }

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
                  setState(() { _currentSessionId = null; });
                  Navigator.pop(context); 
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
    
    final Color themeColor = _getCharacterThemeColor();
    final Color accentColor = _getCharacterAccentColor();

    final Map<String, dynamic> card1 = _getCard1Data();
    final Map<String, dynamic> card2 = _getCard2Data();

    return Scaffold(
      backgroundColor: const Color(0xFF121212), 
      drawer: _buildDrawer(), 
      appBar: AppBar(
        title: DropdownButton<String>(
          isExpanded: true,
          value: _availableCharacters.contains(_selectedCharacter) ? _selectedCharacter : _availableCharacters.first,
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          underline: Container(), 
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          items: _availableCharacters.map((String character) {
            return DropdownMenuItem<String>(
              value: character,
              child: Row(
                children: [
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
                _currentSessionId = null; 
              });
            }
          },
        ),
        backgroundColor: Colors.grey[950], 
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))
                .then((_) => _loadUserAvatar());
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white10,
                backgroundImage: _userAvatar != null && _userAvatar!.isNotEmpty ? AssetImage(_userAvatar!) : null,
                child: (_userAvatar == null || _userAvatar!.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
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
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Welcome! Choose a practice mode below:",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 12),

                        // Card 1: Grounding Tool
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: themeColor.withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(card1["icon"], color: accentColor, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    card1["title"],
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                card1["desc"],
                                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 32, 
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeColor.withOpacity(0.12),
                                    side: BorderSide(color: themeColor.withOpacity(0.7)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  icon: Icon(Icons.bolt, color: accentColor, size: 14),
                                  label: Text(card1["btnText"], style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    _handleSubmitted(card1["prompt"]);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Card 2: Confidence Booster
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accentColor.withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(card2["icon"], color: themeColor, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    card2["title"],
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                card2["desc"],
                                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 32, 
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor.withOpacity(0.12),
                                    side: BorderSide(color: accentColor.withOpacity(0.7)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  icon: Icon(Icons.star, color: themeColor, size: 14),
                                  label: Text(card2["btnText"], style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    _handleSubmitted(card2["prompt"]);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('chats')
                        .where('sessionId', isEqualTo: _currentSessionId) 
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

    Widget userAvatarWidget = CircleAvatar(
      radius: 16,
      backgroundColor: Colors.deepPurpleAccent,
      backgroundImage: _userAvatar != null && _userAvatar!.isNotEmpty ? AssetImage(_userAvatar!) : null,
      child: (_userAvatar == null || _userAvatar!.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 16) : null,
    );

    Widget characterAvatarWidget = CircleAvatar(
      radius: 16,
      backgroundColor: Colors.transparent, 
      backgroundImage: AssetImage(_getCharacterAvatar(_selectedCharacter)),
      onBackgroundImageError: (exception, stackTrace) {
        debugPrint("Image load error: $exception");
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            characterAvatarWidget,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: isUser ? _getCharacterThemeColor() : Colors.grey[850], 
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                ),
              ),
              child: Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ),
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
            backgroundColor: _getCharacterThemeColor(), 
            child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _handleSubmitted(_textController.text)),
          ),
        ],
      ),
    );
  }
}