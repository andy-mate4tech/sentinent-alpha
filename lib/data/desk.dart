import 'dart:math';

import 'models.dart';

class TechSnapshot {
  const TechSnapshot({
    required this.rsi,
    required this.sma20,
    required this.ret6m,
    required this.vol,
    required this.rangePct,
  });

  final double? rsi;
  final double? sma20;
  final double ret6m;
  final double vol;
  final double rangePct;
}

TechSnapshot techFrom(List<double> closes, double last) {
  final series = [...closes];
  if (series.isEmpty || series.last != last) {
    series.add(last);
  }
  final first = series.first;
  final ret = first == 0 ? 0.0 : last / first - 1;
  final rets = <double>[];
  for (var i = 1; i < series.length; i++) {
    if (series[i - 1] != 0) rets.add(series[i] / series[i - 1] - 1);
  }
  final vol = _stdev(rets);
  final sma = series.length >= 20
      ? series.sublist(series.length - 20).reduce((a, b) => a + b) / 20
      : (series.isEmpty ? null : series.reduce((a, b) => a + b) / series.length);
  final hi = series.reduce(max);
  final lo = series.reduce(min);
  final rangePct = hi == lo ? 0.5 : (last - lo) / (hi - lo);
  return TechSnapshot(
    rsi: _rsi(series, 14),
    sma20: sma,
    ret6m: ret,
    vol: vol,
    rangePct: rangePct,
  );
}

double? _rsi(List<double> closes, int n) {
  if (closes.length < n + 1) return null;
  var gain = 0.0;
  var loss = 0.0;
  for (var i = closes.length - n; i < closes.length; i++) {
    final d = closes[i] - closes[i - 1];
    if (d >= 0) {
      gain += d;
    } else {
      loss -= d;
    }
  }
  if (loss == 0) return 100;
  final rs = (gain / n) / (loss / n);
  return 100 - (100 / (1 + rs));
}

double _stdev(List<double> xs) {
  if (xs.length < 2) return 0;
  final m = xs.reduce((a, b) => a + b) / xs.length;
  final v = xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (xs.length - 1);
  return sqrt(v);
}

int scoreFrom({
  required TechSnapshot t,
  required double last,
  double? avgCost,
}) {
  var s = 50.0;
  s += (t.ret6m * 40).clamp(-18, 18);
  if (t.sma20 != null) {
    s += last >= t.sma20! ? 8 : -8;
  }
  final rsi = t.rsi;
  if (rsi != null) {
    if (rsi >= 40 && rsi <= 65) {
      s += 10;
    } else if (rsi > 75) {
      s -= 8;
    } else if (rsi < 30) {
      s += 4;
    }
  }
  if (t.rangePct > 0.85) s -= 6;
  if (t.rangePct < 0.25) s += 4;
  s -= (t.vol * 120).clamp(0, 12);
  if (avgCost != null && avgCost > 0) {
    final pnl = last / avgCost - 1;
    s += (pnl * 20).clamp(-10, 10);
  }
  return s.round().clamp(0, 100);
}

Rating ratingFromScore(int score) {
  if (score >= 80) return Rating.strongBuy;
  if (score >= 65) return Rating.buy;
  if (score >= 45) return Rating.hold;
  if (score >= 30) return Rating.sell;
  return Rating.strongSell;
}

