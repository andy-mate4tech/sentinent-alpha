enum Rec { buy, hold, sell }

enum Rating { strongBuy, buy, hold, sell, strongSell }

extension RatingX on Rating {
  String get label => switch (this) {
        Rating.strongBuy => 'STRONG BUY',
        Rating.buy => 'BUY',
        Rating.hold => 'HOLD',
        Rating.sell => 'SELL',
        Rating.strongSell => 'STRONG SELL',
      };

  Rec get rec => switch (this) {
        Rating.strongBuy || Rating.buy => Rec.buy,
        Rating.hold => Rec.hold,
        Rating.sell || Rating.strongSell => Rec.sell,
      };

  static Rating parse(String raw) {
    final t = raw.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (t.contains('strong buy') || t.contains('strongbuy')) {
      return Rating.strongBuy;
    }
    if (t.contains('strong sell') || t.contains('strongsell')) {
      return Rating.strongSell;
    }
    if (t.contains('buy')) return Rating.buy;
    if (t.contains('sell') || t.contains('reduce')) return Rating.sell;
    return Rating.hold;
  }
}

class SearchHit {
  const SearchHit({
    required this.ticker,
    required this.name,
    required this.exchange,
    this.quoteType = 'EQUITY',
  });

  final String ticker;
  final String name;
  final String exchange;
  final String quoteType;
}

class NewsHit {
  const NewsHit({
    required this.title,
    required this.publisher,
    this.link = '',
  });

  final String title;
  final String publisher;
  final String link;
}

class Quote {
  const Quote({
    required this.ticker,
    required this.name,
    required this.exchange,
    required this.price,
    required this.prevClose,
    required this.changePct,
    required this.sparkline,
    required this.asOf,
    this.currency = 'USD',
    this.high6m,
    this.low6m,
    this.volume,
  });

  final String ticker;
  final String name;
  final String exchange;
  final double price;
  final double prevClose;
  final double changePct;
  final List<double> sparkline;
  final DateTime asOf;
  final String currency;
  final double? high6m;
  final double? low6m;
  final double? volume;

