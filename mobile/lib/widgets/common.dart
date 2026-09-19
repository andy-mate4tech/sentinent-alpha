import 'package:flutter/material.dart';
import 'package:sentient_alpha/theme.dart';

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.color = SA.mint});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(label, style: SA.mono(size: 10, color: color, weight: FontWeight.w700)),
    );
  }
}

class TerminalHeader extends StatelessWidget {
  const TerminalHeader({
    super.key,
    required this.nav,
    required this.dayChange,
    required this.pill,
    this.asOf,
  });

  final String nav;
  final String dayChange;
  final String pill;
  final DateTime? asOf;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SENTIENT ALPHA', style: SA.mono(size: 14, weight: FontWeight.w700, color: SA.mint)),
              Text('RESEARCH TERMINAL · NOT ADVICE', style: SA.mono(size: 10, color: SA.cyan)),
              const SizedBox(height: 8),
              Text(nav, style: SA.mono(size: 22, weight: FontWeight.w700)),
              Text(dayChange, style: SA.mono(size: 12, color: SA.muted)),
              if (asOf != null)
                Text('as-of ${asOf!.toLocal()}', style: SA.mono(size: 10, color: SA.muted)),
            ],
          ),
        ),
        Pill(
          label: pill,
          color: pill.contains('RUNNING')
              ? SA.cyan
              : pill.contains('TAURIC')
                  ? SA.mint
                  : SA.muted,
        ),
      ],
    );
  }
}

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: SA.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(kDisclaimerShort, style: SA.mono(size: 11, color: SA.muted)),
    );
  }
}
