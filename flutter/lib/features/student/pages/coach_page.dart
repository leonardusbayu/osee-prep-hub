import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:osee_prep_hub/design/tokens.dart';
import 'package:osee_prep_hub/design/components.dart';

/// Coach (tutor) chat page — T10 (Wave 2).
///
/// Magazine-styled chat UI. Sends messages to POST /api/coach/sessions/:id/messages.
class CoachPage extends ConsumerStatefulWidget {
  const CoachPage({super.key, this.sessionId});

  /// If null, starts a new session on first send.
  final String? sessionId;

  @override
  ConsumerState<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends ConsumerState<CoachPage> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String? _sessionId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    if (_sessionId != null) {
      _loadHistory(_sessionId!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory(String sessionId) async {
    // TODO: fetch from API client
    // Mock welcome message for now.
    setState(() {
      _messages.add(_ChatMessage(
        role: 'assistant',
        content: "Hi! I'm your OSEE Coach. What can we work on today?",
      ));
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _controller.clear();
      _loading = true;
    });

    // TODO: actual API call.
    // Mock response for skeleton.
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _messages.add(_ChatMessage(
        role: 'assistant',
        content: 'Good question! Let me think... (T10 Coach skeleton — connect to POST /api/coach/sessions/:id/messages)',
      ));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: MagazineColors.paperCream,
      ),
      backgroundColor: MagazineColors.paperCream,
      body: Column(
        children: [
          const _CoachMasthead(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(MagazineSpacing.base),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _MessageBubble(message: _messages[i]),
            ),
          ),
          if (_loading) const _TypingIndicator(),
          _Composer(controller: _controller, onSend: _send, loading: _loading),
        ],
      ),
    );
  }
}

class _CoachMasthead extends StatelessWidget {
  const _CoachMasthead();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MagazineSpacing.base, vertical: MagazineSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MagazineColors.mastheadGold, width: 1.5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI TUTOR', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: MagazineColors.mastheadGold,
          )),
          SizedBox(height: 4),
          Text("Let's make today count.", style: TextStyle(
            fontSize: 18, fontFamily: 'Georgia', fontWeight: FontWeight.w700, color: MagazineColors.inkBlack,
          )),
        ],
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.role, required this.content});
  final String role;
  final String content;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MagazineSpacing.sm),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: MagazineColors.mastheadGold,
              child: Text('C', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: MagazineSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(MagazineSpacing.md),
              decoration: BoxDecoration(
                color: isUser ? MagazineColors.mastheadGold.withValues(alpha: 0.1) : Colors.white,
                border: Border.all(
                  color: isUser ? MagazineColors.mastheadGold : MagazineColors.surfaceMuted,
                  width: 1,
                ),
              ),
              child: Text(message.content, style: magazineBody()),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: MagazineSpacing.sm),
            const CircleAvatar(
              radius: 16,
              backgroundColor: MagazineColors.dropCapBlue,
              child: Text('U', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MagazineSpacing.base),
      child: Row(
        children: [
          const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: MagazineColors.mastheadGold),
          ),
          const SizedBox(width: MagazineSpacing.sm),
          Text('Coach is thinking...', style: magazineCaption()),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.loading});
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MagazineSpacing.base),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MagazineColors.mastheadGold, width: 1)),
        color: MagazineColors.paperCream,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ask your coach...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              style: magazineBody(),
            ),
          ),
          const SizedBox(width: MagazineSpacing.sm),
          IconButton(
            icon: Icon(Icons.send, color: loading ? Colors.grey : MagazineColors.mastheadGold),
            onPressed: loading ? null : onSend,
          ),
        ],
      ),
    );
  }
}