import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'models.dart';

abstract class MarketClient {
  Future<List<SearchHit>> search(String query);
  Future<Quote> quote(String ticker, {String range = '6mo'});
  Future<double?> closeOn(String ticker, DateTime day);
  Future<List<NewsHit>> news(String query);
}

class YahooClient implements MarketClient {
  YahooClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36';

  Future<String> _get(List<Uri> urls) async {
    Object? last;
    for (final url in urls) {
      try {
        final res = await _http
            .get(url, headers: {'User-Agent': _ua, 'Accept': 'application/json'})
            .timeout(const Duration(seconds: 12));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return res.body;
        }
        last = 'HTTP ${res.statusCode} for $url';
      } catch (e) {
        last = e;
      }
    }
    throw StateError('Yahoo request failed: $last');
  }

  @override
  Future<List<SearchHit>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final body = await _get([
      Uri.https('query1.finance.yahoo.com', '/v1/finance/search', {
        'q': q,
        'quotesCount': '10',
        'newsCount': '0',
      }),
      Uri.https('query2.finance.yahoo.com', '/v1/finance/search', {
        'q': q,
        'quotesCount': '10',
        'newsCount': '0',
      }),
    ]);
    return parseSearch(body);
  }

  @override
  Future<Quote> quote(String ticker, {String range = '6mo'}) async {
    final body = await _get([
      Uri.https('query1.finance.yahoo.com', '/v8/finance/chart/${ticker.trim()}', {
        'interval': '1d',
        'range': range,
        'includePrePost': 'false',
      }),
      Uri.https('query2.finance.yahoo.com', '/v8/finance/chart/${ticker.trim()}', {
        'interval': '1d',
        'range': range,
        'includePrePost': 'false',
      }),
    ]);
    return parseChart(body);
  }

  @override
  Future<double?> closeOn(String ticker, DateTime day) async {
    final start = DateTime.utc(day.year, day.month, day.day)
        .subtract(const Duration(days: 5));
    final end = DateTime.utc(day.year, day.month, day.day)
        .add(const Duration(days: 6));
    final body = await _get([
      Uri.https('query1.finance.yahoo.com', '/v8/finance/chart/${ticker.trim()}', {
        'interval': '1d',
        'period1': '${start.millisecondsSinceEpoch ~/ 1000}',
        'period2': '${end.millisecondsSinceEpoch ~/ 1000}',
      }),
      Uri.https('query2.finance.yahoo.com', '/v8/finance/chart/${ticker.trim()}', {
        'interval': '1d',
        'period1': '${start.millisecondsSinceEpoch ~/ 1000}',
        'period2': '${end.millisecondsSinceEpoch ~/ 1000}',
      }),
    ]);
    return closeNearest(body, day);
  }

  @override
  Future<List<NewsHit>> news(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final body = await _get([
        Uri.https('query1.finance.yahoo.com', '/v1/finance/search', {
          'q': q,
          'quotesCount': '0',
          'newsCount': '6',
        }),
      ]);
      return parseNews(body);
    } catch (_) {
      return const [];
    }
  }
}

List<SearchHit> parseSearch(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final quotes = (json['quotes'] as List?) ?? const [];
  final hits = <SearchHit>[];
  for (final raw in quotes) {
    final m = (raw as Map).cast<String, dynamic>();
    final symbol = (m['symbol'] as String?)?.trim() ?? '';
    if (symbol.isEmpty) continue;
    final type = (m['quoteType'] as String? ?? '').toUpperCase();
    if (type.isNotEmpty &&
        type != 'EQUITY' &&
        type != 'ETF' &&
        type != 'CRYPTOCURRENCY' &&
        type != 'INDEX' &&
        type != 'MUTUALFUND') {
      continue;
    }
    hits.add(
      SearchHit(
        ticker: symbol,
        name: (m['shortname'] as String?) ??
            (m['longname'] as String?) ??
            (m['longName'] as String?) ??
            symbol,
        exchange: (m['exchDisp'] as String?) ?? (m['exchange'] as String?) ?? '',
        quoteType: type.isEmpty ? 'EQUITY' : type,
      ),
    );
  }
  return hits;
}

