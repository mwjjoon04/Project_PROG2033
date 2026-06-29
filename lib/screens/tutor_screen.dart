import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http; 
import '../services/audio_service.dart';          
import '../widgets/sign_language_translator.dart'; 

class TutorScreen extends StatelessWidget {
  const TutorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      appBar: AppBar(
        title: const Text('Nihongo Dojo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: const Center(
        child: NihongoAudioTutorWidget(),
      ),
    );
  }
}

class NihongoAudioTutorWidget extends StatefulWidget {
  const NihongoAudioTutorWidget({super.key});

  @override
  State<NihongoAudioTutorWidget> createState() => _NihongoAudioTutorWidgetState();
}

class _NihongoAudioTutorWidgetState extends State<NihongoAudioTutorWidget> {
  final AudioService _audioService = AudioService(); 
  
  bool _isPlaying = false;
  bool _isNezukoSigning = false; 

  Timer? _mockTimer;
  int _elapsedMilliseconds = 0;
  int _totalMockDurationMs = 4000; // 🌟 去掉 final，改为动态自适应时钟

  String _selectedCharacter = 'Tanjiro Kamado';
  String _selectedLanguage = 'English (EN)'; 

  List<String> _jpWords = ["全集中！", "今日", "の稽古", "を始め", "ましょう！"];
  List<String> _romajiWords = ["Zen ", "shuu ", "chuu! ", "Kyou ", "no ", "keiko ", "o ", "hajimemashou!"];
  
  Map<String, String> _currentTranslations = {
    'English (EN)': "Total concentration! Let's start today's training!",
    'Chinese (ZH)': "全神贯注！开始今天的训练吧！",
    'Malay (MS)': "Konsentrasi penuh! Mari mulakan latihan hari ini!"
  };

  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _mockTimer?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      _stopPlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    String japaneseText = _jpWords.join('');
    
    // 🌟 核心算法：依据不同角色的发音速率，动态计算最完美的动画驻留总时长
    double speechRate = 0.5; // 默认
    if (_selectedCharacter == 'Nezuko') speechRate = 0.4; // 慢速
    if (_selectedCharacter == 'Luffy') speechRate = 0.6;   // 快速

    // 计算单个字符所需的毫秒数，并加上发音引擎起步的硬件缓冲延迟
    int msPerChar = (130 / speechRate).round(); 
    int calculatedDuration = (japaneseText.length * msPerChar) + 600;

    setState(() {
      _isPlaying = true;
      _elapsedMilliseconds = 0;
      _totalMockDurationMs = calculatedDuration; // 🌟 将算好的精准时间赋予时钟引擎
      if (_selectedCharacter == 'Nezuko') {
        _isNezukoSigning = true;
      }
    });

    String englishText = _currentTranslations['English (EN)'] ?? "";
    String mappedCharacterName = "Tanjiro Kamado";
    if (_selectedCharacter == 'Nezuko') mappedCharacterName = "Nezuko Kamado";
    if (_selectedCharacter == 'Luffy') mappedCharacterName = "Monkey D. Luffy";

    // 触发纯净日语朗读
    _audioService.speak(japaneseText, mappedCharacterName, locale: "ja-JP");

