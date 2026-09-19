import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../data/position.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'shell.dart';
import 'stock_detail.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key, required this.state});
  final AppState state;

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _query = TextEditingController();
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  DateTime? _buyDate;
  List<SearchHit> _hits = [];
  SearchHit? _picked;

  @override
  void dispose() {
    _query.dispose();
    _qty.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    try {
      final hits = await widget.state.lookup(q);
      setState(() {
        _hits = hits;
        _picked = hits.isEmpty ? null : hits.first;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _add() async {
    await widget.state.addHolding(
      query: _query.text,
      chosen: _picked,
      shares: double.tryParse(_qty.text.trim().replaceAll(',', '')),
      cost: double.tryParse(_cost.text.trim().replaceAll(',', '')),
      buyDate: _buyDate,
    );
    if (!mounted) return;
    if (widget.state.error == null) {
      _qty.clear();
      _cost.clear();
      setState(() {
        _buyDate = null;
        _hits = [];
        _picked = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          TerminalHeader(
            state: s,
            title: 'Sentient Alpha',
            subtitle: 'NO LOGIN  ·  YAHOO + TAURIC DESK',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Open the app, type a stock, add cost or the day you bought it. The desk looks up the print and keeps watching.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AlphaCard(
              accent: SA.mint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BOOK VALUE',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: SA.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Mono(money(s.equityValue), size: 28, weight: FontWeight.w700),
                  Mono(
                    '${money(s.unrealizedTotal)}  (${s.costValue == 0 ? '0.00%' : signedPct(s.costValue == 0 ? 0 : s.unrealizedTotal / s.costValue * 100)})  vs cost',
                    size: 12,
                    color: dirColor(s.unrealizedTotal),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AlphaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add a lot', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'Name or ticker. Cost per share, total dollars, or a buy date (historical close). Quantity optional — the desk infers it when the cash figure looks like a total.',
                    style: TextStyle(color: SA.muted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Stock name or ticker',
                      hintText: 'NVDA  ·  Apple  ·  RELIANCE.NS',
                    ),
                    onSubmitted: (_) => _search(),
                    onChanged: (_) {
                      if (_picked != null) setState(() => _picked = null);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qty,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Quantity'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _cost,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cost / total \$',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _buyDate ?? now,
                              firstDate: DateTime(1990),
                              lastDate: now,
                            );
                            if (picked != null) setState(() => _buyDate = picked);
                          },
                          icon: const Icon(Icons.event, size: 16),
                          label: Text(
                            _buyDate == null
                                ? 'Buy date (optional)'
                                : DateFormat.yMMMd().format(_buyDate!),
                          ),
                        ),
                      ),
                      if (_buyDate != null)
                        IconButton(
                          onPressed: () => setState(() => _buyDate = null),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                    ],
                  ),
                  if (_hits.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _hits.take(6).map((h) {
                        final on = _picked?.ticker == h.ticker;
                        return ChoiceChip(
                          label: Text('${h.ticker}  ${h.exchange}'),
                          selected: on,
                          onSelected: (_) => setState(() => _picked = h),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: s.busy ? 'Looking up…' : 'Track with AI desk',
                    icon: Icons.search,
                    onPressed: s.busy ? null : _add,
                  ),
                  if (s.error != null) ...[
                    const SizedBox(height: 8),
                    Text(s.error!, style: const TextStyle(color: SA.coral, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          if (s.alerts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Monitor', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...s.alerts.take(3).map(
              (a) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AlphaCard(
                  padding: const EdgeInsets.all(12),
                  accent: a.tone == 'warn' ? SA.coral : SA.mint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Text(a.time, style: const TextStyle(color: SA.muted, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(a.body, style: const TextStyle(color: SA.muted, fontSize: 12, height: 1.35)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              s.holdings.isEmpty ? 'Holdings' : 'Holdings  ·  ${s.holdings.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (s.holdings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AlphaCard(
                child: Text(
                  'Empty book. Add NVDA, a name like Apple, or an exchange ticker such as 7203.T. No account required.',
                  style: TextStyle(color: SA.muted, height: 1.4),
                ),
              ),
            )
          else
            ...s.holdings.map((h) {
              final q = s.quoteOf(h.ticker);
              final px = q?.price ?? h.avgCost;
              final value = px * h.shares;
              final u = (px - h.avgCost) * h.shares;
              final desk = s.desks[h.ticker];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: AlphaCard(
                  onTap: () => openStock(context, s, h.ticker),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: SA.surface2,
                            child: Text(h.ticker.substring(0, 1)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(h.ticker, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 6),
                                    if (desk != null)
                                      Pill(desk.rating.label, color: recColor(desk.rating.rec)),
                                  ],
                                ),
                                Text(
                                  h.name,
                                  style: const TextStyle(color: SA.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => s.removeHolding(h.id),
                            icon: const Icon(Icons.close, size: 16, color: SA.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (q != null && q.sparkline.length > 1)
                        Sparkline(
                          values: q.sparkline,
                          color: dirColor(q.changePct),
                          height: 36,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Mono(money(value), size: 18, weight: FontWeight.w700)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Mono(money(u), size: 13, color: dirColor(u)),
                              Text(
                                signedPct((px / h.avgCost - 1) * 100),
                                style: TextStyle(color: dirColor(u), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fmtQty(h.shares)} shares  ·  Avg ${money(h.avgCost)}  ·  Mkt ${money(px)}'
                        '${q == null ? '' : '  (${signedPct(q.changePct)})'}',
                        style: const TextStyle(color: SA.muted, fontSize: 11),
                      ),
                      if (h.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(h.note, style: const TextStyle(color: SA.mint, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
