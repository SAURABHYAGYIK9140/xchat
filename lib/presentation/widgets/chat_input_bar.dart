import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSendMessage;
  final ValueChanged<bool> onTypingChanged;

  const ChatInputBar({
    super.key,
    required this.onSendMessage,
    required this.onTypingChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _controller.text;
    final hasContent = text.trim().isNotEmpty;
    if (hasContent != _hasText) {
      setState(() => _hasText = hasContent);
      widget.onTypingChanged(hasContent);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSendMessage(text);
    _controller.clear();
    setState(() => _hasText = false);
    widget.onTypingChanged(false);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: const Color(0xFFF0F2F5),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Input container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.inputBorder, width: 0.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.sentiment_satisfied_alt_outlined, color: AppColors.textSecondary, size: 22),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSend(),
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 15),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          filled: false,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary, size: 22),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Circular Send Button
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              elevation: 1,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _hasText ? _handleSend : null,
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(
                    _hasText ? Icons.send_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

