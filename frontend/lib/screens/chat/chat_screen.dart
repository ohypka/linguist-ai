import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> messages = [];
  final controller = TextEditingController();

  void send() {
    final text = controller.text.trim();
    if (text.isEmpty) return; // prevent sending empty messages

    controller.clear();

    setState(() {
      messages.add(Message(text: text, isUser: true));

      // TODO: replace with real API response
      messages.add(Message(
        text: "AI: Try to rephrase that sentence more naturally.",
        isUser: false,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Chat")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // newest messages at the bottom
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                // reverse index to display messages correctly
                final msg = messages[messages.length - 1 - index];
                return ChatBubble(message: msg);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Type something...",
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: send, // triggers message handling
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}