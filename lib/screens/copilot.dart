import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'shell.dart';

class CopilotScreen extends StatefulWidget {
  const CopilotScreen({super.key, required this.state});
  final AppState state;

  @override
  State<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _input.text;
    _input.clear();
    await widget.state.sendChat(text);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 240,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final ctx = s.holdings.isEmpty ? 'Empty book' : s.holdings.map((h) => h.ticker).join(' · ');
    return SafeArea(
      child: Column(
        children: [
          TerminalHeader(
            state: s,
            title: 'Copilot',
            subtitle: 'BOOK + LAST DESK PASS',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AlphaCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Active context', style: TextStyle(color: SA.muted, fontSize: 11)),
                        Text(ctx, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Pill(s.backendUrl.isEmpty ? 'Local desk' : 'Tauric', color: SA.cyan),
                  IconButton(
                    onPressed: s.resetChat,
                    icon: const Icon(Icons.refresh, color: SA.muted, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _ask('How does Tauric work here?'),
                if (s.holdings.isNotEmpty) _ask('How is ${s.holdings.first.ticker} doing?'),
                _ask('What is on my book?'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: s.messages.length + (s.typing ? 1 : 0),
              itemBuilder: (context, i) {
                if (s.typing && i == s.messages.length) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Desk copilot  ·  reading the book',
                      style: TextStyle(color: SA.cyan, fontSize: 11),
                    ),
                  );
                }
                return _bubble(s.messages[i]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ask about a lot, P/L, or the desk',
                      filled: true,
                      fillColor: SA.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: SA.lineStrong),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: SA.mint,
                  child: IconButton(
                    onPressed: s.typing ? null : _send,
                    icon: const Icon(Icons.arrow_upward, color: SA.canvas, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ask(String t) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(t, style: const TextStyle(fontSize: 12)),
        backgroundColor: SA.surface,
        side: const BorderSide(color: SA.lineStrong),
        onPressed: widget.state.typing ? null : () => _send(t),
      ),
    );
  }

  Widget _bubble(ChatMsg m) {
    final mine = m.fromUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF123C32) : SA.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: mine ? SA.mint.withValues(alpha: 0.35) : SA.lineStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Desk copilot',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    color: SA.cyan,
                  ),
                ),
              ),
            Text(m.text, style: const TextStyle(height: 1.4, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
