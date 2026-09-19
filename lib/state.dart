import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'data/copilot.dart';
import 'data/desk.dart';
import 'data/models.dart';
import 'data/position.dart';
import 'data/storage.dart';
import 'data/yahoo.dart';

class AppState extends ChangeNotifier {
  AppState({
    MarketClient? markets,
    HoldingStore? store,
    TauricGateway? tauric,
    Duration refreshEvery = const Duration(seconds: 45),
    bool autostart = true,
  })  : markets = markets ?? YahooClient(),
        store = store ?? PrefsStore(),
        tauric = tauric ?? TauricGateway(),
        _refreshEvery = refreshEvery {
    if (autostart) {
      unawaited(boot());
    }
  }

  final MarketClient markets;
  final HoldingStore store;
  final TauricGateway tauric;
  final Duration _refreshEvery;
  final _rng = Random();

  Timer? _timer;
  bool ready = false;
  bool busy = false;
  String? error;
  int tab = 0;
  bool typing = false;
  String backendUrl = '';
  String? lastRefreshNote;
  DateTime? lastRefreshAt;

  final List<Holding> holdings = [];
  final Map<String, Quote> quotes = {};
  final Map<String, DeskReport> desks = {};
  final List<AlertItem> alerts = [];
  final List<ChatMsg> _messages = [];
  final Map<String, double> _lastMark = {};

  List<ChatMsg> get messages => List.unmodifiable(_messages);

  Future<void> boot() async {
    final book = await store.load();
    holdings
      ..clear()
      ..addAll(book.holdings);
    quotes
      ..clear()
      ..addAll(book.quotes);
    desks
      ..clear()
      ..addAll(book.desks);
    backendUrl = book.backendUrl;
    _messages
      ..clear()
      ..addAll(seedThread(holdings));
    ready = true;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer.periodic(_refreshEvery, (_) => refreshQuotes());
    if (holdings.isNotEmpty) {
      await refreshQuotes();
    }
  }

  double get equityValue => holdings.fold(0.0, (sum, h) {
        final px = quotes[h.ticker]?.price ?? h.avgCost;
        return sum + px * h.shares;
      });

  double get costValue =>
      holdings.fold(0.0, (sum, h) => sum + h.avgCost * h.shares);

  double get unrealizedTotal => equityValue - costValue;

  double holdingValue(Holding h) =>
      (quotes[h.ticker]?.price ?? h.avgCost) * h.shares;

  double unrealized(Holding h) =>
      ((quotes[h.ticker]?.price ?? h.avgCost) - h.avgCost) * h.shares;

  Quote? quoteOf(String ticker) => quotes[ticker];

  Future<void> setTab(int value) async {
    tab = value;
    notifyListeners();
  }

  Future<void> setBackendUrl(String url) async {
    backendUrl = url.trim();
    await _persist();
    notifyListeners();
  }

  Future<List<SearchHit>> lookup(String query) => markets.search(query);

