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

    await _flutterTts.setLanguage("en-US"); // We will use English for now
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
        // For Android: tells the OS this stream is speech, avoiding standard media ducking mix-ups
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.assistanceAccessibility, // 🌟 修复完成：已更正为官方正确的底层枚举名，红线彻底消除！
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      ));
    } catch (e) {
      print("AudioSession 基础通道配置出错: $e");
    }
  }

  // Function to play the audio
  // Function to play the audio with character-specific voices
  Future<void> speak(String text, String characterName) async {
    await _flutterTts.stop(); // Stop any currently playing audio
    await _flutterTts.setVolume(0.9); // Set volume to 90% (保持你最初代码的 0.9)

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