import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentient_alpha/data/yahoo.dart';
import 'package:sentient_alpha/state/book_controller.dart';
import 'package:sentient_alpha/theme.dart';
import 'package:sentient_alpha/widgets/common.dart';

class TrackTab extends ConsumerStatefulWidget {
  const TrackTab({super.key});

  @override
  ConsumerState<TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends ConsumerState<TrackTab> {
  final qCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final dateCtrl = TextEditingController();
  List<Map<String, dynamic>> hits = [];
  String? pickedTicker;
  String? pickedName;

  @override
  void dispose() {
    qCtrl.dispose();
    qtyCtrl.dispose();
    costCtrl.dispose();
    dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 1) {
      setState(() => hits = []);
      return;
    }
    try {
      final r = await ref.read(yahooProvider).search(q);
      setState(() => hits = r);
    } catch (_) {}
  }

  Future<void> _track() async {
    final book = ref.read(bookProvider);
    final ctrl = ref.read(bookProvider.notifier);
    final qty = double.tryParse(qtyCtrl.text.trim());
    final cost = double.tryParse(costCtrl.text.trim());
    final date = dateCtrl.text.trim().isEmpty ? null : dateCtrl.text.trim();
    final query = pickedTicker ?? qCtrl.text.trim();
    if (query.isEmpty) return;

    // Preview concentration if we can
    try {
      final y = ref.read(yahooProvider);
      final ticker = pickedTicker ?? ((await y.search(query)).firstOrNull?['ticker'] as String?) ?? query;
      final quote = await y.quote(ticker);
      final last = (quote['last'] as num?)?.toDouble() ?? 0;
      final warn = await ctrl.previewConcentration(ticker: ticker, qty: qty ?? 1, mark: last);
      if (warn != null && mounted) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Concentration'),
            content: Text(warn),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save anyway')),
            ],
          ),
        );
        if (ok != true) return;
      }
      await ctrl.addLot(
        queryOrTicker: query,
        qty: qty,
        cost: cost,
        buyDate: date,
        resolvedTicker: pickedTicker,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tracked $ticker · ${kDisclaimerShort}')),
      );
      qCtrl.clear();
      qtyCtrl.clear();
      costCtrl.clear();
      dateCtrl.clear();
      setState(() {
        hits = [];
        pickedTicker = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(bookProvider);
    final money = NumberFormat.currency(symbol: '${book.baseCcy} ');
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(bookProvider.notifier).refreshQuotes(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TerminalHeader(
              nav: money.format(book.nav),
              dayChange: '${book.uPnl >= 0 ? '+' : ''}${money.format(book.uPnl)} uPnL',
              pill: book.backendPill,
              asOf: book.lastQuoteAt,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qCtrl,
              decoration: const InputDecoration(
                hintText: 'Name or ticker · cost or buy date · we look up the rest',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            if (hits.isNotEmpty)
              Card(
                child: Column(
                  children: hits
                      .map(
                        (h) => ListTile(
                          dense: true,
                          title: Text(h['ticker'] as String, style: SA.mono()),
                          subtitle: Text('${h['name']} · ${h['exchange'] ?? ""}'),
                          onTap: () {
                            setState(() {
                              pickedTicker = h['ticker'] as String;
                              pickedName = h['name'] as String?;
                              qCtrl.text = pickedTicker!;
                              hits = [];
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Qty (optional)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cost (share or total)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dateCtrl,
              decoration: const InputDecoration(labelText: 'Buy date YYYY-MM-DD (optional)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: book.busy ? null : _track,
              child: Text(book.busy ? 'Working…' : 'Track with AI desk'),
            ),
            const SizedBox(height: 8),
            Text(kDisclaimerShort, style: SA.mono(size: 11, color: SA.muted)),
            const SizedBox(height: 20),
            Text('HOLDINGS', style: SA.mono(size: 12, color: SA.cyan)),
            const SizedBox(height: 8),
            if (book.lots.isEmpty)
              const Text('No lots yet. Search a name to begin.', style: TextStyle(color: SA.muted))
            else
              ...book.lots.map((l) {
                final stale = l.asOf != null &&
                    DateTime.now().toUtc().difference(l.asOf!).inMinutes >= 5;
                return Card(
                  child: ListTile(
                    title: Row(
                      children: [
                        Text(l.ticker, style: SA.mono(weight: FontWeight.w700)),
                        if (stale) ...[
                          const SizedBox(width: 8),
                          const Pill(label: 'STALE', color: SA.coral),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      'qty ${l.qty.toStringAsFixed(4)} · avg ${l.costPerShare.toStringAsFixed(2)} ${l.costCcy}\n'
                      '${l.inferenceNote ?? ""}',
                      style: SA.mono(size: 11, color: SA.muted),
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${l.uPnl >= 0 ? '+' : ''}${l.uPnl.toStringAsFixed(2)}',
                          style: SA.mono(
                            color: l.uPnl >= 0 ? SA.mint : SA.coral,
                            weight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${l.uPnlPct >= 0 ? '+' : ''}${l.uPnlPct.toStringAsFixed(2)}% · ${book.weightPct(l).toStringAsFixed(1)}%',
                          style: SA.mono(size: 10, color: SA.muted),
                        ),
                      ],
                    ),
                    onTap: () => ref.read(bookProvider.notifier).runDesk(l.ticker, forceLocal: true),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text('ALERTS', style: SA.mono(size: 12, color: SA.cyan)),
            ...book.alerts.take(10).map(
                  (a) => ListTile(
                    dense: true,
                    title: Text(a.title, style: SA.mono(size: 12)),
                    subtitle: Text(a.body, style: const TextStyle(color: SA.muted, fontSize: 12)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

extension<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
