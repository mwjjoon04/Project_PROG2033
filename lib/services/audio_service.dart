import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_session/audio_session.dart'; // 引入系统底层音频会话依赖包

class AudioService {
  final FlutterTts _flutterTts = FlutterTts();

  AudioService() {
    _initTts();
  }

  // Configure the voice settings
  void _initTts() async {
    // 初始化 TTS 音质前，先调用总指挥官配置，彻底理顺手机声卡通道
    await _configureAudioSession();

    await _flutterTts.setLanguage("ja-JP"); // 🌟 默认直接切换为地道的纯正日语发音引擎
    await _flutterTts.setSpeechRate(0.5);   // Speed of the voice
    await _flutterTts.setPitch(1.2);        // Slightly higher pitch for an anime feel
  }

  // 系统底层音频总指挥官配置函数
  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.assistanceAccessibility, 
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      ));
    } catch (e) {
      print("AudioSession 基础通道配置出错: $e");
    }
  }

  // 🌟 动态语言支持：增加 locale 参数，默认直接以日语 "ja-JP" 格式进行动漫配音
  Future<void> speak(String text, String characterName, {String locale = "ja-JP"}) async {
    await _flutterTts.stop(); // Stop any currently playing audio
    await _flutterTts.setVolume(1.0); // 100% 满额系统最大软件音量
    
    // 🌟 根据传入的指令，动态切换引擎语种（如日语 ja-JP 或英文 en-US）
    await _flutterTts.setLanguage(locale); 

    // Adjust the voice profile based on the character
    if (characterName == "Nezuko Kamado") {
      await _flutterTts.setPitch(1.8);      // High pitch
      await _flutterTts.setSpeechRate(0.4); // Slower, softer
    } else if (characterName == "Monkey D. Luffy") {
      await _flutterTts.setPitch(1.3);      // Slightly higher pitch
      await _flutterTts.setSpeechRate(0.6); // Fast and energetic
    } else {
      // Default / Tanjiro Kamado
      await _flutterTts.setPitch(1.0);      // Normal pitch
      await _flutterTts.setSpeechRate(0.5); // Normal speed
    }

    await _flutterTts.speak(text);
  }

  // Function to stop the audio manually if needed
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}