import 'package:flutter_tts/flutter_tts.dart';

class AudioService {
  final FlutterTts _flutterTts = FlutterTts();

  AudioService() {
    _initTts();
  }

  // Configure the voice settings
  void _initTts() async {
    await _flutterTts.setLanguage("en-US"); // We will use English for now
    await _flutterTts.setSpeechRate(0.5);   // Speed of the voice
    await _flutterTts.setPitch(1.2);        // Slightly higher pitch for an anime feel
  }

  // Function to play the audio
  // Function to play the audio with character-specific voices
  Future<void> speak(String text, String characterName) async {
    await _flutterTts.stop(); // Stop any currently playing audio
    await _flutterTts.setVolume(9.8); // Set volume to 80%
    
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