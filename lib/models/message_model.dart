class Message {
  // 1. The properties (variables) that make up a single chat message
  final String text;
  final bool isUser; // If true, the user sent it. If false, the anime character sent it.
  final DateTime timestamp;

  // 2. The constructor (how we build a new Message object)
  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}