DeskReport buildLocalDesk({
  required Quote quote,
  Holding? holding,
  List<NewsHit> headlines = const [],
}) {
  final t = techFrom(quote.sparkline, quote.price);
  final score = scoreFrom(t: t, last: quote.price, avgCost: holding?.avgCost);
  final rating = ratingFromScore(score);
  final rsiTxt = t.rsi == null ? 'n/a' : t.rsi!.toStringAsFixed(1);
  final smaTxt = t.sma20 == null ? 'n/a' : t.sma20!.toStringAsFixed(2);
  final newsBlock = headlines.isEmpty
      ? 'No Yahoo headlines in this pull. News analyst is tape-only until the Tauric backend is attached.'
      : headlines.take(4).map((n) => '• ${n.publisher}: ${n.title}').join('\n');

  final pnlTxt = holding == null
      ? 'No lot on the book — desk is running a watch-only pass.'
      : 'Lot ${holding.shares} @ ${holding.avgCost.toStringAsFixed(2)}. '
          'Mark ${quote.price.toStringAsFixed(2)} is '
          '${((quote.price / holding.avgCost - 1) * 100).toStringAsFixed(2)}% vs cost.';

  return DeskReport(
    ticker: quote.ticker,
    source: 'local',
    asOf: DateTime.now().toUtc(),
    rating: rating,
    score: score,
    technicals:
        'Technical analyst (local, Yahoo daily)\n'
        'Last ${quote.price.toStringAsFixed(2)} ${quote.currency}  ·  ${quote.changePct.toStringAsFixed(2)}% vs prev close.\n'
        'SMA20 $smaTxt  ·  RSI14 $rsiTxt  ·  window return ${(t.ret6m * 100).toStringAsFixed(1)}%  ·  '
        'range percentile ${(t.rangePct * 100).toStringAsFixed(0)}%  ·  daily vol ${(t.vol * 100).toStringAsFixed(2)}%.\n'
        'This node mirrors Tauric’s technical analyst: MACD/RSI-style tape, not a full TA library.',
    fundamentals:
        'Fundamentals analyst (local, price-tape only)\n'
        '${quote.name} (${quote.ticker}) on ${quote.exchange}. '
        '6m high ${quote.high6m?.toStringAsFixed(2) ?? '—'} / low ${quote.low6m?.toStringAsFixed(2) ?? '—'}.\n'
        'On-device desk does not pull 10-Ks or filings. Attach TauricResearch/TradingAgents for the real fundamentals agent (yfinance / Alpha Vantage).',
    sentiment:
        'Sentiment analyst (local)\n'
        'Session tape is ${quote.changePct >= 0 ? 'bid' : 'offered'} ${quote.changePct.abs().toStringAsFixed(2)}%. '
        'Range percentile ${(t.rangePct * 100).toStringAsFixed(0)}% of the downloaded window.\n'
        'Tauric’s sentiment node uses StockTwits/Reddit. This APK approximates mood from price action only.',
    news:
        'News analyst (Yahoo headlines)\n$newsBlock',
    bull:
        'Bull researcher\n'
        'Case for the long: window return ${(t.ret6m * 100).toStringAsFixed(1)}%, '
        '${t.sma20 != null && quote.price >= t.sma20! ? 'price holds above SMA20' : 'mean-reversion room if SMA20 is recaptured'}. '
        '$pnlTxt',
    bear:
        'Bear researcher\n'
        'Case against: daily vol ${(t.vol * 100).toStringAsFixed(2)}%, '
        '${t.rsi != null && t.rsi! > 70 ? 'RSI is extended' : 'momentum can fade without a fundamental catalyst'}. '
        'A local desk cannot see dilution, guidance, or positioning. Treat this as a tape argument only.',
    trader:
        'Trader\n'
        'Synthesis: ${rating.label} at score $score/100. '
        '${holding == null ? 'No shares to adjust — watch the level.' : _traderAction(rating, holding, quote)} '
        'Not an order. Research framing only.',
    risk:
        'Risk committee\n'
        'Realized window vol ${(t.vol * 100).toStringAsFixed(2)}% daily. '
        '${holding == null ? 'No lot risk.' : 'Notional ${(holding.shares * quote.price).toStringAsFixed(2)} ${quote.currency}. '
            'A 10% shock is ~${(holding.shares * quote.price * 0.1).toStringAsFixed(2)} ${quote.currency}.'} '
        'Tauric’s risk team debates aggressive/conservative/neutral; this node is a single volatility check.',
    pm:
        'Portfolio manager\n'
        'Final local rating: ${rating.label}. '
        'This is the on-device stand-in for TradingAgentsGraph.propagate("${quote.ticker}", date). '
        'It is not the LangGraph multi-agent firm. Point the About tab at a Tauric backend to swap this node for the real desk. '
        'Informational only — not investment advice.',
  );
}

String _traderAction(Rating r, Holding h, Quote q) {
  return switch (r) {
    Rating.strongBuy =>
      'Hold the ${fmt(h.shares)} share lot. Tape supports adds only on a pullback toward ${h.avgCost.toStringAsFixed(2)}.',
    Rating.buy =>
      'Hold ${h.ticker}. Do not chase ${q.price.toStringAsFixed(2)} if RSI is extended; scale on dips.',
    Rating.hold =>
      'Stand down. Cost ${h.avgCost.toStringAsFixed(2)} vs mark ${q.price.toStringAsFixed(2)} — no edge to resize.',
    Rating.sell =>
      'Reduce risk. Mark is against the local score. A trim is the research suggestion, not an order.',
    Rating.strongSell =>
      'Risk-off. Local score is in the left tail. Review the lot before the next session.',
  };
}

String fmt(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(4);
}

DeskReport deskFromTauricJson(Map<String, dynamic> j, {Quote? quote}) {
  final decision = '${j['decision'] ?? j['final_trade_decision'] ?? j['rating'] ?? 'HOLD'}';
  final rating = RatingX.parse(decision);
  String pick(List<String> keys) {
    for (final k in keys) {
      final v = j[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  return DeskReport(
    ticker: (j['ticker'] as String?) ?? quote?.ticker ?? '',
    source: 'tauric',
    asOf: DateTime.now().toUtc(),
    rating: rating,
    score: (j['score'] as num?)?.toInt() ?? _scoreFor(rating),
    technicals: pick(['market_report', 'technicals', 'market']),
    fundamentals: pick(['fundamentals_report', 'fundamentals']),
    sentiment: pick(['sentiment_report', 'sentiment']),
    news: pick(['news_report', 'news']),
    bull: pick(['bull_history', 'bull', 'investment_debate_bull']),
    bear: pick(['bear_history', 'bear', 'investment_debate_bear']),
    trader: pick(['trader_investment_plan', 'trader', 'investment_plan']),
    risk: pick(['risk_debate_state', 'risk', 'risk_report']),
    pm: pick(['final_trade_decision', 'pm', 'decision']) +
        (decision.isEmpty ? '' : '\nDecision: $decision'),
    tradeDate: '${j['trade_date'] ?? ''}',
  );
}

int _scoreFor(Rating r) => switch (r) {
      Rating.strongBuy => 88,
      Rating.buy => 72,
      Rating.hold => 52,
      Rating.sell => 34,
      Rating.strongSell => 18,
    };
