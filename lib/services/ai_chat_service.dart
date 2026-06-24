import 'package:flutter/foundation.dart'; 
import 'package:firebase_ai/firebase_ai.dart'; 

class AIChatService {
  
  // --------------------------------------------------------
  // 正常聊天功能保持不变
  // --------------------------------------------------------
  Future<String> getCharacterResponse(String message, String characterName) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3-flash-preview', 
      );

      final prompt = '''
      You are $characterName from anime. 
      You must respond to the user exactly in the tone, personality, and catchphrases of $characterName. 
      Keep your responses short, engaging, and conversational (1 to 3 sentences maximum).
      Do not break character. 
      
      User says: $message
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Sorry, I am speechless right now.";
      
    } catch (e) {
      debugPrint("Firebase AI Logic Error: $e");
      return "*looks confused* Connection error... Are you sure Firebase AI Logic is enabled in your console?";
    }
  }

  // --------------------------------------------------------
  // 终极修复版：强制逐字翻译，绝不加戏
  // --------------------------------------------------------
  Future<String> getTutorResponse(
      String topic, 
      String characterName, 
      String characterPersona, 
      bool isSignLanguage,
      String translationLanguage) async {
    
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3-flash-preview', 
      );

      String prompt;

      if (isSignLanguage) {
        prompt = '''
        You are $characterName.
        Task: Translate the phrase "[$topic]" into sign language actions.
        CRITICAL RULE: DO NOT add any extra meaning. Just describe the gesture for "[$topic]".
        
        Return strictly in this JSON format without markdown:
        {
          "japanese": "んー！ (Mmh!)", 
          "romaji": "(Describe the gesture accurately and concisely)",
          "translation": "Provide the exact translation in $translationLanguage"
        }
        ''';
      } else {
        prompt = '''
        Task: EXACTLY translate the user's phrase "[$topic]" into Japanese.
        
        CRITICAL RULES (ABSOLUTE OVERRIDE):
        1. LITERAL TRANSLATION ONLY. You MUST NOT add any new words, concepts, actions, or scenarios. 
        2. NO CATCHPHRASES. If the user says "I am sick", you translate "I am sick". DO NOT add things like "Total Concentration Breathing" or "I will become Pirate King".
        3. CHARACTER TONE: You are acting as $characterName. Apply their tone ONLY by changing pronouns (e.g., using 'Ore' instead of 'Watashi') and sentence endings (e.g., using polite 'desu/masu' for Tanjiro, or rough casual language for Luffy). DO NOT ADD EXTRA SENTENCES.
        
        Return strictly in this JSON format without markdown:
        {
          "japanese": "The exact Japanese translation using the character's specific pronouns and endings",
          "romaji": "(Romaji pronunciation)",
          "translation": "Translate '[$topic]' into $translationLanguage"
        }
        ''';
      }

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "{}";
      
    } catch (e) {
      debugPrint("Tutor AI Error: $e");
      throw Exception("Failed to fetch tutor response"); 
    }
  }
}