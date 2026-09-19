import 'models.dart';
import 'position.dart';

String replyFor(
  String raw, {
  required List<Holding> holdings,
  required Map<String, Quote> quotes,
  required Map<String, DeskReport> desks,
}) {
  final q = raw.trim();
  if (q.isEmpty) {
    return 'Ask about a ticker on your book, or paste a name to look up.';
  }
  final upper = q.toUpperCase();
  Holding? hit;
  for (final h in holdings) {
    if (upper.contains(h.ticker.toUpperCase()) ||
        q.toLowerCase().contains(h.name.toLowerCase().split(' ').first)) {
      hit = h;
      break;
    }
  }
  if (hit == null && holdings.length == 1) hit = holdings.first;

  if (upper.contains('HOW') && (upper.contains('WORK') || upper.contains('TAURIC'))) {
    return 'This APK is a no-login tracker.\n\n'
        '1. You type a name or ticker plus cost or buy date.\n'
        '2. Yahoo Finance search + chart fill identity, last price, and (if you gave a date) historical close.\n'
        '3. A local desk walks the same seats as Tauric Research TradingAgents — technicals, fundamentals, sentiment, news, bull/bear, trader, risk, PM — using the tape, not LangGraph.\n'
        '4. Quotes refresh about every 45s so the lot is monitored.\n\n'
        'The real TradingAgents firm is Python + LLM keys. Paste a backend URL in About to swap the local desk for TradingAgentsGraph.propagate(ticker, date). Research only, not advice.';
  }

  if (hit != null) {
    final px = quotes[hit.ticker];
    final desk = desks[hit.ticker];
    final mark = px?.price;
    final pnl = mark == null ? null : (mark - hit.avgCost) * hit.shares;
    final pnlPct = mark == null ? null : (mark / hit.avgCost - 1) * 100;
    final buf = StringBuffer()
      ..writeln('${hit.ticker} · ${hit.name}')
      ..writeln(
        '${fmtQty(hit.shares)} shares  ·  cost ${hit.avgCost.toStringAsFixed(2)}'
        '${hit.buyDate != null ? '  ·  bought ${hit.buyDate!.toIso8601String().split('T').first}' : ''}',
      );
    if (mark != null) {
      buf.writeln(
        'Mark ${mark.toStringAsFixed(2)} (${px!.changePct >= 0 ? '+' : ''}${px.changePct.toStringAsFixed(2)}%)  ·  '
        'uPnL ${pnl!.toStringAsFixed(2)} (${pnlPct!.toStringAsFixed(2)}%)',
      );
    } else {
      buf.writeln('Quote not in yet — pull-to-refresh or wait for the monitor tick.');
    }
    if (desk != null) {
      buf
        ..writeln()
        ..writeln(
          'Desk ${desk.source == 'tauric' ? 'Tauric TradingAgents' : 'local (Tauric seats, Yahoo tape)'}  ·  '
          '${desk.rating.label}  ·  ${desk.score}/100',
        )
        ..writeln(desk.pm);
    } else {
      buf.writeln('\nNo desk pass yet. Open the Desk tab and run it on ${hit.ticker}.');
    }
    buf.writeln('\nInformational only — not a trade instruction.');
    return buf.toString();
  }

  if (holdings.isEmpty) {
    return 'Nothing on the book yet. Open Track, type a ticker or company name, and add cost or a buy date. The desk will look up last/historical price and keep the quote live.';
  }

  final lines = holdings.map((h) {
    final px = quotes[h.ticker];
    final desk = desks[h.ticker];
    final mark = px?.price;
    final u = mark == null ? '—' : '${((mark / h.avgCost - 1) * 100).toStringAsFixed(2)}%';
    return '• ${h.ticker}  ${fmtQty(h.shares)} sh  cost ${h.avgCost.toStringAsFixed(2)}  mark ${mark?.toStringAsFixed(2) ?? '…'}  $u'
        '${desk != null ? '  ·  ${desk.rating.label}' : ''}';
  });
  return 'Your monitored book:\n${lines.join('\n')}\n\nAsk about a ticker, or open Desk for the full Tauric-style pass.';
}

List<ChatMsg> seedThread(List<Holding> holdings) {
  if (holdings.isEmpty) {
    return const [
      ChatMsg(
        fromUser: false,
        time: 'Now',
        text:
            'No sign-in. Add a ticker on Track (name or id, plus cost or buy date). I will look up the print on Yahoo and keep monitoring the lot. Desk runs the Tauric seats locally until you attach the Python backend.',
      ),
    ];
  }
  final names = holdings.map((h) => h.ticker).join(', ');
  return [
    ChatMsg(
      fromUser: false,
      time: 'Now',
      text:
          'Monitoring $names. Ask for P/L, the last desk rating, or how Tauric Research wires in. Quotes refresh on their own.',
    ),
  ];
}