List<NewsHit> parseNews(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final news = (json['news'] as List?) ?? const [];
  return news.map((raw) {
    final m = (raw as Map).cast<String, dynamic>();
    return NewsHit(
      title: m['title'] as String? ?? '',
      publisher: m['publisher'] as String? ?? '',
      link: m['link'] as String? ?? '',
    );
  }).where((n) => n.title.isNotEmpty).toList();
}

Quote parseChart(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final chart = json['chart'] as Map<String, dynamic>?;
  final err = chart?['error'];
  if (err != null) {
    throw StateError('Yahoo chart error: $err');
  }
  final results = chart?['result'] as List?;
  if (results == null || results.isEmpty) {
    throw StateError('No Yahoo chart data');
  }
  final r = (results.first as Map).cast<String, dynamic>();
  final meta = (r['meta'] as Map).cast<String, dynamic>();
  final indicators = (r['indicators'] as Map?)?.cast<String, dynamic>() ?? {};
  final quoteList = (indicators['quote'] as List?) ?? const [];
  final q0 = quoteList.isEmpty
      ? <String, dynamic>{}
      : (quoteList.first as Map).cast<String, dynamic>();
  final closes = ((q0['close'] as List?) ?? const [])
      .where((e) => e != null)
      .map((e) => (e as num).toDouble())
      .toList();
  final price = (meta['regularMarketPrice'] as num?)?.toDouble() ??
      (closes.isNotEmpty ? closes.last : null);
  if (price == null) {
    throw StateError('Yahoo returned no last price');
  }
  final prev = (meta['chartPreviousClose'] as num?)?.toDouble() ??
      (meta['previousClose'] as num?)?.toDouble() ??
      (closes.length >= 2 ? closes[closes.length - 2] : price);
  final changePct = prev == 0 ? 0.0 : (price / prev - 1) * 100;
  final high = closes.isEmpty ? price : closes.reduce(max);
  final low = closes.isEmpty ? price : closes.reduce(min);
  final ts = meta['regularMarketTime'];
  final asOf = ts is num
      ? DateTime.fromMillisecondsSinceEpoch((ts * 1000).round(), isUtc: true)
      : DateTime.now().toUtc();
  return Quote(
    ticker: (meta['symbol'] as String?) ?? '',
    name: (meta['shortName'] as String?) ??
        (meta['longName'] as String?) ??
        (meta['symbol'] as String?) ??
        '',
    exchange: (meta['fullExchangeName'] as String?) ??
        (meta['exchangeName'] as String?) ??
        '',
    price: price,
    prevClose: prev,
    changePct: changePct,
    sparkline: closes.length > 80 ? closes.sublist(closes.length - 80) : closes,
    asOf: asOf,
    currency: meta['currency'] as String? ?? 'USD',
    high6m: high,
    low6m: low,
    volume: (meta['regularMarketVolume'] as num?)?.toDouble(),
  );
}

double? closeNearest(String body, DateTime day) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final results = (json['chart'] as Map?)?['result'] as List?;
  if (results == null || results.isEmpty) return null;
  final r = (results.first as Map).cast<String, dynamic>();
  final stamps = ((r['timestamp'] as List?) ?? const [])
      .map((e) => (e as num).toInt())
      .toList();
  final quoteList =
      ((r['indicators'] as Map?)?['quote'] as List?) ?? const [];
  final closes = quoteList.isEmpty
      ? const <dynamic>[]
      : ((quoteList.first as Map)['close'] as List? ?? const []);
  if (stamps.isEmpty || closes.isEmpty) return null;
  final target = DateTime.utc(day.year, day.month, day.day);
  int? bestI;
  var bestDist = 1 << 30;
  for (var i = 0; i < stamps.length && i < closes.length; i++) {
    if (closes[i] == null) continue;
    final d = DateTime.fromMillisecondsSinceEpoch(stamps[i] * 1000, isUtc: true);
    final dayOnly = DateTime.utc(d.year, d.month, d.day);
    final dist = target.difference(dayOnly).inDays.abs();
    if (dayOnly.isAfter(target)) continue;
    if (dist < bestDist) {
      bestDist = dist;
      bestI = i;
    }
  }
  if (bestI == null) return null;
  return (closes[bestI] as num).toDouble();
}
