import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/position.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

void openStock(BuildContext context, AppState state, String ticker) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => StockDetailScreen(state: state, ticker: ticker),
    ),
  );
}

class StockDetailScreen extends StatelessWidget {
  const StockDetailScreen({super.key, required this.state, required this.ticker});
  final AppState state;
  final String ticker;

  @override
  Widget build(BuildContext context) {
    final q = state.quoteOf(ticker);
    final holding = state.holdings.cast<Holding?>().firstWhere(
          (h) => h!.ticker == ticker,
          orElse: () => null,
        );
    final desk = state.desks[ticker];
    final px = q?.price ?? holding?.avgCost ?? 0;
    final ch = q?.changePct ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(ticker),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Pill(q == null ? 'CACHED' : 'YAHOO', color: SA.cyan),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(q?.name ?? holding?.name ?? ticker, style: const TextStyle(color: SA.muted)),
          const SizedBox(height: 8),
          AlphaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LAST',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    color: SA.muted,
                    letterSpacing: 0.6,
                  ),
                ),
                Row(
                  children: [
                    Mono(px.toStringAsFixed(2), size: 28, weight: FontWeight.w700),
                    const SizedBox(width: 8),
                    Mono(signedPct(ch), size: 14, color: dirColor(ch)),
                  ],
                ),
                if (q != null && q.sparkline.length > 1) ...[
                  const SizedBox(height: 8),
                  Sparkline(values: q.sparkline, color: dirColor(ch), height: 64),
                ],
              ],
            ),
          ),
          if (holding != null) ...[
            const SizedBox(height: 12),
            AlphaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your lot', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    '${fmtQty(holding.shares)} shares  ·  cost ${money(holding.avgCost)}  ·  value ${money(px * holding.shares)}',
                    style: const TextStyle(color: SA.muted),
                  ),
                  Mono(
                    money((px - holding.avgCost) * holding.shares),
                    size: 18,
                    color: dirColor(px - holding.avgCost),
                  ),
                  if (holding.note.isNotEmpty)
                    Text(holding.note, style: const TextStyle(color: SA.mint, fontSize: 12)),
                ],
              ),
            ),
          ],
          if (desk != null) ...[
            const SizedBox(height: 12),
            AlphaCard(
              accent: recColor(desk.rating.rec),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ScoreRing(score: desk.score, size: 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Pill(desk.rating.label, color: recColor(desk.rating.rec)),
                            Text(
                              desk.source == 'tauric' ? 'Tauric TradingAgents' : 'Local Tauric seats',
                              style: const TextStyle(color: SA.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(desk.pm, style: const TextStyle(height: 1.4, fontSize: 13, color: SA.muted)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Run desk',
            icon: Icons.apartment,
            onPressed: () async {
              await state.runDesk(ticker);
              if (!context.mounted) return;
              state.setTab(1);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
