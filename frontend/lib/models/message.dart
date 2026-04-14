class Message {
  final String text;
  final bool isUser; // true = user message, false = AI response

  Message({required this.text, required this.isUser});
}