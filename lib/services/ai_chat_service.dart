import 'package:firebase_ai/firebase_ai.dart'; // 导入正确的包

class AIChatService {
  Future<String> getCharacterResponse(String message, String characterName) async {
    try {
      // 🌟 核心魔法：使用 googleAI() 明确指定走【免费】的 Developer API 路线！
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

      // 发送请求给 Firebase AI Logic
      final response = await model.generateContent([Content.text(prompt)]);

      return response.text ?? "Sorry, I am speechless right now.";
      
    } catch (e) {
      print("Firebase AI Logic Error: $e");
      return "*looks confused* Connection error... Are you sure Firebase AI Logic is enabled in your console?";
    }
  }
}