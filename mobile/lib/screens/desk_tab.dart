import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentient_alpha/state/book_controller.dart';
import 'package:sentient_alpha/theme.dart';
import 'package:sentient_alpha/widgets/common.dart';

class DeskTab extends ConsumerWidget {
  const DeskTab({super.key});

  static const seatOrder = [
    ('technicals', 'Technical'),
    ('fundamentals', 'Fundamentals'),
    ('sentiment', 'Sentiment'),
    ('news', 'News'),
    ('bull', 'Bull'),
    ('bear', 'Bear'),
    ('research_manager', 'Research Manager'),
    ('trader', 'Trader'),
    ('risk', 'Risk'),
    ('pm', 'Portfolio Manager'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookProvider);
    final tickers = book.lots.map((l) => l.ticker).toSet().toList()..sort();
    final selected = book.selectedTicker ?? (tickers.isNotEmpty ? tickers.first : null);
    final report = book.deskReport;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DisclaimerBanner(),
          Text('DESK', style: SA.mono(size: 12, color: SA.cyan)),
          const SizedBox(height: 8),
          if (tickers.isEmpty)
            const Text('Add a lot on Track first.', style: TextStyle(color: SA.muted))
          else
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: selected,
              items: tickers
                  .map((t) => DropdownMenuItem(value: t, child: Text(t, style: SA.mono())))
                  .toList(),
              onChanged: (t) {
                if (t != null) ref.read(bookProvider.notifier).runDesk(t, forceLocal: true);
              },
              decoration: const InputDecoration(labelText: 'Ticker'),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: selected == null || book.busy
                      ? null
                      : () => ref.read(bookProvider.notifier).runDesk(selected),
                  child: Text(book.busy ? 'Running…' : 'Run desk'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: selected == null || book.busy
                      ? null
                      : () => ref.read(bookProvider.notifier).runDesk(selected, forceLocal: true),
                  child: const Text('Local tape'),
                ),
              ),
            ],
          ),
          if (book.error != null) ...[
            const SizedBox(height: 8),
            Text(book.error!, style: SA.mono(size: 11, color: SA.coral)),
          ],
          if (report != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Pill(
                  label: report.source == 'tauric'
                      ? 'Tauric'
                      : report.source == 'cli'
                          ? 'CLI'
                          : 'Local tape',
                  color: report.source == 'tauric' ? SA.mint : SA.cyan,
                ),
                const SizedBox(width: 8),
                Text(report.rating, style: SA.mono(size: 18, weight: FontWeight.w700, color: _ratingColor(report.rating))),
                const Spacer(),
                Text(
                  'score ${report.score.toStringAsFixed(0)}${report.scoreDerived ? '*' : ''}',
                  style: SA.mono(color: SA.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(kDisclaimerShort, style: SA.mono(size: 11, color: SA.muted)),
            const SizedBox(height: 12),
            ...seatOrder.map((s) {
              final body = report.seats[s.$1] ?? '';
              if (body.isEmpty) return const SizedBox.shrink();
              return ExpansionTile(
                title: Text(s.$2, style: SA.mono(weight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(body, style: const TextStyle(height: 1.4)),
                    ),
                  ),
                ],
              );
            }),
            if (report.finalDecision != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Final: ${report.finalDecision}', style: SA.mono()),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _ratingColor(String r) {
    final t = r.toLowerCase();
    if (t.contains('buy') || t.contains('over')) return SA.mint;
    if (t.contains('sell') || t.contains('under')) return SA.coral;
    return SA.cyan;
  }
}
