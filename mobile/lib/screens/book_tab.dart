import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentient_alpha/state/book_controller.dart';
import 'package:sentient_alpha/theme.dart';
import 'package:sentient_alpha/widgets/common.dart';

class BookTab extends ConsumerWidget {
  const BookTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookProvider);
    final money = NumberFormat.currency(symbol: '${book.baseCcy} ');
    final sorted = [...book.lots]..sort((a, b) => b.marketValue.compareTo(a.marketValue));
    final hhi = _hhi(book);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DisclaimerBanner(),
          Text('BOOK', style: SA.mono(size: 12, color: SA.cyan)),
          const SizedBox(height: 8),
          Text(money.format(book.nav), style: SA.mono(size: 28, weight: FontWeight.w700)),
          Text(
            'Cost ${money.format(book.cost)} · uPnL ${book.uPnl >= 0 ? '+' : ''}${money.format(book.uPnl)}',
            style: SA.mono(size: 12, color: SA.muted),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text('Cash', style: SA.mono()),
              trailing: Text(money.format(book.cash), style: SA.mono(weight: FontWeight.w700)),
              subtitle: const Text('Tap to edit cash balance'),
              onTap: () async {
                final ctrl = TextEditingController(text: book.cash.toString());
                final v = await showDialog<double>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cash (base)'),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
                if (v != null) await ref.read(bookProvider.notifier).setCash(v);
              },
            ),
          ),
          const SizedBox(height: 12),
          Text('RISK STRIP', style: SA.mono(size: 12, color: SA.cyan)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('HHI', hhi?.toStringAsFixed(3) ?? 'n/a'),
              _chip('Eff-N', hhi != null && hhi > 0 ? (1 / hhi).toStringAsFixed(2) : 'n/a'),
              _chip(
                'Top',
                sorted.isEmpty ? 'n/a' : '${book.weightPct(sorted.first).toStringAsFixed(1)}%',
              ),
              _chip('Cap', '${book.capPct.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 16),
          Text('ALLOCATION', style: SA.mono(size: 12, color: SA.cyan)),
          ...sorted.map(
            (l) => ListTile(
              dense: true,
              title: Text(l.ticker, style: SA.mono()),
              trailing: Text('${book.weightPct(l).toStringAsFixed(1)}%', style: SA.mono()),
              subtitle: LinearProgressIndicator(
                value: (book.weightPct(l) / 100).clamp(0, 1),
                color: book.weightPct(l) >= book.capPct ? SA.coral : SA.mint,
                backgroundColor: SA.hairline,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('SCENARIOS', style: SA.mono(size: 12, color: SA.cyan)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Each name −10%: ${money.format(_allDown(book))}',
                    style: SA.mono(size: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sorted.isEmpty
                        ? 'Largest −30%: n/a'
                        : 'Largest (${sorted.first.ticker}) −30%: ${money.format(sorted.first.marketValue * -0.30)}',
                    style: SA.mono(size: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(kDisclaimerShort, style: SA.mono(size: 10, color: SA.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String k, String v) => Chip(
        label: Text('$k $v', style: SA.mono(size: 11)),
        backgroundColor: SA.surface,
        side: const BorderSide(color: SA.hairline),
      );

  double? _hhi(BookState book) {
    if (book.nav <= 0) return null;
    var h = 0.0;
    for (final l in book.lots) {
      final w = l.marketValue / book.nav;
      h += w * w;
    }
    final cw = book.cash / book.nav;
    h += cw * cw;
    return h;
  }

  double _allDown(BookState book) {
    return book.lots.fold(0.0, (s, l) => s + l.marketValue * -0.10);
  }
}
