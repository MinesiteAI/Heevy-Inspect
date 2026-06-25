import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analytics/inspect_analytics.dart';
import '../../theme/app_colors.dart';
import '../../widgets/heevy_ui.dart';
import 'field_chat_service.dart';

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}

class FieldGuideScreen extends StatefulWidget {
  const FieldGuideScreen({
    super.key,
    this.sourceType,
    this.sourceId,
  });

  final String? sourceType;
  final String? sourceId;

  @override
  State<FieldGuideScreen> createState() => _FieldGuideScreenState();
}

class _FieldGuideScreenState extends State<FieldGuideScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  String? _conversationId;
  bool _sending = false;

  FieldChatService get _chat => FieldChatService(Supabase.instance.client);

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
    });
    _scrollToEnd();
    try {
      final result = await _chat.sendMessage(
        message: text,
        conversationId: _conversationId,
        sourceType: widget.sourceType,
        sourceId: widget.sourceId,
      );
      _conversationId = result.conversationId ?? _conversationId;
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: result.reply, isUser: false));
      });
      await InspectAnalytics.track('field_chat_message');
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: e.toString().replaceFirst('Exception: ', ''),
          isUser: false,
        ));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: const HeevyBrandedAppBar(title: 'Field guide'),
      body: Column(
        children: [
          if (widget.sourceType != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Context: ${widget.sourceType}',
                style: TextStyle(
                  color: AppColors.textFaint(context),
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Ask about your captures, PMs, work orders, or general maintenance terms.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted(context),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _SuggestionChip(
                              label: 'What is an idler?',
                              onTap: () => _send('What is an idler?'),
                            ),
                            _SuggestionChip(
                              label: 'Leaking seal tips',
                              onTap: () => _send('How do I diagnose a leaking seal?'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                          ),
                        );
                      }
                      final m = _messages[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: m.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.82,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: m.isUser
                                  ? AppColors.surfaceAlt(context)
                                  : AppColors.surface(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border(context),
                              ),
                            ),
                            child: Text(
                              m.text,
                              style: TextStyle(
                                color: AppColors.text(context),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _controller,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          hintText: 'Ask the field guide…',
                          hintStyle: TextStyle(
                            color: AppColors.textFaint(context),
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : () => _send(),
                    icon: Icon(Icons.send, color: AppColors.text(context)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.surface(context),
      labelStyle: TextStyle(color: AppColors.textMuted(context)),
    );
  }
}
