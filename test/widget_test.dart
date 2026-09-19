import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentient_alpha/data/copilot.dart';
import 'package:sentient_alpha/data/desk.dart';
import 'package:sentient_alpha/data/models.dart';
import 'package:sentient_alpha/data/position.dart';
import 'package:sentient_alpha/data/storage.dart';
import 'package:sentient_alpha/data/yahoo.dart';
import 'package:sentient_alpha/main.dart';
import 'package:sentient_alpha/state.dart';

class FakeMarkets implements MarketClient {
  @override
  Future<List<SearchHit>> search(String query) async {
    const all = [
      SearchHit(ticker: 'NVDA', name: 'NVIDIA Corporation', exchange: 'NASDAQ'),
      SearchHit(ticker: 'AAPL', name: 'Apple Inc.', exchange: 'NASDAQ'),
    ];
    final q = query.toLowerCase();
    return all
        .where((h) =>
            h.ticker.toLowerCase().contains(q) || h.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<Quote> quote(String ticker, {String range = '6mo'}) async {
    final upper = ticker.toUpperCase();
    final px = upper == 'NVDA' ? 140.0 : 200.0;
    return Quote(
      ticker: upper,
      name: upper == 'NVDA' ? 'NVIDIA Corporation' : 'Apple Inc.',
      exchange: 'NASDAQ',
      price: px,
      prevClose: px * 0.99,
      changePct: 1.01,
      sparkline: [100, 110, 120, 125, 130, px],
      asOf: DateTime.utc(2026, 1, 15),
      high6m: px,
      low6m: 100,
    );
  }

  @override
  Future<double?> closeOn(String ticker, DateTime day) async => 118.4;

  @override
  Future<List<NewsHit>> news(String query) async => const [
        NewsHit(title: 'Cloud capex rises', publisher: 'Reuters'),
      ];
}

void main() {
  test('cost near last price is per-share, quantity defaults to 1', () {
    final g = inferPosition(lastPrice: 140, costIn: 118.4);
    expect(g.shares, 1);
    expect(g.avgCost, 118.4);
    expect(g.costLookedUp, isFalse);
  });

  test('large cash figure infers quantity from last price', () {
    final g = inferPosition(lastPrice: 140, costIn: 1400);
    expect(g.shares, closeTo(10, 0.0001));
    expect(g.avgCost, 140);
    expect(g.costLookedUp, isTrue);
  });

  test('buy-date close becomes cost basis', () {
    final g = inferPosition(lastPrice: 140, sharesIn: 5, histClose: 118.4);
    expect(g.shares, 5);
    expect(g.avgCost, 118.4);
    expect(g.costLookedUp, isTrue);
  });

  test('Yahoo chart JSON parses last and sparkline', () {
    const body = '''
{"chart":{"result":[{"meta":{"currency":"USD","symbol":"NVDA","regularMarketPrice":140.5,
"chartPreviousClose":138,"shortName":"NVIDIA Corporation","exchangeName":"NMS",
"regularMarketTime":1700000000},"timestamp":[1,2,3],
"indicators":{"quote":[{"close":[100.0,120.0,140.5]}]}}],"error":null}}
''';
    final q = parseChart(body);
    expect(q.ticker, 'NVDA');
    expect(q.price, 140.5);
    expect(q.sparkline, [100.0, 120.0, 140.5]);
    expect(q.changePct, closeTo((140.5 / 138 - 1) * 100, 0.001));
  });

  test('search JSON keeps equities', () {
    const body = '''
{"quotes":[
  {"symbol":"NVDA","shortname":"NVIDIA Corporation","exchDisp":"NASDAQ","quoteType":"EQUITY"},
  {"symbol":"FOO","shortname":"Foo Option","quoteType":"OPTION"}
]}
''';
    final hits = parseSearch(body);
    expect(hits.map((h) => h.ticker), ['NVDA']);
  });

  test('rising window scores as a buy-ish local desk', () {
    final quote = Quote(
      ticker: 'NVDA',
      name: 'NVIDIA Corporation',
      exchange: 'NASDAQ',
      price: 140,
      prevClose: 138,
      changePct: 1.4,
      sparkline: [100, 108, 116, 122, 128, 134, 140],
      asOf: DateTime.utc(2026, 1, 15),
      high6m: 140,
      low6m: 100,
    );
    final holding = Holding(
      id: '1',
      ticker: 'NVDA',
      name: 'NVIDIA Corporation',
      exchange: 'NASDAQ',
      shares: 10,
      avgCost: 118.4,
      addedAt: DateTime.utc(2026, 1, 1),
    );
    final desk = buildLocalDesk(
      quote: quote,
      holding: holding,
      headlines: const [NewsHit(title: 'Cloud capex rises', publisher: 'Reuters')],
    );
    expect(desk.source, 'local');
    expect(desk.score, greaterThanOrEqualTo(60));
    expect(desk.news, contains('Cloud capex'));
    expect(desk.pm, contains('NVDA'));
  });

  test('Tauric JSON maps to BUY report', () {
    final desk = deskFromTauricJson({
      'ticker': 'NVDA',
      'decision': 'BUY',
      'market_report': 'tape ok',
      'final_trade_decision': 'BUY on dips',
    });
    expect(desk.source, 'tauric');
    expect(desk.rating, Rating.buy);
    expect(desk.technicals, 'tape ok');
  });

  test('copilot mentions the lot', () {
    final holding = Holding(
      id: '1',
      ticker: 'NVDA',
      name: 'NVIDIA Corporation',
      exchange: 'NASDAQ',
      shares: 10,
      avgCost: 100,
      addedAt: DateTime.utc(2026, 1, 1),
    );
    final reply = replyFor(
      'How is NVDA doing?',
      holdings: [holding],
      quotes: {
        'NVDA': Quote(
          ticker: 'NVDA',
          name: 'NVIDIA Corporation',
          exchange: 'NASDAQ',
          price: 140,
          prevClose: 138,
          changePct: 1.4,
          sparkline: const [140],
          asOf: DateTime.utc(2026, 1, 15),
        ),
      },
      desks: const {},
    );
    expect(reply, contains('NVDA'));
    expect(reply, contains('140.00'));
  });

  testWidgets('app opens on Track with no login and shows a tracked lot', (tester) async {
    final state = AppState(
      markets: FakeMarkets(),
      store: MemoryStore(),
      refreshEvery: const Duration(days: 1),
      autostart: false,
    );
    await state.boot();
    await tester.pumpWidget(SentientAlphaApp(state: state));
    expect(find.text('Enter Terminal'), findsNothing);
    expect(find.text('Add a lot'), findsOneWidget);
    expect(find.text('Track with AI desk'), findsOneWidget);
    await state.addHolding(query: 'NVDA', shares: 10, cost: 118.4);
    await tester.pump();
    expect(state.holdings, isNotEmpty);
    expect(state.holdings.first.ticker, 'NVDA');
    expect(state.holdings.first.shares, 10);
    expect(state.holdings.first.avgCost, 118.4);
    expect(state.quotes['NVDA']?.price, 140);
    state.dispose();
  });
}
