import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentient_alpha/state/book_controller.dart';
import 'package:sentient_alpha/theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  String ccy = 'USD';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: step == 0
              ? _disclaimer()
              : step == 1
                  ? _currency()
                  : _ready(),
        ),
      ),
    );
  }

  Widget _disclaimer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SENTIENT ALPHA', style: SA.mono(size: 22, weight: FontWeight.w700, color: SA.mint)),
        const SizedBox(height: 4),
        Text('RESEARCH TERMINAL · NOT ADVICE', style: SA.mono(size: 12, color: SA.cyan)),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Text(kDisclaimer, style: const TextStyle(height: 1.45, color: SA.text)),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => step = 1),
          child: const Text('I understand — continue'),
        ),
      ],
    );
  }

  Widget _currency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Base currency', style: SA.mono(size: 18, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Optional. Risk questionnaire can wait — skip anytime.', style: TextStyle(color: SA.muted)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: ['USD', 'INR', 'EUR', 'JPY', 'HKD', 'GBP']
              .map(
                (c) => ChoiceChip(
                  label: Text(c),
                  selected: ccy == c,
                  onSelected: (_) => setState(() => ccy = c),
                ),
              )
              .toList(),
        ),
        const Spacer(),
        TextButton(onPressed: () => setState(() => step = 2), child: const Text('Skip')),
        ElevatedButton(
          onPressed: () async {
            await ref.read(storeProvider).setMeta('base_currency', ccy);
            setState(() => step = 2);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _ready() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add your first lot', style: SA.mono(size: 18, weight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text(
          'Name or ticker · cost or buy date · we look up the rest',
          style: TextStyle(color: SA.muted),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () => ref.read(bookProvider.notifier).acceptDisclaimer(),
          child: const Text('Open Track'),
        ),
      ],
    );
  }
}