  Map<String, dynamic> toJson() => {
        'ticker': ticker,
        'name': name,
        'exchange': exchange,
        'price': price,
        'prevClose': prevClose,
        'changePct': changePct,
        'sparkline': sparkline,
        'asOf': asOf.toIso8601String(),
        'currency': currency,
        'high6m': high6m,
        'low6m': low6m,
        'volume': volume,
      };

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        ticker: j['ticker'] as String,
        name: j['name'] as String? ?? j['ticker'] as String,
        exchange: j['exchange'] as String? ?? '',
        price: (j['price'] as num).toDouble(),
        prevClose: (j['prevClose'] as num?)?.toDouble() ?? (j['price'] as num).toDouble(),
        changePct: (j['changePct'] as num?)?.toDouble() ?? 0,
        sparkline: ((j['sparkline'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        asOf: DateTime.tryParse(j['asOf'] as String? ?? '') ?? DateTime.now(),
        currency: j['currency'] as String? ?? 'USD',
        high6m: (j['high6m'] as num?)?.toDouble(),
        low6m: (j['low6m'] as num?)?.toDouble(),
        volume: (j['volume'] as num?)?.toDouble(),
      );
}

class Holding {
  const Holding({
    required this.id,
    required this.ticker,
    required this.name,
    required this.exchange,
    required this.shares,
    required this.avgCost,
    required this.addedAt,
    this.buyDate,
    this.costLookedUp = false,
    this.note = '',
  });

  final String id;
  final String ticker;
  final String name;
  final String exchange;
  final double shares;
  final double avgCost;
  final DateTime addedAt;
  final DateTime? buyDate;
  final bool costLookedUp;
  final String note;

  Holding copyWith({
    double? shares,
    double? avgCost,
    String? note,
    String? name,
    String? exchange,
  }) {
    return Holding(
      id: id,
      ticker: ticker,
      name: name ?? this.name,
      exchange: exchange ?? this.exchange,
      shares: shares ?? this.shares,
      avgCost: avgCost ?? this.avgCost,
      addedAt: addedAt,
      buyDate: buyDate,
      costLookedUp: costLookedUp,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticker': ticker,
        'name': name,
        'exchange': exchange,
        'shares': shares,
        'avgCost': avgCost,
        'addedAt': addedAt.toIso8601String(),
        'buyDate': buyDate?.toIso8601String(),
        'costLookedUp': costLookedUp,
        'note': note,
      };

  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
        id: j['id'] as String,
        ticker: j['ticker'] as String,
        name: j['name'] as String? ?? j['ticker'] as String,
        exchange: j['exchange'] as String? ?? '',
        shares: (j['shares'] as num).toDouble(),
        avgCost: (j['avgCost'] as num).toDouble(),
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now(),
        buyDate: DateTime.tryParse(j['buyDate'] as String? ?? ''),
        costLookedUp: j['costLookedUp'] as bool? ?? false,
        note: j['note'] as String? ?? '',
      );
}

class PositionGuess {
  const PositionGuess({
    required this.shares,
    required this.avgCost,
    required this.note,
    this.costLookedUp = false,
  });

  final double shares;
  final double avgCost;
  final String note;
  final bool costLookedUp;
}

class DeskReport {
  const DeskReport({
    required this.ticker,
    required this.source,
    required this.asOf,
    required this.rating,
    required this.score,
    required this.technicals,
    required this.fundamentals,
    required this.sentiment,
    required this.news,
    required this.bull,
    required this.bear,
    required this.trader,
    required this.risk,
    required this.pm,
    this.tradeDate = '',
  });

  final String ticker;
  final String source; // local | tauric
  final DateTime asOf;
  final Rating rating;
  final int score;
  final String technicals;
  final String fundamentals;
  final String sentiment;
  final String news;
  final String bull;
  final String bear;
  final String trader;
  final String risk;
  final String pm;
  final String tradeDate;

  Map<String, dynamic> toJson() => {
        'ticker': ticker,
        'source': source,
        'asOf': asOf.toIso8601String(),
        'rating': rating.name,
        'score': score,
        'technicals': technicals,
        'fundamentals': fundamentals,
        'sentiment': sentiment,
        'news': news,
        'bull': bull,
        'bear': bear,
        'trader': trader,
        'risk': risk,
        'pm': pm,
        'tradeDate': tradeDate,
      };

  factory DeskReport.fromJson(Map<String, dynamic> j) => DeskReport(
        ticker: j['ticker'] as String,
        source: j['source'] as String? ?? 'local',
        asOf: DateTime.tryParse(j['asOf'] as String? ?? '') ?? DateTime.now(),
        rating: Rating.values.firstWhere(
          (r) => r.name == j['rating'],
          orElse: () => RatingX.parse('${j['rating']}'),
        ),
        score: (j['score'] as num?)?.toInt() ?? 50,
        technicals: j['technicals'] as String? ?? '',
        fundamentals: j['fundamentals'] as String? ?? '',
        sentiment: j['sentiment'] as String? ?? '',
        news: j['news'] as String? ?? '',
        bull: j['bull'] as String? ?? '',
        bear: j['bear'] as String? ?? '',
        trader: j['trader'] as String? ?? '',
        risk: j['risk'] as String? ?? '',
        pm: j['pm'] as String? ?? '',
        tradeDate: j['tradeDate'] as String? ?? '',
      );
}

class AlertItem {
  const AlertItem({
    required this.title,
    required this.body,
    required this.time,
    this.tone = 'info',
  });

  final String title;
  final String body;
  final String time;
  final String tone;
}

class ChatMsg {
  const ChatMsg({
    required this.text,
    required this.fromUser,
    this.time = '',
  });

  final String text;
  final bool fromUser;
  final String time;
}

class PersistedBook {
  const PersistedBook({
    this.holdings = const [],
    this.quotes = const {},
    this.desks = const {},
    this.backendUrl = '',
  });

  final List<Holding> holdings;
  final Map<String, Quote> quotes;
  final Map<String, DeskReport> desks;
  final String backendUrl;

  Map<String, dynamic> toJson() => {
        'holdings': holdings.map((h) => h.toJson()).toList(),
        'quotes': quotes.map((k, v) => MapEntry(k, v.toJson())),
        'desks': desks.map((k, v) => MapEntry(k, v.toJson())),
        'backendUrl': backendUrl,
      };

  factory PersistedBook.fromJson(Map<String, dynamic> j) {
    final qj = (j['quotes'] as Map?)?.cast<String, dynamic>() ?? {};
    final dj = (j['desks'] as Map?)?.cast<String, dynamic>() ?? {};
    return PersistedBook(
      holdings: ((j['holdings'] as List?) ?? const [])
          .map((e) => Holding.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      quotes: qj.map(
        (k, v) => MapEntry(k, Quote.fromJson((v as Map).cast<String, dynamic>())),
      ),
      desks: dj.map(
        (k, v) => MapEntry(k, DeskReport.fromJson((v as Map).cast<String, dynamic>())),
      ),
      backendUrl: j['backendUrl'] as String? ?? '',
    );
  }
}
