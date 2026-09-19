import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentient_alpha/data/api.dart';
import 'package:sentient_alpha/data/local_desk.dart';
import 'package:sentient_alpha/data/models.dart';
import 'package:sentient_alpha/data/store.dart';
import 'package:sentient_alpha/data/yahoo.dart';
import 'package:uuid/uuid.dart';

// inferPosition lives in models.dart

final storeProvider = Provider((_) => LocalStore());
final yahooProvider = Provider((_) => YahooClient());
final apiProvider = Provider((_) => ApiClient());

class BookState {
  BookState({
    required this.lots,
    required this.alerts,
    required this.cash,
    required this.baseCcy,
    required this.capPct,
    required this.refreshSecs,
    required this.disclaimerAccepted,
    this.backendPill = 'LOCAL DESK',
    this.lastQuoteAt,
    this.selectedTicker,
    this.deskReport,
    this.busy = false,
    this.error,
  });

  final List<Lot> lots;
  final List<AppAlert> alerts;
  final double cash;
  final String baseCcy;
  final double capPct;
  final int refreshSecs;
  final bool disclaimerAccepted;
  final String backendPill;
  final DateTime? lastQuoteAt;
  final String? selectedTicker;
  final DeskReport? deskReport;
  final bool busy;
  final String? error;

  double get nav => cash + lots.fold(0.0, (s, l) => s + l.marketValue);
  double get cost => lots.fold(0.0, (s, l) => s + l.costBasis);
  double get uPnl => nav - cash - cost;

  double weightPct(Lot l) => nav <= 0 ? 0 : (l.marketValue / nav) * 100;

  BookState copyWith({
    List<Lot>? lots,
    List<AppAlert>? alerts,
    double? cash,
    String? baseCcy,
    double? capPct,
    int? refreshSecs,
    bool? disclaimerAccepted,
    String? backendPill,
    DateTime? lastQuoteAt,
    String? selectedTicker,
    DeskReport? deskReport,
    bool? busy,
    String? error,
  }) =>
      BookState(
        lots: lots ?? this.lots,
        alerts: alerts ?? this.alerts,
        cash: cash ?? this.cash,
        baseCcy: baseCcy ?? this.baseCcy,
        capPct: capPct ?? this.capPct,
        refreshSecs: refreshSecs ?? this.refreshSecs,
        disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
        backendPill: backendPill ?? this.backendPill,
        lastQuoteAt: lastQuoteAt ?? this.lastQuoteAt,
        selectedTicker: selectedTicker ?? this.selectedTicker,
        deskReport: deskReport ?? this.deskReport,
        busy: busy ?? this.busy,
        error: error,
      );
}

class BookController extends StateNotifier<BookState> {
  BookController(this._store, this._yahoo, this._api)
      : super(
          BookState(
            lots: const [],
            alerts: const [],
            cash: 0,
            baseCcy: 'USD',
            capPct: 25,
            refreshSecs: 45,
            disclaimerAccepted: false,
          ),
        ) {
    _init();
  }

  final LocalStore _store;
  final YahooClient _yahoo;
  final ApiClient _api;
  Timer? _timer;
  final _uuid = const Uuid();
  final Map<String, double> _prevMarks = {};