    // 启动完全与声音长度动态对齐的高亮计时器
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedMilliseconds += 50;
        if (_elapsedMilliseconds >= _totalMockDurationMs) {
          _stopPlayback();
        }
      });
    });
  }

  void _stopPlayback() {
    _mockTimer?.cancel();
    _audioService.stop(); 
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isNezukoSigning = false; 
        _elapsedMilliseconds = 0; 
      });
    }
  }

  // 保持你原本完美的实时网络 Google 翻译与本地兜底逻辑完好损
  Future<void> _handleTranslate() async {
    String text = _inputController.text.trim();
    if (text.isEmpty) return;

    _stopPlayback();

    setState(() {
      _jpWords = ["翻", "译", "中", "..."];
      _romajiWords = ["Translating..."];
      _currentTranslations = {
        'English (EN)': "Translating in real-time...",
        'Chinese (ZH)': "正在实时翻译中...",
        'Malay (MS)': "Sedang menterjemah..."
      };
    });
    
    _inputController.clear();
    FocusScope.of(context).unfocus();

    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=ja&dt=t&dt=rm&q=${Uri.encodeComponent(text)}'
      );
      
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0'
      });

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        String translatedJp = "";
        String romajiString = "";

        if (jsonData.isNotEmpty && jsonData[0] != null) {
          final List<dynamic> blocks = jsonData[0];
          for (var block in blocks) {
            if (block != null && block is List && block.isNotEmpty) {
              translatedJp += block[0].toString();
            }
          }
          try {
            if (blocks.length > 1 && blocks.last is List) {
              final lastBlock = blocks.last;
              if (lastBlock.length > 3 && lastBlock[3] != null) {
                romajiString = lastBlock[3].toString();
              }
            }
          } catch (_) {}
        }

        if (romajiString.isEmpty || !RegExp(r'[a-zA-Z]').hasMatch(romajiString)) {
          String lowerInput = text.toLowerCase();
          if (lowerInput.contains("hello")) {
            romajiString = "Konnichiwa";
          } else if (lowerInput.contains("what time")) {
            romajiString = "Shigoto wa nan-ji ni shimasu ka";
          } else if (lowerInput.contains("thank you")) {
            romajiString = "Arigatou gozaimasu";
          } else {
            romajiString = "Nihongo dojo gakushuu";
          }
        }

        List<String> jpSegments = [];
        for (int i = 0; i < translatedJp.length; i++) {
          jpSegments.add(translatedJp[i]);
        }

        List<String> romajiSegments = romajiString.split(' ').where((e) => e.isNotEmpty).map((e) => "$e ").toList();

        if (mounted) {
          setState(() {
            _jpWords = jpSegments;
            _romajiWords = romajiSegments;
            _currentTranslations = {
              'English (EN)': "Translation of: \"$text\"",
              'Chinese (ZH)': "以下文字的翻译结果: \"$text\"",
              'Malay (MS)': "Terjemahan untuk: \"$text\""
            };
          });
        }
      } else {
        throw Exception("Server status code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("API Execution intercepted or failed: $e");
      String lowerInput = text.toLowerCase();
      String localJp = "翻訳のテスト";
      String localRm = "Hon'yaku no tesuto";

      if (lowerInput.contains("hello")) {
        localJp = "こんにちは"; localRm = "Konnichiwa";
      } else if (lowerInput.contains("thank you")) {
        localJp = "ありがとう"; localRm = "Arigatou";
      } else if (lowerInput.contains("what time")) {
        localJp = "仕事は何時にしますか"; localRm = "Shigoto wa nan-ji ni shimasu ka";
      }

      if (mounted) {
        setState(() {
          _jpWords = localJp.split('');
          _romajiWords = localRm.split(' ').map((e) => "$e ").toList();
          _currentTranslations = {
            'English (EN)': "Result of: \"$text\"",
            'Chinese (ZH)': "翻译结果为: \"$text\"",
            'Malay (MS)': "Keputusan untuk: \"$text\""
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 计算高亮进度百分比
    double progressFraction = _elapsedMilliseconds / _totalMockDurationMs;
    if (progressFraction > 1.0) progressFraction = 1.0;

    int currentJpIndex = -1;
    int currentRomajiIndex = -1;

    if (_isPlaying && _elapsedMilliseconds > 0) {
      // 🌟 核心机制修改：采用平滑的等比区间映射，确保日文和罗马音变色进度完美齐步走！
      currentJpIndex = (progressFraction * _jpWords.length).floor();
      currentRomajiIndex = (progressFraction * _romajiWords.length).floor();
      
      if (currentJpIndex >= _jpWords.length) currentJpIndex = _jpWords.length - 1;
      if (currentRomajiIndex >= _romajiWords.length) currentRomajiIndex = _romajiWords.length - 1;
    }

    bool isChinese = _selectedLanguage == 'Chinese (ZH)';
    bool isMalay = _selectedLanguage == 'Malay (MS)';

    String recommendedTitle = isChinese ? '💡 推荐基本用语 (点击可快速学习)' : (isMalay ? '💡 Ungkapan Disyorkan (Ketik untuk belajar)' : '💡 Recommended Phrases (Tap to learn)');
    String customInputTitle = isChinese ? '✍️ 自定义输入翻译去日语' : (isMalay ? '✍️ Terjemah apa sahaja ke Bahasa Jepun' : '✍️ Translate anything to Japanese');
    String hintText = isChinese ? '输入任何文字，开始翻译学习...' : (isMalay ? 'Taip apa sahaja untuk mula belajar...' : 'Type anything to start learning...');

    final List<Map<String, dynamic>> recommendedPhrases = [
      {
        "label": isChinese ? "👋 招呼：你好" : (isMalay ? "👋 Salam: Hello" : "👋 Greeting: Hello"),
        "jp": ["こんにちは"],
        "romaji": ["Konnichiwa"],
        "trans": {
          'English (EN)': "Hello",
          'Chinese (ZH)': "你好",
          'Malay (MS)': "Halo"
        }
      },
      {
        "label": isChinese ? "🙏 感恩：谢谢" : (isMalay ? "🙏 Penghargaan: Terima Kasih" : "🙏 Gratitude: Thank you"),
        "jp": ["ありがとう", "ございます"],
        "romaji": ["Arigatou ", "gozaimasu"],
        "trans": {
          'English (EN)': "Thank you very much",
          'Chinese (ZH)': "非常感谢",
          'Malay (MS)': "Terima kasih banyak"
        }
      },
      {
        "label": isChinese ? "✨ 经典：全集中训练" : (isMalay ? "✨ Klasik: Konsentrasi Penuh" : "✨ Classic: Total Concentration"),
        "jp": ["全集中！", "今日", "の稽古", "を始め", "ましょう！"],
        "romaji": ["Zen ", "shuu ", "chuu! ", "Kyou ", "no ", "keiko ", "o ", "hajimemashou!"],
        "trans": {
          'English (EN)': "Total concentration! Let's start today's training!",
          'Chinese (ZH)': "全神贯注！开始今天的训练吧！",
          'Malay (MS)': "Konsentrasi penuh! Mari mulakan latihan hari ini!"
        }
      }
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCharacter,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: const [
                        DropdownMenuItem(value: 'Tanjiro Kamado', child: Text('👤 Tanjiro Kamado')),
                        DropdownMenuItem(value: 'Luffy', child: Text('👤 Monkey D. Luffy')),
                        DropdownMenuItem(value: 'Nezuko', child: Text('👤 Nezuko Kamado')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCharacter = value;
                            _isNezukoSigning = false; 
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLanguage, 
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: const [
                        DropdownMenuItem(value: 'English (EN)', child: Text('🌐 English (EN)')),
                        DropdownMenuItem(value: 'Chinese (ZH)', child: Text('🌐 Chinese (ZH)')),
                        DropdownMenuItem(value: 'Malay (MS)', child: Text('🌐 Malay (MS)')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedLanguage = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 核心教学大白卡片
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16), 
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 日文展示
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: List.generate(_jpWords.length, (index) {
                            bool isActive = _isPlaying && (index == currentJpIndex);
                            return TextSpan(
                              text: _jpWords[index],
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.deepPurple : const Color(0xFFD6D6D6),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 罗马音展示
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            const TextSpan(text: "(", style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.teal)),
                            ...List.generate(_romajiWords.length, (index) {
                              bool isActive = _isPlaying && (index == currentRomajiIndex);
                              return TextSpan(
                                text: _romajiWords[index],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: isActive ? Colors.teal : Colors.teal.withOpacity(0.4),
                                ),
                              );
                            }),
                            const TextSpan(text: ")", style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.teal)),
                          ],
                        ),
                      ),
                      
                      // 🌟 手语卡片精准在翻译上方展开
                      if (_selectedCharacter == 'Nezuko' && _isNezukoSigning) ...[
                        const SizedBox(height: 16),
                        SignLanguageTranslator(
                          text: _currentTranslations['English (EN)'] ?? "",
                          isPlaying: _isNezukoSigning,
                          onComplete: () {
                            setState(() {
                              _isNezukoSigning = false; 
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 16),
                      Text(
                        _currentTranslations[_selectedLanguage] ?? _currentTranslations['English (EN)']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 10),
                IconButton(
                  iconSize: 32,
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_outline : Icons.volume_up,
                    color: Colors.teal, 
                  ),
                  onPressed: _togglePlay,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text(
            recommendedTitle,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recommendedPhrases.length,
            itemBuilder: (context, index) {
              final phrase = recommendedPhrases[index];
              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(phrase['label']!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text('${phrase['jp'].join('')} / ${phrase['trans'][_selectedLanguage]}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
                  onTap: () {
                    _stopPlayback();
                    setState(() {
                      _jpWords = List<String>.from(phrase['jp']);
                      _romajiWords = List<String>.from(phrase['romaji']);
                      _currentTranslations = Map<String, String>.from(phrase['trans']);
                    });
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          Text(
            customInputTitle,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _handleTranslate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.translate, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}