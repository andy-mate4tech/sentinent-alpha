import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'shell.dart';

class DeskScreen extends StatefulWidget {
  const DeskScreen({super.key, required this.state});
  final AppState state;

  @override
  State<DeskScreen> createState() => _DeskScreenState();
}

class _DeskScreenState extends State<DeskScreen> {
  String? _ticker;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final tickers = s.holdings.map((h) => h.ticker).toSet().toList();
    final selected = tickers.contains(_ticker)
        ? _ticker
        : (tickers.isEmpty ? null : tickers.first);
    final report = selected == null ? null : s.desks[selected];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          TerminalHeader(
            state: s,
            title: 'Trading desk',
            subtitle: s.backendUrl.isEmpty
                ? 'LOCAL TAURIC SEATS  ·  YAHOO TAPE'
                : 'TRADINGAGENTS BACKEND',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AlphaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Same seats as TauricResearch/TradingAgents: analysts, bull/bear, trader, risk, portfolio manager. On this phone they run as a local tape desk. Point About at a Python backend to call TradingAgentsGraph.propagate(ticker, date).',
                    style: TextStyle(color: SA.muted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  if (tickers.isEmpty)
                    const Text('Add a lot on Track first.', style: TextStyle(color: SA.muted))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tickers.map((t) {
                        return ChoiceChip(
                          label: Text(t),
                          selected: t == selected,
                          onSelected: (_) => setState(() => _ticker = t),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: s.busy
                        ? 'Desk is working…'
                        : selected == null
                            ? 'Run desk'
                            : 'Run desk on $selected',
                    icon: Icons.account_balance,
                    onPressed: s.busy || selected == null ? null : () => s.runDesk(selected),
                  ),
                ],
              ),
            ),
          ),
          if (report != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AlphaCard(
                accent: recColor(report.rating.rec),
                child: Row(
                  children: [
                    ScoreRing(score: report.score, size: 64),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report.ticker, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                          Pill(report.rating.label, color: recColor(report.rating.rec)),
                          const SizedBox(height: 4),
                          Text(
                            report.source == 'tauric'
                                ? 'Source: Tauric TradingAgents'
                                : 'Source: local desk (Yahoo)',
                            style: const TextStyle(color: SA.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _seat('Technical analyst', report.technicals),
            _seat('Fundamentals analyst', report.fundamentals),
            _seat('Sentiment analyst', report.sentiment),
            _seat('News analyst', report.news),
            _seat('Bull researcher', report.bull),
            _seat('Bear researcher', report.bear),
            _seat('Trader', report.trader),
            _seat('Risk committee', report.risk),
            _seat('Portfolio manager', report.pm),
          ],
        ],
      ),
    );
  }

  Widget _seat(String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AlphaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: SA.cyan)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(height: 1.4, fontSize: 13, color: SA.muted)),
          ],
        ),
      ),
    );
  }
}
