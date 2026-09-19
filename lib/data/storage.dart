import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'desk.dart';
import 'models.dart';

abstract class HoldingStore {
  Future<PersistedBook> load();
  Future<void> save(PersistedBook book);
}

class MemoryStore implements HoldingStore {
  MemoryStore([this.book = const PersistedBook()]);
  PersistedBook book;

  @override
  Future<PersistedBook> load() async => book;

  @override
  Future<void> save(PersistedBook next) async {
    book = next;
  }
}

class PrefsStore implements HoldingStore {
  PrefsStore({this.key = 'sa_book_v3'});
  final String key;

  @override
  Future<PersistedBook> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return const PersistedBook();
    try {
      return PersistedBook.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PersistedBook();
    }
  }

  @override
  Future<void> save(PersistedBook book) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(book.toJson()));
  }
}

class TauricGateway {
  TauricGateway({http.Client? httpClient}) : _http = httpClient ?? http.Client();
  final http.Client _http;

  Future<DeskReport> analyze({
    required String baseUrl,
    required String ticker,
    String? tradeDate,
    double? avgCost,
    double? shares,
  }) async {
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$root/v1/desk/analyze');
    final res = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({
            'ticker': ticker,
            'trade_date': tradeDate,
            'avg_cost': avgCost,
            'shares': shares,
          }),
        )
        .timeout(const Duration(seconds: 180));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Tauric backend HTTP ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return deskFromTauricJson(json);
  }
}