  Future<void> _init() async {
    await _api.load();
    final accepted = (await _store.meta('disclaimer_accepted')) == '1';
    final cash = double.tryParse(await _store.meta('cash_base') ?? '0') ?? 0;
    final ccy = await _store.meta('base_currency') ?? 'USD';
    final cap = double.tryParse(await _store.meta('concentration_cap') ?? '25') ?? 25;
    final refresh = int.tryParse(await _store.meta('refresh_secs') ?? '45') ?? 45;
    final lots = await _store.lots();
    final alerts = await _store.alerts();
    state = state.copyWith(
      lots: lots,
      alerts: alerts,
      cash: cash,
      baseCcy: ccy,
      capPct: cap,
      refreshSecs: refresh,
      disclaimerAccepted: accepted,
      backendPill: _api.isConfigured ? 'TAURIC LINKED' : 'LOCAL DESK',
    );
    await refreshQuotes();
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: state.refreshSecs), (_) => refreshQuotes());
  }

  Future<void> acceptDisclaimer() async {
    await _store.setMeta('disclaimer_accepted', '1');
    state = state.copyWith(disclaimerAccepted: true);
  }

  Future<void> setCash(double v) async {
    await _store.setMeta('cash_base', v.toString());
    state = state.copyWith(cash: v);
  }

  Future<void> setBackend(String url, {String? pairing}) async {
    await _api.setBackendUrl(url);
    if (url.trim().isEmpty) {
      state = state.copyWith(backendPill: 'LOCAL DESK');
      return;
    }
    try {
      await _api.health();
      final deviceId = await _store.meta('device_id') ?? _uuid.v4();
      await _store.setMeta('device_id', deviceId);
      await _api.register(deviceId: deviceId, pairingCode: pairing);
      state = state.copyWith(backendPill: 'TAURIC LINKED', error: null);
    } catch (e) {
      state = state.copyWith(backendPill: 'LOCAL DESK', error: 'Backend unreachable: $e');
    }
  }

  Future<void> setRefresh(int secs) async {
    await _store.setMeta('refresh_secs', '$secs');
    state = state.copyWith(refreshSecs: secs);
    _armTimer();
  }

  Future<void> setCap(double cap) async {
    await _store.setMeta('concentration_cap', '$cap');
    state = state.copyWith(capPct: cap);
  }

  /// Returns concentration warning text if any (caller confirms).
  Future<String?> previewConcentration({
    required String ticker,
    required double qty,
    required double mark,
  }) async {
    final existing = state.lots.where((l) => l.ticker.toUpperCase() == ticker.toUpperCase());
    final existingMv = existing.fold(0.0, (s, l) => s + l.marketValue);
    final newMv = existingMv + qty * mark;
    final nav = state.nav - existingMv + newMv;
    if (nav <= 0) return null;
    final pct = newMv / nav * 100;
    if (pct >= state.capPct) {
      return 'This lot would make ${ticker.toUpperCase()} ${pct.toStringAsFixed(1)}% of the book (cap ${state.capPct.toStringAsFixed(0)}%). Save anyway?';
    }
    return null;
  }

  Future<Lot> addLot({
    required String queryOrTicker,
    double? qty,
    double? cost,
    String? buyDate,
    String? note,
    String? resolvedTicker,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      String ticker = resolvedTicker ?? queryOrTicker.trim().toUpperCase();
      String? name;
      if (resolvedTicker == null) {
        final hits = await _yahoo.search(queryOrTicker);
        if (hits.isNotEmpty) {
          ticker = hits.first['ticker'] as String;
          name = hits.first['name'] as String?;
        }
      }
      final q = await _yahoo.quote(ticker);
      name ??= q['name'] as String?;
      final last = (q['last'] as num?)?.toDouble() ?? 0;
      double? hist;
      if (buyDate != null && buyDate.isNotEmpty) {
        hist = await _yahoo.closeOnDate(ticker, buyDate);
      }
      final inf = inferPosition(
        last: last,
        histClose: hist,
        qty: qty,
        cost: cost,
        buyDate: buyDate,
      );
      final lot = Lot(
        id: _uuid.v4(),
        ticker: ticker,
        name: name,
        qty: inf.qty,
        costPerShare: inf.costPerShare,
        costCcy: q['currency'] as String? ?? 'USD',
        tradeDate: buyDate,
        inferred: inf.inferred,
        inferenceNote: inf.inferenceNote,
        note: note,
        last: last,
        asOf: DateTime.now().toUtc(),
      );
      await _store.upsertLot(lot);
      final lots = [...state.lots, lot];
      state = state.copyWith(lots: lots, busy: false, selectedTicker: ticker);
      // Auto local desk only
      await runDesk(ticker, forceLocal: true);
      return lot;
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> refreshQuotes() async {
    if (state.lots.isEmpty) return;
    final updated = <Lot>[];
    for (final lot in state.lots) {
      try {
        final q = await _yahoo.quote(lot.ticker, range: '5d');
        final last = (q['last'] as num?)?.toDouble();
        if (last == null) {
          updated.add(lot);
          continue;
        }
        final prev = _prevMarks[lot.ticker] ?? lot.last;
        if (prev != null && prev > 0) {
          final move = ((last - prev) / prev).abs() * 100;
          if (move >= 3) {
            await _pushAlert(
              kind: 'move',
              title: '${lot.ticker} moved ${move.toStringAsFixed(1)}%',
              body: 'Mark $prev → $last',
            );
          }
          final crossed = (prev - lot.costPerShare) * (last - lot.costPerShare) < 0 ||
              (prev < lot.costPerShare && last >= lot.costPerShare) ||
              (prev > lot.costPerShare && last <= lot.costPerShare);
          if (crossed) {
            await _pushAlert(
              kind: 'cost_cross',
              title: '${lot.ticker} crossed cost',
              body: 'Cost ${lot.costPerShare} · mark $last',
            );
          }
        }
        _prevMarks[lot.ticker] = last;
        lot.last = last;
        lot.asOf = DateTime.now().toUtc();
        await _store.upsertLot(lot);
        updated.add(lot);
      } catch (_) {
        updated.add(lot);
      }
    }
    state = state.copyWith(
      lots: updated,
      lastQuoteAt: DateTime.now().toUtc(),
      alerts: await _store.alerts(),
    );
  }

  Future<void> _pushAlert({required String kind, required String title, required String body}) async {
    final a = AppAlert(id: _uuid.v4(), kind: kind, title: title, body: body, ts: DateTime.now());
    await _store.addAlert(a);
  }

  Future<void> runDesk(String ticker, {bool forceLocal = false}) async {
    state = state.copyWith(busy: true, backendPill: forceLocal || !_api.isConfigured ? state.backendPill : 'DESK RUNNING', selectedTicker: ticker);
    try {
      if (!forceLocal && _api.isConfigured) {
        try {
          final enq = await _api.enqueueDesk(ticker);
          final jobId = enq['job_id'] as String;
          Map<String, dynamic>? job;
          for (var i = 0; i < 60; i++) {
            await Future<void>.delayed(const Duration(seconds: 3));
            job = await _api.getJob(jobId);
            final status = job['status'] as String?;
            if (status == 'succeeded' || status == 'failed') break;
          }
          final report = job?['report'] as Map<String, dynamic>?;
          if (report != null) {
            final seatsRaw = (report['seats'] as Map?) ?? {};
            final seats = seatsRaw.map((k, v) => MapEntry(k.toString(), v.toString()));
            final dr = DeskReport(
              ticker: ticker,
              source: report['source'] as String? ?? 'tauric',
              rating: report['rating'] as String? ?? 'Hold',
              score: (report['score'] as num?)?.toDouble() ?? 50,
              scoreDerived: report['score_derived'] as bool? ?? false,
              seats: seats.cast<String, String>(),
              finalDecision: report['final_trade_decision'] as String?,
            );
            state = state.copyWith(
              deskReport: dr,
              busy: false,
              backendPill: 'TAURIC LINKED',
            );
            return;
          }
          state = state.copyWith(
            error: 'Tauric backend unreachable — fell back to the local desk.',
          );
        } catch (_) {
          state = state.copyWith(
            error: 'Tauric backend unreachable — fell back to the local desk.',
          );
        }
      }
      final portfolio = {
        'cash': state.cash,
        'positions': state.lots
            .map((l) => {
                  'ticker': l.ticker,
                  'qty': l.qty,
                  'weight_pct': state.weightPct(l),
                })
            .toList(),
      };
      final local = await runLocalDesk(ticker, yahoo: _yahoo, portfolio: portfolio);
      state = state.copyWith(
        deskReport: local,
        busy: false,
        backendPill: _api.isConfigured ? 'TAURIC LINKED' : 'LOCAL DESK',
      );
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  Future<String> copilot(String message) async {
    if (_api.isConfigured) {
      try {
        final r = await _api.copilot(message);
        return r['reply'] as String? ?? 'No reply';
      } catch (_) {
        // fall through local
      }
    }
    // Local grounded reply
    final top = [...state.lots]..sort((a, b) => b.marketValue.compareTo(a.marketValue));
    final t = top.isEmpty ? 'none' : '${top.first.ticker} ${state.weightPct(top.first).toStringAsFixed(1)}%';
    return 'Book NAV ${state.nav.toStringAsFixed(2)} ${state.baseCcy}. '
        'uPnL ${state.uPnl >= 0 ? '+' : ''}${state.uPnl.toStringAsFixed(2)}. '
        'Largest name: $t. '
        'Informational only — not a trade instruction. '
        '(Cloud copilot offline — answered from on-device book.)';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final bookProvider = StateNotifierProvider<BookController, BookState>((ref) {
  return BookController(ref.watch(storeProvider), ref.watch(yahooProvider), ref.watch(apiProvider));
});