  Future<void> addHolding({
    required String query,
    SearchHit? chosen,
    double? shares,
    double? cost,
    DateTime? buyDate,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      error = 'Enter a stock name or ticker.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final hit = chosen ?? await _resolve(q);
      final quote = await markets.quote(hit.ticker);
      double? hist;
      if (buyDate != null) {
        hist = await markets.closeOn(hit.ticker, buyDate);
        if (hist == null) {
          throw StateError(
            'No daily close near ${DateFormat.yMMMd().format(buyDate)} for ${hit.ticker}.',
          );
        }
      }
      final guess = inferPosition(
        lastPrice: quote.price,
        sharesIn: shares,
        costIn: cost,
        histClose: hist,
      );
      final holding = Holding(
        id: '${hit.ticker}-${DateTime.now().millisecondsSinceEpoch}',
        ticker: quote.ticker.isEmpty ? hit.ticker : quote.ticker,
        name: quote.name.isEmpty ? hit.name : quote.name,
        exchange: quote.exchange.isEmpty ? hit.exchange : quote.exchange,
        shares: guess.shares,
        avgCost: guess.avgCost,
        addedAt: DateTime.now().toUtc(),
        buyDate: buyDate,
        costLookedUp: guess.costLookedUp,
        note: guess.note,
      );
      holdings.removeWhere((h) => h.ticker == holding.ticker);
      holdings.insert(0, holding);
      quotes[holding.ticker] = quote;
      _pushAlert(
        title: 'Now tracking ${holding.ticker}',
        body: guess.note,
        tone: 'good',
      );
      await _persist();
      notifyListeners();
      unawaited(runDesk(holding.ticker));
    } catch (e) {
      error = '$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<SearchHit> _resolve(String q) async {
    final asTicker = q.toUpperCase().replaceAll(' ', '');
    try {
      final direct = await markets.quote(asTicker);
      return SearchHit(
        ticker: direct.ticker.isEmpty ? asTicker : direct.ticker,
        name: direct.name,
        exchange: direct.exchange,
      );
    } catch (_) {
      final hits = await markets.search(q);
      if (hits.isEmpty) {
        throw StateError('No Yahoo match for "$q". Try the ticker (AAPL, RELIANCE.NS).');
      }
      return hits.first;
    }
  }

  Future<void> updateLot(Holding h, {double? shares, double? avgCost}) async {
    final i = holdings.indexWhere((x) => x.id == h.id);
    if (i < 0) return;
    holdings[i] = h.copyWith(shares: shares, avgCost: avgCost);
    await _persist();
    notifyListeners();
  }

  Future<void> removeHolding(String id) async {
    final gone = holdings.where((h) => h.id == id).toList();
    holdings.removeWhere((h) => h.id == id);
    for (final h in gone) {
      quotes.remove(h.ticker);
      desks.remove(h.ticker);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> refreshQuotes() async {
    if (holdings.isEmpty) return;
    try {
      for (final h in List<Holding>.from(holdings)) {
        final q = await markets.quote(h.ticker);
        final prev = _lastMark[h.ticker] ?? quotes[h.ticker]?.price;
        quotes[h.ticker] = q;
        if (h.name != q.name && q.name.isNotEmpty) {
          final i = holdings.indexWhere((x) => x.id == h.id);
          if (i >= 0) holdings[i] = holdings[i].copyWith(name: q.name, exchange: q.exchange);
        }
        if (prev != null && prev > 0) {
          final move = (q.price / prev - 1) * 100;
          if (move.abs() >= 3) {
            _pushAlert(
              title: '${h.ticker} ${move >= 0 ? 'up' : 'down'} ${move.abs().toStringAsFixed(2)}%',
              body:
                  'Mark ${q.price.toStringAsFixed(2)} vs last check ${prev.toStringAsFixed(2)}. Cost ${h.avgCost.toStringAsFixed(2)}.',
              tone: move >= 0 ? 'good' : 'warn',
            );
          }
          final crossed = (prev - h.avgCost) * (q.price - h.avgCost) < 0;
          if (crossed) {
            _pushAlert(
              title: '${h.ticker} crossed cost',
              body:
                  'Price ${q.price.toStringAsFixed(2)} vs cost ${h.avgCost.toStringAsFixed(2)}.',
              tone: q.price >= h.avgCost ? 'good' : 'warn',
            );
          }
        }
        _lastMark[h.ticker] = q.price;
      }
      lastRefreshAt = DateTime.now();
      lastRefreshNote = 'Yahoo ${DateFormat.Hms().format(lastRefreshAt!.toLocal())}';
      error = null;
      await _persist();
    } catch (e) {
      error = 'Monitor: $e';
    }
    notifyListeners();
  }

  Future<DeskReport?> runDesk(String ticker) async {
    final holding = holdings.cast<Holding?>().firstWhere(
          (h) => h!.ticker == ticker,
          orElse: () => null,
        );
    final quote = quotes[ticker] ?? await markets.quote(ticker);
    quotes[ticker] = quote;
    busy = true;
    notifyListeners();
    try {
      DeskReport report;
      if (backendUrl.isNotEmpty) {
        try {
          report = await tauric.analyze(
            baseUrl: backendUrl,
            ticker: ticker,
            tradeDate: DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc()),
            avgCost: holding?.avgCost,
            shares: holding?.shares,
          );
        } catch (e) {
          final headlines = await markets.news(ticker);
          report = buildLocalDesk(quote: quote, holding: holding, headlines: headlines);
          _pushAlert(
            title: 'Tauric backend unreachable',
            body: '$e — fell back to the local desk.',
            tone: 'warn',
          );
        }
      } else {
        final headlines = await markets.news(ticker);
        report = buildLocalDesk(quote: quote, holding: holding, headlines: headlines);
      }
      desks[ticker] = report;
      _pushAlert(
        title: '$ticker desk ${report.rating.label}',
        body:
            'Score ${report.score}/100 via ${report.source == 'tauric' ? 'TradingAgents' : 'local Tauric seats'}.',
        tone: report.rating.rec == Rec.sell ? 'warn' : 'good',
      );
      await _persist();
      return report;
    } catch (e) {
      error = '$e';
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> sendChat(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || typing) return;
    _messages.add(ChatMsg(text: trimmed, fromUser: true, time: 'Now'));
    typing = true;
    notifyListeners();
    await Future<void>.delayed(Duration(milliseconds: 350 + _rng.nextInt(400)));
    _messages.add(
      ChatMsg(
        text: replyFor(
          trimmed,
          holdings: holdings,
          quotes: quotes,
          desks: desks,
        ),
        fromUser: false,
        time: 'Now',
      ),
    );
    typing = false;
    notifyListeners();
  }

  void resetChat() {
    _messages
      ..clear()
      ..addAll(seedThread(holdings));
    notifyListeners();
  }

  void _pushAlert({
    required String title,
    required String body,
    required String tone,
  }) {
    alerts.insert(
      0,
      AlertItem(
        title: title,
        body: body,
        time: DateFormat.Hm().format(DateTime.now()),
        tone: tone,
      ),
    );
    if (alerts.length > 20) {
      alerts.removeRange(20, alerts.length);
    }
  }

  Future<void> _persist() {
    return store.save(
      PersistedBook(
        holdings: List.unmodifiable(holdings),
        quotes: Map.unmodifiable(quotes),
        desks: Map.unmodifiable(desks),
        backendUrl: backendUrl,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
