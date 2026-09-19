import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentient_alpha/state/book_controller.dart';
import 'package:sentient_alpha/theme.dart';
import 'package:sentient_alpha/widgets/common.dart';

class CopilotTab extends ConsumerStatefulWidget {
  const CopilotTab({super.key});

  @override
  ConsumerState<CopilotTab> createState() => _CopilotTabState();
}

class _CopilotTabState extends ConsumerState<CopilotTab> {
  final ctrl = TextEditingController();
  final messages = <({bool user, String text})>[];
  bool busy = false;

  static const chips = [
    'How is my book?',
    'What moved today?',
    'Am I too concentrated?',
    'What if largest −30%?',
  ];

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      messages.add((user: true, text: text.trim()));
      busy = true;
    });
    final reply = await ref.read(bookProvider.notifier).copilot(text.trim());
    setState(() {
      messages.add((user: false, text: reply));
      busy = false;
      ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: DisclaimerBanner(),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: chips
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(label: Text(c, style: SA.mono(size: 11)), onPressed: () => _send(c)),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                return Align(
                  alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(
                      color: m.user ? SA.mint.withValues(alpha: 0.15) : SA.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SA.hairline),
                    ),
                    child: Text(m.text, style: TextStyle(color: SA.text, height: 1.4)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(hintText: 'Ask about your book…'),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: busy ? null : () => _send(ctrl.text),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
